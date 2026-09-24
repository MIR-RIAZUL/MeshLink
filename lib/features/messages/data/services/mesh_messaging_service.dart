import 'dart:async';

import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';

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
    MeshRouter? router,
  })  : _service = discoveryService,
        _storage = storageService,
        _currentLocalId = localId,
        _router = router ??
            MeshRouter(
              discoveryService: discoveryService,
              localId: localId,
            ) {
    _subscription = _service.events.listen(_handleDiscoveryEvent);
  }

  final DeviceDiscoveryService _service;
  final MessageStorageService _storage;
  final MeshRouter _router;
  String _currentLocalId;
  bool _isFlushing = false;

  String get localId => _currentLocalId;
  MeshRouter get router => _router;

  void setLocalId(String id) {
    _currentLocalId = id;
    _router.setLocalId(id);
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

    // 2. Transmit via MeshRouter (direct or multi-hop relay)
    final sent = await _router.routeMessage(sendingMsg);

    if (sent) {
      // Sent over wire, waiting for ACK to mark delivered
      final sentMsg = message.copyWith(status: MessageStatus.sent);
      await _storage.updateMessageStatus(message.id, MessageStatus.sent);
      _incomingController.add(sentMsg);
      return true;
    } else {
      // Failed to deliver frame (offline or no path available)
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
  Future<void> flushPendingMessages([String? peerId]) async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final pending = await _storage.getAllPendingMessages();
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
      final result = await _router.handleIncomingPayload(
        event.payload,
        fromPeerId: event.peerId,
      );

      switch (result) {
        case LocalMessageDelivery(:final message):
          await _storage.saveMessage(message);
          _incomingController.add(message);
        case LocalAckDelivery(:final messageId):
          await _storage.updateMessageStatus(
            messageId,
            MessageStatus.delivered,
          );
          _ackController.add(messageId);
        case RelayedMessage():
        case RelayedAck():
        case DroppedPayload():
          // Relayed/dropped appropriately by MeshRouter
          break;
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
    await _router.dispose();
  }
}
