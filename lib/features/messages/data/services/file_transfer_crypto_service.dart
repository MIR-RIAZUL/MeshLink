import 'dart:convert';
import 'dart:typed_data';

import 'package:meshlink/features/messages/data/models/encrypted_file_chunk_envelope.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/domain/models/file_chunk.dart';

export 'package:meshlink/features/messages/data/models/encrypted_file_chunk_envelope.dart';

/// Exception thrown when file transfer cryptographic operations or validations fail.
class FileTransferCryptoException extends DirectionalEncryptionException {
  const FileTransferCryptoException(super.message);

  @override
  String toString() => 'FileTransferCryptoException: $message';
}

/// Service providing canonical AAD construction, chunk encryption, and chunk decryption
/// for MeshLink offline file transfers.
///
/// Phase 8 Step 8: Cryptographic Protocol & AAD Construction.
///
/// Cryptographic properties:
/// - Reuses Phase 7 directional session security: X25519 shared secret, HKDF-SHA256
///   directional keys (sendKey / receiveKey), and ChaCha20-Poly1305 AEAD.
/// - Authenticates complete chunk metadata in canonical binary AAD:
///   domain separator (`MESHLINK-FILE-CHUNK-v2`), protocol version (2), packet type,
///   transferId, originId, destinationId, sessionId, epoch, sequenceNumber, chunkIndex,
///   totalChunks, offset, and chunkLength.
/// - Fails closed: any tampering with ciphertext, nonce, MAC tag, or any AAD metadata field
///   immediately throws [FileTransferCryptoException] with zero plaintext leakage.
/// - In-memory only: raw session keys and secret materials are never written to disk or SQLite.
class FileTransferCryptoService {
  FileTransferCryptoService({
    DirectionalSessionEncryptionService? encryptionService,
  }) : _encryptionService = encryptionService ?? DirectionalSessionEncryptionService();

  final DirectionalSessionEncryptionService _encryptionService;

  /// Dedicated domain separator ensuring file chunk encryption cannot be confused
  /// with ordinary text messages.
  static const String domainSeparator = 'MESHLINK-FILE-CHUNK-v2';

  /// Packet type identifier bound into the canonical AAD.
  static const String defaultPacketType = 'file_chunk';

  /// Protocol version for MeshLink v2 file transfer cryptography.
  static const int protocolVersion = 2;

  /// Validates chunk metadata parameters strictly according to protocol rules.
  static void validateChunkMetadata({
    required String transferId,
    required String originId,
    required String destinationId,
    required int chunkIndex,
    required int totalChunks,
    required int offset,
    required int chunkLength,
    int? plaintextLength,
  }) {
    try {
      FilePathService.validateTransferId(transferId);
    } on ArgumentError catch (e) {
      throw FileTransferCryptoException('Invalid transferId: ${e.message}');
    }

    _validateIdentifier(originId, 'originId');
    _validateIdentifier(destinationId, 'destinationId');

    if (chunkIndex < 0 || chunkIndex > 0xFFFFFFFF) {
      throw FileTransferCryptoException(
        'chunkIndex out of range [0, 0xFFFFFFFF] (got $chunkIndex)',
      );
    }
    if (totalChunks < 0 || totalChunks > 0xFFFFFFFF) {
      throw FileTransferCryptoException(
        'totalChunks out of range [0, 0xFFFFFFFF] (got $totalChunks)',
      );
    }
    if (totalChunks > 0 && chunkIndex >= totalChunks) {
      throw FileTransferCryptoException(
        'chunkIndex ($chunkIndex) must be less than totalChunks ($totalChunks)',
      );
    }
    if (totalChunks == 0 && chunkIndex != 0) {
      throw FileTransferCryptoException(
        'chunkIndex must be 0 when totalChunks is 0 (got $chunkIndex)',
      );
    }
    if (offset < 0) {
      throw FileTransferCryptoException('offset cannot be negative ($offset)');
    }
    if (chunkLength < 0 || chunkLength > 0xFFFFFFFF) {
      throw FileTransferCryptoException(
        'chunkLength out of range [0, 0xFFFFFFFF] (got $chunkLength)',
      );
    }
    if (plaintextLength != null && chunkLength != plaintextLength) {
      throw FileTransferCryptoException(
        'chunkLength ($chunkLength) must match plaintext length ($plaintextLength)',
      );
    }
    if (offset > 0x7FFFFFFFFFFFFFFF - chunkLength || offset + chunkLength < 0) {
      throw const FileTransferCryptoException('offset + chunkLength arithmetic overflow');
    }
  }

