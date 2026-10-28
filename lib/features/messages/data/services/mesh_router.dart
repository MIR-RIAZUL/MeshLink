import 'dart:async';
import 'dart:convert';

import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/chunk_ack_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';

export 'package:meshlink/features/messages/data/models/encrypted_chunk_ack_envelope.dart';
export 'package:meshlink/features/messages/data/models/encrypted_file_chunk_envelope.dart';

sealed class RoutedPayloadResult {
  const RoutedPayloadResult();
}

class LocalMessageDelivery extends RoutedPayloadResult {
  const LocalMessageDelivery(this.message);
  final MeshMessage message;
}

class LocalAckDelivery extends RoutedPayloadResult {
  const LocalAckDelivery(this.messageId);
  final String messageId;
}

class EncryptedMessageDelivery extends RoutedPayloadResult {
  const EncryptedMessageDelivery(this.payload);
  final Map<String, dynamic> payload;
}

class LocalKeyExchangeDelivery extends RoutedPayloadResult {
  const LocalKeyExchangeDelivery(this.payload);
  final Map<String, dynamic> payload;
}

@Deprecated('Legacy v1 file transfer delivery. Superseded by LocalFileChunkDelivery and LocalFileChunkAckDelivery in Phase 8.')
class FileTransferDelivery extends RoutedPayloadResult {
  const FileTransferDelivery(this.payload);
  final Map<String, dynamic> payload;
}

class LocalFileChunkDelivery extends RoutedPayloadResult {
  const LocalFileChunkDelivery({
    required this.envelope,
    required this.payload,
  });
  final EncryptedFileChunkEnvelope envelope;
  final Map<String, dynamic> payload;
}

class LocalFileChunkAckDelivery extends RoutedPayloadResult {
  const LocalFileChunkAckDelivery({
    required this.envelope,
    required this.payload,
  });
  final EncryptedChunkAckEnvelope envelope;
  final Map<String, dynamic> payload;
}

class RelayedMessage extends RoutedPayloadResult {
  const RelayedMessage({
    required this.messageId,
    required this.destinationId,
    required this.newTtl,
    required this.newHopCount,
    required this.forwardedCount,
  });
  final String messageId;
  final String destinationId;
  final int newTtl;
  final int newHopCount;
  final int forwardedCount;
}

class RelayedAck extends RoutedPayloadResult {
  const RelayedAck({
    required this.messageId,
    required this.destinationId,
    required this.newTtl,
    required this.newHopCount,
    required this.forwardedCount,
  });
  final String messageId;
  final String destinationId;
  final int newTtl;
  final int newHopCount;
  final int forwardedCount;
}

class RelayedFileChunk extends RoutedPayloadResult {
  const RelayedFileChunk({
    required this.transferId,
    required this.chunkIndex,
    required this.destinationId,
    required this.newTtl,
    required this.newHopCount,
    required this.forwardedCount,
  });
  final String transferId;
  final int chunkIndex;
  final String destinationId;
  final int newTtl;
  final int newHopCount;
  final int forwardedCount;
}

class RelayedFileAck extends RoutedPayloadResult {
  const RelayedFileAck({
    required this.transferId,
    required this.chunkIndex,
    required this.destinationId,
    required this.newTtl,
    required this.newHopCount,
    required this.forwardedCount,
  });
  final String transferId;
  final int chunkIndex;
  final String destinationId;
  final int newTtl;
  final int newHopCount;
  final int forwardedCount;
}

class DroppedPayload extends RoutedPayloadResult {
  const DroppedPayload(this.reason);
  final String reason;
}

/// MeshRouter handles multi-hop packet routing, loop prevention, TTL decrement,
/// and neighbor store-and-forward routing.
class MeshRouter {
  MeshRouter({
    required DeviceDiscoveryService discoveryService,
    required String localId,
    Set<String> Function()? getConnectedPeers,
    ReplayProtectionService? replayProtectionService,
  })  : _service = discoveryService,
        _currentLocalId = localId,
        // ignore: prefer_initializing_formals
        _getConnectedPeers = getConnectedPeers,
        _replayProtection = replayProtectionService,
        _subscription = null {
    _subscription = _service.events.listen(_onDiscoveryEvent);
  }

  final DeviceDiscoveryService _service;
  String _currentLocalId;
  final Set<String> Function()? _getConnectedPeers;
  final ReplayProtectionService? _replayProtection;
  final Set<String> _connectedPeers = {};
  final Set<String> _processedMessageIds = {};
  final Set<String> _processedAckIds = {};
  StreamSubscription<DeviceDiscoveryEvent>? _subscription;

  static const int _maxCacheSize = 1000;

  /// Maximum allowed wire payload length for raw packet strings (512 KB).
  static const int maxWirePayloadLength = 512 * 1024;

