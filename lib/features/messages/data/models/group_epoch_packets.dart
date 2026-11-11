import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meshlink/features/messages/domain/models/group.dart';

/// Acknowledgement status for per-member re-epoch protocol stages (prepare, commit, finalize).
enum GroupEpochAckStatus {
  /// The member has not yet acknowledged the operation stage.
  pending,

  /// The member has successfully prepared/committed/finalized the epoch update.
  acknowledged,

  /// The member encountered an error and failed to apply the epoch update.
  failed;

  /// Serializes the status to its wire JSON string name.
  String toJson() => name;

  /// Parses an acknowledgement status strictly from a string.
  ///
  /// Throws [ArgumentError] if the value is unrecognized.
  static GroupEpochAckStatus fromString(String value) {
    switch (value.trim()) {
      case 'pending':
        return GroupEpochAckStatus.pending;
      case 'acknowledged':
        return GroupEpochAckStatus.acknowledged;
      case 'failed':
        return GroupEpochAckStatus.failed;
      default:
        throw ArgumentError(
          'Invalid GroupEpochAckStatus: "$value". Allowed values: [pending, acknowledged, failed].',
        );
    }
  }

  /// Parses status safely, returning null if invalid or null.
  static GroupEpochAckStatus? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }
}

/// Lifecycle status of an administrative re-epoch operation.
enum GroupEpochOperationStatus {
  /// Administrator is gathering prepare acknowledgements from active group members.
  preparing,

  /// Administrator has committed the epoch advancement locally and is propagating commit packets.
  committing,

  /// All required members have committed; administrator is issuing finalize packets.
  finalizing,

  /// Operation is fully finalized and all members are un-frozen.
  finalized,

  /// Operation was abandoned or superseded by a higher sequence number.
  superseded;

  /// Serializes the status to its wire JSON string name.
  String toJson() => name;

  /// Parses an operation status strictly from a string.
  ///
  /// Throws [ArgumentError] if the value is unrecognized.
  static GroupEpochOperationStatus fromString(String value) {
    switch (value.trim()) {
      case 'preparing':
        return GroupEpochOperationStatus.preparing;
      case 'committing':
        return GroupEpochOperationStatus.committing;
      case 'finalizing':
        return GroupEpochOperationStatus.finalizing;
      case 'finalized':
        return GroupEpochOperationStatus.finalized;
      case 'superseded':
        return GroupEpochOperationStatus.superseded;
      default:
        throw ArgumentError(
          'Invalid GroupEpochOperationStatus: "$value". '
          'Allowed values: [preparing, committing, finalizing, finalized, superseded].',
        );
    }
  }

  /// Parses status safely, returning null if invalid or null.
  static GroupEpochOperationStatus? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }
}

/// Validation utilities and protocol constants for re-epoch wire packets.
class GroupEpochValidator {
  /// Current wire protocol version for re-epoch packets.
  static const int currentProtocolVersion = 1;

  /// Regex enforcing exactly 32 hexadecimal characters (128-bit random identifier).
  static final RegExp _operationIdRegex = RegExp(r'^[0-9a-fA-F]{32}$');

  /// Validates and normalizes [operationId] to lower-case.
  ///
  /// Throws [ArgumentError] if [operationId] is not exactly 32 hexadecimal characters.
  static String validateAndNormalizeOperationId(
    String operationId, [
    String fieldName = 'operationId',
  ]) {
    if (operationId.isEmpty) {
      throw ArgumentError('$fieldName cannot be empty.');
    }
    if (operationId.trim() != operationId) {
      throw ArgumentError('$fieldName must not contain leading or trailing whitespace.');
    }
    if (!_operationIdRegex.hasMatch(operationId)) {
      throw ArgumentError(
        'Invalid $fieldName format: "$operationId". Expected exactly 32 hexadecimal characters (128-bit).',
      );
    }
    return operationId.toLowerCase();
  }

  /// Validates that an epoch is an integer >= 1.
  static void validateEpoch(int epoch, [String fieldName = 'epoch']) {
    if (epoch < 1) {
      throw ArgumentError('$fieldName must be a positive integer >= 1 (got $epoch).');
    }
  }

  /// Validates progression where [targetEpoch] must be strictly greater than [previousEpoch].
  static void validateEpochProgression(int previousEpoch, int targetEpoch) {
    validateEpoch(previousEpoch, 'previousEpoch');
    validateEpoch(targetEpoch, 'targetEpoch');
    if (targetEpoch <= previousEpoch) {
      throw ArgumentError(
        'targetEpoch ($targetEpoch) must be strictly greater than previousEpoch ($previousEpoch).',
      );
    }
  }

  /// Validates that [sequenceNumber] is a positive integer >= 1.
  static void validateSequenceNumber(
    int sequenceNumber, [
    String fieldName = 'sequenceNumber',
  ]) {
    if (sequenceNumber < 1) {
      throw ArgumentError('$fieldName must be a positive integer >= 1 (got $sequenceNumber).');
    }
  }

  /// Validates that [sequenceNumber] is a non-negative integer >= 0 (used for probes/reconciliation).
  static void validateNonNegativeSequenceNumber(
    int sequenceNumber, [
    String fieldName = 'sequenceNumber',
  ]) {
    if (sequenceNumber < 0) {
      throw ArgumentError('$fieldName must be a non-negative integer >= 0 (got $sequenceNumber).');
    }
  }

