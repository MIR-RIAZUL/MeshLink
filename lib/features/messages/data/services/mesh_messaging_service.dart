import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MeshFileTransferProgress {
  const MeshFileTransferProgress({
    required this.transferId,
    required this.fileName,
    required this.status,
    required this.progress,
  });

  final String transferId;
  final String fileName;
  final String status;
  final double progress;
}

abstract class MeshMessagingService {
  Stream<MeshMessage> get incomingMessages;
  Stream<String> get ackReceived;
  Stream<MeshFileTransferProgress> get fileTransferProgress;

  Future<bool> sendMessage(MeshMessage message);
  Future<void> sendFile(String peerId, File file);
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
  final Map<String, Map<String, dynamic>> _incomingTransfers = {};

  final StreamController<MeshFileTransferProgress> _fileTransferProgressController =
      StreamController<MeshFileTransferProgress>.broadcast();

  String get localId => _currentLocalId;
  MeshRouter get router => _router;

  @override
  Stream<MeshFileTransferProgress> get fileTransferProgress =>
      _fileTransferProgressController.stream;

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
        case FileTransferDelivery(:final payload):
          await _handleFileTransferPacket(payload);
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
  Future<void> sendFile(String peerId, File file) async {
    final fileName = file.uri.pathSegments.isEmpty ? 'meshlink-transfer.bin' : file.uri.pathSegments.last;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    final transferId = 'FT-${DateTime.now().millisecondsSinceEpoch}';
    final chunkSize = 32 * 1024;
    final totalChunks = (bytes.length / chunkSize).ceil();
    final safeTotal = totalChunks <= 0 ? 1 : totalChunks;
    final startPayload = {
      'type': 'file_start',
      'version': 1,
      'messageId': '$transferId-start',
      'transferId': transferId,
      'originId': _currentLocalId,
      'destinationId': peerId,
      'ttl': MeshMessage.defaultTtl,
      'hopCount': 0,
      'fileName': fileName,
      'fileSize': bytes.length,
      'totalChunks': safeTotal,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _router.routeEncryptedPayload(startPayload);

    for (var chunkIndex = 0; chunkIndex < safeTotal; chunkIndex++) {
      final start = chunkIndex * chunkSize;
      final end = (chunkIndex + 1) * chunkSize;
      final chunk = bytes.sublist(start, end > bytes.length ? bytes.length : end);
      final encrypted = await _crypto.encrypt(
        messageId: '$transferId-chunk-$chunkIndex',
        originId: _currentLocalId,
        destinationId: peerId,
        text: base64Encode(chunk),
      );

      await _router.routeEncryptedPayload({
        'type': 'file_chunk',
        'version': 1,
        'messageId': '$transferId-chunk-$chunkIndex',
        'transferId': transferId,
        'originId': _currentLocalId,
        'destinationId': peerId,
        'senderId': _currentLocalId,
        'receiverId': peerId,
        'ttl': MeshMessage.defaultTtl,
        'hopCount': 0,
        'fileName': fileName,
        'fileSize': bytes.length,
        'totalChunks': safeTotal,
        'chunkIndex': chunkIndex,
        'nonce': encrypted.nonce,
        'ciphertext': encrypted.ciphertext,
        'mac': encrypted.mac,
      });

      _fileTransferProgressController.add(MeshFileTransferProgress(
        transferId: transferId,
        fileName: fileName,
        status: 'sending',
        progress: (chunkIndex + 1) / safeTotal,
      ));
    }

    final endPayload = {
      'type': 'file_end',
      'version': 1,
      'messageId': '$transferId-end',
      'transferId': transferId,
      'originId': _currentLocalId,
      'destinationId': peerId,
      'ttl': MeshMessage.defaultTtl,
      'hopCount': 0,
      'fileName': fileName,
      'fileSize': bytes.length,
      'totalChunks': safeTotal,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _router.routeEncryptedPayload(endPayload);
    _fileTransferProgressController.add(MeshFileTransferProgress(
      transferId: transferId,
      fileName: fileName,
      status: 'complete',
      progress: 1.0,
    ));
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

  Future<void> _handleFileTransferPacket(Map<String, dynamic> payload) async {
    final type = payload['type'] as String?;
    final transferId = payload['transferId'] as String?;
    if (type == null || transferId == null) return;

    switch (type) {
      case 'file_start':
        final fileName = payload['fileName'] as String? ?? 'meshlink-transfer.bin';
        final totalChunks = (payload['totalChunks'] as int?) ?? 0;
        _incomingTransfers[transferId] = {
          'fileName': fileName,
          'totalChunks': totalChunks,
          'chunks': <int, List<int>>{},
          'fileSize': payload['fileSize'] as int? ?? 0,
          'originId': payload['originId'] as String? ?? '',
        };
        _fileTransferProgressController.add(MeshFileTransferProgress(
          transferId: transferId,
          fileName: fileName,
          status: 'receiving',
          progress: 0.0,
        ));
        break;
      case 'file_chunk':
        final originId = payload['originId'] as String? ?? '';
        final transfer = _incomingTransfers.putIfAbsent(transferId, () => {
          'fileName': payload['fileName'] as String? ?? 'meshlink-transfer.bin',
          'totalChunks': payload['totalChunks'] as int? ?? 1,
          'chunks': <int, List<int>>{},
          'fileSize': payload['fileSize'] as int? ?? 0,
          'originId': originId,
        });
        try {
          final decrypted = await _crypto.decrypt(
            messageId: payload['messageId'] as String,
            originId: originId,
            destinationId: _currentLocalId,
            nonce: payload['nonce'] as String,
            ciphertext: payload['ciphertext'] as String,
            mac: payload['mac'] as String,
          );
          final chunkIndex = (payload['chunkIndex'] as int?) ?? 0;
          final fileChunks = (transfer['chunks'] as Map<int, List<int>>?) ?? <int, List<int>>{};
          transfer['chunks'] = fileChunks;
          fileChunks[chunkIndex] = base64Decode(decrypted);
          final totalChunks = (transfer['totalChunks'] as int?) ?? 1;
          final received = fileChunks.length;
          final progressValue = totalChunks == 0 ? 0.0 : (received / totalChunks).clamp(0.0, 1.0);
          _fileTransferProgressController.add(MeshFileTransferProgress(
            transferId: transferId,
            fileName: transfer['fileName'] as String? ?? 'meshlink-transfer.bin',
            status: 'receiving',
            progress: progressValue,
          ));
          if (received >= totalChunks && totalChunks > 0) {
            await _finalizeIncomingTransfer(transferId);
          }
        } on MeshCryptoException {
          // Ignore tampered or wrong-key chunks.
        }
        break;
      case 'file_end':
        await _finalizeIncomingTransfer(transferId);
        break;
      case 'file_ack':
      case 'file_error':
        break;
    }
  }

  Future<void> _finalizeIncomingTransfer(String transferId) async {
    final transfer = _incomingTransfers[transferId];
    if (transfer == null) return;

    final chunks = (transfer['chunks'] as Map<int, List<int>>?) ?? <int, List<int>>{};
    final totalChunks = (transfer['totalChunks'] as int?) ?? chunks.length;
    if (totalChunks <= 0 || chunks.length < totalChunks) {
      _fileTransferProgressController.add(MeshFileTransferProgress(
        transferId: transferId,
        fileName: transfer['fileName'] as String? ?? 'meshlink-transfer.bin',
        status: 'failed',
        progress: 0.0,
      ));
      _incomingTransfers.remove(transferId);
      return;
    }

    final assembled = <int>[];
    for (var idx = 0; idx < totalChunks; idx++) {
      final chunk = chunks[idx];
      if (chunk == null) {
        _fileTransferProgressController.add(MeshFileTransferProgress(
          transferId: transferId,
          fileName: transfer['fileName'] as String? ?? 'meshlink-transfer.bin',
          status: 'failed',
          progress: 0.0,
        ));
        _incomingTransfers.remove(transferId);
        return;
      }
      assembled.addAll(chunk);
    }

    final downloadDir = await getDownloadsDirectory() ?? Directory.systemTemp;
    final originalName = transfer['fileName'] as String? ?? 'meshlink-transfer.bin';
    final baseName = p.basenameWithoutExtension(originalName);
    final extension = p.extension(originalName);
    var candidate = File(p.join(downloadDir.path, originalName));
    var counter = 1;
    while (await candidate.exists()) {
      candidate = File(p.join(downloadDir.path, '$baseName($counter)$extension'));
      counter++;
    }
    await candidate.writeAsBytes(assembled, flush: true);
    _fileTransferProgressController.add(MeshFileTransferProgress(
      transferId: transferId,
      fileName: originalName,
      status: 'complete',
      progress: 1.0,
    ));
    _incomingTransfers.remove(transferId);
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
    await _fileTransferProgressController.close();
    await _router.dispose();
  }
}
