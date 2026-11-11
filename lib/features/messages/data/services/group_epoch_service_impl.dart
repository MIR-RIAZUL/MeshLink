// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/group_epoch_packets.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';
import 'package:meshlink/features/messages/domain/models/group_epoch_signed_history.dart';
import 'package:meshlink/features/messages/domain/repositories/group_repository.dart';
import 'package:meshlink/features/messages/domain/services/group_epoch_service.dart';
import 'package:meshlink/features/messages/domain/services/group_epoch_state_machine.dart';

/// Production runtime implementation of [GroupEpochService].
///
/// Phase 9 Step 6.3.2: Re-Epoch Runtime Service and Durable Persistence Integration
///
/// Integrates:
/// - [GroupEpochStateMachine] for pure domain transition validation.
/// - Drift Schema v5 ([GroupEpochOperationsTable], [GroupEpochSyncTable], [GroupsTable]).
/// - Administrator exclusion policy (admin coordinates locally; remote active members must ACK).
/// - Atomic database transactions ensuring consistency across state machine snapshots and SQLite records.
/// - Authenticated Ed25519 authoritative operation history signing and verification.
/// - Offline-member reconciliation via status probes.
/// - Fail-closed messaging freeze while re-epoching is pending.
class GroupEpochServiceImpl implements GroupEpochService {
  GroupEpochServiceImpl({
    required AppDatabase db,
    required GroupRepository groupRepository,
    required MeshIdentityService identityService,
    required String localPeerId,
    Ed25519? ed25519,
    DateTime Function()? clock,
  })  : _db = db,
        _groupRepo = groupRepository,
        _identityService = identityService,
        _localPeerId = localPeerId,
        _ed25519 = ed25519 ?? Ed25519(),
        _clock = clock;

  final AppDatabase _db;
  final GroupRepository _groupRepo;
  final MeshIdentityService _identityService;
  final String _localPeerId;
  final Ed25519 _ed25519;
  final DateTime Function()? _clock;

  DateTime get _now => _clock != null ? _clock() : DateTime.now().toUtc();

  /// Generates a standardized 32-hexadecimal (128-bit) operation identifier.
  static String generateOperationId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ===========================================================================
  // 1. Prepare Initiation (Admin Only)
  // ===========================================================================

