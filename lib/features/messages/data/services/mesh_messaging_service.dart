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
  Future<void> flushPendingMessages(String peerId);
  Future<void> dispose();
}

class BleMeshMessagingService implements MeshMessagingService {
  BleMeshMessagingService({
    required DeviceDiscoveryService discoveryService,
    required MessageStorageService storageService,
    required String localId,
  })  : _service = discoveryService,
        _storage = storageService,
        _currentLocalId = localId {
    _subscription = _service.events.listen(_handleDiscoveryEvent);
  }

  final DeviceDiscoveryService _service;
  final MessageStorageService _storage;
  String _currentLocalId;
  bool _isFlushing = false;

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
    // Validate text length
    MeshMessage.validateLength(message.text);

    // If message is created in pending state (offline), store locally without wire transmission
    if (message.status == MessageStatus.pending) {
      await _storage.saveMessage(message);
      return false;
    }

    // 1. Prepare sending status message
    final sendingMsg = message.copyWith(status: MessageStatus.sending);
    await _storage.saveMessage(sendingMsg);

    // 2. Transmit wire payload over P2P link
    final payload = sendingMsg.toWireProtocol();
    final sent = await _service.sendMessage(message.receiverId, payload);

    if (sent) {
      // Sent over wire, waiting for ACK to mark delivered
      final sentMsg = message.copyWith(status: MessageStatus.sent);
      await _storage.updateMessageStatus(message.id, MessageStatus.sent);
      _incomingController.add(sentMsg);
      return true;
    } else {
      // Failed to deliver frame (offline or connection lost during send)
      final newStatus = message.retryCount >= MeshMessage.maxRetryLimit
          ? MessageStatus.failed
          : MessageStatus.pending;
      final failedMsg = message.copyWith(status: newStatus);
      await _storage.updateMessageStatus(message.id, newStatus);
      _incomingController.add(failedMsg);
      return false;
    }
  }

  @override
  Future<void> retryMessage(MeshMessage message) async {
    await _storage.incrementRetryCount(message.id);
    final toSend = message.copyWith(
      status: MessageStatus.sending,
      retryCount: message.retryCount + 1,
    );
    await sendMessage(toSend);
  }

  @override
  Future<List<MeshMessage>> getMessagesForPeer(String peerId) async {
    return _storage.getMessages(peerId);
  }

  @override
  Future<void> flushPendingMessages(String peerId) async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final pending = await _storage.getPendingMessages(peerId);
      for (final msg in pending) {
        await retryMessage(msg);
      }
    } finally {
      _isFlushing = false;
    }
  }

  void _handleDiscoveryEvent(DeviceDiscoveryEvent event) async {
    if (event is ConnectionEvent) {
      if (event.type == 'connected') {
        await flushPendingMessages(event.deviceId);
      }
      return;
    }

    if (event is! MessageReceivedEvent) return;

    try {
      final data = jsonDecode(event.payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'message') {
        final messageId = data['messageId'] as String;
        final senderId = data['senderId'] as String;
        final receiverId = data['receiverId'] as String;
        final text = (data['text'] as String? ?? '').trim();
        final timestamp =
            DateTime.tryParse(data['timestamp'] as String? ?? '') ??
            DateTime.now();

        // Enforce maximum size limit on incoming text
        if (text.length > MeshMessage.maxMessageLength) {
          return;
        }

        final conversationId = senderId; // Conversation for receiver is sender ID

        // Duplicate protection
        if (await _storage.hasMessage(messageId)) {
          // Message already stored locally, but reply with ACK frame in case previous ACK was lost
          final ackPayload = MeshMessage.createAckPayload(
            messageId: messageId,
            conversationId: conversationId,
            senderId: _currentLocalId,
            receiverId: senderId,
          );
          await _service.sendMessage(senderId, ackPayload);
          return;
        }

        final receivedMessage = MeshMessage(
          id: messageId,
          conversationId: conversationId,
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
          conversationId: conversationId,
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
