import 'dart:convert';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';

/// Type of decision rendered on a file transfer offer.
enum FileTransferDecisionType {
  accept,
  reject;

  String toJson() => name;

  static FileTransferDecisionType fromString(String value) {
    return FileTransferDecisionType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.trim().toLowerCase(),
      orElse: () => throw ArgumentError('Unknown FileTransferDecisionType: "$value"'),
    );
  }
}

/// Bounded rejection reason codes for file transfer negotiation.
///
/// Prevents exposing local filesystem paths, environment details, or arbitrary
/// unbounded remote strings.
enum FileTransferRejectionReason {
  userRejected('user_rejected'),
  insufficientStorage('insufficient_storage'),
  unsupportedFile('unsupported_file'),
  invalidMetadata('invalid_metadata'),
  transferBusy('transfer_busy');

  const FileTransferRejectionReason(this.wireCode);

  final String wireCode;

  String toJson() => wireCode;

  static FileTransferRejectionReason fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final reason in FileTransferRejectionReason.values) {
      if (reason.wireCode == normalized || reason.name.toLowerCase() == normalized) {
        return reason;
      }
    }
    throw ArgumentError('Unknown FileTransferRejectionReason: "$value"');
  }

  static FileTransferRejectionReason? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }
}

/// Immutable domain model representing an authenticated decision (accept/reject)
/// on a file transfer offer.
///
/// Phase 8 Step 9: File Negotiation Handshake.
///
/// Protocol properties:
/// - Version: strictly 2.
/// - Bound identifiers: transfer ID, offer ID, authenticated sender ID, authenticated recipient ID.
/// - Explicit decision: accept or reject.
/// - Rejection reasons are restricted to a closed enum of bounded wire codes.
/// - Never includes local paths, system details, or unvalidated error text.
class FileTransferDecision {
  FileTransferDecision({
    this.version = defaultProtocolVersion,
    required this.transferId,
    required this.offerId,
    required this.decisionType,
    this.rejectionReason,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
  }) {
    if (version != defaultProtocolVersion) {
      throw ArgumentError(
        'Unsupported protocol version: $version (expected $defaultProtocolVersion).',
      );
    }

    FilePathService.validateTransferId(transferId);
    _validateIdentifier(offerId, 'offerId');
    _validateIdentifier(senderId, 'senderId');
    _validateIdentifier(recipientId, 'recipientId');

    if (senderId == recipientId) {
      throw ArgumentError('senderId and recipientId cannot be identical.');
    }

    if (decisionType == FileTransferDecisionType.accept) {
      if (rejectionReason != null) {
        throw ArgumentError('Acceptance decisions cannot include a rejectionReason.');
      }
    } else if (decisionType == FileTransferDecisionType.reject) {
      if (rejectionReason == null) {
        throw ArgumentError('Rejection decisions must specify a rejectionReason.');
      }
    }
  }

  static const int defaultProtocolVersion = 2;
  static const int maxIdentifierLength = 128;
  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');

  final int version;
  final String transferId;
  final String offerId;
  final FileTransferDecisionType decisionType;
  final FileTransferRejectionReason? rejectionReason;
  final String senderId;
  final String recipientId;
  final DateTime createdAt;

  bool get isAccepted => decisionType == FileTransferDecisionType.accept;
  bool get isRejected => decisionType == FileTransferDecisionType.reject;

  static void _validateIdentifier(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$fieldName must not be empty.');
    }
    if (value.length > maxIdentifierLength) {
      throw ArgumentError(
        '$fieldName length (${value.length}) exceeds maximum limit of $maxIdentifierLength.',
      );
    }
    if (_controlCharRegex.hasMatch(value)) {
      throw ArgumentError('$fieldName contains invalid control characters.');
    }
  }

  /// Checks if this decision has a timestamp too far in the future relative to [currentTime].
  bool isFuture([DateTime? currentTime, Duration skewTolerance = const Duration(minutes: 2)]) {
    final now = (currentTime ?? DateTime.now()).toUtc();
    return createdAt.toUtc().isAfter(now.add(skewTolerance));
  }

  FileTransferDecision copyWith({
    int? version,
    String? transferId,
    String? offerId,
    FileTransferDecisionType? decisionType,
    FileTransferRejectionReason? rejectionReason,
    String? senderId,
    String? recipientId,
    DateTime? createdAt,
  }) {
    return FileTransferDecision(
      version: version ?? this.version,
      transferId: transferId ?? this.transferId,
      offerId: offerId ?? this.offerId,
      decisionType: decisionType ?? this.decisionType,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'transferId': transferId,
    'offerId': offerId,
    'decisionType': decisionType.toJson(),
    if (rejectionReason != null) 'rejectionReason': rejectionReason!.toJson(),
    'senderId': senderId,
    'recipientId': recipientId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory FileTransferDecision.fromMap(Map<String, dynamic> map) {
    final version = (map['version'] as num?)?.toInt() ?? 0;
    final transferId = map['transferId'] as String? ?? '';
    final offerId = map['offerId'] as String? ?? '';
    final decisionTypeStr = map['decisionType'] as String? ?? '';
    final decisionType = FileTransferDecisionType.fromString(decisionTypeStr);
    final rejectionReasonStr = map['rejectionReason'] as String?;
    final rejectionReason = FileTransferRejectionReason.tryFromString(rejectionReasonStr);
    final senderId = map['senderId'] as String? ?? '';
    final recipientId = map['recipientId'] as String? ?? '';
    final createdAtRaw = map['createdAt'] as String?;

    if (createdAtRaw == null) {
      throw ArgumentError('createdAt is required.');
    }
    final createdAt = DateTime.parse(createdAtRaw).toUtc();

    return FileTransferDecision(
      version: version,
      transferId: transferId,
      offerId: offerId,
      decisionType: decisionType,
      rejectionReason: rejectionReason,
      senderId: senderId,
      recipientId: recipientId,
      createdAt: createdAt,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FileTransferDecision.fromJson(String source) =>
      FileTransferDecision.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTransferDecision &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          transferId == other.transferId &&
          offerId == other.offerId &&
          decisionType == other.decisionType &&
          rejectionReason == other.rejectionReason &&
          senderId == other.senderId &&
          recipientId == other.recipientId &&
          createdAt.toUtc() == other.createdAt.toUtc();

  @override
  int get hashCode => Object.hash(
    version,
    transferId,
    offerId,
    decisionType,
    rejectionReason,
    senderId,
    recipientId,
    createdAt.toUtc(),
  );

  @override
  String toString() =>
      'FileTransferDecision(transferId: $transferId, offerId: $offerId, '
      'type: ${decisionType.name}, reason: ${rejectionReason?.wireCode})';
}
