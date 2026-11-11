import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';

/// Legacy SQLite schema v4 definition for genuine on-disk migration testing.
class _V4LegacyDatabase extends GeneratedDatabase {
  _V4LegacyDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement('PRAGMA user_version = 4;');
      await customStatement('''
        CREATE TABLE messages_table (
          message_id TEXT NOT NULL PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          sender_id TEXT NOT NULL,
          receiver_id TEXT NOT NULL,
          text_content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0
        );
      ''');
      await customStatement('''
        CREATE TABLE peer_identities_table (
          peer_id TEXT NOT NULL PRIMARY KEY,
          identity_public_key TEXT NOT NULL,
          safety_number TEXT NOT NULL,
          trust_status TEXT NOT NULL,
          protocol_version INTEGER NOT NULL DEFAULT 2,
          first_seen_at INTEGER NOT NULL,
          last_seen_at INTEGER NOT NULL
        );
      ''');
      await customStatement('''
        CREATE TABLE seen_packets_table (
          replay_key TEXT NOT NULL PRIMARY KEY,
          packet_type TEXT NOT NULL,
          origin_id TEXT NOT NULL,
          received_at INTEGER NOT NULL
        );
      ''');
      await customStatement('CREATE INDEX idx_seen_packets_received_at ON seen_packets_table (received_at);');
      await customStatement('''
        CREATE TABLE file_transfers_table (
          transfer_id TEXT NOT NULL PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          peer_id TEXT NOT NULL,
          direction TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          mime_type TEXT NOT NULL,
          file_hash TEXT NOT NULL,
          local_path TEXT NOT NULL,
          staging_path TEXT NOT NULL,
          total_chunks INTEGER NOT NULL,
          chunk_size INTEGER NOT NULL,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          CHECK (file_size >= 0),
          CHECK (total_chunks >= 0),
          CHECK (chunk_size > 0)
        );
      ''');
      await customStatement('CREATE INDEX idx_file_transfers_peer_id ON file_transfers_table (peer_id);');
      await customStatement('CREATE INDEX idx_file_transfers_status ON file_transfers_table (status);');
      await customStatement('CREATE INDEX idx_file_transfers_updated_at ON file_transfers_table (updated_at);');
      await customStatement('''
        CREATE TABLE file_chunks_table (
          transfer_id TEXT NOT NULL,
          chunk_index INTEGER NOT NULL,
          status TEXT NOT NULL,
          received_at INTEGER NOT NULL,
          PRIMARY KEY (transfer_id, chunk_index),
          CHECK (chunk_index >= 0)
        );
      ''');
      await customStatement('CREATE INDEX idx_file_chunks_transfer_id ON file_chunks_table (transfer_id);');
      await customStatement('''
        CREATE TABLE groups_table (
          group_id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          creator_id TEXT NOT NULL,
          admin_id TEXT NOT NULL,
          epoch INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          CHECK (epoch >= 1),
          CHECK (length(name) >= 1 AND length(name) <= 64)
        );
      ''');
      await customStatement('CREATE INDEX idx_groups_admin_id ON groups_table (admin_id);');
      await customStatement('CREATE INDEX idx_groups_created_at ON groups_table (created_at);');
      await customStatement('''
        CREATE TABLE group_members_table (
          group_id TEXT NOT NULL REFERENCES groups_table(group_id) ON DELETE CASCADE,
          peer_id TEXT NOT NULL,
          role TEXT NOT NULL,
          status TEXT NOT NULL,
          joined_at INTEGER NOT NULL,
          invited_by TEXT NOT NULL,
          PRIMARY KEY (group_id, peer_id),
          CHECK (role IN ('admin', 'member')),
          CHECK (status IN ('active', 'pendingInvite', 'removed'))
        );
      ''');
      await customStatement('CREATE INDEX idx_group_members_peer_id ON group_members_table (peer_id);');
      await customStatement('CREATE INDEX idx_group_members_status ON group_members_table (group_id, status);');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS trg_group_members_limit
        BEFORE INSERT ON group_members_table
        WHEN NEW.status != 'removed' AND (
          SELECT COUNT(DISTINCT peer_id)
          FROM group_members_table
          WHERE group_id = NEW.group_id
            AND status != 'removed'
            AND peer_id != NEW.peer_id
        ) >= 8
        BEGIN
          SELECT RAISE(ABORT, 'Group member limit of 8 exceeded');
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS trg_group_members_limit_update
        BEFORE UPDATE OF peer_id, group_id, status ON group_members_table
        WHEN NEW.status != 'removed' AND (
          SELECT COUNT(DISTINCT peer_id)
          FROM group_members_table
          WHERE group_id = NEW.group_id
            AND status != 'removed'
            AND peer_id != NEW.peer_id
        ) >= 8
        BEGIN
          SELECT RAISE(ABORT, 'Group member limit of 8 exceeded');
        END;
      ''');
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final testNow = DateTime.utc(2026, 11, 11, 12, 0, 0);

  group('Phase 9 Step 6.1 — Drift Database Schema v5 Migration Tests', () {
    test('1. Fresh database reports schemaVersion 5 and foreign keys enabled', () async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        expect(db.schemaVersion, 5);

        // Verify foreign keys pragma is active
        final fkResult = await db.customSelect('PRAGMA foreign_keys;').getSingle();
        expect(fkResult.data.values.first, 1);

        // Verify user_version pragma reports 5
        final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
        expect(versionResult.data.values.first, 5);

        // Verify all 4 new v5 tables exist
        final tables = (await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get())
            .map((r) => r.data['name'] as String)
            .toSet();
        expect(tables.contains('group_epoch_operations_table'), isTrue);
        expect(tables.contains('group_epoch_sync_table'), isTrue);
        expect(tables.contains('group_message_payloads_table'), isTrue);
        expect(tables.contains('group_delivery_queue_table'), isTrue);
      } finally {
        await db.close();
      }
    });

    test('2. Genuine schema v4 on-disk database migrates safely to v5 with 100% data preservation', () async {
      final tempDir = await Directory.systemTemp.createTemp('meshlink_db_migration_v5_');
      final dbFile = File('${tempDir.path}/v4_migrating_to_v5.db');

      try {
        // Step A: Construct a genuine Schema v4 SQLite database on disk
        final v4Db = _V4LegacyDatabase(NativeDatabase(dbFile));
        final nowUnixSecs = testNow.millisecondsSinceEpoch ~/ 1000;

        await v4Db.customStatement('''
          INSERT INTO messages_table (message_id, conversation_id, sender_id, receiver_id, text_content, created_at, status, retry_count)
          VALUES ('MSG-V4-001', 'PEER-ALICE', 'PEER-ALICE', 'LOCAL-NODE', 'Legacy v4 message', $nowUnixSecs, 'delivered', 0);
        ''');
        await v4Db.customStatement('''
          INSERT INTO peer_identities_table (peer_id, identity_public_key, safety_number, trust_status, protocol_version, first_seen_at, last_seen_at)
          VALUES ('PEER-ALICE', 'b64url_ed25519_alice_v4', '112233', 'verified', 2, $nowUnixSecs, $nowUnixSecs);
        ''');
        await v4Db.customStatement('''
          INSERT INTO seen_packets_table (replay_key, packet_type, origin_id, received_at)
          VALUES ('encrypted_message:PEER-ALICE:MSG-V4-001', 'encrypted_message', 'PEER-ALICE', $nowUnixSecs);
        ''');
        await v4Db.customStatement('''
          INSERT INTO file_transfers_table (transfer_id, conversation_id, peer_id, direction, file_name, file_size, mime_type, file_hash, local_path, staging_path, total_chunks, chunk_size, status, created_at, updated_at)
          VALUES ('FT-V4-001', 'PEER-ALICE', 'PEER-ALICE', 'incoming', 'plan.pdf', 51200, 'application/pdf', 'sha256-hash', '/down/plan.pdf', '/stage/plan.part', 4, 16384, 'completed', $nowUnixSecs, $nowUnixSecs);
        ''');
        await v4Db.customStatement('''
          INSERT INTO file_chunks_table (transfer_id, chunk_index, status, received_at)
          VALUES ('FT-V4-001', 0, 'verified', $nowUnixSecs);
        ''');
        await v4Db.customStatement('''
          INSERT INTO groups_table (group_id, name, creator_id, admin_id, epoch, created_at, updated_at)
          VALUES ('GRP-ALPHA-V4', 'Alpha Squad', 'LOCAL-NODE', 'LOCAL-NODE', 2, $nowUnixSecs, $nowUnixSecs);
        ''');
        await v4Db.customStatement('''
          INSERT INTO group_members_table (group_id, peer_id, role, status, joined_at, invited_by)
          VALUES ('GRP-ALPHA-V4', 'LOCAL-NODE', 'admin', 'active', $nowUnixSecs, 'LOCAL-NODE');
        ''');
        await v4Db.customStatement('''
          INSERT INTO group_members_table (group_id, peer_id, role, status, joined_at, invited_by)
          VALUES ('GRP-ALPHA-V4', 'PEER-ALICE', 'member', 'active', $nowUnixSecs, 'LOCAL-NODE');
        ''');
        await v4Db.customStatement('''
          INSERT INTO group_members_table (group_id, peer_id, role, status, joined_at, invited_by)
          VALUES ('GRP-ALPHA-V4', 'PEER-BOB', 'member', 'pendingInvite', $nowUnixSecs, 'LOCAL-NODE');
        ''');

        // Verify v4 state
        final v4Version = (await v4Db.customSelect('PRAGMA user_version;').getSingle()).data.values.first;
        expect(v4Version, 4);

        final tablesBefore = (await v4Db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get())
            .map((r) => r.data['name'] as String)
            .toSet();
        expect(tablesBefore.contains('group_epoch_operations_table'), isFalse);
        expect(tablesBefore.contains('group_epoch_sync_table'), isFalse);
        expect(tablesBefore.contains('group_message_payloads_table'), isFalse);
        expect(tablesBefore.contains('group_delivery_queue_table'), isFalse);

        await v4Db.close();

        // Step B: Re-open the genuine v4 database with production AppDatabase (triggers onUpgrade to v5)
        final upgradedDb = AppDatabase(NativeDatabase(dbFile));

        expect(upgradedDb.schemaVersion, 5);

        // Verify SQLite user_version is updated to 5
        final v5Version = (await upgradedDb.customSelect('PRAGMA user_version;').getSingle()).data.values.first;
        expect(v5Version, 5);

        // Verify all 4 new tables now exist
        final tablesAfter = (await upgradedDb.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get())
            .map((r) => r.data['name'] as String)
            .toSet();
        expect(tablesAfter.contains('group_epoch_operations_table'), isTrue);
        expect(tablesAfter.contains('group_epoch_sync_table'), isTrue);
        expect(tablesAfter.contains('group_message_payloads_table'), isTrue);
        expect(tablesAfter.contains('group_delivery_queue_table'), isTrue);

        // Step C: Verify existing data survived 100% intact
        // 1. Existing 1-to-1 message
        final messages = await upgradedDb.getMessagesForConversation('PEER-ALICE');
        expect(messages.length, 1);
        expect(messages.first.messageId, 'MSG-V4-001');
        expect(messages.first.textContent, 'Legacy v4 message');

        // 2. Existing peer identity
        final peerIdentity = await upgradedDb.getPeerIdentity('PEER-ALICE');
        expect(peerIdentity, isNotNull);
        expect(peerIdentity!.identityPublicKey, 'b64url_ed25519_alice_v4');
        expect(peerIdentity.safetyNumber, '112233');

        // 3. Existing group record survived with new columns populated with defaults
        final group = await upgradedDb.getGroup('GRP-ALPHA-V4');
        expect(group, isNotNull);
        expect(group!.groupId, 'GRP-ALPHA-V4');
        expect(group.name, 'Alpha Squad');
        expect(group.creatorId, 'LOCAL-NODE');
        expect(group.adminId, 'LOCAL-NODE');
        expect(group.epoch, 2);
        // Verify schema v5 columns received expected defaults
        expect(group.isReEpochPending, isFalse);
        expect(group.activeReEpochOperationId, isNull);
        expect(group.preparedEpoch, isNull);
        expect(group.operationSequenceNumber, 0);

        // 4. Existing group members survived
        final members = await upgradedDb.getGroupMembers('GRP-ALPHA-V4');
        expect(members.length, 3);
        final alice = members.firstWhere((m) => m.peerId == 'PEER-ALICE');
        expect(alice.role, 'member');
        expect(alice.status, 'active');
        final bob = members.firstWhere((m) => m.peerId == 'PEER-BOB');
        expect(bob.status, 'pendingInvite');

        // Step D: Insert records into the new v5 tables to ensure operational integrity
        await upgradedDb.into(upgradedDb.groupEpochOperationsTable).insert(
          GroupEpochOperationsTableCompanion.insert(
            operationId: 'RE-OP-0123456789abcdef0123456789abcdef',
            groupId: 'GRP-ALPHA-V4',
            previousEpoch: 2,
            targetEpoch: 3,
            operationSequenceNumber: 1,
            operationStatus: 'preparing',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );

        final op = await (upgradedDb.select(upgradedDb.groupEpochOperationsTable)
              ..where((t) => t.operationId.equals('RE-OP-0123456789abcdef0123456789abcdef')))
            .getSingle();
        expect(op.operationId, 'RE-OP-0123456789abcdef0123456789abcdef');
        expect(op.targetEpoch, 3);
        expect(op.operationStatus, 'preparing');

        await upgradedDb.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('Phase 9 Step 6.1 — Schema v5 Constraints & Foreign Key Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      // Seed a parent group and active members for foreign key validation
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-TEST-1',
          name: 'Constraint Test Group',
          creatorId: 'PEER-CREATOR',
          adminId: 'PEER-CREATOR',
          epoch: const Value(1),
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-TEST-1',
          peerId: 'PEER-CREATOR',
          role: GroupRole.admin.toJson(),
          status: GroupMemberStatus.active.toJson(),
          joinedAt: testNow,
          invitedBy: 'PEER-CREATOR',
        ),
      );

      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-TEST-1',
          peerId: 'PEER-MEMBER-A',
          role: GroupRole.member.toJson(),
          status: GroupMemberStatus.active.toJson(),
          joinedAt: testNow,
          invitedBy: 'PEER-CREATOR',
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('3. Duplicate operation IDs are rejected by PRIMARY KEY', () async {
      await db.into(db.groupEpochOperationsTable).insert(
        GroupEpochOperationsTableCompanion.insert(
          operationId: 'OP-00000000000000000000000000000001',
          groupId: 'GRP-TEST-1',
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          operationStatus: 'preparing',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      expect(
        () async => db.into(db.groupEpochOperationsTable).insert(
          GroupEpochOperationsTableCompanion.insert(
            operationId: 'OP-00000000000000000000000000000001', // duplicate PK
            groupId: 'GRP-TEST-1',
            previousEpoch: 1,
            targetEpoch: 2,
            operationSequenceNumber: 2,
            operationStatus: 'preparing',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('4. Invalid epoch progression (targetEpoch <= previousEpoch) is rejected by CHECK constraint', () async {
      // targetEpoch equal to previousEpoch
      expect(
        () async => db.into(db.groupEpochOperationsTable).insert(
          GroupEpochOperationsTableCompanion.insert(
            operationId: 'OP-EQUAL-EPOCH',
            groupId: 'GRP-TEST-1',
            previousEpoch: 2,
            targetEpoch: 2,
            operationSequenceNumber: 1,
            operationStatus: 'preparing',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // targetEpoch less than previousEpoch
      expect(
        () async => db.into(db.groupEpochOperationsTable).insert(
          GroupEpochOperationsTableCompanion.insert(
            operationId: 'OP-DECREASING-EPOCH',
            groupId: 'GRP-TEST-1',
            previousEpoch: 3,
            targetEpoch: 2,
            operationSequenceNumber: 1,
            operationStatus: 'preparing',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('5. Non-positive operation sequence number is rejected by CHECK constraint', () async {
      expect(
        () async => db.into(db.groupEpochOperationsTable).insert(
          GroupEpochOperationsTableCompanion.insert(
            operationId: 'OP-ZERO-SEQ',
            groupId: 'GRP-TEST-1',
            previousEpoch: 1,
            targetEpoch: 2,
            operationSequenceNumber: 0, // Must be > 0
            operationStatus: 'preparing',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('6. Invalid operation status strings are rejected by CHECK constraint', () async {
      // Valid statuses: preparing, committing, finalizing, finalized, superseded
      for (final validStatus in ['preparing', 'committing', 'finalizing', 'finalized', 'superseded']) {
        final opId = 'OP-VALID-$validStatus';
        await db.into(db.groupEpochOperationsTable).insert(
          GroupEpochOperationsTableCompanion.insert(
            operationId: opId,
            groupId: 'GRP-TEST-1',
            previousEpoch: 1,
            targetEpoch: 2,
            operationSequenceNumber: 1,
            operationStatus: validStatus,
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );
      }

      // Invalid status 'aborted'
      expect(
        () async => db.into(db.groupEpochOperationsTable).insert(
          GroupEpochOperationsTableCompanion.insert(
            operationId: 'OP-INVALID-STATUS',
            groupId: 'GRP-TEST-1',
            previousEpoch: 1,
            targetEpoch: 2,
            operationSequenceNumber: 10,
            operationStatus: 'aborted',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('7. Invalid sync status values are rejected by CHECK constraints', () async {
      // First insert valid operation
      await db.into(db.groupEpochOperationsTable).insert(
        GroupEpochOperationsTableCompanion.insert(
          operationId: 'OP-SYNC-TEST',
          groupId: 'GRP-TEST-1',
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          operationStatus: 'preparing',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Invalid prepareStatus
      expect(
        () async => db.into(db.groupEpochSyncTable).insert(
          GroupEpochSyncTableCompanion.insert(
            operationId: 'OP-SYNC-TEST',
            groupId: 'GRP-TEST-1',
            memberPeerId: 'PEER-MEMBER-A',
            prepareStatus: const Value('invalid_status'),
            commitStatus: const Value('pending'),
            finalizeStatus: const Value('pending'),
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // Valid statuses: pending, acknowledged, failed
      await db.into(db.groupEpochSyncTable).insert(
        GroupEpochSyncTableCompanion.insert(
          operationId: 'OP-SYNC-TEST',
          groupId: 'GRP-TEST-1',
          memberPeerId: 'PEER-MEMBER-A',
          prepareStatus: const Value('acknowledged'),
          commitStatus: const Value('pending'),
          finalizeStatus: const Value('failed'),
          updatedAt: testNow,
        ),
      );
      final syncRecord = await (db.select(db.groupEpochSyncTable)
            ..where((t) => t.operationId.equals('OP-SYNC-TEST') & t.memberPeerId.equals('PEER-MEMBER-A')))
          .getSingle();
      expect(syncRecord.prepareStatus, 'acknowledged');
      expect(syncRecord.finalizeStatus, 'failed');
    });

    test('8. Sync record cannot reference an operation from another group (composite FK)', () async {
      // Create a second group
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-TEST-2',
          name: 'Second Group',
          creatorId: 'PEER-CREATOR',
          adminId: 'PEER-CREATOR',
          epoch: const Value(1),
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Create operation belonging to GRP-TEST-1
      await db.into(db.groupEpochOperationsTable).insert(
        GroupEpochOperationsTableCompanion.insert(
          operationId: 'OP-GRP-1',
          groupId: 'GRP-TEST-1',
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          operationStatus: 'preparing',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Attempt to insert sync record claiming operation OP-GRP-1 belongs to GRP-TEST-2
      // Must be rejected by composite foreign key (operation_id, group_id) -> group_epoch_operations_table(operation_id, group_id)
      expect(
        () async => db.into(db.groupEpochSyncTable).insert(
          GroupEpochSyncTableCompanion.insert(
            operationId: 'OP-GRP-1',
            groupId: 'GRP-TEST-2', // MISMATCH! Operation belongs to GRP-TEST-1
            memberPeerId: 'PEER-MEMBER-A',
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('9. Group deletion cascades to operations, sync records, payloads, and delivery queues', () async {
      // Create operation
      await db.into(db.groupEpochOperationsTable).insert(
        GroupEpochOperationsTableCompanion.insert(
          operationId: 'OP-CASCADE-1',
          groupId: 'GRP-TEST-1',
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          operationStatus: 'preparing',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Create sync record
      await db.into(db.groupEpochSyncTable).insert(
        GroupEpochSyncTableCompanion.insert(
          operationId: 'OP-CASCADE-1',
          groupId: 'GRP-TEST-1',
          memberPeerId: 'PEER-MEMBER-A',
          updatedAt: testNow,
        ),
      );

      // Create payload record
      await db.into(db.groupMessagePayloadsTable).insert(
        GroupMessagePayloadsTableCompanion.insert(
          groupId: 'GRP-TEST-1',
          messageId: 'MSG-CASCADE-1',
          encryptedPayload: Uint8List.fromList([1, 2, 3, 4]),
          nonce: Uint8List.fromList([5, 6, 7, 8]),
          createdAt: testNow,
        ),
      );

      // Create delivery queue record
      await db.into(db.groupDeliveryQueueTable).insert(
        GroupDeliveryQueueTableCompanion.insert(
          groupId: 'GRP-TEST-1',
          messageId: 'MSG-CASCADE-1',
          recipientPeerId: 'PEER-MEMBER-A',
          epoch: 1,
          packetType: 'group_message',
          encryptedEnvelopeJson: '{"ciphertext":"enc-blob"}',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Verify records exist before group deletion
      expect((await db.select(db.groupEpochOperationsTable).get()).length, 1);
      expect((await db.select(db.groupEpochSyncTable).get()).length, 1);
      expect((await db.select(db.groupMessagePayloadsTable).get()).length, 1);
      expect((await db.select(db.groupDeliveryQueueTable).get()).length, 1);

      // Delete the group
      final deletedCount = await db.deleteGroup('GRP-TEST-1');
      expect(deletedCount, 1);

      // Verify cascading deletion across all tables
      expect(await db.select(db.groupEpochOperationsTable).get(), isEmpty);
      expect(await db.select(db.groupEpochSyncTable).get(), isEmpty);
      expect(await db.select(db.groupMessagePayloadsTable).get(), isEmpty);
      expect(await db.select(db.groupDeliveryQueueTable).get(), isEmpty);
    });

    test('10. Delivery queue rejects duplicate (groupId, recipientPeerId, messageId) entries', () async {
      await db.into(db.groupDeliveryQueueTable).insert(
        GroupDeliveryQueueTableCompanion.insert(
          groupId: 'GRP-TEST-1',
          messageId: 'MSG-QUEUE-DUP',
          recipientPeerId: 'PEER-MEMBER-A',
          epoch: 1,
          packetType: 'group_message',
          encryptedEnvelopeJson: '{"ciphertext":"first"}',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Inserting duplicate (groupId, recipientPeerId, messageId) must violate UNIQUE constraint
      expect(
        () async => db.into(db.groupDeliveryQueueTable).insert(
          GroupDeliveryQueueTableCompanion.insert(
            groupId: 'GRP-TEST-1',
            messageId: 'MSG-QUEUE-DUP',
            recipientPeerId: 'PEER-MEMBER-A',
            epoch: 1,
            packetType: 'group_message',
            encryptedEnvelopeJson: '{"ciphertext":"second"}',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('11. Delivery queue rejects recipient not in group_members_table (FK enforcement)', () async {
      // Recipient 'PEER-OUTSIDER' is not a member of GRP-TEST-1
      expect(
        () async => db.into(db.groupDeliveryQueueTable).insert(
          GroupDeliveryQueueTableCompanion.insert(
            groupId: 'GRP-TEST-1',
            messageId: 'MSG-ORPHAN',
            recipientPeerId: 'PEER-OUTSIDER',
            epoch: 1,
            packetType: 'group_message',
            encryptedEnvelopeJson: '{"ciphertext":"enc"}',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('12. Delivery queue rejects invalid status strings and epoch < 1', () async {
      // Valid statuses: pending, sending, transport_acked, delivered, failed, cancelled, obsolete, expired
      final validStatuses = [
        'pending', 'sending', 'transport_acked', 'delivered',
        'failed', 'cancelled', 'obsolete', 'expired',
      ];
      int msgCounter = 1;
      for (final st in validStatuses) {
        await db.into(db.groupDeliveryQueueTable).insert(
          GroupDeliveryQueueTableCompanion.insert(
            groupId: 'GRP-TEST-1',
            messageId: 'MSG-ST-$msgCounter',
            recipientPeerId: 'PEER-MEMBER-A',
            epoch: 1,
            packetType: 'group_message',
            encryptedEnvelopeJson: '{"ciphertext":"data"}',
            status: Value(st),
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );
        msgCounter++;
      }

      // Invalid status 'completed'
      expect(
        () async => db.into(db.groupDeliveryQueueTable).insert(
          GroupDeliveryQueueTableCompanion.insert(
            groupId: 'GRP-TEST-1',
            messageId: 'MSG-INVALID-STATUS',
            recipientPeerId: 'PEER-MEMBER-A',
            epoch: 1,
            packetType: 'group_message',
            encryptedEnvelopeJson: '{"ciphertext":"data"}',
            status: const Value('completed'), // Invalid!
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // Invalid epoch 0
      expect(
        () async => db.into(db.groupDeliveryQueueTable).insert(
          GroupDeliveryQueueTableCompanion.insert(
            groupId: 'GRP-TEST-1',
            messageId: 'MSG-INVALID-EPOCH',
            recipientPeerId: 'PEER-MEMBER-A',
            epoch: 0, // Invalid! epoch must be >= 1
            packetType: 'group_message',
            encryptedEnvelopeJson: '{"ciphertext":"data"}',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('13. Required indexes exist in SQLite schema', () async {
      final indexRows = await db.customSelect("SELECT name FROM sqlite_master WHERE type='index';").get();
      final indexNames = indexRows.map((r) => r.data['name'] as String).toSet();

      // GroupEpochOperationsTable indexes
      expect(indexNames.contains('idx_epoch_ops_group_id'), isTrue);
      expect(indexNames.contains('idx_epoch_ops_status'), isTrue);
      expect(indexNames.contains('idx_epoch_ops_group_seq'), isTrue);

      // GroupEpochSyncTable indexes
      expect(indexNames.contains('idx_epoch_sync_group_member'), isTrue);
      expect(indexNames.contains('idx_epoch_sync_prepare'), isTrue);
      expect(indexNames.contains('idx_epoch_sync_commit'), isTrue);
      expect(indexNames.contains('idx_epoch_sync_finalize'), isTrue);

      // GroupMessagePayloadsTable indexes
      expect(indexNames.contains('idx_payloads_created_at'), isTrue);
      expect(indexNames.contains('idx_payloads_expires_at'), isTrue);

      // GroupDeliveryQueueTable indexes
      expect(indexNames.contains('idx_group_queue_recipient_status'), isTrue);
      expect(indexNames.contains('idx_group_queue_group_epoch'), isTrue);
      expect(indexNames.contains('idx_group_queue_retry'), isTrue);
    });
  });

  group('Phase 9 Step 6.1 — Payload and Delivery Queue Field Verification Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-PAYLOAD-1',
          name: 'Payload Test Group',
          creatorId: 'PEER-CREATOR',
          adminId: 'PEER-CREATOR',
          epoch: const Value(1),
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-PAYLOAD-1',
          peerId: 'PEER-MEMBER-B',
          role: GroupRole.member.toJson(),
          status: GroupMemberStatus.active.toJson(),
          joinedAt: testNow,
          invitedBy: 'PEER-CREATOR',
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('14. Encrypted payloads and nonces store arbitrary binary blobs without mutation', () async {
      final binaryPayload = Uint8List.fromList(List.generate(256, (i) => (i * 7) % 256));
      final nonce = Uint8List.fromList(List.generate(12, (i) => (i * 13) % 256));
      final expires = testNow.add(const Duration(days: 30));

      await db.into(db.groupMessagePayloadsTable).insert(
        GroupMessagePayloadsTableCompanion.insert(
          groupId: 'GRP-PAYLOAD-1',
          messageId: 'MSG-BINARY-001',
          encryptedPayload: binaryPayload,
          nonce: nonce,
          createdAt: testNow,
          expiresAt: Value(expires),
        ),
      );

      final entry = await (db.select(db.groupMessagePayloadsTable)
            ..where((t) => t.groupId.equals('GRP-PAYLOAD-1') & t.messageId.equals('MSG-BINARY-001')))
          .getSingle();

      expect(entry.encryptedPayload, orderedEquals(binaryPayload));
      expect(entry.nonce, orderedEquals(nonce));
      expect(entry.expiresAt, isNotNull);
      expect(entry.expiresAt!.toUtc(), expires);
    });

    test('15. Failed queue entries persist with failureReason and retry scheduling', () async {
      final nextRetry = testNow.add(const Duration(seconds: 30));

      await db.into(db.groupDeliveryQueueTable).insert(
        GroupDeliveryQueueTableCompanion.insert(
          groupId: 'GRP-PAYLOAD-1',
          messageId: 'MSG-FAIL-001',
          recipientPeerId: 'PEER-MEMBER-B',
          epoch: 1,
          packetType: 'group_message',
          sessionId: const Value('SESSION-XYZ'),
          encryptedEnvelopeJson: '{"v":1,"enc":"secret_wire_bytes"}',
          status: const Value('failed'),
          failureReason: const Value('connection_timeout'),
          retryCount: const Value(3),
          nextRetryAt: Value(nextRetry),
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      final queueEntry = await (db.select(db.groupDeliveryQueueTable)
            ..where((t) => t.groupId.equals('GRP-PAYLOAD-1') & t.messageId.equals('MSG-FAIL-001')))
          .getSingle();

      expect(queueEntry.status, 'failed');
      expect(queueEntry.failureReason, 'connection_timeout');
      expect(queueEntry.retryCount, 3);
      expect(queueEntry.sessionId, 'SESSION-XYZ');
      expect(queueEntry.nextRetryAt!.toUtc(), nextRetry);
      expect(queueEntry.encryptedEnvelopeJson, '{"v":1,"enc":"secret_wire_bytes"}');
    });

    test('16. Nullable session IDs and nullable expiresAt work correctly on insert and query', () async {
      // Nullable sessionId on queue
      await db.into(db.groupDeliveryQueueTable).insert(
        GroupDeliveryQueueTableCompanion.insert(
          groupId: 'GRP-PAYLOAD-1',
          messageId: 'MSG-NULL-SESSION',
          recipientPeerId: 'PEER-MEMBER-B',
          epoch: 1,
          packetType: 'group_message',
          sessionId: const Value(null),
          encryptedEnvelopeJson: '{"enc":"no_session"}',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      final queueEntry = await (db.select(db.groupDeliveryQueueTable)
            ..where((t) => t.groupId.equals('GRP-PAYLOAD-1') & t.messageId.equals('MSG-NULL-SESSION')))
          .getSingle();
      expect(queueEntry.sessionId, isNull);
      expect(queueEntry.nextRetryAt, isNull);
      expect(queueEntry.failureReason, isNull);
      expect(queueEntry.retryCount, 0); // default 0

      // Nullable expiresAt on payload
      await db.into(db.groupMessagePayloadsTable).insert(
        GroupMessagePayloadsTableCompanion.insert(
          groupId: 'GRP-PAYLOAD-1',
          messageId: 'MSG-NO-EXPIRY',
          encryptedPayload: Uint8List.fromList([42]),
          nonce: Uint8List.fromList([1, 2, 3]),
          createdAt: testNow,
          expiresAt: const Value(null),
        ),
      );

      final payloadEntry = await (db.select(db.groupMessagePayloadsTable)
            ..where((t) => t.groupId.equals('GRP-PAYLOAD-1') & t.messageId.equals('MSG-NO-EXPIRY')))
          .getSingle();
      expect(payloadEntry.expiresAt, isNull);
    });
  });
}
