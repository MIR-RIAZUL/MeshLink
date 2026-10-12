import 'dart:convert';
import 'dart:typed_data';

import 'package:meshlink/features/messages/data/models/chunk_acknowledgment.dart';
import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';

/// Strongly-typed immutable envelope representing an encrypted chunk acknowledgment (ACK/NACK).
///
/// Phase 8 Step 12: Incremental Chunk Acknowledgment.
///
/// Cryptographic properties:
/// - Version strictly 2.
/// - Authenticates transferId, chunkIndex, totalChunks, ackType, nackReason,
///   originId, destinationId, sessionId, epoch, sequenceNumber, and timestamp.
/// - ChaCha20-Poly1305 ciphertext with 12-byte nonce and 16-byte Poly1305 MAC tag.
class EncryptedChunkAckEnvelope {
  EncryptedChunkAckEnvelope({
    required this.version,
    required this.transferId,
    required this.originId,
    required this.destinationId,
    required this.sessionId,
    required this.epoch,
    required this.sequenceNumber,
    required this.chunkIndex,
    required this.totalChunks,
    required this.ackType,
    this.nackReason,
    required this.createdAt,
    required List<int> nonce,
    required List<int> mac,
    required List<int> ciphertext,
    bool validate = true,
  })  : nonce = Uint8List.fromList(nonce),
        mac = Uint8List.fromList(mac),
        ciphertext = Uint8List.fromList(ciphertext) {
    if (validate) {
      this.validate();
    }
  }

  /// Expected protocol version for MeshLink chunk acknowledgments.
  static const int currentProtocolVersion = 2;

  final int version;
  final String transferId;
  final String originId;
  final String destinationId;
  final String sessionId;
  final int epoch;
  final int sequenceNumber;
  final int chunkIndex;
  final int totalChunks;
  final ChunkAckType ackType;
  final ChunkNackReason? nackReason;
  final DateTime createdAt;
  final Uint8List nonce;
  final Uint8List mac;
  final Uint8List ciphertext;

  bool get isAck => ackType == ChunkAckType.ack;
  bool get isNack => ackType == ChunkAckType.nack;

  EncryptedChunkAckEnvelope copyWith({
    int? version,
    String? transferId,
    String? originId,
    String? destinationId,
    String? sessionId,
    int? epoch,
    int? sequenceNumber,
    int? chunkIndex,
    int? totalChunks,
    ChunkAckType? ackType,
    ChunkNackReason? nackReason,
    DateTime? createdAt,
    List<int>? nonce,
    List<int>? mac,
    List<int>? ciphertext,
    bool validate = true,
  }) {
    return EncryptedChunkAckEnvelope(
      version: version ?? this.version,
      transferId: transferId ?? this.transferId,
      originId: originId ?? this.originId,
      destinationId: destinationId ?? this.destinationId,
      sessionId: sessionId ?? this.sessionId,
      epoch: epoch ?? this.epoch,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      ackType: ackType ?? this.ackType,
      nackReason: nackReason ?? this.nackReason,
      createdAt: createdAt ?? this.createdAt,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      ciphertext: ciphertext ?? this.ciphertext,
      validate: validate,
    );
  }

  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');

