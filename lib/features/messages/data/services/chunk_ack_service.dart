import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/chunk_acknowledgment.dart';
import 'package:meshlink/features/messages/data/models/encrypted_chunk_ack_envelope.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
import 'package:meshlink/features/messages/providers/messaging_providers.dart';

export 'package:meshlink/features/messages/data/models/chunk_acknowledgment.dart';
export 'package:meshlink/features/messages/data/models/encrypted_chunk_ack_envelope.dart';

/// Abstract transport contract for handing off encrypted chunk acknowledgments.
///
/// Symmetric to [ChunkTransportSender] in the sending pipeline.
abstract class ChunkAckTransportSender {
  /// Hands off [envelope] to the local transport subsystem.
  ///
  /// Returns `true` if local handoff succeeded.
  Future<bool> sendAck(EncryptedChunkAckEnvelope envelope);
}

/// Convenience adapter converting a callback closure into a [ChunkAckTransportSender].
class FunctionalChunkAckTransportSender implements ChunkAckTransportSender {
  FunctionalChunkAckTransportSender(this._sendFunction);

  final Future<bool> Function(EncryptedChunkAckEnvelope envelope) _sendFunction;

  @override
  Future<bool> sendAck(EncryptedChunkAckEnvelope envelope) =>
      _sendFunction(envelope);
}

/// Base exception class for ACK/NACK service errors.
abstract class ChunkAckException implements Exception {
  const ChunkAckException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? '$runtimeType: $message (caused by: $cause)'
      : '$runtimeType: $message';
}

/// Thrown when the transfer record is missing or in an invalid state for ACK processing.
class AckInvalidTransferException extends ChunkAckException {
  const AckInvalidTransferException(super.message, [super.cause]);
}

/// Thrown when ACK/NACK metadata does not match the transfer record.
class AckMetadataMismatchException extends ChunkAckException {
  const AckMetadataMismatchException(super.message, [super.cause]);
}

/// Thrown when the session, peer, or epoch does not match the ACK envelope.
class AckSessionMismatchException extends ChunkAckException {
  const AckSessionMismatchException(super.message, [super.cause]);
}

/// Thrown when ACK/NACK cryptographic authentication fails.
class AckAuthenticationException extends ChunkAckException {
  const AckAuthenticationException(super.message, [super.cause]);
}

/// Thrown when an ACK/NACK is rejected by Phase 7 replay protection.
class AckReplayException extends ChunkAckException {
  const AckReplayException(String message, {this.validationResult, Object? cause})
      : super(message, cause);

  final ReplayValidationResult? validationResult;
}

/// Thrown when ACK transport handoff fails.
class AckTransportException extends ChunkAckException {
  const AckTransportException(super.message, [super.cause]);
}

/// Thrown when a NACK is received indicating the remote peer rejected the chunk.
class ChunkNackReceivedException extends ChunkAckException {
  const ChunkNackReceivedException(
    super.message, {
    required this.transferId,
    required this.chunkIndex,
    required this.reason,
  });

  final String transferId;
  final int chunkIndex;
  final ChunkNackReason reason;
}

/// Thrown when waiting for an ACK times out after all retries are exhausted.
class ChunkAckTimeoutException extends ChunkAckException {
  const ChunkAckTimeoutException(
    super.message, {
    required this.transferId,
    required this.chunkIndex,
    required this.attempts,
  });

  final String transferId;
  final int chunkIndex;
  final int attempts;
}

/// Result of processing a received ACK/NACK.
class AckProcessingResult {
  const AckProcessingResult({
    required this.transferId,
    required this.chunkIndex,
    required this.ackType,
    this.nackReason,
    required this.isSuccess,
    required this.isDuplicate,
    this.error,
  });

  final String transferId;
  final int chunkIndex;
  final ChunkAckType ackType;
  final ChunkNackReason? nackReason;
  final bool isSuccess;
  final bool isDuplicate;
  final Object? error;

  @override
  String toString() =>
      'AckProcessingResult(transferId: $transferId, chunk: $chunkIndex, '
      'type: ${ackType.name}, reason: ${nackReason?.wireCode}, '
      'success: $isSuccess, duplicate: $isDuplicate)';
}

