import 'dart:async';

import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';

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
    MeshCryptoService? cryptoService,
  })  : _service = discoveryService,
        _storage = storageService,
        _currentLocalId = localId,
        _crypto = cryptoService ?? MeshCryptoService(),
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
  final MeshCryptoService _crypto;
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

    // 2. Transmit only an authenticated encrypted wire packet.
    final sent = await _sendEncrypted(sendingMsg);

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
        case EncryptedMessageDelivery(:final payload):
          await _deliverEncryptedMessage(payload);
        case LocalKeyExchangeDelivery(:final payload):
          await _handleKeyExchange(payload);
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

  Future<bool> _sendEncrypted(MeshMessage message) async {
    if (!_crypto.hasPeerKey(message.destinationId)) {
      await _requestPeerKey(message.destinationId, message.id);
      return false;
    }
    try {
      final encrypted = await _crypto.encrypt(
        messageId: message.id,
        originId: message.originId,
        destinationId: message.destinationId,
        text: message.text,
      );
      return await _router.routeEncryptedPayload({
        'type': 'encrypted_message',
        'version': MeshCryptoService.protocolVersion,
        'messageId': message.id,
        'originId': message.originId,
        'destinationId': message.destinationId,
        'senderId': message.senderId,
        'receiverId': message.receiverId,
        'conversationId': message.conversationId,
        'timestamp': message.timestamp.toIso8601String(),
        'ttl': message.ttl,
        'hopCount': message.hopCount,
        'nonce': encrypted.nonce,
        'ciphertext': encrypted.ciphertext,
        'mac': encrypted.mac,
      });
    } on MeshCryptoException {
      return false;
    }
  }

  Future<void> _requestPeerKey(String destinationId, String requestId) async {
    try {
      await _router.routeEncryptedPayload({
        'type': 'key_request',
        'version': MeshCryptoService.protocolVersion,
        'requestId': requestId,
        'originId': _currentLocalId,
        'destinationId': destinationId,
        'ttl': MeshMessage.defaultTtl,
        'hopCount': 0,
        'publicKey': await _crypto.localPublicKey(),
      });
    } catch (_) {
      // The message remains queued and will retry after a connection event.
    }
  }

  Future<void> _handleKeyExchange(Map<String, dynamic> payload) async {
    final type = payload['type'] as String;
    final origin = payload['originId'] as String;
    final publicKey = payload['publicKey'] as String;
    try {
      _crypto.rememberPeerKey(origin, publicKey);
      if (type == 'key_request') {
        await _router.routeEncryptedPayload({
          'type': 'key_response',
          'version': MeshCryptoService.protocolVersion,
          'requestId': payload['requestId'],
          'originId': _currentLocalId,
          'destinationId': origin,
          'ttl': MeshMessage.defaultTtl,
          'hopCount': 0,
          'publicKey': await _crypto.localPublicKey(),
        });
      } else {
        await flushPendingMessages();
      }
    } catch (_) {
      // Invalid key packets are ignored without exposing crypto details.
    }
  }

  Future<void> _deliverEncryptedMessage(Map<String, dynamic> payload) async {
    try {
      final text = await _crypto.decrypt(
        messageId: payload['messageId'] as String,
        originId: payload['originId'] as String,
        destinationId: payload['destinationId'] as String,
        nonce: payload['nonce'] as String,
        ciphertext: payload['ciphertext'] as String,
        mac: payload['mac'] as String,
      );
      if (text.length > MeshMessage.maxMessageLength) return;
      final message = MeshMessage(
        id: payload['messageId'] as String,
        conversationId: payload['originId'] as String,
        senderId: payload['senderId'] as String? ?? payload['originId'] as String,
        receiverId: payload['receiverId'] as String? ?? _currentLocalId,
        originId: payload['originId'] as String,
        destinationId: payload['destinationId'] as String,
        text: text,
        timestamp: DateTime.tryParse(payload['timestamp'] as String? ?? '') ?? DateTime.now(),
        status: MessageStatus.delivered,
        ttl: payload['ttl'] as int? ?? MeshMessage.defaultTtl,
        hopCount: payload['hopCount'] as int? ?? 0,
      );
      await _storage.saveMessage(message);
      _incomingController.add(message);
    } on MeshCryptoException {
      // Authentication failures are rejected; no plaintext is delivered.
    } catch (_) {
      // Malformed encrypted payload.
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
