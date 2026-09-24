import 'dart:convert';
import 'dart:math';

/// Message lifecycle status:
/// pending -> sending -> sent -> delivered
/// or sending -> failed
enum MessageStatus { pending, sending, sent, delivered, failed }

class MeshMessage {
  static const int maxMessageLength = 10000;
  static const int maxRetryLimit = 5;

  const MeshMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.pending,
    this.retryCount = 0,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final int retryCount;

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
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    int? retryCount,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
    'retryCount': retryCount,
  };

  factory MeshMessage.fromMap(Map<String, dynamic> map) => MeshMessage(
    id: map['id'] as String,
    conversationId:
        (map['conversationId'] as String?) ??
        (map['receiverId'] as String? ?? ''),
    senderId: map['senderId'] as String,
    receiverId: map['receiverId'] as String,
    text: map['text'] as String,
    timestamp:
        DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    status: MessageStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => MessageStatus.delivered,
    ),
    retryCount: (map['retryCount'] as int?) ?? 0,
  );

  String toJson() => jsonEncode(toMap());

  factory MeshMessage.fromJson(String source) =>
      MeshMessage.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Wire protocol payload for BLE/P2P transmission
  String toWireProtocol() => jsonEncode({
    'type': 'message',
    'version': 1,
    'messageId': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'receiverId': receiverId,
    'timestamp': timestamp.toIso8601String(),
    'text': text,
  });

  /// Parse incoming wire protocol payload
  static MeshMessage? fromWireProtocol(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map['type'] != 'message') return null;

      final text = map['text'] as String? ?? '';
      if (text.length > maxMessageLength) {
        return null; // Reject payloads exceeding size limit
      }

      final senderId = map['senderId'] as String;
      final receiverId = map['receiverId'] as String;

      return MeshMessage(
        id: map['messageId'] as String,
        conversationId:
            (map['conversationId'] as String?) ?? senderId, // conversation is sender for receiver
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        timestamp:
            DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
        status: MessageStatus.delivered,
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
  }) => jsonEncode({
    'type': 'ack',
    'version': 1,
    'messageId': messageId,
    'conversationId': conversationId,
    'senderId': senderId,
    'receiverId': receiverId,
    'timestamp': DateTime.now().toIso8601String(),
  });
}