  /// Validates that [timestamp] is non-null and represents a valid UTC DateTime.
  static void validateTimestamp(DateTime timestamp, [String fieldName = 'timestamp']) {
    if (!timestamp.isUtc) {
      throw ArgumentError('$fieldName must represent a valid UTC timestamp.');
    }
  }
}

/// Deterministic canonical operation payload for re-epoch operations.
///
/// Provides a stable, order-independent representation of the administrative operation
/// that will be signed by the group administrator's Ed25519 identity in future steps.
class GroupEpochCanonicalPayload {
  GroupEpochCanonicalPayload({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required this.packetType,
    required String operationId,
    required this.groupId,
    required this.previousEpoch,
    required this.targetEpoch,
    required this.operationSequenceNumber,
    required this.adminPeerId,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported protocol version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    if (packetType.isEmpty || packetType.trim() != packetType) {
      throw ArgumentError('packetType cannot be empty or contain whitespace.');
    }
    Group.validateGroupId(groupId);
    GroupEpochValidator.validateEpochProgression(previousEpoch, targetEpoch);
    GroupEpochValidator.validateSequenceNumber(operationSequenceNumber, 'operationSequenceNumber');
    Group.validatePeerId(adminPeerId, 'adminPeerId');
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  /// Wire protocol version.
  final int version;

  /// Packet type discriminator (e.g. `'group_epoch_prepare'`).
  final String packetType;

  /// Normalized 32-hex operation identifier.
  final String operationId;

  /// Target group identifier.
  final String groupId;

  /// Epoch prior to re-epoching.
  final int previousEpoch;

  /// Target epoch advancement.
  final int targetEpoch;

  /// Monotonically increasing operation sequence number.
  final int operationSequenceNumber;

  /// Peer identifier of group administrator.
  final String adminPeerId;

  /// UTC creation timestamp.
  final DateTime timestamp;

  /// Returns a sorted Map with strictly lexicographical key order.
  Map<String, dynamic> toSortedMap() {
    return SplayTreeMap<String, dynamic>()
      ..addAll({
        'adminPeerId': adminPeerId,
        'groupId': groupId,
        'operationId': operationId,
        'operationSequenceNumber': operationSequenceNumber,
        'packetType': packetType,
        'previousEpoch': previousEpoch,
        'targetEpoch': targetEpoch,
        'timestamp': timestamp.toIso8601String(),
        'version': version,
      });
  }

  /// Deterministic UTF-8 encoded JSON string without arbitrary whitespace.
  String serialize() => jsonEncode(toSortedMap());

  /// Deterministic binary bytes for future cryptographic signing.
  Uint8List get bytes => Uint8List.fromList(utf8.encode(serialize()));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochCanonicalPayload &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          packetType == other.packetType &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          previousEpoch == other.previousEpoch &&
          targetEpoch == other.targetEpoch &&
          operationSequenceNumber == other.operationSequenceNumber &&
          adminPeerId == other.adminPeerId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    version,
    packetType,
    operationId,
    groupId,
    previousEpoch,
    targetEpoch,
    operationSequenceNumber,
    adminPeerId,
    timestamp,
  );
}

/// Base interface for all MeshLink Phase 9 Step 6.2 re-epoch wire packets.
abstract class GroupEpochPacket {
  /// Wire packet type discriminator.
  String get type;

  /// Wire protocol version.
  int get version;

  /// Unique 32-hexadecimal operation identifier.
  String get operationId;

  /// Target group identifier.
  String get groupId;

  /// UTC creation timestamp.
  DateTime get timestamp;

  /// Serializes packet to Map for wire transmission.
  Map<String, dynamic> toMap();

  /// Serializes packet to JSON string.
  String toJson();

  /// Polymorphic deserializer for any supported Phase 9 re-epoch wire packet.
  ///
  /// Throws [FormatException] if the packet type is unknown, malformed, or fails validation.
  static GroupEpochPacket fromMap(Map<String, dynamic> map) {
    final type = map['type'];
    if (type is! String) {
      throw const FormatException('Missing or invalid type discriminator for GroupEpochPacket.');
    }
    switch (type) {
      case GroupEpochPreparePacket.packetType:
        return GroupEpochPreparePacket.fromMap(map);
      case GroupEpochPrepareAckPacket.packetType:
        return GroupEpochPrepareAckPacket.fromMap(map);
      case GroupEpochCommitPacket.packetType:
        return GroupEpochCommitPacket.fromMap(map);
      case GroupEpochCommitAckPacket.packetType:
        return GroupEpochCommitAckPacket.fromMap(map);
      case GroupEpochFinalizePacket.packetType:
        return GroupEpochFinalizePacket.fromMap(map);
      case GroupEpochFinalizeAckPacket.packetType:
        return GroupEpochFinalizeAckPacket.fromMap(map);
      case GroupEpochStatusProbePacket.packetType:
        return GroupEpochStatusProbePacket.fromMap(map);
      case GroupEpochStatusResponsePacket.packetType:
        return GroupEpochStatusResponsePacket.fromMap(map);
      default:
        throw FormatException('Unsupported or unknown GroupEpochPacket type: "$type".');
    }
  }

  /// Deserializes a re-epoch packet from a JSON string.
  static GroupEpochPacket fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochPacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON payload for GroupEpochPacket: expected Map.');
    }
    return GroupEpochPacket.fromMap(decoded);
  }
}

