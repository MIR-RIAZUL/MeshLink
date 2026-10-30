import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/group_repository_impl.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';
import 'package:meshlink/features/messages/domain/repositories/group_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testNow = DateTime.utc(2026, 10, 30, 20, 0, 0);

  group('Phase 9 Step 4 — GroupRepository & Persistence Tests', () {
    late AppDatabase db;
    late DriftGroupRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftGroupRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    // ==========================================
    // 1. Group Operations
    // ==========================================

    group('Group Operations', () {
      test('1. Create and retrieve a group (creator is automatically added as active admin)', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000001-A00001',
          name: 'Alpha Squad',
          creatorId: 'PEER-ALICE',
          createdAt: testNow,
        );

        await repo.createGroup(group);

        final retrieved = await repo.getGroup('GRP-1730000000001-A00001');
        expect(retrieved, isNotNull);
        expect(retrieved!.groupId, 'GRP-1730000000001-A00001');
        expect(retrieved.name, 'Alpha Squad');
        expect(retrieved.creatorId, 'PEER-ALICE');
        expect(retrieved.adminId, 'PEER-ALICE');
        expect(retrieved.epoch, 1);
        expect(retrieved.createdAt, testNow);
        expect(retrieved.updatedAt, testNow);

        // Verify creator was atomically added as admin member
        final members = await repo.getGroupMembers('GRP-1730000000001-A00001');
        expect(members.length, 1);
        final creator = members.first;
        expect(creator.peerId, 'PEER-ALICE');
        expect(creator.role, GroupRole.admin);
        expect(creator.status, GroupMemberStatus.active);
        expect(creator.invitedBy, 'PEER-ALICE');
      });

      test('2. Create group with addCreatorAsMember: false creates only group entity', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000002-A00002',
          name: 'Bravo Squad',
          creatorId: 'PEER-BOB',
          createdAt: testNow,
        );

        await repo.createGroup(group, addCreatorAsMember: false);

        final retrieved = await repo.getGroup('GRP-1730000000002-A00002');
        expect(retrieved, isNotNull);

        final members = await repo.getGroupMembers('GRP-1730000000002-A00002');
        expect(members, isEmpty);
      });

      test('3. Creating a duplicate group throws DuplicateGroupException', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000003-A00003',
          name: 'Charlie Squad',
          creatorId: 'PEER-CHARLIE',
          createdAt: testNow,
        );

        await repo.createGroup(group);

        expect(
          () => repo.createGroup(group),
          throwsA(isA<DuplicateGroupException>()),
        );
      });

      test('4. Retrieve all groups orders by createdAt descending', () async {
        final g1 = Group.create(
          groupId: 'GRP-1730000000010-000001',
          name: 'Old Group',
          creatorId: 'PEER-1',
          createdAt: testNow.subtract(const Duration(hours: 2)),
        );
        final g2 = Group.create(
          groupId: 'GRP-1730000000020-000002',
          name: 'New Group',
          creatorId: 'PEER-2',
          createdAt: testNow,
        );

        await repo.createGroup(g1);
        await repo.createGroup(g2);

        final all = await repo.getAllGroups();
        expect(all.length, 2);
        expect(all[0].groupId, g2.groupId);
        expect(all[1].groupId, g1.groupId);
      });

      test('5. Update permitted metadata modifies name, adminId, epoch, updatedAt', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000004-A00004',
          name: 'Initial Name',
          creatorId: 'PEER-ADMIN',
          createdAt: testNow,
        );
        await repo.createGroup(group);

        // Add successor member
        await repo.addMember(
          GroupMember(
            groupId: group.groupId,
            peerId: 'PEER-SUCCESSOR',
            role: GroupRole.member,
            status: GroupMemberStatus.active,
            joinedAt: testNow,
            invitedBy: 'PEER-ADMIN',
          ),
        );

        final updatedTime = testNow.add(const Duration(minutes: 5));
        final updatedGroup = group.copyWith(
          name: 'Renamed Squad',
          adminId: 'PEER-SUCCESSOR',
          epoch: 2,
          updatedAt: updatedTime,
        );

        await repo.updateGroup(updatedGroup);

        final refreshed = await repo.getGroup(group.groupId);
        expect(refreshed, isNotNull);
        expect(refreshed!.name, 'Renamed Squad');
        expect(refreshed.adminId, 'PEER-SUCCESSOR');
        expect(refreshed.epoch, 2);
        expect(refreshed.updatedAt, updatedTime);
      });

      test('6. Update group throws GroupNotFoundException if group does not exist', () async {
        final phantomGroup = Group(
          groupId: 'GRP-1730000000999-000000',
          name: 'Phantom',
          creatorId: 'PEER-NONE',
          adminId: 'PEER-NONE',
          epoch: 1,
          createdAt: testNow,
          updatedAt: testNow,
        );

        expect(
          () => repo.updateGroup(phantomGroup),
          throwsA(isA<GroupNotFoundException>()),
        );
      });

      test('7. Update group throws InvalidGroupDataException if attempting to decrement epoch', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000005-A00005',
          name: 'Epoch Group',
          creatorId: 'PEER-ADMIN',
          createdAt: testNow,
        );
        await repo.createGroup(group);

        // Update to epoch 3
        await repo.updateGroup(group.copyWith(epoch: 3, updatedAt: testNow.add(const Duration(minutes: 1))));

        // Attempt to decrement to epoch 2
        final decremented = group.copyWith(epoch: 2, updatedAt: testNow.add(const Duration(minutes: 2)));
        expect(
          () => repo.updateGroup(decremented),
          throwsA(isA<InvalidGroupDataException>()),
        );
      });

      test('8. updateGroupMetadata convenience helper updates specific fields', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000006-A00006',
          name: 'Original',
          creatorId: 'PEER-CREATOR',
          createdAt: testNow,
        );
        await repo.createGroup(group);

        await repo.updateGroupMetadata(
          groupId: group.groupId,
          name: 'Convenience Renamed',
          updatedAt: testNow.add(const Duration(minutes: 1)),
        );

        final fetched = await repo.getGroup(group.groupId);
        expect(fetched!.name, 'Convenience Renamed');
      });

      test('9. Delete group deletes group and cascades deletion to all its members', () async {
        final g1 = Group.create(
          groupId: 'GRP-1730000000007-111111',
          name: 'Group To Delete',
          creatorId: 'PEER-ADMIN-1',
          createdAt: testNow,
        );
        final g2 = Group.create(
          groupId: 'GRP-1730000000007-222222',
          name: 'Preserved Group',
          creatorId: 'PEER-ADMIN-2',
          createdAt: testNow,
        );

        await repo.createGroup(g1);
        await repo.createGroup(g2);

        await repo.addPendingInvite(
          groupId: g1.groupId,
          peerId: 'PEER-INVITEE-1',
          invitedBy: 'PEER-ADMIN-1',
        );
        await repo.addPendingInvite(
          groupId: g2.groupId,
          peerId: 'PEER-INVITEE-2',
          invitedBy: 'PEER-ADMIN-2',
        );

        expect((await repo.getGroupMembers(g1.groupId)).length, 2);
        expect((await repo.getGroupMembers(g2.groupId)).length, 2);

        // Delete g1
        await repo.deleteGroup(g1.groupId);

        // g1 is gone
        expect(await repo.getGroup(g1.groupId), isNull);
        expect(await repo.getGroupMembers(g1.groupId), isEmpty);

        // g2 and its members remain completely intact
        expect(await repo.getGroup(g2.groupId), isNotNull);
        expect((await repo.getGroupMembers(g2.groupId)).length, 2);
      });

      test('10. Delete group throws GroupNotFoundException when group does not exist', () async {
        expect(
          () => repo.deleteGroup('GRP-1730000000999-000000'),
          throwsA(isA<GroupNotFoundException>()),
        );
      });
    });

    // ==========================================
    // 2. Member Operations
    // ==========================================

    group('Member Operations', () {
      late Group testGroup;

      setUp(() async {
        testGroup = Group.create(
          groupId: 'GRP-1730000000020-B00001',
          name: 'Member Operations Squad',
          creatorId: 'PEER-CREATOR',
          createdAt: testNow,
        );
        await repo.createGroup(testGroup);
      });

      test('11. addPendingInvite adds member in pendingInvite status', () async {
        await repo.addPendingInvite(
          groupId: testGroup.groupId,
          peerId: 'PEER-PENDING',
          invitedBy: 'PEER-CREATOR',
        );

        final member = await repo.getGroupMember(testGroup.groupId, 'PEER-PENDING');
        expect(member, isNotNull);
        expect(member!.peerId, 'PEER-PENDING');
        expect(member.role, GroupRole.member);
        expect(member.status, GroupMemberStatus.pendingInvite);
        expect(member.isPendingInvite, isTrue);
        expect(member.isActive, isFalse);
      });

      test('12. addMember adds member with specified role and status', () async {
        final member = GroupMember(
          groupId: testGroup.groupId,
          peerId: 'PEER-OFFICER',
          role: GroupRole.admin,
          status: GroupMemberStatus.active,
          joinedAt: testNow,
          invitedBy: 'PEER-CREATOR',
        );

        await repo.addMember(member);

        final fetched = await repo.getGroupMember(testGroup.groupId, 'PEER-OFFICER');
        expect(fetched, isNotNull);
        expect(fetched!.role, GroupRole.admin);
        expect(fetched.status, GroupMemberStatus.active);
        expect(fetched.isActive, isTrue);
      });

      test('13. getGroupMembers returns all members ordered by joinedAt ascending', () async {
        await repo.addPendingInvite(
          groupId: testGroup.groupId,
          peerId: 'PEER-FIRST',
          invitedBy: 'PEER-CREATOR',
          joinedAt: testNow.add(const Duration(seconds: 10)),
        );
        await repo.addPendingInvite(
          groupId: testGroup.groupId,
          peerId: 'PEER-SECOND',
          invitedBy: 'PEER-CREATOR',
          joinedAt: testNow.add(const Duration(seconds: 20)),
        );

        final members = await repo.getGroupMembers(testGroup.groupId);
        expect(members.length, 3); // creator + 2
        expect(members[0].peerId, 'PEER-CREATOR');
        expect(members[1].peerId, 'PEER-FIRST');
        expect(members[2].peerId, 'PEER-SECOND');
      });

      test('14. getMembersByStatus filters accurately', () async {
        await repo.addPendingInvite(
          groupId: testGroup.groupId,
          peerId: 'PEER-PENDING-1',
          invitedBy: 'PEER-CREATOR',
        );
        await repo.addMember(
          GroupMember(
            groupId: testGroup.groupId,
            peerId: 'PEER-ACTIVE-1',
            role: GroupRole.member,
            status: GroupMemberStatus.active,
            joinedAt: testNow,
            invitedBy: 'PEER-CREATOR',
          ),
        );
        await repo.addMember(
          GroupMember(
            groupId: testGroup.groupId,
            peerId: 'PEER-REMOVED-1',
            role: GroupRole.member,
            status: GroupMemberStatus.removed,
            joinedAt: testNow,
            invitedBy: 'PEER-CREATOR',
          ),
        );

        final active = await repo.getMembersByStatus(testGroup.groupId, GroupMemberStatus.active);
        expect(active.length, 2); // creator + PEER-ACTIVE-1

        final pending = await repo.getMembersByStatus(testGroup.groupId, GroupMemberStatus.pendingInvite);
        expect(pending.length, 1);
        expect(pending.first.peerId, 'PEER-PENDING-1');

        final removed = await repo.getMembersByStatus(testGroup.groupId, GroupMemberStatus.removed);
        expect(removed.length, 1);
        expect(removed.first.peerId, 'PEER-REMOVED-1');
      });

      test('15. updateMemberStatus transitions member status', () async {
        await repo.addPendingInvite(
          groupId: testGroup.groupId,
          peerId: 'PEER-ACCEPTING',
          invitedBy: 'PEER-CREATOR',
        );

        await repo.updateMemberStatus(testGroup.groupId, 'PEER-ACCEPTING', GroupMemberStatus.active);

        final updated = await repo.getGroupMember(testGroup.groupId, 'PEER-ACCEPTING');
        expect(updated!.status, GroupMemberStatus.active);
        expect(updated.isActive, isTrue);
      });

      test('16. updateMemberStatus throws GroupMemberNotFoundException for nonexistent member', () async {
        expect(
          () => repo.updateMemberStatus(testGroup.groupId, 'PEER-GHOST', GroupMemberStatus.active),
          throwsA(isA<GroupMemberNotFoundException>()),
        );
      });

      test('17. removeMember and markMemberRemoved transition member to removed', () async {
        await repo.addMember(
          GroupMember(
            groupId: testGroup.groupId,
            peerId: 'PEER-TO-REMOVE',
            role: GroupRole.member,
            status: GroupMemberStatus.active,
            joinedAt: testNow,
            invitedBy: 'PEER-CREATOR',
          ),
        );

        await repo.removeMember(testGroup.groupId, 'PEER-TO-REMOVE');

        final removed = await repo.getGroupMember(testGroup.groupId, 'PEER-TO-REMOVE');
        expect(removed!.status, GroupMemberStatus.removed);
        expect(removed.isRemoved, isTrue);
        expect(removed.isActive, isFalse);

        // markMemberRemoved alias
        await repo.addMember(
          GroupMember(
            groupId: testGroup.groupId,
            peerId: 'PEER-TO-REMOVE-2',
            role: GroupRole.member,
            status: GroupMemberStatus.active,
            joinedAt: testNow,
            invitedBy: 'PEER-CREATOR',
          ),
        );
        await repo.markMemberRemoved(testGroup.groupId, 'PEER-TO-REMOVE-2');
        final removed2 = await repo.getGroupMember(testGroup.groupId, 'PEER-TO-REMOVE-2');
        expect(removed2!.isRemoved, isTrue);
      });

      test('18. deleteMemberRecord completely purges member record', () async {
        await repo.addPendingInvite(
          groupId: testGroup.groupId,
          peerId: 'PEER-PURGE',
          invitedBy: 'PEER-CREATOR',
        );

        await repo.deleteMemberRecord(testGroup.groupId, 'PEER-PURGE');

        expect(await repo.getGroupMember(testGroup.groupId, 'PEER-PURGE'), isNull);
      });
    });

    // ==========================================
    // 3. Membership Rules & Capacity Policy
    // ==========================================

    group('Membership Rules & Capacity Policy', () {
      late Group group;

      setUp(() async {
        group = Group.create(
          groupId: 'GRP-1730000000030-C00001',
          name: 'Capacity Test Group',
          creatorId: 'PEER-CREATOR',
          createdAt: testNow,
        );
        // Creates group with 1 active member (PEER-CREATOR)
        await repo.createGroup(group);
      });

      test('19. Reject a 9th distinct active/pending participant (8 distinct max including creator)', () async {
        // Add 7 additional active members (reaching 1 creator + 7 = 8 total)
        for (int i = 1; i <= 7; i++) {
          await repo.addMember(
            GroupMember(
              groupId: group.groupId,
              peerId: 'PEER-$i',
              role: GroupRole.member,
              status: GroupMemberStatus.active,
              joinedAt: testNow,
              invitedBy: 'PEER-CREATOR',
            ),
          );
        }

        final members = await repo.getGroupMembers(group.groupId);
        expect(members.length, 8);

        // Attempting to add 9th distinct active member throws GroupCapacityExceededException
        expect(
          () => repo.addMember(
            GroupMember(
              groupId: group.groupId,
              peerId: 'PEER-9',
              role: GroupRole.member,
              status: GroupMemberStatus.active,
              joinedAt: testNow,
              invitedBy: 'PEER-CREATOR',
            ),
          ),
          throwsA(isA<GroupCapacityExceededException>()),
        );

        // Attempting to add 9th distinct member as pendingInvite throws GroupCapacityExceededException
        expect(
          () => repo.addPendingInvite(
            groupId: group.groupId,
            peerId: 'PEER-9',
            invitedBy: 'PEER-CREATOR',
          ),
          throwsA(isA<GroupCapacityExceededException>()),
        );
      });

      test('20. Pending invitations reserve capacity in the group', () async {
        // Add 6 active members + 1 pending invitation (total 1 creator + 6 + 1 = 8)
        for (int i = 1; i <= 6; i++) {
          await repo.addMember(
            GroupMember(
              groupId: group.groupId,
              peerId: 'PEER-ACT-$i',
              role: GroupRole.member,
              status: GroupMemberStatus.active,
              joinedAt: testNow,
              invitedBy: 'PEER-CREATOR',
            ),
          );
        }
        await repo.addPendingInvite(
          groupId: group.groupId,
          peerId: 'PEER-PEND-7',
          invitedBy: 'PEER-CREATOR',
        );

        // Capacity is full at 8. Another invite is rejected.
        expect(
          () => repo.addPendingInvite(
            groupId: group.groupId,
            peerId: 'PEER-OVERFLOW',
            invitedBy: 'PEER-CREATOR',
          ),
          throwsA(isA<GroupCapacityExceededException>()),
        );
      });

      test('21. Removed members do NOT reserve capacity and a new member can be added', () async {
        // Fill to 8 members
        for (int i = 1; i <= 7; i++) {
          await repo.addMember(
            GroupMember(
              groupId: group.groupId,
              peerId: 'PEER-$i',
              role: GroupRole.member,
              status: GroupMemberStatus.active,
              joinedAt: testNow,
              invitedBy: 'PEER-CREATOR',
            ),
          );
        }

        // Remove PEER-1
        await repo.removeMember(group.groupId, 'PEER-1');

        final activeMembers = await repo.getMembersByStatus(group.groupId, GroupMemberStatus.active);
        expect(activeMembers.length, 7);

        // Now adding a replacement member succeeds
        await repo.addMember(
          GroupMember(
            groupId: group.groupId,
            peerId: 'PEER-REPLACEMENT',
            role: GroupRole.member,
            status: GroupMemberStatus.active,
            joinedAt: testNow,
            invitedBy: 'PEER-CREATOR',
          ),
        );

        final allMembers = await repo.getGroupMembers(group.groupId);
        expect(allMembers.length, 9); // 8 active + 1 removed audit entry
        final activeNow = await repo.getMembersByStatus(group.groupId, GroupMemberStatus.active);
        expect(activeNow.length, 8);
      });

      test('22. Reactivating a removed member is rejected if group is already at full capacity', () async {
        // Fill to 8 members
        for (int i = 1; i <= 7; i++) {
          await repo.addMember(
            GroupMember(
              groupId: group.groupId,
              peerId: 'PEER-$i',
              role: GroupRole.member,
              status: GroupMemberStatus.active,
              joinedAt: testNow,
              invitedBy: 'PEER-CREATOR',
            ),
          );
        }

        // Remove PEER-1
        await repo.removeMember(group.groupId, 'PEER-1');

        // Add PEER-REPLACEMENT to fill capacity back to 8
        await repo.addMember(
          GroupMember(
            groupId: group.groupId,
            peerId: 'PEER-REPLACEMENT',
            role: GroupRole.member,
            status: GroupMemberStatus.active,
            joinedAt: testNow,
            invitedBy: 'PEER-CREATOR',
          ),
        );

        // Attempting to reactivate PEER-1 back to active throws GroupCapacityExceededException
        expect(
          () => repo.updateMemberStatus(group.groupId, 'PEER-1', GroupMemberStatus.active),
          throwsA(isA<GroupCapacityExceededException>()),
        );

        // Attempting to reactivate PEER-1 to pendingInvite also throws GroupCapacityExceededException
        expect(
          () => repo.updateMemberStatus(group.groupId, 'PEER-1', GroupMemberStatus.pendingInvite),
          throwsA(isA<GroupCapacityExceededException>()),
        );
      });

      test('23. Reject duplicate membership without silently overwriting existing records', () async {
        await repo.addPendingInvite(
          groupId: group.groupId,
          peerId: 'PEER-ALICE',
          invitedBy: 'PEER-CREATOR',
        );

        // Attempting to add duplicate via addMember throws DuplicateGroupMemberException
        expect(
          () => repo.addMember(
            GroupMember(
              groupId: group.groupId,
              peerId: 'PEER-ALICE',
              role: GroupRole.admin,
              status: GroupMemberStatus.active,
              joinedAt: testNow,
              invitedBy: 'PEER-HACKER',
            ),
          ),
          throwsA(isA<DuplicateGroupMemberException>()),
        );

        // Verify PEER-ALICE record was NOT overwritten
        final alice = await repo.getGroupMember(group.groupId, 'PEER-ALICE');
        expect(alice!.role, GroupRole.member);
        expect(alice.status, GroupMemberStatus.pendingInvite);
        expect(alice.invitedBy, 'PEER-CREATOR');

        // Attempting to add duplicate via addPendingInvite throws DuplicateGroupMemberException
        expect(
          () => repo.addPendingInvite(
            groupId: group.groupId,
            peerId: 'PEER-ALICE',
            invitedBy: 'PEER-CREATOR',
          ),
          throwsA(isA<DuplicateGroupMemberException>()),
        );
      });
    });

    // ==========================================
    // 4. Data Integrity & Resilience
    // ==========================================

    group('Data Integrity & Resilience', () {
      test('24. UTC timestamp round-tripping for groups and members', () async {
        final utcCreated = DateTime.utc(2026, 10, 30, 15, 30, 45);
        final group = Group.create(
          groupId: 'GRP-1730000000040-D00001',
          name: 'Timestamp Squad',
          creatorId: 'PEER-TIME',
          createdAt: utcCreated,
        );

        await repo.createGroup(group);
        final fetched = await repo.getGroup(group.groupId);
        expect(fetched!.createdAt.isUtc, isTrue);
        expect(fetched.createdAt, utcCreated);
        expect(fetched.updatedAt.isUtc, isTrue);
        expect(fetched.updatedAt, utcCreated);

        final member = (await repo.getGroupMembers(group.groupId)).first;
        expect(member.joinedAt.isUtc, isTrue);
        expect(member.joinedAt, utcCreated);
      });

      test('25. Enum round-tripping preserves exact enum values without defaults', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000050-E00001',
          name: 'Enum Squad',
          creatorId: 'PEER-ADMIN',
          createdAt: testNow,
        );
        await repo.createGroup(group);

        await repo.addMember(
          GroupMember(
            groupId: group.groupId,
            peerId: 'PEER-MEM',
            role: GroupRole.member,
            status: GroupMemberStatus.pendingInvite,
            joinedAt: testNow,
            invitedBy: 'PEER-ADMIN',
          ),
        );

        final member = await repo.getGroupMember(group.groupId, 'PEER-MEM');
        expect(member!.role, GroupRole.member);
        expect(member.status, GroupMemberStatus.pendingInvite);
      });

      test('26. Missing record queries return null', () async {
        expect(await repo.getGroup('GRP-1730000000999-000000'), isNull);
        expect(await repo.getGroupMember('GRP-1730000000999-000000', 'PEER-NONE'), isNull);
      });

      test('27. addMember referencing non-existent group throws GroupNotFoundException', () async {
        expect(
          () => repo.addMember(
            GroupMember(
              groupId: 'GRP-1730000000999-000000',
              peerId: 'PEER-ORPHAN',
              role: GroupRole.member,
              status: GroupMemberStatus.active,
              joinedAt: testNow,
              invitedBy: 'PEER-NONE',
            ),
          ),
          throwsA(isA<GroupNotFoundException>()),
        );
      });

      test('28. Multi-write transaction rollback when group creation member fails', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000060-F00001',
          name: 'Rollback Squad',
          creatorId: 'PEER-ROLLBACK-CREATOR',
          createdAt: testNow,
        );

        // Temporarily disable foreign keys and insert a member for GRP-1730000000060-F00001 first
        // to cause primary key conflict on creator member insertion inside the transaction
        await db.customStatement('PRAGMA foreign_keys = OFF;');
        await db.customStatement('''
          INSERT INTO group_members_table (group_id, peer_id, role, status, joined_at, invited_by)
          VALUES ('GRP-1730000000060-F00001', 'PEER-ROLLBACK-CREATOR', 'member', 'active', 1000, 'PEER-X');
        ''');
        await db.customStatement('PRAGMA foreign_keys = ON;');

        // Now createGroup should attempt to insert group and then insert creator member, which will fail!
        expect(
          () => repo.createGroup(group),
          throwsA(isA<DuplicateGroupMemberException>()),
        );

        // Verify the transaction rolled back: the group row was NOT persisted!
        final groupInDb = await db.getGroup(group.groupId);
        expect(groupInDb, isNull);
      });

      test('29. Corrupted database record: invalid persisted enum throws InvalidGroupDataException without silent defaults', () async {
        final group = Group.create(
          groupId: 'GRP-1730000000070-000007',
          name: 'Corrupt Squad',
          creatorId: 'PEER-CORRUPT-CREATOR',
          createdAt: testNow,
        );
        await repo.createGroup(group, addCreatorAsMember: false);

        // 1. Direct raw SQL with invalid role fails SQLite CHECK constraint
        expect(
          () => db.customStatement('''
            INSERT INTO group_members_table (group_id, peer_id, role, status, joined_at, invited_by)
            VALUES ('GRP-1730000000070-000007', 'PEER-BAD-ROLE', 'invalid_super_role', 'active', 1000, 'PEER-NONE');
          '''),
          throwsA(isA<SqliteException>()),
        );

        // 2. Deserializing a corrupted GroupMemberEntry with invalid role throws InvalidGroupDataException
        final corruptRoleEntry = GroupMemberEntry(
          groupId: group.groupId,
          peerId: 'PEER-BAD-ROLE',
          role: 'invalid_role_value',
          status: 'active',
          joinedAt: testNow,
          invitedBy: 'PEER-NONE',
        );

        expect(
          () => repo.entryToGroupMemberForTesting(corruptRoleEntry),
          throwsA(isA<InvalidGroupDataException>()),
        );

        // 3. Deserializing a corrupted GroupMemberEntry with invalid status throws InvalidGroupDataException
        final corruptStatusEntry = GroupMemberEntry(
          groupId: group.groupId,
          peerId: 'PEER-BAD-STATUS',
          role: 'member',
          status: 'unknown_status_state',
          joinedAt: testNow,
          invitedBy: 'PEER-NONE',
        );

        expect(
          () => repo.entryToGroupMemberForTesting(corruptStatusEntry),
          throwsA(isA<InvalidGroupDataException>()),
        );

        // 4. Deserializing a corrupted GroupEntry with invalid epoch throws InvalidGroupDataException
        final corruptGroupEntry = GroupEntry(
          groupId: group.groupId,
          name: 'Corrupt Group',
          creatorId: 'PEER-CREATOR',
          adminId: 'PEER-CREATOR',
          epoch: 0, // Invalid epoch < 1
          createdAt: testNow,
          updatedAt: testNow,
        );

        expect(
          () => repo.entryToGroupForTesting(corruptGroupEntry),
          throwsA(isA<InvalidGroupDataException>()),
        );
      });
    });

    // ==========================================
    // 5. Regression Protection
    // ==========================================

    group('Regression Protection', () {
      test('30. 1-to-1 messages and peer identities coexist and remain unaffected', () async {
        // Save 1-to-1 message
        await db.insertMessage(
          MessagesTableCompanion.insert(
            messageId: 'MSG-REGRESS-01',
            conversationId: 'PEER-BOB',
            senderId: 'LOCAL-NODE',
            receiverId: 'PEER-BOB',
            textContent: 'Regular 1-to-1 chat',
            createdAt: testNow,
            status: 'sent',
          ),
        );

        // Save peer identity
        await db.savePeerIdentity(
          PeerIdentitiesTableCompanion.insert(
            peerId: 'PEER-BOB',
            identityPublicKey: 'b64url_ed25519_key_bob',
            safetyNumber: '123456',
            trustStatus: 'verified',
            firstSeenAt: testNow,
            lastSeenAt: testNow,
          ),
        );

        // Perform group operations
        final group = Group.create(
          groupId: 'GRP-1730000000080-000008',
          name: 'Regression Group',
          creatorId: 'LOCAL-NODE',
          createdAt: testNow,
        );
        await repo.createGroup(group);
        await repo.addPendingInvite(
          groupId: group.groupId,
          peerId: 'PEER-BOB',
          invitedBy: 'LOCAL-NODE',
        );

        // Verify 1-to-1 message is intact
        final messages = await db.getMessagesForConversation('PEER-BOB');
        expect(messages.length, 1);
        expect(messages.first.textContent, 'Regular 1-to-1 chat');

        // Verify peer identity is intact
        final identity = await db.getPeerIdentity('PEER-BOB');
        expect(identity, isNotNull);
        expect(identity!.safetyNumber, '123456');

        // Delete group
        await repo.deleteGroup(group.groupId);

        // 1-to-1 message and identity STILL intact
        final messagesAfter = await db.getMessagesForConversation('PEER-BOB');
        expect(messagesAfter.length, 1);
        final identityAfter = await db.getPeerIdentity('PEER-BOB');
        expect(identityAfter, isNotNull);
      });

      test('31. File transfers and chunks remain unaffected', () async {
        await db.insertFileTransfer(
          FileTransfersTableCompanion.insert(
            transferId: 'FT-REGRESS-01',
            conversationId: 'PEER-CAROL',
            peerId: 'PEER-CAROL',
            direction: 'outgoing',
            fileName: 'file.bin',
            fileSize: BigInt.from(2048),
            mimeType: 'application/octet-stream',
            fileHash: 'sha256-hash',
            localPath: '/files/file.bin',
            stagingPath: '/staging/file.bin.part',
            totalChunks: 2,
            chunkSize: 1024,
            status: 'completed',
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );

        final group = Group.create(
          groupId: 'GRP-1730000000090-000009',
          name: 'File Regression Group',
          creatorId: 'LOCAL-NODE',
          createdAt: testNow,
        );
        await repo.createGroup(group);

        final transfer = await db.getFileTransfer('FT-REGRESS-01');
        expect(transfer, isNotNull);
        expect(transfer!.status, 'completed');
      });
    });
  });
}