/// Service for creating, encrypting, sending, receiving, and processing
/// chunk-level ACK/NACK messages.
///
/// Phase 8 Step 12: Incremental Chunk Acknowledgment.
///
/// Architectural properties:
/// 1. **Authenticated ACK/NACK**: Each acknowledgment is encrypted via the same
///    Phase 7 directional session infrastructure (ChaCha20-Poly1305 AEAD) with
///    a dedicated domain separator (`MESHLINK-CHUNK-ACK-v2`) preventing
///    cross-protocol confusion with chunk data or negotiation messages.
/// 2. **Replay Protection**: ACK/NACK messages are subject to Phase 7 persistent
///    replay protection using the dedicated `chunk_ack` packet type.
/// 3. **Idempotency**: Duplicate ACKs for the same (transferId, chunkIndex) are
///    accepted without error or double-counting.
/// 4. **Bounded NACK Reasons**: Only a closed enum of wire codes is used —
///    no arbitrary strings, stack traces, or local paths leak to peers.
/// 5. **Non-completion Invariant**: This service NEVER marks a transfer as
///    `completed`. Whole-file integrity verification belongs to Step 13.
class ChunkAckService {
  ChunkAckService({
    required this.localDeviceId,
    required this.database,
    this.messageRepository,
    ReplayProtectionService? replayProtectionService,
    DirectionalSessionEncryptionService? encryptionService,
    FileTransferStateMachine? stateMachine,
    this.requireVerifiedPeer = false,
  })  : _encryptionService =
            encryptionService ?? DirectionalSessionEncryptionService(),
        _stateMachine = stateMachine ?? FileTransferStateMachine.instance,
        _replayProtectionService = replayProtectionService ??
            (messageRepository != null
                ? ReplayProtectionService(repository: messageRepository)
                : null);

  final String localDeviceId;
  final AppDatabase database;
  final MessageRepository? messageRepository;
  final ReplayProtectionService? _replayProtectionService;
  final DirectionalSessionEncryptionService _encryptionService;
  final FileTransferStateMachine _stateMachine;
  final bool requireVerifiedPeer;

  /// Returns the underlying [DirectionalSessionEncryptionService].
  DirectionalSessionEncryptionService get encryptionService =>
      _encryptionService;

  /// Returns the underlying [ReplayProtectionService], if configured.
  ReplayProtectionService? get replayProtectionService =>
      _replayProtectionService;

  /// Returns the underlying [FileTransferStateMachine].
  FileTransferStateMachine get stateMachine => _stateMachine;

  // ---------------------------------------------------------------------------
  // ACK/NACK Creation
  // ---------------------------------------------------------------------------