  @override
  Future<GroupEpochPreparePacket> initiateReEpoch({
    required String groupId,
    required String requestingPeerId,
    String? operationId,
  }) async {
    final nowUtc = _now;

    return await _db.transaction(() async {
      // 1. Fetch group metadata
      final group = await _db.getGroup(groupId);
      if (group == null) {
        throw GroupNotFoundException(groupId);
      }

      // 2. Authorization check: Admin only
      if (requestingPeerId != group.adminId) {
        throw GroupEpochAuthorizationException(
          groupId: groupId,
          requestingPeerId: requestingPeerId,
          adminPeerId: group.adminId,
        );
      }

      // 3. Admin exclusion contract:
      // Active group members are fetched, and the administrator is excluded from requiredMemberPeerIds.
      final activeMemberEntries =
          await _groupRepo.getMembersByStatus(groupId, GroupMemberStatus.active);

      final remoteRequiredMembers = activeMemberEntries
          .where((m) => m.peerId != group.adminId)
          .map((m) => m.peerId)
          .toSet();

      // 4. Monotonic operation sequence number
      final nextSequenceNumber = group.operationSequenceNumber + 1;

      // 5. Operation identity
      final opId = operationId != null
          ? GroupEpochValidator.validateAndNormalizeOperationId(operationId)
          : generateOperationId();

      // 6. If an existing operation is pending, mark it 'superseded' in history
      if (group.isReEpochPending && group.activeReEpochOperationId != null) {
        await (_db.update(_db.groupEpochOperationsTable)
              ..where((t) => t.operationId.equals(group.activeReEpochOperationId!)))
            .write(
          GroupEpochOperationsTableCompanion(
            operationStatus: const Value('superseded'),
            updatedAt: Value(nowUtc),
          ),
        );
      }

      // 7. Validate transition via pure GroupEpochStateMachine
      final stateMachine = GroupEpochStateMachine.initial(
        groupId: groupId,
        adminPeerId: group.adminId,
        epoch: group.epoch,
        lastSequenceNumber: group.operationSequenceNumber,
        timestamp: nowUtc,
      );

      final newState = stateMachine.initiatePrepare(
        requestingPeerId: requestingPeerId,
        operationId: opId,
        previousEpoch: group.epoch,
        targetEpoch: group.epoch + 1,
        sequenceNumber: nextSequenceNumber,
        requiredMemberPeerIds: remoteRequiredMembers,
        timestamp: nowUtc,
      );

      // 8. Persist new operation record
      await _db.into(_db.groupEpochOperationsTable).insert(
            GroupEpochOperationsTableCompanion.insert(
              operationId: opId,
              groupId: groupId,
              previousEpoch: group.epoch,
              targetEpoch: group.epoch + 1,
              operationSequenceNumber: nextSequenceNumber,
              operationStatus: newState.operationStatus.toJson(),
              createdAt: nowUtc,
              updatedAt: nowUtc,
            ),
          );

      // 9. Persist per-member synchronization tracking
      for (final memberPeerId in remoteRequiredMembers) {
        await _db.into(_db.groupEpochSyncTable).insert(
              GroupEpochSyncTableCompanion.insert(
                operationId: opId,
                groupId: groupId,
                memberPeerId: memberPeerId,
                prepareStatus: const Value('pending'),
                commitStatus: const Value('pending'),
                finalizeStatus: const Value('pending'),
                updatedAt: nowUtc,
              ),
            );
      }

      // 10. Update group row with freeze and pending operation
      await (_db.update(_db.groupsTable)..where((t) => t.groupId.equals(groupId)))
          .write(
        GroupsTableCompanion(
          isReEpochPending: const Value(true),
          activeReEpochOperationId: Value(opId),
          preparedEpoch: Value(group.epoch + 1),
          operationSequenceNumber: Value(nextSequenceNumber),
          updatedAt: Value(nowUtc),
        ),
      );

      // 11. Construct canonical Prepare packet
      return GroupEpochPreparePacket(
        operationId: opId,
        groupId: groupId,
        previousEpoch: group.epoch,
        targetEpoch: group.epoch + 1,
        operationSequenceNumber: nextSequenceNumber,
        adminPeerId: group.adminId,
        timestamp: nowUtc,
      );
    });
  }

  // ===========================================================================
  // 2. Prepare Acknowledgement Processing
  // ===========================================================================

  @override
  Future<GroupEpochState> processPrepareAck({
    required GroupEpochPrepareAckPacket packet,
    required String authenticatedSenderPeerId,
  }) async {
    final nowUtc = _now;

    // Verify authenticated transport identity matches claimed packet sender
    if (authenticatedSenderPeerId != packet.memberPeerId) {
      throw InvalidGroupEpochAckException(
        'Authenticated transport identity "$authenticatedSenderPeerId" '
        'does not match claimed packet member ID "${packet.memberPeerId}".',
      );
    }

    return await _db.transaction(() async {
      final op = await _getOperationRecord(packet.operationId);
      if (op.operationStatus == 'superseded') {
        throw InvalidGroupEpochAckException(
          'Operation "${packet.operationId}" has been superseded.',
        );
      }

      final stateMachine = await _reconstructStateMachine(op.groupId, op.operationId);
      if (stateMachine == null) {
        throw InvalidGroupEpochAckException(
          'Cannot reconstruct state machine for operation "${packet.operationId}".',
        );
      }

      // Apply ACK to state machine
      final updatedState = stateMachine.processPrepareAck(packet);

      // Persist member prepare status
      await (_db.update(_db.groupEpochSyncTable)
            ..where((t) =>
                t.operationId.equals(packet.operationId) &
                t.memberPeerId.equals(packet.memberPeerId)))
          .write(
        GroupEpochSyncTableCompanion(
          prepareStatus: Value(packet.status.toJson()),
          updatedAt: Value(nowUtc),
        ),
      );

      // Persist operation status progression if changed
      if (updatedState.operationStatus != GroupEpochOperationStatus.fromString(op.operationStatus)) {
        await (_db.update(_db.groupEpochOperationsTable)
              ..where((t) => t.operationId.equals(packet.operationId)))
            .write(
          GroupEpochOperationsTableCompanion(
            operationStatus: Value(updatedState.operationStatus.toJson()),
            updatedAt: Value(nowUtc),
          ),
        );
      }

      return updatedState;
    });
  }

