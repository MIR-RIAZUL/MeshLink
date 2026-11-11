import 'dart:convert';

import 'package:meshlink/features/messages/data/models/group_epoch_packets.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';

/// Base exception for all re-epoch domain state machine errors.
abstract class GroupEpochException implements Exception {
  final String message;
  const GroupEpochException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when an unauthorized peer attempts an administrative re-epoch operation.
class GroupEpochAuthorizationException extends GroupEpochException {
  final String groupId;
  final String requestingPeerId;
  final String adminPeerId;

  const GroupEpochAuthorizationException({
    required this.groupId,
    required this.requestingPeerId,
    required this.adminPeerId,
    String? message,
  }) : super(
          message ??
              'Peer "$requestingPeerId" is not authorized to manage re-epoch operations on group "$groupId" (admin is "$adminPeerId").',
        );
}

/// Thrown when invalid parameters (e.g. malformed identifiers) are passed to the state machine.
class GroupEpochValidationException extends GroupEpochException {
  const GroupEpochValidationException(super.message);
}

/// Thrown when an illegal lifecycle transition is attempted (e.g. skipping phases, invalid epoch progression).
class InvalidGroupEpochTransitionException extends GroupEpochException {
  const InvalidGroupEpochTransitionException(super.message);
}

/// Thrown when an acknowledgement packet violates protocol constraints (e.g. unknown member, pending status, stale operation).
class InvalidGroupEpochAckException extends GroupEpochException {
  const InvalidGroupEpochAckException(super.message);
}

/// Thrown when a peer submits a conflicting duplicate acknowledgement.
class GroupEpochConflictException extends GroupEpochException {
  const GroupEpochConflictException(super.message);
}

/// Immutable state snapshot of a group's re-epoch lifecycle.
///
/// Phase 9 Step 6.3.1: Re-epoch Domain State Machine
///
/// Encapsulates:
/// - Group and administrative identity.
/// - Active operation identifier and progression numbers.
/// - Captured active-member snapshot for the operation.
/// - Per-stage acknowledgement status tracking.
/// - Freeze and messaging eligibility flags.
class GroupEpochState {
  GroupEpochState({
    required this.groupId,
    required this.operationId,
    required this.currentEpoch,
    required this.previousEpoch,
    required this.targetEpoch,
    required this.operationSequenceNumber,
    required this.adminPeerId,
    required this.operationStatus,
    required this.isReEpochPending,
    required Set<String> requiredMemberPeerIds,
    Set<String> preparedMemberPeerIds = const {},
    Set<String> committedMemberPeerIds = const {},
    Set<String> finalizedMemberPeerIds = const {},
    Map<String, GroupEpochAckStatus> prepareAcks = const {},
    Map<String, GroupEpochAckStatus> commitAcks = const {},
    Map<String, GroupEpochAckStatus> finalizeAcks = const {},
    this.failureReason,
    required this.updatedAt,
  })  : requiredMemberPeerIds = Set.unmodifiable(requiredMemberPeerIds),
        preparedMemberPeerIds = Set.unmodifiable(preparedMemberPeerIds),
        committedMemberPeerIds = Set.unmodifiable(committedMemberPeerIds),
        finalizedMemberPeerIds = Set.unmodifiable(finalizedMemberPeerIds),
        prepareAcks = Map.unmodifiable(prepareAcks),
        commitAcks = Map.unmodifiable(commitAcks),
        finalizeAcks = Map.unmodifiable(finalizeAcks) {
    Group.validateGroupId(groupId);
    Group.validatePeerId(adminPeerId, 'adminPeerId');
    if (operationId.isNotEmpty) {
      GroupEpochValidator.validateAndNormalizeOperationId(operationId);
    }
    if (currentEpoch < 1) {
      throw ArgumentError('currentEpoch must be >= 1 (got $currentEpoch).');
    }
    if (previousEpoch < 1) {
      throw ArgumentError('previousEpoch must be >= 1 (got $previousEpoch).');
    }
    if (targetEpoch < 1) {
      throw ArgumentError('targetEpoch must be >= 1 (got $targetEpoch).');
    }
    if (operationSequenceNumber < 0) {
      throw ArgumentError(
        'operationSequenceNumber must be >= 0 (got $operationSequenceNumber).',
      );
    }
    if (!updatedAt.isUtc) {
      throw ArgumentError('updatedAt must represent a valid UTC timestamp.');
    }
    for (final memberId in this.requiredMemberPeerIds) {
      Group.validatePeerId(memberId, 'requiredMemberPeerId');
    }
  }