  /// Creates a positive ACK domain model for a successfully received chunk.
  ChunkAcknowledgment createAck({
    required String transferId,
    required int chunkIndex,
    required int totalChunks,
    required String destinationId,
    required EphemeralSession session,
    int? sequenceNumber,
    DateTime? createdAt,
  }) {
    return ChunkAcknowledgment(
      transferId: transferId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      ackType: ChunkAckType.ack,
      originId: localDeviceId,
      destinationId: destinationId,
      sessionId: session.sessionId,
      epoch: session.epoch,
      sequenceNumber: sequenceNumber ?? session.sequenceNumber,
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }

  /// Creates a NACK domain model for a rejected chunk with a bounded reason code.
  ChunkAcknowledgment createNack({
    required String transferId,
    required int chunkIndex,
    required int totalChunks,
    required String destinationId,
    required EphemeralSession session,
    required ChunkNackReason reason,
    int? sequenceNumber,
    DateTime? createdAt,
  }) {
    return ChunkAcknowledgment(
      transferId: transferId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      ackType: ChunkAckType.nack,
      nackReason: reason,
      originId: localDeviceId,
      destinationId: destinationId,
      sessionId: session.sessionId,
      epoch: session.epoch,
      sequenceNumber: sequenceNumber ?? session.sequenceNumber,
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }

  // ---------------------------------------------------------------------------
  // Canonical AAD Construction
  // ---------------------------------------------------------------------------

  /// Builds canonical binary AAD for an ACK/NACK message.
  ///
  /// Layout:
  /// 1. `uint16_be(domainLen)` + utf8(`MESHLINK-CHUNK-ACK-v2`)
  /// 2. `uint16_be(version)` (2 bytes)
  /// 3. `uint16_be(packetTypeLen)` + utf8(`chunk_ack`)
  /// 4. `uint16_be(transferIdLen)` + utf8(transferId)
  /// 5. `uint16_be(originIdLen)` + utf8(originId)
  /// 6. `uint16_be(destinationIdLen)` + utf8(destinationId)
  /// 7. `uint16_be(sessionIdLen)` + utf8(sessionId)
  /// 8. `uint32_be(epoch)` (4 bytes)
  /// 9. `uint32_be(sequenceNumber)` (4 bytes)
  /// 10. `uint32_be(chunkIndex)` (4 bytes)
  /// 11. `uint32_be(totalChunks)` (4 bytes)
  /// 12. `uint8(ackType)` (1 byte: 0 = ack, 1 = nack)
  /// 13. `uint8(nackReasonCode)` (1 byte: 0xFF if none, else index)
  /// 14. `int64_be(createdAtMillis)` (8 bytes)
  static Uint8List buildAckAad({
    required int version,
    required String transferId,
    required String originId,
    required String destinationId,
    required String sessionId,
    required int epoch,
    required int sequenceNumber,
    required int chunkIndex,
    required int totalChunks,
    required ChunkAckType ackType,
    ChunkNackReason? nackReason,
    required DateTime createdAt,
  }) {
    final builder = BytesBuilder(copy: false);

    void addPrefixedString(String s) {
      final strBytes = utf8.encode(s);
      final len = ByteData(2)..setUint16(0, strBytes.length, Endian.big);
      builder.add(len.buffer.asUint8List());
      builder.add(strBytes);
    }

    // 1. Domain separator
    addPrefixedString(ChunkAcknowledgment.domainSeparator);

    // 2. Protocol version
    final verData = ByteData(2)..setUint16(0, version, Endian.big);
    builder.add(verData.buffer.asUint8List());

    // 3. Packet type
    addPrefixedString(ChunkAcknowledgment.packetType);

    // 4-7. Identifiers
    addPrefixedString(transferId);
    addPrefixedString(originId);
    addPrefixedString(destinationId);
    addPrefixedString(sessionId);

    // 8-14. Numeric & categorical fields
    final fixedData = ByteData(26);
    fixedData.setUint32(0, epoch, Endian.big);
    fixedData.setUint32(4, sequenceNumber, Endian.big);
    fixedData.setUint32(8, chunkIndex, Endian.big);
    fixedData.setUint32(12, totalChunks, Endian.big);
    fixedData.setUint8(16, ackType == ChunkAckType.ack ? 0 : 1);
    fixedData.setUint8(
      17,
      nackReason != null ? ChunkNackReason.values.indexOf(nackReason) : 0xFF,
    );
    fixedData.setInt64(18, createdAt.toUtc().millisecondsSinceEpoch, Endian.big);
    builder.add(fixedData.buffer.asUint8List());

    return builder.toBytes();
  }

  // ---------------------------------------------------------------------------
  // Encryption & Sending
  // ---------------------------------------------------------------------------

  /// Encrypts a [ChunkAcknowledgment] into an [EncryptedChunkAckEnvelope]
  /// under the session's directional key using ChaCha20-Poly1305 with canonical AAD.
  Future<EncryptedChunkAckEnvelope> encryptAck({
    required ChunkAcknowledgment ack,
    required EphemeralSession session,
    int? sequenceNumber,
  }) async {
    if (session.isDestroyed) {
      throw const AckAuthenticationException(
        'Cannot encrypt ACK: session is destroyed.',
      );
    }
    if (session.state != SessionLifecycleState.activeSession) {
      throw AckAuthenticationException(
        'Cannot encrypt ACK: session is in invalid state (${session.state}).',
      );
    }

    final seq = sequenceNumber ?? ack.sequenceNumber;
    final aad = buildAckAad(
      version: ack.version,
      transferId: ack.transferId,
      originId: ack.originId,
      destinationId: ack.destinationId,
      sessionId: ack.sessionId,
      epoch: ack.epoch,
      sequenceNumber: seq,
      chunkIndex: ack.chunkIndex,
      totalChunks: ack.totalChunks,
      ackType: ack.ackType,
      nackReason: ack.nackReason,
      createdAt: ack.createdAt,
    );

    // Plaintext payload contains the canonical binary serialization of the acknowledgment
    final plaintext = ack.toBytes();

    try {
      final payload = await _encryptionService.encrypt(
        session: session,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      return EncryptedChunkAckEnvelope(
        version: ack.version,
        transferId: ack.transferId,
        originId: ack.originId,
        destinationId: ack.destinationId,
        sessionId: ack.sessionId,
        epoch: ack.epoch,
        sequenceNumber: seq,
        chunkIndex: ack.chunkIndex,
        totalChunks: ack.totalChunks,
        ackType: ack.ackType,
        nackReason: ack.nackReason,
        createdAt: ack.createdAt,
        nonce: payload.nonce,
        mac: payload.mac,
        ciphertext: payload.ciphertext,
      );
    } on DirectionalEncryptionException catch (e) {
      throw AckAuthenticationException('ACK encryption failed: ${e.message}', e);
    } catch (e) {
      throw AckAuthenticationException('ACK encryption failed: $e', e);
    }
  }

  /// Encrypts and sends an [ack] via the provided transport.
  Future<bool> encryptAndSendAck({
    required ChunkAcknowledgment ack,
    required EphemeralSession session,
    required ChunkAckTransportSender transport,
    int? sequenceNumber,
  }) async {
    final envelope = await encryptAck(
      ack: ack,
      session: session,
      sequenceNumber: sequenceNumber,
    );

    try {
      return await transport.sendAck(envelope);
    } catch (e) {
      throw AckTransportException('ACK transport handoff failed: $e', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Decryption & Validation
  // ---------------------------------------------------------------------------

  /// Decrypts and authenticates an incoming [EncryptedChunkAckEnvelope].
  ///
  /// Fails closed: any MAC mismatch, metadata tampering, or structural error
  /// throws [AckAuthenticationException] with zero plaintext leakage.
  Future<ChunkAcknowledgment> decryptAck({
    required EphemeralSession session,
    required EncryptedChunkAckEnvelope envelope,
    DateTime? now,
  }) async {
    if (session.isDestroyed) {
      throw const AckAuthenticationException(
        'Cannot decrypt ACK: session is destroyed.',
      );
    }
    if (session.state != SessionLifecycleState.activeSession) {
      throw AckAuthenticationException(
        'Cannot decrypt ACK: session is in invalid state (${session.state}).',
      );
    }

    // 1. Session binding validation
    if (envelope.sessionId != session.sessionId) {
      throw AckSessionMismatchException(
        'ACK session ID (${envelope.sessionId}) does not match active session (${session.sessionId}).',
      );
    }
    if (envelope.epoch != session.epoch) {
      throw AckSessionMismatchException(
        'ACK epoch (${envelope.epoch}) does not match active session epoch (${session.epoch}).',
      );
    }

    // 2. Destination validation (must be addressed to this local device)
    if (envelope.destinationId != localDeviceId) {
      throw AckMetadataMismatchException(
        'ACK destination (${envelope.destinationId}) does not match local device ($localDeviceId).',
      );
    }

    // 3. Sender validation (must match the session peer)
    if (envelope.originId != session.peerId) {
      throw AckSessionMismatchException(
        'ACK origin (${envelope.originId}) does not match session peer (${session.peerId}).',
      );
    }

    // 4. Peer trust verification
    if (messageRepository != null) {
      final peer = await messageRepository!.getPeerIdentity(envelope.originId);
      if (peer != null) {
        final status = peer.trustStatus.trim().toLowerCase();
        if (status == 'compromised') {
          throw const AckAuthenticationException(
            'Cannot accept ACK: peer identity is marked as compromised.',
          );
        }
        if (requireVerifiedPeer && status != 'verified') {
          throw AckAuthenticationException(
            'Cannot accept ACK: peer trustStatus is "$status" (verified identity required).',
          );
        }
      } else if (requireVerifiedPeer) {
        throw AckAuthenticationException(
          'Cannot accept ACK: peer ${envelope.originId} identity missing (verified identity required).',
        );
      }
    }

    // 5. Reconstruct canonical AAD from envelope metadata
    final aad = buildAckAad(
      version: envelope.version,
      transferId: envelope.transferId,
      originId: envelope.originId,
      destinationId: envelope.destinationId,
      sessionId: envelope.sessionId,
      epoch: envelope.epoch,
      sequenceNumber: envelope.sequenceNumber,
      chunkIndex: envelope.chunkIndex,
      totalChunks: envelope.totalChunks,
      ackType: envelope.ackType,
      nackReason: envelope.nackReason,
      createdAt: envelope.createdAt,
    );

    // 6. Decrypt and authenticate via ChaCha20-Poly1305
    final Uint8List plaintext;
    try {
      plaintext = await _encryptionService.decrypt(
        session: session,
        encrypted: envelope.toEncryptedPayload(),
        aad: aad,
      );
    } on DirectionalEncryptionException catch (e) {
      throw AckAuthenticationException(
        'ACK cryptographic authentication failed: ${e.message}',
        e,
      );
    } catch (e) {
      throw AckAuthenticationException('ACK decryption failed: $e', e);
    }

    // 7. Deserialize decrypted plaintext and verify full field match
    final ChunkAcknowledgment decrypted;
    try {
      decrypted = ChunkAcknowledgment.fromBytes(plaintext);
    } catch (e) {
      throw AckAuthenticationException(
        'Decrypted ACK deserialization failed: $e',
        e,
      );
    }

    if (decrypted.transferId != envelope.transferId ||
        decrypted.chunkIndex != envelope.chunkIndex ||
        decrypted.totalChunks != envelope.totalChunks ||
        decrypted.ackType != envelope.ackType ||
        decrypted.nackReason != envelope.nackReason ||
        decrypted.originId != envelope.originId ||
        decrypted.destinationId != envelope.destinationId ||
        decrypted.sessionId != envelope.sessionId ||
        decrypted.epoch != envelope.epoch ||
        decrypted.sequenceNumber != envelope.sequenceNumber) {
      throw const AckAuthenticationException(
        'Decrypted ACK content does not match authenticated envelope metadata.',
      );
    }

    return decrypted;
  }

  // ---------------------------------------------------------------------------
  // ACK/NACK Processing (Sender-side)
  // ---------------------------------------------------------------------------

  /// Processes an authenticated, decrypted [ChunkAcknowledgment] on the sender side.
  ///
  /// Replay protection: evaluates against persistent replay database.
  /// Idempotency: duplicate valid ACKs are processed safely without double-counting.
  /// State safety: does NOT mark the transfer as completed (deferred to Step 13).
  Future<AckProcessingResult> processReceivedAck({
    required ChunkAcknowledgment ack,
    required EphemeralSession session,
    DateTime? packetTimestamp,
    DateTime? now,
    bool throwOnError = true,
  }) async {
    try {
      // 1. Transfer existence and direction check
      final transfer = await database.getFileTransfer(ack.transferId);
      if (transfer == null) {
        throw AckInvalidTransferException(
          'Transfer ${ack.transferId} not found in database.',
        );
      }

      if (transfer.direction != FileTransferDirection.outgoing.name) {
        throw AckInvalidTransferException(
          'Cannot process ACK for non-outgoing transfer ${ack.transferId} (direction: ${transfer.direction}).',
        );
      }

      // 2. Transfer status check
      final currentStatus = FileTransferStatus.values.firstWhere(
        (s) => s.name == transfer.status,
        orElse: () => FileTransferStatus.failed,
      );

      const validAckStatuses = {
        FileTransferStatus.transferring,
        FileTransferStatus.paused,
      };

      if (!validAckStatuses.contains(currentStatus)) {
        throw AckInvalidTransferException(
          'Cannot process ACK: transfer ${ack.transferId} is in status '
          '"${currentStatus.name}". Valid statuses: [transferring, paused].',
        );
      }

      // 3. Metadata consistency
      if (ack.totalChunks != transfer.totalChunks) {
        throw AckMetadataMismatchException(
          'ACK totalChunks (${ack.totalChunks}) does not match transfer metadata (${transfer.totalChunks}).',
        );
      }

      if (ack.chunkIndex < 0 || ack.chunkIndex >= transfer.totalChunks) {
        throw AckMetadataMismatchException(
          'ACK chunk index ${ack.chunkIndex} out of bounds [0, ${transfer.totalChunks - 1}].',
        );
      }

      // 4. Origin peer match
      if (ack.originId != transfer.peerId) {
        throw AckSessionMismatchException(
          'ACK origin (${ack.originId}) does not match transfer peer (${transfer.peerId}).',
        );
      }

      // 5. Session match
      if (ack.sessionId != session.sessionId) {
        throw AckSessionMismatchException(
          'ACK session ID (${ack.sessionId}) does not match session (${session.sessionId}).',
        );
      }
      if (ack.epoch != session.epoch) {
        throw AckSessionMismatchException(
          'ACK epoch (${ack.epoch}) does not match session epoch (${session.epoch}).',
        );
      }

      // 6. Phase 7 Replay Protection
      final effectiveTimestamp = packetTimestamp ?? ack.createdAt;
      final replayPacketId =
          '${ack.transferId}:${ack.chunkIndex}:${ack.sequenceNumber}:${ack.ackType.name}';

      if (_replayProtectionService != null) {
        final validation = _replayProtectionService.validatePacketMetadata(
          packetType: ChunkAcknowledgment.packetType,
          originId: ack.originId,
          packetId: replayPacketId,
          timestamp: effectiveTimestamp,
          now: now,
        );

        if (validation != ReplayValidationResult.accepted) {
          throw AckReplayException(
            'ACK rejected during replay metadata validation: ${validation.name}',
            validationResult: validation,
          );
        }

        final outcome = await _replayProtectionService.checkAndMarkSeen(
          packetType: ChunkAcknowledgment.packetType,
          originId: ack.originId,
          packetId: replayPacketId,
          timestamp: effectiveTimestamp,
          now: now,
        );

        if (!outcome.isAccepted) {
          // Replayed exact packet: reject or return idempotent duplicate
          if (outcome.result == ReplayValidationResult.duplicate) {
            return AckProcessingResult(
              transferId: ack.transferId,
              chunkIndex: ack.chunkIndex,
              ackType: ack.ackType,
              nackReason: ack.nackReason,
              isSuccess: true,
              isDuplicate: true,
            );
          } else {
            throw AckReplayException(
              'ACK rejected by Phase 7 replay protection: ${outcome.result.name}',
              validationResult: outcome.result,
            );
          }
        }
      }

      // 7. Process ACK vs NACK
      if (ack.isAck) {
        // Idempotency: check existing chunk state
        final existingChunk = await database.getFileChunk(
          ack.transferId,
          ack.chunkIndex,
        );

        if (existingChunk != null && existingChunk.status == 'acked') {
          return AckProcessingResult(
            transferId: ack.transferId,
            chunkIndex: ack.chunkIndex,
            ackType: ack.ackType,
            isSuccess: true,
            isDuplicate: true,
          );
        }

        // Persist chunk as acknowledged
        await database.markChunkReceived(
          ack.transferId,
          ack.chunkIndex,
          status: 'acked',
          receivedAt: now ?? DateTime.now(),
        );

        return AckProcessingResult(
          transferId: ack.transferId,
          chunkIndex: ack.chunkIndex,
          ackType: ack.ackType,
          isSuccess: true,
          isDuplicate: false,
        );
      } else {
        // NACK received
        await database.markChunkReceived(
          ack.transferId,
          ack.chunkIndex,
          status: 'nacked',
          receivedAt: now ?? DateTime.now(),
        );

        return AckProcessingResult(
          transferId: ack.transferId,
          chunkIndex: ack.chunkIndex,
          ackType: ack.ackType,
          nackReason: ack.nackReason,
          isSuccess: true,
          isDuplicate: false,
        );
      }
    } on ChunkAckException catch (e) {
      if (throwOnError) rethrow;
      return AckProcessingResult(
        transferId: ack.transferId,
        chunkIndex: ack.chunkIndex,
        ackType: ack.ackType,
        nackReason: ack.nackReason,
        isSuccess: false,
        isDuplicate: false,
        error: e,
      );
    } catch (e) {
      if (throwOnError) {
        throw AckInvalidTransferException(
          'Unexpected error processing ACK: $e',
          e,
        );
      }
      return AckProcessingResult(
        transferId: ack.transferId,
        chunkIndex: ack.chunkIndex,
        ackType: ack.ackType,
        nackReason: ack.nackReason,
        isSuccess: false,
        isDuplicate: false,
        error: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns count of acknowledged chunks for a transfer.
  Future<int> getAckedChunkCount(String transferId) async {
    final chunks = await database.getFileChunks(transferId);
    return chunks.where((c) => c.status == 'acked').length;
  }

  /// Returns count of NACKed chunks for a transfer.
  Future<int> getNackedChunkCount(String transferId) async {
    final chunks = await database.getFileChunks(transferId);
    return chunks.where((c) => c.status == 'nacked').length;
  }

  /// Returns list of chunk indices acknowledged so far.
  Future<List<int>> getAckedChunkIndices(String transferId) async {
    final chunks = await database.getFileChunks(transferId);
    return chunks
        .where((c) => c.status == 'acked')
        .map((c) => c.chunkIndex)
        .toList();
  }

  /// Returns list of chunk indices that were NACKed.
  Future<List<int>> getNackedChunkIndices(String transferId) async {
    final chunks = await database.getFileChunks(transferId);
    return chunks
        .where((c) => c.status == 'nacked')
        .map((c) => c.chunkIndex)
        .toList();
  }

  /// Checks if all chunks of a transfer have been acknowledged.
  ///
  /// NOTE: Does not mark transfer completed. Integrity verification is Step 13.
  Future<bool> areAllChunksAcked(String transferId) async {
    final transfer = await database.getFileTransfer(transferId);
    if (transfer == null) return false;
    final acked = await getAckedChunkCount(transferId);
    return acked >= transfer.totalChunks;
  }
}

class _PendingAckWaiter {
  _PendingAckWaiter({
    required this.completer,
    this.timer,
    this.sessionId,
    this.epoch,
    this.cancellationToken,
    this.cancelListener,
  });

  final Completer<ChunkAcknowledgment> completer;
  final Timer? timer;
  final String? sessionId;
  final int? epoch;
  final FileTransferCancellationToken? cancellationToken;
  final void Function()? cancelListener;
}

/// Helper tracking in-flight chunk acknowledgments on the sender side with
/// correlation, bounded timeouts, retries, and cancellation.
class ChunkAckTracker {
  ChunkAckTracker({
    this.defaultTimeout = const Duration(seconds: 5),
    this.maxRetries = 3,
  });

  final Duration defaultTimeout;
  final int maxRetries;

  final Map<String, _PendingAckWaiter> _pendingAcks = {};
  final Map<String, ChunkAcknowledgment> _unconsumedAcks = {};
  final Set<String> _cancelledTransfers = {};

  static String _key(String transferId, int chunkIndex) =>
      '$transferId:$chunkIndex';

  /// Whether [transferId] has been explicitly cancelled on this tracker.
  bool isTransferCancelled(String transferId) =>
      _cancelledTransfers.contains(transferId);

  /// Registers interest in an ACK for [transferId] and [chunkIndex].
  ///
  /// Returns a Future that completes when the matching ACK arrives, or throws
  /// [TimeoutException] after [timeout], or [ChunkSendCancelledException] if cancelled.
  Future<ChunkAcknowledgment> waitForAck({
    required String transferId,
    required int chunkIndex,
    Duration? timeout,
    FileTransferCancellationToken? cancellationToken,
    String? sessionId,
    int? epoch,
  }) async {
    final key = _key(transferId, chunkIndex);

    // Fast-path: reject if already cancelled
    if (_cancelledTransfers.contains(transferId) ||
        (cancellationToken != null && cancellationToken.isCancelled)) {
      throw ChunkSendCancelledException(
        'ACK wait cancelled for chunk $chunkIndex on transfer $transferId: ${cancellationToken?.reason ?? "cancelled"}',
      );
    }

    // If an ACK for this chunk already arrived prior to registration, consume it if it matches session/epoch.
    final existing = _unconsumedAcks.remove(key);
    if (existing != null) {
      final sessionMatches = sessionId == null || existing.sessionId == sessionId;
      final epochMatches = epoch == null || existing.epoch == epoch;
      if (sessionMatches && epochMatches) {
        return existing;
      }
      // Stale or mismatched ACK discarded
    }

    final completer = Completer<ChunkAcknowledgment>();
    final effectiveTimeout = timeout ?? defaultTimeout;
    Timer? timer;

    if (effectiveTimeout > Duration.zero) {
      timer = Timer(effectiveTimeout, () {
        if (!completer.isCompleted) {
          _pendingAcks.remove(key);
          completer.completeError(
            TimeoutException(
              'Timed out waiting for ACK of chunk $chunkIndex on transfer $transferId',
              effectiveTimeout,
            ),
          );
        }
      });
    }

    void Function()? cancelListener;
    if (cancellationToken != null) {
      cancelListener = () {
        if (!completer.isCompleted) {
          timer?.cancel();
          _pendingAcks.remove(key);
          completer.completeError(
            ChunkSendCancelledException(
              'ACK wait cancelled for chunk $chunkIndex on transfer $transferId: ${cancellationToken.reason ?? "cancelled"}',
            ),
          );
        }
      };
      cancellationToken.addListener(cancelListener);
    }

    _pendingAcks[key] = _PendingAckWaiter(
      completer: completer,
      timer: timer,
      sessionId: sessionId,
      epoch: epoch,
      cancellationToken: cancellationToken,
      cancelListener: cancelListener,
    );

    try {
      return await completer.future;
    } finally {
      timer?.cancel();
      if (cancellationToken != null && cancelListener != null) {
        cancellationToken.removeListener(cancelListener);
      }
      _pendingAcks.remove(key);
    }
  }

  /// Delivers an incoming [ChunkAcknowledgment] to any pending listener.
  ///
  /// Validates session and epoch if expected by the listener.
  /// Returns `true` if an active listener was satisfied.
  bool onAckReceived(ChunkAcknowledgment ack) {
    if (_cancelledTransfers.contains(ack.transferId)) {
      return false; // Dropped late ACK for cancelled transfer
    }

    final key = _key(ack.transferId, ack.chunkIndex);
    final waiter = _pendingAcks[key];

    if (waiter != null && !waiter.completer.isCompleted) {
      // Validate session and epoch correlation (Requirement C.8)
      if (waiter.sessionId != null && ack.sessionId != waiter.sessionId) {
        return false;
      }
      if (waiter.epoch != null && ack.epoch != waiter.epoch) {
        return false;
      }

      _pendingAcks.remove(key);
      waiter.timer?.cancel();
      if (waiter.cancellationToken != null && waiter.cancelListener != null) {
        waiter.cancellationToken!.removeListener(waiter.cancelListener!);
      }
      waiter.completer.complete(ack);
      return true;
    }

    _unconsumedAcks[key] = ack;
    if (_unconsumedAcks.length > 256) {
      _unconsumedAcks.remove(_unconsumedAcks.keys.first);
    }
    return false;
  }

  /// Cancels any pending wait for [transferId] and [chunkIndex].
  void cancelPending(String transferId, int chunkIndex) {
    final key = _key(transferId, chunkIndex);
    final waiter = _pendingAcks.remove(key);
    if (waiter != null) {
      waiter.timer?.cancel();
      if (waiter.cancellationToken != null && waiter.cancelListener != null) {
        waiter.cancellationToken!.removeListener(waiter.cancelListener!);
      }
    }
    _unconsumedAcks.remove(key);
  }

  /// Cancels all pending ACK waits for [transferId] and prevents future late ACKs.
  void cancelTransfer(String transferId, [String? reason]) {
    _cancelledTransfers.add(transferId);
    final prefix = '$transferId:';
    final keysToCancel =
        _pendingAcks.keys.where((k) => k.startsWith(prefix)).toList();
    final error = ChunkSendCancelledException(
      'ACK wait cancelled for transfer $transferId: ${reason ?? "cancelled"}',
    );
    for (final key in keysToCancel) {
      final waiter = _pendingAcks.remove(key);
      if (waiter != null) {
        waiter.timer?.cancel();
        if (waiter.cancellationToken != null && waiter.cancelListener != null) {
          waiter.cancellationToken!.removeListener(waiter.cancelListener!);
        }
        if (!waiter.completer.isCompleted) {
          waiter.completer.completeError(error);
        }
      }
    }
    _unconsumedAcks.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Cancels all pending ACK waits with optional reason.
  void cancelAll([String? reason]) {
    final error = ChunkSendCancelledException(
      'All pending ACK waits cancelled: ${reason ?? "cancelled"}',
    );
    for (final waiter in _pendingAcks.values) {
      waiter.timer?.cancel();
      if (waiter.cancellationToken != null && waiter.cancelListener != null) {
        waiter.cancellationToken!.removeListener(waiter.cancelListener!);
      }
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(error);
      }
    }
    _pendingAcks.clear();
  }

  /// Number of currently pending ACK listeners.
  int get pendingCount => _pendingAcks.length;
}

/// Riverpod provider for [ChunkAckService].
final chunkAckServiceProvider = Provider<ChunkAckService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(messageRepositoryProvider);
  final replayService = ref.watch(replayProtectionServiceProvider);
  final encryptionService =
      ref.watch(directionalSessionEncryptionServiceProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );

  return ChunkAckService(
    localDeviceId: discoveryController.localIdentity.id,
    database: db,
    messageRepository: repo,
    replayProtectionService: replayService,
    encryptionService: encryptionService,
  );
});