  // ===========================================================================
  // 3. Commit Phase Initiation
  // ===========================================================================

  @override
  Future<GroupEpochCommitPacket> commitReEpoch({
    required String groupId,
    required String requestingPeerId,
    required String operationId,
  }) async {
    final nowUtc = _now;

    return await _db.transaction(() async {
      final group = await _db.getGroup(groupId);
      if (group == null) throw GroupNotFoundException(groupId);
      if (requestingPeerId != group.adminId) {
        throw GroupEpochAuthorizationException(
          groupId: groupId,
          requestingPeerId: requestingPeerId,
          adminPeerId: group.adminId,
        );
      }

      final op = await _getOperationRecord(operationId);
      if (op.operationStatus == 'superseded') {
        throw InvalidGroupEpochTransitionException(
          'Cannot commit: operation "$operationId" has been superseded.',
        );
      }

      final stateMachine = await _reconstructStateMachine(groupId, operationId);
      if (stateMachine == null) {
        throw InvalidGroupEpochTransitionException(
          'Cannot reconstruct state machine for operation "$operationId".',
        );
      }

      // For solo groups or ready groups, ensure committed state
      if (stateMachine.state.operationStatus == GroupEpochOperationStatus.preparing) {
        stateMachine.advanceToCommitting(nowUtc);
      }

      if (stateMachine.state.operationStatus != GroupEpochOperationStatus.committing) {
        throw InvalidGroupEpochTransitionException(
          'Cannot emit Commit packet: operation is in ${stateMachine.state.operationStatus} status.',
        );
      }

      // Update operation table status
      await (_db.update(_db.groupEpochOperationsTable)
            ..where((t) => t.operationId.equals(operationId)))
          .write(
        GroupEpochOperationsTableCompanion(
          operationStatus: const Value('committing'),
          updatedAt: Value(nowUtc),
        ),
      );

      return GroupEpochCommitPacket(
        operationId: operationId,
        groupId: groupId,
        previousEpoch: op.previousEpoch,
        targetEpoch: op.targetEpoch,
        sequenceNumber: op.operationSequenceNumber,
        adminPeerId: group.adminId,
        timestamp: nowUtc,
      );
    });
  }

  // ===========================================================================
  // 4. Commit Acknowledgement Processing
  // ===========================================================================

  @override
  Future<GroupEpochState> processCommitAck({
    required GroupEpochCommitAckPacket packet,
    required String authenticatedSenderPeerId,
  }) async {
    final nowUtc = _now;

    if (authenticatedSenderPeerId != packet.memberPeerId) {
      throw InvalidGroupEpochAckException(
        'Authenticated transport identity "$authenticatedSenderPeerId" '
        'does not match claimed packet member ID "${packet.memberPeerId}".',
      );
    }

    return await _db.transaction(() async {
      final op = await _getOperationRecord(packet.operationId);
      if (op.operationStatus == 'superseded') {
        throw InvalidGroupEpochAckException(
          'Operation "${packet.operationId}" has been superseded.',
        );
      }

      final stateMachine = await _reconstructStateMachine(op.groupId, op.operationId);
      if (stateMachine == null) {
        throw InvalidGroupEpochAckException(
          'Cannot reconstruct state machine for operation "${packet.operationId}".',
        );
      }

      final updatedState = stateMachine.processCommitAck(packet);

      await (_db.update(_db.groupEpochSyncTable)
            ..where((t) =>
                t.operationId.equals(packet.operationId) &
                t.memberPeerId.equals(packet.memberPeerId)))
          .write(
        GroupEpochSyncTableCompanion(
          commitStatus: Value(packet.status.toJson()),
          updatedAt: Value(nowUtc),
        ),
      );

      if (updatedState.operationStatus != GroupEpochOperationStatus.fromString(op.operationStatus)) {
        await (_db.update(_db.groupEpochOperationsTable)
              ..where((t) => t.operationId.equals(packet.operationId)))
            .write(
          GroupEpochOperationsTableCompanion(
            operationStatus: Value(updatedState.operationStatus.toJson()),
            updatedAt: Value(nowUtc),
          ),
        );
      }

      return updatedState;
    });
  }

