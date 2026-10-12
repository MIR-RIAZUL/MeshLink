import 'dart:convert';
import 'dart:typed_data';

import 'package:meshlink/features/messages/data/services/file_path_service.dart';

/// Type of chunk acknowledgment.
enum ChunkAckType {
  /// Positive acknowledgment: chunk was received and staged successfully.
  ack,

  /// Negative acknowledgment: chunk was rejected for a specific reason.
  nack;

  String toJson() => name;

  static ChunkAckType fromString(String value) {
    return ChunkAckType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.trim().toLowerCase(),
      orElse: () => throw ArgumentError('Unknown ChunkAckType: "$value"'),
    );
  }
}

/// Bounded NACK reason codes.
///
/// Prevents exposing local filesystem details, environment information,
/// or arbitrary unbounded strings to remote peers.
enum ChunkNackReason {
  /// Chunk cryptographic authentication or decryption failed.
  authenticationFailed('authentication_failed'),

  /// Chunk metadata (index, offset, length, totalChunks) does not match transfer metadata.
  metadataMismatch('metadata_mismatch'),

  /// Transfer not found, wrong direction, or invalid lifecycle state.
  invalidTransferState('invalid_transfer_state'),

  /// Session ID, epoch, or peer identity mismatch.
  sessionMismatch('session_mismatch'),

  /// Packet rejected by Phase 7 replay protection (stale, future, or duplicate session packet).
  replayRejected('replay_rejected'),

  /// Disk write or staging failure prevented chunk storage.
  storageFailure('storage_failure'),

  /// Duplicate chunk arrived with conflicting content (byte mismatch on already-staged data).
  contentConflict('content_conflict'),

  /// Peer trust verification failed (compromised or unverified when verified required).
  peerUntrusted('peer_untrusted');

  const ChunkNackReason(this.wireCode);

  final String wireCode;

  String toJson() => wireCode;

  static ChunkNackReason fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final reason in ChunkNackReason.values) {
      if (reason.wireCode == normalized ||
          reason.name.toLowerCase() == normalized) {
        return reason;
      }
    }
    throw ArgumentError('Unknown ChunkNackReason: "$value"');
  }

  static ChunkNackReason? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }
}

/// Immutable, strongly-typed domain model representing a chunk-level ACK or NACK.
///
/// Phase 8 Step 12: Incremental Chunk Acknowledgment.
///
/// Protocol properties:
/// - Protocol version: strictly 2.
/// - Correlates to a specific transfer, chunk index, session, epoch, and sequenceNumber.
/// - ACKs confirm successful receipt and staging of a specific chunk.
/// - NACKs carry a bounded [ChunkNackReason] — never arbitrary error text.
/// - Sender/receiver IDs are bound; origin is the acknowledging peer.
/// - Never includes: plaintext data, encryption keys, local paths, or stack traces.
class ChunkAcknowledgment {
  ChunkAcknowledgment({
    this.version = defaultProtocolVersion,
    required this.transferId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.ackType,
    this.nackReason,
    required this.originId,
    required this.destinationId,
    required this.sessionId,
    required this.epoch,
    this.sequenceNumber = 0,
    required this.createdAt,
  }) {
    if (version != defaultProtocolVersion) {
      throw ArgumentError(
        'Unsupported protocol version: $version (expected $defaultProtocolVersion).',
      );
    }

    FilePathService.validateTransferId(transferId);
    _validateIdentifier(originId, 'originId');
    _validateIdentifier(destinationId, 'destinationId');
    _validateIdentifier(sessionId, 'sessionId');

    if (originId == destinationId) {
      throw ArgumentError('originId and destinationId cannot be identical.');
    }

    if (chunkIndex < 0 || chunkIndex > 0xFFFFFFFF) {
      throw ArgumentError(
        'chunkIndex out of range [0, 0xFFFFFFFF] (got $chunkIndex).',
      );
    }
    if (totalChunks < 0 || totalChunks > 0xFFFFFFFF) {
      throw ArgumentError(
        'totalChunks out of range [0, 0xFFFFFFFF] (got $totalChunks).',
      );
    }
    if (totalChunks > 0 && chunkIndex >= totalChunks) {
      throw ArgumentError(
        'chunkIndex ($chunkIndex) must be less than totalChunks ($totalChunks).',
      );
    }

    if (epoch < 0 || epoch > 0xFFFFFFFF) {
      throw ArgumentError(
        'epoch out of range [0, 0xFFFFFFFF] (got $epoch).',
      );
    }
    if (sequenceNumber < 0 || sequenceNumber > 0xFFFFFFFF) {
      throw ArgumentError(
        'sequenceNumber out of range [0, 0xFFFFFFFF] (got $sequenceNumber).',
      );
    }

    if (ackType == ChunkAckType.ack && nackReason != null) {
      throw ArgumentError('ACK messages must not include a nackReason.');
    }
    if (ackType == ChunkAckType.nack && nackReason == null) {
      throw ArgumentError('NACK messages must specify a nackReason.');
    }
  }

