import 'dart:convert';
import 'dart:math';

/// Role of a peer within a group.
enum GroupRole {
  /// Administrator who can invite members, remove members, and update group settings.
  admin,

  /// Regular participant in the group.
  member;

  /// Serializes the role to its wire/JSON string name.
  String toJson() => name;

  /// Parses role strictly from a string.
  ///
  /// Throws [ArgumentError] if the value does not match any valid [GroupRole].
  /// Silently defaulting is strictly prohibited to prevent privilege escalation.
  static GroupRole fromString(String value) {
    switch (value.trim()) {
      case 'admin':
        return GroupRole.admin;
      case 'member':
        return GroupRole.member;
      default:
        throw ArgumentError('Invalid GroupRole: "$value". Allowed values: [admin, member].');
    }
  }

  /// Parses role safely, returning null if invalid or null.
  static GroupRole? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }
}

/// Lifecycle status of a peer's membership within a group.
enum GroupMemberStatus {
  /// Active participant who has manually accepted an invitation (or is creator).
  ///
  /// Active members are permitted to participate in group messaging.
  active,

  /// Invitation has been sent to or received by the peer, but has not yet been accepted.
  ///
  /// A pending invitation does NOT confer active membership.
  /// The peer cannot send or receive group messages until manual acceptance occurs.
  pendingInvite,

  /// Peer was removed by an administrator or has departed the group.
  ///
  /// A removed member is strictly prevented from participating in the group.
  removed;

  /// Serializes the status to its wire/JSON string name.
  String toJson() => name;

  /// Parses status strictly from a string.
  ///
  /// Throws [ArgumentError] if the value does not match any valid [GroupMemberStatus].
  /// Silently defaulting is strictly prohibited.
  static GroupMemberStatus fromString(String value) {
    switch (value.trim()) {
      case 'active':
        return GroupMemberStatus.active;
      case 'pendingInvite':
        return GroupMemberStatus.pendingInvite;
      case 'removed':
        return GroupMemberStatus.removed;
      default:
        throw ArgumentError(
          'Invalid GroupMemberStatus: "$value". Allowed values: [active, pendingInvite, removed].',
        );
    }
  }

  /// Parses status safely, returning null if invalid or null.
  static GroupMemberStatus? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }
}

/// Immutable domain model representing a group in MeshLink.
///
/// Phase 9 Step 2: Group Domain Models
///
/// Governance & Constraints:
/// - Maximum group size is 8 members (including creator).
/// - Membership governance is admin-only.
/// - The creator is the initial group admin (`creatorId == adminId` in epoch 1).
/// - Group ID format: `GRP-<timestampMs>-<randomHex6>`.
/// - Group name: trimmed, non-empty, 1-64 characters.
/// - Timestamps must be valid UTC.
/// - Epoch must be an integer >= 1.
class Group {
  Group({
    required this.groupId,
    required String name,
    required this.creatorId,
    required this.adminId,
    this.epoch = 1,
    required this.createdAt,
    required this.updatedAt,
  }) : name = validateAndSanitizeName(name) {
    validateGroupId(groupId);
    validatePeerId(creatorId, 'creatorId');
    validatePeerId(adminId, 'adminId');

    if (epoch < 1) {
      throw ArgumentError('epoch must be an integer >= 1 (got $epoch).');
    }

    if (!createdAt.isUtc) {
      throw ArgumentError('createdAt must represent a valid UTC timestamp.');
    }
    if (!updatedAt.isUtc) {
      throw ArgumentError('updatedAt must represent a valid UTC timestamp.');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError(
        'updatedAt ($updatedAt) cannot precede createdAt ($createdAt).',
      );
    }

    // In initial group state (epoch == 1), the creator is the initial admin.
    if (epoch == 1 && creatorId != adminId) {
      throw ArgumentError(
        'Newly created group (epoch 1) must enforce creatorId == adminId '
        '(creatorId: "$creatorId", adminId: "$adminId").',
      );
    }
  }