  /// Maximum allowed hop limit to prevent persistent forwarding loops.
  static const int maxHopCount = 32;

  /// Maximum allowed TTL.
  static const int maxTtl = 64;

  /// Canonical wire packet type for Phase 8 encrypted file chunks.
  static const String fileChunkPacketType = 'file_chunk';

  /// Canonical wire packet type for Phase 8 encrypted chunk acknowledgments.
  static const String fileAckPacketType = 'file_ack';

  /// Maximum allowed individual chunk ciphertext length (128 KB).
  static const int maxChunkLength = 128 * 1024;

  final StreamController<LocalFileChunkDelivery> _fileChunkDeliveryController =
      StreamController<LocalFileChunkDelivery>.broadcast();
  final StreamController<LocalFileChunkAckDelivery> _fileAckDeliveryController =
      StreamController<LocalFileChunkAckDelivery>.broadcast();

  /// Stream of file chunk envelopes successfully delivered to this local destination.
  Stream<LocalFileChunkDelivery> get onFileChunkDelivery =>
      _fileChunkDeliveryController.stream;

  /// Stream of file chunk ACK/NACK envelopes successfully delivered to this local destination.
  Stream<LocalFileChunkAckDelivery> get onFileAckDelivery =>
      _fileAckDeliveryController.stream;

  String get localId => _currentLocalId;

  void setLocalId(String id) {
    _currentLocalId = id;
  }

  Set<String> get connectedPeers {
    if (_getConnectedPeers != null) {
      return {..._connectedPeers, ..._getConnectedPeers()};
    }
    return Set.unmodifiable(_connectedPeers);
  }

  void _onDiscoveryEvent(DeviceDiscoveryEvent event) {
    if (event is ConnectionEvent) {
      if (event.type == 'connected') {
        _connectedPeers.add(event.deviceId);
      } else if (event.type == 'disconnected') {
        _connectedPeers.remove(event.deviceId);
      }
    }
  }

  /// Plaintext message routing is intentionally disabled.
  /// All active outbound traffic must use encrypted packets via
  /// routeEncryptedPayload() and the encrypted_message protocol.
  Future<bool> routeMessage(MeshMessage message) async {
    throw UnsupportedError(
      'Plaintext message routing is disabled. Use routeEncryptedPayload() with encrypted_message packets.',
    );
  }

  /// Sends an already encrypted end-to-end packet without inspecting its body.
  Future<bool> routeEncryptedPayload(Map<String, dynamic> payload) =>
      _routePayload(
        payload,
        destinationId: payload['destinationId'] as String,
        originId: payload['originId'] as String,
      );

  /// Routes a Phase 8 encrypted file chunk envelope across the mesh network.
  ///
  /// Packages [envelope] into an authenticated wire frame preserving all immutable
  /// end-to-end cryptographic fields, setting the initial TTL and hopCount.
  Future<bool> routeFileChunk(
    EncryptedFileChunkEnvelope envelope, {
    int? ttl,
  }) async {
    final payload = {
      'type': 'file_chunk',
      'version': EncryptedFileChunkEnvelope.currentProtocolVersion,
      'messageId': '${envelope.transferId}:${envelope.chunkIndex}',
      'transferId': envelope.transferId,
      'chunkIndex': envelope.chunkIndex,
      'originId': envelope.originId,
      'destinationId': envelope.destinationId,
      'ttl': ttl ?? MeshMessage.defaultTtl,
      'hopCount': 0,
      'timestamp': DateTime.now().toIso8601String(),
      ...envelope.toMap(),
    };
    return _routePayload(
      payload,
      destinationId: envelope.destinationId,
      originId: envelope.originId,
    );
  }

  /// Routes a Phase 8 encrypted chunk acknowledgment (ACK/NACK) envelope across the mesh network.
  Future<bool> routeFileAck(
    EncryptedChunkAckEnvelope envelope, {
    int? ttl,
  }) async {
    final payload = {
      'type': 'file_ack',
      'version': EncryptedChunkAckEnvelope.currentProtocolVersion,
      'messageId': 'ack:${envelope.transferId}:${envelope.chunkIndex}',
      'transferId': envelope.transferId,
      'chunkIndex': envelope.chunkIndex,
      'originId': envelope.originId,
      'destinationId': envelope.destinationId,
      'ttl': ttl ?? MeshMessage.defaultTtl,
      'hopCount': 0,
      'timestamp': envelope.createdAt.toIso8601String(),
      ...envelope.toMap(),
    };
    return _routePayload(
      payload,
      destinationId: envelope.destinationId,
      originId: envelope.originId,
    );
  }