  /// Protocol version for MeshLink v2 chunk acknowledgments.
  static const int defaultProtocolVersion = 2;

  /// Maximum length for identifier fields.
  static const int maxIdentifierLength = 128;

  /// Domain separator for ACK/NACK AAD construction.
  static const String domainSeparator = 'MESHLINK-CHUNK-ACK-v2';

  /// Packet type identifier for replay protection.
  static const String packetType = 'chunk_ack';

  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');

  final int version;
  final String transferId;
  final int chunkIndex;
  final int totalChunks;
  final ChunkAckType ackType;
  final ChunkNackReason? nackReason;
  final String originId;
  final String destinationId;
  final String sessionId;
  final int epoch;
  final int sequenceNumber;
  final DateTime createdAt;

  /// Whether this is a positive acknowledgment.
  bool get isAck => ackType == ChunkAckType.ack;

  /// Whether this is a negative acknowledgment.
  bool get isNack => ackType == ChunkAckType.nack;

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

  /// Serializes to a Map using JSON-compatible types.
  Map<String, dynamic> toMap() => {
        'version': version,
        'transferId': transferId,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
        'ackType': ackType.toJson(),
        if (nackReason != null) 'nackReason': nackReason!.toJson(),
        'originId': originId,
        'destinationId': destinationId,
        'sessionId': sessionId,
        'epoch': epoch,
        'sequenceNumber': sequenceNumber,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// Deserializes from a Map with strict validation.
  factory ChunkAcknowledgment.fromMap(Map<String, dynamic> map) {
    final version = (map['version'] as num?)?.toInt() ?? 0;
    final transferId = map['transferId'] as String? ?? '';
    final chunkIndex = (map['chunkIndex'] as num?)?.toInt() ?? -1;
    final totalChunks = (map['totalChunks'] as num?)?.toInt() ?? -1;
    final ackTypeStr = map['ackType'] as String? ?? '';
    final ackType = ChunkAckType.fromString(ackTypeStr);
    final nackReasonStr = map['nackReason'] as String?;
    final nackReason = ChunkNackReason.tryFromString(nackReasonStr);
    final originId = map['originId'] as String? ?? '';
    final destinationId = map['destinationId'] as String? ?? '';
    final sessionId = map['sessionId'] as String? ?? '';
    final epoch = (map['epoch'] as num?)?.toInt() ?? -1;
    final sequenceNumber = (map['sequenceNumber'] as num?)?.toInt() ?? 0;
    final createdAtRaw = map['createdAt'] as String?;

    if (createdAtRaw == null) {
      throw ArgumentError('createdAt is required.');
    }
    final createdAt = DateTime.parse(createdAtRaw).toUtc();

    return ChunkAcknowledgment(
      version: version,
      transferId: transferId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      ackType: ackType,
      nackReason: nackReason,
      originId: originId,
      destinationId: destinationId,
      sessionId: sessionId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
      createdAt: createdAt,
    );
  }

  /// JSON serialization.
  String toJson() => jsonEncode(toMap());

  /// JSON deserialization.
  factory ChunkAcknowledgment.fromJson(String source) =>
      ChunkAcknowledgment.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Canonical binary serialization for compact wire transmission.
  Uint8List toBytes() {
    final builder = BytesBuilder(copy: false);

    final fixed = ByteData(28);
    fixed.setUint16(0, version, Endian.big);
    fixed.setUint8(2, ackType == ChunkAckType.ack ? 0 : 1);
    fixed.setUint8(
      3,
      nackReason != null ? ChunkNackReason.values.indexOf(nackReason!) : 0xFF,
    );
    fixed.setUint32(4, epoch, Endian.big);
    fixed.setUint32(8, sequenceNumber, Endian.big);
    fixed.setUint32(12, chunkIndex, Endian.big);
    fixed.setUint32(16, totalChunks, Endian.big);
    fixed.setInt64(20, createdAt.toUtc().millisecondsSinceEpoch, Endian.big);
    builder.add(fixed.buffer.asUint8List());

    void addPrefixedString(String s) {
      final bytes = utf8.encode(s);
      final len = ByteData(2)..setUint16(0, bytes.length, Endian.big);
      builder.add(len.buffer.asUint8List());
      builder.add(bytes);
    }

    addPrefixedString(transferId);
    addPrefixedString(originId);
    addPrefixedString(destinationId);
    addPrefixedString(sessionId);

    return builder.toBytes();
  }

  /// Deserializes from canonical binary format.
  factory ChunkAcknowledgment.fromBytes(List<int> bytes) {
    if (bytes.length < 28 + 8) {
      throw const FormatException(
        'Invalid binary chunk acknowledgment: too short',
      );
    }

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    int cursor = 0;

    final version = data.getUint16(cursor, Endian.big);
    cursor += 2;
    final ackTypeByte = data.getUint8(cursor);
    cursor += 1;
    final ackType = ackTypeByte == 0 ? ChunkAckType.ack : ChunkAckType.nack;

    final nackReasonByte = data.getUint8(cursor);
    cursor += 1;
    ChunkNackReason? nackReason;
    if (nackReasonByte != 0xFF && nackReasonByte < ChunkNackReason.values.length) {
      nackReason = ChunkNackReason.values[nackReasonByte];
    }

    final epoch = data.getUint32(cursor, Endian.big);
    cursor += 4;
    final sequenceNumber = data.getUint32(cursor, Endian.big);
    cursor += 4;
    final chunkIndex = data.getUint32(cursor, Endian.big);
    cursor += 4;
    final totalChunks = data.getUint32(cursor, Endian.big);
    cursor += 4;
    final createdAtMillis = data.getInt64(cursor, Endian.big);
    cursor += 8;

    String readPrefixedString() {
      if (cursor + 2 > bytes.length) {
        throw const FormatException(
          'Unexpected EOF reading string length in chunk acknowledgment',
        );
      }
      final len = data.getUint16(cursor, Endian.big);
      cursor += 2;
      if (cursor + len > bytes.length) {
        throw const FormatException(
          'Unexpected EOF reading string content in chunk acknowledgment',
        );
      }
      final strBytes = bytes.sublist(cursor, cursor + len);
      cursor += len;
      return utf8.decode(strBytes);
    }

    final transferId = readPrefixedString();
    final originId = readPrefixedString();
    final destinationId = readPrefixedString();
    final sessionId = readPrefixedString();

    return ChunkAcknowledgment(
      version: version,
      transferId: transferId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      ackType: ackType,
      nackReason: nackReason,
      originId: originId,
      destinationId: destinationId,
      sessionId: sessionId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis, isUtc: true),
    );
  }