  /// Factory creating an initial idle group epoch state (epoch 1, un-frozen).
  factory GroupEpochState.initial({
    required String groupId,
    required String adminPeerId,
    int epoch = 1,
    int lastSequenceNumber = 0,
    DateTime? timestamp,
  }) {
    Group.validateGroupId(groupId);
    Group.validatePeerId(adminPeerId, 'adminPeerId');
    if (epoch < 1) {
      throw ArgumentError('epoch must be >= 1 (got $epoch).');
    }
    if (lastSequenceNumber < 0) {
      throw ArgumentError(
        'lastSequenceNumber must be >= 0 (got $lastSequenceNumber).',
      );
    }
    final nowUtc = (timestamp ?? DateTime.now().toUtc());
    if (!nowUtc.isUtc) {
      throw ArgumentError('timestamp must represent a valid UTC timestamp.');
    }

    return GroupEpochState(
      groupId: groupId,
      operationId: '',
      currentEpoch: epoch,
      previousEpoch: epoch,
      targetEpoch: epoch,
      operationSequenceNumber: lastSequenceNumber,
      adminPeerId: adminPeerId,
      operationStatus: GroupEpochOperationStatus.finalized,
      isReEpochPending: false,
      requiredMemberPeerIds: const {},
      preparedMemberPeerIds: const {},
      committedMemberPeerIds: const {},
      finalizedMemberPeerIds: const {},
      prepareAcks: const {},
      commitAcks: const {},
      finalizeAcks: const {},
      failureReason: null,
      updatedAt: nowUtc,
    );
  }

  /// Target group identifier.
  final String groupId;

  /// Active 32-hex operation identifier, or empty string if idle.
  final String operationId;

  /// Current authoritative group epoch.
  final int currentEpoch;

  /// Epoch prior to the active re-epoch operation.
  final int previousEpoch;

  /// Target epoch advancement for the active re-epoch operation.
  final int targetEpoch;

  /// Monotonically increasing operation sequence number.
  final int operationSequenceNumber;

  /// Peer identifier of group administrator.
  final String adminPeerId;

  /// Lifecycle status of the re-epoch operation.
  final GroupEpochOperationStatus operationStatus;

  /// True if a re-epoch operation is active and messaging is frozen.
  final bool isReEpochPending;

  /// Immutable snapshot of required active-member peer IDs captured at operation initiation.
  final Set<String> requiredMemberPeerIds;

  /// Immutable set of member peer IDs that have successfully prepared.
  final Set<String> preparedMemberPeerIds;

  /// Immutable set of member peer IDs that have successfully committed.
  final Set<String> committedMemberPeerIds;

  /// Immutable set of member peer IDs that have successfully finalized.
  final Set<String> finalizedMemberPeerIds;

  /// Detailed per-member acknowledgement status map for Prepare stage.
  final Map<String, GroupEpochAckStatus> prepareAcks;

  /// Detailed per-member acknowledgement status map for Commit stage.
  final Map<String, GroupEpochAckStatus> commitAcks;

  /// Detailed per-member acknowledgement status map for Finalize stage.
  final Map<String, GroupEpochAckStatus> finalizeAcks;

  /// Optional message describing the failure or rejection reason.
  final String? failureReason;

  /// UTC timestamp of last state transition.
  final DateTime updatedAt;

  /// Checks whether group messaging is permitted.
  ///
  /// Group messaging is strictly blocked whenever [isReEpochPending] is true.
  bool canSendGroupMessages(String peerId) {
    if (isReEpochPending) return false;
    return true;
  }