// =============================================================================
// A. Prepare Packet
// =============================================================================

/// Phase 1 Prepare packet sent by group administrator to initiate a re-epoch operation.
///
/// Instructs active group members to freeze outbound new-message generation and enter
/// the prepared state for [targetEpoch].
class GroupEpochPreparePacket implements GroupEpochPacket {
  GroupEpochPreparePacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.previousEpoch,
    required this.targetEpoch,
    required this.operationSequenceNumber,
    required this.adminPeerId,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    GroupEpochValidator.validateEpochProgression(previousEpoch, targetEpoch);
    GroupEpochValidator.validateSequenceNumber(operationSequenceNumber, 'operationSequenceNumber');
    Group.validatePeerId(adminPeerId, 'adminPeerId');
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  static const String packetType = 'group_epoch_prepare';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Current epoch prior to re-epoching.
  final int previousEpoch;

  /// Target epoch advancement.
  final int targetEpoch;

  /// Monotonically increasing sequence number for this group's operations.
  final int operationSequenceNumber;

  /// Peer identifier of group administrator.
  final String adminPeerId;

  @override
  final DateTime timestamp;

  /// Convenience alias for [timestamp].
  DateTime get createdAt => timestamp;

  /// Convenience alias for [adminPeerId].
  String get adminId => adminPeerId;

  /// Convenience alias for [operationSequenceNumber].
  int get sequenceNumber => operationSequenceNumber;

  /// Canonical operation payload object for cryptographic verification.
  GroupEpochCanonicalPayload get canonicalPayloadObj => GroupEpochCanonicalPayload(
        version: version,
        packetType: packetType,
        operationId: operationId,
        groupId: groupId,
        previousEpoch: previousEpoch,
        targetEpoch: targetEpoch,
        operationSequenceNumber: operationSequenceNumber,
        adminPeerId: adminPeerId,
        timestamp: timestamp,
      );

  /// Deterministic canonical operation payload serialized as a sorted-key JSON string.
  String get canonicalPayload => canonicalPayloadObj.serialize();

  /// Deterministic binary representation of the canonical operation payload.
  Uint8List get canonicalPayloadBytes => canonicalPayloadObj.bytes;

  GroupEpochPreparePacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    int? previousEpoch,
    int? targetEpoch,
    int? operationSequenceNumber,
    String? adminPeerId,
    DateTime? timestamp,
  }) {
    return GroupEpochPreparePacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      previousEpoch: previousEpoch ?? this.previousEpoch,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      operationSequenceNumber: operationSequenceNumber ?? this.operationSequenceNumber,
      adminPeerId: adminPeerId ?? this.adminPeerId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'version': version,
        'operationId': operationId,
        'groupId': groupId,
        'previousEpoch': previousEpoch,
        'targetEpoch': targetEpoch,
        'operationSequenceNumber': operationSequenceNumber,
        'adminPeerId': adminPeerId,
        'timestamp': timestamp.toIso8601String(),
        'canonicalPayload': canonicalPayload,
      };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochPreparePacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawPreviousEpoch = map['previousEpoch'];
    if (rawPreviousEpoch is! int) {
      throw const FormatException('Missing or invalid type for "previousEpoch" (expected int).');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch" (expected int).');
    }

    final rawSequenceNumber = map['operationSequenceNumber'] ?? map['sequenceNumber'];
    if (rawSequenceNumber is! int) {
      throw const FormatException(
        'Missing or invalid type for "operationSequenceNumber" (expected int).',
      );
    }

    final rawAdminPeerId = map['adminPeerId'] ?? map['adminId'];
    if (rawAdminPeerId is! String) {
      throw const FormatException('Missing or invalid type for "adminPeerId" (expected String).');
    }

    final rawTimestamp = map['timestamp'] ?? map['createdAt'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupEpochPreparePacket.');
    }

    final packet = GroupEpochPreparePacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      previousEpoch: rawPreviousEpoch,
      targetEpoch: rawTargetEpoch,
      operationSequenceNumber: rawSequenceNumber,
      adminPeerId: rawAdminPeerId,
      timestamp: parsedTimestamp,
    );

    // If wire payload included canonicalPayload, ensure it matches computed canonical representation
    final rawCanonical = map['canonicalPayload'];
    if (rawCanonical != null) {
      if (rawCanonical is! String || rawCanonical != packet.canonicalPayload) {
        throw const FormatException(
          'canonicalPayload mismatch: wire payload does not match computed canonical payload.',
        );
      }
    }

    return packet;
  }

  factory GroupEpochPreparePacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochPreparePacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochPreparePacket: expected Map.');
    }
    return GroupEpochPreparePacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochPreparePacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          previousEpoch == other.previousEpoch &&
          targetEpoch == other.targetEpoch &&
          operationSequenceNumber == other.operationSequenceNumber &&
          adminPeerId == other.adminPeerId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        previousEpoch,
        targetEpoch,
        operationSequenceNumber,
        adminPeerId,
        timestamp,
      );

  @override
  String toString() =>
      'GroupEpochPreparePacket(opId: $operationId, group: $groupId, epochs: $previousEpoch->$targetEpoch, seq: $operationSequenceNumber)';
}

// =============================================================================
// B. Prepare Acknowledgement Packet
// =============================================================================