  ChunkAcknowledgment copyWith({
    int? version,
    String? transferId,
    int? chunkIndex,
    int? totalChunks,
    ChunkAckType? ackType,
    ChunkNackReason? nackReason,
    String? originId,
    String? destinationId,
    String? sessionId,
    int? epoch,
    int? sequenceNumber,
    DateTime? createdAt,
  }) {
    return ChunkAcknowledgment(
      version: version ?? this.version,
      transferId: transferId ?? this.transferId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      ackType: ackType ?? this.ackType,
      nackReason: nackReason ?? this.nackReason,
      originId: originId ?? this.originId,
      destinationId: destinationId ?? this.destinationId,
      sessionId: sessionId ?? this.sessionId,
      epoch: epoch ?? this.epoch,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkAcknowledgment &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          transferId == other.transferId &&
          chunkIndex == other.chunkIndex &&
          totalChunks == other.totalChunks &&
          ackType == other.ackType &&
          nackReason == other.nackReason &&
          originId == other.originId &&
          destinationId == other.destinationId &&
          sessionId == other.sessionId &&
          epoch == other.epoch &&
          sequenceNumber == other.sequenceNumber &&
          createdAt.toUtc() == other.createdAt.toUtc();

  @override
  int get hashCode => Object.hash(
        version,
        transferId,
        chunkIndex,
        totalChunks,
        ackType,
        nackReason,
        originId,
        destinationId,
        sessionId,
        epoch,
        sequenceNumber,
        createdAt.toUtc(),
      );

  @override
  String toString() =>
      'ChunkAcknowledgment(transferId: $transferId, chunk: $chunkIndex/$totalChunks, '
      'type: ${ackType.name}, reason: ${nackReason?.wireCode}, '
      'session: $sessionId, epoch: $epoch, seq: $sequenceNumber)';
}
