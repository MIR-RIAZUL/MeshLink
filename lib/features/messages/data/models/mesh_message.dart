import 'dart:convert';
import 'dart:math';

/// Message lifecycle status:
/// pending -> sending -> sent -> delivered
/// or sending -> failed
enum MessageStatus { pending, sending, sent, delivered, failed }

class MeshMessage {
  static const int maxMessageLength = 10000;
  static const int maxRetryLimit = 5;
  static const int defaultTtl = 5;

  const MeshMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    String? originId,
    String? destinationId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.pending,
    this.retryCount = 0,
    this.ttl = defaultTtl,
    this.hopCount = 0,
  })  : originId = originId ?? senderId,
        destinationId = destinationId ?? receiverId;

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String originId;
  final String destinationId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final int retryCount;
  final int ttl;
  final int hopCount;

  bool get isOutgoing =>
      status == MessageStatus.pending ||
      status == MessageStatus.sending ||
      status == MessageStatus.sent ||
      status == MessageStatus.delivered ||
      status == MessageStatus.failed;

  /// Helper to validate message length.
  static void validateLength(String text) {
    if (text.length > maxMessageLength) {
      throw ArgumentError(
        'Message text exceeds maximum allowed limit of $maxMessageLength characters (length: ${text.length}).',
      );
    }
  }

  static String generateId() {
    final rand = Random()
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return 'MSG-${DateTime.now().millisecondsSinceEpoch}-$rand';
  }

  MeshMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? originId,
    String? destinationId,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    int? retryCount,
    int? ttl,
    int? hopCount,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      originId: originId ?? this.originId,
      destinationId: destinationId ?? this.destinationId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'receiverId': receiverId,
    'originId': originId,
    'destinationId': destinationId,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
    'retryCount': retryCount,
    'ttl': ttl,
    'hopCount': hopCount,
  };

  factory MeshMessage.fromMap(Map<String, dynamic> map) {
    final senderId = (map['senderId'] as String?) ?? (map['originId'] as String? ?? '');
    final receiverId = (map['receiverId'] as String?) ?? (map['destinationId'] as String? ?? '');
    final originId = (map['originId'] as String?) ?? senderId;
    final destinationId = (map['destinationId'] as String?) ?? receiverId;

    return MeshMessage(
      id: map['id'] as String,
      conversationId:
          (map['conversationId'] as String?) ??
          (map['receiverId'] as String? ?? originId),
      senderId: senderId,
      receiverId: receiverId,
      originId: originId,
      destinationId: destinationId,
      text: map['text'] as String,
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MessageStatus.delivered,
      ),
      retryCount: (map['retryCount'] as int?) ?? 0,
      ttl: (map['ttl'] as int?) ?? defaultTtl,
      hopCount: (map['hopCount'] as int?) ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MeshMessage.fromJson(String source) =>
      MeshMessage.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Plaintext wire payloads are intentionally disabled.
  /// The active mesh path must only transmit encrypted_message packets.
  String toWireProtocol({int? ttl, int? hopCount}) => throw UnsupportedError(
    'Plaintext wire protocol is disabled. Use encrypted_message payloads only.',
  );

  /// Parse incoming wire protocol payload
  static MeshMessage? fromWireProtocol(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map['type'] != 'message') return null;

      final text = (map['text'] as String? ?? '').trim();
      if (text.length > maxMessageLength) {
        return null; // Reject payloads exceeding size limit
      }

      final senderId = (map['senderId'] as String?) ?? (map['originId'] as String? ?? '');
      final receiverId = (map['receiverId'] as String?) ?? (map['destinationId'] as String? ?? '');
      final originId = (map['originId'] as String?) ?? senderId;
      final destinationId = (map['destinationId'] as String?) ?? receiverId;
      final ttl = (map['ttl'] as int?) ?? defaultTtl;
      final hopCount = (map['hopCount'] as int?) ?? 0;

      return MeshMessage(
        id: map['messageId'] as String,
        conversationId:
            (map['conversationId'] as String?) ?? originId, // conversation is sender/origin for receiver
        senderId: senderId,
        receiverId: receiverId,
        originId: originId,
        destinationId: destinationId,
        text: text,
        timestamp:
            DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
        status: MessageStatus.delivered,
        ttl: ttl,
        hopCount: hopCount,
      );
    } catch (_) {
      return null;
    }
  }

  /// Wire protocol ACK payload
  static String createAckPayload({
    required String messageId,
    required String conversationId,
    required String senderId,
    required String receiverId,
    String? originId,
    String? destinationId,
    int ttl = defaultTtl,
    int hopCount = 0,
  }) => jsonEncode({
    'type': 'ack',
    'version': 1,
    'messageId': messageId,
    'originId': originId ?? senderId,
    'destinationId': destinationId ?? receiverId,
    'senderId': senderId,
    'receiverId': receiverId,
    'conversationId': conversationId,
    'timestamp': DateTime.now().toIso8601String(),
    'ttl': ttl,
    'hopCount': hopCount,
  });
}
