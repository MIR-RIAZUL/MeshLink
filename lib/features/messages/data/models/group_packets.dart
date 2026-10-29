import 'dart:convert';
import 'dart:typed_data';

import 'package:meshlink/features/messages/domain/models/group.dart';

/// Helper for validating group packet identifiers, epochs, timestamps, and ciphertext.
class GroupPacketValidator {
  static const int currentProtocolVersion = 1;
  static const int maxIdLength = 128;
  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');

  /// Validates an arbitrary identifier (message ID, invite ID, remove ID, etc.).
  static void validateIdentifier(String id, String fieldName) {
    if (id.isEmpty) {
      throw ArgumentError('$fieldName cannot be empty.');
    }
    if (id.trim() != id) {
      throw ArgumentError('$fieldName must not contain leading or trailing whitespace.');
    }
    if (id.length > maxIdLength) {
      throw ArgumentError(
        '$fieldName exceeds maximum length of $maxIdLength characters (length: ${id.length}).',
      );
    }
    if (_controlCharRegex.hasMatch(id)) {
      throw ArgumentError('$fieldName contains forbidden control characters.');
    }
  }

  /// Validates that [epoch] is an integer >= 1.
  static void validateEpoch(int epoch) {
    if (epoch < 1) {
      throw ArgumentError('epoch must be an integer >= 1 (got $epoch).');
    }
  }

  /// Validates that [timestamp] is non-null and represents UTC.
  static void validateTimestamp(DateTime timestamp, String fieldName) {
    if (!timestamp.isUtc) {
      throw ArgumentError('$fieldName must represent a valid UTC timestamp.');
    }
  }

  /// Validates raw ciphertext bytes.
  static void validateCiphertextBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Ciphertext cannot be empty.');
    }
  }

  /// Decodes and validates a Base64/Base64URL encoded ciphertext string.
  static Uint8List decodeCiphertext(String rawCiphertext) {
    final trimmed = rawCiphertext.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Ciphertext string cannot be empty or whitespace-only.');
    }
    try {
      final decoded = base64Decode(base64.normalize(trimmed));
      if (decoded.isEmpty) {
        throw const FormatException('Decoded ciphertext bytes cannot be empty.');
      }
      return decoded;
    } catch (e) {
      // Fallback attempt with Base64URL
      try {
        final decoded = base64Url.decode(base64Url.normalize(trimmed));
        if (decoded.isEmpty) {
          throw const FormatException('Decoded ciphertext bytes cannot be empty.');
        }
        return decoded;
      } catch (_) {
        throw FormatException('Malformed ciphertext: not a valid Base64 string ($e).');
      }
    }
  }

  /// Compares two byte lists for equality.
  static bool bytesEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Base interface for all MeshLink Phase 9 group wire packets.
abstract class GroupPacket {
  /// Packet type discriminator (e.g. `'group_invite'`).
  String get type;

  /// Wire protocol version (strictly 1).
  int get version;

  /// Target group identifier.
  String get groupId;

  /// Membership epoch bound to this packet.
  int get epoch;

  /// UTC timestamp of packet creation.
  DateTime get timestamp;

  /// Serializes packet to a Map for wire transmission.
  Map<String, dynamic> toMap();

  /// Serializes packet to JSON string.
  String toJson();

  /// Polymorphic deserializer for any supported Phase 9 group wire packet.
  ///
  /// Throws [FormatException] if the packet type is unknown, malformed,
  /// or validation fails.
  static GroupPacket fromMap(Map<String, dynamic> map) {
    final type = map['type'];
    if (type is! String) {
      throw const FormatException('Missing or invalid type discriminator for GroupPacket.');
    }
    switch (type) {
      case GroupInvitePacket.packetType:
        return GroupInvitePacket.fromMap(map);
      case GroupJoinAckPacket.packetType:
        return GroupJoinAckPacket.fromMap(map);
      case GroupMessagePacket.packetType:
        return GroupMessagePacket.fromMap(map);
      case GroupMemberRemovePacket.packetType:
        return GroupMemberRemovePacket.fromMap(map);
      default:
        throw FormatException('Unsupported or unknown GroupPacket type: "$type".');
    }
  }

