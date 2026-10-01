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

/// Table storing verified and TOFU peer public identity keys and verification state.
@DataClassName('PeerIdentityEntry')
class PeerIdentitiesTable extends Table {
  /// Remote peer device ID (e.g. ML-A1B2C3).
  TextColumn get peerId => text()();

  /// Ed25519 identity public key representation (Base64URL encoded 32 bytes).
  TextColumn get identityPublicKey => text()();

  /// Currently calculated verification value (e.g. 6-digit SAS).
  TextColumn get safetyNumber => text()();

  /// Lifecycle trust status: tofu_unverified, verified, compromised.
  TextColumn get trustStatus => text()();

  /// Protocol version supported by peer (e.g. 2).
  IntColumn get protocolVersion => integer().withDefault(const Constant(2))();

  /// Initial pairing/discovery timestamp.
  DateTimeColumn get firstSeenAt => dateTime()();

  /// Last observed activity/handshake timestamp.
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {peerId};
}

/// Table storing deduplication keys for persistent replay protection.
@DataClassName('SeenPacketEntry')
class SeenPacketsTable extends Table {
  /// Canonical composite replay key: "packetType:originId:packetId".
  TextColumn get replayKey => text()();

  /// Category of packet (e.g. encrypted_message, ack, key_request, key_response, file_chunk).
  TextColumn get packetType => text()();

  /// Origin node identifier.
  TextColumn get originId => text()();

  /// Local timestamp when packet was recorded.
  DateTimeColumn get receivedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {replayKey};

  List<TableIndex> get tableIndexes => [
    TableIndex(name: 'idx_seen_packets_received_at', columns: {#receivedAt}),
  ];
}

@DriftDatabase(tables: [MessagesTable, PeerIdentitiesTable, SeenPacketsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(peerIdentitiesTable);
        await m.createTable(seenPacketsTable);
      }
    },
  );

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

  // --- Replay Protection Operations ---

  /// Atomically records a packet key if not already seen.
  /// Returns true if newly inserted, false if already seen.
  Future<bool> checkAndMarkSeen({
    required String packetType,
    required String originId,
    required String packetId,
  }) async {
    final key = '$packetType:$originId:$packetId';
    final rowsAffected = await customUpdate(
      'INSERT OR IGNORE INTO seen_packets_table (replay_key, packet_type, origin_id, received_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString(key),
        Variable.withString(packetType),
        Variable.withString(originId),
        Variable.withDateTime(DateTime.now()),
      ],
      updates: {seenPacketsTable},
    );
    return rowsAffected > 0;
  }

  /// Deletes seen packet entries older than maxAge.
  Future<int> pruneExpiredPackets(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    return (delete(seenPacketsTable)
          ..where((t) => t.receivedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  // --- Peer Identity Operations ---

  /// Retrieve peer identity by peer ID.
  Future<PeerIdentityEntry?> getPeerIdentity(String peerId) {
    return (select(peerIdentitiesTable)..where((t) => t.peerId.equals(peerId)))
        .getSingleOrNull();
  }

  /// Insert or replace a peer identity entry.
  Future<int> savePeerIdentity(PeerIdentitiesTableCompanion entry) {
    return into(peerIdentitiesTable).insertOnConflictUpdate(entry);
  }

  /// Update only trust status for a specific peer ID, preserving other fields.
  Future<int> updateTrustStatus(String peerId, String status) {
    return (update(peerIdentitiesTable)..where((t) => t.peerId.equals(peerId)))
        .write(PeerIdentitiesTableCompanion(trustStatus: Value(status)));
  }
}