  /// Creates a copy of this state with specified fields replaced.
  GroupEpochState copyWith({
    String? groupId,
    String? operationId,
    int? currentEpoch,
    int? previousEpoch,
    int? targetEpoch,
    int? operationSequenceNumber,
    String? adminPeerId,
    GroupEpochOperationStatus? operationStatus,
    bool? isReEpochPending,
    Set<String>? requiredMemberPeerIds,
    Set<String>? preparedMemberPeerIds,
    Set<String>? committedMemberPeerIds,
    Set<String>? finalizedMemberPeerIds,
    Map<String, GroupEpochAckStatus>? prepareAcks,
    Map<String, GroupEpochAckStatus>? commitAcks,
    Map<String, GroupEpochAckStatus>? finalizeAcks,
    String? failureReason,
    DateTime? updatedAt,
  }) {
    return GroupEpochState(
      groupId: groupId ?? this.groupId,
      operationId: operationId ?? this.operationId,
      currentEpoch: currentEpoch ?? this.currentEpoch,
      previousEpoch: previousEpoch ?? this.previousEpoch,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      operationSequenceNumber:
          operationSequenceNumber ?? this.operationSequenceNumber,
      adminPeerId: adminPeerId ?? this.adminPeerId,
      operationStatus: operationStatus ?? this.operationStatus,
      isReEpochPending: isReEpochPending ?? this.isReEpochPending,
      requiredMemberPeerIds:
          requiredMemberPeerIds ?? this.requiredMemberPeerIds,
      preparedMemberPeerIds:
          preparedMemberPeerIds ?? this.preparedMemberPeerIds,
      committedMemberPeerIds:
          committedMemberPeerIds ?? this.committedMemberPeerIds,
      finalizedMemberPeerIds:
          finalizedMemberPeerIds ?? this.finalizedMemberPeerIds,
      prepareAcks: prepareAcks ?? this.prepareAcks,
      commitAcks: commitAcks ?? this.commitAcks,
      finalizeAcks: finalizeAcks ?? this.finalizeAcks,
      failureReason: failureReason ?? this.failureReason,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes the state snapshot to a Map.
  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'operationId': operationId,
        'currentEpoch': currentEpoch,
        'previousEpoch': previousEpoch,
        'targetEpoch': targetEpoch,
        'operationSequenceNumber': operationSequenceNumber,
        'adminPeerId': adminPeerId,
        'operationStatus': operationStatus.toJson(),
        'isReEpochPending': isReEpochPending,
        'requiredMemberPeerIds': requiredMemberPeerIds.toList()..sort(),
        'preparedMemberPeerIds': preparedMemberPeerIds.toList()..sort(),
        'committedMemberPeerIds': committedMemberPeerIds.toList()..sort(),
        'finalizedMemberPeerIds': finalizedMemberPeerIds.toList()..sort(),
        'prepareAcks': prepareAcks.map((k, v) => MapEntry(k, v.toJson())),
        'commitAcks': commitAcks.map((k, v) => MapEntry(k, v.toJson())),
        'finalizeAcks': finalizeAcks.map((k, v) => MapEntry(k, v.toJson())),
        'failureReason': failureReason,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Serializes the state snapshot to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Restores a state snapshot strictly from a Map.
  factory GroupEpochState.fromMap(Map<String, dynamic> map) {
    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId".');
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId".');
    }

    final rawCurrentEpoch = map['currentEpoch'];
    if (rawCurrentEpoch is! int) {
      throw const FormatException('Missing or invalid type for "currentEpoch".');
    }

    final rawPreviousEpoch = map['previousEpoch'];
    if (rawPreviousEpoch is! int) {
      throw const FormatException('Missing or invalid type for "previousEpoch".');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch".');
    }

    final rawSequenceNumber = map['operationSequenceNumber'];
    if (rawSequenceNumber is! int) {
      throw const FormatException(
          'Missing or invalid type for "operationSequenceNumber".');
    }

    final rawAdminPeerId = map['adminPeerId'];
    if (rawAdminPeerId is! String) {
      throw const FormatException('Missing or invalid type for "adminPeerId".');
    }

    final rawOperationStatus = map['operationStatus'];
    if (rawOperationStatus is! String) {
      throw const FormatException('Missing or invalid type for "operationStatus".');
    }

    final rawIsPending = map['isReEpochPending'];
    if (rawIsPending is! bool) {
      throw const FormatException('Missing or invalid type for "isReEpochPending".');
    }

    final rawRequiredMembers = map['requiredMemberPeerIds'];
    if (rawRequiredMembers is! List) {
      throw const FormatException(
          'Missing or invalid type for "requiredMemberPeerIds".');
    }

    final rawPreparedMembers = map['preparedMemberPeerIds'] ?? <dynamic>[];
    if (rawPreparedMembers is! List) {
      throw const FormatException(
          'Missing or invalid type for "preparedMemberPeerIds".');
    }

    final rawCommittedMembers = map['committedMemberPeerIds'] ?? <dynamic>[];
    if (rawCommittedMembers is! List) {
      throw const FormatException(
          'Missing or invalid type for "committedMemberPeerIds".');
    }

    final rawFinalizedMembers = map['finalizedMemberPeerIds'] ?? <dynamic>[];
    if (rawFinalizedMembers is! List) {
      throw const FormatException(
          'Missing or invalid type for "finalizedMemberPeerIds".');
    }

    Map<String, GroupEpochAckStatus> parseAckMap(
        dynamic rawMap, String mapName) {
      if (rawMap == null) return {};
      if (rawMap is! Map) {
        throw FormatException('Missing or invalid type for "$mapName".');
      }
      final result = <String, GroupEpochAckStatus>{};
      for (final entry in rawMap.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw FormatException(
              'Invalid entry in "$mapName": key and value must be Strings.');
        }
        result[entry.key as String] =
            GroupEpochAckStatus.fromString(entry.value as String);
      }
      return result;
    }

    final rawPrepareAcks = parseAckMap(map['prepareAcks'], 'prepareAcks');
    final rawCommitAcks = parseAckMap(map['commitAcks'], 'commitAcks');
    final rawFinalizeAcks = parseAckMap(map['finalizeAcks'], 'finalizeAcks');

    final rawFailureReason = map['failureReason'];
    if (rawFailureReason != null && rawFailureReason is! String) {
      throw const FormatException('Invalid type for "failureReason".');
    }

    final rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is! String) {
      throw const FormatException('Missing or invalid type for "updatedAt".');
    }
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    if (parsedUpdatedAt == null || !parsedUpdatedAt.isUtc) {
      throw const FormatException('Invalid or non-UTC "updatedAt" timestamp.');
    }