  // ===========================================================================
  // 5. Finalize Phase Initiation
  // ===========================================================================

  @override
  Future<GroupEpochFinalizePacket> finalizeReEpoch({
    required String groupId,
    required String requestingPeerId,
    required String operationId,
  }) async {
    final nowUtc = _now;

    return await _db.transaction(() async {
      final group = await _db.getGroup(groupId);
      if (group == null) throw GroupNotFoundException(groupId);
      if (requestingPeerId != group.adminId) {
        throw GroupEpochAuthorizationException(
          groupId: groupId,
          requestingPeerId: requestingPeerId,
          adminPeerId: group.adminId,
        );
      }

      final op = await _getOperationRecord(operationId);
      if (op.operationStatus == 'superseded') {
        throw InvalidGroupEpochTransitionException(
          'Cannot finalize: operation "$operationId" has been superseded.',
        );
      }

      final stateMachine = await _reconstructStateMachine(groupId, operationId);
      if (stateMachine == null) {
        throw InvalidGroupEpochTransitionException(
          'Cannot reconstruct state machine for operation "$operationId".',
        );
      }

      if (stateMachine.state.operationStatus == GroupEpochOperationStatus.committing) {
        stateMachine.advanceToFinalizing(nowUtc);
      }

      if (stateMachine.state.operationStatus != GroupEpochOperationStatus.finalizing) {
        throw InvalidGroupEpochTransitionException(
          'Cannot emit Finalize packet: operation is in ${stateMachine.state.operationStatus} status.',
        );
      }

      await (_db.update(_db.groupEpochOperationsTable)
            ..where((t) => t.operationId.equals(operationId)))
          .write(
        GroupEpochOperationsTableCompanion(
          operationStatus: const Value('finalizing'),
          updatedAt: Value(nowUtc),
        ),
      );

      return GroupEpochFinalizePacket(
        operationId: operationId,
        groupId: groupId,
        previousEpoch: op.previousEpoch,
        targetEpoch: op.targetEpoch,
        sequenceNumber: op.operationSequenceNumber,
        adminPeerId: group.adminId,
        timestamp: nowUtc,
      );
    });
  }

  // ===========================================================================
  // 6. Finalize Acknowledgement Processing
  // ===========================================================================

  @override
  Future<GroupEpochState> processFinalizeAck({
    required GroupEpochFinalizeAckPacket packet,
    required String authenticatedSenderPeerId,
  }) async {
    final nowUtc = _now;

    if (authenticatedSenderPeerId != packet.memberPeerId) {
      throw InvalidGroupEpochAckException(
        'Authenticated transport identity "$authenticatedSenderPeerId" '
        'does not match claimed packet member ID "${packet.memberPeerId}".',
      );
    }

    return await _db.transaction(() async {
      final op = await _getOperationRecord(packet.operationId);
      if (op.operationStatus == 'superseded') {
        throw InvalidGroupEpochAckException(
          'Operation "${packet.operationId}" has been superseded.',
        );
      }

      final stateMachine = await _reconstructStateMachine(op.groupId, op.operationId);
      if (stateMachine == null) {
        throw InvalidGroupEpochAckException(
          'Cannot reconstruct state machine for operation "${packet.operationId}".',
        );
      }

      final updatedState = stateMachine.processFinalizeAck(packet);

      await (_db.update(_db.groupEpochSyncTable)
            ..where((t) =>
                t.operationId.equals(packet.operationId) &
                t.memberPeerId.equals(packet.memberPeerId)))
          .write(
        GroupEpochSyncTableCompanion(
          finalizeStatus: Value(packet.status.toJson()),
          updatedAt: Value(nowUtc),
        ),
      );

      if (updatedState.operationStatus != GroupEpochOperationStatus.fromString(op.operationStatus)) {
        await (_db.update(_db.groupEpochOperationsTable)
              ..where((t) => t.operationId.equals(packet.operationId)))
            .write(
          GroupEpochOperationsTableCompanion(
            operationStatus: Value(updatedState.operationStatus.toJson()),
            updatedAt: Value(nowUtc),
          ),
        );
      }

      // If finalization completed: update groupsTable atomically!
      if (updatedState.operationStatus == GroupEpochOperationStatus.finalized) {
        await (_db.update(_db.groupsTable)..where((t) => t.groupId.equals(op.groupId)))
            .write(
          GroupsTableCompanion(
            epoch: Value(updatedState.currentEpoch),
            isReEpochPending: const Value(false),
            activeReEpochOperationId: const Value(null),
            preparedEpoch: const Value(null),
            updatedAt: Value(nowUtc),
          ),
        );
      }

      return updatedState;
    });
  }

