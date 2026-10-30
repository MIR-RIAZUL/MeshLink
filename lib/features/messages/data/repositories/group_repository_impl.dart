import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';
import 'package:meshlink/features/messages/domain/repositories/group_repository.dart';

/// Drift and SQLite-backed implementation of [GroupRepository].
///
/// Implements persistent group lifecycle and member management using [AppDatabase].
/// Enforces domain invariants, foreign-key cascade integrity, and strict active-membership
/// capacity limits (max 8 distinct active/pending participants, including the creator).
class DriftGroupRepository implements GroupRepository {
  DriftGroupRepository(this._db);

  final AppDatabase _db;

  /// Maximum permitted active or pending participants per group.
  static const int maxGroupCapacity = 8;

  @override
  Future<void> createGroup(Group group, {bool addCreatorAsMember = true}) async {
    try {
      final existing = await _db.getGroup(group.groupId);
      if (existing != null) {
        throw DuplicateGroupException(group.groupId);
      }

      await _db.transaction(() async {
        await _db.into(_db.groupsTable).insert(_groupToCompanion(group));

        if (addCreatorAsMember) {
          final creatorMember = GroupMember(
            groupId: group.groupId,
            peerId: group.creatorId,
            role: GroupRole.admin,
            status: GroupMemberStatus.active,
            joinedAt: group.createdAt.toUtc(),
            invitedBy: group.creatorId,
          );
          try {
            await _db.into(_db.groupMembersTable).insert(_memberToCompanion(creatorMember));
          } catch (e, st) {
            _handleDatabaseException(e, st, groupId: group.groupId, peerId: group.creatorId);
          }
        }
      });
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: group.groupId);
    }
  }

  @override
  Future<Group?> getGroup(String groupId) async {
    try {
      final entry = await _db.getGroup(groupId);
      return entry != null ? _entryToGroup(entry) : null;
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: groupId);
    }
  }

  @override
  Future<List<Group>> getAllGroups() async {
    try {
      final entries = await _db.getAllGroups();
      return entries.map(_entryToGroup).toList();
    } catch (e, st) {
      _handleDatabaseException(e, st);
    }
  }

  @override
  Future<void> updateGroup(Group group) async {
    try {
      final existing = await _db.getGroup(group.groupId);
      if (existing == null) {
        throw GroupNotFoundException(group.groupId);
      }

      if (group.epoch < existing.epoch) {
        throw InvalidGroupDataException(
          'Cannot decrement group epoch from ${existing.epoch} to ${group.epoch}.',
        );
      }

      final rowsAffected = await (_db.update(_db.groupsTable)
            ..where((t) => t.groupId.equals(group.groupId)))
          .write(
            GroupsTableCompanion(
              name: Value(group.name),
              adminId: Value(group.adminId),
              epoch: Value(group.epoch),
              updatedAt: Value(group.updatedAt.toUtc()),
            ),
          );

      if (rowsAffected == 0) {
        throw GroupNotFoundException(group.groupId);
      }
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: group.groupId);
    }
  }

  @override
  Future<void> updateGroupMetadata({
    required String groupId,
    String? name,
    String? adminId,
    int? epoch,
    DateTime? updatedAt,
  }) async {
    final existing = await getGroup(groupId);
    if (existing == null) {
      throw GroupNotFoundException(groupId);
    }

    final now = DateTime.now().toUtc();
    final effectiveUpdatedAt = updatedAt ??
        (now.isAfter(existing.createdAt) ? now : existing.createdAt);

    final updated = existing.copyWith(
      name: name,
      adminId: adminId,
      epoch: epoch,
      updatedAt: effectiveUpdatedAt,
    );
    await updateGroup(updated);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    try {
      final existing = await _db.getGroup(groupId);
      if (existing == null) {
        throw GroupNotFoundException(groupId);
      }

      final deletedCount = await _db.deleteGroup(groupId);
      if (deletedCount == 0) {
        throw GroupNotFoundException(groupId);
      }
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: groupId);
    }
  }

  @override
  Future<void> addPendingInvite({
    required String groupId,
    required String peerId,
    required String invitedBy,
    DateTime? joinedAt,
  }) {
    final member = GroupMember(
      groupId: groupId,
      peerId: peerId,
      role: GroupRole.member,
      status: GroupMemberStatus.pendingInvite,
      joinedAt: (joinedAt ?? DateTime.now().toUtc()),
      invitedBy: invitedBy,
    );
    return addMember(member);
  }

  @override
  Future<void> addMember(GroupMember member) async {
    try {
      // 1. Verify target group exists
      final group = await _db.getGroup(member.groupId);
      if (group == null) {
        throw GroupNotFoundException(member.groupId);
      }

      // 2. Prevent duplicate membership records from silently overwriting
      final existing = await _db.getGroupMember(member.groupId, member.peerId);
      if (existing != null) {
        throw DuplicateGroupMemberException(member.groupId, member.peerId);
      }

      // 3. Application-level capacity verification for active/pending participants
      if (member.status != GroupMemberStatus.removed) {
        final currentMembers = await _db.getGroupMembers(member.groupId);
        final activePeers = currentMembers
            .where((m) => m.status != 'removed' && m.peerId != member.peerId)
            .map((m) => m.peerId)
            .toSet();

        if (activePeers.length >= maxGroupCapacity) {
          throw GroupCapacityExceededException(
            member.groupId,
            maxGroupCapacity,
            'Group "${member.groupId}" has reached maximum capacity of $maxGroupCapacity members '
            '(attempted to add "${member.peerId}" with status "${member.status.name}").',
          );
        }
      }

      // 4. Raw insert: enforces SQLite PK and BEFORE INSERT trigger boundary
      await _db.into(_db.groupMembersTable).insert(_memberToCompanion(member));
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: member.groupId, peerId: member.peerId);
    }
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final entries = await _db.getGroupMembers(groupId);
      return entries.map(_entryToGroupMember).toList();
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: groupId);
    }
  }

  @override
  Future<GroupMember?> getGroupMember(String groupId, String peerId) async {
    try {
      final entry = await _db.getGroupMember(groupId, peerId);
      return entry != null ? _entryToGroupMember(entry) : null;
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: groupId, peerId: peerId);
    }
  }

  @override
  Future<List<GroupMember>> getMembersByStatus(
    String groupId,
    GroupMemberStatus status,
  ) async {
    try {
      final query = _db.select(_db.groupMembersTable)
        ..where((t) => t.groupId.equals(groupId) & t.status.equals(status.toJson()))
        ..orderBy([(t) => OrderingTerm.asc(t.joinedAt)]);
      final entries = await query.get();
      return entries.map(_entryToGroupMember).toList();
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: groupId);
    }
  }

  @override
  Future<void> updateMemberStatus(
    String groupId,
    String peerId,
    GroupMemberStatus newStatus,
  ) async {
    try {
      final existing = await _db.getGroupMember(groupId, peerId);
      if (existing == null) {
        throw GroupMemberNotFoundException(groupId, peerId);
      }

      if (existing.status == newStatus.toJson()) {
        return;
      }

      // If reactivating from 'removed' to active or pendingInvite, check capacity
      if (existing.status == 'removed' && newStatus != GroupMemberStatus.removed) {
        final currentMembers = await _db.getGroupMembers(groupId);
        final activePeers = currentMembers
            .where((m) => m.status != 'removed' && m.peerId != peerId)
            .map((m) => m.peerId)
            .toSet();

        if (activePeers.length >= maxGroupCapacity) {
          throw GroupCapacityExceededException(
            groupId,
            maxGroupCapacity,
            'Cannot reactivate member "$peerId": group "$groupId" already has $maxGroupCapacity active/pending members.',
          );
        }
      }

      final rowsAffected = await (_db.update(_db.groupMembersTable)
            ..where((t) => t.groupId.equals(groupId) & t.peerId.equals(peerId)))
          .write(GroupMembersTableCompanion(status: Value(newStatus.toJson())));

      if (rowsAffected == 0) {
        throw GroupMemberNotFoundException(groupId, peerId);
      }
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: groupId, peerId: peerId);
    }
  }

  @override
  Future<void> removeMember(String groupId, String peerId) {
    return updateMemberStatus(groupId, peerId, GroupMemberStatus.removed);
  }

  @override
  Future<void> markMemberRemoved(String groupId, String peerId) {
    return removeMember(groupId, peerId);
  }

  @override
  Future<void> deleteMemberRecord(String groupId, String peerId) async {
    try {
      final existing = await _db.getGroupMember(groupId, peerId);
      if (existing == null) {
        throw GroupMemberNotFoundException(groupId, peerId);
      }

      final deletedCount = await _db.deleteGroupMember(groupId, peerId);
      if (deletedCount == 0) {
        throw GroupMemberNotFoundException(groupId, peerId);
      }
    } catch (e, st) {
      _handleDatabaseException(e, st, groupId: groupId, peerId: peerId);
    }
  }

  // --- Visible For Testing Helpers ---

  Group entryToGroupForTesting(GroupEntry entry) => _entryToGroup(entry);

  GroupMember entryToGroupMemberForTesting(GroupMemberEntry entry) =>
      _entryToGroupMember(entry);

  // --- Entity Mapping & Validation ---

  Group _entryToGroup(GroupEntry entry) {
    try {
      return Group(
        groupId: entry.groupId,
        name: entry.name,
        creatorId: entry.creatorId,
        adminId: entry.adminId,
        epoch: entry.epoch,
        createdAt: entry.createdAt.toUtc(),
        updatedAt: entry.updatedAt.toUtc(),
      );
    } on ArgumentError catch (e) {
      throw InvalidGroupDataException(
        'Invalid database record for group "${entry.groupId}": ${e.message}',
      );
    }
  }

  GroupsTableCompanion _groupToCompanion(Group group) {
    return GroupsTableCompanion.insert(
      groupId: group.groupId,
      name: group.name,
      creatorId: group.creatorId,
      adminId: group.adminId,
      epoch: Value(group.epoch),
      createdAt: group.createdAt.toUtc(),
      updatedAt: group.updatedAt.toUtc(),
    );
  }

  GroupMember _entryToGroupMember(GroupMemberEntry entry) {
    try {
      final role = GroupRole.fromString(entry.role);
      final status = GroupMemberStatus.fromString(entry.status);

      return GroupMember(
        groupId: entry.groupId,
        peerId: entry.peerId,
        role: role,
        status: status,
        joinedAt: entry.joinedAt.toUtc(),
        invitedBy: entry.invitedBy,
      );
    } on ArgumentError catch (e) {
      throw InvalidGroupDataException(
        'Invalid database record for member "${entry.peerId}" in group "${entry.groupId}": ${e.message}',
      );
    }
  }

  GroupMembersTableCompanion _memberToCompanion(GroupMember member) {
    return GroupMembersTableCompanion.insert(
      groupId: member.groupId,
      peerId: member.peerId,
      role: member.role.toJson(),
      status: member.status.toJson(),
      joinedAt: member.joinedAt.toUtc(),
      invitedBy: member.invitedBy,
    );
  }

  // --- Exception Translation ---

  Never _handleDatabaseException(
    Object error,
    StackTrace stackTrace, {
    String? groupId,
    String? peerId,
  }) {
    if (error is GroupRepositoryException) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (error is ArgumentError) {
      Error.throwWithStackTrace(
        InvalidGroupDataException(error.message?.toString() ?? error.toString()),
        stackTrace,
      );
    }

    if (error is FormatException) {
      Error.throwWithStackTrace(
        InvalidGroupDataException(error.message),
        stackTrace,
      );
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('limit of 8 exceeded') ||
        errorString.contains('group member limit') ||
        errorString.contains('group membership limit exceeded')) {
      Error.throwWithStackTrace(
        GroupCapacityExceededException(
          groupId ?? 'unknown',
          maxGroupCapacity,
          'Group capacity limit of $maxGroupCapacity members exceeded: $error',
        ),
        stackTrace,
      );
    }

    if (errorString.contains('foreign key') || errorString.contains('foreign_key')) {
      Error.throwWithStackTrace(
        InvalidGroupReferenceException('Foreign key constraint failed for group: $error'),
        stackTrace,
      );
    }

    if (errorString.contains('unique') || errorString.contains('primary key')) {
      if (peerId != null && groupId != null) {
        Error.throwWithStackTrace(
          DuplicateGroupMemberException(
            groupId,
            peerId,
            'Member "$peerId" already exists in group "$groupId".',
          ),
          stackTrace,
        );
      }
      if (groupId != null) {
        Error.throwWithStackTrace(
          DuplicateGroupException(groupId, 'Group "$groupId" already exists.'),
          stackTrace,
        );
      }
    }

    if (errorString.contains('check')) {
      Error.throwWithStackTrace(
        InvalidGroupDataException('Database check constraint failed: $error'),
        stackTrace,
      );
    }

    if (error is SqliteException) {
      Error.throwWithStackTrace(
        InvalidGroupDataException('SQLite error (${error.extendedResultCode}): ${error.message}'),
        stackTrace,
      );
    }

    Error.throwWithStackTrace(error, stackTrace);
  }
}