/// Phase 1 Prepare acknowledgement packet returned by an active group member.
class GroupEpochPrepareAckPacket implements GroupEpochPacket {
  GroupEpochPrepareAckPacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.memberPeerId,
    required this.targetEpoch,
    required this.status,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(memberPeerId, 'memberPeerId');
    GroupEpochValidator.validateEpoch(targetEpoch, 'targetEpoch');
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  static const String packetType = 'group_epoch_prepare_ack';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Peer identifier of acknowledging member.
  final String memberPeerId;

  /// Target epoch prepared by the member.
  final int targetEpoch;

  /// Acknowledgement status (pending, acknowledged, failed).
  final GroupEpochAckStatus status;

  @override
  final DateTime timestamp;

  /// Alias for [status].
  GroupEpochAckStatus get acknowledgementStatus => status;

  GroupEpochPrepareAckPacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    String? memberPeerId,
    int? targetEpoch,
    GroupEpochAckStatus? status,
    DateTime? timestamp,
  }) {
    return GroupEpochPrepareAckPacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      memberPeerId: memberPeerId ?? this.memberPeerId,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'version': version,
        'operationId': operationId,
        'groupId': groupId,
        'memberPeerId': memberPeerId,
        'targetEpoch': targetEpoch,
        'status': status.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochPrepareAckPacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawMemberPeerId = map['memberPeerId'] ?? map['memberId'];
    if (rawMemberPeerId is! String) {
      throw const FormatException('Missing or invalid type for "memberPeerId" (expected String).');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch" (expected int).');
    }

    final rawStatus = map['status'] ?? map['acknowledgementStatus'];
    if (rawStatus is! String) {
      throw const FormatException('Missing or invalid type for "status" (expected String).');
    }

    final GroupEpochAckStatus ackStatus;
    try {
      ackStatus = GroupEpochAckStatus.fromString(rawStatus);
    } on ArgumentError catch (e) {
      throw FormatException(e.message);
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupEpochPrepareAckPacket.');
    }

    return GroupEpochPrepareAckPacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      memberPeerId: rawMemberPeerId,
      targetEpoch: rawTargetEpoch,
      status: ackStatus,
      timestamp: parsedTimestamp,
    );
  }

  factory GroupEpochPrepareAckPacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochPrepareAckPacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochPrepareAckPacket: expected Map.');
    }
    return GroupEpochPrepareAckPacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochPrepareAckPacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          memberPeerId == other.memberPeerId &&
          targetEpoch == other.targetEpoch &&
          status == other.status &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        memberPeerId,
        targetEpoch,
        status,
        timestamp,
      );

  @override
  String toString() =>
      'GroupEpochPrepareAckPacket(opId: $operationId, member: $memberPeerId, targetEpoch: $targetEpoch, status: $status)';
}

// =============================================================================
// C. Commit Packet
// =============================================================================

/// Phase 2 Commit packet sent by group administrator after all active members prepare.
///
/// Instructs group members to advance their local epoch from [previousEpoch] to [targetEpoch].
class GroupEpochCommitPacket implements GroupEpochPacket {
  GroupEpochCommitPacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.previousEpoch,
    required this.targetEpoch,
    required this.sequenceNumber,
    required this.adminPeerId,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    GroupEpochValidator.validateEpochProgression(previousEpoch, targetEpoch);
    GroupEpochValidator.validateSequenceNumber(sequenceNumber, 'sequenceNumber');
    Group.validatePeerId(adminPeerId, 'adminPeerId');
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  static const String packetType = 'group_epoch_commit';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Epoch prior to re-epoching.
  final int previousEpoch;

  /// Target epoch advancement.
  final int targetEpoch;

  /// Monotonically increasing sequence number.
  final int sequenceNumber;

  /// Peer identifier of group administrator.
  final String adminPeerId;

  @override
  final DateTime timestamp;

  /// Convenience alias for [adminPeerId].
  String get adminId => adminPeerId;

  /// Convenience alias for [sequenceNumber].
  int get operationSequenceNumber => sequenceNumber;

  GroupEpochCommitPacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    int? previousEpoch,
    int? targetEpoch,
    int? sequenceNumber,
    String? adminPeerId,
    DateTime? timestamp,
  }) {
    return GroupEpochCommitPacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      previousEpoch: previousEpoch ?? this.previousEpoch,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      adminPeerId: adminPeerId ?? this.adminPeerId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'version': version,
        'operationId': operationId,
        'groupId': groupId,
        'previousEpoch': previousEpoch,
        'targetEpoch': targetEpoch,
        'sequenceNumber': sequenceNumber,
        'adminPeerId': adminPeerId,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochCommitPacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawPreviousEpoch = map['previousEpoch'];
    if (rawPreviousEpoch is! int) {
      throw const FormatException('Missing or invalid type for "previousEpoch" (expected int).');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch" (expected int).');
    }

    final rawSequenceNumber = map['sequenceNumber'] ?? map['operationSequenceNumber'];
    if (rawSequenceNumber is! int) {
      throw const FormatException('Missing or invalid type for "sequenceNumber" (expected int).');
    }

    final rawAdminPeerId = map['adminPeerId'] ?? map['adminId'];
    if (rawAdminPeerId is! String) {
      throw const FormatException('Missing or invalid type for "adminPeerId" (expected String).');
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupEpochCommitPacket.');
    }

    return GroupEpochCommitPacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      previousEpoch: rawPreviousEpoch,
      targetEpoch: rawTargetEpoch,
      sequenceNumber: rawSequenceNumber,
      adminPeerId: rawAdminPeerId,
      timestamp: parsedTimestamp,
    );
  }

  factory GroupEpochCommitPacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochCommitPacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochCommitPacket: expected Map.');
    }
    return GroupEpochCommitPacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochCommitPacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          previousEpoch == other.previousEpoch &&
          targetEpoch == other.targetEpoch &&
          sequenceNumber == other.sequenceNumber &&
          adminPeerId == other.adminPeerId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        previousEpoch,
        targetEpoch,
        sequenceNumber,
        adminPeerId,
        timestamp,
      );

  @override
  String toString() =>
      'GroupEpochCommitPacket(opId: $operationId, group: $groupId, epochs: $previousEpoch->$targetEpoch, seq: $sequenceNumber)';
}

