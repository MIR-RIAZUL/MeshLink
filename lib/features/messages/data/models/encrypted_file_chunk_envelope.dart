import 'dart:convert';
import 'dart:typed_data';

import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';

/// Strongly-typed immutable envelope representing an encrypted file chunk.
///
/// Phase 8 Step 8: Cryptographic Protocol & AAD Construction.
///
/// Binds authenticated transfer metadata to ChaCha20-Poly1305 ciphertext.
class EncryptedFileChunkEnvelope {
  EncryptedFileChunkEnvelope({
    required this.version,
    required this.transferId,
    required this.originId,
    required this.destinationId,
    required this.sessionId,
    required this.epoch,
    required this.sequenceNumber,
    required this.chunkIndex,
    required this.totalChunks,
    required this.offset,
    required this.chunkLength,
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

  /// Expected protocol version for MeshLink file chunk envelopes.
  static const int currentProtocolVersion = 2;

  /// Protocol version (must be 2).
  final int version;

  /// Unique transfer identifier.
  final String transferId;

  /// Device ID of origin sender.
  final String originId;

  /// Device ID of destination receiver.
  final String destinationId;

  /// Authenticated ephemeral session ID.
  final String sessionId;

  /// Monotonically increasing session epoch (0 for initial, 1+ for rekeys).
  final int epoch;

  /// Session sequence number bound to this chunk transmission.
  final int sequenceNumber;

  /// 0-based chunk index within the transfer.
  final int chunkIndex;

  /// Total chunks in the file transfer.
  final int totalChunks;

  /// Byte offset of this chunk in the staging/destination file.
  final int offset;

  /// Plaintext and ciphertext byte length of this chunk.
  final int chunkLength;

  /// Exactly 12-byte ChaCha20-Poly1305 nonce.
  final Uint8List nonce;

  /// Exactly 16-byte Poly1305 authentication tag.
  final Uint8List mac;

  /// Raw ciphertext bytes produced by ChaCha20.
  final Uint8List ciphertext;

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

    if (epoch < 0 || epoch > 0xFFFFFFFF) {
      throw FormatException('epoch out of range [0, 0xFFFFFFFF] (got $epoch)');
    }
    if (sequenceNumber < 0) {
      throw FormatException('sequenceNumber cannot be negative ($sequenceNumber)');
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
    if (totalChunks == 0 && chunkIndex != 0) {
      throw FormatException(
        'chunkIndex must be 0 when totalChunks is 0 (got $chunkIndex)',
      );
    }
    if (offset < 0) {
      throw FormatException('offset cannot be negative ($offset)');
    }
    if (chunkLength < 0 || chunkLength > 0xFFFFFFFF) {
      throw FormatException('chunkLength out of range [0, 0xFFFFFFFF] (got $chunkLength)');
    }
    if (offset > 0x7FFFFFFFFFFFFFFF - chunkLength || offset + chunkLength < 0) {
      throw const FormatException('offset + chunkLength arithmetic overflow');
    }
    if (nonce.length != 12) {
      throw FormatException(
        'Invalid nonce length: must be exactly 12 bytes (got ${nonce.length})',
      );
    }
    if (mac.length != 16) {
      throw FormatException(
        'Invalid MAC tag length: must be exactly 16 bytes (got ${mac.length})',
      );
    }
    if (ciphertext.length != chunkLength) {
      throw FormatException(
        'Ciphertext length (${ciphertext.length}) does not match chunkLength ($chunkLength)',
      );
    }
  }

  static void _validateIdentifier(String id, String fieldName) {
    if (id.isEmpty) {
      throw FormatException('$fieldName cannot be empty');
    }
    if (id.length > 128) {
      throw FormatException(
        '$fieldName exceeds maximum length of 128 characters',
      );
    }
    for (int i = 0; i < id.length; i++) {
      final code = id.codeUnitAt(i);
      if (code < 0x20 || code == 0x7F) {
        throw FormatException(
          '$fieldName contains invalid control characters',
        );
      }
    }
  }

  /// Converts the cryptographic components into a [SessionEncryptedPayload].
  SessionEncryptedPayload toSessionEncryptedPayload() =>
      SessionEncryptedPayload(nonce: nonce, ciphertext: ciphertext, mac: mac);

  /// Constructs an envelope from a [SessionEncryptedPayload].
  factory EncryptedFileChunkEnvelope.fromPayload({
    required int version,
    required String transferId,
    required String originId,
    required String destinationId,
    required String sessionId,
    required int epoch,
    required int sequenceNumber,
    required int chunkIndex,
    required int totalChunks,
    required int offset,
    required int chunkLength,
    required SessionEncryptedPayload payload,
    bool validate = true,
  }) =>
      EncryptedFileChunkEnvelope(
        version: version,
        transferId: transferId,
        originId: originId,
        destinationId: destinationId,
        sessionId: sessionId,
        epoch: epoch,
        sequenceNumber: sequenceNumber,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        offset: offset,
        chunkLength: chunkLength,
        nonce: payload.nonce,
        mac: payload.mac,
        ciphertext: payload.ciphertext,
        validate: validate,
      );

  /// Creates a copy of this envelope with optional updated fields.
  EncryptedFileChunkEnvelope copyWith({
    int? version,
    String? transferId,
    String? originId,
    String? destinationId,
    String? sessionId,
    int? epoch,
    int? sequenceNumber,
    int? chunkIndex,
    int? totalChunks,
    int? offset,
    int? chunkLength,
    List<int>? nonce,
    List<int>? mac,
    List<int>? ciphertext,
    bool validate = false,
  }) =>
      EncryptedFileChunkEnvelope(
        version: version ?? this.version,
        transferId: transferId ?? this.transferId,
        originId: originId ?? this.originId,
        destinationId: destinationId ?? this.destinationId,
        sessionId: sessionId ?? this.sessionId,
        epoch: epoch ?? this.epoch,
        sequenceNumber: sequenceNumber ?? this.sequenceNumber,
        chunkIndex: chunkIndex ?? this.chunkIndex,
        totalChunks: totalChunks ?? this.totalChunks,
        offset: offset ?? this.offset,
        chunkLength: chunkLength ?? this.chunkLength,
        nonce: nonce ?? this.nonce,
        mac: mac ?? this.mac,
        ciphertext: ciphertext ?? this.ciphertext,
        validate: validate,
      );

  /// Serializes into Map using Base64URL encoding for binary payloads.
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
        'offset': offset,
        'chunkLength': chunkLength,
        'nonce': base64UrlEncode(nonce),
        'mac': base64UrlEncode(mac),
        'ciphertext': base64UrlEncode(ciphertext),
      };

  /// Deserializes and strictly validates an envelope from a Map.
  factory EncryptedFileChunkEnvelope.fromMap(Map<String, dynamic> map) {
    const requiredKeys = [
      'version',
      'transferId',
      'originId',
      'destinationId',
      'sessionId',
      'epoch',
      'sequenceNumber',
      'chunkIndex',
      'totalChunks',
      'offset',
      'chunkLength',
      'nonce',
      'mac',
      'ciphertext',
    ];
    for (final key in requiredKeys) {
      if (!map.containsKey(key) || map[key] == null) {
        throw FormatException('Missing required field: $key');
      }
    }

    final versionVal = map['version'];
    if (versionVal is! num) {
      throw const FormatException('version must be a number');
    }
    final version = versionVal.toInt();

    final transferId = map['transferId'];
    if (transferId is! String) {
      throw const FormatException('transferId must be a string');
    }

    final originId = map['originId'];
    if (originId is! String) {
      throw const FormatException('originId must be a string');
    }

    final destinationId = map['destinationId'];
    if (destinationId is! String) {
      throw const FormatException('destinationId must be a string');
    }

    final sessionId = map['sessionId'];
    if (sessionId is! String) {
      throw const FormatException('sessionId must be a string');
    }

    final epochVal = map['epoch'];
    if (epochVal is! num) {
      throw const FormatException('epoch must be a number');
    }
    final epoch = epochVal.toInt();

    final seqVal = map['sequenceNumber'];
    if (seqVal is! num) {
      throw const FormatException('sequenceNumber must be a number');
    }
    final sequenceNumber = seqVal.toInt();

    final chunkIndexVal = map['chunkIndex'];
    if (chunkIndexVal is! num) {
      throw const FormatException('chunkIndex must be a number');
    }
    final chunkIndex = chunkIndexVal.toInt();

    final totalChunksVal = map['totalChunks'];
    if (totalChunksVal is! num) {
      throw const FormatException('totalChunks must be a number');
    }
    final totalChunks = totalChunksVal.toInt();

    final offsetVal = map['offset'];
    if (offsetVal is! num) {
      throw const FormatException('offset must be a number');
    }
    final offset = offsetVal.toInt();

    final chunkLengthVal = map['chunkLength'];
    if (chunkLengthVal is! num) {
      throw const FormatException('chunkLength must be a number');
    }
    final chunkLength = chunkLengthVal.toInt();

    Uint8List decodeBase64(dynamic val, String name) {
      if (val is! String) {
        throw FormatException('$name must be a base64 string');
      }
      try {
        final normalized = base64.normalize(val.replaceAll('-', '+').replaceAll('_', '/'));
        return Uint8List.fromList(base64Decode(normalized));
      } catch (e) {
        throw FormatException('Invalid base64 encoding in $name: $e');
      }
    }

    final nonce = decodeBase64(map['nonce'], 'nonce');
    final mac = decodeBase64(map['mac'], 'mac');
    final ciphertext = decodeBase64(map['ciphertext'], 'ciphertext');

    return EncryptedFileChunkEnvelope(
      version: version,
      transferId: transferId,
      originId: originId,
      destinationId: destinationId,
      sessionId: sessionId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      offset: offset,
      chunkLength: chunkLength,
      nonce: nonce,
      mac: mac,
      ciphertext: ciphertext,
    );
  }

  /// Serializes into JSON string.
  String toJson() => jsonEncode(toMap());

  /// Deserializes from JSON string.
  factory EncryptedFileChunkEnvelope.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JSON payload is not a Map');
      }
      return EncryptedFileChunkEnvelope.fromMap(decoded);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Malformed JSON: $e');
    }
  }

  /// Canonical binary serialization for compact transmission.
  ///
  /// Layout:
  /// - `uint16_be(version)` (2 bytes)
  /// - `uint32_be(epoch)` (4 bytes)
  /// - `uint64_be(sequenceNumber)` (8 bytes)
  /// - `uint32_be(chunkIndex)` (4 bytes)
  /// - `uint32_be(totalChunks)` (4 bytes)
  /// - `uint64_be(offset)` (8 bytes)
  /// - `uint32_be(chunkLength)` (4 bytes)
  /// - `uint16_be(transferIdLen)` + utf8 bytes
  /// - `uint16_be(originIdLen)` + utf8 bytes
  /// - `uint16_be(destinationIdLen)` + utf8 bytes
  /// - `uint16_be(sessionIdLen)` + utf8 bytes
  /// - 12 bytes nonce
  /// - 16 bytes mac
  /// - `chunkLength` bytes ciphertext
  Uint8List toBytes() {
    final builder = BytesBuilder(copy: false);

    final numData = ByteData(34);
    numData.setUint16(0, version, Endian.big);
    numData.setUint32(2, epoch, Endian.big);
    numData.setUint64(6, sequenceNumber, Endian.big);
    numData.setUint32(14, chunkIndex, Endian.big);
    numData.setUint32(18, totalChunks, Endian.big);
    numData.setUint64(22, offset, Endian.big);
    numData.setUint32(30, chunkLength, Endian.big);
    builder.add(numData.buffer.asUint8List());

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

  /// Deserializes an envelope from canonical binary format.
  factory EncryptedFileChunkEnvelope.fromBytes(List<int> bytes) {
    if (bytes.length < 34 + 8 + 12 + 16) {
      throw const FormatException('Invalid binary envelope: byte stream is too short');
    }

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    int cursor = 0;

    final version = data.getUint16(cursor, Endian.big);
    cursor += 2;
    final epoch = data.getUint32(cursor, Endian.big);
    cursor += 4;
    final sequenceNumber = data.getUint64(cursor, Endian.big);
    cursor += 8;
    final chunkIndex = data.getUint32(cursor, Endian.big);
    cursor += 4;
    final totalChunks = data.getUint32(cursor, Endian.big);
    cursor += 4;
    final offset = data.getUint64(cursor, Endian.big);
    cursor += 8;
    final chunkLength = data.getUint32(cursor, Endian.big);
    cursor += 4;

    String readPrefixedString() {
      if (cursor + 2 > bytes.length) {
        throw const FormatException('Unexpected EOF while reading string length');
      }
      final len = data.getUint16(cursor, Endian.big);
      cursor += 2;
      if (cursor + len > bytes.length) {
        throw const FormatException('Unexpected EOF while reading string content');
      }
      final strBytes = bytes.sublist(cursor, cursor + len);
      cursor += len;
      return utf8.decode(strBytes);
    }

    final transferId = readPrefixedString();
    final originId = readPrefixedString();
    final destinationId = readPrefixedString();
    final sessionId = readPrefixedString();

    if (cursor + 12 > bytes.length) {
      throw const FormatException('Unexpected EOF while reading nonce');
    }
    final nonce = Uint8List.fromList(bytes.sublist(cursor, cursor + 12));
    cursor += 12;

    if (cursor + 16 > bytes.length) {
      throw const FormatException('Unexpected EOF while reading MAC tag');
    }
    final mac = Uint8List.fromList(bytes.sublist(cursor, cursor + 16));
    cursor += 16;

    if (cursor + chunkLength != bytes.length) {
      throw FormatException(
        'Binary envelope length mismatch: expected $chunkLength ciphertext bytes, but remaining is ${bytes.length - cursor}',
      );
    }
    final ciphertext = Uint8List.fromList(bytes.sublist(cursor, cursor + chunkLength));

    return EncryptedFileChunkEnvelope(
      version: version,
      transferId: transferId,
      originId: originId,
      destinationId: destinationId,
      sessionId: sessionId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      offset: offset,
      chunkLength: chunkLength,
      nonce: nonce,
      mac: mac,
      ciphertext: ciphertext,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EncryptedFileChunkEnvelope) return false;
    return version == other.version &&
        transferId == other.transferId &&
        originId == other.originId &&
        destinationId == other.destinationId &&
        sessionId == other.sessionId &&
        epoch == other.epoch &&
        sequenceNumber == other.sequenceNumber &&
        chunkIndex == other.chunkIndex &&
        totalChunks == other.totalChunks &&
        offset == other.offset &&
        chunkLength == other.chunkLength &&
        _bytesEqual(nonce, other.nonce) &&
        _bytesEqual(mac, other.mac) &&
        _bytesEqual(ciphertext, other.ciphertext);
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        version,
        transferId,
        originId,
        destinationId,
        sessionId,
        epoch,
        sequenceNumber,
        chunkIndex,
        totalChunks,
        offset,
        chunkLength,
      );

  @override
  String toString() =>
      'EncryptedFileChunkEnvelope(version: $version, transferId: $transferId, chunk: $chunkIndex/$totalChunks, offset: $offset, len: $chunkLength, seq: $sequenceNumber, epoch: $epoch)';
}
