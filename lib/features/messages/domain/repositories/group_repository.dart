import 'package:meshlink/features/messages/domain/models/group.dart';

/// Base exception for all group repository errors.
abstract class GroupRepositoryException implements Exception {
  final String message;
  const GroupRepositoryException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a requested group does not exist in the database.
class GroupNotFoundException extends GroupRepositoryException {
  final String groupId;
  const GroupNotFoundException(this.groupId, [String? message])
      : super(message ?? 'Group not found: "$groupId".');
}

/// Thrown when attempting to create a group whose ID already exists.
class DuplicateGroupException extends GroupRepositoryException {
  final String groupId;
  const DuplicateGroupException(this.groupId, [String? message])
      : super(message ?? 'Group with ID "$groupId" already exists.');
}

/// Thrown when a requested group member does not exist in the database.
class GroupMemberNotFoundException extends GroupRepositoryException {
  final String groupId;
  final String peerId;
  const GroupMemberNotFoundException(this.groupId, this.peerId, [String? message])
      : super(message ?? 'Group member not found: "$peerId" in group "$groupId".');
}

/// Thrown when attempting to add a member that already exists in the group.
class DuplicateGroupMemberException extends GroupRepositoryException {
  final String groupId;
  final String peerId;
  const DuplicateGroupMemberException(this.groupId, this.peerId, [String? message])
      : super(message ?? 'Member "$peerId" already exists in group "$groupId".');
}

/// Thrown when an operation would cause active/pending members to exceed the maximum capacity of 8.
class GroupCapacityExceededException extends GroupRepositoryException {
  final String groupId;
  final int limit;
  const GroupCapacityExceededException(this.groupId, [this.limit = 8, String? message])
      : super(message ?? 'Group "$groupId" has reached maximum capacity of $limit active members.');
}

/// Thrown when an operation references an invalid or non-existent group.
class InvalidGroupReferenceException extends GroupRepositoryException {
  const InvalidGroupReferenceException(super.message);
}

/// Thrown when persisted or incoming group data violates domain or schema invariants.
class InvalidGroupDataException extends GroupRepositoryException {
  const InvalidGroupDataException(super.message);
}

/// Domain repository interface for managing group persistence, metadata, and memberships.
///
/// This interface is completely independent of SQLite and Drift, exposing only pure
/// domain models ([Group], [GroupMember], [GroupRole], [GroupMemberStatus]) and
/// typed repository exceptions.
abstract class GroupRepository {
  /// Creates a new group record.
  ///
  /// If [addCreatorAsMember] is `true` (default), the creator is atomically added as
  /// an active administrator member within the same database transaction.
  ///
  /// Throws [DuplicateGroupException] if a group with this ID already exists.
  /// Throws [InvalidGroupDataException] if group data is invalid.
  Future<void> createGroup(Group group, {bool addCreatorAsMember = true});

  /// Retrieves a group by its [groupId].
  ///
  /// Returns `null` if the group does not exist.
  Future<Group?> getGroup(String groupId);

  /// Retrieves all groups, ordered by creation time descending.
  Future<List<Group>> getAllGroups();

  /// Updates permitted group metadata (name, adminId, epoch, updatedAt).
  ///
  /// Throws [GroupNotFoundException] if the group does not exist.
  /// Throws [InvalidGroupDataException] if the update violates domain rules
  /// (e.g. attempting to decrement the epoch).
  Future<void> updateGroup(Group group);

  /// Convenience helper to update specific group metadata fields.
  Future<void> updateGroupMetadata({
    required String groupId,
    String? name,
    String? adminId,
    int? epoch,
    DateTime? updatedAt,
  });

  /// Deletes a group and cascades deletion to all associated members.
  ///
  /// Throws [GroupNotFoundException] if the group does not exist.
  Future<void> deleteGroup(String groupId);

  /// Adds a pending invitation for a peer to join the group.
  ///
  /// A pending invitation reserves capacity in the group.
  /// Throws [GroupNotFoundException] if the group does not exist.
  /// Throws [DuplicateGroupMemberException] if the member already exists in the group.
  /// Throws [GroupCapacityExceededException] if the group is already at full capacity (8 active/pending members).
  Future<void> addPendingInvite({
    required String groupId,
    required String peerId,
    required String invitedBy,
    DateTime? joinedAt,
  });

  /// Adds a member to the group.
  ///
  /// Throws [GroupNotFoundException] if the group does not exist.
  /// Throws [DuplicateGroupMemberException] if the member already exists in the group.
  /// Throws [GroupCapacityExceededException] if adding an active/pending member exceeds capacity.
  Future<void> addMember(GroupMember member);

  /// Retrieves all members of a group, ordered chronologically by joinedAt.
  Future<List<GroupMember>> getGroupMembers(String groupId);

  /// Retrieves a specific member of a group.
  ///
  /// Returns `null` if the member is not found.
  Future<GroupMember?> getGroupMember(String groupId, String peerId);

  /// Retrieves all members of a group matching a specific [status].
  Future<List<GroupMember>> getMembersByStatus(
    String groupId,
    GroupMemberStatus status,
  );

  /// Updates the status of an existing group member.
  ///
  /// If reactivating a removed member (transitioning to [GroupMemberStatus.active] or
  /// [GroupMemberStatus.pendingInvite]), verifies that active group capacity will not exceed 8.
  ///
  /// Throws [GroupMemberNotFoundException] if the member does not exist.
  /// Throws [GroupCapacityExceededException] if reactivation exceeds capacity.
  Future<void> updateMemberStatus(
    String groupId,
    String peerId,
    GroupMemberStatus newStatus,
  );

  /// Marks a group member as removed.
  ///
  /// Preserves the member record for audit and history, but frees an active group slot.
  /// Throws [GroupMemberNotFoundException] if the member does not exist.
  Future<void> removeMember(String groupId, String peerId);

  /// Alias for [removeMember].
  Future<void> markMemberRemoved(String groupId, String peerId);

  /// Completely deletes a specific member record from the database.
  ///
  /// Throws [GroupMemberNotFoundException] if the member does not exist.
  Future<void> deleteMemberRecord(String groupId, String peerId);
}

