import 'package:meshlink/features/messages/data/models/group_epoch_packets.dart';
import 'package:meshlink/features/messages/domain/models/group_epoch_signed_history.dart';
import 'package:meshlink/features/messages/domain/services/group_epoch_state_machine.dart';

/// Base exception for runtime re-epoch coordination errors.
abstract class GroupEpochCoordinationException implements Exception {
  final String message;
  const GroupEpochCoordinationException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when cryptographic signature verification of an authoritative history record fails.
class GroupEpochSignatureException extends GroupEpochCoordinationException {
  const GroupEpochSignatureException(super.message);
}

/// Thrown when an offline-member reconciliation process fails closed.
class GroupEpochReconciliationException extends GroupEpochCoordinationException {
  const GroupEpochReconciliationException(super.message);
}

/// Domain service interface for runtime group re-epoch coordination and reconciliation.
///
/// Phase 9 Step 6.3.2: Re-Epoch Runtime Service and Durable Persistence Integration
///
/// Coordinates the administrative re-epoch protocol:
/// - Three-phase transitions: Prepare → Commit → Finalize.
/// - Administrator exclusion contract (admin directs; remote active members must ACK).
/// - Durable operation history and per-member sync persistence.
/// - In-flight operation supersession with strictly increasing sequence numbers.
/// - Authenticated Ed25519 authoritative operation history.
/// - Offline-member reconciliation via status probes and authenticated responses.
/// - Fail-closed messaging freeze while re-epoch is pending.
abstract class GroupEpochService {
  /// Initiates an administrative re-epoch operation for [groupId].
  ///
  /// Enforces:
  /// - Only the authenticated group administrator may initiate.
  /// - The administrator is local and is EXCLUDED from `requiredMemberPeerIds`.
  /// - Active remote group members are captured as the immutable snapshot.
  /// - Monotonic operation sequence number is incremented and enforced.
  /// - If an active operation exists, it is marked 'superseded' in durable history.
  /// - Group is marked pending and group messaging is blocked.
  /// - State machine and database transaction execute atomically.
  /// - Returns the created [GroupEpochPreparePacket] ready for broadcast.
  Future<GroupEpochPreparePacket> initiateReEpoch({
    required String groupId,
    required String requestingPeerId,
    String? operationId,
  });

  /// Processes an inbound Prepare ACK from a remote member.
  ///
  /// Validates [authenticatedSenderPeerId] matches [packet.memberPeerId].
  Future<GroupEpochState> processPrepareAck({
    required GroupEpochPrepareAckPacket packet,
    required String authenticatedSenderPeerId,
  });

  /// Commits the epoch advancement locally on the administrator node and generates Commit packets.
  ///
  /// Can only be called once all required remote members have acknowledged Prepare.
  Future<GroupEpochCommitPacket> commitReEpoch({
    required String groupId,
    required String requestingPeerId,
    required String operationId,
  });

  /// Processes an inbound Commit ACK from a remote member.
  ///
  /// Validates [authenticatedSenderPeerId] matches [packet.memberPeerId].
  Future<GroupEpochState> processCommitAck({
    required GroupEpochCommitAckPacket packet,
    required String authenticatedSenderPeerId,
  });

  /// Issues Finalize packets on the administrator node.
  ///
  /// Can only be called once all required remote members have acknowledged Commit.
  Future<GroupEpochFinalizePacket> finalizeReEpoch({
    required String groupId,
    required String requestingPeerId,
    required String operationId,
  });

  /// Processes an inbound Finalize ACK from a remote member.
  ///
  /// When all required members acknowledge, durably advances group epoch to targetEpoch
  /// and clears the pending/frozen flag.
  Future<GroupEpochState> processFinalizeAck({
    required GroupEpochFinalizeAckPacket packet,
    required String authenticatedSenderPeerId,
  });

  /// Handles an incoming [GroupEpochStatusProbePacket] and returns the authoritative status response.
  Future<GroupEpochStatusResponsePacket> handleStatusProbe({
    required GroupEpochStatusProbePacket probe,
    required String authenticatedSenderPeerId,
  });

  /// Reconciles local member state with an incoming authoritative status response and signed history.
  Future<void> handleStatusResponse({
    required GroupEpochStatusResponsePacket response,
    required GroupEpochSignedHistory signedHistory,
    required String authenticatedSenderPeerId,
  });

  /// Generates or retrieves the signed authoritative history record for the latest operation of [groupId].
  Future<GroupEpochSignedHistory> getAuthoritativeSignedHistory(String groupId);

  /// Reconstructs the active [GroupEpochStateMachine] from durable database state.
  ///
  /// Returns `null` if no re-epoch operation is currently active.
  Future<GroupEpochStateMachine?> getActiveStateMachine(String groupId);

  /// Checks whether group messaging is permitted (not frozen by an active re-epoch).
  Future<bool> canSendGroupMessages(String groupId, String peerId);
}

