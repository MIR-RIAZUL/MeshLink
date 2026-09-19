import 'dart:async';
import 'dart:convert';

import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';

abstract class MeshMessagingService {
  Stream<MeshMessage> get incomingMessages;
  Stream<String> get ackReceived;

  Future<bool> sendMessage(MeshMessage message);
  Future<List<MeshMessage>> getMessagesForPeer(String peerId);
  Future<void> retryMessage(MeshMessage message);
  Future<void> dispose();
}

class BleMeshMessagingService implements MeshMessagingService {
  BleMeshMessagingService({
    required DeviceDiscoveryService discoveryService,
    required MessageStorageService storageService,
    required String localId,
  }) : _service = discoveryService,
       _storage = storageService,
       _currentLocalId = localId {
    _subscription = _service.events.listen(_handleDiscoveryEvent);
  }

  final DeviceDiscoveryService _service;
  final MessageStorageService _storage;
  String _currentLocalId;

  String get localId => _currentLocalId;

  void setLocalId(String id) {
    _currentLocalId = id;
  }

  StreamSubscription<DeviceDiscoveryEvent>? _subscription;
  final StreamController<MeshMessage> _incomingController =
      StreamController<MeshMessage>.broadcast();
  final StreamController<String> _ackController =
      StreamController<String>.broadcast();

  @override
  Stream<MeshMessage> get incomingMessages => _incomingController.stream;

  @override
  Stream<String> get ackReceived => _ackController.stream;

  @override
  Future<bool> sendMessage(MeshMessage message) async {
    // 1. Save locally with sending state
    final sendingMsg = message.copyWith(status: MessageStatus.sending);
    await _storage.saveMessage(sendingMsg);

    // 2. Transmit over BLE GATT connection
    final payload = sendingMsg.toWireProtocol();
    final sent = await _service.sendMessage(message.receiverId, payload);

    if (sent) {
      await _storage.updateMessageStatus(message.id, MessageStatus.sent);
      return true;
    } else {
      await _storage.updateMessageStatus(message.id, MessageStatus.failed);
      return false;
    }
  }

  @override
  Future<void> retryMessage(MeshMessage message) async {
    await sendMessage(message);
  }

  @override
  Future<List<MeshMessage>> getMessagesForPeer(String peerId) async {
    return _storage.getMessages(peerId);
  }

  void _handleDiscoveryEvent(DeviceDiscoveryEvent event) async {
    if (event is! MessageReceivedEvent) return;
    try {
      final data = jsonDecode(event.payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'message') {
        final messageId = data['messageId'] as String;
        final senderId = data['senderId'] as String;
        final receiverId = data['receiverId'] as String;
        final text = data['text'] as String;
        final timestamp =
            DateTime.tryParse(data['timestamp'] as String? ?? '') ??
            DateTime.now();

        // Duplicate protection
        if (await _storage.hasMessage(messageId)) {
          // Already have it, but reply with ACK in case sender didn't receive previous ACK
          final ackPayload = MeshMessage.createAckPayload(
            messageId: messageId,
            senderId: _currentLocalId,
            receiverId: senderId,
          );
          await _service.sendMessage(senderId, ackPayload);
          return;
        }

        final receivedMessage = MeshMessage(
          id: messageId,
          senderId: senderId,
          receiverId: receiverId,
          text: text,
          timestamp: timestamp,
          status: MessageStatus.delivered,
        );

        await _storage.saveMessage(receivedMessage);
        _incomingController.add(receivedMessage);

        // Send ACK back to sender
        final ackPayload = MeshMessage.createAckPayload(
          messageId: messageId,
          senderId: _currentLocalId,
          receiverId: senderId,
        );
        await _service.sendMessage(senderId, ackPayload);
      } else if (type == 'ack') {
        final messageId = data['messageId'] as String?;
        if (messageId != null) {
          await _storage.updateMessageStatus(
            messageId,
            MessageStatus.delivered,
          );
          _ackController.add(messageId);
        }
      }
    } catch (_) {
      // Ignore malformed payloads
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _incomingController.close();
    await _ackController.close();
  }
}