    return GroupEpochState(
      groupId: rawGroupId,
      operationId: rawOperationId,
      currentEpoch: rawCurrentEpoch,
      previousEpoch: rawPreviousEpoch,
      targetEpoch: rawTargetEpoch,
      operationSequenceNumber: rawSequenceNumber,
      adminPeerId: rawAdminPeerId,
      operationStatus:
          GroupEpochOperationStatus.fromString(rawOperationStatus),
      isReEpochPending: rawIsPending,
      requiredMemberPeerIds: rawRequiredMembers.cast<String>().toSet(),
      preparedMemberPeerIds: rawPreparedMembers.cast<String>().toSet(),
      committedMemberPeerIds: rawCommittedMembers.cast<String>().toSet(),
      finalizedMemberPeerIds: rawFinalizedMembers.cast<String>().toSet(),
      prepareAcks: rawPrepareAcks,
      commitAcks: rawCommitAcks,
      finalizeAcks: rawFinalizeAcks,
      failureReason: rawFailureReason as String?,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Restores a state snapshot from a JSON string.
  factory GroupEpochState.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'Invalid JSON payload for GroupEpochState: expected Map.');
    }
    return GroupEpochState.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochState &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          operationId == other.operationId &&
          currentEpoch == other.currentEpoch &&
          previousEpoch == other.previousEpoch &&
          targetEpoch == other.targetEpoch &&
          operationSequenceNumber == other.operationSequenceNumber &&
          adminPeerId == other.adminPeerId &&
          operationStatus == other.operationStatus &&
          isReEpochPending == other.isReEpochPending &&
          _setEquals(requiredMemberPeerIds, other.requiredMemberPeerIds) &&
          _setEquals(preparedMemberPeerIds, other.preparedMemberPeerIds) &&
          _setEquals(committedMemberPeerIds, other.committedMemberPeerIds) &&
          _setEquals(finalizedMemberPeerIds, other.finalizedMemberPeerIds) &&
          _mapEquals(prepareAcks, other.prepareAcks) &&
          _mapEquals(commitAcks, other.commitAcks) &&
          _mapEquals(finalizeAcks, other.finalizeAcks) &&
          failureReason == other.failureReason &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        groupId,
        operationId,
        currentEpoch,
        previousEpoch,
        targetEpoch,
        operationSequenceNumber,
        adminPeerId,
        operationStatus,
        isReEpochPending,
        Object.hashAll(requiredMemberPeerIds),
        Object.hashAll(preparedMemberPeerIds),
        Object.hashAll(committedMemberPeerIds),
        Object.hashAll(finalizedMemberPeerIds),
        failureReason,
        updatedAt,
      );

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

/// Pure domain transition engine for MeshLink group re-epoching.
///
/// Phase 9 Step 6.3.1: Re-epoch Domain State Machine
///
/// Orchestrates the three-phase administrative re-epoch protocol:
/// 1. Prepare: Admin initiates, members acknowledge prepare.
/// 2. Commit: Admin commits, members acknowledge commit.
/// 3. Finalize: Admin finalizes, members acknowledge finalize, unfreezing messaging.
class GroupEpochStateMachine {
  GroupEpochStateMachine({
    required GroupEpochState initialState,
  }) : _state = initialState;

  /// Factory creating a state machine initialized to a clean idle state.
  factory GroupEpochStateMachine.initial({
    required String groupId,
    required String adminPeerId,
    int epoch = 1,
    int lastSequenceNumber = 0,
    DateTime? timestamp,
  }) {
    return GroupEpochStateMachine(
      initialState: GroupEpochState.initial(
        groupId: groupId,
        adminPeerId: adminPeerId,
        epoch: epoch,
        lastSequenceNumber: lastSequenceNumber,
        timestamp: timestamp,
      ),
    );
  }

  /// Restores a state machine from a serialized snapshot.
  factory GroupEpochStateMachine.fromSnapshot(GroupEpochState snapshot) {
    return GroupEpochStateMachine(initialState: snapshot);
  }

