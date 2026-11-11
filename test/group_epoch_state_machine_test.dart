import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/models/group_epoch_packets.dart';
import 'package:meshlink/features/messages/domain/services/group_epoch_state_machine.dart';

void main() {
  const testGroupId = 'GRP-1730000000000-A1B2C3';
  const testAdminId = 'PEER-ADMIN-NODE';
  const testMember1 = 'PEER-MEMBER-01';
  const testMember2 = 'PEER-MEMBER-02';
  const testOpId = '0123456789abcdef0123456789abcdef';
  final testTimestamp = DateTime.utc(2026, 11, 11, 12, 0, 0);

  GroupEpochStateMachine createInitialMachine({
    int epoch = 1,
    int lastSequenceNumber = 0,
  }) {
    return GroupEpochStateMachine.initial(
      groupId: testGroupId,
      adminPeerId: testAdminId,
      epoch: epoch,
      lastSequenceNumber: lastSequenceNumber,
      timestamp: testTimestamp,
    );
  }

  group('Phase 9 Step 6.3.1 — Group Epoch State Machine Tests', () {
    // =========================================================================
    // 1. Valid Prepare initiation
    // =========================================================================
    test('1. Valid Prepare initiation transitions to preparing and freezes messaging', () {
      final machine = createInitialMachine();
      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalized);
      expect(machine.state.isReEpochPending, isFalse);
      expect(machine.canSendGroupMessages(testAdminId), isTrue);

      final state = machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
        timestamp: testTimestamp,
      );

      expect(state.operationStatus, GroupEpochOperationStatus.preparing);
      expect(state.operationId, testOpId);
      expect(state.previousEpoch, 1);
      expect(state.targetEpoch, 2);
      expect(state.currentEpoch, 1);
      expect(state.operationSequenceNumber, 1);
      expect(state.isReEpochPending, isTrue);
      expect(state.requiredMemberPeerIds, {testMember1, testMember2});
      expect(state.preparedMemberPeerIds, isEmpty);
      expect(state.committedMemberPeerIds, isEmpty);
      expect(state.finalizedMemberPeerIds, isEmpty);
      expect(machine.canSendGroupMessages(testAdminId), isFalse);
      expect(machine.canSendGroupMessages(testMember1), isFalse);
    });

    // =========================================================================
    // 2. Unauthorized admin rejection
    // =========================================================================
    test('2. Unauthorized non-admin initiation is rejected', () {
      final machine = createInitialMachine();

      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testMember1,
          operationId: testOpId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 1,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<GroupEpochAuthorizationException>()),
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalized);
      expect(machine.state.isReEpochPending, isFalse);
    });

    // =========================================================================
    // 3. Invalid operation ID rejection
    // =========================================================================
    test('3. Invalid operation ID is rejected', () {
      final machine = createInitialMachine();

      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: 'short-op-id',
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 1,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: '0123456789abcdef0123456789abcdef ', // trailing space
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 1,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // =========================================================================
    // 4. Wrong previous epoch rejection
    // =========================================================================
    test('4. Wrong previous epoch is rejected', () {
      final machine = createInitialMachine(epoch: 3);

      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: testOpId,
          previousEpoch: 1, // does not match currentEpoch 3
          targetEpoch: 2,
          sequenceNumber: 1,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 5. Target epoch must be exactly previous + 1
    // =========================================================================
    test('5. Target epoch must be exactly previous + 1', () {
      final machine = createInitialMachine(epoch: 2);

      // Skips an epoch (+2)
      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: testOpId,
          previousEpoch: 2,
          targetEpoch: 4,
          sequenceNumber: 1,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );

      // Same epoch (+0)
      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: testOpId,
          previousEpoch: 2,
          targetEpoch: 2,
          sequenceNumber: 1,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 6. Non-increasing sequence rejection
    // =========================================================================
    test('6. Non-increasing or reused sequence number is rejected', () {
      final machine = createInitialMachine(lastSequenceNumber: 5);

      // Reused sequence 5
      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: testOpId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 5,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );

      // Lower sequence 4
      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: testOpId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 4,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 7. Required active-member snapshot
    // =========================================================================
    test('7. Required active-member set is an immutable snapshot', () {
      final machine = createInitialMachine();
      final mutableSet = {testMember1, testMember2};

      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: mutableSet,
      );

      // Modifying the external set has no effect on the state machine
      mutableSet.add('PEER-NEW-MEMBER');
      expect(machine.state.requiredMemberPeerIds, {testMember1, testMember2});

      // Internal set is unmodifiable
      expect(
        () => machine.state.requiredMemberPeerIds.add('PEER-INTRUDER'),
        throwsUnsupportedError,
      );
    });

    // =========================================================================
    // 8. No transition before all Prepare ACKs
    // =========================================================================
    test('8. State remains preparing until all required members acknowledge Prepare', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      // Only 1 of 2 has prepared
      expect(machine.state.operationStatus, GroupEpochOperationStatus.preparing);
      expect(machine.state.preparedMemberPeerIds, {testMember1});
      expect(machine.state.isReEpochPending, isTrue);

      // Cannot advance to committing explicitly before all prepare ACKs
      expect(
        () => machine.advanceToCommitting(),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 9. Prepare ACK from unknown peer rejected
    // =========================================================================
    test('9. Prepare ACK from peer not in required member snapshot is rejected', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: 'PEER-UNKNOWN-NODE',
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );

      expect(machine.state.preparedMemberPeerIds, isEmpty);
    });

    // =========================================================================
    // 10. Prepare ACK from wrong operation rejected
    // =========================================================================
    test('10. Prepare ACK with mismatched operation ID is rejected', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      expect(
        () => machine.applyPrepareAck(
          operationId: 'fedcba9876543210fedcba9876543210',
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );
    });

    // =========================================================================
    // 11. Prepare ACK with pending rejected
    // =========================================================================
    test('11. Prepare ACK with pending status is rejected on the wire', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.pending,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );
    });

    // =========================================================================
    // 12. Failed Prepare ACK does not advance
    // =========================================================================
    test('12. Failed Prepare ACK is recorded as failure and does not advance', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.failed,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.preparing);
      expect(machine.state.preparedMemberPeerIds, isEmpty);
      expect(machine.state.prepareAcks[testMember1], GroupEpochAckStatus.failed);
      expect(machine.state.failureReason, isNotNull);
      expect(machine.state.isReEpochPending, isTrue);

      // Even if member2 succeeds, state cannot advance because member1 failed
      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember2,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.preparing);
      expect(machine.state.isReEpochPending, isTrue);
    });

    // =========================================================================
    // 13. Duplicate identical ACK is idempotent
    // =========================================================================
    test('13. Duplicate identical ACK returns current state idempotently', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      final stateBefore = machine.state;

      // Duplicate identical ACK
      final stateAfter = machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(stateAfter, equals(stateBefore));
      expect(machine.state.preparedMemberPeerIds.length, 1);
    });

    // =========================================================================
    // 14. Conflicting duplicate ACK rejected
    // =========================================================================
    test('14. Conflicting duplicate ACK is rejected', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      // State is still preparing (waiting for member2)
      expect(machine.state.operationStatus, GroupEpochOperationStatus.preparing);

      // Conflicting ACK with status 'failed' from member1
      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.failed,
        ),
        throwsA(isA<GroupEpochConflictException>()),
      );
    });

    // =========================================================================
    // 15. Commit cannot be skipped
    // =========================================================================
    test('15. Commit cannot be skipped while operation is preparing', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      // Attempting to send Commit ACK while in preparing phase
      expect(
        () => machine.applyCommitAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 16. No transition before all Commit ACKs
    // =========================================================================
    test('16. State remains committing until all required members acknowledge Commit', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
      );

      // Both prepare
      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember2,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);

      // Only member1 commits
      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);
      expect(machine.state.committedMemberPeerIds, {testMember1});
      expect(machine.state.isReEpochPending, isTrue);

      // Cannot advance to finalizing before member2 commits
      expect(
        () => machine.advanceToFinalizing(),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 17. Finalize cannot be skipped
    // =========================================================================
    test('17. Finalize cannot be skipped while operation is committing', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);

      // Attempting to send Finalize ACK while in committing phase
      expect(
        () => machine.applyFinalizeAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 18. No epoch update before all Finalize ACKs
    // =========================================================================
    test('18. Epoch is not updated before all members acknowledge Finalize', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
      );

      // Both prepare
      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember2,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      // Both commit
      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember2,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalizing);

      // Member1 finalizes
      machine.applyFinalizeAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      // Epoch MUST still be 1, messaging MUST still be frozen
      expect(machine.state.currentEpoch, 1);
      expect(machine.state.isReEpochPending, isTrue);
      expect(machine.canSendGroupMessages(testAdminId), isFalse);
      expect(machine.canSendGroupMessages(testMember1), isFalse);
    });

    // =========================================================================
    // 19. Finalization updates epoch exactly once
    // =========================================================================
    test('19. Finalization updates current epoch to target epoch exactly once and unfreezes', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalizing);

      machine.applyFinalizeAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalized);
      expect(machine.state.currentEpoch, 2);
      expect(machine.state.isReEpochPending, isFalse);
      expect(machine.canSendGroupMessages(testAdminId), isTrue);
      expect(machine.canSendGroupMessages(testMember1), isTrue);

      // advanceToFinalized is idempotent once finalized
      machine.advanceToFinalized();
      expect(machine.state.currentEpoch, 2);
    });

    // =========================================================================
    // 20. Messaging remains frozen until finalization
    // =========================================================================
    test('20. Messaging is blocked throughout Preparing, Committing, and Finalizing', () {
      final machine = createInitialMachine();
      expect(machine.canSendGroupMessages(testAdminId), isTrue);

      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );
      expect(machine.canSendGroupMessages(testAdminId), isFalse);
      expect(machine.canSendGroupMessages(testMember1), isFalse);

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);
      expect(machine.canSendGroupMessages(testAdminId), isFalse);

      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalizing);
      expect(machine.canSendGroupMessages(testAdminId), isFalse);

      machine.applyFinalizeAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalized);
      expect(machine.canSendGroupMessages(testAdminId), isTrue);
    });

    // =========================================================================
    // 21. Membership snapshot cannot silently change
    // =========================================================================
    test('21. Membership changes cannot silently modify the operation required-member set', () {
      final machine = createInitialMachine();
      final memberSet = {testMember1};

      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: memberSet,
      );

      final capturedSet = machine.state.requiredMemberPeerIds;

      // An ACK from a newly added member outside the snapshot is rejected
      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: 'PEER-NEW-NODE',
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );

      expect(machine.state.requiredMemberPeerIds, equals(capturedSet));
    });

    // =========================================================================
    // 22. Stale operation ACK rejected
    // =========================================================================
    test('22. Stale operation ACK is rejected', () {
      final machine = createInitialMachine();
      const oldOpId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const newOpId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: oldOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      // Supersede with higher sequence
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: newOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 2,
        requiredMemberPeerIds: {testMember1},
      );

      // ACK for the stale oldOpId
      expect(
        () => machine.applyPrepareAck(
          operationId: oldOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );
    });

    // =========================================================================
    // 23. Wrong sequence rejected
    // =========================================================================
    test('23. Sequence number lower than or equal to active sequence is rejected', () {
      final machine = createInitialMachine(lastSequenceNumber: 10);

      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: testOpId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 10,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );

      expect(
        () => machine.initiatePrepare(
          requestingPeerId: testAdminId,
          operationId: testOpId,
          previousEpoch: 1,
          targetEpoch: 2,
          sequenceNumber: 9,
          requiredMemberPeerIds: {testMember1},
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 24. Wrong target epoch rejected
    // =========================================================================
    test('24. ACK with wrong target epoch is rejected', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 99, // Mismatched target epoch
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );
    });

    // =========================================================================
    // 25. ACK after finalization rejected
    // =========================================================================
    test('25. Any ACK after finalization is rejected', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      machine.applyFinalizeAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalized);

      // Attempting further ACKs after finalization
      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );

      expect(
        () => machine.applyCommitAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );

      expect(
        () => machine.applyFinalizeAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochTransitionException>()),
      );
    });

    // =========================================================================
    // 26. Failure preserves pending/frozen state
    // =========================================================================
    test('26. Failed Commit or Finalize ACK preserves pending/frozen state', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);

      // Failed commit
      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.failed,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);
      expect(machine.state.isReEpochPending, isTrue);
      expect(machine.state.currentEpoch, 1);
      expect(machine.canSendGroupMessages(testAdminId), isFalse);
    });

    // =========================================================================
    // 27. State serialization and snapshot restoration
    // =========================================================================
    test('27. State serialization to Map/JSON and snapshot restoration preserves all state', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
        timestamp: testTimestamp,
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
        timestamp: testTimestamp,
      );

      // Snapshot mid-way in prepare
      final stateSnapshot = machine.state;
      final jsonStr = stateSnapshot.toJson();
      final restoredState = GroupEpochState.fromJson(jsonStr);

      expect(restoredState, equals(stateSnapshot));
      expect(restoredState.hashCode, equals(stateSnapshot.hashCode));
      expect(restoredState.operationStatus, GroupEpochOperationStatus.preparing);
      expect(restoredState.preparedMemberPeerIds, {testMember1});
      expect(restoredState.requiredMemberPeerIds, {testMember1, testMember2});
      expect(restoredState.isReEpochPending, isTrue);

      // Restored state machine can continue transitions seamlessly
      final restoredMachine = GroupEpochStateMachine.fromSnapshot(restoredState);
      restoredMachine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember2,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(restoredMachine.state.operationStatus, GroupEpochOperationStatus.committing);
      expect(restoredMachine.state.preparedMemberPeerIds, {testMember1, testMember2});
    });

    // =========================================================================
    // 28. Solo group re-epoch (empty requiredMemberPeerIds)
    // =========================================================================
    test('28. Solo group re-epoch with empty required members completes via explicit advancement', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: const {},
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.preparing);
      expect(machine.state.isReEpochPending, isTrue);

      machine.advanceToCommitting();
      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);
      expect(machine.state.isReEpochPending, isTrue);

      machine.advanceToFinalizing();
      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalizing);
      expect(machine.state.isReEpochPending, isTrue);

      machine.advanceToFinalized();
      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalized);
      expect(machine.state.currentEpoch, 2);
      expect(machine.state.isReEpochPending, isFalse);
      expect(machine.canSendGroupMessages(testAdminId), isTrue);
    });

    // =========================================================================
    // 29. Admin sending member ACK when admin is not in requiredMemberPeerIds
    // =========================================================================
    test('29. Admin ACK is rejected if admin is not in captured requiredMemberPeerIds', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1}, // Admin not included
      );

      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testAdminId,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );
    });

    // =========================================================================
    // 30. Wire packet integration: processPrepareAck, processCommitAck, processFinalizeAck
    // =========================================================================
    test('30. Full lifecycle succeeds via wire packet models', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      final prepareAckPacket = GroupEpochPrepareAckPacket(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
        timestamp: testTimestamp,
      );
      machine.processPrepareAck(prepareAckPacket);
      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);

      final commitAckPacket = GroupEpochCommitAckPacket(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
        timestamp: testTimestamp,
      );
      machine.processCommitAck(commitAckPacket);
      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalizing);

      final finalizeAckPacket = GroupEpochFinalizeAckPacket(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
        timestamp: testTimestamp,
      );
      machine.processFinalizeAck(finalizeAckPacket);
      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalized);
      expect(machine.state.currentEpoch, 2);
      expect(machine.state.isReEpochPending, isFalse);
    });

    // =========================================================================
    // 31. Commit ACK and Finalize ACK from unknown peer rejected
    // =========================================================================
    test('31. Commit and Finalize ACKs from unknown peers are rejected', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(
        () => machine.applyCommitAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: 'PEER-INTRUDER',
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );

      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(
        () => machine.applyFinalizeAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: 'PEER-INTRUDER',
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );
    });

    // =========================================================================
    // 32. Commit and Finalize duplicate conflicting ACKs rejected
    // =========================================================================
    test('32. Conflicting duplicate Commit and Finalize ACKs are rejected', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1, testMember2},
      );
      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );
      machine.applyPrepareAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember2,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.committing);

      // Member1 commits
      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      // Conflicting commit ack from member1
      expect(
        () => machine.applyCommitAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.failed,
        ),
        throwsA(isA<GroupEpochConflictException>()),
      );

      // Member2 commits
      machine.applyCommitAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember2,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      expect(machine.state.operationStatus, GroupEpochOperationStatus.finalizing);

      // Member1 finalizes
      machine.applyFinalizeAck(
        operationId: testOpId,
        groupId: testGroupId,
        memberPeerId: testMember1,
        targetEpoch: 2,
        status: GroupEpochAckStatus.acknowledged,
      );

      // Conflicting finalize ack from member1
      expect(
        () => machine.applyFinalizeAck(
          operationId: testOpId,
          groupId: testGroupId,
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.failed,
        ),
        throwsA(isA<GroupEpochConflictException>()),
      );
    });

    // =========================================================================
    // 33. Superseding an unfinalized operation with higher sequence number
    // =========================================================================
    test('33. Superseding an active unfinalized operation succeeds with strictly higher sequence', () {
      final machine = createInitialMachine();
      const op1 = '11111111111111111111111111111111';
      const op2 = '22222222222222222222222222222222';

      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: op1,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );
      expect(machine.state.operationId, op1);

      // Superseding with sequence 2
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: op2,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 2,
        requiredMemberPeerIds: {testMember1, testMember2},
      );

      expect(machine.state.operationId, op2);
      expect(machine.state.operationSequenceNumber, 2);
      expect(machine.state.requiredMemberPeerIds, {testMember1, testMember2});
    });

    // =========================================================================
    // 34. Group ID mismatch rejected across all ACKs
    // =========================================================================
    test('34. Group ID mismatch is rejected across all ACK stages', () {
      final machine = createInitialMachine();
      machine.initiatePrepare(
        requestingPeerId: testAdminId,
        operationId: testOpId,
        previousEpoch: 1,
        targetEpoch: 2,
        sequenceNumber: 1,
        requiredMemberPeerIds: {testMember1},
      );

      expect(
        () => machine.applyPrepareAck(
          operationId: testOpId,
          groupId: 'GRP-9999999999999-FFFFFF',
          memberPeerId: testMember1,
          targetEpoch: 2,
          status: GroupEpochAckStatus.acknowledged,
        ),
        throwsA(isA<InvalidGroupEpochAckException>()),
      );
    });
  });
}