  /// Constructs canonical binary Authenticated Additional Data (AAD) for a file chunk.
  ///
  /// Layout:
  /// 1. `uint16_be(domainLen)` + utf8(`MESHLINK-FILE-CHUNK-v2`) (24 bytes)
  /// 2. `uint16_be(version)` (2 bytes)
  /// 3. `uint16_be(packetTypeLen)` + utf8(`packetType`)
  /// 4. `uint16_be(transferIdLen)` + utf8(`transferId`)
  /// 5. `uint16_be(originIdLen)` + utf8(`originId`)
  /// 6. `uint16_be(destinationIdLen)` + utf8(`destinationId`)
  /// 7. `uint16_be(sessionIdLen)` + utf8(`sessionId`)
  /// 8. `uint32_be(epoch)` (4 bytes)
  /// 9. `uint64_be(sequenceNumber)` (8 bytes)
  /// 10. `uint32_be(chunkIndex)` (4 bytes)
  /// 11. `uint32_be(totalChunks)` (4 bytes)
  /// 12. `uint64_be(offset)` (8 bytes)
  /// 13. `uint32_be(chunkLength)` (4 bytes)
  static Uint8List buildChunkAad({
    int version = protocolVersion,
    String packetType = defaultPacketType,
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
  }) {
    if (version != protocolVersion) {
      throw FileTransferCryptoException(
        'Unsupported protocol version: $version (expected $protocolVersion)',
      );
    }

    validateChunkMetadata(
      transferId: transferId,
      originId: originId,
      destinationId: destinationId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      offset: offset,
      chunkLength: chunkLength,
    );

    _validateIdentifier(sessionId, 'sessionId');
    _validateIdentifier(packetType, 'packetType');

    if (epoch < 0 || epoch > 0xFFFFFFFF) {
      throw FileTransferCryptoException('epoch out of range [0, 0xFFFFFFFF] (got $epoch)');
    }
    if (sequenceNumber < 0) {
      throw FileTransferCryptoException(
        'sequenceNumber cannot be negative ($sequenceNumber)',
      );
    }

    final builder = BytesBuilder(copy: false);

    void addPrefixedString(String s, String fieldName) {
      final strBytes = utf8.encode(s);
      if (strBytes.length > 65535) {
        throw FileTransferCryptoException(
          '$fieldName byte length (${strBytes.length}) exceeds 16-bit limit',
        );
      }
      final lenData = ByteData(2)..setUint16(0, strBytes.length, Endian.big);
      builder.add(lenData.buffer.asUint8List());
      builder.add(strBytes);
    }

    // 1. Domain separator
    addPrefixedString(domainSeparator, 'domainSeparator');

    // 2. Protocol version
    final verData = ByteData(2)..setUint16(0, version, Endian.big);
    builder.add(verData.buffer.asUint8List());

    // 3. Packet type
    addPrefixedString(packetType, 'packetType');

    // 4. Transfer ID
    addPrefixedString(transferId, 'transferId');

    // 5. Origin ID
    addPrefixedString(originId, 'originId');

    // 6. Destination ID
    addPrefixedString(destinationId, 'destinationId');

    // 7. Session ID
    addPrefixedString(sessionId, 'sessionId');

    // 8-13. Fixed-width numeric fields: epoch (4), seq (8), chunkIndex (4), totalChunks (4), offset (8), chunkLength (4)
    final numData = ByteData(32);
    numData.setUint32(0, epoch, Endian.big);
    numData.setUint64(4, sequenceNumber, Endian.big);
    numData.setUint32(12, chunkIndex, Endian.big);
    numData.setUint32(16, totalChunks, Endian.big);
    numData.setUint64(20, offset, Endian.big);
    numData.setUint32(28, chunkLength, Endian.big);
    builder.add(numData.buffer.asUint8List());

    return builder.toBytes();
  }

  static void _validateIdentifier(String id, String fieldName) {
    if (id.isEmpty) {
      throw FileTransferCryptoException('$fieldName cannot be empty');
    }
    if (id.length > 128) {
      throw FileTransferCryptoException(
        '$fieldName exceeds maximum length of 128 characters',
      );
    }
    for (int i = 0; i < id.length; i++) {
      final code = id.codeUnitAt(i);
      if (code < 0x20 || code == 0x7F) {
        throw FileTransferCryptoException(
          '$fieldName contains invalid control characters',
        );
      }
    }
  }