  /// Deserializes a group packet from a JSON string.
  static GroupPacket fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for GroupPacket: expected Map.');
    }
    return GroupPacket.fromMap(decoded);
  }
}

/// Wire packet sent by a group administrator to invite a peer to join a group.
///
/// CRITICAL SECURITY NOTE:
/// An invitation requests membership; it DOES NOT activate membership.
/// The receiving peer must still explicitly perform manual acceptance.
/// Receiving or parsing this packet does not create active membership.
class GroupInvitePacket implements GroupPacket {
  GroupInvitePacket({
    this.version = currentProtocolVersion,
    required this.groupId,
    required String groupName,
    required this.adminId,
    required this.invitedPeerId,
    required this.epoch,
    required this.inviteId,
    required this.timestamp,
  }) : groupName = Group.validateAndSanitizeName(groupName) {
    if (version != currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected $currentProtocolVersion).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(adminId, 'adminId');
    Group.validatePeerId(invitedPeerId, 'invitedPeerId');
    GroupPacketValidator.validateEpoch(epoch);
    GroupPacketValidator.validateIdentifier(inviteId, 'inviteId');
    GroupPacketValidator.validateTimestamp(timestamp, 'timestamp');

    if (adminId == invitedPeerId) {
      throw ArgumentError('adminId and invitedPeerId cannot be identical (self-invitation).');
    }
  }

  /// Wire format packet discriminator.
  static const String packetType = 'group_invite';

  /// Wire protocol version for Phase 9 group packets.
  static const int currentProtocolVersion = 1;

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String groupId;

  /// Human-readable group name (1-64 chars).
  final String groupName;

  /// Peer ID of the inviting administrator.
  final String adminId;

  /// Peer ID of the recipient being invited.
  final String invitedPeerId;

  @override
  final int epoch;

  /// Unique identifier for this invitation message.
  final String inviteId;

  @override
  final DateTime timestamp;

  /// Alias for [adminId].
  String get inviterId => adminId;

  /// Alias for [invitedPeerId].
  String get inviteeId => invitedPeerId;

  /// Alias for [inviteId].
  String get messageId => inviteId;

  GroupInvitePacket copyWith({
    int? version,
    String? groupId,
    String? groupName,
    String? adminId,
    String? invitedPeerId,
    int? epoch,
    String? inviteId,
    DateTime? timestamp,
  }) {
    return GroupInvitePacket(
      version: version ?? this.version,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      adminId: adminId ?? this.adminId,
      invitedPeerId: invitedPeerId ?? this.invitedPeerId,
      epoch: epoch ?? this.epoch,
      inviteId: inviteId ?? this.inviteId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'version': version,
    'groupId': groupId,
    'groupName': groupName,
    'adminId': adminId,
    'invitedPeerId': invitedPeerId,
    'epoch': epoch,
    'inviteId': inviteId,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupInvitePacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected $currentProtocolVersion).',
      );
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawGroupName = map['groupName'];
    if (rawGroupName is! String) {
      throw const FormatException('Missing or invalid type for "groupName" (expected String).');
    }

    final rawAdminId = map['adminId'] ?? map['inviterId'];
    if (rawAdminId is! String) {
      throw const FormatException('Missing or invalid type for "adminId" (expected String).');
    }

    final rawInvitedPeerId = map['invitedPeerId'] ?? map['inviteeId'];
    if (rawInvitedPeerId is! String) {
      throw const FormatException('Missing or invalid type for "invitedPeerId" (expected String).');
    }

    final rawEpoch = map['epoch'];
    if (rawEpoch is! int) {
      throw const FormatException('Missing or invalid type for "epoch" (expected int).');
    }