  /// Factory for creating a brand new group where the creator is the initial admin.
  factory Group.create({
    required String groupId,
    required String name,
    required String creatorId,
    DateTime? createdAt,
  }) {
    final nowUtc = (createdAt ?? DateTime.now().toUtc());
    if (!nowUtc.isUtc) {
      throw ArgumentError('createdAt must represent a valid UTC timestamp.');
    }
    return Group(
      groupId: groupId,
      name: name,
      creatorId: creatorId,
      adminId: creatorId,
      epoch: 1,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  /// Unique group identifier following format `GRP-<timestampMs>-<randomHex6>`.
  final String groupId;

  /// Human-readable group name (1-64 characters, trimmed).
  final String name;

  /// Peer identifier of the group creator.
  final String creatorId;

  /// Peer identifier of current group administrator.
  final String adminId;

  /// Monotonically increasing membership epoch (starts at 1).
  final int epoch;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last update timestamp.
  final DateTime updatedAt;

  static final RegExp _groupIdRegex = RegExp(r'^GRP-(\d+)-([0-9a-fA-F]{6})$');
  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');
  static const int maxPeerIdLength = 128;
  static const int maxNameLength = 64;

  /// Generates a valid [groupId] following the format `GRP-<timestampMs>-<randomHex6>`.
  static String generateGroupId([DateTime? now]) {
    final timestamp = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final rand = Random()
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return 'GRP-$timestamp-$rand';
  }

  /// Validates the structure of a [groupId].
  ///
  /// Must match `GRP-<timestampMs>-<randomHex6>`, where `<timestampMs>` is a positive integer
  /// and `<randomHex6>` is exactly 6 hex characters.
  static void validateGroupId(String groupId) {
    if (groupId.trim() != groupId) {
      throw ArgumentError('groupId must not contain leading or trailing whitespace.');
    }
    final match = _groupIdRegex.firstMatch(groupId);
    if (match == null) {
      throw ArgumentError(
        'Invalid groupId format: "$groupId". Expected format "GRP-<timestampMs>-<randomHex6>".',
      );
    }
    final timestamp = int.tryParse(match.group(1)!);
    if (timestamp == null || timestamp <= 0) {
      throw ArgumentError('Invalid timestamp in groupId: "${match.group(1)}".');
    }
  }

  /// Validates that [rawName] is non-empty and 1-64 characters after trimming.
  ///
  /// Returns the trimmed name. Throws [ArgumentError] if invalid.
  static String validateAndSanitizeName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Group name cannot be empty or whitespace-only.');
    }
    if (trimmed.length > maxNameLength) {
      throw ArgumentError(
        'Group name exceeds maximum allowed limit of $maxNameLength characters (length: ${trimmed.length}).',
      );
    }
    return trimmed;
  }

  /// Validates that [peerId] is non-empty, within length limits, has no control characters,
  /// and has no leading or trailing whitespace.
  static void validatePeerId(String peerId, String fieldName) {
    if (peerId.isEmpty) {
      throw ArgumentError('$fieldName cannot be empty.');
    }
    if (peerId.trim() != peerId) {
      throw ArgumentError('$fieldName must not contain leading or trailing whitespace.');
    }
    if (peerId.length > maxPeerIdLength) {
      throw ArgumentError(
        '$fieldName exceeds maximum length of $maxPeerIdLength characters (length: ${peerId.length}).',
      );
    }
    if (_controlCharRegex.hasMatch(peerId)) {
      throw ArgumentError('$fieldName contains forbidden control characters.');
    }
  }