  /// Validates all envelope fields strictly against protocol constraints.
  void validate() {
    if (version != currentProtocolVersion) {
      throw FormatException(
        'Unsupported protocol version: $version (expected $currentProtocolVersion)',
      );
    }

    try {
      FilePathService.validateTransferId(transferId);
    } on ArgumentError catch (e) {
      throw FormatException('Invalid transferId: ${e.message}');
    }

    _validateIdentifier(originId, 'originId');
    _validateIdentifier(destinationId, 'destinationId');
    _validateIdentifier(sessionId, 'sessionId');

    if (originId == destinationId) {
      throw const FormatException('originId and destinationId cannot be identical');
    }

    if (epoch < 0 || epoch > 0xFFFFFFFF) {
      throw FormatException('epoch out of range [0, 0xFFFFFFFF] (got $epoch)');
    }
    if (sequenceNumber < 0 || sequenceNumber > 0xFFFFFFFF) {
      throw FormatException(
        'sequenceNumber out of range [0, 0xFFFFFFFF] (got $sequenceNumber)',
      );
    }
    if (chunkIndex < 0 || chunkIndex > 0xFFFFFFFF) {
      throw FormatException('chunkIndex out of range [0, 0xFFFFFFFF] (got $chunkIndex)');
    }
    if (totalChunks < 0 || totalChunks > 0xFFFFFFFF) {
      throw FormatException('totalChunks out of range [0, 0xFFFFFFFF] (got $totalChunks)');
    }
    if (totalChunks > 0 && chunkIndex >= totalChunks) {
      throw FormatException(
        'chunkIndex ($chunkIndex) must be less than totalChunks ($totalChunks)',
      );
    }

    if (ackType == ChunkAckType.ack && nackReason != null) {
      throw const FormatException('ACK messages must not include a nackReason');
    }
    if (ackType == ChunkAckType.nack && nackReason == null) {
      throw const FormatException('NACK messages must specify a nackReason');
    }

    if (nonce.length != 12) {
      throw FormatException('nonce must be exactly 12 bytes (got ${nonce.length})');
    }
    if (mac.length != 16) {
      throw FormatException('mac must be exactly 16 bytes (got ${mac.length})');
    }
  }