  GroupEpochState _state;

  /// Current immutable state of the state machine.
  GroupEpochState get state => _state;

  /// True if group messaging is permitted in the current state.
  bool canSendGroupMessages(String peerId) => _state.canSendGroupMessages(peerId);

  // ===========================================================================
  // 1. Initial / Idle → Preparing (Initiation)
  // ===========================================================================

  /// Initiates an administrative re-epoch operation.
  ///
  /// Enforces:
  /// - Only the authenticated group admin may initiate.
  /// - Valid 32-hex [operationId].
  /// - [previousEpoch] must equal [GroupEpochState.currentEpoch].
  /// - [targetEpoch] must equal `previousEpoch + 1`.
  /// - [sequenceNumber] must be strictly greater than [GroupEpochState.operationSequenceNumber].
  /// - Captures immutable snapshot of [requiredMemberPeerIds].
  /// - Freezes group messaging ([GroupEpochState.isReEpochPending] = true).
  GroupEpochState initiatePrepare({
    required String requestingPeerId,
    required String operationId,
    required int previousEpoch,
    required int targetEpoch,
    required int sequenceNumber,
    required Set<String> requiredMemberPeerIds,
    DateTime? timestamp,
  }) {
    final nowUtc = (timestamp ?? DateTime.now().toUtc());
    if (!nowUtc.isUtc) {
      throw ArgumentError('timestamp must represent a valid UTC timestamp.');
    }

    // 1. Authorization check: Admin only
    if (requestingPeerId != _state.adminPeerId) {
      throw GroupEpochAuthorizationException(
        groupId: _state.groupId,
        requestingPeerId: requestingPeerId,
        adminPeerId: _state.adminPeerId,
      );
    }

    // 2. Validate operation ID
    final normalizedOpId =
        GroupEpochValidator.validateAndNormalizeOperationId(operationId);

    // If an operation is currently active, ensure we are strictly superseding it with a higher sequence
    if (_state.isReEpochPending) {
      if (sequenceNumber <= _state.operationSequenceNumber) {
        throw InvalidGroupEpochTransitionException(
          'Cannot supersede active operation "${_state.operationId}": '
          'sequenceNumber ($sequenceNumber) must be strictly greater than active sequence (${_state.operationSequenceNumber}).',
        );
      }
      if (normalizedOpId == _state.operationId) {
        throw InvalidGroupEpochTransitionException(
          'Operation ID "$normalizedOpId" is already active.',
        );
      }
    } else {
      if (sequenceNumber <= _state.operationSequenceNumber) {
        throw InvalidGroupEpochTransitionException(
          'sequenceNumber ($sequenceNumber) must be strictly greater than last sequence (${_state.operationSequenceNumber}).',
        );
      }
    }

    // 3. Previous epoch must equal current group epoch
    if (previousEpoch != _state.currentEpoch) {
      throw InvalidGroupEpochTransitionException(
        'previousEpoch ($previousEpoch) must equal current group epoch (${_state.currentEpoch}).',
      );
    }

    // 4. Target epoch must equal previousEpoch + 1
    if (targetEpoch != previousEpoch + 1) {
      throw InvalidGroupEpochTransitionException(
        'targetEpoch ($targetEpoch) must equal previousEpoch + 1 (${previousEpoch + 1}).',
      );
    }

    // 5. Sequence number validation
    GroupEpochValidator.validateSequenceNumber(
      sequenceNumber,
      'sequenceNumber',
    );

    // 6. Capture and validate required active-member snapshot defensively
    final snapshot = <String>{};
    for (final memberId in requiredMemberPeerIds) {
      Group.validatePeerId(memberId, 'memberPeerId');
      snapshot.add(memberId);
    }

    _state = _state.copyWith(
      operationId: normalizedOpId,
      previousEpoch: previousEpoch,
      targetEpoch: targetEpoch,
      operationSequenceNumber: sequenceNumber,
      operationStatus: GroupEpochOperationStatus.preparing,
      isReEpochPending: true,
      requiredMemberPeerIds: Set.unmodifiable(snapshot),
      preparedMemberPeerIds: const {},
      committedMemberPeerIds: const {},
      finalizedMemberPeerIds: const {},
      prepareAcks: const {},
      commitAcks: const {},
      finalizeAcks: const {},
      failureReason: null,
      updatedAt: nowUtc,
    );

    return _state;
  }

  // ===========================================================================
  // 2. Prepare Acknowledgement Handling & Preparing → Committing
  // ===========================================================================

