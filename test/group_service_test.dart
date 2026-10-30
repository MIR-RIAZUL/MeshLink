import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/group_repository_impl.dart';
import 'package:meshlink/features/messages/data/services/group_service_impl.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';
import 'package:meshlink/features/messages/domain/repositories/group_repository.dart';
import 'package:meshlink/features/messages/domain/services/group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testNow = DateTime.utc(2026, 10, 30, 20, 0, 0);

  group('Phase 9 Step 5 — GroupService & Business Logic Tests', () {
    late AppDatabase db;
    late DriftGroupRepository repo;
    late GroupServiceImpl service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftGroupRepository(db);
      service = GroupServiceImpl(groupRepository: repo);
    });

    tearDown(() async {
      await db.close();
    });

    // ==========================================
    // 1. Group Creation
    // ==========================================
    group('1. Group Creation', () {
      test('1.1 Creates group with creator as active member and admin role', () async {
        final group = await service.createGroup(
          name: 'Core Ops',
          creatorId: 'PEER-ALICE',
          groupId: 'GRP-1730000000001-A00001',
          createdAt: testNow,
        );

        expect(group.groupId, 'GRP-1730000000001-A00001');
        expect(group.name, 'Core Ops');
        expect(group.creatorId, 'PEER-ALICE');
        expect(group.adminId, 'PEER-ALICE');
        expect(group.epoch, 1);
        expect(group.createdAt, testNow);
        expect(group.updatedAt, testNow);

        // Verify creator is an active admin member in repository
        final member = await repo.getGroupMember(group.groupId, 'PEER-ALICE');
        expect(member, isNotNull);
        expect(member!.role, GroupRole.admin);
        expect(member.status, GroupMemberStatus.active);
        expect(member.invitedBy, 'PEER-ALICE');
        expect(member.joinedAt, testNow);
      });

      test('1.2 Generates valid groupId matching pattern when groupId is null', () async {
        final group = await service.createGroup(
          name: 'Auto Generated',
          creatorId: 'PEER-BOB',
          createdAt: testNow,
        );

        expect(group.groupId, startsWith('GRP-'));
        expect(() => Group.validateGroupId(group.groupId), returnsNormally);
        expect(group.epoch, 1);
        expect(group.creatorId, 'PEER-BOB');
        expect(group.adminId, 'PEER-BOB');
      });

      test('1.3 Accepts valid custom groupId', () async {
        const customGid = 'GRP-1730000000002-B00002';
        final group = await service.createGroup(
          name: 'Custom Squad',
          creatorId: 'PEER-CHARLIE',
          groupId: customGid,
          createdAt: testNow,
        );

        expect(group.groupId, customGid);
      });

      test('1.4 Rejects invalid custom groupId with ArgumentError', () async {
        expect(
          () => service.createGroup(
            name: 'Bad ID Squad',
            creatorId: 'PEER-ALICE',
            groupId: 'INVALID-GROUP-ID',
            createdAt: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => service.createGroup(
            name: 'Whitespace ID Squad',
            creatorId: 'PEER-ALICE',
            groupId: ' GRP-1730000000001-A00001 ',
            createdAt: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('1.5 Sanitizes and trims group name', () async {
        final group = await service.createGroup(
          name: '   Padded Name Squad   ',
          creatorId: 'PEER-ALICE',
          groupId: 'GRP-1730000000003-C00003',
          createdAt: testNow,
        );

        expect(group.name, 'Padded Name Squad');
      });

      test('1.6 Rejects empty or whitespace-only group name with ArgumentError', () async {
        expect(
          () => service.createGroup(
            name: '',
            creatorId: 'PEER-ALICE',
            createdAt: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => service.createGroup(
            name: '    ',
            creatorId: 'PEER-ALICE',
            createdAt: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('1.7 Rejects group name exceeding 64 characters with ArgumentError', () async {
        final longName = 'A' * 65;
        expect(
          () => service.createGroup(
            name: longName,
            creatorId: 'PEER-ALICE',
            createdAt: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('1.8 Rejects empty or invalid creatorId with ArgumentError', () async {
        expect(
          () => service.createGroup(
            name: 'Valid Name',
            creatorId: '',
            createdAt: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => service.createGroup(
            name: 'Valid Name',
            creatorId: '   ',
            createdAt: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('1.9 Rejects non-UTC createdAt timestamp with ArgumentError', () async {
        final localTime = DateTime(2026, 10, 30, 20, 0, 0); // non-UTC
        expect(
          () => service.createGroup(
            name: 'Valid Name',
            creatorId: 'PEER-ALICE',
            createdAt: localTime,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('1.10 Initial group epoch is strictly 1', () async {
        final group = await service.createGroup(
          name: 'Epoch Check',
          creatorId: 'PEER-ALICE',
          createdAt: testNow,
        );

        expect(group.epoch, 1);
      });
    });

    // ==========================================
    // 2. Group Retrieval & Query Operations
    // ==========================================
    group('2. Group Retrieval & Query Operations', () {
      late Group groupAlpha;
      late Group groupBeta;

      setUp(() async {
        groupAlpha = await service.createGroup(
          name: 'Alpha Team',
          creatorId: 'PEER-ALICE',
          groupId: 'GRP-1730000000010-A00010',
          createdAt: testNow,
        );

        groupBeta = await service.createGroup(
          name: 'Beta Team',
          creatorId: 'PEER-BOB',
          groupId: 'GRP-1730000000020-B00020',
          createdAt: testNow.add(const Duration(minutes: 5)),
        );
      });

      test('2.1 getGroup returns existing group or null if nonexistent', () async {
        final retrieved = await service.getGroup(groupAlpha.groupId);
        expect(retrieved, isNotNull);
        expect(retrieved!.groupId, groupAlpha.groupId);
        expect(retrieved.name, 'Alpha Team');

        final nonexistent = await service.getGroup('GRP-9999999999999-F99999');
        expect(nonexistent, isNull);
      });

      test('2.2 getAllGroups returns all groups ordered by createdAt descending', () async {
        final all = await service.getAllGroups();
        expect(all.length, 2);
        // groupBeta was created 5 minutes after groupAlpha
        expect(all[0].groupId, groupBeta.groupId);
        expect(all[1].groupId, groupAlpha.groupId);
      });

      test('2.3 getActiveMembers returns only active members', () async {
        await service.invitePeer(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-BOB',
          timestamp: testNow,
        );

        final active = await service.getActiveMembers(groupAlpha.groupId);
        expect(active.length, 1);
        expect(active.first.peerId, 'PEER-ALICE');
        expect(active.first.status, GroupMemberStatus.active);
      });

      test('2.4 getPendingInvitations returns only pending members', () async {
        await service.invitePeer(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-CHARLIE',
          timestamp: testNow,
        );

        final pending = await service.getPendingInvitations(groupAlpha.groupId);
        expect(pending.length, 1);
        expect(pending.first.peerId, 'PEER-CHARLIE');
        expect(pending.first.status, GroupMemberStatus.pendingInvite);
      });

      test('2.5 getRemovedMembers returns only removed members', () async {
        await service.invitePeer(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-DAVE',
          timestamp: testNow,
        );

        await service.removeMember(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-DAVE',
        );

        final removed = await service.getRemovedMembers(groupAlpha.groupId);
        expect(removed.length, 1);
        expect(removed.first.peerId, 'PEER-DAVE');
        expect(removed.first.status, GroupMemberStatus.removed);
      });

      test('2.6 getMember returns specific member or null if not found', () async {
        final member = await service.getMember(groupAlpha.groupId, 'PEER-ALICE');
        expect(member, isNotNull);
        expect(member!.peerId, 'PEER-ALICE');

        final nonexistent = await service.getMember(groupAlpha.groupId, 'PEER-UNKNOWN');
        expect(nonexistent, isNull);
      });

      test('2.7 isActiveMember returns true only for active members', () async {
        expect(await service.isActiveMember(groupAlpha.groupId, 'PEER-ALICE'), isTrue);

        await service.invitePeer(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-EVE',
          timestamp: testNow,
        );
        expect(await service.isActiveMember(groupAlpha.groupId, 'PEER-EVE'), isFalse);

        await service.removeMember(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-EVE',
        );
        expect(await service.isActiveMember(groupAlpha.groupId, 'PEER-EVE'), isFalse);

        expect(await service.isActiveMember(groupAlpha.groupId, 'PEER-NONEXISTENT'), isFalse);
      });

      test('2.8 isGroupAdmin returns true only for group admin', () async {
        expect(await service.isGroupAdmin(groupAlpha.groupId, 'PEER-ALICE'), isTrue);
        expect(await service.isGroupAdmin(groupAlpha.groupId, 'PEER-BOB'), isFalse);
        expect(await service.isGroupAdmin(groupAlpha.groupId, 'PEER-UNKNOWN'), isFalse);
        expect(await service.isGroupAdmin('GRP-9999999999999-F99999', 'PEER-ALICE'), isFalse);
      });

      test('2.9 canSendGroupMessages returns true for active members, false otherwise', () async {
        expect(await service.canSendGroupMessages(groupAlpha.groupId, 'PEER-ALICE'), isTrue);

        await service.invitePeer(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-FRANK',
          timestamp: testNow,
        );
        expect(await service.canSendGroupMessages(groupAlpha.groupId, 'PEER-FRANK'), isFalse);

        await service.acceptInvitation(
          groupId: groupAlpha.groupId,
          peerId: 'PEER-FRANK',
        );
        expect(await service.canSendGroupMessages(groupAlpha.groupId, 'PEER-FRANK'), isTrue);

        await service.removeMember(
          groupId: groupAlpha.groupId,
          requestingPeerId: 'PEER-ALICE',
          targetPeerId: 'PEER-FRANK',
        );
        expect(await service.canSendGroupMessages(groupAlpha.groupId, 'PEER-FRANK'), isFalse);
      });
    });

    // ==========================================
    // 3. Invitations
    // ==========================================
    group('3. Invitations', () {
      late Group group;

      setUp(() async {
        group = await service.createGroup(
          name: 'Invites Squad',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000030-A00030',
          createdAt: testNow,
        );
      });

      test('3.1 Admin can invite peer: target gets pendingInvite status with invitedBy = adminId', () async {
        final member = await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEMBER1',
          timestamp: testNow,
        );

        expect(member.groupId, group.groupId);
        expect(member.peerId, 'PEER-MEMBER1');
        expect(member.role, GroupRole.member);
        expect(member.status, GroupMemberStatus.pendingInvite);
        expect(member.invitedBy, 'PEER-ADMIN');
        expect(member.joinedAt, testNow);
      });

      test('3.2 Non-admin inviting peer throws GroupAuthorizationException', () async {
        // First invite and accept a normal member
        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEMBER1',
          timestamp: testNow,
        );
        await service.acceptInvitation(groupId: group.groupId, peerId: 'PEER-MEMBER1');

        // Member attempts to invite someone else
        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-MEMBER1',
            targetPeerId: 'PEER-MEMBER2',
            timestamp: testNow,
          ),
          throwsA(isA<GroupAuthorizationException>()),
        );

        // Stranger attempts to invite someone
        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-STRANGER',
            targetPeerId: 'PEER-MEMBER2',
            timestamp: testNow,
          ),
          throwsA(isA<GroupAuthorizationException>()),
        );
      });

      test('3.3 Inviting peer in nonexistent group throws GroupNotFoundException', () async {
        expect(
          () => service.invitePeer(
            groupId: 'GRP-9999999999999-F99999',
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-MEMBER1',
            timestamp: testNow,
          ),
          throwsA(isA<GroupNotFoundException>()),
        );
      });

      test('3.4 Inviting already active member throws InvitationAlreadyExistsException', () async {
        // Creator/admin is already active
        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-ADMIN',
            timestamp: testNow,
          ),
          throwsA(isA<InvitationAlreadyExistsException>()),
        );

        // Invite and accept peer
        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEMBER1',
          timestamp: testNow,
        );
        await service.acceptInvitation(groupId: group.groupId, peerId: 'PEER-MEMBER1');

        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-MEMBER1',
            timestamp: testNow,
          ),
          throwsA(isA<InvitationAlreadyExistsException>()),
        );
      });

      test('3.5 Inviting already pending member throws InvitationAlreadyExistsException', () async {
        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEMBER1',
          timestamp: testNow,
        );

        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-MEMBER1',
            timestamp: testNow,
          ),
          throwsA(isA<InvitationAlreadyExistsException>()),
        );
      });

      test('3.6 Group capacity enforcement: up to 8 distinct active/pending participants', () async {
        // Group has 1 member (admin). Add 7 more pending/active members -> reaches 8.
        for (var i = 1; i <= 7; i++) {
          await service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-M$i',
            timestamp: testNow,
          );
        }

        final activeAndPending = (await repo.getGroupMembers(group.groupId))
            .where((m) => m.status != GroupMemberStatus.removed)
            .toList();
        expect(activeAndPending.length, 8);

        // Inviting the 9th peer must throw GroupCapacityExceededException
        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-M8-OVERFLOW',
            timestamp: testNow,
          ),
          throwsA(isA<GroupCapacityExceededException>()),
        );
      });

      test('3.7 Re-inviting previously removed peer transitions status back to pendingInvite', () async {
        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEMBER1',
          timestamp: testNow,
        );

        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEMBER1',
        );

        final removed = await service.getMember(group.groupId, 'PEER-MEMBER1');
        expect(removed!.status, GroupMemberStatus.removed);

        // Re-invite
        final reinvited = await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEMBER1',
          timestamp: testNow,
        );

        expect(reinvited.status, GroupMemberStatus.pendingInvite);
        expect(reinvited.peerId, 'PEER-MEMBER1');
      });

      test('3.8 Re-inviting previously removed peer when cohort is full (8 active/pending) throws GroupCapacityExceededException', () async {
        // Invite and remove PEER-M1
        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-M1',
          timestamp: testNow,
        );
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-M1',
        );

        // Fill remaining 7 slots with other peers (PEER-M2 .. PEER-M8)
        for (var i = 2; i <= 8; i++) {
          await service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-M$i',
            timestamp: testNow,
          );
        }

        // Now cohort has 1 admin + 7 active/pending peers = 8 participants
        // Attempting to re-invite PEER-M1 must fail due to capacity
        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-M1',
            timestamp: testNow,
          ),
          throwsA(isA<GroupCapacityExceededException>()),
        );
      });

      test('3.9 Inviting with invalid peerId throws ArgumentError', () async {
        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: '',
            timestamp: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: '',
            targetPeerId: 'PEER-MEMBER1',
            timestamp: testNow,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ==========================================
    // 4. Invitation Acceptance & Rejection
    // ==========================================
    group('4. Invitation Acceptance & Rejection', () {
      late Group group;

      setUp(() async {
        group = await service.createGroup(
          name: 'Accept/Reject Squad',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000040-A00040',
          createdAt: testNow,
        );

        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-INVITEE',
          timestamp: testNow,
        );
      });

      test('4.1 Target peer accepts invitation: status transitions from pendingInvite to active', () async {
        final accepted = await service.acceptInvitation(
          groupId: group.groupId,
          peerId: 'PEER-INVITEE',
        );

        expect(accepted.status, GroupMemberStatus.active);
        expect(accepted.peerId, 'PEER-INVITEE');
        expect(accepted.role, GroupRole.member);

        final member = await service.getMember(group.groupId, 'PEER-INVITEE');
        expect(member!.status, GroupMemberStatus.active);
      });

      test('4.2 Accepting invitation when already active throws InvalidGroupStateException', () async {
        await service.acceptInvitation(
          groupId: group.groupId,
          peerId: 'PEER-INVITEE',
        );

        expect(
          () => service.acceptInvitation(
            groupId: group.groupId,
            peerId: 'PEER-INVITEE',
          ),
          throwsA(isA<InvalidGroupStateException>()),
        );

        // Creator is also active
        expect(
          () => service.acceptInvitation(
            groupId: group.groupId,
            peerId: 'PEER-ADMIN',
          ),
          throwsA(isA<InvalidGroupStateException>()),
        );
      });

      test('4.3 Accepting invitation when removed throws NoPendingInvitationException', () async {
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-INVITEE',
        );

        expect(
          () => service.acceptInvitation(
            groupId: group.groupId,
            peerId: 'PEER-INVITEE',
          ),
          throwsA(isA<NoPendingInvitationException>()),
        );
      });

      test('4.4 Accepting nonexistent invitation throws NoPendingInvitationException', () async {
        expect(
          () => service.acceptInvitation(
            groupId: group.groupId,
            peerId: 'PEER-UNINVITED',
          ),
          throwsA(isA<NoPendingInvitationException>()),
        );
      });

      test('4.5 Accepting invitation on nonexistent group throws GroupNotFoundException', () async {
        expect(
          () => service.acceptInvitation(
            groupId: 'GRP-9999999999999-F99999',
            peerId: 'PEER-INVITEE',
          ),
          throwsA(isA<GroupNotFoundException>()),
        );
      });

      test('4.6 Target peer rejects invitation: status transitions to removed (tombstone)', () async {
        await service.rejectInvitation(
          groupId: group.groupId,
          peerId: 'PEER-INVITEE',
        );

        final member = await service.getMember(group.groupId, 'PEER-INVITEE');
        expect(member, isNotNull);
        expect(member!.status, GroupMemberStatus.removed);
      });

      test('4.7 Rejection frees capacity slot: admin can invite another peer up to 8', () async {
        // Invite 6 more peers to reach 8 total (1 admin + 1 pending + 6 more)
        for (var i = 1; i <= 6; i++) {
          await service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-OTHER-$i',
            timestamp: testNow,
          );
        }

        // At capacity 8: attempting to invite 9th fails
        await expectLater(
          service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-NINTH',
            timestamp: testNow,
          ),
          throwsA(isA<GroupCapacityExceededException>()),
        );

        // PEER-INVITEE rejects their invitation
        await service.rejectInvitation(
          groupId: group.groupId,
          peerId: 'PEER-INVITEE',
        );

        // Now capacity slot is freed: PEER-NINTH can be invited
        final ninth = await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-NINTH',
          timestamp: testNow,
        );
        expect(ninth.status, GroupMemberStatus.pendingInvite);
        expect(ninth.peerId, 'PEER-NINTH');
      });

      test('4.8 Rejecting invitation when not pending throws NoPendingInvitationException', () async {
        // Peer not in group
        expect(
          () => service.rejectInvitation(
            groupId: group.groupId,
            peerId: 'PEER-NOT-IN-GROUP',
          ),
          throwsA(isA<NoPendingInvitationException>()),
        );

        // Peer is active admin
        expect(
          () => service.rejectInvitation(
            groupId: group.groupId,
            peerId: 'PEER-ADMIN',
          ),
          throwsA(isA<NoPendingInvitationException>()),
        );

        // Peer is already removed
        await service.rejectInvitation(
          groupId: group.groupId,
          peerId: 'PEER-INVITEE',
        );
        expect(
          () => service.rejectInvitation(
            groupId: group.groupId,
            peerId: 'PEER-INVITEE',
          ),
          throwsA(isA<NoPendingInvitationException>()),
        );
      });

      test('4.9 Rejecting invitation on nonexistent group throws GroupNotFoundException', () async {
        expect(
          () => service.rejectInvitation(
            groupId: 'GRP-9999999999999-F99999',
            peerId: 'PEER-INVITEE',
          ),
          throwsA(isA<GroupNotFoundException>()),
        );
      });
    });

    // ==========================================
    // 5. Member Removal
    // ==========================================
    group('5. Member Removal', () {
      late Group group;

      setUp(() async {
        group = await service.createGroup(
          name: 'Removal Squad',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000050-A00050',
          createdAt: testNow,
        );

        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-ACTIVE1',
          timestamp: testNow,
        );
        await service.acceptInvitation(groupId: group.groupId, peerId: 'PEER-ACTIVE1');

        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-PENDING1',
          timestamp: testNow,
        );
      });

      test('5.1 Admin can remove active member: status transitions to removed', () async {
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-ACTIVE1',
        );

        final member = await service.getMember(group.groupId, 'PEER-ACTIVE1');
        expect(member, isNotNull);
        expect(member!.status, GroupMemberStatus.removed);
      });

      test('5.2 Admin can revoke pending invitation: status transitions to removed', () async {
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-PENDING1',
        );

        final member = await service.getMember(group.groupId, 'PEER-PENDING1');
        expect(member, isNotNull);
        expect(member!.status, GroupMemberStatus.removed);
      });

      test('5.3 Non-admin attempting to remove active member throws GroupAuthorizationException', () async {
        expect(
          () => service.removeMember(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ACTIVE1',
            targetPeerId: 'PEER-PENDING1',
          ),
          throwsA(isA<GroupAuthorizationException>()),
        );

        expect(
          () => service.removeMember(
            groupId: group.groupId,
            requestingPeerId: 'PEER-STRANGER',
            targetPeerId: 'PEER-ACTIVE1',
          ),
          throwsA(isA<GroupAuthorizationException>()),
        );
      });

      test('5.4 Non-admin attempting to revoke pending invitation throws GroupAuthorizationException', () async {
        expect(
          () => service.removeMember(
            groupId: group.groupId,
            requestingPeerId: 'PEER-PENDING1',
            targetPeerId: 'PEER-ACTIVE1',
          ),
          throwsA(isA<GroupAuthorizationException>()),
        );
      });

      test('5.5 Admin attempting self-removal throws AdminSelfRemovalProhibitedException', () async {
        expect(
          () => service.removeMember(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-ADMIN',
          ),
          throwsA(isA<AdminSelfRemovalProhibitedException>()),
        );
      });

      test('5.6 Removing member from nonexistent group throws GroupNotFoundException', () async {
        expect(
          () => service.removeMember(
            groupId: 'GRP-9999999999999-F99999',
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-ACTIVE1',
          ),
          throwsA(isA<GroupNotFoundException>()),
        );
      });

      test('5.7 Removing nonexistent member throws GroupMemberNotFoundException', () async {
        expect(
          () => service.removeMember(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-NONEXISTENT',
          ),
          throwsA(isA<GroupMemberNotFoundException>()),
        );
      });

      test('5.8 Removing already removed member throws MemberAlreadyRemovedException', () async {
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-ACTIVE1',
        );

        expect(
          () => service.removeMember(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-ACTIVE1',
          ),
          throwsA(isA<MemberAlreadyRemovedException>()),
        );
      });

      test('5.9 Removed member record is preserved in database (audit trail)', () async {
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-ACTIVE1',
        );

        final members = await repo.getGroupMembers(group.groupId);
        expect(members.any((m) => m.peerId == 'PEER-ACTIVE1'), isTrue);

        final removedMembers = await service.getRemovedMembers(group.groupId);
        expect(removedMembers.length, 1);
        expect(removedMembers.first.peerId, 'PEER-ACTIVE1');
      });

      test('5.10 Removing member frees capacity slot: allows another peer to be invited', () async {
        // Group has: Admin + PEER-ACTIVE1 + PEER-PENDING1 (3 members).
        // Add 5 more to reach 8.
        for (var i = 1; i <= 5; i++) {
          await service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-SLOT-$i',
            timestamp: testNow,
          );
        }

        // At capacity 8
        await expectLater(
          service.invitePeer(
            groupId: group.groupId,
            requestingPeerId: 'PEER-ADMIN',
            targetPeerId: 'PEER-OVERFLOW',
            timestamp: testNow,
          ),
          throwsA(isA<GroupCapacityExceededException>()),
        );

        // Remove PEER-ACTIVE1
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-ACTIVE1',
        );

        // Now PEER-OVERFLOW can be invited successfully
        final newMember = await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-OVERFLOW',
          timestamp: testNow,
        );
        expect(newMember.peerId, 'PEER-OVERFLOW');
        expect(newMember.status, GroupMemberStatus.pendingInvite);
      });
    });

    // ==========================================
    // 6. Group Deletion
    // ==========================================
    group('6. Group Deletion', () {
      late Group group;

      setUp(() async {
        group = await service.createGroup(
          name: 'Delete Squad',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000060-A00060',
          createdAt: testNow,
        );

        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-MEM1',
          timestamp: testNow,
        );
      });

      test('6.1 Admin can delete group: cascades deletion to all members', () async {
        await service.deleteGroup(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
        );

        final g = await service.getGroup(group.groupId);
        expect(g, isNull);

        final members = await repo.getGroupMembers(group.groupId);
        expect(members, isEmpty);
      });

      test('6.2 Non-admin attempting group deletion throws GroupAuthorizationException', () async {
        expect(
          () => service.deleteGroup(
            groupId: group.groupId,
            requestingPeerId: 'PEER-MEM1',
          ),
          throwsA(isA<GroupAuthorizationException>()),
        );

        expect(
          () => service.deleteGroup(
            groupId: group.groupId,
            requestingPeerId: 'PEER-STRANGER',
          ),
          throwsA(isA<GroupAuthorizationException>()),
        );
      });

      test('6.3 Deleting nonexistent group throws GroupNotFoundException', () async {
        expect(
          () => service.deleteGroup(
            groupId: 'GRP-9999999999999-F99999',
            requestingPeerId: 'PEER-ADMIN',
          ),
          throwsA(isA<GroupNotFoundException>()),
        );
      });
    });

    // ==========================================
    // 7. Invariants & Multi-step Lifecycle
    // ==========================================
    group('7. Invariants & Multi-step Lifecycle', () {
      test('7.1 Full lifecycle: create -> invite -> accept -> remove -> re-invite -> reject -> cycle', () async {
        // 1. Create group
        final group = await service.createGroup(
          name: 'Lifecycle Squad',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000070-A00070',
          createdAt: testNow,
        );
        expect(group.epoch, 1);
        expect(await service.isActiveMember(group.groupId, 'PEER-ADMIN'), isTrue);

        // 2. Invite Peer 1
        final p1Invite = await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-1',
          timestamp: testNow,
        );
        expect(p1Invite.status, GroupMemberStatus.pendingInvite);
        expect(await service.canSendGroupMessages(group.groupId, 'PEER-1'), isFalse);

        // 3. Peer 1 accepts
        final p1Active = await service.acceptInvitation(
          groupId: group.groupId,
          peerId: 'PEER-1',
        );
        expect(p1Active.status, GroupMemberStatus.active);
        expect(await service.canSendGroupMessages(group.groupId, 'PEER-1'), isTrue);

        // 4. Admin removes Peer 1
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-1',
        );
        expect(await service.canSendGroupMessages(group.groupId, 'PEER-1'), isFalse);
        final p1Removed = await service.getMember(group.groupId, 'PEER-1');
        expect(p1Removed!.status, GroupMemberStatus.removed);

        // 5. Admin re-invites Peer 1
        final p1Reinvite = await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-1',
          timestamp: testNow,
        );
        expect(p1Reinvite.status, GroupMemberStatus.pendingInvite);

        // 6. Peer 1 rejects
        await service.rejectInvitation(
          groupId: group.groupId,
          peerId: 'PEER-1',
        );
        expect(await service.canSendGroupMessages(group.groupId, 'PEER-1'), isFalse);
        final p1Rejected = await service.getMember(group.groupId, 'PEER-1');
        expect(p1Rejected!.status, GroupMemberStatus.removed);

        // 7. Verify audit trail: database still holds PEER-ADMIN and PEER-1
        final allMembers = await repo.getGroupMembers(group.groupId);
        expect(allMembers.length, 2);
        expect(allMembers.map((m) => m.peerId).toSet(), {'PEER-ADMIN', 'PEER-1'});
      });

      test('7.2 Epoch starts at 1 and remains 1 across metadata queries', () async {
        final group = await service.createGroup(
          name: 'Epoch Immutability',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000080-A00080',
          createdAt: testNow,
        );

        expect(group.epoch, 1);
        final fetched = await service.getGroup(group.groupId);
        expect(fetched!.epoch, 1);
      });

      test('7.3 Admin ID remains unchanged across all normal member operations', () async {
        final group = await service.createGroup(
          name: 'Admin Integrity',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000090-A00090',
          createdAt: testNow,
        );

        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-USER',
          timestamp: testNow,
        );
        await service.acceptInvitation(groupId: group.groupId, peerId: 'PEER-USER');
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-USER',
        );

        final currentGroup = await service.getGroup(group.groupId);
        expect(currentGroup!.adminId, 'PEER-ADMIN');
        expect(currentGroup.creatorId, 'PEER-ADMIN');
      });

      test('7.4 canSendGroupMessages returns false for pending and removed members', () async {
        final group = await service.createGroup(
          name: 'Message Permission',
          creatorId: 'PEER-ADMIN',
          groupId: 'GRP-1730000000100-A00100',
          createdAt: testNow,
        );

        await service.invitePeer(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-TARGET',
          timestamp: testNow,
        );

        // Pending member cannot send
        expect(await service.canSendGroupMessages(group.groupId, 'PEER-TARGET'), isFalse);

        // Removed member cannot send
        await service.removeMember(
          groupId: group.groupId,
          requestingPeerId: 'PEER-ADMIN',
          targetPeerId: 'PEER-TARGET',
        );
        expect(await service.canSendGroupMessages(group.groupId, 'PEER-TARGET'), isFalse);

        // Stranger cannot send
        expect(await service.canSendGroupMessages(group.groupId, 'PEER-STRANGER'), isFalse);

        // Nonexistent group cannot send
        expect(await service.canSendGroupMessages('GRP-9999999999999-F99999', 'PEER-ADMIN'), isFalse);
      });
    });
  });
}