  /// Encrypts [plaintext] file chunk under [session] directional key and binds all
  /// transfer metadata into a canonical AAD envelope.
  ///
  /// Parameters:
  /// - [session]: Active authenticated [EphemeralSession].
  /// - [transferId]: Valid transfer identifier.
  /// - [originId]: Transfer sender device identifier.
  /// - [destinationId]: Transfer destination device identifier.
  /// - [chunkIndex]: 0-based chunk index.
  /// - [totalChunks]: Total chunks in file.
  /// - [offset]: Byte offset in staging/target file.
  /// - [plaintext]: Binary content of chunk.
  /// - [chunkLength]: Optional chunkLength override (must match plaintext length if provided).
  /// - [sequenceNumber]: Optional sequence number override (defaults to [session.sequenceNumber]).
  /// - [explicitNonce]: Optional 12-byte nonce override for deterministic testing.
  Future<EncryptedFileChunkEnvelope> encryptChunk({
    required EphemeralSession session,
    required String transferId,
    required String originId,
    required String destinationId,
    required int chunkIndex,
    required int totalChunks,
    required int offset,
    required Uint8List plaintext,
    int? chunkLength,
    int? sequenceNumber,
    Uint8List? explicitNonce,
  }) async {
    if (session.isDestroyed) {
      throw const FileTransferCryptoException('Cannot encrypt chunk: session is destroyed');
    }
    if (session.state != SessionLifecycleState.activeSession) {
      throw FileTransferCryptoException(
        'Cannot encrypt chunk: session is in invalid lifecycle state (${session.state})',
      );
    }

    final effectiveChunkLength = chunkLength ?? plaintext.length;

    validateChunkMetadata(
      transferId: transferId,
      originId: originId,
      destinationId: destinationId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      offset: offset,
      chunkLength: effectiveChunkLength,
      plaintextLength: plaintext.length,
    );

    final seq = sequenceNumber ?? session.sequenceNumber;

    final aad = buildChunkAad(
      version: protocolVersion,
      packetType: defaultPacketType,
      transferId: transferId,
      originId: originId,
      destinationId: destinationId,
      sessionId: session.sessionId,
      epoch: session.epoch,
      sequenceNumber: seq,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      offset: offset,
      chunkLength: effectiveChunkLength,
    );

    try {
      final payload = await _encryptionService.encrypt(
        session: session,
        plaintext: plaintext,
        aad: aad,
        explicitNonce: explicitNonce,
      );

      return EncryptedFileChunkEnvelope.fromPayload(
        version: protocolVersion,
        transferId: transferId,
        originId: originId,
        destinationId: destinationId,
        sessionId: session.sessionId,
        epoch: session.epoch,
        sequenceNumber: seq,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        offset: offset,
        chunkLength: effectiveChunkLength,
        payload: payload,
      );
    } on DirectionalEncryptionException catch (e) {
      throw FileTransferCryptoException('Encryption failed: ${e.message}');
    } catch (e) {
      throw FileTransferCryptoException('Encryption failed: $e');
    }
  }

  /// Convenience helper to encrypt a chunk using a [FileChunk] DTO.
  Future<EncryptedFileChunkEnvelope> encryptChunkFromMetadata({
    required EphemeralSession session,
    required FileChunk chunk,
    required String originId,
    required String destinationId,
    required Uint8List plaintext,
    int? sequenceNumber,
    Uint8List? explicitNonce,
  }) {
    return encryptChunk(
      session: session,
      transferId: chunk.transferId,
      originId: originId,
      destinationId: destinationId,
      chunkIndex: chunk.chunkIndex,
      totalChunks: chunk.totalChunks,
      offset: chunk.offset,
      chunkLength: chunk.chunkLength,
      plaintext: plaintext,
      sequenceNumber: sequenceNumber,
      explicitNonce: explicitNonce,
    );
  }

  /// Decrypts [envelope] using the session's directional receiveKey after reconstructing
  /// and verifying the canonical binary AAD.
  ///
  /// Fails closed: any modification to ciphertext, MAC tag, nonce, or metadata throws
  /// [FileTransferCryptoException] with zero plaintext leakage.
  Future<Uint8List> decryptChunk({
    required EphemeralSession session,
    required EncryptedFileChunkEnvelope envelope,
  }) async {
    try {
      envelope.validate();
    } on FormatException catch (e) {
      throw FileTransferCryptoException('Envelope validation failed: ${e.message}');
    }

    if (session.isDestroyed) {
      throw const FileTransferCryptoException('Cannot decrypt chunk: session is destroyed');
    }
    if (session.state != SessionLifecycleState.activeSession) {
      throw FileTransferCryptoException(
        'Cannot decrypt chunk: session is in invalid lifecycle state (${session.state})',
      );
    }

    if (envelope.sessionId != session.sessionId) {
      throw FileTransferCryptoException(
        'Session ID mismatch: envelope (${envelope.sessionId}) != session (${session.sessionId})',
      );
    }
    if (envelope.epoch != session.epoch) {
      throw FileTransferCryptoException(
        'Session epoch mismatch: envelope (${envelope.epoch}) != session (${session.epoch})',
      );
    }

    final aad = buildChunkAad(
      version: envelope.version,
      packetType: defaultPacketType,
      transferId: envelope.transferId,
      originId: envelope.originId,
      destinationId: envelope.destinationId,
      sessionId: envelope.sessionId,
      epoch: envelope.epoch,
      sequenceNumber: envelope.sequenceNumber,
      chunkIndex: envelope.chunkIndex,
      totalChunks: envelope.totalChunks,
      offset: envelope.offset,
      chunkLength: envelope.chunkLength,
    );

    try {
      final plaintext = await _encryptionService.decrypt(
        session: session,
        encrypted: envelope.toSessionEncryptedPayload(),
        aad: aad,
      );
      return plaintext;
    } on DirectionalEncryptionException catch (e) {
      throw FileTransferCryptoException('Decryption authentication failed: ${e.message}');
    } catch (e) {
      throw FileTransferCryptoException('Decryption failed: $e');
    }
  }
}
