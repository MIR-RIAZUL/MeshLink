import 'dart:convert';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';

/// Immutable domain model representing an authenticated file transfer offer.
///
/// Phase 8 Step 9: File Negotiation Handshake.
///
/// Flow:
/// ```text
/// Sender selects file -> creates offer -> encrypted via session
/// -> Recipient validates & verifies trust -> accepts or rejects
/// ```
///
/// Protocol properties:
/// - Protocol version: strictly 2. Unsupported versions are rejected.
/// - Bound identifiers: transfer ID, offer ID, sender device ID, recipient device ID.
/// - File metadata: filename (traversal-safe), fileSize, mimeType, chunkSize, totalChunks.
/// - Temporal bounds: createdAt and expiresAt timestamps with injectable validation.
/// - Zero-byte files: fileSize == 0 requires totalChunks == 0.
/// - Never includes: plaintext data, encryption keys, session secrets, or local file paths.
class FileTransferOffer {
  FileTransferOffer({
    this.version = defaultProtocolVersion,
    required this.transferId,
    required this.offerId,
    required this.senderId,
    required this.recipientId,
    required this.fileName,
    required this.fileSize,
    this.mimeType = 'application/octet-stream',
    this.chunkSize = defaultChunkSize,
    required this.totalChunks,
    this.fileHash,
    required this.createdAt,
    required this.expiresAt,
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

    FilePathService.validateFileName(fileName);

    if (fileSize < 0) {
      throw ArgumentError('fileSize cannot be negative ($fileSize).');
    }

    _validateMimeType(mimeType);

    if (chunkSize < minChunkSize || chunkSize > maxChunkSize) {
      throw ArgumentError(
        'chunkSize ($chunkSize) must be between $minChunkSize and $maxChunkSize bytes.',
      );
    }

    if (fileSize == 0) {
      if (totalChunks != 0) {
        throw ArgumentError(
          'totalChunks must be 0 for zero-byte file ($totalChunks provided).',
        );
      }
    } else {
      final expectedChunks = (fileSize / chunkSize).ceil();
      if (totalChunks != expectedChunks) {
        throw ArgumentError(
          'totalChunks ($totalChunks) does not match expected chunk count ($expectedChunks) '
          'for fileSize $fileSize and chunkSize $chunkSize.',
        );
      }
    }

    if (fileHash != null) {
      if (fileHash!.length > 128) {
        throw ArgumentError('fileHash exceeds maximum length of 128 characters.');
      }
      if (_controlCharRegex.hasMatch(fileHash!)) {
        throw ArgumentError('fileHash contains control characters.');
      }
    }

    if (!expiresAt.isAfter(createdAt)) {
      throw ArgumentError(
        'expiresAt (${expiresAt.toIso8601String()}) must be strictly after createdAt (${createdAt.toIso8601String()}).',
      );
    }
  }

  /// Default protocol version for MeshLink v2.
  static const int defaultProtocolVersion = 2;

  /// Default chunk size: 32 KB.
  static const int defaultChunkSize = 32768;

  /// Minimum allowable chunk size: 1 KB.
  static const int minChunkSize = 1024;

  /// Maximum allowable chunk size: 64 KB.
  static const int maxChunkSize = 65536;

  /// Maximum length for IDs.
  static const int maxIdentifierLength = 128;

  /// Maximum length for MIME types.
  static const int maxMimeTypeLength = 128;

  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');

  final int version;
  final String transferId;
  final String offerId;
  final String senderId;
  final String recipientId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int chunkSize;
  final int totalChunks;
  final String? fileHash;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Validates generic printable ASCII identifier fields.
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

  /// Validates MIME type string.
  static void _validateMimeType(String mime) {
    if (mime.trim().isEmpty) {
      throw ArgumentError('mimeType must not be empty.');
    }
    if (mime.length > maxMimeTypeLength) {
      throw ArgumentError(
        'mimeType length (${mime.length}) exceeds maximum limit of $maxMimeTypeLength.',
      );
    }
    if (_controlCharRegex.hasMatch(mime)) {
      throw ArgumentError('mimeType contains invalid control characters.');
    }
  }

  /// Checks if this offer has expired relative to [currentTime].
  bool isExpired([DateTime? currentTime]) {
    final now = (currentTime ?? DateTime.now()).toUtc();
    return now.isAfter(expiresAt.toUtc());
  }

  /// Checks if this offer has a timestamp too far in the future relative to [currentTime].
  bool isFuture([DateTime? currentTime, Duration skewTolerance = const Duration(minutes: 2)]) {
    final now = (currentTime ?? DateTime.now()).toUtc();
    return createdAt.toUtc().isAfter(now.add(skewTolerance));
  }

  FileTransferOffer copyWith({
    int? version,
    String? transferId,
    String? offerId,
    String? senderId,
    String? recipientId,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? chunkSize,
    int? totalChunks,
    String? fileHash,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return FileTransferOffer(
      version: version ?? this.version,
      transferId: transferId ?? this.transferId,
      offerId: offerId ?? this.offerId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      chunkSize: chunkSize ?? this.chunkSize,
      totalChunks: totalChunks ?? this.totalChunks,
      fileHash: fileHash ?? this.fileHash,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'transferId': transferId,
    'offerId': offerId,
    'senderId': senderId,
    'recipientId': recipientId,
    'fileName': fileName,
    'fileSize': fileSize,
    'mimeType': mimeType,
    'chunkSize': chunkSize,
    'totalChunks': totalChunks,
    if (fileHash != null) 'fileHash': fileHash,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  factory FileTransferOffer.fromMap(Map<String, dynamic> map) {
    final version = (map['version'] as num?)?.toInt() ?? 0;
    final transferId = map['transferId'] as String? ?? '';
    final offerId = map['offerId'] as String? ?? '';
    final senderId = map['senderId'] as String? ?? '';
    final recipientId = map['recipientId'] as String? ?? '';
    final fileName = map['fileName'] as String? ?? '';
    final fileSize = (map['fileSize'] as num?)?.toInt() ?? -1;
    final mimeType = map['mimeType'] as String? ?? 'application/octet-stream';
    final chunkSize = (map['chunkSize'] as num?)?.toInt() ?? defaultChunkSize;
    final totalChunks = (map['totalChunks'] as num?)?.toInt() ?? -1;
    final fileHash = map['fileHash'] as String?;
    final createdAtRaw = map['createdAt'] as String?;
    final expiresAtRaw = map['expiresAt'] as String?;

    if (createdAtRaw == null || expiresAtRaw == null) {
      throw ArgumentError('createdAt and expiresAt are required.');
    }

    final createdAt = DateTime.parse(createdAtRaw).toUtc();
    final expiresAt = DateTime.parse(expiresAtRaw).toUtc();

    return FileTransferOffer(
      version: version,
      transferId: transferId,
      offerId: offerId,
      senderId: senderId,
      recipientId: recipientId,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      fileHash: fileHash,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FileTransferOffer.fromJson(String source) =>
      FileTransferOffer.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTransferOffer &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          transferId == other.transferId &&
          offerId == other.offerId &&
          senderId == other.senderId &&
          recipientId == other.recipientId &&
          fileName == other.fileName &&
          fileSize == other.fileSize &&
          mimeType == other.mimeType &&
          chunkSize == other.chunkSize &&
          totalChunks == other.totalChunks &&
          fileHash == other.fileHash &&
          createdAt.toUtc() == other.createdAt.toUtc() &&
          expiresAt.toUtc() == other.expiresAt.toUtc();

  @override
  int get hashCode => Object.hash(
    version,
    transferId,
    offerId,
    senderId,
    recipientId,
    fileName,
    fileSize,
    mimeType,
    chunkSize,
    totalChunks,
    fileHash,
    createdAt.toUtc(),
    expiresAt.toUtc(),
  );

  @override
  String toString() =>
      'FileTransferOffer(transferId: $transferId, offerId: $offerId, file: $fileName, '
      'size: $fileSize B, chunks: $totalChunks, expiresAt: ${expiresAt.toIso8601String()})';
}