  static void _validateIdentifier(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw FormatException('$fieldName must not be empty');
    }
    if (value.length > 128) {
      throw FormatException(
        '$fieldName length (${value.length}) exceeds maximum limit of 128',
      );
    }
    if (_controlCharRegex.hasMatch(value)) {
      throw FormatException('$fieldName contains invalid control characters');
    }
  }

  /// Converts the cryptographic components into a [SessionEncryptedPayload].
  SessionEncryptedPayload toEncryptedPayload() {
    return SessionEncryptedPayload(
      nonce: nonce,
      ciphertext: ciphertext,
      mac: mac,
    );
  }

  /// Map serialization using Base64URL encoding for binary buffers.
  Map<String, dynamic> toMap() => {
        'version': version,
        'transferId': transferId,
        'originId': originId,
        'destinationId': destinationId,
        'sessionId': sessionId,
        'epoch': epoch,
        'sequenceNumber': sequenceNumber,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
        'ackType': ackType.toJson(),
        if (nackReason != null) 'nackReason': nackReason!.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'nonce': base64UrlEncode(nonce),
        'mac': base64UrlEncode(mac),
        'ciphertext': base64UrlEncode(ciphertext),
      };

  /// Map deserialization with validation.
  factory EncryptedChunkAckEnvelope.fromMap(
    Map<String, dynamic> map, {
    bool validate = true,
  }) {
    final version = (map['version'] as num?)?.toInt() ?? 0;
    final transferId = map['transferId'] as String? ?? '';
    final originId = map['originId'] as String? ?? '';
    final destinationId = map['destinationId'] as String? ?? '';
    final sessionId = map['sessionId'] as String? ?? '';
    final epoch = (map['epoch'] as num?)?.toInt() ?? -1;
    final sequenceNumber = (map['sequenceNumber'] as num?)?.toInt() ?? -1;
    final chunkIndex = (map['chunkIndex'] as num?)?.toInt() ?? -1;
    final totalChunks = (map['totalChunks'] as num?)?.toInt() ?? -1;
    final ackTypeStr = map['ackType'] as String? ?? '';
    final ackType = ChunkAckType.fromString(ackTypeStr);
    final nackReasonStr = map['nackReason'] as String?;
    final nackReason = ChunkNackReason.tryFromString(nackReasonStr);
    final createdAtRaw = map['createdAt'] as String?;

    if (createdAtRaw == null) {
      throw const FormatException('createdAt is required');
    }
    final createdAt = DateTime.parse(createdAtRaw).toUtc();

    final nonceStr = map['nonce'] as String?;
    final macStr = map['mac'] as String?;
    final ciphertextStr = map['ciphertext'] as String?;

    if (nonceStr == null || macStr == null || ciphertextStr == null) {
      throw const FormatException(
        'Missing required crypto fields (nonce, mac, ciphertext)',
      );
    }

    final nonce = Uint8List.fromList(base64Url.decode(nonceStr));
    final mac = Uint8List.fromList(base64Url.decode(macStr));
    final ciphertext = Uint8List.fromList(base64Url.decode(ciphertextStr));

    return EncryptedChunkAckEnvelope(
      version: version,
      transferId: transferId,
      originId: originId,
      destinationId: destinationId,
      sessionId: sessionId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      ackType: ackType,
      nackReason: nackReason,
      createdAt: createdAt,
      nonce: nonce,
      mac: mac,
      ciphertext: ciphertext,
      validate: validate,
    );
  }

  /// JSON serialization.
  String toJson() => jsonEncode(toMap());

  /// JSON deserialization.
  factory EncryptedChunkAckEnvelope.fromJson(
    String source, {
    bool validate = true,
  }) =>
      EncryptedChunkAckEnvelope.fromMap(
        jsonDecode(source) as Map<String, dynamic>,
        validate: validate,
      );

  /// Canonical binary serialization for compact transmission.
  ///
  /// Fixed Header Layout (36 bytes):
  /// - `uint16_be(version)` (2 bytes)
  /// - `uint8(ackType)` (1 byte: 0 = ack, 1 = nack)
  /// - `uint8(nackReasonIndex)` (1 byte: 0xFF if none)
  /// - `uint32_be(epoch)` (4 bytes)
  /// - `uint32_be(sequenceNumber)` (4 bytes)
  /// - `uint32_be(chunkIndex)` (4 bytes)
  /// - `uint32_be(totalChunks)` (4 bytes)
  /// - `int64_be(createdAtMillis)` (8 bytes)
  /// - `uint32_be(ciphertextLength)` (4 bytes)
  /// - `uint16_be(transferIdLen)` + utf8 bytes
  /// - `uint16_be(originIdLen)` + utf8 bytes
  /// - `uint16_be(destinationIdLen)` + utf8 bytes
  /// - `uint16_be(sessionIdLen)` + utf8 bytes
  /// - `nonce` (12 bytes)
  /// - `mac` (16 bytes)
  /// - `ciphertext` (variable bytes)
  Uint8List toBytes() {
    final builder = BytesBuilder(copy: false);

    final fixed = ByteData(32);
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
    fixed.setUint32(28, ciphertext.length, Endian.big);
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

    builder.add(nonce);
    builder.add(mac);
    builder.add(ciphertext);

    return builder.toBytes();
  }

  /// Binary deserialization.
  factory EncryptedChunkAckEnvelope.fromBytes(
    List<int> bytes, {
    bool validate = true,
  }) {
    if (bytes.length < 32 + 8 + 28) {
      throw const FormatException('Invalid binary chunk ACK envelope: too short');
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
    final ciphertextLength = data.getUint32(cursor, Endian.big);
    cursor += 4;

    String readPrefixedString() {
      if (cursor + 2 > bytes.length) {
        throw const FormatException('Unexpected EOF reading string length');
      }
      final len = data.getUint16(cursor, Endian.big);
      cursor += 2;
      if (cursor + len > bytes.length) {
        throw const FormatException('Unexpected EOF reading string content');
      }
      final strBytes = bytes.sublist(cursor, cursor + len);
      cursor += len;
      return utf8.decode(strBytes);
    }

    final transferId = readPrefixedString();
    final originId = readPrefixedString();
    final destinationId = readPrefixedString();
    final sessionId = readPrefixedString();

    if (cursor + 12 + 16 + ciphertextLength > bytes.length) {
      throw const FormatException('Unexpected EOF reading crypto payload');
    }

    final nonce = Uint8List.fromList(bytes.sublist(cursor, cursor + 12));
    cursor += 12;
    final mac = Uint8List.fromList(bytes.sublist(cursor, cursor + 16));
    cursor += 16;
    final ciphertext = Uint8List.fromList(bytes.sublist(cursor, cursor + ciphertextLength));

    return EncryptedChunkAckEnvelope(
      version: version,
      transferId: transferId,
      originId: originId,
      destinationId: destinationId,
      sessionId: sessionId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      ackType: ackType,
      nackReason: nackReason,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis, isUtc: true),
      nonce: nonce,
      mac: mac,
      ciphertext: ciphertext,
      validate: validate,
    );
  }
}
