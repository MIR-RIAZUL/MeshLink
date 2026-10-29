import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';

class _V3LegacyDatabase extends GeneratedDatabase {
  _V3LegacyDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement('PRAGMA user_version = 3;');
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
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final testNow = DateTime.utc(2026, 10, 30, 2, 30, 0);

  group('Phase 9 Step 3 — Drift Database Schema v4 Migration & Group Persistence Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    // Test 1: Fresh database creates the new tables and reports schemaVersion 4
    test('1. Fresh database creates groups_table and group_members_table with schemaVersion 4 and foreign keys enabled', () async {
      expect(db.schemaVersion, 4);

      // Verify PRAGMA foreign_keys is enabled
      final fkResult = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      expect(fkResult.data.values.first, 1);

      // Verify groups_table exists and accepts queries
      final groups = await db.getAllGroups();
      expect(groups, isEmpty);

      // Verify group_members_table exists and accepts queries
      final members = await db.getGroupMembers('GRP-NONEXISTENT');
      expect(members, isEmpty);
    });

    // Test 2 & 3: Migration from genuine v3 to v4 preserves existing data and creates new tables
    test('2 & 3. Existing genuine schema v3 migrates safely to v4 with existing data 100% intact', () async {
      final tempDir = await Directory.systemTemp.createTemp('meshlink_db_migration_test_');
      final dbFile = File('${tempDir.path}/v3_migrating_to_v4.db');

      try {
        // Step A: Construct a genuine Schema v3 SQLite database on disk
        final v3Database = _V3LegacyDatabase(NativeDatabase(dbFile));

        // Populate all existing v3 tables using custom statements
        final nowUnixSecs = testNow.millisecondsSinceEpoch ~/ 1000;
        await v3Database.customStatement('''
          INSERT INTO messages_table (message_id, conversation_id, sender_id, receiver_id, text_content, created_at, status, retry_count)
          VALUES ('MSG-V3-001', 'PEER-V3-ALICE', 'PEER-V3-ALICE', 'LOCAL-NODE', 'Historic 1-to-1 message from v3', $nowUnixSecs, 'delivered', 0);
        ''');
        await v3Database.customStatement('''
          INSERT INTO peer_identities_table (peer_id, identity_public_key, safety_number, trust_status, protocol_version, first_seen_at, last_seen_at)
          VALUES ('PEER-V3-ALICE', 'b64url_ed25519_alice_key_v3', '654321', 'verified', 2, $nowUnixSecs, $nowUnixSecs);
        ''');
        await v3Database.customStatement('''
          INSERT INTO seen_packets_table (replay_key, packet_type, origin_id, received_at)
          VALUES ('encrypted_message:PEER-V3-ALICE:MSG-V3-001', 'encrypted_message', 'PEER-V3-ALICE', $nowUnixSecs);
        ''');
        await v3Database.customStatement('''
          INSERT INTO file_transfers_table (transfer_id, conversation_id, peer_id, direction, file_name, file_size, mime_type, file_hash, local_path, staging_path, total_chunks, chunk_size, status, created_at, updated_at)
          VALUES ('FT-V3-001', 'PEER-V3-ALICE', 'PEER-V3-ALICE', 'incoming', 'v3_doc.pdf', 102400, 'application/pdf', 'sha256-v3-doc-hash', '/downloads/v3_doc.pdf', '/staging/v3_doc.part', 7, 16384, 'completed', $nowUnixSecs, $nowUnixSecs);
        ''');
        await v3Database.customStatement('''
          INSERT INTO file_chunks_table (transfer_id, chunk_index, status, received_at)
          VALUES ('FT-V3-001', 0, 'verified', $nowUnixSecs);
        ''');

        // Verify pre-migration state: user_version is 3, group tables and triggers do NOT exist
        final versionRows = await v3Database.customSelect('PRAGMA user_version;').getSingle();
        expect(versionRows.data.values.first, 3);

        final tablesBefore = (await v3Database.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get())
            .map((r) => r.data['name'] as String)
            .toSet();
        expect(tablesBefore.contains('groups_table'), isFalse);
        expect(tablesBefore.contains('group_members_table'), isFalse);

        await v3Database.close();

        // Step B: Re-open the genuine v3 database with AppDatabase (which triggers migration from v3 to v4)
        final upgradedDb = AppDatabase(NativeDatabase(dbFile));

        expect(upgradedDb.schemaVersion, 4);

        // Verify that Drift ran onUpgrade and updated user_version to 4
        final versionAfter = await upgradedDb.customSelect('PRAGMA user_version;').getSingle();
        expect(versionAfter.data.values.first, 4);

        // Verify that groups_table and group_members_table now exist
        final tablesAfter = (await upgradedDb.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get())
            .map((r) => r.data['name'] as String)
            .toSet();
        expect(tablesAfter.contains('groups_table'), isTrue);
        expect(tablesAfter.contains('group_members_table'), isTrue);

        // Verify that triggers trg_group_members_limit and trg_group_members_limit_update exist
        final triggers = (await upgradedDb.customSelect("SELECT name FROM sqlite_master WHERE type='trigger';").get())
            .map((r) => r.data['name'] as String)
            .toSet();
        expect(triggers.contains('trg_group_members_limit'), isTrue);
        expect(triggers.contains('trg_group_members_limit_update'), isTrue);

        // Verify existing MessagesTable data is unchanged
        final messages = await upgradedDb.getMessagesForConversation('PEER-V3-ALICE');
        expect(messages.length, 1);
        expect(messages.first.messageId, 'MSG-V3-001');
        expect(messages.first.textContent, 'Historic 1-to-1 message from v3');
        expect(messages.first.status, 'delivered');

        // Verify existing PeerIdentitiesTable data is unchanged
        final peerIdentity = await upgradedDb.getPeerIdentity('PEER-V3-ALICE');
        expect(peerIdentity, isNotNull);
        expect(peerIdentity!.identityPublicKey, 'b64url_ed25519_alice_key_v3');
        expect(peerIdentity.safetyNumber, '654321');

        // Verify existing SeenPacketsTable data is unchanged
        final hasSeen = await upgradedDb.hasSeenPacket('encrypted_message:PEER-V3-ALICE:MSG-V3-001');
        expect(hasSeen, isTrue);

        // Verify existing FileTransfersTable data is unchanged
        final transfer = await upgradedDb.getFileTransfer('FT-V3-001');
        expect(transfer, isNotNull);
        expect(transfer!.fileName, 'v3_doc.pdf');
        expect(transfer.status, 'completed');
        expect(transfer.fileSize, BigInt.from(102400));

        // Verify existing FileChunksTable data is unchanged
        final chunks = await upgradedDb.getFileChunks('FT-V3-001');
        expect(chunks.length, 1);
        expect(chunks.first.status, 'verified');

        // Step C: Verify new v4 group tables work seamlessly on the migrated database
        final groupRowId = await upgradedDb.insertGroup(
          GroupsTableCompanion.insert(
            groupId: 'GRP-1730000000000-A1B2C3',
            name: 'Migrated Group',
            creatorId: 'LOCAL-NODE',
            adminId: 'LOCAL-NODE',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );
        expect(groupRowId, greaterThan(0));

        final retrievedGroup = await upgradedDb.getGroup('GRP-1730000000000-A1B2C3');
        expect(retrievedGroup, isNotNull);
        expect(retrievedGroup!.name, 'Migrated Group');

        await upgradedDb.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    // Test 4: Groups can be inserted and retrieved with all fields intact
    test('4. Groups can be inserted and retrieved with all fields intact', () async {
      final now = DateTime.utc(2026, 10, 30, 10, 0, 0);
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000001-FFFFFF',
          name: 'Tactical Recon Group',
          creatorId: 'ML-ALPHA',
          adminId: 'ML-ALPHA',
          epoch: const Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final group = await db.getGroup('GRP-1730000000001-FFFFFF');
      expect(group, isNotNull);
      expect(group!.groupId, 'GRP-1730000000001-FFFFFF');
      expect(group.name, 'Tactical Recon Group');
      expect(group.creatorId, 'ML-ALPHA');
      expect(group.adminId, 'ML-ALPHA');
      expect(group.epoch, 1);
      expect(group.createdAt.toUtc(), now);
      expect(group.updatedAt.toUtc(), now);

      final allGroups = await db.getAllGroups();
      expect(allGroups.length, 1);
      expect(allGroups.first.groupId, 'GRP-1730000000001-FFFFFF');
    });

    // Test 5: Group members can be inserted and retrieved
    test('5. Group members can be inserted and retrieved with role and status', () async {
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000002-AAAAAA',
          name: 'Squad 1',
          creatorId: 'ML-LEADER',
          adminId: 'ML-LEADER',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Insert creator as admin
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000002-AAAAAA',
          peerId: 'ML-LEADER',
          role: GroupRole.admin.toJson(),
          status: GroupMemberStatus.active.toJson(),
          joinedAt: testNow,
          invitedBy: 'ML-LEADER',
        ),
      );

      // Insert invited peer as pendingInvite
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000002-AAAAAA',
          peerId: 'ML-SCOUT',
          role: GroupRole.member.toJson(),
          status: GroupMemberStatus.pendingInvite.toJson(),
          joinedAt: testNow,
          invitedBy: 'ML-LEADER',
        ),
      );

      final allMembers = await db.getGroupMembers('GRP-1730000000002-AAAAAA');
      expect(allMembers.length, 2);

      final activeOnly = await db.getGroupMembers('GRP-1730000000002-AAAAAA', activeOnly: true);
      expect(activeOnly.length, 1);
      expect(activeOnly.first.peerId, 'ML-LEADER');

      final scout = await db.getGroupMember('GRP-1730000000002-AAAAAA', 'ML-SCOUT');
      expect(scout, isNotNull);
      expect(scout!.role, 'member');
      expect(scout.status, 'pendingInvite');
      expect(scout.invitedBy, 'ML-LEADER');
    });

    // Test 6: Duplicate (groupId, peerId) records are rejected by primary key constraint
    test('6. Duplicate (groupId, peerId) records violate primary key on raw insert and update cleanly on conflict', () async {
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000003-BBBBBB',
          name: 'Security Squad',
          creatorId: 'ML-LEAD',
          adminId: 'ML-LEAD',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Insert initial member record
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000003-BBBBBB',
          peerId: 'ML-OFFICER',
          role: 'member',
          status: 'pendingInvite',
          joinedAt: testNow,
          invitedBy: 'ML-LEAD',
        ),
      );

      // Raw insert of same (groupId, peerId) without conflict handling fails primary key constraint
      expect(
        () async => db.into(db.groupMembersTable).insert(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000003-BBBBBB',
            peerId: 'ML-OFFICER',
            role: 'admin',
            status: 'active',
            joinedAt: testNow,
            invitedBy: 'ML-LEAD',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // insertGroupMember uses insertOnConflictUpdate and updates the member cleanly
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000003-BBBBBB',
          peerId: 'ML-OFFICER',
          role: 'admin',
          status: 'active',
          joinedAt: testNow,
          invitedBy: 'ML-LEAD',
        ),
      );

      final members = await db.getGroupMembers('GRP-1730000000003-BBBBBB');
      expect(members.length, 1);
      expect(members.first.role, 'admin');
      expect(members.first.status, 'active');
    });

    // Test 7: Foreign-key violations are rejected
    test('7. Inserting member for non-existent group violates foreign-key constraint', () async {
      expect(
        () async => db.insertGroupMember(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000099-NONEXIST',
            peerId: 'ML-ORPHAN',
            role: 'member',
            status: 'active',
            joinedAt: testNow,
            invitedBy: 'ML-NONE',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    // Test 8: Deleting a group cascades to its members and preserves other groups
    test('8. Deleting a group cascades to its members without affecting other groups', () async {
      // Group A
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000004-AAAAAA',
          name: 'Group A',
          creatorId: 'ML-USER-A',
          adminId: 'ML-USER-A',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000004-AAAAAA',
          peerId: 'ML-USER-A',
          role: 'admin',
          status: 'active',
          joinedAt: testNow,
          invitedBy: 'ML-USER-A',
        ),
      );
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000004-AAAAAA',
          peerId: 'ML-USER-B',
          role: 'member',
          status: 'active',
          joinedAt: testNow,
          invitedBy: 'ML-USER-A',
        ),
      );

      // Group B
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000004-BBBBBB',
          name: 'Group B',
          creatorId: 'ML-USER-C',
          adminId: 'ML-USER-C',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000004-BBBBBB',
          peerId: 'ML-USER-C',
          role: 'admin',
          status: 'active',
          joinedAt: testNow,
          invitedBy: 'ML-USER-C',
        ),
      );

      expect((await db.getGroupMembers('GRP-1730000000004-AAAAAA')).length, 2);
      expect((await db.getGroupMembers('GRP-1730000000004-BBBBBB')).length, 1);

      // Delete Group A
      final deletedCount = await db.deleteGroup('GRP-1730000000004-AAAAAA');
      expect(deletedCount, 1);

      // Group A and its members must be gone
      expect(await db.getGroup('GRP-1730000000004-AAAAAA'), isNull);
      expect((await db.getGroupMembers('GRP-1730000000004-AAAAAA')).isEmpty, isTrue);

      // Group B and its members must remain completely intact
      expect(await db.getGroup('GRP-1730000000004-BBBBBB'), isNotNull);
      expect((await db.getGroupMembers('GRP-1730000000004-BBBBBB')).length, 1);
    });

    // Test 9: Invalid role and status values are rejected by CHECK constraints
    test('9. Invalid role or status strings violate SQLite CHECK constraints', () async {
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000005-CCCCCC',
          name: 'Check Constraint Test',
          creatorId: 'ML-ADMIN',
          adminId: 'ML-ADMIN',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Invalid role 'superuser' fails CHECK (role IN ('admin', 'member'))
      expect(
        () async => db.insertGroupMember(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000005-CCCCCC',
            peerId: 'ML-HACKER',
            role: 'superuser',
            status: 'active',
            joinedAt: testNow,
            invitedBy: 'ML-ADMIN',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // Invalid status 'banned' fails CHECK (status IN ('active', 'pendingInvite', 'removed'))
      expect(
        () async => db.insertGroupMember(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000005-CCCCCC',
            peerId: 'ML-HACKER',
            role: 'member',
            status: 'banned',
            joinedAt: testNow,
            invitedBy: 'ML-ADMIN',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    // Test 10: Maximum group size of 8 distinct active/pending members is strictly enforced
    test('10. Maximum group size of 8 distinct members is strictly enforced under active-membership policy', () async {
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000006-DDDDDD',
          name: 'Eight Max Group',
          creatorId: 'ML-CREATOR',
          adminId: 'ML-CREATOR',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      // Insert 8 distinct members (1 creator + 7 members)
      for (int i = 1; i <= 8; i++) {
        await db.insertGroupMember(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000006-DDDDDD',
            peerId: 'ML-PEER-$i',
            role: i == 1 ? 'admin' : 'member',
            status: 'active',
            joinedAt: testNow,
            invitedBy: 'ML-CREATOR',
          ),
        );
      }

      final activeMembers = await db.getGroupMembers('GRP-1730000000006-DDDDDD', activeOnly: true);
      expect(activeMembers.length, 8);

      // Inserting a 9th distinct member as 'active' via insertGroupMember throws ArgumentError
      expect(
        () async => db.insertGroupMember(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000006-DDDDDD',
            peerId: 'ML-PEER-9',
            role: 'member',
            status: 'active',
            joinedAt: testNow,
            invitedBy: 'ML-CREATOR',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Inserting a 9th distinct member as 'pendingInvite' via insertGroupMember throws ArgumentError
      expect(
        () async => db.insertGroupMember(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000006-DDDDDD',
            peerId: 'ML-PEER-9',
            role: 'member',
            status: 'pendingInvite',
            joinedAt: testNow,
            invitedBy: 'ML-CREATOR',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Inserting a 9th distinct member via raw SQL insert violates SQLite trigger
      expect(
        () async => db.into(db.groupMembersTable).insert(
          GroupMembersTableCompanion.insert(
            groupId: 'GRP-1730000000006-DDDDDD',
            peerId: 'ML-PEER-9',
            role: 'member',
            status: 'active',
            joinedAt: testNow,
            invitedBy: 'ML-CREATOR',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // Updating an existing member to 'removed' succeeds and frees an active slot
      await db.updateGroupMemberStatus('GRP-1730000000006-DDDDDD', 'ML-PEER-2', 'removed');
      final updatedPeer2 = await db.getGroupMember('GRP-1730000000006-DDDDDD', 'ML-PEER-2');
      expect(updatedPeer2!.status, 'removed');

      final activeAfterRemoval = await db.getGroupMembers('GRP-1730000000006-DDDDDD', activeOnly: true);
      expect(activeAfterRemoval.length, 7);

      // Inserting a replacement member now succeeds (7 + 1 = 8 active members, 1 removed member, 9 total rows)
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000006-DDDDDD',
          peerId: 'ML-PEER-REPLACEMENT',
          role: 'member',
          status: 'active',
          joinedAt: testNow,
          invitedBy: 'ML-CREATOR',
        ),
      );

      final totalRows = await db.getGroupMembers('GRP-1730000000006-DDDDDD');
      expect(totalRows.length, 9);
      final activeNow = await db.getGroupMembers('GRP-1730000000006-DDDDDD', activeOnly: true);
      expect(activeNow.length, 8);

      // Now with 8 active members, re-activating the removed member 'ML-PEER-2' fails in Dart
      expect(
        () async => db.updateGroupMemberStatus('GRP-1730000000006-DDDDDD', 'ML-PEER-2', 'active'),
        throwsA(isA<ArgumentError>()),
      );

      // Raw SQL update to re-activate 'ML-PEER-2' is blocked by SQLite trigger
      expect(
        () async => db.customStatement(
          "UPDATE group_members_table SET status = 'active' WHERE group_id = 'GRP-1730000000006-DDDDDD' AND peer_id = 'ML-PEER-2';",
        ),
        throwsA(isA<SqliteException>()),
      );

      // Removing another member frees an active slot
      await db.updateGroupMemberStatus('GRP-1730000000006-DDDDDD', 'ML-PEER-3', 'removed');

      // Now re-activating 'ML-PEER-2' succeeds
      await db.updateGroupMemberStatus('GRP-1730000000006-DDDDDD', 'ML-PEER-2', 'active');
      final reactivatedPeer2 = await db.getGroupMember('GRP-1730000000006-DDDDDD', 'ML-PEER-2');
      expect(reactivatedPeer2!.status, 'active');
    });

    // Test 11: Existing database operations coexist cleanly with new group tables
    test('11. Existing 1-to-1 messages, file transfers, and peer identities coexist cleanly', () async {
      // 1-to-1 Message
      await db.insertMessage(
        MessagesTableCompanion.insert(
          messageId: 'MSG-COEXIST-1',
          conversationId: 'ML-PEER-Z',
          senderId: 'ML-LOCAL',
          receiverId: 'ML-PEER-Z',
          textContent: 'Regular 1-to-1 chat',
          createdAt: testNow,
          status: 'sent',
        ),
      );

      // Group & Member
      await db.insertGroup(
        GroupsTableCompanion.insert(
          groupId: 'GRP-1730000000007-EEEEEE',
          name: 'Coexistence Group',
          creatorId: 'ML-LOCAL',
          adminId: 'ML-LOCAL',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );
      await db.insertGroupMember(
        GroupMembersTableCompanion.insert(
          groupId: 'GRP-1730000000007-EEEEEE',
          peerId: 'ML-LOCAL',
          role: 'admin',
          status: 'active',
          joinedAt: testNow,
          invitedBy: 'ML-LOCAL',
        ),
      );

      // Verify 1-to-1 message
      final msg = await db.getMessagesForConversation('ML-PEER-Z');
      expect(msg.length, 1);
      expect(msg.first.textContent, 'Regular 1-to-1 chat');

      // Verify group
      final group = await db.getGroup('GRP-1730000000007-EEEEEE');
      expect(group, isNotNull);
      expect(group!.name, 'Coexistence Group');
    });
  });
}

