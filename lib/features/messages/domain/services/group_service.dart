import 'package:meshlink/features/messages/domain/models/group.dart';

/// Base exception for group service business-rule failures.
abstract class GroupServiceException implements Exception {
  final String message;
  const GroupServiceException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when an operation is attempted by a peer who is not authorized (e.g. not the admin).
class GroupAuthorizationException extends GroupServiceException {
  final String groupId;
  final String requestingPeerId;
  const GroupAuthorizationException(
    this.groupId,
    this.requestingPeerId, [
    String? message,
  ]) : super(
          message ??
              'Peer "$requestingPeerId" is not authorized to perform admin operations on group "$groupId".',
        );
}

/// Thrown when an invitation cannot be created because the target peer already has an active or pending membership.
class InvitationAlreadyExistsException extends GroupServiceException {
  final String groupId;
  final String peerId;
  const InvitationAlreadyExistsException(
    this.groupId,
    this.peerId, [
    String? message,
  ]) : super(
          message ??
              'An active membership or pending invitation already exists for peer "$peerId" in group "$groupId".',
        );
}

/// Thrown when an acceptance or rejection is attempted for a peer who has no pending invitation.
class NoPendingInvitationException extends GroupServiceException {
  final String groupId;
  final String peerId;
  const NoPendingInvitationException(
    this.groupId,
    this.peerId, [
    String? message,
  ]) : super(
          message ??
              'No pending invitation found for peer "$peerId" in group "$groupId".',
        );
}

/// Thrown when an operation requires an active member but the member is pending or removed.
class MemberNotActiveException extends GroupServiceException {
  final String groupId;
  final String peerId;
  const MemberNotActiveException(
    this.groupId,
    this.peerId, [
    String? message,
  ]) : super(
          message ??
              'Peer "$peerId" is not an active member of group "$groupId".',
        );
}

/// Thrown when an operation is attempted on a member who has already been removed.
class MemberAlreadyRemovedException extends GroupServiceException {
  final String groupId;
  final String peerId;
  const MemberAlreadyRemovedException(
    this.groupId,
    this.peerId, [
    String? message,
  ]) : super(
          message ??
              'Member "$peerId" is already removed from group "$groupId".',
        );
}

/// Thrown when an admin attempts to remove themselves through ordinary member-removal operations.
class AdminSelfRemovalProhibitedException extends GroupServiceException {
  final String groupId;
  final String adminId;
  const AdminSelfRemovalProhibitedException(
    this.groupId,
    this.adminId, [
    String? message,
  ]) : super(
          message ??
              'Group admin "$adminId" cannot remove themselves from group "$groupId". Ownership transfer is required.',
        );
}

/// Thrown when group state is invalid for the requested operation.
class InvalidGroupStateException extends GroupServiceException {
  const InvalidGroupStateException(super.message);
}

/// Domain service interface coordinating group lifecycle operations and business rules.
///
/// Pure domain abstraction decoupled from Drift and SQLite.
abstract class GroupService {
  /// Creates a new group and atomically registers the creator as its initial active admin.
  ///
  /// Enforces:
  /// - Group name validation (trimmed, 1-64 characters).
  /// - Creator peer ID validation.
  /// - Format verification of [groupId] (or generation if null).
  /// - Initial group epoch = 1.
  /// - Creator becomes active admin member.
  Future<Group> createGroup({
    required String name,
    required String creatorId,
    String? groupId,
    DateTime? createdAt,
  });

  /// Retrieves a group by ID, or returns `null` if not found.
  Future<Group?> getGroup(String groupId);

  /// Retrieves all groups, ordered by creation time descending.
  Future<List<Group>> getAllGroups();

  /// Retrieves all currently active members of a group.
  Future<List<GroupMember>> getActiveMembers(String groupId);

  /// Retrieves all pending invitations for a group.
  Future<List<GroupMember>> getPendingInvitations(String groupId);

  /// Retrieves all removed members of a group.
  Future<List<GroupMember>> getRemovedMembers(String groupId);

  /// Retrieves a specific member of a group, or returns `null` if not found.
  Future<GroupMember?> getMember(String groupId, String peerId);

  /// Checks whether [peerId] is an active member of [groupId].
  ///
  /// Returns `false` for pending, removed, or nonexistent peers.
  Future<bool> isActiveMember(String groupId, String peerId);

  /// Checks whether [peerId] is the current admin of [groupId].
  Future<bool> isGroupAdmin(String groupId, String peerId);

  /// Checks whether [peerId] is permitted to send group messages (must be active member).
  Future<bool> canSendGroupMessages(String groupId, String peerId);

  /// Creates a pending invitation for [targetPeerId].
  ///
  /// Enforces:
  /// - Group exists.
  /// - [requestingPeerId] is the current admin.
  /// - [targetPeerId] is valid and not already an active/pending member.
  /// - Group has available capacity (out of 8).
  ///
  /// Returns the created or re-invited [GroupMember] in [GroupMemberStatus.pendingInvite] status.
  Future<GroupMember> invitePeer({
    required String groupId,
    required String requestingPeerId,
    required String targetPeerId,
    DateTime? timestamp,
  });

  /// Accepts a pending invitation for [peerId].
  ///
  /// Enforces:
  /// - Group exists.
  /// - [peerId] has an existing invitation in [GroupMemberStatus.pendingInvite] status.
  /// - Group is not over capacity.
  ///
  /// Transitions member status to [GroupMemberStatus.active] and returns the updated member.
  Future<GroupMember> acceptInvitation({
    required String groupId,
    required String peerId,
    DateTime? timestamp,
  });

  /// Rejects a pending invitation for [peerId].
  ///
  /// Enforces:
  /// - Group exists.
  /// - [peerId] has a pending invitation.
  ///
  /// Marks member as [GroupMemberStatus.removed] (tombstone), releasing reserved capacity.
  Future<void> rejectInvitation({
    required String groupId,
    required String peerId,
  });

  /// Removes an active member or revokes a pending invitation.
  ///
  /// Enforces:
  /// - Group exists.
  /// - [requestingPeerId] is the current admin.
  /// - [targetPeerId] exists and is active or pending.
  /// - Admin cannot remove themselves.
  ///
  /// Transitions target to [GroupMemberStatus.removed], releasing capacity and preserving audit trail.
  Future<void> removeMember({
    required String groupId,
    required String requestingPeerId,
    required String targetPeerId,
  });

  /// Deletes a group and cascades deletion to all members.
  ///
  /// Enforces:
  /// - Group exists.
  /// - [requestingPeerId] is the current admin.
  Future<void> deleteGroup({
    required String groupId,
    required String requestingPeerId,
  });
}

