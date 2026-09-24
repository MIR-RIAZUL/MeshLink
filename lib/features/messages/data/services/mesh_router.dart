import 'dart:async';
import 'dart:convert';

import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';

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

class FileTransferDelivery extends RoutedPayloadResult {
  const FileTransferDelivery(this.payload);
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
  })  : _service = discoveryService,
        _currentLocalId = localId,
        // ignore: prefer_initializing_formals
        _getConnectedPeers = getConnectedPeers,
        _subscription = null {
    _subscription = _service.events.listen(_onDiscoveryEvent);
  }

  final DeviceDiscoveryService _service;
  String _currentLocalId;
  final Set<String> Function()? _getConnectedPeers;
  final Set<String> _connectedPeers = {};
  final Set<String> _processedMessageIds = {};
  final Set<String> _processedAckIds = {};
  StreamSubscription<DeviceDiscoveryEvent>? _subscription;

  static const int _maxCacheSize = 1000;

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
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'message') {
        return await _handleIncomingMessage(data, fromPeerId);
      } else if (type == 'encrypted_message') {
        return await _handleIncomingEncryptedMessage(data, fromPeerId);
      } else if (type == 'key_request' || type == 'key_response') {
        return await _handleKeyExchange(data, fromPeerId);
      } else if (type == 'file_start' ||
          type == 'file_chunk' ||
          type == 'file_end' ||
          type == 'file_ack' ||
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
    if (_processedMessageIds.contains(messageId)) {
      return const DroppedPayload('Duplicate message');
    }
    _addToProcessed(messageId, _processedMessageIds);
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

    final ackKey = '${messageId}_$originId';
    if (_processedAckIds.contains(ackKey)) {
      return const DroppedPayload('Duplicate ACK');
    }
    _addToProcessed(ackKey, _processedAckIds);

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

  void _addToProcessed(String id, Set<String> cache) {
    if (cache.length > _maxCacheSize) {
      cache.remove(cache.first);
    }
    cache.add(id);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