  Group copyWith({
    String? groupId,
    String? name,
    String? creatorId,
    String? adminId,
    int? epoch,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      adminId: adminId ?? this.adminId,
      epoch: epoch ?? this.epoch,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'name': name,
    'creatorId': creatorId,
    'adminId': adminId,
    'epoch': epoch,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  String toJson() => jsonEncode(toMap());

  factory Group.fromMap(Map<String, dynamic> map) {
    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawName = map['name'];
    if (rawName is! String) {
      throw const FormatException('Missing or invalid type for "name" (expected String).');
    }

    final rawCreatorId = map['creatorId'];
    if (rawCreatorId is! String) {
      throw const FormatException('Missing or invalid type for "creatorId" (expected String).');
    }

    final rawAdminId = map['adminId'];
    if (rawAdminId is! String) {
      throw const FormatException('Missing or invalid type for "adminId" (expected String).');
    }

    final rawEpoch = map['epoch'];
    if (rawEpoch is! int) {
      throw const FormatException('Missing or invalid type for "epoch" (expected int).');
    }

    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is! String) {
      throw const FormatException('Missing or invalid type for "createdAt" (expected String).');
    }

    final rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is! String) {
      throw const FormatException('Missing or invalid type for "updatedAt" (expected String).');
    }

    final parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    if (parsedCreatedAt == null || !parsedCreatedAt.isUtc) {
      throw const FormatException('Invalid or non-UTC "createdAt" timestamp in Group JSON.');
    }

    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    if (parsedUpdatedAt == null || !parsedUpdatedAt.isUtc) {
      throw const FormatException('Invalid or non-UTC "updatedAt" timestamp in Group JSON.');
    }

    try {
      return Group(
        groupId: rawGroupId,
        name: rawName,
        creatorId: rawCreatorId,
        adminId: rawAdminId,
        epoch: rawEpoch,
        createdAt: parsedCreatedAt,
        updatedAt: parsedUpdatedAt,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Failed to deserialize Group: ${e.message}');
    }
  }

  factory Group.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for Group: expected Map.');
    }
    return Group.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          name == other.name &&
          creatorId == other.creatorId &&
          adminId == other.adminId &&
          epoch == other.epoch &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    groupId,
    name,
    creatorId,
    adminId,
    epoch,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Group(id: $groupId, name: "$name", admin: $adminId, epoch: $epoch)';
}

/// Immutable domain model representing a group member.
///
/// Phase 9 Step 2: Group Domain Models
///
/// Models manual invitation acceptance explicitly:
/// - [GroupMemberStatus.pendingInvite] represents an unaccepted invitation.
/// - [GroupMemberStatus.active] represents active participation.
/// - [GroupMemberStatus.removed] represents a removed or departed member.
class GroupMember {
  GroupMember({
    required this.groupId,
    required this.peerId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.invitedBy,
  }) {
    Group.validateGroupId(groupId);
    Group.validatePeerId(peerId, 'peerId');
    Group.validatePeerId(invitedBy, 'invitedBy');

    if (!joinedAt.isUtc) {
      throw ArgumentError('joinedAt must represent a valid UTC timestamp.');
    }
  }

  /// Target group identifier.
  final String groupId;

  /// Peer device identifier.
  final String peerId;

  /// Member's role within the group ([GroupRole.admin] or [GroupRole.member]).
  final GroupRole role;

  /// Current membership status ([GroupMemberStatus.active], [GroupMemberStatus.pendingInvite], [GroupMemberStatus.removed]).
  final GroupMemberStatus status;

  /// UTC timestamp when member joined or was invited.
  final DateTime joinedAt;

  /// Peer identifier of the administrator who invited this member.
  final String invitedBy;

  /// True if the member is currently active and permitted to participate.
  bool get isActive => status == GroupMemberStatus.active;

  /// True if the member is awaiting manual acceptance.
  bool get isPendingInvite => status == GroupMemberStatus.pendingInvite;

  /// True if the member has been removed or left the group.
  bool get isRemoved => status == GroupMemberStatus.removed;

  /// True if the member is a group administrator.
  bool get isAdmin => role == GroupRole.admin;

  /// True if the member is a regular member.
  bool get isMember => role == GroupRole.member;

