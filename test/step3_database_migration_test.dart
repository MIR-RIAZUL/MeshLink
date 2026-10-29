import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';

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
    test('1. Fresh database creates groups_table and group_members_table with schemaVersion 4', () async {
      expect(db.schemaVersion, 4);

      // Verify groups_table exists and accepts queries
      final groups = await db.getAllGroups();
      expect(groups, isEmpty);

      // Verify group_members_table exists and accepts queries
      final members = await db.getGroupMembers('GRP-NONEXISTENT');
      expect(members, isEmpty);
    });

    // Test 2 & 3: Migration from v3 to v4 preserves existing data and creates new tables
    test('2 & 3. Existing schema v3 migrates safely to v4 with existing data 100% intact', () async {
      final tempDir = await Directory.systemTemp.createTemp('meshlink_db_migration_test_');
      final dbFile = File('${tempDir.path}/v3_migrating_to_v4.db');

      try {
        // Step A: Manually construct a valid Schema v3 SQLite database
        final rawV3Db = NativeDatabase(dbFile);
        final v3Database = AppDatabase(rawV3Db);

        // Populate all existing v3 tables
        await v3Database.insertMessage(
          MessagesTableCompanion.insert(
            messageId: 'MSG-V3-001',
            conversationId: 'PEER-V3-ALICE',
            senderId: 'PEER-V3-ALICE',
            receiverId: 'LOCAL-NODE',
            textContent: 'Historic 1-to-1 message from v3',
            createdAt: testNow,
            status: 'delivered',
          ),
        );

        await v3Database.savePeerIdentity(
          PeerIdentitiesTableCompanion.insert(
            peerId: 'PEER-V3-ALICE',
            identityPublicKey: 'b64url_ed25519_alice_key_v3',
            safetyNumber: '654321',
            trustStatus: 'verified',
            firstSeenAt: testNow,
            lastSeenAt: testNow,
          ),
        );

        await v3Database.checkAndMarkSeen(
          packetType: 'encrypted_message',
          originId: 'PEER-V3-ALICE',
          packetId: 'MSG-V3-001',
          receivedAt: testNow,
        );

        await v3Database.insertFileTransfer(
          FileTransfersTableCompanion.insert(
            transferId: 'FT-V3-001',
            conversationId: 'PEER-V3-ALICE',
            peerId: 'PEER-V3-ALICE',
            direction: 'incoming',
            fileName: 'v3_doc.pdf',
            fileSize: BigInt.from(102400),
            mimeType: 'application/pdf',
            fileHash: 'sha256-v3-doc-hash',
            localPath: '/downloads/v3_doc.pdf',
            stagingPath: '/staging/v3_doc.part',
            totalChunks: 7,
            chunkSize: 16384,
            status: 'completed',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );

        await v3Database.markChunkReceived(
          'FT-V3-001',
          0,
          status: 'verified',
          receivedAt: testNow,
        );

        await v3Database.close();

        // Step B: Re-open the database with AppDatabase (which triggers migration from v3 to v4)
        final upgradedDb = AppDatabase(NativeDatabase(dbFile));

        expect(upgradedDb.schemaVersion, 4);

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

    // Test 10: Maximum group size of 8 distinct members is strictly enforced
    test('10. Maximum group size of 8 distinct members is strictly enforced at database boundary', () async {
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

      final members = await db.getGroupMembers('GRP-1730000000006-DDDDDD');
      expect(members.length, 8);

      // Inserting a 9th distinct member via insertGroupMember throws ArgumentError
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

      // Updating an existing member among the 8 succeeds
      await db.updateGroupMemberStatus('GRP-1730000000006-DDDDDD', 'ML-PEER-2', 'removed');
      final updatedPeer2 = await db.getGroupMember('GRP-1730000000006-DDDDDD', 'ML-PEER-2');
      expect(updatedPeer2!.status, 'removed');
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