    final rawInviteId = map['inviteId'] ?? map['messageId'];
    if (rawInviteId is! String) {
      throw const FormatException('Missing or invalid type for "inviteId" (expected String).');
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupInvitePacket JSON.');
    }

    try {
      return GroupInvitePacket(
        version: rawVersion,
        groupId: rawGroupId,
        groupName: rawGroupName,
        adminId: rawAdminId,
        invitedPeerId: rawInvitedPeerId,
        epoch: rawEpoch,
        inviteId: rawInviteId,
        timestamp: parsedTimestamp,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Failed to deserialize GroupInvitePacket: ${e.message}');
    }
  }

  factory GroupInvitePacket.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for GroupInvitePacket: expected Map.');
    }
    return GroupInvitePacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupInvitePacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          adminId == other.adminId &&
          invitedPeerId == other.invitedPeerId &&
          epoch == other.epoch &&
          inviteId == other.inviteId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    version,
    groupId,
    groupName,
    adminId,
    invitedPeerId,
    epoch,
    inviteId,
    timestamp,
  );

  @override
  String toString() =>
      'GroupInvitePacket(group: $groupId, admin: $adminId, invited: $invitedPeerId, epoch: $epoch)';
}

/// Wire packet sent by an invited peer acknowledging acceptance of a group invitation.
///
/// CRITICAL SECURITY NOTE:
/// This packet represents an unverified acceptance acknowledgement over the wire.
/// Successfully parsing or receiving a [GroupJoinAckPacket] DOES NOT:
/// 1. Prove authenticated peer identity merely because it parses.
/// 2. Automatically bypass manual acceptance on the receiving side or activate membership.
///
/// The recipient MUST verify peer authentication via existing authenticated sessions
/// before transitioning [GroupMemberStatus] to active.
class GroupJoinAckPacket implements GroupPacket {
  GroupJoinAckPacket({
    this.version = currentProtocolVersion,
    required this.groupId,
    required this.ackPeerId,
    required this.adminId,
    required this.epoch,
    required this.ackId,
    required this.timestamp,
  }) {
    if (version != currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected $currentProtocolVersion).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(ackPeerId, 'ackPeerId');
    Group.validatePeerId(adminId, 'adminId');
    GroupPacketValidator.validateEpoch(epoch);
    GroupPacketValidator.validateIdentifier(ackId, 'ackId');
    GroupPacketValidator.validateTimestamp(timestamp, 'timestamp');

    if (ackPeerId == adminId) {
      throw ArgumentError('ackPeerId and adminId cannot be identical.');
    }
  }

  /// Wire format packet discriminator.
  static const String packetType = 'group_join_ack';

  /// Wire protocol version for Phase 9 group packets.
  static const int currentProtocolVersion = 1;

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String groupId;

  /// Peer ID of the acknowledging invited peer.
  final String ackPeerId;

  /// Peer ID of the inviting administrator.
  final String adminId;

  @override
  final int epoch;

  /// Unique identifier for this acknowledgement packet.
  final String ackId;

  @override
  final DateTime timestamp;

  /// Alias for [ackPeerId].
  String get peerId => ackPeerId;

  /// Alias for [adminId].
  String get inviterId => adminId;

  /// Alias for [ackId].
  String get messageId => ackId;

  GroupJoinAckPacket copyWith({
    int? version,
    String? groupId,
    String? ackPeerId,
    String? adminId,
    int? epoch,
    String? ackId,
    DateTime? timestamp,
  }) {
    return GroupJoinAckPacket(
      version: version ?? this.version,
      groupId: groupId ?? this.groupId,
      ackPeerId: ackPeerId ?? this.ackPeerId,
      adminId: adminId ?? this.adminId,
      epoch: epoch ?? this.epoch,
      ackId: ackId ?? this.ackId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'version': version,
    'groupId': groupId,
    'ackPeerId': ackPeerId,
    'adminId': adminId,
    'epoch': epoch,
    'ackId': ackId,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupJoinAckPacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected $currentProtocolVersion).',
      );
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawAckPeerId = map['ackPeerId'] ?? map['peerId'];
    if (rawAckPeerId is! String) {
      throw const FormatException('Missing or invalid type for "ackPeerId" (expected String).');
    }