  /// Processes an inbound [GroupEpochPrepareAckPacket].
  GroupEpochState processPrepareAck(GroupEpochPrepareAckPacket packet) {
    return applyPrepareAck(
      operationId: packet.operationId,
      groupId: packet.groupId,
      memberPeerId: packet.memberPeerId,
      targetEpoch: packet.targetEpoch,
      status: packet.status,
      timestamp: packet.timestamp,
    );
  }

  /// Applies a Prepare acknowledgement directly with field-level parameters.
  GroupEpochState applyPrepareAck({
    required String operationId,
    required String groupId,
    required String memberPeerId,
    required int targetEpoch,
    required GroupEpochAckStatus status,
    DateTime? timestamp,
  }) {
    final nowUtc = (timestamp ?? DateTime.now().toUtc());

    _validateAckCommon(
      expectedPhase: GroupEpochOperationStatus.preparing,
      operationId: operationId,
      groupId: groupId,
      memberPeerId: memberPeerId,
      targetEpoch: targetEpoch,
      status: status,
    );

    // Check duplicate or conflicting ACK
    if (_state.prepareAcks.containsKey(memberPeerId)) {
      final existingStatus = _state.prepareAcks[memberPeerId]!;
      if (existingStatus == status) {
        // Idempotent duplicate: return current state unchanged
        return _state;
      }
      throw GroupEpochConflictException(
        'Conflicting duplicate Prepare ACK from "$memberPeerId": '
        'existing $existingStatus vs incoming $status.',
      );
    }

    final newPrepareAcks =
        Map<String, GroupEpochAckStatus>.from(_state.prepareAcks)
          ..[memberPeerId] = status;

    if (status == GroupEpochAckStatus.failed) {
      _state = _state.copyWith(
        prepareAcks: newPrepareAcks,
        failureReason: 'Prepare failed for member: $memberPeerId',
        updatedAt: nowUtc,
      );
      return _state;
    }

    // status == acknowledged
    final newPrepared = Set<String>.from(_state.preparedMemberPeerIds)
      ..add(memberPeerId);

    final allPrepared =
        newPrepared.containsAll(_state.requiredMemberPeerIds);

    _state = _state.copyWith(
      prepareAcks: newPrepareAcks,
      preparedMemberPeerIds: newPrepared,
      operationStatus: allPrepared
          ? GroupEpochOperationStatus.committing
          : GroupEpochOperationStatus.preparing,
      updatedAt: nowUtc,
    );

    return _state;
  }

  // ===========================================================================
  // 3. Commit Acknowledgement Handling & Committing → Finalizing
  // ===========================================================================

  /// Processes an inbound [GroupEpochCommitAckPacket].
  GroupEpochState processCommitAck(GroupEpochCommitAckPacket packet) {
    return applyCommitAck(
      operationId: packet.operationId,
      groupId: packet.groupId,
      memberPeerId: packet.memberPeerId,
      targetEpoch: packet.targetEpoch,
      status: packet.status,
      timestamp: packet.timestamp,
    );
  }

  /// Applies a Commit acknowledgement directly with field-level parameters.
  GroupEpochState applyCommitAck({
    required String operationId,
    required String groupId,
    required String memberPeerId,
    required int targetEpoch,
    required GroupEpochAckStatus status,
    DateTime? timestamp,
  }) {
    final nowUtc = (timestamp ?? DateTime.now().toUtc());

    _validateAckCommon(
      expectedPhase: GroupEpochOperationStatus.committing,
      operationId: operationId,
      groupId: groupId,
      memberPeerId: memberPeerId,
      targetEpoch: targetEpoch,
      status: status,
    );

    // Check duplicate or conflicting ACK
    if (_state.commitAcks.containsKey(memberPeerId)) {
      final existingStatus = _state.commitAcks[memberPeerId]!;
      if (existingStatus == status) {
        return _state;
      }
      throw GroupEpochConflictException(
        'Conflicting duplicate Commit ACK from "$memberPeerId": '
        'existing $existingStatus vs incoming $status.',
      );
    }

    final newCommitAcks =
        Map<String, GroupEpochAckStatus>.from(_state.commitAcks)
          ..[memberPeerId] = status;

    if (status == GroupEpochAckStatus.failed) {
      _state = _state.copyWith(
        commitAcks: newCommitAcks,
        failureReason: 'Commit failed for member: $memberPeerId',
        updatedAt: nowUtc,
      );
      return _state;
    }

    // status == acknowledged
    final newCommitted = Set<String>.from(_state.committedMemberPeerIds)
      ..add(memberPeerId);

    final allCommitted =
        newCommitted.containsAll(_state.requiredMemberPeerIds);

    _state = _state.copyWith(
      commitAcks: newCommitAcks,
      committedMemberPeerIds: newCommitted,
      operationStatus: allCommitted
          ? GroupEpochOperationStatus.finalizing
          : GroupEpochOperationStatus.committing,
      updatedAt: nowUtc,
    );

    return _state;
  }