// =============================================================================
// D. Commit Acknowledgement Packet
// =============================================================================

/// Phase 2 Commit acknowledgement packet returned by an active group member.
class GroupEpochCommitAckPacket implements GroupEpochPacket {
  GroupEpochCommitAckPacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.memberPeerId,
    required this.targetEpoch,
    required this.status,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(memberPeerId, 'memberPeerId');
    GroupEpochValidator.validateEpoch(targetEpoch, 'targetEpoch');
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  static const String packetType = 'group_epoch_commit_ack';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Peer identifier of acknowledging member.
  final String memberPeerId;

  /// Target epoch committed by member.
  final int targetEpoch;

  /// Acknowledgement status (pending, acknowledged, failed).
  final GroupEpochAckStatus status;

  @override
  final DateTime timestamp;

  /// Alias for [status].
  GroupEpochAckStatus get acknowledgementStatus => status;

  GroupEpochCommitAckPacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    String? memberPeerId,
    int? targetEpoch,
    GroupEpochAckStatus? status,
    DateTime? timestamp,
  }) {
    return GroupEpochCommitAckPacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      memberPeerId: memberPeerId ?? this.memberPeerId,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'version': version,
        'operationId': operationId,
        'groupId': groupId,
        'memberPeerId': memberPeerId,
        'targetEpoch': targetEpoch,
        'status': status.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochCommitAckPacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawMemberPeerId = map['memberPeerId'] ?? map['memberId'];
    if (rawMemberPeerId is! String) {
      throw const FormatException('Missing or invalid type for "memberPeerId" (expected String).');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch" (expected int).');
    }

    final rawStatus = map['status'] ?? map['acknowledgementStatus'];
    if (rawStatus is! String) {
      throw const FormatException('Missing or invalid type for "status" (expected String).');
    }

    final GroupEpochAckStatus ackStatus;
    try {
      ackStatus = GroupEpochAckStatus.fromString(rawStatus);
    } on ArgumentError catch (e) {
      throw FormatException(e.message);
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupEpochCommitAckPacket.');
    }

    return GroupEpochCommitAckPacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      memberPeerId: rawMemberPeerId,
      targetEpoch: rawTargetEpoch,
      status: ackStatus,
      timestamp: parsedTimestamp,
    );
  }

  factory GroupEpochCommitAckPacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochCommitAckPacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochCommitAckPacket: expected Map.');
    }
    return GroupEpochCommitAckPacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochCommitAckPacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          memberPeerId == other.memberPeerId &&
          targetEpoch == other.targetEpoch &&
          status == other.status &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        memberPeerId,
        targetEpoch,
        status,
        timestamp,
      );

  @override
  String toString() =>
      'GroupEpochCommitAckPacket(opId: $operationId, member: $memberPeerId, targetEpoch: $targetEpoch, status: $status)';
}

// =============================================================================
// E. Finalize Packet
// =============================================================================

/// Phase 3 Finalize packet sent by group administrator after all active members commit.
///
/// Instructs group members to un-freeze and resume normal group messaging at the new epoch.
class GroupEpochFinalizePacket implements GroupEpochPacket {
  GroupEpochFinalizePacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.previousEpoch,
    required this.targetEpoch,
    required this.sequenceNumber,
    required this.adminPeerId,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    GroupEpochValidator.validateEpochProgression(previousEpoch, targetEpoch);
    GroupEpochValidator.validateSequenceNumber(sequenceNumber, 'sequenceNumber');
    Group.validatePeerId(adminPeerId, 'adminPeerId');
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  static const String packetType = 'group_epoch_finalize';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Epoch prior to re-epoching.
  final int previousEpoch;

  /// Target epoch advancement.
  final int targetEpoch;

  /// Monotonically increasing sequence number.
  final int sequenceNumber;

  /// Peer identifier of group administrator.
  final String adminPeerId;

  @override
  final DateTime timestamp;

  /// Convenience alias for [adminPeerId].
  String get adminId => adminPeerId;

  /// Convenience alias for [sequenceNumber].
  int get operationSequenceNumber => sequenceNumber;

  GroupEpochFinalizePacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    int? previousEpoch,
    int? targetEpoch,
    int? sequenceNumber,
    String? adminPeerId,
    DateTime? timestamp,
  }) {
    return GroupEpochFinalizePacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      previousEpoch: previousEpoch ?? this.previousEpoch,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      adminPeerId: adminPeerId ?? this.adminPeerId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'version': version,
        'operationId': operationId,
        'groupId': groupId,
        'previousEpoch': previousEpoch,
        'targetEpoch': targetEpoch,
        'sequenceNumber': sequenceNumber,
        'adminPeerId': adminPeerId,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochFinalizePacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawPreviousEpoch = map['previousEpoch'];
    if (rawPreviousEpoch is! int) {
      throw const FormatException('Missing or invalid type for "previousEpoch" (expected int).');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch" (expected int).');
    }

    final rawSequenceNumber = map['sequenceNumber'] ?? map['operationSequenceNumber'];
    if (rawSequenceNumber is! int) {
      throw const FormatException('Missing or invalid type for "sequenceNumber" (expected int).');
    }

    final rawAdminPeerId = map['adminPeerId'] ?? map['adminId'];
    if (rawAdminPeerId is! String) {
      throw const FormatException('Missing or invalid type for "adminPeerId" (expected String).');
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupEpochFinalizePacket.');
    }

    return GroupEpochFinalizePacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      previousEpoch: rawPreviousEpoch,
      targetEpoch: rawTargetEpoch,
      sequenceNumber: rawSequenceNumber,
      adminPeerId: rawAdminPeerId,
      timestamp: parsedTimestamp,
    );
  }

  factory GroupEpochFinalizePacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochFinalizePacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochFinalizePacket: expected Map.');
    }
    return GroupEpochFinalizePacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochFinalizePacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          previousEpoch == other.previousEpoch &&
          targetEpoch == other.targetEpoch &&
          sequenceNumber == other.sequenceNumber &&
          adminPeerId == other.adminPeerId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        previousEpoch,
        targetEpoch,
        sequenceNumber,
        adminPeerId,
        timestamp,
      );

  @override
  String toString() =>
      'GroupEpochFinalizePacket(opId: $operationId, group: $groupId, epochs: $previousEpoch->$targetEpoch, seq: $sequenceNumber)';
}

// =============================================================================
// F. Finalize Acknowledgement Packet
// =============================================================================

/// Phase 3 Finalize acknowledgement packet returned by an active group member.
class GroupEpochFinalizeAckPacket implements GroupEpochPacket {
  GroupEpochFinalizeAckPacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.memberPeerId,
    required this.targetEpoch,
    required this.status,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(memberPeerId, 'memberPeerId');
    GroupEpochValidator.validateEpoch(targetEpoch, 'targetEpoch');
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  static const String packetType = 'group_epoch_finalize_ack';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Peer identifier of acknowledging member.
  final String memberPeerId;

  /// Target epoch finalized by member.
  final int targetEpoch;

  /// Acknowledgement status (pending, acknowledged, failed).
  final GroupEpochAckStatus status;

  @override
  final DateTime timestamp;

  /// Alias for [status].
  GroupEpochAckStatus get acknowledgementStatus => status;

  GroupEpochFinalizeAckPacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    String? memberPeerId,
    int? targetEpoch,
    GroupEpochAckStatus? status,
    DateTime? timestamp,
  }) {
    return GroupEpochFinalizeAckPacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      memberPeerId: memberPeerId ?? this.memberPeerId,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'version': version,
        'operationId': operationId,
        'groupId': groupId,
        'memberPeerId': memberPeerId,
        'targetEpoch': targetEpoch,
        'status': status.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochFinalizeAckPacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawMemberPeerId = map['memberPeerId'] ?? map['memberId'];
    if (rawMemberPeerId is! String) {
      throw const FormatException('Missing or invalid type for "memberPeerId" (expected String).');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch" (expected int).');
    }

    final rawStatus = map['status'] ?? map['acknowledgementStatus'];
    if (rawStatus is! String) {
      throw const FormatException('Missing or invalid type for "status" (expected String).');
    }

    final GroupEpochAckStatus ackStatus;
    try {
      ackStatus = GroupEpochAckStatus.fromString(rawStatus);
    } on ArgumentError catch (e) {
      throw FormatException(e.message);
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupEpochFinalizeAckPacket.');
    }

    return GroupEpochFinalizeAckPacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      memberPeerId: rawMemberPeerId,
      targetEpoch: rawTargetEpoch,
      status: ackStatus,
      timestamp: parsedTimestamp,
    );
  }

  factory GroupEpochFinalizeAckPacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochFinalizeAckPacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochFinalizeAckPacket: expected Map.');
    }
    return GroupEpochFinalizeAckPacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochFinalizeAckPacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          memberPeerId == other.memberPeerId &&
          targetEpoch == other.targetEpoch &&
          status == other.status &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        memberPeerId,
        targetEpoch,
        status,
        timestamp,
      );

  @override
  String toString() =>
      'GroupEpochFinalizeAckPacket(opId: $operationId, member: $memberPeerId, targetEpoch: $targetEpoch, status: $status)';
}

// =============================================================================
// G. Status Probe Packet
// =============================================================================

/// Diagnostic and reconciliation status probe packet sent by a member or admin
/// to inquire about the authoritative epoch state.
class GroupEpochStatusProbePacket implements GroupEpochPacket {
  GroupEpochStatusProbePacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.requestingPeerId,
    required this.knownEpoch,
    required this.knownSequenceNumber,
    required this.timestamp,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(requestingPeerId, 'requestingPeerId');
    GroupEpochValidator.validateEpoch(knownEpoch, 'knownEpoch');
    GroupEpochValidator.validateNonNegativeSequenceNumber(
      knownSequenceNumber,
      'knownSequenceNumber',
    );
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  static const String packetType = 'group_epoch_status_probe';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Peer identifier requesting epoch status.
  final String requestingPeerId;

