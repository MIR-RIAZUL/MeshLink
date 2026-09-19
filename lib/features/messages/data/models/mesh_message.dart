import 'dart:convert';
import 'dart:math';

enum MessageStatus { sending, sent, delivered, failed }

class MeshMessage {
  const MeshMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sending,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;

  bool get isOutgoing =>
      status == MessageStatus.sending ||
      status == MessageStatus.sent ||
      status == MessageStatus.delivered ||
      status == MessageStatus.failed;

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
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
  };

  factory MeshMessage.fromMap(Map<String, dynamic> map) => MeshMessage(
    id: map['id'] as String,
    senderId: map['senderId'] as String,
    receiverId: map['receiverId'] as String,
    text: map['text'] as String,
    timestamp:
        DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    status: MessageStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => MessageStatus.delivered,
    ),
  );

  String toJson() => jsonEncode(toMap());

  factory MeshMessage.fromJson(String source) =>
      MeshMessage.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Wire protocol payload for BLE transmission
  String toWireProtocol() => jsonEncode({
    'type': 'message',
    'messageId': id,
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
      return MeshMessage(
        id: map['messageId'] as String,
        senderId: map['senderId'] as String,
        receiverId: map['receiverId'] as String,
        text: map['text'] as String,
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
    required String senderId,
    required String receiverId,
  }) => jsonEncode({
    'type': 'ack',
    'messageId': messageId,
    'senderId': senderId,
    'receiverId': receiverId,
    'timestamp': DateTime.now().toIso8601String(),
  });
}