  // ===========================================================================
  // 4. Finalize Acknowledgement Handling & Finalizing → Finalized
  // ===========================================================================

  /// Processes an inbound [GroupEpochFinalizeAckPacket].
  GroupEpochState processFinalizeAck(GroupEpochFinalizeAckPacket packet) {
    return applyFinalizeAck(
      operationId: packet.operationId,
      groupId: packet.groupId,
      memberPeerId: packet.memberPeerId,
      targetEpoch: packet.targetEpoch,
      status: packet.status,
      timestamp: packet.timestamp,
    );
  }

  /// Applies a Finalize acknowledgement directly with field-level parameters.
  GroupEpochState applyFinalizeAck({
    required String operationId,
    required String groupId,
    required String memberPeerId,
    required int targetEpoch,
    required GroupEpochAckStatus status,
    DateTime? timestamp,
  }) {
    final nowUtc = (timestamp ?? DateTime.now().toUtc());

    _validateAckCommon(
      expectedPhase: GroupEpochOperationStatus.finalizing,
      operationId: operationId,
      groupId: groupId,
      memberPeerId: memberPeerId,
      targetEpoch: targetEpoch,
      status: status,
    );

    // Check duplicate or conflicting ACK
    if (_state.finalizeAcks.containsKey(memberPeerId)) {
      final existingStatus = _state.finalizeAcks[memberPeerId]!;
      if (existingStatus == status) {
        return _state;
      }
      throw GroupEpochConflictException(
        'Conflicting duplicate Finalize ACK from "$memberPeerId": '
        'existing $existingStatus vs incoming $status.',
      );
    }

    final newFinalizeAcks =
        Map<String, GroupEpochAckStatus>.from(_state.finalizeAcks)
          ..[memberPeerId] = status;

    if (status == GroupEpochAckStatus.failed) {
      _state = _state.copyWith(
        finalizeAcks: newFinalizeAcks,
        failureReason: 'Finalize failed for member: $memberPeerId',
        updatedAt: nowUtc,
      );
      return _state;
    }

    // status == acknowledged
    final newFinalized = Set<String>.from(_state.finalizedMemberPeerIds)
      ..add(memberPeerId);

    final allFinalized =
        newFinalized.containsAll(_state.requiredMemberPeerIds);

    if (allFinalized) {
      // Finalization complete: update epoch to targetEpoch and unfreeze messaging!
      _state = _state.copyWith(
        finalizeAcks: newFinalizeAcks,
        finalizedMemberPeerIds: newFinalized,
        operationStatus: GroupEpochOperationStatus.finalized,
        currentEpoch: _state.targetEpoch,
        isReEpochPending: false,
        failureReason: null,
        updatedAt: nowUtc,
      );
    } else {
      _state = _state.copyWith(
        finalizeAcks: newFinalizeAcks,
        finalizedMemberPeerIds: newFinalized,
        operationStatus: GroupEpochOperationStatus.finalizing,
        updatedAt: nowUtc,
      );
    }

    return _state;
  }

  // ===========================================================================
  // 5. Explicit Phase Progression (e.g. for empty/solo groups)
  // ===========================================================================

  /// Advances the state from [GroupEpochOperationStatus.preparing] to [GroupEpochOperationStatus.committing].
  ///
  /// Requires that all required members have acknowledged Prepare.
  GroupEpochState advanceToCommitting([DateTime? timestamp]) {
    if (_state.operationStatus != GroupEpochOperationStatus.preparing) {
      if (_state.operationStatus == GroupEpochOperationStatus.committing) {
        return _state;
      }
      throw InvalidGroupEpochTransitionException(
        'Cannot advance to committing: operation is in ${_state.operationStatus} status (expected preparing).',
      );
    }
    if (!_state.preparedMemberPeerIds.containsAll(_state.requiredMemberPeerIds)) {
      throw InvalidGroupEpochTransitionException(
        'Cannot advance to committing: not all required members have acknowledged Prepare.',
      );
    }
    _state = _state.copyWith(
      operationStatus: GroupEpochOperationStatus.committing,
      updatedAt: (timestamp ?? DateTime.now().toUtc()),
    );
    return _state;
  }

