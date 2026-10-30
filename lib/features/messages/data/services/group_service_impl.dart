import 'package:meshlink/features/messages/domain/models/group.dart';
import 'package:meshlink/features/messages/domain/repositories/group_repository.dart';
import 'package:meshlink/features/messages/domain/services/group_service.dart';

/// Implementation of [GroupService] coordinating group business rules and lifecycles.
///
/// Encapsulates authorization rules (admin-only membership governance), manual invitation
/// acceptance, cohort capacity constraints (max 8 active/pending participants including creator),
/// and audit preservation of removed members.
class GroupServiceImpl implements GroupService {
  GroupServiceImpl({required GroupRepository groupRepository})
      : _repo = groupRepository;

  final GroupRepository _repo;

  @override
  Future<Group> createGroup({
    required String name,
    required String creatorId,
    String? groupId,
    DateTime? createdAt,
  }) async {
    final sanitizedName = Group.validateAndSanitizeName(name);
    Group.validatePeerId(creatorId, 'creatorId');

    final nowUtc = (createdAt ?? DateTime.now().toUtc());
    if (!nowUtc.isUtc) {
      throw ArgumentError('createdAt must represent a valid UTC timestamp.');
    }

    if (groupId != null) {
      Group.validateGroupId(groupId);
    }
    final gid = groupId ?? Group.generateGroupId(nowUtc);

    final group = Group.create(
      groupId: gid,
      name: sanitizedName,
      creatorId: creatorId,
      createdAt: nowUtc,
    );

    // Repository atomically writes group and registers creator as active admin member.
    await _repo.createGroup(group, addCreatorAsMember: true);
    return group;
  }

  @override
  Future<Group?> getGroup(String groupId) {
    return _repo.getGroup(groupId);
  }

  @override
  Future<List<Group>> getAllGroups() {
    return _repo.getAllGroups();
  }

  @override
  Future<List<GroupMember>> getActiveMembers(String groupId) {
    return _repo.getMembersByStatus(groupId, GroupMemberStatus.active);
  }

  @override
  Future<List<GroupMember>> getPendingInvitations(String groupId) {
    return _repo.getMembersByStatus(groupId, GroupMemberStatus.pendingInvite);
  }

  @override
  Future<List<GroupMember>> getRemovedMembers(String groupId) {
    return _repo.getMembersByStatus(groupId, GroupMemberStatus.removed);
  }

  @override
  Future<GroupMember?> getMember(String groupId, String peerId) {
    return _repo.getGroupMember(groupId, peerId);
  }

  @override
  Future<bool> isActiveMember(String groupId, String peerId) async {
    final member = await _repo.getGroupMember(groupId, peerId);
    return member != null && member.status == GroupMemberStatus.active;
  }

  @override
  Future<bool> isGroupAdmin(String groupId, String peerId) async {
    final group = await _repo.getGroup(groupId);
    return group != null && group.adminId == peerId;
  }

  @override
  Future<bool> canSendGroupMessages(String groupId, String peerId) {
    return isActiveMember(groupId, peerId);
  }

