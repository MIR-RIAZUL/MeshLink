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

  // Replay Protection Primitives
  Future<bool> checkAndMarkSeen({
    required String packetType,
    required String originId,
    required String packetId,
    DateTime? receivedAt,
  });

  Future<bool> hasSeenPacket(String replayKey);

  Future<int> pruneExpiredPackets(Duration maxAge);

  // Peer Identity Primitives
  Future<PeerIdentityEntry?> getPeerIdentity(String peerId);

  Future<void> savePeerIdentity(PeerIdentityEntry entry);

  Future<void> updateTrustStatus(String peerId, String status);
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

  @override
  Future<bool> checkAndMarkSeen({
    required String packetType,
    required String originId,
    required String packetId,
    DateTime? receivedAt,
  }) {
    return _db.checkAndMarkSeen(
      packetType: packetType,
      originId: originId,
      packetId: packetId,
      receivedAt: receivedAt,
    );
  }

  @override
  Future<bool> hasSeenPacket(String replayKey) {
    return _db.hasSeenPacket(replayKey);
  }

  @override
  Future<int> pruneExpiredPackets(Duration maxAge) {
    return _db.pruneExpiredPackets(maxAge);
  }

  @override
  Future<PeerIdentityEntry?> getPeerIdentity(String peerId) {
    return _db.getPeerIdentity(peerId);
  }

  @override
  Future<void> savePeerIdentity(PeerIdentityEntry entry) async {
    await _db.savePeerIdentity(
      PeerIdentitiesTableCompanion(
        peerId: Value(entry.peerId),
        identityPublicKey: Value(entry.identityPublicKey),
        safetyNumber: Value(entry.safetyNumber),
        trustStatus: Value(entry.trustStatus),
        protocolVersion: Value(entry.protocolVersion),
        firstSeenAt: Value(entry.firstSeenAt),
        lastSeenAt: Value(entry.lastSeenAt),
      ),
    );
  }

  @override
  Future<void> updateTrustStatus(String peerId, String status) async {
    await _db.updateTrustStatus(peerId, status);
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
