import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/models/group_epoch_packets.dart';
import 'package:meshlink/features/messages/domain/models/group.dart';

/// Cryptographically authenticated, signed record of an administrative group re-epoch operation.
///
/// Phase 9 Step 6.3.2: Re-Epoch Runtime Service and Durable Persistence Integration
///
/// Binds:
/// - Group identifier.
/// - Operation identifier.
/// - Previous epoch.
/// - Target epoch.
/// - Operation sequence number.
/// - Administrator peer identifier.
/// - Operation lifecycle status.
/// - UTC timestamp.
/// - Cryptographic Ed25519 signature.
class GroupEpochSignedHistory {
  GroupEpochSignedHistory({
    this.version = GroupEpochValidator.currentProtocolVersion,
    required this.groupId,
    required String operationId,
    required this.previousEpoch,
    required this.targetEpoch,
    required this.operationSequenceNumber,
    required this.adminPeerId,
    required this.operationStatus,
    required this.timestamp,
    this.signature = '',
  }) : operationId = GroupEpochValidator.validateAndNormalizeOperationId(operationId) {
    if (version != GroupEpochValidator.currentProtocolVersion) {
      throw ArgumentError(
        'Unsupported version: $version (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }
    Group.validateGroupId(groupId);
    Group.validatePeerId(adminPeerId, 'adminPeerId');
    GroupEpochValidator.validateEpoch(previousEpoch, 'previousEpoch');
    GroupEpochValidator.validateEpoch(targetEpoch, 'targetEpoch');
    if (targetEpoch <= previousEpoch) {
      throw ArgumentError(
        'targetEpoch ($targetEpoch) must be strictly greater than previousEpoch ($previousEpoch).',
      );
    }
    GroupEpochValidator.validateSequenceNumber(
      operationSequenceNumber,
      'operationSequenceNumber',
    );
    GroupEpochValidator.validateTimestamp(timestamp, 'timestamp');
  }

  /// Protocol version (strictly 1).
  final int version;

  /// Target group identifier.
  final String groupId;

  /// Unique 32-hexadecimal operation identifier.
  final String operationId;

  /// Epoch prior to re-epoching.
  final int previousEpoch;

  /// Target epoch advancement.
  final int targetEpoch;

  /// Monotonically increasing operation sequence number.
  final int operationSequenceNumber;

  /// Claimed administrator peer identifier.
  final String adminPeerId;

  /// Authoritative lifecycle status of the operation.
  final GroupEpochOperationStatus operationStatus;

  /// UTC creation timestamp.
  final DateTime timestamp;

  /// Canonical Base64URL-encoded 64-byte Ed25519 signature.
  final String signature;

  /// Returns a sorted Map with strictly lexicographical key order for signing.
  Map<String, dynamic> toSigningMap() {
    return SplayTreeMap<String, dynamic>()
      ..addAll({
        'adminPeerId': adminPeerId,
        'groupId': groupId,
        'operationId': operationId,
        'operationSequenceNumber': operationSequenceNumber,
        'operationStatus': operationStatus.toJson(),
        'previousEpoch': previousEpoch,
        'targetEpoch': targetEpoch,
        'timestamp': timestamp.toIso8601String(),
        'version': version,
      });
  }

  /// Deterministic binary bytes for Ed25519 signing and verification.
  Uint8List get signingBytes =>
      Uint8List.fromList(utf8.encode(jsonEncode(toSigningMap())));

  /// Signs this history record using the administrator's local Ed25519 key pair.
  Future<GroupEpochSignedHistory> sign(
    Ed25519 ed25519,
    SimpleKeyPair keyPair,
  ) async {
    final signatureObj = await ed25519.sign(signingBytes, keyPair: keyPair);
    return copyWith(signature: base64UrlEncode(signatureObj.bytes));
  }

  /// Verifies the signature against the provided trusted administrator Ed25519 public key bytes.
  Future<bool> verify(
    Ed25519 ed25519,
    Uint8List adminPublicKeyBytes,
  ) async {
    if (signature.isEmpty) return false;
    if (adminPublicKeyBytes.length != 32) return false;
    try {
      final sigBytes = base64Url.decode(signature);
      if (sigBytes.length != 64) return false;

      return await ed25519.verify(
        signingBytes,
        signature: Signature(
          sigBytes,
          publicKey: SimplePublicKey(
            adminPublicKeyBytes,
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  GroupEpochSignedHistory copyWith({
    int? version,
    String? groupId,
    String? operationId,
    int? previousEpoch,
    int? targetEpoch,
    int? operationSequenceNumber,
    String? adminPeerId,
    GroupEpochOperationStatus? operationStatus,
    DateTime? timestamp,
    String? signature,
  }) {
    return GroupEpochSignedHistory(
      version: version ?? this.version,
      groupId: groupId ?? this.groupId,
      operationId: operationId ?? this.operationId,
      previousEpoch: previousEpoch ?? this.previousEpoch,
      targetEpoch: targetEpoch ?? this.targetEpoch,
      operationSequenceNumber:
          operationSequenceNumber ?? this.operationSequenceNumber,
      adminPeerId: adminPeerId ?? this.adminPeerId,
      operationStatus: operationStatus ?? this.operationStatus,
      timestamp: timestamp ?? this.timestamp,
      signature: signature ?? this.signature,
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'groupId': groupId,
        'operationId': operationId,
        'previousEpoch': previousEpoch,
        'targetEpoch': targetEpoch,
        'operationSequenceNumber': operationSequenceNumber,
        'adminPeerId': adminPeerId,
        'operationStatus': operationStatus.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'signature': signature,
      };

  String toJson() => jsonEncode(toMap());

  factory GroupEpochSignedHistory.fromMap(Map<String, dynamic> map) {
    final rawVersion = map['version'];
    if (rawVersion is! int ||
        rawVersion != GroupEpochValidator.currentProtocolVersion) {
      throw FormatException(
        'Unsupported version: "$rawVersion" (expected ${GroupEpochValidator.currentProtocolVersion}).',
      );
    }

    final rawGroupId = map['groupId'];
    if (rawGroupId is! String) {
      throw const FormatException('Missing or invalid type for "groupId".');
    }

    final rawOperationId = map['operationId'];
    if (rawOperationId is! String) {
      throw const FormatException('Missing or invalid type for "operationId".');
    }

    final rawPreviousEpoch = map['previousEpoch'];
    if (rawPreviousEpoch is! int) {
      throw const FormatException(
          'Missing or invalid type for "previousEpoch".');
    }

    final rawTargetEpoch = map['targetEpoch'];
    if (rawTargetEpoch is! int) {
      throw const FormatException('Missing or invalid type for "targetEpoch".');
    }

    final rawSeqNum = map['operationSequenceNumber'];
    if (rawSeqNum is! int) {
      throw const FormatException(
          'Missing or invalid type for "operationSequenceNumber".');
    }

    final rawAdminPeerId = map['adminPeerId'];
    if (rawAdminPeerId is! String) {
      throw const FormatException('Missing or invalid type for "adminPeerId".');
    }

    final rawStatus = map['operationStatus'];
    if (rawStatus is! String) {
      throw const FormatException(
          'Missing or invalid type for "operationStatus".');
    }

    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is! String) {
      throw const FormatException('Missing or invalid type for "timestamp".');
    }
    final parsedTimestamp = DateTime.tryParse(rawTimestamp);
    if (parsedTimestamp == null || !parsedTimestamp.isUtc) {
      throw const FormatException('Invalid or non-UTC "timestamp".');
    }

    final rawSignature = map['signature'] as String? ?? '';

    return GroupEpochSignedHistory(
      version: rawVersion,
      groupId: rawGroupId,
      operationId: rawOperationId,
      previousEpoch: rawPreviousEpoch,
      targetEpoch: rawTargetEpoch,
      operationSequenceNumber: rawSeqNum,
      adminPeerId: rawAdminPeerId,
      operationStatus: GroupEpochOperationStatus.fromString(rawStatus),
      timestamp: parsedTimestamp,
      signature: rawSignature,
    );
  }

  factory GroupEpochSignedHistory.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'Invalid JSON payload for GroupEpochSignedHistory: expected Map.');
    }
    return GroupEpochSignedHistory.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupEpochSignedHistory &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          groupId == other.groupId &&
          operationId == other.operationId &&
          previousEpoch == other.previousEpoch &&
          targetEpoch == other.targetEpoch &&
          operationSequenceNumber == other.operationSequenceNumber &&
          adminPeerId == other.adminPeerId &&
          operationStatus == other.operationStatus &&
          timestamp == other.timestamp &&
          signature == other.signature;

  @override
  int get hashCode => Object.hash(
        version,
        groupId,
        operationId,
        previousEpoch,
        targetEpoch,
        operationSequenceNumber,
        adminPeerId,
        operationStatus,
        timestamp,
        signature,
      );

  @override
  String toString() =>
      'GroupEpochSignedHistory(opId: $operationId, group: $groupId, epoch: $previousEpoch->$targetEpoch, seq: $operationSequenceNumber, status: $operationStatus)';
}