    final rawAdminId = map['adminId'] ?? map['inviterId'];
    if (rawAdminId is! String) {
      throw const FormatException('Missing or invalid type for "adminId" (expected String).');
    }

    final rawEpoch = map['epoch'];
    if (rawEpoch is! int) {
      throw const FormatException('Missing or invalid type for "epoch" (expected int).');
    }

    final rawAckId = map['ackId'] ?? map['messageId'];
    if (rawAckId is! String) {
      throw const FormatException('Missing or invalid type for "ackId" (expected String).');
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupJoinAckPacket JSON.');
    }

    try {
      return GroupJoinAckPacket(
        version: rawVersion,
        groupId: rawGroupId,
        ackPeerId: rawAckPeerId,
        adminId: rawAdminId,
        epoch: rawEpoch,
        ackId: rawAckId,
        timestamp: parsedTimestamp,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Failed to deserialize GroupJoinAckPacket: ${e.message}');
    }
  }

  factory GroupJoinAckPacket.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for GroupJoinAckPacket: expected Map.');
    }
    return GroupJoinAckPacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupJoinAckPacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          groupId == other.groupId &&
          ackPeerId == other.ackPeerId &&
          adminId == other.adminId &&
          epoch == other.epoch &&
          ackId == other.ackId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    version,
    groupId,
    ackPeerId,
    adminId,
    epoch,
    ackId,
    timestamp,
  );

  @override
  String toString() =>
      'GroupJoinAckPacket(group: $groupId, ackPeer: $ackPeerId, admin: $adminId, epoch: $epoch)';
}