  Future<bool> _routePayload(
    Map<String, dynamic> payload, {
    required String destinationId,
    required String originId,
  }) async {
    final encoded = jsonEncode(payload);
    if (connectedPeers.contains(destinationId)) {
      if (await _service.sendMessage(destinationId, encoded)) return true;
    }
    var anySent = false;
    for (final peerId in connectedPeers) {
      if (peerId != originId && peerId != _currentLocalId && peerId != destinationId) {
        if (await _service.sendMessage(peerId, encoded)) anySent = true;
      }
    }
    return anySent;
  }

  /// Process an incoming raw wire payload frame (message or ack).
  Future<RoutedPayloadResult> handleIncomingPayload(
    String payload, {
    String? fromPeerId,
  }) async {
    if (payload.length > maxWirePayloadLength) {
      return const DroppedPayload('Payload size limit exceeded');
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'message') {
        return await _handleIncomingMessage(data, fromPeerId);
      } else if (type == 'encrypted_message') {
        return await _handleIncomingEncryptedMessage(data, fromPeerId);
      } else if (type == 'key_request' || type == 'key_response') {
        return await _handleKeyExchange(data, fromPeerId);
      } else if (type == 'file_chunk') {
        if (data['version'] == EncryptedFileChunkEnvelope.currentProtocolVersion) {
          return await _handleIncomingEncryptedFileChunk(data, fromPeerId);
        }
        return await _handleIncomingFileTransfer(data, fromPeerId);
      } else if (type == 'file_ack' || type == 'file_chunk_ack') {
        if (data['version'] == EncryptedChunkAckEnvelope.currentProtocolVersion) {
          return await _handleIncomingEncryptedChunkAck(data, fromPeerId);
        }
        return await _handleIncomingFileTransfer(data, fromPeerId);
      } else if (type == 'file_start' ||
          type == 'file_end' ||
          type == 'file_error') {
        return await _handleIncomingFileTransfer(data, fromPeerId);
      } else if (type == 'ack') {
        return await _handleIncomingAck(data, fromPeerId);
      }
      return const DroppedPayload('Unknown packet type');
    } catch (e) {
      return DroppedPayload('Malformed payload: $e');
    }
  }

  Future<RoutedPayloadResult> _handleIncomingEncryptedMessage(
    Map<String, dynamic> data,
    String? fromPeerId,
  ) async {
    final messageId = data['messageId'] as String?;
    final originId = data['originId'] as String?;
    final destinationId = data['destinationId'] as String?;
    final ttl = data['ttl'] as int?;
    final hopCount = data['hopCount'] as int? ?? 0;
    if (messageId == null || originId == null || destinationId == null || ttl == null ||
        data['version'] != 1 || data['nonce'] is! String || data['ciphertext'] is! String || data['mac'] is! String) {
      return const DroppedPayload('Invalid encrypted packet');
    }

    if (ttl <= 0) {
      return const DroppedPayload('TTL expired');
    }
    if (ttl > maxTtl) {
      return const DroppedPayload('Invalid TTL: exceeds maximum allowed TTL');
    }
    if (hopCount < 0) {
      return const DroppedPayload('Invalid hopCount');
    }
    if (hopCount >= maxHopCount) {
      return const DroppedPayload('Hop limit exceeded');
    }

    // Routing loop detection
    if (fromPeerId != null && fromPeerId == destinationId) {
      return const DroppedPayload('Routing loop detected: received from packet destination');
    }
    if (originId == _currentLocalId) {
      return const DroppedPayload('Routing loop: packet originated locally');
    }
    if (originId == destinationId) {
      return const DroppedPayload('Destination echo: originId matches destinationId');
    }
    if (originId == destinationId) {
      return const DroppedPayload('Destination echo: originId matches destinationId');
    }

    final timestampStr = data['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? (DateTime.tryParse(timestampStr) ?? DateTime.now())
        : DateTime.now();

    if (_replayProtection != null) {
      if (destinationId != _currentLocalId) {
        // Relaying node: check and mark as seen so duplicate is not forwarded
        final outcome = await _replayProtection.checkAndMarkSeen(
          packetType: 'encrypted_message',
          originId: originId,
          packetId: messageId,
          timestamp: timestamp,
        );
        if (!outcome.isAccepted) {
          return const DroppedPayload('Duplicate or invalid replay packet');
        }
      } else {
        // Local destination: pre-check if already recorded
        final isDuplicate = await _replayProtection.isSeen(
          packetType: 'encrypted_message',
          originId: originId,
          packetId: messageId,
        );
        if (isDuplicate) {
          return const DroppedPayload('Duplicate message');
        }
      }
    } else {
      if (_processedMessageIds.contains(messageId)) {
        return const DroppedPayload('Duplicate message');
      }
      _addToProcessed(messageId, _processedMessageIds);
    }

    if (destinationId == _currentLocalId) {
      await _sendAck(
        messageId: messageId,
        destinationId: originId,
        conversationId: data['conversationId'] as String? ?? originId,
        fromPeerId: fromPeerId,
      );
      return EncryptedMessageDelivery(data);
    }
    return _relayPayload(data, messageId, originId, destinationId, ttl, hopCount, fromPeerId);
  }

  Future<RoutedPayloadResult> _handleKeyExchange(
    Map<String, dynamic> data,
    String? fromPeerId,
  ) async {
    final requestId = data['requestId'] as String?;
    final originId = data['originId'] as String?;
    final destinationId = data['destinationId'] as String?;
    final ttl = data['ttl'] as int?;
    final hopCount = data['hopCount'] as int? ?? 0;
    if (requestId == null || originId == null || destinationId == null || ttl == null ||
        data['version'] != 1 || data['publicKey'] is! String) {
      return const DroppedPayload('Invalid key exchange packet');
    }

    if (ttl <= 0) {
      return const DroppedPayload('TTL expired');
    }
    if (ttl > maxTtl) {
      return const DroppedPayload('Invalid TTL: exceeds maximum allowed TTL');
    }
    if (hopCount < 0) {
      return const DroppedPayload('Invalid hopCount');
    }
    if (hopCount >= maxHopCount) {
      return const DroppedPayload('Hop limit exceeded');
    }

    // Routing loop detection
    if (fromPeerId != null && fromPeerId == destinationId) {
      return const DroppedPayload('Routing loop detected: received from packet destination');
    }
    if (originId == _currentLocalId) {
      return const DroppedPayload('Routing loop: packet originated locally');
    }
    if (originId == destinationId) {
      return const DroppedPayload('Destination echo: originId matches destinationId');
    }
    final cacheKey = 'key:$requestId:${data['type']}';
    if (_processedMessageIds.contains(cacheKey)) return const DroppedPayload('Duplicate key exchange packet');
    _addToProcessed(cacheKey, _processedMessageIds);
    if (destinationId == _currentLocalId) return LocalKeyExchangeDelivery(data);
    return _relayPayload(data, requestId, originId, destinationId, ttl, hopCount, fromPeerId);
  }

  Future<RoutedPayloadResult> _handleIncomingFileTransfer(
    Map<String, dynamic> data,
    String? fromPeerId,
  ) async {
    final type = data['type'] as String?;
    final transferId = data['transferId'] as String?;
    final messageId = data['messageId'] as String?;
    final originId = data['originId'] as String?;
    final destinationId = data['destinationId'] as String?;
    final ttl = data['ttl'] as int?;
    final hopCount = data['hopCount'] as int? ?? 0;
    if (type == null ||
        transferId == null ||
        messageId == null ||
        originId == null ||
        destinationId == null ||
        ttl == null ||
        data['version'] != 1) {
      return const DroppedPayload('Invalid file transfer packet');
    }
    if (_processedMessageIds.contains(messageId)) {
      return const DroppedPayload('Duplicate file transfer packet');
    }
    _addToProcessed(messageId, _processedMessageIds);
    if (destinationId == _currentLocalId) {
      return FileTransferDelivery(data);
    }
    return _relayPayload(data, messageId, originId, destinationId, ttl, hopCount, fromPeerId);
  }

  Future<RoutedPayloadResult> _relayPayload(
    Map<String, dynamic> data,
    String messageId,
    String originId,
    String destinationId,
    int ttl,
    int hopCount,
    String? fromPeerId,
  ) async {
    final newTtl = ttl - 1;
    final newHopCount = hopCount + 1;
    if (newTtl <= 0) return const DroppedPayload('TTL expired');
    final forwarded = jsonEncode({...data, 'ttl': newTtl, 'hopCount': newHopCount});
    var forwardedCount = 0;
    if (connectedPeers.contains(destinationId)) {
      if (await _service.sendMessage(destinationId, forwarded)) forwardedCount++;
    } else {
      for (final peerId in connectedPeers) {
        if (peerId != fromPeerId && peerId != originId && peerId != _currentLocalId) {
          if (await _service.sendMessage(peerId, forwarded)) forwardedCount++;
        }
      }
    }
    return RelayedMessage(messageId: messageId, destinationId: destinationId, newTtl: newTtl, newHopCount: newHopCount, forwardedCount: forwardedCount);
  }

  Future<RoutedPayloadResult> _handleIncomingMessage(
    Map<String, dynamic> data,
    String? fromPeerId,
  ) async {
    final messageId = data['messageId'] as String;
    final senderId = (data['senderId'] as String?) ?? (data['originId'] as String? ?? '');
    final receiverId = (data['receiverId'] as String?) ?? (data['destinationId'] as String? ?? '');
    final originId = (data['originId'] as String?) ?? senderId;
    final destinationId = (data['destinationId'] as String?) ?? receiverId;
    final text = (data['text'] as String? ?? '').trim();
    final ttl = (data['ttl'] as int?) ?? MeshMessage.defaultTtl;
    final hopCount = (data['hopCount'] as int?) ?? 0;

    if (text.length > MeshMessage.maxMessageLength) {
      return const DroppedPayload('Message size limit exceeded');
    }

    // 1. Loop & Duplicate Detection
    if (_processedMessageIds.contains(messageId)) {
      if (destinationId == _currentLocalId) {
        // Re-send ACK in case previous ACK was lost on the wire
        await _sendAck(
          messageId: messageId,
          destinationId: originId,
          conversationId: originId,
          fromPeerId: fromPeerId,
        );
      }
      return const DroppedPayload('Duplicate message');
    }
    _addToProcessed(messageId, _processedMessageIds);

    // 2. Is this node the final destination?
    if (destinationId == _currentLocalId) {
      final msg = MeshMessage(
        id: messageId,
        conversationId: originId,
        senderId: senderId,
        receiverId: receiverId,
        originId: originId,
        destinationId: destinationId,
        text: text,
        timestamp: DateTime.tryParse(data['timestamp'] as String? ?? '') ??
            DateTime.now(),
        status: MessageStatus.delivered,
        ttl: ttl,
        hopCount: hopCount,
      );

      // Send ACK back towards origin
      await _sendAck(
        messageId: messageId,
        destinationId: originId,
        conversationId: originId,
        fromPeerId: fromPeerId,
      );

      return LocalMessageDelivery(msg);
    }

    // 3. Multi-Hop Forwarding (Relay Node)
    final newTtl = ttl - 1;
    final newHopCount = hopCount + 1;

    if (newTtl <= 0) {
      return const DroppedPayload('TTL expired');
    }

    final forwardedPayload = jsonEncode({
      ...data,
      'ttl': newTtl,
      'hopCount': newHopCount,
    });

    int forwardedCount = 0;

    // Check if destination is directly connected to this relay node
    if (connectedPeers.contains(destinationId)) {
      final sent = await _service.sendMessage(destinationId, forwardedPayload);
      if (sent) forwardedCount++;
    } else {
      // Forward to other connected peers (excluding origin, previous hop, and self)
      for (final peerId in connectedPeers) {
        if (peerId != fromPeerId &&
            peerId != originId &&
            peerId != _currentLocalId) {
          final sent = await _service.sendMessage(peerId, forwardedPayload);
          if (sent) forwardedCount++;
        }
      }
    }

    return RelayedMessage(
      messageId: messageId,
      destinationId: destinationId,
      newTtl: newTtl,
      newHopCount: newHopCount,
      forwardedCount: forwardedCount,
    );
  }

  Future<RoutedPayloadResult> _handleIncomingAck(
    Map<String, dynamic> data,
    String? fromPeerId,
  ) async {
    final messageId = data['messageId'] as String;
    final senderId = (data['senderId'] as String?) ?? (data['originId'] as String? ?? '');
    final receiverId = (data['receiverId'] as String?) ?? (data['destinationId'] as String? ?? '');
    final originId = (data['originId'] as String?) ?? senderId;
    final destinationId = (data['destinationId'] as String?) ?? receiverId;
    final ttl = (data['ttl'] as int?) ?? MeshMessage.defaultTtl;
    final hopCount = (data['hopCount'] as int?) ?? 0;

    if (ttl <= 0) {
      return const DroppedPayload('ACK TTL expired');
    }
    if (ttl > maxTtl) {
      return const DroppedPayload('Invalid TTL: exceeds maximum allowed TTL');
    }
    if (hopCount < 0) {
      return const DroppedPayload('Invalid hopCount');
    }
    if (hopCount >= maxHopCount) {
      return const DroppedPayload('Hop limit exceeded');
    }

    // Routing loop detection
    if (fromPeerId != null && fromPeerId == destinationId) {
      return const DroppedPayload('Routing loop detected: received from packet destination');
    }
    if (originId == _currentLocalId) {
      return const DroppedPayload('Routing loop: ACK originated locally');
    }
    if (originId == destinationId) {
      return const DroppedPayload('Destination echo: originId matches destinationId');
    }

    final ackKey = '${messageId}_$originId';
    if (_replayProtection != null) {
      final timestampStr = data['timestamp'] as String?;
      final timestamp = timestampStr != null
          ? (DateTime.tryParse(timestampStr) ?? DateTime.now())
          : DateTime.now();

      final outcome = await _replayProtection.checkAndMarkSeen(
        packetType: 'ack',
        originId: originId,
        packetId: messageId,
        timestamp: timestamp,
      );
      if (!outcome.isAccepted) {
        return const DroppedPayload('Duplicate or invalid ACK');
      }
    } else {
      if (_processedAckIds.contains(ackKey)) {
        return const DroppedPayload('Duplicate ACK');
      }
      _addToProcessed(ackKey, _processedAckIds);
    }

    // Is this ACK destined for this node?
    if (destinationId == _currentLocalId) {
      return LocalAckDelivery(messageId);
    }

    // Relay ACK back towards original sender
    final newTtl = ttl - 1;
    final newHopCount = hopCount + 1;

    if (newTtl <= 0) {
      return const DroppedPayload('ACK TTL expired');
    }

    final forwardedAck = jsonEncode({
      ...data,
      'ttl': newTtl,
      'hopCount': newHopCount,
    });

    int forwardedCount = 0;
    if (connectedPeers.contains(destinationId)) {
      final sent = await _service.sendMessage(destinationId, forwardedAck);
      if (sent) forwardedCount++;
    } else {
      for (final peerId in connectedPeers) {
        if (peerId != fromPeerId &&
            peerId != originId &&
            peerId != _currentLocalId) {
          final sent = await _service.sendMessage(peerId, forwardedAck);
          if (sent) forwardedCount++;
        }
      }
    }

    return RelayedAck(
      messageId: messageId,
      destinationId: destinationId,
      newTtl: newTtl,
      newHopCount: newHopCount,
      forwardedCount: forwardedCount,
    );
  }

  Future<void> _sendAck({
    required String messageId,
    required String destinationId,
    required String conversationId,
    String? fromPeerId,
  }) async {
    final ackPayload = MeshMessage.createAckPayload(
      messageId: messageId,
      conversationId: conversationId,
      senderId: _currentLocalId,
      receiverId: destinationId,
      originId: _currentLocalId,
      destinationId: destinationId,
      ttl: MeshMessage.defaultTtl,
      hopCount: 0,
    );

    if (connectedPeers.isEmpty) {
      await _service.sendMessage(destinationId, ackPayload);
      return;
    }

    // Direct link to origin if available
    if (connectedPeers.contains(destinationId)) {
      await _service.sendMessage(destinationId, ackPayload);
      return;
    }

    // Send back to the relay peer we received from
    if (fromPeerId != null && connectedPeers.contains(fromPeerId)) {
      await _service.sendMessage(fromPeerId, ackPayload);
      return;
    }

    // Fallback: send to all connected peers
    for (final peerId in connectedPeers) {
      if (peerId != _currentLocalId) {
        await _service.sendMessage(peerId, ackPayload);
      }
    }
  }

  Future<RoutedPayloadResult> _handleIncomingEncryptedFileChunk(
    Map<String, dynamic> data,
    String? fromPeerId,
  ) async {
    final destinationId = data['destinationId'] as String?;
    final originId = data['originId'] as String?;
    final ttl = data['ttl'] as int?;
    final hopCount = data['hopCount'] as int? ?? 0;

    if (destinationId == null || originId == null || ttl == null) {
      return const DroppedPayload('Invalid file chunk packet: missing routing metadata');
    }

    if (ttl <= 0) {
      return const DroppedPayload('TTL expired');
    }
    if (ttl > maxTtl) {
      return const DroppedPayload('Invalid TTL: exceeds maximum allowed TTL');
    }
    if (hopCount < 0) {
      return const DroppedPayload('Invalid hopCount');
    }
    if (hopCount >= maxHopCount) {
      return const DroppedPayload('Hop limit exceeded');
    }

    // Routing loop detection
    if (fromPeerId != null && fromPeerId == destinationId) {
      return const DroppedPayload('Routing loop detected: received from packet destination');
    }
    if (originId == _currentLocalId) {
      return const DroppedPayload('Routing loop: packet originated locally');
    }
    if (originId == destinationId) {
      return const DroppedPayload('Destination echo: originId matches destinationId');
    }

    // Parse and validate the immutable EncryptedFileChunkEnvelope
    final Map<String, dynamic> envelopeMap;
    if (data['envelope'] is Map<String, dynamic>) {
      envelopeMap = data['envelope'] as Map<String, dynamic>;
    } else {
      envelopeMap = data;
    }

    final EncryptedFileChunkEnvelope envelope;
    try {
      envelope = EncryptedFileChunkEnvelope.fromMap(envelopeMap);
      envelope.validate();
    } catch (e) {
      return DroppedPayload('Malformed or invalid file chunk envelope: $e');
    }

    if (envelope.chunkLength > maxChunkLength || envelope.ciphertext.length > maxChunkLength) {
      return const DroppedPayload('Chunk payload exceeds maximum allowed chunk length');
    }

    final messageId = (data['messageId'] as String?) ?? '${envelope.transferId}:${envelope.chunkIndex}';
    final timestampStr = data['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? (DateTime.tryParse(timestampStr) ?? DateTime.now())
        : DateTime.now();

    // Replay protection and duplicate suppression
    if (_replayProtection != null) {
      if (destinationId != _currentLocalId) {
        // Relaying node: check and record so duplicates are not forwarded
        final outcome = await _replayProtection.checkAndMarkSeen(
          packetType: 'file_chunk',
          originId: envelope.originId,
          packetId: messageId,
          timestamp: timestamp,
        );
        if (!outcome.isAccepted) {
          return const DroppedPayload('Duplicate or invalid replay packet');
        }
      } else {
        // Local destination: pre-check if already recorded
        final isDuplicate = await _replayProtection.isSeen(
          packetType: 'file_chunk',
          originId: envelope.originId,
          packetId: messageId,
        );
        if (isDuplicate) {
          return const DroppedPayload('Duplicate file chunk');
        }
      }
    } else {
      if (_processedMessageIds.contains(messageId)) {
        return const DroppedPayload('Duplicate file chunk');
      }
      _addToProcessed(messageId, _processedMessageIds);
    }

    if (destinationId == _currentLocalId) {
      final delivery = LocalFileChunkDelivery(envelope: envelope, payload: data);
      _fileChunkDeliveryController.add(delivery);
      return delivery;
    }

    return _relayFileChunk(
      data,
      envelope,
      messageId,
      originId,
      destinationId,
      ttl,
      hopCount,
      fromPeerId,
    );
  }

  Future<RoutedPayloadResult> _relayFileChunk(
    Map<String, dynamic> data,
    EncryptedFileChunkEnvelope envelope,
    String messageId,
    String originId,
    String destinationId,
    int ttl,
    int hopCount,
    String? fromPeerId,
  ) async {
    final newTtl = ttl - 1;
    final newHopCount = hopCount + 1;
    if (newTtl <= 0) return const DroppedPayload('TTL expired');
    if (newHopCount >= maxHopCount) return const DroppedPayload('Hop limit exceeded');

    final forwarded = jsonEncode({
      ...data,
      'ttl': newTtl,
      'hopCount': newHopCount,
    });

    var forwardedCount = 0;
    if (connectedPeers.contains(destinationId)) {
      if (await _service.sendMessage(destinationId, forwarded)) {
        forwardedCount++;
      }
    } else {
      for (final peerId in connectedPeers) {
        if (peerId != fromPeerId &&
            peerId != originId &&
            peerId != _currentLocalId) {
          if (await _service.sendMessage(peerId, forwarded)) {
            forwardedCount++;
          }
        }
      }
    }

    if (forwardedCount == 0) {
      return const DroppedPayload('No route to host: destination unreachable');
    }

    return RelayedFileChunk(
      transferId: envelope.transferId,
      chunkIndex: envelope.chunkIndex,
      destinationId: destinationId,
      newTtl: newTtl,
      newHopCount: newHopCount,
      forwardedCount: forwardedCount,
    );
  }

  Future<RoutedPayloadResult> _handleIncomingEncryptedChunkAck(
    Map<String, dynamic> data,
    String? fromPeerId,
  ) async {
    final destinationId = data['destinationId'] as String?;
    final originId = data['originId'] as String?;
    final ttl = data['ttl'] as int?;
    final hopCount = data['hopCount'] as int? ?? 0;

    if (destinationId == null || originId == null || ttl == null) {
      return const DroppedPayload('Invalid chunk ACK packet: missing routing metadata');
    }

    if (ttl <= 0) {
      return const DroppedPayload('ACK TTL expired');
    }
    if (ttl > maxTtl) {
      return const DroppedPayload('Invalid TTL: exceeds maximum allowed TTL');
    }
    if (hopCount < 0) {
      return const DroppedPayload('Invalid hopCount');
    }
    if (hopCount >= maxHopCount) {
      return const DroppedPayload('Hop limit exceeded');
    }

    // Routing loop detection
    if (fromPeerId != null && fromPeerId == destinationId) {
      return const DroppedPayload('Routing loop detected: received from packet destination');
    }
    if (originId == _currentLocalId) {
      return const DroppedPayload('Routing loop: ACK originated locally');
    }

    // Parse and validate the immutable EncryptedChunkAckEnvelope
    final Map<String, dynamic> envelopeMap;
    if (data['envelope'] is Map<String, dynamic>) {
      envelopeMap = data['envelope'] as Map<String, dynamic>;
    } else {
      envelopeMap = data;
    }

    final EncryptedChunkAckEnvelope envelope;
    try {
      envelope = EncryptedChunkAckEnvelope.fromMap(envelopeMap);
      envelope.validate();
    } catch (e) {
      return DroppedPayload('Malformed or invalid chunk ACK envelope: $e');
    }

    final messageId = (data['messageId'] as String?) ?? 'ack:${envelope.transferId}:${envelope.chunkIndex}';

    // Replay protection and duplicate suppression
    if (_replayProtection != null) {
      if (destinationId != _currentLocalId) {
        // Relaying node: check and record so duplicate ACKs are not forwarded
        final outcome = await _replayProtection.checkAndMarkSeen(
          packetType: 'file_ack',
          originId: envelope.originId,
          packetId: messageId,
          timestamp: envelope.createdAt,
        );
        if (!outcome.isAccepted) {
          return const DroppedPayload('Duplicate or invalid ACK');
        }
      } else {
        // Local destination: pre-check if already recorded
        final isDuplicate = await _replayProtection.isSeen(
          packetType: 'file_ack',
          originId: envelope.originId,
          packetId: messageId,
        );
        if (isDuplicate) {
          return const DroppedPayload('Duplicate ACK');
        }
      }
    } else {
      if (_processedAckIds.contains(messageId)) {
        return const DroppedPayload('Duplicate ACK');
      }
      _addToProcessed(messageId, _processedAckIds);
    }

    if (destinationId == _currentLocalId) {
      final delivery = LocalFileChunkAckDelivery(envelope: envelope, payload: data);
      _fileAckDeliveryController.add(delivery);
      return delivery;
    }

    return _relayFileAck(
      data,
      envelope,
      messageId,
      originId,
      destinationId,
      ttl,
      hopCount,
      fromPeerId,
    );
  }

  Future<RoutedPayloadResult> _relayFileAck(
    Map<String, dynamic> data,
    EncryptedChunkAckEnvelope envelope,
    String messageId,
    String originId,
    String destinationId,
    int ttl,
    int hopCount,
    String? fromPeerId,
  ) async {
    final newTtl = ttl - 1;
    final newHopCount = hopCount + 1;
    if (newTtl <= 0) return const DroppedPayload('ACK TTL expired');
    if (newHopCount >= maxHopCount) return const DroppedPayload('Hop limit exceeded');

    final forwarded = jsonEncode({
      ...data,
      'ttl': newTtl,
      'hopCount': newHopCount,
    });

    var forwardedCount = 0;
    if (connectedPeers.contains(destinationId)) {
      if (await _service.sendMessage(destinationId, forwarded)) {
        forwardedCount++;
      }
    } else {
      for (final peerId in connectedPeers) {
        if (peerId != fromPeerId &&
            peerId != originId &&
            peerId != _currentLocalId) {
          if (await _service.sendMessage(peerId, forwarded)) {
            forwardedCount++;
          }
        }
      }
    }

    if (forwardedCount == 0) {
      return const DroppedPayload('No route to host: destination unreachable');
    }

    return RelayedFileAck(
      transferId: envelope.transferId,
      chunkIndex: envelope.chunkIndex,
      destinationId: destinationId,
      newTtl: newTtl,
      newHopCount: newHopCount,
      forwardedCount: forwardedCount,
    );
  }

  void _addToProcessed(String id, Set<String> cache) {
    if (cache.length >= _maxCacheSize) {
      cache.remove(cache.first);
    }
    cache.add(id);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _fileChunkDeliveryController.close();
    await _fileAckDeliveryController.close();
  }
}

/// Router-backed adapter implementing [ChunkTransportSender] for [ChunkSendingPipeline].
///
/// Hands off [EncryptedFileChunkEnvelope] instances to [MeshRouter.routeFileChunk]
/// for multihop store-and-forward transmission.
class RouterChunkTransportSender implements ChunkTransportSender {
  RouterChunkTransportSender({
    required this.router,
    this.ttl = MeshMessage.defaultTtl,
  });

  final MeshRouter router;
  final int ttl;

  @override
  Future<bool> sendChunk(EncryptedFileChunkEnvelope envelope) =>
      router.routeFileChunk(envelope, ttl: ttl);
}

/// Router-backed adapter implementing [ChunkAckTransportSender] for [ChunkAckService].
///
/// Hands off [EncryptedChunkAckEnvelope] instances to [MeshRouter.routeFileAck]
/// for multihop store-and-forward transmission.
class RouterChunkAckTransportSender implements ChunkAckTransportSender {
  RouterChunkAckTransportSender({
    required this.router,
    this.ttl = MeshMessage.defaultTtl,
  });

  final MeshRouter router;
  final int ttl;

  @override
  Future<bool> sendAck(EncryptedChunkAckEnvelope envelope) =>
      router.routeFileAck(envelope, ttl: ttl);
}