  /// Advances the state from [GroupEpochOperationStatus.committing] to [GroupEpochOperationStatus.finalizing].
  ///
  /// Requires that all required members have acknowledged Commit.
  GroupEpochState advanceToFinalizing([DateTime? timestamp]) {
    if (_state.operationStatus != GroupEpochOperationStatus.committing) {
      if (_state.operationStatus == GroupEpochOperationStatus.finalizing) {
        return _state;
      }
      throw InvalidGroupEpochTransitionException(
        'Cannot advance to finalizing: operation is in ${_state.operationStatus} status (expected committing).',
      );
    }
    if (!_state.committedMemberPeerIds.containsAll(_state.requiredMemberPeerIds)) {
      throw InvalidGroupEpochTransitionException(
        'Cannot advance to finalizing: not all required members have acknowledged Commit.',
      );
    }
    _state = _state.copyWith(
      operationStatus: GroupEpochOperationStatus.finalizing,
      updatedAt: (timestamp ?? DateTime.now().toUtc()),
    );
    return _state;
  }

  /// Advances the state from [GroupEpochOperationStatus.finalizing] to [GroupEpochOperationStatus.finalized].
  ///
  /// Updates group epoch to targetEpoch and clears the pending/frozen state.
  GroupEpochState advanceToFinalized([DateTime? timestamp]) {
    if (_state.operationStatus != GroupEpochOperationStatus.finalizing) {
      if (_state.operationStatus == GroupEpochOperationStatus.finalized) {
        return _state;
      }
      throw InvalidGroupEpochTransitionException(
        'Cannot advance to finalized: operation is in ${_state.operationStatus} status (expected finalizing).',
      );
    }
    if (!_state.finalizedMemberPeerIds.containsAll(_state.requiredMemberPeerIds)) {
      throw InvalidGroupEpochTransitionException(
        'Cannot advance to finalized: not all required members have acknowledged Finalize.',
      );
    }
    _state = _state.copyWith(
      operationStatus: GroupEpochOperationStatus.finalized,
      currentEpoch: _state.targetEpoch,
      isReEpochPending: false,
      failureReason: null,
      updatedAt: (timestamp ?? DateTime.now().toUtc()),
    );
    return _state;
  }

  // ===========================================================================
  // Private Helper Validations
  // ===========================================================================

  void _validateAckCommon({
    required GroupEpochOperationStatus expectedPhase,
    required String operationId,
    required String groupId,
    required String memberPeerId,
    required int targetEpoch,
    required GroupEpochAckStatus status,
  }) {
    // 1. Reject if already finalized
    if (_state.operationStatus == GroupEpochOperationStatus.finalized) {
      throw InvalidGroupEpochTransitionException(
        'Cannot process acknowledgement: operation "${_state.operationId}" is already finalized.',
      );
    }

    // 2. Reject if skipping phases or called in wrong phase
    if (_state.operationStatus != expectedPhase) {
      if (expectedPhase == GroupEpochOperationStatus.committing &&
          _state.operationStatus == GroupEpochOperationStatus.preparing) {
        throw InvalidGroupEpochTransitionException(
          'Commit cannot be skipped: operation is still in preparing status.',
        );
      }
      if (expectedPhase == GroupEpochOperationStatus.finalizing &&
          (_state.operationStatus == GroupEpochOperationStatus.preparing ||
              _state.operationStatus == GroupEpochOperationStatus.committing)) {
        throw InvalidGroupEpochTransitionException(
          'Finalize cannot be skipped: operation is in ${_state.operationStatus} status.',
        );
      }
      throw InvalidGroupEpochTransitionException(
        'Cannot process acknowledgement for $expectedPhase: '
        'operation is currently in ${_state.operationStatus} status.',
      );
    }

    // 3. Stale / Mismatched operation ID
    final normalizedOpId =
        GroupEpochValidator.validateAndNormalizeOperationId(operationId);
    if (normalizedOpId != _state.operationId) {
      throw InvalidGroupEpochAckException(
        'Stale or mismatched operationId: expected "${_state.operationId}", got "$normalizedOpId".',
      );
    }

    // 4. Mismatched group ID
    if (groupId != _state.groupId) {
      throw InvalidGroupEpochAckException(
        'Mismatched groupId: expected "${_state.groupId}", got "$groupId".',
      );
    }

    // 5. Mismatched target epoch
    if (targetEpoch != _state.targetEpoch) {
      throw InvalidGroupEpochAckException(
        'Mismatched targetEpoch: expected ${_state.targetEpoch}, got $targetEpoch.',
      );
    }

    // 6. Sender membership: must be in required active-member snapshot
    if (!_state.requiredMemberPeerIds.contains(memberPeerId)) {
      throw InvalidGroupEpochAckException(
        'Peer "$memberPeerId" is not in the required member snapshot for this operation.',
      );
    }

    // 7. Reject pending status on the wire
    if (status == GroupEpochAckStatus.pending) {
      throw const InvalidGroupEpochAckException(
        'Wire acknowledgement cannot have pending status.',
      );
    }
  }
}