/// Wire packet representing the group-level envelope needed for pairwise sender fan-out.
///
/// Phase 9 Step 2: Validated Wire Packet Models
///
/// Cryptographic Protocol Rules:
/// - Represents ciphertext only; NEVER stores or serializes a plaintext `text` field.
/// - Deserialization rejects any incoming payload containing a plaintext `text` field.
/// - Encrypted separately for each recipient peer via existing authenticated pairwise sessions.
/// - Does NOT use a group-wide shared symmetric key.
class GroupMessagePacket implements GroupPacket {
  GroupMessagePacket({
    this.version = currentProtocolVersion,
    required this.groupId,
    required this.messageId,
    required this.senderPeerId,
    required this.epoch,
    required this.timestamp,
    required List<int> ciphertext,
  }) : ciphertext = Uint8List.fromList(ciphertext) {
    if (version != currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected $currentProtocolVersion).',
      );
    }
    Group.validateGroupId(groupId);
    GroupPacketValidator.validateIdentifier(messageId, 'messageId');
    Group.validatePeerId(senderPeerId, 'senderPeerId');
    GroupPacketValidator.validateEpoch(epoch);
    GroupPacketValidator.validateTimestamp(timestamp, 'timestamp');
    GroupPacketValidator.validateCiphertextBytes(ciphertext);
  }

  /// Wire format packet discriminator.
  static const String packetType = 'group_message';

  /// Wire protocol version for Phase 9 group packets.
  static const int currentProtocolVersion = 1;

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String groupId;

  /// Unique message identifier.
  final String messageId;

  /// Peer ID of the sending member.
  final String senderPeerId;

  @override
  final int epoch;

  @override
  final DateTime timestamp;

  /// Authenticated ciphertext bytes encrypted under pairwise recipient session.
  ///
  /// Never plaintext.
  final Uint8List ciphertext;

  /// Alias for [senderPeerId].
  String get senderId => senderPeerId;

  /// Alias for [ciphertext].
  Uint8List get encryptedPayload => ciphertext;

  GroupMessagePacket copyWith({
    int? version,
    String? groupId,
    String? messageId,
    String? senderPeerId,
    int? epoch,
    DateTime? timestamp,
    List<int>? ciphertext,
  }) {
    return GroupMessagePacket(
      version: version ?? this.version,
      groupId: groupId ?? this.groupId,
      messageId: messageId ?? this.messageId,
      senderPeerId: senderPeerId ?? this.senderPeerId,
      epoch: epoch ?? this.epoch,
      timestamp: timestamp ?? this.timestamp,
      ciphertext: ciphertext ?? this.ciphertext,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'version': version,
    'groupId': groupId,
    'messageId': messageId,
    'senderPeerId': senderPeerId,
    'epoch': epoch,
    'timestamp': timestamp.toIso8601String(),
    'ciphertext': base64Encode(ciphertext),
  };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupMessagePacket.fromMap(Map<String, dynamic> map) {
    // Strictly forbid plaintext 'text' field to prevent security regressions.
    if (map.containsKey('text')) {
      throw const FormatException(
        'Plaintext "text" field is strictly forbidden in GroupMessagePacket. '
        'Messages must only be transmitted as authenticated ciphertext.',
      );
    }

    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected $currentProtocolVersion).',
      );
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawMessageId = map['messageId'];
    if (rawMessageId is! String) {
      throw const FormatException('Missing or invalid type for "messageId" (expected String).');
    }

    final rawSenderPeerId = map['senderPeerId'] ?? map['senderId'];
    if (rawSenderPeerId is! String) {
      throw const FormatException('Missing or invalid type for "senderPeerId" (expected String).');
    }

    final rawEpoch = map['epoch'];
    if (rawEpoch is! int) {
      throw const FormatException('Missing or invalid type for "epoch" (expected int).');
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupMessagePacket JSON.');
    }

    final rawCiphertext = map['ciphertext'] ?? map['encryptedPayload'];
    if (rawCiphertext is! String) {
      throw const FormatException('Missing or invalid type for "ciphertext" (expected Base64 String).');
    }

    final decodedCiphertext = GroupPacketValidator.decodeCiphertext(rawCiphertext);

    try {
      return GroupMessagePacket(
        version: rawVersion,
        groupId: rawGroupId,
        messageId: rawMessageId,
        senderPeerId: rawSenderPeerId,
        epoch: rawEpoch,
        timestamp: parsedTimestamp,
        ciphertext: decodedCiphertext,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Failed to deserialize GroupMessagePacket: ${e.message}');
    }
  }

  factory GroupMessagePacket.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for GroupMessagePacket: expected Map.');
    }
    return GroupMessagePacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMessagePacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          groupId == other.groupId &&
          messageId == other.messageId &&
          senderPeerId == other.senderPeerId &&
          epoch == other.epoch &&
          timestamp == other.timestamp &&
          GroupPacketValidator.bytesEqual(ciphertext, other.ciphertext);

  @override
  int get hashCode => Object.hash(
    version,
    groupId,
    messageId,
    senderPeerId,
    epoch,
    timestamp,
    Object.hashAll(ciphertext),
  );

  @override
  String toString() =>
      'GroupMessagePacket(group: $groupId, messageId: $messageId, sender: $senderPeerId, bytes: ${ciphertext.length})';
}

/// Wire packet sent by an administrator to remove a member from a group.
///
/// CRITICAL SECURITY NOTE:
/// This packet represents only a claimed removal request over the wire.
/// Successfully parsing or receiving a [GroupMemberRemovePacket] DOES NOT:
/// 1. Prove that the [adminId] is authenticated or cryptographically verified.
/// 2. Authorize the removal of the member.
/// 3. Mutate or remove any [GroupMember] in local storage.
///
/// Authorization and membership mutation must be explicitly validated by the
/// membership governance service in subsequent pipeline stages after verifying
/// peer signatures, admin role, and epoch consistency.
class GroupMemberRemovePacket implements GroupPacket {
  GroupMemberRemovePacket({
    this.version = currentProtocolVersion,
    required this.groupId,
    required this.targetPeerId,
    required this.adminId,
    required this.epoch,
    required this.removeId,
    required this.timestamp,
  }) {
    if (version != currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected $currentProtocolVersion).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(targetPeerId, 'targetPeerId');
    Group.validatePeerId(adminId, 'adminId');
    GroupPacketValidator.validateEpoch(epoch);
    GroupPacketValidator.validateIdentifier(removeId, 'removeId');
    GroupPacketValidator.validateTimestamp(timestamp, 'timestamp');

    if (targetPeerId == adminId) {
      throw ArgumentError(
        'adminId and targetPeerId cannot be identical in removal packet '
        '(admin removal of self must be handled via explicit departure).',
      );
    }
  }