  /// Locally known epoch of the requesting peer.
  final int knownEpoch;

  /// Locally known sequence number of the requesting peer.
  final int knownSequenceNumber;

  @override
  final DateTime timestamp;

  GroupEpochStatusProbePacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    String? requestingPeerId,
    int? knownEpoch,
    int? knownSequenceNumber,
    DateTime? timestamp,
  }) {
    return GroupEpochStatusProbePacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      requestingPeerId: requestingPeerId ?? this.requestingPeerId,
      knownEpoch: knownEpoch ?? this.knownEpoch,
      knownSequenceNumber: knownSequenceNumber ?? this.knownSequenceNumber,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'version': version,
        'operationId': operationId,
        'groupId': groupId,
        'requestingPeerId': requestingPeerId,
        'knownEpoch': knownEpoch,
        'knownSequenceNumber': knownSequenceNumber,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochStatusProbePacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawRequestingPeerId = map['requestingPeerId'];
    if (rawRequestingPeerId is! String) {
      throw const FormatException(
        'Missing or invalid type for "requestingPeerId" (expected String).',
      );
    }

    final rawKnownEpoch = map['knownEpoch'];
    if (rawKnownEpoch is! int) {
      throw const FormatException('Missing or invalid type for "knownEpoch" (expected int).');
    }

    final rawKnownSequenceNumber = map['knownSequenceNumber'];
    if (rawKnownSequenceNumber is! int) {
      throw const FormatException(
        'Missing or invalid type for "knownSequenceNumber" (expected int).',
      );
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp" in GroupEpochStatusProbePacket.');
    }

    return GroupEpochStatusProbePacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      requestingPeerId: rawRequestingPeerId,
      knownEpoch: rawKnownEpoch,
      knownSequenceNumber: rawKnownSequenceNumber,
      timestamp: parsedTimestamp,
    );
  }

  factory GroupEpochStatusProbePacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochStatusProbePacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochStatusProbePacket: expected Map.');
    }
    return GroupEpochStatusProbePacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochStatusProbePacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          requestingPeerId == other.requestingPeerId &&
          knownEpoch == other.knownEpoch &&
          knownSequenceNumber == other.knownSequenceNumber &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        requestingPeerId,
        knownEpoch,
        knownSequenceNumber,
        timestamp,
      );

  @override
  String toString() =>
      'GroupEpochStatusProbePacket(opId: $operationId, requester: $requestingPeerId, knownEpoch: $knownEpoch, knownSeq: $knownSequenceNumber)';
}

// =============================================================================
// H. Status Response / Reconciliation Packet
// =============================================================================