  GroupMember copyWith({
    String? groupId,
    String? peerId,
    GroupRole? role,
    GroupMemberStatus? status,
    DateTime? joinedAt,
    String? invitedBy,
  }) {
    return GroupMember(
      groupId: groupId ?? this.groupId,
      peerId: peerId ?? this.peerId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
    );
  }

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'peerId': peerId,
    'role': role.toJson(),
    'status': status.toJson(),
    'joinedAt': joinedAt.toIso8601String(),
    'invitedBy': invitedBy,
  };

  String toJson() => jsonEncode(toMap());

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawPeerId = map['peerId'];
    if (rawPeerId is! String) {
      throw const FormatException('Missing or invalid type for "peerId" (expected String).');
    }

    final rawRole = map['role'];
    if (rawRole is! String) {
      throw const FormatException('Missing or invalid type for "role" (expected String).');
    }

    final rawStatus = map['status'];
    if (rawStatus is! String) {
      throw const FormatException('Missing or invalid type for "status" (expected String).');
    }

    final rawJoinedAt = map['joinedAt'];
    if (rawJoinedAt is! String) {
      throw const FormatException('Missing or invalid type for "joinedAt" (expected String).');
    }

    final rawInvitedBy = map['invitedBy'];
    if (rawInvitedBy is! String) {
      throw const FormatException('Missing or invalid type for "invitedBy" (expected String).');
    }

    final parsedJoinedAt = DateTime.tryParse(rawJoinedAt);
    if (parsedJoinedAt == null || !parsedJoinedAt.isUtc) {
      throw const FormatException('Invalid or non-UTC "joinedAt" timestamp in GroupMember JSON.');
    }

    final role = GroupRole.fromString(rawRole);
    final status = GroupMemberStatus.fromString(rawStatus);

    try {
      return GroupMember(
        groupId: rawGroupId,
        peerId: rawPeerId,
        role: role,
        status: status,
        joinedAt: parsedJoinedAt,
        invitedBy: rawInvitedBy,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Failed to deserialize GroupMember: ${e.message}');
    }
  }

  factory GroupMember.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for GroupMember: expected Map.');
    }
    return GroupMember.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          peerId == other.peerId &&
          role == other.role &&
          status == other.status &&
          joinedAt == other.joinedAt &&
          invitedBy == other.invitedBy;

  @override
  int get hashCode => Object.hash(
    groupId,
    peerId,
    role,
    status,
    joinedAt,
    invitedBy,
  );

  @override
  String toString() =>
      'GroupMember(group: $groupId, peer: $peerId, role: ${role.name}, status: ${status.name})';
}

/// Reusable domain validation helper for group membership limits and integrity.
///
/// Enforces the Phase 9 rule: at most 8 members per group, including the creator.
/// Duplicate peer IDs are deduplicated and not counted as separate members.
class GroupMembershipValidator {
  /// Maximum group size, including the creator.
  static const int maxGroupMembers = 8;

  /// Validates that a collection of proposed group members satisfies the
  /// group size limit of at most 8 distinct members.
  ///
  /// Duplicate peer IDs are deduplicated and not counted as separate members.
  ///
  /// If [expectedGroupId] is provided, verifies that all members belong to the specified group.
  ///
  /// Throws [ArgumentError] if distinct member count exceeds 8 or if members belong
  /// to an unexpected group.
  static void validateProposedMembers(
    Iterable<GroupMember> members, {
    String? expectedGroupId,
  }) {
    if (expectedGroupId != null) {
      for (final member in members) {
        if (member.groupId != expectedGroupId) {
          throw ArgumentError(
            'Member "${member.peerId}" has groupId "${member.groupId}", '
            'expected "$expectedGroupId".',
          );
        }
      }
    }

    final distinctPeerIds = members.map((m) => m.peerId).toSet();
    if (distinctPeerIds.length > maxGroupMembers) {
      throw ArgumentError(
        'Group membership limit exceeded: maximum $maxGroupMembers distinct members allowed '
        '(got ${distinctPeerIds.length}).',
      );
    }
  }

  /// Validates a collection of proposed peer IDs against the group size limit of at most 8.
  ///
  /// Deduplicates peer IDs so duplicate occurrences are not counted multiple times.
  /// Throws [ArgumentError] if distinct peer count exceeds 8.
  static void validateProposedPeerIds(Iterable<String> peerIds) {
    for (final id in peerIds) {
      Group.validatePeerId(id, 'peerId');
    }
    final distinctPeerIds = peerIds.toSet();
    if (distinctPeerIds.length > maxGroupMembers) {
      throw ArgumentError(
        'Group membership limit exceeded: maximum $maxGroupMembers distinct members allowed '
        '(got ${distinctPeerIds.length}).',
      );
    }
  }
}