  @override
  Future<GroupMember> invitePeer({
    required String groupId,
    required String requestingPeerId,
    required String targetPeerId,
    DateTime? timestamp,
  }) async {
    Group.validatePeerId(requestingPeerId, 'requestingPeerId');
    Group.validatePeerId(targetPeerId, 'targetPeerId');

    final group = await _repo.getGroup(groupId);
    if (group == null) {
      throw GroupNotFoundException(groupId);
    }

    if (group.adminId != requestingPeerId) {
      throw GroupAuthorizationException(groupId, requestingPeerId);
    }

    final existingMember = await _repo.getGroupMember(groupId, targetPeerId);
    if (existingMember != null) {
      if (existingMember.status == GroupMemberStatus.active) {
        throw InvitationAlreadyExistsException(
          groupId,
          targetPeerId,
          'Peer "$targetPeerId" is already an active member of group "$groupId".',
        );
      }
      if (existingMember.status == GroupMemberStatus.pendingInvite) {
        throw InvitationAlreadyExistsException(
          groupId,
          targetPeerId,
          'A pending invitation already exists for peer "$targetPeerId" in group "$groupId".',
        );
      }

      // If existingMember.status == GroupMemberStatus.removed:
      // Re-invitation of a previously removed member by the admin.
      // Re-activating to pendingInvite reserves capacity and checks limits.
      await _repo.updateMemberStatus(groupId, targetPeerId, GroupMemberStatus.pendingInvite);
      return (await _repo.getGroupMember(groupId, targetPeerId))!;
    }

    final nowUtc = (timestamp ?? DateTime.now().toUtc());
    await _repo.addPendingInvite(
      groupId: groupId,
      peerId: targetPeerId,
      invitedBy: requestingPeerId,
      joinedAt: nowUtc,
    );

    return (await _repo.getGroupMember(groupId, targetPeerId))!;
  }

  @override
  Future<GroupMember> acceptInvitation({
    required String groupId,
    required String peerId,
    DateTime? timestamp,
  }) async {
    final group = await _repo.getGroup(groupId);
    if (group == null) {
      throw GroupNotFoundException(groupId);
    }

    final member = await _repo.getGroupMember(groupId, peerId);
    if (member == null) {
      throw NoPendingInvitationException(groupId, peerId);
    }

    if (member.status == GroupMemberStatus.active) {
      throw InvalidGroupStateException(
        'Invitation for peer "$peerId" in group "$groupId" has already been accepted.',
      );
    }

    if (member.status == GroupMemberStatus.removed) {
      throw NoPendingInvitationException(
        groupId,
        peerId,
        'Cannot accept invitation: member "$peerId" was removed from group "$groupId".',
      );
    }

    if (member.status != GroupMemberStatus.pendingInvite) {
      throw NoPendingInvitationException(groupId, peerId);
    }

    await _repo.updateMemberStatus(groupId, peerId, GroupMemberStatus.active);
    return (await _repo.getGroupMember(groupId, peerId))!;
  }

  @override
  Future<void> rejectInvitation({
    required String groupId,
    required String peerId,
  }) async {
    final group = await _repo.getGroup(groupId);
    if (group == null) {
      throw GroupNotFoundException(groupId);
    }

    final member = await _repo.getGroupMember(groupId, peerId);
    if (member == null || member.status != GroupMemberStatus.pendingInvite) {
      throw NoPendingInvitationException(groupId, peerId);
    }

    // Rejection transitions status to removed, freeing the reserved capacity slot.
    await _repo.updateMemberStatus(groupId, peerId, GroupMemberStatus.removed);
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String requestingPeerId,
    required String targetPeerId,
  }) async {
    final group = await _repo.getGroup(groupId);
    if (group == null) {
      throw GroupNotFoundException(groupId);
    }

    if (group.adminId != requestingPeerId) {
      throw GroupAuthorizationException(groupId, requestingPeerId);
    }

    if (targetPeerId == group.adminId) {
      throw AdminSelfRemovalProhibitedException(groupId, targetPeerId);
    }

    final member = await _repo.getGroupMember(groupId, targetPeerId);
    if (member == null) {
      throw GroupMemberNotFoundException(groupId, targetPeerId);
    }

    if (member.status == GroupMemberStatus.removed) {
      throw MemberAlreadyRemovedException(groupId, targetPeerId);
    }

    await _repo.removeMember(groupId, targetPeerId);
  }

  @override
  Future<void> deleteGroup({
    required String groupId,
    required String requestingPeerId,
  }) async {
    final group = await _repo.getGroup(groupId);
    if (group == null) {
      throw GroupNotFoundException(groupId);
    }

    if (group.adminId != requestingPeerId) {
      throw GroupAuthorizationException(groupId, requestingPeerId);
    }

    await _repo.deleteGroup(groupId);
  }
}