  // ===========================================================================
  // 7. Status Probe & Signed Authoritative History
  // ===========================================================================

  @override
  Future<GroupEpochStatusResponsePacket> handleStatusProbe({
    required GroupEpochStatusProbePacket probe,
    required String authenticatedSenderPeerId,
  }) async {
    final nowUtc = _now;

    final group = await _db.getGroup(probe.groupId);
    if (group == null) throw GroupNotFoundException(probe.groupId);

    // Query latest operation for the group
    final op = await (_db.select(_db.groupEpochOperationsTable)
          ..where((t) => t.groupId.equals(probe.groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.operationSequenceNumber)])
          ..limit(1))
        .getSingleOrNull();

    if (op == null) {
      return GroupEpochStatusResponsePacket(
        operationId: probe.operationId,
        groupId: probe.groupId,
        respondingPeerId: _localPeerId,
        authoritativeEpoch: group.epoch,
        authoritativeSequenceNumber: group.operationSequenceNumber,
        operationStatus: GroupEpochOperationStatus.finalized,
        timestamp: nowUtc,
      );
    }

    return GroupEpochStatusResponsePacket(
      operationId: op.operationId,
      groupId: probe.groupId,
      respondingPeerId: _localPeerId,
      authoritativeEpoch: op.operationStatus == 'finalized' ? op.targetEpoch : group.epoch,
      authoritativeSequenceNumber: op.operationSequenceNumber,
      operationStatus: GroupEpochOperationStatus.fromString(op.operationStatus),
      targetEpoch: op.targetEpoch,
      previousEpoch: op.previousEpoch,
      isReEpochPending: group.isReEpochPending,
      timestamp: nowUtc,
    );
  }

  @override
  Future<GroupEpochSignedHistory> getAuthoritativeSignedHistory(String groupId) async {
    final group = await _db.getGroup(groupId);
    if (group == null) throw GroupNotFoundException(groupId);

    final op = await (_db.select(_db.groupEpochOperationsTable)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.operationSequenceNumber)])
          ..limit(1))
        .getSingleOrNull();

    if (op == null) {
      throw GroupEpochReconciliationException(
        'No re-epoch operation history exists for group $groupId to sign.',
      );
    }

    final unsignedHistory = GroupEpochSignedHistory(
      groupId: groupId,
      operationId: op.operationId,
      previousEpoch: op.previousEpoch,
      targetEpoch: op.targetEpoch,
      operationSequenceNumber: op.operationSequenceNumber,
      adminPeerId: group.adminId,
      operationStatus: GroupEpochOperationStatus.fromString(op.operationStatus),
      timestamp: _now,
    );

    final keyPair = await _identityService.getKeyPair();
    return await unsignedHistory.sign(_ed25519, keyPair);
  }

  @override
  Future<void> handleStatusResponse({
    required GroupEpochStatusResponsePacket response,
    required GroupEpochSignedHistory signedHistory,
    required String authenticatedSenderPeerId,
  }) async {
    final nowUtc = _now;

    // 1. Group identity match
    if (response.groupId != signedHistory.groupId) {
      throw const GroupEpochReconciliationException(
        'Group ID mismatch between status response and signed history.',
      );
    }

    final localGroup = await _db.getGroup(response.groupId);
    if (localGroup == null) throw GroupNotFoundException(response.groupId);

    // 2. Reject mismatched operation identity
    if (response.operationId != signedHistory.operationId) {
      throw const GroupEpochReconciliationException(
        'Operation ID mismatch between status response and signed history.',
      );
    }

    // 3. Do not trust administrator claimed in packet: verify against local group's admin
    if (signedHistory.adminPeerId != localGroup.adminId) {
      throw GroupEpochSignatureException(
        'Claimed administrator "${signedHistory.adminPeerId}" does not match local group administrator "${localGroup.adminId}".',
      );
    }

    // 4. Retrieve administrator's Ed25519 public key from PeerIdentitiesTable
    final adminIdentity = await _db.getPeerIdentity(localGroup.adminId);
    if (adminIdentity == null) {
      throw GroupEpochSignatureException(
        'Administrator "${localGroup.adminId}" identity public key not found.',
      );
    }
    if (adminIdentity.trustStatus.trim().toLowerCase() == 'compromised') {
      throw const GroupEpochSignatureException(
        'Cannot reconcile: administrator identity is marked as compromised.',
      );
    }

    // 5. Verify Ed25519 signature
    final adminPubKeyBytes = MeshIdentityService.decodePublicKey(adminIdentity.identityPublicKey);
    final isSigValid = await signedHistory.verify(_ed25519, adminPubKeyBytes);
    if (!isSigValid) {
      throw const GroupEpochSignatureException(
        'Cryptographic verification of authoritative history failed: invalid signature.',
      );
    }

    // 6. Monotonic sequence check: reject stale sequences
    if (signedHistory.operationSequenceNumber < localGroup.operationSequenceNumber) {
      throw GroupEpochReconciliationException(
        'Authoritative history sequence (${signedHistory.operationSequenceNumber}) is lower than local sequence (${localGroup.operationSequenceNumber}).',
      );
    }

    // 7. Handle reconciliation in a transaction
    await _db.transaction(() async {
      // Reject superseded operations
      if (signedHistory.operationStatus == GroupEpochOperationStatus.superseded) {
        throw const GroupEpochReconciliationException(
          'Cannot reconcile with an operation marked superseded.',
        );
      }

      if (signedHistory.operationStatus == GroupEpochOperationStatus.finalized) {
        if (signedHistory.targetEpoch > localGroup.epoch) {
          // Member catches up to finalized epoch
          await (_db.update(_db.groupsTable)..where((t) => t.groupId.equals(localGroup.groupId)))
              .write(
            GroupsTableCompanion(
              epoch: Value(signedHistory.targetEpoch),
              isReEpochPending: const Value(false),
              activeReEpochOperationId: const Value(null),
              preparedEpoch: const Value(null),
              operationSequenceNumber: Value(signedHistory.operationSequenceNumber),
              updatedAt: Value(nowUtc),
            ),
          );

          await _db.into(_db.groupEpochOperationsTable).insertOnConflictUpdate(
                GroupEpochOperationsTableCompanion.insert(
                  operationId: signedHistory.operationId,
                  groupId: signedHistory.groupId,
                  previousEpoch: signedHistory.previousEpoch,
                  targetEpoch: signedHistory.targetEpoch,
                  operationSequenceNumber: signedHistory.operationSequenceNumber,
                  operationStatus: 'finalized',
                  createdAt: signedHistory.timestamp,
                  updatedAt: nowUtc,
                ),
              );
        }
      } else {
        // Active ongoing operation: set pending and update sequence
        await (_db.update(_db.groupsTable)..where((t) => t.groupId.equals(localGroup.groupId)))
            .write(
          GroupsTableCompanion(
            isReEpochPending: const Value(true),
            activeReEpochOperationId: Value(signedHistory.operationId),
            preparedEpoch: Value(signedHistory.targetEpoch),
            operationSequenceNumber: Value(signedHistory.operationSequenceNumber),
            updatedAt: Value(nowUtc),
          ),
        );

        await _db.into(_db.groupEpochOperationsTable).insertOnConflictUpdate(
              GroupEpochOperationsTableCompanion.insert(
                operationId: signedHistory.operationId,
                groupId: signedHistory.groupId,
                previousEpoch: signedHistory.previousEpoch,
                targetEpoch: signedHistory.targetEpoch,
                operationSequenceNumber: signedHistory.operationSequenceNumber,
                operationStatus: signedHistory.operationStatus.toJson(),
                createdAt: signedHistory.timestamp,
                updatedAt: nowUtc,
              ),
            );
      }
    });
  }

  // ===========================================================================
  // 8. Reconstruct State Machine & Messaging Verification
  // ===========================================================================

  @override
  Future<GroupEpochStateMachine?> getActiveStateMachine(String groupId) async {
    final group = await _db.getGroup(groupId);
    if (group == null || !group.isReEpochPending || group.activeReEpochOperationId == null) {
      return null;
    }
    return _reconstructStateMachine(groupId, group.activeReEpochOperationId!);
  }

  @override
  Future<bool> canSendGroupMessages(String groupId, String peerId) async {
    final group = await _db.getGroup(groupId);
    if (group == null || group.isReEpochPending) return false;

    final member = await _db.getGroupMember(groupId, peerId);
    return member != null && member.status == GroupMemberStatus.active.name;
  }

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  Future<GroupEpochOperationEntry> _getOperationRecord(String operationId) async {
    final op = await (_db.select(_db.groupEpochOperationsTable)
          ..where((t) => t.operationId.equals(operationId)))
        .getSingleOrNull();

    if (op == null) {
      throw InvalidGroupEpochAckException('Operation "$operationId" not found in durable history.');
    }
    return op;
  }

  Future<GroupEpochStateMachine?> _reconstructStateMachine(
    String groupId,
    String operationId,
  ) async {
    final group = await _db.getGroup(groupId);
    if (group == null) return null;

    final op = await (_db.select(_db.groupEpochOperationsTable)
          ..where((t) => t.operationId.equals(operationId)))
        .getSingleOrNull();
    if (op == null) return null;

    final syncEntries = await (_db.select(_db.groupEpochSyncTable)
          ..where((t) => t.operationId.equals(operationId)))
        .get();

    final requiredMembers = syncEntries.map((e) => e.memberPeerId).toSet();
    final preparedMembers = syncEntries
        .where((e) => e.prepareStatus == 'acknowledged')
        .map((e) => e.memberPeerId)
        .toSet();
    final committedMembers = syncEntries
        .where((e) => e.commitStatus == 'acknowledged')
        .map((e) => e.memberPeerId)
        .toSet();
    final finalizedMembers = syncEntries
        .where((e) => e.finalizeStatus == 'acknowledged')
        .map((e) => e.memberPeerId)
        .toSet();

    final prepareAcks = <String, GroupEpochAckStatus>{
      for (final e in syncEntries)
        if (e.prepareStatus != 'pending')
          e.memberPeerId: GroupEpochAckStatus.fromString(e.prepareStatus),
    };
    final commitAcks = <String, GroupEpochAckStatus>{
      for (final e in syncEntries)
        if (e.commitStatus != 'pending')
          e.memberPeerId: GroupEpochAckStatus.fromString(e.commitStatus),
    };
    final finalizeAcks = <String, GroupEpochAckStatus>{
      for (final e in syncEntries)
        if (e.finalizeStatus != 'pending')
          e.memberPeerId: GroupEpochAckStatus.fromString(e.finalizeStatus),
    };

    final state = GroupEpochState(
      groupId: groupId,
      operationId: op.operationId,
      currentEpoch: group.epoch,
      previousEpoch: op.previousEpoch,
      targetEpoch: op.targetEpoch,
      operationSequenceNumber: op.operationSequenceNumber,
      adminPeerId: group.adminId,
      operationStatus: GroupEpochOperationStatus.fromString(op.operationStatus),
      isReEpochPending: group.isReEpochPending,
      requiredMemberPeerIds: requiredMembers,
      preparedMemberPeerIds: preparedMembers,
      committedMemberPeerIds: committedMembers,
      finalizedMemberPeerIds: finalizedMembers,
      prepareAcks: prepareAcks,
      commitAcks: commitAcks,
      finalizeAcks: finalizeAcks,
      updatedAt: op.updatedAt.toUtc(),
    );

    return GroupEpochStateMachine.fromSnapshot(state);
  }
}
