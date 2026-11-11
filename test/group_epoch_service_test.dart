import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/group_epoch_packets.dart';
import 'package:meshlink/features/messages/data/repositories/group_repository_impl.dart';
import 'package:meshlink/features/messages/data/services/group_epoch_service_impl.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';
import 'package:meshlink/features/messages/domain/models/group_epoch_signed_history.dart';
import 'package:meshlink/features/messages/domain/services/group_epoch_service.dart';
import 'package:meshlink/features/messages/domain/services/group_epoch_state_machine.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const testGroupId = 'GRP-1730000000000-A1B2C3';
  const testAdminId = 'PEER-ADMIN-01';
  const testMember1 = 'PEER-MEMBER-01';
  const testMember2 = 'PEER-MEMBER-02';
  final testTimestamp = DateTime.utc(2026, 11, 11, 12, 0, 0);

  late AppDatabase db;
  late DriftGroupRepository groupRepo;
  late MeshIdentityService adminIdentityService;
  late GroupEpochServiceImpl epochService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    groupRepo = DriftGroupRepository(db);

    adminIdentityService = MeshIdentityService(
      store: InMemorySecureIdentityStoreV2(),
    );
    await adminIdentityService.initialize();

    epochService = GroupEpochServiceImpl(
      db: db,
      groupRepository: groupRepo,
      identityService: adminIdentityService,
      localPeerId: testAdminId,
      clock: () => testTimestamp,
    );

    // Seed group with admin and two active members
    final group = Group.create(
      groupId: testGroupId,
      name: 'Test Secure Group',
      creatorId: testAdminId,
      createdAt: testTimestamp,
    );
    await groupRepo.createGroup(group, addCreatorAsMember: true);

    await groupRepo.addMember(GroupMember(
      groupId: testGroupId,
      peerId: testMember1,
      role: GroupRole.member,
      status: GroupMemberStatus.active,
      joinedAt: testTimestamp,
      invitedBy: testAdminId,
    ));

    await groupRepo.addMember(GroupMember(
      groupId: testGroupId,
      peerId: testMember2,
      role: GroupRole.member,
      status: GroupMemberStatus.active,
      joinedAt: testTimestamp,
      invitedBy: testAdminId,
    ));

    // Save admin identity in PeerIdentitiesTable for signature verification
    final adminPubKey = await adminIdentityService.getIdentityPublicKey();
    await db.savePeerIdentity(PeerIdentitiesTableCompanion(
      peerId: const drift.Value(testAdminId),
      identityPublicKey: drift.Value(adminPubKey),
      safetyNumber: const drift.Value('123456'),
      trustStatus: const drift.Value('verified'),
      firstSeenAt: drift.Value(testTimestamp),
      lastSeenAt: drift.Value(testTimestamp),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 9 Step 6.3.2 — Group Epoch Runtime Service & Persistence Tests', () {
    // =========================================================================
    // 1. Runtime Lifecycle
    // =========================================================================
    group('1. Runtime Lifecycle', () {
      test('1.1 Complete Prepare -> Commit -> Finalize lifecycle advances epoch and unfreezes messaging', () async {
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isTrue);

        // Initiate prepare
        final preparePacket = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        expect(preparePacket.groupId, testGroupId);
        expect(preparePacket.previousEpoch, 1);
        expect(preparePacket.targetEpoch, 2);
        expect(preparePacket.operationSequenceNumber, 1);

        // Messaging is now frozen
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isFalse);
        expect(await epochService.canSendGroupMessages(testGroupId, testMember1), isFalse);

        // Member 1 Prepare ACK
        var state = await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );
        expect(state.operationStatus, GroupEpochOperationStatus.preparing);

        // Member 2 Prepare ACK -> transitions to committing
        state = await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember2,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember2,
        );
        expect(state.operationStatus, GroupEpochOperationStatus.committing);

        // Admin emits Commit packet
        final commitPacket = await epochService.commitReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: preparePacket.operationId,
        );
        expect(commitPacket.targetEpoch, 2);

        // Members Commit ACKs
        await epochService.processCommitAck(
          packet: GroupEpochCommitAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );

        state = await epochService.processCommitAck(
          packet: GroupEpochCommitAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember2,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember2,
        );
        expect(state.operationStatus, GroupEpochOperationStatus.finalizing);

        // Admin emits Finalize packet
        final finalizePacket = await epochService.finalizeReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: preparePacket.operationId,
        );
        expect(finalizePacket.targetEpoch, 2);

        // Member 1 Finalize ACK (still finalizing)
        state = await epochService.processFinalizeAck(
          packet: GroupEpochFinalizeAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );
        expect(state.operationStatus, GroupEpochOperationStatus.finalizing);
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isFalse);

        // Member 2 Finalize ACK -> transitions to finalized!
        state = await epochService.processFinalizeAck(
          packet: GroupEpochFinalizeAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember2,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember2,
        );
        expect(state.operationStatus, GroupEpochOperationStatus.finalized);
        expect(state.currentEpoch, 2);

        // Verified persisted group in DB: epoch updated, pending cleared!
        final updatedGroup = await db.getGroup(testGroupId);
        expect(updatedGroup!.epoch, 2);
        expect(updatedGroup.isReEpochPending, isFalse);
        expect(updatedGroup.activeReEpochOperationId, isNull);

        // Messaging is unfrozen!
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isTrue);
        expect(await epochService.canSendGroupMessages(testGroupId, testMember1), isTrue);
      });

      test('1.2 Prepare ACK failure records failure and keeps messaging frozen', () async {
        final preparePacket = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        final state = await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.failed,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );

        expect(state.operationStatus, GroupEpochOperationStatus.preparing);
        expect(state.prepareAcks[testMember1], GroupEpochAckStatus.failed);
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isFalse);

        // Check DB sync row
        final syncRow = await (db.select(db.groupEpochSyncTable)
              ..where((t) =>
                  t.operationId.equals(preparePacket.operationId) &
                  t.memberPeerId.equals(testMember1)))
            .getSingle();
        expect(syncRow.prepareStatus, 'failed');
      });

      test('1.3 Commit ACK failure records failure and keeps operation in committing', () async {
        final preparePacket = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );
        await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember2,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember2,
        );

        await epochService.commitReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: preparePacket.operationId,
        );

        final state = await epochService.processCommitAck(
          packet: GroupEpochCommitAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.failed,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );

        expect(state.operationStatus, GroupEpochOperationStatus.committing);
        expect(state.commitAcks[testMember1], GroupEpochAckStatus.failed);
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isFalse);
      });

      test('1.4 Finalize ACK failure records failure and keeps epoch at previous', () async {
        final preparePacket = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );
        await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember2,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember2,
        );

        await epochService.commitReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: preparePacket.operationId,
        );

        await epochService.processCommitAck(
          packet: GroupEpochCommitAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );
        await epochService.processCommitAck(
          packet: GroupEpochCommitAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember2,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember2,
        );

        await epochService.finalizeReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: preparePacket.operationId,
        );

        final state = await epochService.processFinalizeAck(
          packet: GroupEpochFinalizeAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.failed,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );

        expect(state.operationStatus, GroupEpochOperationStatus.finalizing);
        expect(state.currentEpoch, 1);
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isFalse);
      });

      test('1.5 Duplicate identical ACK is idempotent and returns current state', () async {
        final preparePacket = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        final ack = GroupEpochPrepareAckPacket(
          operationId: preparePacket.operationId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
          timestamp: testTimestamp,
        );

        final state1 = await epochService.processPrepareAck(
          packet: ack,
          authenticatedSenderPeerId: testMember1,
        );

        final state2 = await epochService.processPrepareAck(
          packet: ack,
          authenticatedSenderPeerId: testMember1,
        );

        expect(state1, equals(state2));
      });

      test('1.6 Conflicting ACK from same member throws GroupEpochConflictException', () async {
        final preparePacket = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: preparePacket.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );

        // Conflicting ACK
        expect(
          () => epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: preparePacket.operationId,
              groupId: testGroupId,
              memberPeerId: testMember1,
              targetEpoch: 2,
              status: GroupEpochAckStatus.failed,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: testMember1,
          ),
          throwsA(isA<GroupEpochConflictException>()),
        );
      });

      test('1.7 Invalid authenticated transport identity is rejected immediately', () async {
        final preparePacket = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        expect(
          () => epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: preparePacket.operationId,
              groupId: testGroupId,
              memberPeerId: testMember1,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: 'PEER-SPOOFED',
          ),
          throwsA(isA<InvalidGroupEpochAckException>()),
        );
      });

      test('1.8 Invalid operation ID is rejected fail-closed', () async {
        await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        expect(
          () => epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: 'ffffffffffffffffffffffffffffffff',
              groupId: testGroupId,
              memberPeerId: testMember1,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: testMember1,
          ),
          throwsA(isA<InvalidGroupEpochAckException>()),
        );
      });

      test('1.9 Delayed ACK from superseded operation is rejected', () async {
        final op1 = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        // Admin supersedes op1 with op2
        final op2 = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );
        expect(op2.operationSequenceNumber, 2);

        // Delayed ACK for op1 is rejected
        expect(
          () => epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: op1.operationId,
              groupId: testGroupId,
              memberPeerId: testMember1,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: testMember1,
          ),
          throwsA(isA<InvalidGroupEpochAckException>()),
        );
      });

      test('1.10 ACK after finalization is rejected', () async {
        // Complete full lifecycle to finalized
        final prep = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );
        for (final m in [testMember1, testMember2]) {
          await epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: m,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: m,
          );
        }
        await epochService.commitReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: prep.operationId,
        );
        for (final m in [testMember1, testMember2]) {
          await epochService.processCommitAck(
            packet: GroupEpochCommitAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: m,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: m,
          );
        }
        await epochService.finalizeReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: prep.operationId,
        );
        for (final m in [testMember1, testMember2]) {
          await epochService.processFinalizeAck(
            packet: GroupEpochFinalizeAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: m,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: m,
          );
        }

        // Post-finalization ACK
        expect(
          () => epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: testMember1,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: testMember1,
          ),
          throwsA(isA<InvalidGroupEpochTransitionException>()),
        );
      });
    });

    // =========================================================================
    // 2. Administrator Contract
    // =========================================================================
    group('2. Administrator Contract', () {
      test('2.1 Administrator is excluded from required remote-member snapshot', () async {
        final prep = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        final sm = await epochService.getActiveStateMachine(testGroupId);
        expect(sm!.state.requiredMemberPeerIds, {testMember1, testMember2});
        expect(sm.state.requiredMemberPeerIds.contains(testAdminId), isFalse);

        // DB sync rows only contain remote members
        final syncRows = await (db.select(db.groupEpochSyncTable)
              ..where((t) => t.operationId.equals(prep.operationId)))
            .get();
        expect(syncRows.map((r) => r.memberPeerId).toSet(), {testMember1, testMember2});
      });

      test('2.2 No network-generated self-ACK is required for administrator', () async {
        final prep = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        // Only member1 and member2 prepare
        for (final m in [testMember1, testMember2]) {
          await epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: m,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: m,
          );
        }

        // State advances to committing without any admin self-ACK!
        final sm = await epochService.getActiveStateMachine(testGroupId);
        expect(sm!.state.operationStatus, GroupEpochOperationStatus.committing);
      });

      test('2.3 Offline remote members remain required and hold operation pending', () async {
        final prep = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        // Member1 prepares, but Member2 is offline
        await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: prep.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );

        final sm = await epochService.getActiveStateMachine(testGroupId);
        expect(sm!.state.operationStatus, GroupEpochOperationStatus.preparing);
        expect(sm.state.isReEpochPending, isTrue);
        expect(await epochService.canSendGroupMessages(testGroupId, testAdminId), isFalse);
      });
    });

    // =========================================================================
    // 3. Persistence and Crash Recovery
    // =========================================================================
    group('3. Persistence and Crash Recovery', () {
      test('3.1 Operation and ACK progress survives service reconstruction (simulated restart)', () async {
        final prep = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        await epochService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: prep.operationId,
            groupId: testGroupId,
            memberPeerId: testMember1,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember1,
        );

        // Simulate application restart: create a new service instance over same DB
        final restartedService = GroupEpochServiceImpl(
          db: db,
          groupRepository: groupRepo,
          identityService: adminIdentityService,
          localPeerId: testAdminId,
          clock: () => testTimestamp,
        );

        final reconstructedSM = await restartedService.getActiveStateMachine(testGroupId);
        expect(reconstructedSM, isNotNull);
        expect(reconstructedSM!.state.operationId, prep.operationId);
        expect(reconstructedSM.state.operationStatus, GroupEpochOperationStatus.preparing);
        expect(reconstructedSM.state.preparedMemberPeerIds, {testMember1});
        expect(reconstructedSM.state.isReEpochPending, isTrue);

        // The restarted service can finish the operation seamlessly
        final state = await restartedService.processPrepareAck(
          packet: GroupEpochPrepareAckPacket(
            operationId: prep.operationId,
            groupId: testGroupId,
            memberPeerId: testMember2,
            targetEpoch: 2,
            status: GroupEpochAckStatus.acknowledged,
            timestamp: testTimestamp,
          ),
          authenticatedSenderPeerId: testMember2,
        );
        expect(state.operationStatus, GroupEpochOperationStatus.committing);
      });

      test('3.2 Superseded operation history is preserved in database', () async {
        final op1 = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        final op2 = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );

        final history1 = await (db.select(db.groupEpochOperationsTable)
              ..where((t) => t.operationId.equals(op1.operationId)))
            .getSingle();
        final history2 = await (db.select(db.groupEpochOperationsTable)
              ..where((t) => t.operationId.equals(op2.operationId)))
            .getSingle();

        expect(history1.operationStatus, 'superseded');
        expect(history1.operationSequenceNumber, 1);
        expect(history2.operationStatus, 'preparing');
        expect(history2.operationSequenceNumber, 2);
      });

      test('3.3 Sequence number remains strictly monotonic across operations', () async {
        final op1 = await epochService.initiateReEpoch(groupId: testGroupId, requestingPeerId: testAdminId);
        final op2 = await epochService.initiateReEpoch(groupId: testGroupId, requestingPeerId: testAdminId);
        final op3 = await epochService.initiateReEpoch(groupId: testGroupId, requestingPeerId: testAdminId);

        expect(op1.operationSequenceNumber, 1);
        expect(op2.operationSequenceNumber, 2);
        expect(op3.operationSequenceNumber, 3);
      });
    });

    // =========================================================================
    // 4. Offline Reconciliation & Authoritative History
    // =========================================================================
    group('4. Offline Reconciliation & Authoritative History', () {
      test('4.1 Valid signed authoritative history is accepted and reconciles member state', () async {
        // Complete operation on admin node
        final prep = await epochService.initiateReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
        );
        for (final m in [testMember1, testMember2]) {
          await epochService.processPrepareAck(
            packet: GroupEpochPrepareAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: m,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: m,
          );
        }
        await epochService.commitReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: prep.operationId,
        );
        for (final m in [testMember1, testMember2]) {
          await epochService.processCommitAck(
            packet: GroupEpochCommitAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: m,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: m,
          );
        }
        await epochService.finalizeReEpoch(
          groupId: testGroupId,
          requestingPeerId: testAdminId,
          operationId: prep.operationId,
        );
        for (final m in [testMember1, testMember2]) {
          await epochService.processFinalizeAck(
            packet: GroupEpochFinalizeAckPacket(
              operationId: prep.operationId,
              groupId: testGroupId,
              memberPeerId: m,
              targetEpoch: 2,
              status: GroupEpochAckStatus.acknowledged,
              timestamp: testTimestamp,
            ),
            authenticatedSenderPeerId: m,
          );
        }

        // Admin generates authoritative signed history
        final signedHistory = await epochService.getAuthoritativeSignedHistory(testGroupId);
        expect(signedHistory.signature, isNotEmpty);

        // Status response
        final probe = GroupEpochStatusProbePacket(
          operationId: prep.operationId,
          groupId: testGroupId,
          requestingPeerId: testMember1,
          knownEpoch: 1,
          knownSequenceNumber: 0,
          timestamp: testTimestamp,
        );
        final response = await epochService.handleStatusProbe(
          probe: probe,
          authenticatedSenderPeerId: testMember1,
        );

        // Create independent member database simulating stale offline member
        final memberDb = AppDatabase(NativeDatabase.memory());
        final memberGroupRepo = DriftGroupRepository(memberDb);
        final memberIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        await memberIdentity.initialize();

        final memberService = GroupEpochServiceImpl(
          db: memberDb,
          groupRepository: memberGroupRepo,
          identityService: memberIdentity,
          localPeerId: testMember1,
          clock: () => testTimestamp,
        );

        // Stale group at epoch 1
        await memberGroupRepo.createGroup(Group(
          groupId: testGroupId,
          name: 'Stale Member Group',
          creatorId: testAdminId,
          adminId: testAdminId,
          epoch: 1,
          createdAt: testTimestamp,
          updatedAt: testTimestamp,
        ), addCreatorAsMember: false);

        // Seed trusted admin public key on member
        final adminPubKey = await adminIdentityService.getIdentityPublicKey();
        await memberDb.savePeerIdentity(PeerIdentitiesTableCompanion(
          peerId: const drift.Value(testAdminId),
          identityPublicKey: drift.Value(adminPubKey),
          safetyNumber: const drift.Value('123456'),
          trustStatus: const drift.Value('verified'),
          firstSeenAt: drift.Value(testTimestamp),
          lastSeenAt: drift.Value(testTimestamp),
        ));

        // Member reconciles with signed authoritative history
        await memberService.handleStatusResponse(
          response: response,
          signedHistory: signedHistory,
          authenticatedSenderPeerId: testAdminId,
        );

        // Member has caught up to epoch 2!
        final reconciledGroup = await memberDb.getGroup(testGroupId);
        expect(reconciledGroup!.epoch, 2);
        expect(reconciledGroup.isReEpochPending, isFalse);

        await memberDb.close();
      });

      test('4.2 Tampered or invalid Ed25519 signature is strictly rejected fail-closed', () async {
        await epochService.initiateReEpoch(groupId: testGroupId, requestingPeerId: testAdminId);
        final signedHistory = await epochService.getAuthoritativeSignedHistory(testGroupId);

        // Tamper with the signature bytes
        final tamperedHistory = signedHistory.copyWith(
          signature: signedHistory.signature.replaceRange(0, 4, 'AAAA'),
        );

        final probe = GroupEpochStatusProbePacket(
          operationId: signedHistory.operationId,
          groupId: testGroupId,
          requestingPeerId: testMember1,
          knownEpoch: 1,
          knownSequenceNumber: 0,
          timestamp: testTimestamp,
        );
        final response = await epochService.handleStatusProbe(
          probe: probe,
          authenticatedSenderPeerId: testMember1,
        );

        expect(
          () => epochService.handleStatusResponse(
            response: response,
            signedHistory: tamperedHistory,
            authenticatedSenderPeerId: testAdminId,
          ),
          throwsA(isA<GroupEpochSignatureException>()),
        );
      });

      test('4.3 Reconciling with superseded operation is rejected', () async {
        final op1 = await epochService.initiateReEpoch(groupId: testGroupId, requestingPeerId: testAdminId);
        await epochService.initiateReEpoch(groupId: testGroupId, requestingPeerId: testAdminId);

        // History for superseded op1
        final keyPair = await adminIdentityService.getKeyPair();
        final supersededHistory = await GroupEpochSignedHistory(
          groupId: testGroupId,
          operationId: op1.operationId,
          previousEpoch: 1,
          targetEpoch: 2,
          operationSequenceNumber: 1,
          adminPeerId: testAdminId,
          operationStatus: GroupEpochOperationStatus.superseded,
          timestamp: testTimestamp,
        ).sign(Ed25519(), keyPair);

        final response = GroupEpochStatusResponsePacket(
          operationId: op1.operationId,
          groupId: testGroupId,
          respondingPeerId: testAdminId,
          authoritativeEpoch: 1,
          authoritativeSequenceNumber: 1,
          operationStatus: GroupEpochOperationStatus.superseded,
          timestamp: testTimestamp,
        );

        expect(
          () => epochService.handleStatusResponse(
            response: response,
            signedHistory: supersededHistory,
            authenticatedSenderPeerId: testAdminId,
          ),
          throwsA(isA<GroupEpochReconciliationException>()),
        );
      });
    });
  });
}
