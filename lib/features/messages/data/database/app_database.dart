import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Table storing local persistent messages for MeshLink.
@DataClassName('LocalMessageEntry')
class MessagesTable extends Table {
  /// Unique identifier for each message (e.g. MSG-1727220000000-A1B2C3).
  TextColumn get messageId => text()();

  /// Stable conversation identifier (remote peer device ID).
  TextColumn get conversationId => text()();

  /// Sender MeshLink device ID.
  TextColumn get senderId => text()();

  /// Receiver MeshLink device ID.
  TextColumn get receiverId => text()();

  /// Text content of the message.
  TextColumn get textContent => text()();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();

  /// Lifecycle status: pending, sending, sent, delivered, failed.
  TextColumn get status => text()();

  /// Number of transmission retries attempted.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {messageId};
}

@DriftDatabase(tables: [MessagesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'meshlink_messages.db');
  }

  // --- Database Operations ---

  /// Get all messages for a specific conversation (peer ID), sorted by createdAt ascending.
  Future<List<LocalMessageEntry>> getMessagesForConversation(
    String conversationId,
  ) {
    return (select(messagesTable)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Get all distinct conversation peer IDs.
  Future<List<String>> getConversationPeerIds() async {
    final query = selectOnly(messagesTable, distinct: true)
      ..addColumns([messagesTable.conversationId]);
    final rows = await query.get();
    return rows
        .map((row) => row.read(messagesTable.conversationId))
        .whereType<String>()
        .toList();
  }

  /// Get the last message for a peer conversation.
  Future<LocalMessageEntry?> getLastMessageForPeer(String peerId) {
    return (select(messagesTable)
          ..where((t) => t.conversationId.equals(peerId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Check if a message with given messageId already exists.
  Future<bool> hasMessage(String messageId) async {
    final query = select(messagesTable)
      ..where((t) => t.messageId.equals(messageId));
    final count = await query.get();
    return count.isNotEmpty;
  }

  /// Insert or ignore a message entry (for duplicate protection).
  Future<int> insertMessage(MessagesTableCompanion entry) {
    return into(messagesTable).insertOnConflictUpdate(entry);
  }

  /// Update the status of a specific message.
  Future<int> updateMessageStatus(String messageId, String newStatus) {
    return (update(messagesTable)..where((t) => t.messageId.equals(messageId)))
        .write(MessagesTableCompanion(status: Value(newStatus)));
  }

  /// Increment the retry count of a message.
  Future<void> incrementRetryCount(String messageId) async {
    final existing = await (select(messagesTable)
          ..where((t) => t.messageId.equals(messageId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(messagesTable)
            ..where((t) => t.messageId.equals(messageId)))
          .write(
            MessagesTableCompanion(
              retryCount: Value(existing.retryCount + 1),
            ),
          );
    }
  }

  /// Get all pending or failed messages for a specific receiver peer ID.
  Future<List<LocalMessageEntry>> getPendingMessagesForPeer(String peerId) {
    return (select(messagesTable)
          ..where(
            (t) =>
                t.receiverId.equals(peerId) &
                (t.status.equals('pending') | t.status.equals('failed')),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Get all pending or failed messages across all peers.
  Future<List<LocalMessageEntry>> getAllPendingMessages() {
    return (select(messagesTable)
          ..where(
            (t) => t.status.equals('pending') | t.status.equals('failed'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Delete all messages (primarily for testing/resetting).
  Future<int> deleteAllMessages() {
    return delete(messagesTable).go();
  }
}