/// Status response packet conveying authoritative epoch metadata for reconciliation.
///
/// CRITICAL SECURITY NOTE:
/// This packet conveys only administrative lifecycle metadata.
/// It MUST NEVER contain private keys, session secrets, or message content.
class GroupEpochStatusResponsePacket implements GroupEpochPacket {
  GroupEpochStatusResponsePacket({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required String operationId,
    required this.groupId,
    required this.respondingPeerId,
    required this.authoritativeEpoch,
    required this.authoritativeSequenceNumber,
    required this.operationStatus,
    required this.timestamp,
    this.targetEpoch,
    this.previousEpoch,
    this.isReEpochPending,
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported packet version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(respondingPeerId, 'respondingPeerId');
    GroupEpochValidator.validateEpoch(authoritativeEpoch, 'authoritativeEpoch');
    GroupEpochValidator.validateNonNegativeSequenceNumber(
      authoritativeSequenceNumber,
      'authoritativeSequenceNumber',
    );
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');

    if (targetEpoch != null) {
      GroupEpochValidator.validateEpoch(targetEpoch!, 'targetEpoch');
    }
    if (previousEpoch != null) {
      GroupEpochValidator.validateEpoch(previousEpoch!, 'previousEpoch');
    }
    if (targetEpoch != null && previousEpoch != null) {
      GroupEpochValidator.validateEpochProgression(previousEpoch!, targetEpoch!);
    }
  }

  static const String packetType = 'group_epoch_status_response';

  @override
  String get type => packetType;

  @override
  final int version;

  @override
  final String operationId;

  @override
  final String groupId;

  /// Peer identifier responding to the status inquiry.
  final String respondingPeerId;

  /// Authoritative current group epoch.
  final int authoritativeEpoch;

  /// Authoritative current sequence number.
  final int authoritativeSequenceNumber;

  /// Authoritative operation lifecycle status.
  final GroupEpochOperationStatus operationStatus;

  @override
  final DateTime timestamp;

  /// Optional target epoch of an ongoing or completed operation.
  final int? targetEpoch;

  /// Optional previous epoch of an ongoing or completed operation.
  final int? previousEpoch;

  /// Optional flag indicating if an administrative re-epoch is currently pending.
  final bool? isReEpochPending;

  /// Convenience alias for [operationStatus].
  GroupEpochOperationStatus get status => operationStatus;

  GroupEpochStatusResponsePacket copyWith({
    int? version,
    String? operationId,
    String? groupId,
    String? respondingPeerId,
    int? authoritativeEpoch,
    int? authoritativeSequenceNumber,
    GroupEpochOperationStatus? operationStatus,
    DateTime? timestamp,
    int? targetEpoch,
    int? previousEpoch,
    bool? isReEpochPending,
  }) {
    return GroupEpochStatusResponsePacket(
      version: version ?? this.version,
      operationId: operationId ?? this.operationId,
      groupId: groupId ?? this.groupId,
      respondingPeerId: respondingPeerId ?? this.respondingPeerId,
      authoritativeEpoch: authoritativeEpoch ?? this.authoritativeEpoch,
      authoritativeSequenceNumber:
          authoritativeSequenceNumber ?? this.authoritativeSequenceNumber,
      operationStatus: operationStatus ?? this.operationStatus,
      timestamp: timestamp ?? this.timestamp,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      previousEpoch: previousEpoch ?? this.previousEpoch,
      isReEpochPending: isReEpochPending ?? this.isReEpochPending,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
      'version': version,
      'operationId': operationId,
      'groupId': groupId,
      'respondingPeerId': respondingPeerId,
      'authoritativeEpoch': authoritativeEpoch,
      'authoritativeSequenceNumber': authoritativeSequenceNumber,
      'operationStatus': operationStatus.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
    if (targetEpoch != null) {
      map['targetEpoch'] = targetEpoch;
    }
    if (previousEpoch != null) {
      map['previousEpoch'] = previousEpoch;
    }
    if (isReEpochPending != null) {
      map['isReEpochPending'] = isReEpochPending;
    }
    return map;
  }

  @override
  String toJson() => jsonEncode(toMap());

  factory GroupEpochStatusResponsePacket.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType != packetType) {
      throw FormatException(
        'Invalid or mismatched packet type: "$rawType" (expected "$packetType").',
      );
    }

    final rawVersion = map['version'];
    if (rawVersion is! int || rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported packet version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId" (expected String).');
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId" (expected String).');
    }

    final rawRespondingPeerId = map['respondingPeerId'];
    if (rawRespondingPeerId is! String) {
      throw const FormatException(
        'Missing or invalid type for "respondingPeerId" (expected String).',
      );
    }

    final rawAuthEpoch = map['authoritativeEpoch'];
    if (rawAuthEpoch is! int) {
      throw const FormatException(
        'Missing or invalid type for "authoritativeEpoch" (expected int).',
      );
    }

    final rawAuthSeq = map['authoritativeSequenceNumber'];
    if (rawAuthSeq is! int) {
      throw const FormatException(
        'Missing or invalid type for "authoritativeSequenceNumber" (expected int).',
      );
    }

    final rawOpStatus = map['operationStatus'] ?? map['status'];
    if (rawOpStatus is! String) {
      throw const FormatException('Missing or invalid type for "operationStatus" (expected String).');
    }

    final GroupEpochOperationStatus opStatus;
    try {
      opStatus = GroupEpochOperationStatus.fromString(rawOpStatus);
    } on ArgumentError catch (e) {
      throw FormatException(e.message);
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp" (expected String).');
    }

    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException(
        'Invalid or non-UTC "timestamp" in GroupEpochStatusResponsePacket.',
      );
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch != null && rawTargetEpoch is! int) {
      throw const FormatException('Invalid type for "targetEpoch" (expected int or null).');
    }

    final rawPrevEpoch = map['previousEpoch'];
    if (rawPrevEpoch != null && rawPrevEpoch is! int) {
      throw const FormatException('Invalid type for "previousEpoch" (expected int or null).');
    }

    final rawPending = map['isReEpochPending'];
    if (rawPending != null && rawPending is! bool) {
      throw const FormatException('Invalid type for "isReEpochPending" (expected bool or null).');
    }

    return GroupEpochStatusResponsePacket(
      version: rawVersion,
      operationId: rawOperationId,
      groupId: rawGroupId,
      respondingPeerId: rawRespondingPeerId,
      authoritativeEpoch: rawAuthEpoch,
      authoritativeSequenceNumber: rawAuthSeq,
      operationStatus: opStatus,
      timestamp: parsedTimestamp,
      targetEpoch: rawTargetEpoch,
      previousEpoch: rawPrevEpoch,
      isReEpochPending: rawPending,
    );
  }

  factory GroupEpochStatusResponsePacket.fromJson(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('Invalid JSON payload for GroupEpochStatusResponsePacket: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for GroupEpochStatusResponsePacket: expected Map.');
    }
    return GroupEpochStatusResponsePacket.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochStatusResponsePacket &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          operationId == other.operationId &&
          groupId == other.groupId &&
          respondingPeerId == other.respondingPeerId &&
          authoritativeEpoch == other.authoritativeEpoch &&
          authoritativeSequenceNumber == other.authoritativeSequenceNumber &&
          operationStatus == other.operationStatus &&
          timestamp == other.timestamp &&
          targetEpoch == other.targetEpoch &&
          previousEpoch == other.previousEpoch &&
          isReEpochPending == other.isReEpochPending;

  @override
  int get hashCode => Object.hash(
        version,
        operationId,
        groupId,
        respondingPeerId,
        authoritativeEpoch,
        authoritativeSequenceNumber,
        operationStatus,
        timestamp,
        targetEpoch,
        previousEpoch,
        isReEpochPending,
      );

  @override
  String toString() =>
      'GroupEpochStatusResponsePacket(opId: $operationId, peer: $respondingPeerId, authEpoch: $authoritativeEpoch, status: $operationStatus)';
}