  /// Wire format packet discriminator.
  static const String packetType = 'group_member_remove';

  /// Wire protocol version for Phase 9 group packets.
  static const int currentProtocolVersion = 1;

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String groupId;

  /// Peer ID of the member being removed.
  final String targetPeerId;

  /// Peer ID of the administrator requesting removal.
  final String adminId;

  @override
  final int epoch;

  /// Unique identifier for this removal request.
  final String removeId;

  @override
  final DateTime timestamp;

  /// Alias for [targetPeerId].
  String get targetId => targetPeerId;

  /// Alias for [adminId].
  String get requestingAdminId => adminId;

  /// Alias for [removeId].
  String get messageId => removeId;

  GroupMemberRemovePacket copyWith({
    int? version,
    String? groupId,
    String? targetPeerId,
    String? adminId,
    int? epoch,
    String? removeId,
    DateTime? timestamp,
  }) {
    return GroupMemberRemovePacket(
      version: version ?? this.version,
      groupId: groupId ?? this.groupId,
      targetPeerId: targetPeerId ?? this.targetPeerId,
      adminId: adminId ?? this.adminId,
      epoch: epoch ?? this.epoch,
      removeId: removeId ?? this.removeId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': type,
    'version': version,
    'groupId': groupId,
    'targetPeerId': targetPeerId,
    'adminId': adminId,
    'epoch': epoch,
    'removeId': removeId,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupMemberRemovePacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected $currentProtocolVersion).',
      );
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawTargetPeerId = map['targetPeerId'] ?? map['targetId'];
    if (rawTargetPeerId is! String) {
      throw const FormatException('Missing or invalid type for "targetPeerId" (expected String).');
    }

    final rawAdminId = map['adminId'] ?? map['requestingAdminId'];
    if (rawAdminId is! String) {
      throw const FormatException('Missing or invalid type for "adminId" (expected String).');
    }

    final rawEpoch = map['epoch'];
    if (rawEpoch is! int) {
      throw const FormatException('Missing or invalid type for "epoch" (expected int).');
    }

    final rawRemoveId = map['removeId'] ?? map['messageId'];
    if (rawRemoveId is! String) {
      throw const FormatException('Missing or invalid type for "removeId" (expected String).');
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupMemberRemovePacket JSON.');
    }

    try {
      return GroupMemberRemovePacket(
        version: rawVersion,
        groupId: rawGroupId,
        targetPeerId: rawTargetPeerId,
        adminId: rawAdminId,
        epoch: rawEpoch,
        removeId: rawRemoveId,
        timestamp: parsedTimestamp,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Failed to deserialize GroupMemberRemovePacket: ${e.message}');
    }
  }

  factory GroupMemberRemovePacket.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for GroupMemberRemovePacket: expected Map.');
    }
    return GroupMemberRemovePacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMemberRemovePacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          groupId == other.groupId &&
          targetPeerId == other.targetPeerId &&
          adminId == other.adminId &&
          epoch == other.epoch &&
          removeId == other.removeId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    version,
    groupId,
    targetPeerId,
    adminId,
    epoch,
    removeId,
    timestamp,
  );

  @override
  String toString() =>
      'GroupMemberRemovePacket(group: $groupId, target: $targetPeerId, admin: $adminId, epoch: $epoch)';
}
