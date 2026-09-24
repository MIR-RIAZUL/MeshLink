import 'package:drift/drift.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';

abstract class MessageRepository implements MessageStorageService {
  @override
  Future<List<MeshMessage>> getMessages(String peerId);
  @override
  Future<void> saveMessage(MeshMessage message);
  @override
  Future<void> updateMessageStatus(String messageId, MessageStatus status);
  @override
  Future<bool> hasMessage(String messageId);
  @override
  Future<List<String>> getActivePeerIds();
  @override
  Future<MeshMessage?> getLastMessage(String peerId);

  @override
  Future<void> incrementRetryCount(String messageId);
  @override
  Future<List<MeshMessage>> getPendingMessages(String peerId);
  @override
  Future<List<MeshMessage>> getAllPendingMessages();
}

class DriftMessageRepository implements MessageRepository {
  DriftMessageRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<MeshMessage>> getMessages(String peerId) async {
    final entries = await _db.getMessagesForConversation(peerId);
    return entries.map(_entryToMessage).toList();
  }

  @override
  Future<void> saveMessage(MeshMessage message) async {
    final companion = MessagesTableCompanion(
      messageId: Value(message.id),
      conversationId: Value(message.conversationId),
      senderId: Value(message.senderId),
      receiverId: Value(message.receiverId),
      textContent: Value(message.text),
      createdAt: Value(message.timestamp),
      status: Value(message.status.name),
      retryCount: Value(message.retryCount),
    );
    await _db.insertMessage(companion);
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    await _db.updateMessageStatus(messageId, status.name);
  }

  @override
  Future<void> incrementRetryCount(String messageId) async {
    await _db.incrementRetryCount(messageId);
  }

  @override
  Future<bool> hasMessage(String messageId) async {
    return _db.hasMessage(messageId);
  }

  @override
  Future<List<String>> getActivePeerIds() async {
    return _db.getConversationPeerIds();
  }

  @override
  Future<MeshMessage?> getLastMessage(String peerId) async {
    final entry = await _db.getLastMessageForPeer(peerId);
    return entry != null ? _entryToMessage(entry) : null;
  }

  @override
  Future<List<MeshMessage>> getPendingMessages(String peerId) async {
    final entries = await _db.getPendingMessagesForPeer(peerId);
    return entries.map(_entryToMessage).toList();
  }

  @override
  Future<List<MeshMessage>> getAllPendingMessages() async {
    final entries = await _db.getAllPendingMessages();
    return entries.map(_entryToMessage).toList();
  }

  MeshMessage _entryToMessage(LocalMessageEntry entry) {
    return MeshMessage(
      id: entry.messageId,
      conversationId: entry.conversationId,
      senderId: entry.senderId,
      receiverId: entry.receiverId,
      text: entry.textContent,
      timestamp: entry.createdAt,
      status: MessageStatus.values.firstWhere(
        (s) => s.name == entry.status,
        orElse: () => MessageStatus.delivered,
      ),
      retryCount: entry.retryCount,
    );
  }
}
