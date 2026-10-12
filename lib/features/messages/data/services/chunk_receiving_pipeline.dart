import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/file_disk_writer.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
import 'package:meshlink/features/messages/providers/messaging_providers.dart';

export 'package:meshlink/features/messages/data/models/encrypted_file_chunk_envelope.dart';

/// Base exception class for chunk receiving errors.
abstract class ChunkReceivingException implements Exception {
  const ChunkReceivingException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? '$runtimeType: $message (caused by: $cause)'
      : '$runtimeType: $message';
}

/// Thrown when the transfer record does not exist in local persistence.
class TransferNotFoundException extends ChunkReceivingException {
  const TransferNotFoundException(super.message, [super.cause]);
}

/// Thrown when attempting to receive a chunk for a transfer in an invalid direction or state.
class InvalidReceivingStateException extends ChunkReceivingException {
  const InvalidReceivingStateException(super.message, [super.cause]);
}

/// Thrown when the peer fails trust verification or session peer identity does not match.
class PeerUntrustedReceivingException extends ChunkReceivingException {
  const PeerUntrustedReceivingException(super.message, [super.cause]);
}

/// Thrown when session state, ID, epoch, or active lifecycle does not match the envelope.
class SessionMismatchException extends ChunkReceivingException {
  const SessionMismatchException(super.message, [super.cause]);
}

/// Thrown when chunk index, offset, length, or total chunks violates transfer metadata invariants.
class ChunkMetadataMismatchException extends ChunkReceivingException {
  const ChunkMetadataMismatchException(super.message, [super.cause]);
}

/// Thrown when cryptographic authentication or decryption of the chunk envelope fails.
class ChunkAuthenticationException extends ChunkReceivingException {
  const ChunkAuthenticationException(super.message, [super.cause]);
}

/// Thrown when a packet is rejected by persistent replay protection (stale, future, or duplicate).
class ChunkReplayException extends ChunkReceivingException {
  const ChunkReplayException(
    String message, {
    this.validationResult,
    Object? cause,
  }) : super(message, cause);

  final ReplayValidationResult? validationResult;
}

/// Thrown when duplicate chunk delivery arrives with conflicting content for an already-staged chunk.
class ChunkContentConflictException extends ChunkReceivingException {
  const ChunkContentConflictException(super.message, [super.cause]);
}

/// Thrown when staging file disk writing or initialization fails.
class ChunkDiskWriteException extends ChunkReceivingException {
  const ChunkDiskWriteException(super.message, [super.cause]);
}

/// Summary result of a chunk receiving operation.
class ChunkReceivingResult {
  const ChunkReceivingResult({
    required this.transferId,
    required this.chunkIndex,
    required this.offset,
    required this.bytesWritten,
    required this.totalBytes,
    required this.chunksReceived,
    required this.totalChunks,
    required this.status,
    this.isDuplicate = false,
    this.isSuccess = true,
    this.error,
  });

  final String transferId;
  final int chunkIndex;
  final int offset;
  final int bytesWritten;
  final int totalBytes;
  final int chunksReceived;
  final int totalChunks;
  final FileTransferStatus status;
  final bool isDuplicate;
  final bool isSuccess;
  final Object? error;

  @override
  String toString() =>
      'ChunkReceivingResult(transferId: $transferId, chunk: $chunkIndex/$totalChunks, offset: $offset, bytes: $bytesWritten, received: $chunksReceived/$totalChunks, status: ${status.name}, isDuplicate: $isDuplicate, isSuccess: $isSuccess, error: $error)';
}

/// Core pipeline service for validating, authenticating, decrypting, and staging
/// incoming encrypted file chunks.
///
/// Phase 8 Step 11: Chunk Receiving Pipeline & Replay Verification.
///
/// Architectural properties:
/// 1. Strict Pre-flight Validation: Validates transfer existence, incoming direction,
///    valid receiving status (`acceptSent`, `transferring`, `paused`), and authenticated sender.
/// 2. Cryptographic Authentication: Fails closed on any envelope tampering, MAC mismatch,
///    or unauthenticated AAD via [FileTransferCryptoService.decryptChunk].
/// 3. Zero Leakage on Failure: Never writes unauthenticated or malformed plaintext to disk.
/// 4. Replay vs. Duplicate Separation: Replay protection enforces Phase 7 session packet
///    replay verification (`seen_packets_table`). Staged chunk duplicate delivery is handled
///    idempotently with byte-level conflict detection via `FileDiskWriter.readAt`.
/// 5. Bounded Memory: Buffers only the active chunk in memory, streaming writes directly to
///    disk via [FileDiskWriter] without whole-file buffering.
/// 6. Atomic Persistence Ordering: Receive progress in SQLite (`markChunkReceived`) advances
///    ONLY AFTER the disk write succeeds.
/// 7. Non-completion Invariant: Transfers remain in `transferring` status; whole-file
///    assembly and SHA-256 integrity verification are deferred to Step 13.
class ChunkReceivingPipeline {
  ChunkReceivingPipeline({
    required this.localDeviceId,
    required this.database,
    this.messageRepository,
    ReplayProtectionService? replayProtectionService,
    FileTransferCryptoService? cryptoService,
    FilePathService? pathService,
    FileTransferStateMachine? stateMachine,
    this.requireVerifiedPeer = false,
  })  : _cryptoService = cryptoService ?? FileTransferCryptoService(),
        _pathService = pathService ?? FilePathService(),
        _stateMachine = stateMachine ?? FileTransferStateMachine.instance,
        _replayProtectionService = replayProtectionService ??
            (messageRepository != null
                ? ReplayProtectionService(repository: messageRepository)
                : null);

  final String localDeviceId;
  final AppDatabase database;
  final MessageRepository? messageRepository;
  final ReplayProtectionService? _replayProtectionService;
  final FileTransferCryptoService _cryptoService;
  final FilePathService _pathService;
  final FileTransferStateMachine _stateMachine;
  final bool requireVerifiedPeer;

  final Map<String, FileDiskWriter> _activeWriters = <String, FileDiskWriter>{};

  /// Returns underlying [FileTransferCryptoService].
  FileTransferCryptoService get cryptoService => _cryptoService;

  /// Returns underlying [FilePathService].
  FilePathService get pathService => _pathService;

  /// Returns underlying [FileTransferStateMachine].
  FileTransferStateMachine get stateMachine => _stateMachine;

  /// Returns underlying [ReplayProtectionService], if configured.
  ReplayProtectionService? get replayProtectionService => _replayProtectionService;

  /// Returns active writer for [transferId] if open, or null.
  FileDiskWriter? getActiveWriter(String transferId) => _activeWriters[transferId];

  /// Closes and releases file handle for [transferId].
  Future<void> closeWriter(String transferId) async {
    final writer = _activeWriters.remove(transferId);
    if (writer != null && writer.isOpen) {
      await writer.close();
    }
  }

  /// Closes and releases all active staging file writers.
  Future<void> closeAll() async {
    final writers = List<FileDiskWriter>.from(_activeWriters.values);
    _activeWriters.clear();
    for (final writer in writers) {
      if (writer.isOpen) {
        await writer.close();
      }
    }
  }

  Future<FileDiskWriter> _getOrCreateWriter(FileTransferEntry transfer) async {
    final existing = _activeWriters[transfer.transferId];
    if (existing != null && existing.isOpen) {
      return existing;
    }

    var stagingPath = transfer.stagingPath;
    if (stagingPath.trim().isEmpty) {
      stagingPath = await _pathService.getStagingPath(transfer.transferId);
    }

    final stagingDir = await _pathService.getStagingDirectory(create: true);
    if (!FilePathService.isPathInsideDirectory(stagingPath, stagingDir.path)) {
      throw ChunkDiskWriteException(
        'Staging path "$stagingPath" is outside authorized staging directory "${stagingDir.path}".',
      );
    }

    final writer = FileDiskWriter(filePathService: _pathService);
    try {
      await writer.open(
        transferId: transfer.transferId,
        expectedFileSize: transfer.fileSize.toInt(),
        stagingPath: stagingPath,
      );
    } catch (e) {
      throw ChunkDiskWriteException('Failed to open staging file "$stagingPath": $e', e);
    }

    _activeWriters[transfer.transferId] = writer;
    return writer;
  }

  /// Receives, authenticates, and stages a single encrypted file chunk envelope.
  ///
  /// Parameters:
  /// - [envelope]: The strongly-typed encrypted chunk envelope.
  /// - [session]: The active authenticated ephemeral session with the sender peer.
  /// - [authenticatedSenderId]: Optional authenticated sender ID passed by the transport.
  /// - [packetTimestamp]: Optional timestamp of the packet for replay checks.
  /// - [now]: Optional clock reference for deterministic testing.
  /// - [throwOnError]: If true (default), rethrows typed exceptions on error.
  Future<ChunkReceivingResult> receiveChunk({
    required EncryptedFileChunkEnvelope envelope,
    required EphemeralSession session,
    String? authenticatedSenderId,
    DateTime? packetTimestamp,
    DateTime? now,
    bool throwOnError = true,
  }) async {
    try {
      // 1. Structural envelope validation
      try {
        envelope.validate();
      } catch (e) {
        throw ChunkMetadataMismatchException('Envelope validation failed: $e', e);
      }

      // 2. Transfer existence & direction
      final transfer = await database.getFileTransfer(envelope.transferId);
      if (transfer == null) {
        throw TransferNotFoundException(
          'Transfer ${envelope.transferId} not found in database.',
        );
      }

      if (transfer.direction != FileTransferDirection.incoming.name) {
        throw InvalidReceivingStateException(
          'Cannot receive chunk for non-incoming transfer ${envelope.transferId} (direction: ${transfer.direction}).',
        );
      }

      // 3. Receiving state validation
      final currentStatus = FileTransferStatus.values.firstWhere(
        (s) => s.name == transfer.status,
        orElse: () => FileTransferStatus.failed,
      );

      const validReceivingStatuses = {
        FileTransferStatus.acceptSent,
        FileTransferStatus.transferring,
        FileTransferStatus.paused,
      };

      if (!validReceivingStatuses.contains(currentStatus)) {
        throw InvalidReceivingStateException(
          'Cannot receive chunk: transfer ${envelope.transferId} is in status "${currentStatus.name}". Valid statuses: [acceptSent, transferring, paused].',
        );
      }

      // 4. Authenticated peer & session verification
      if (envelope.destinationId != localDeviceId) {
        throw ChunkMetadataMismatchException(
          'Envelope destination (${envelope.destinationId}) does not match local device ID ($localDeviceId).',
        );
      }

      if (envelope.originId != transfer.peerId) {
        throw ChunkMetadataMismatchException(
          'Envelope origin (${envelope.originId}) does not match transfer peerId (${transfer.peerId}).',
        );
      }

      if (authenticatedSenderId != null && authenticatedSenderId != envelope.originId) {
        throw SessionMismatchException(
          'Authenticated sender ($authenticatedSenderId) does not match envelope origin (${envelope.originId}).',
        );
      }

      if (session.peerId != envelope.originId) {
        throw SessionMismatchException(
          'Session peerId (${session.peerId}) does not match envelope origin (${envelope.originId}).',
        );
      }

      if (session.isDestroyed) {
        throw const SessionMismatchException('Cannot receive chunk: ephemeral session is destroyed.');
      }

      if (session.state != SessionLifecycleState.activeSession) {
        throw SessionMismatchException(
          'Cannot receive chunk: ephemeral session is in invalid state (${session.state}).',
        );
      }

      if (envelope.sessionId != session.sessionId) {
        throw SessionMismatchException(
          'Session ID mismatch: envelope (${envelope.sessionId}) != session (${session.sessionId}).',
        );
      }

      if (envelope.epoch != session.epoch) {
        throw SessionMismatchException(
          'Session epoch mismatch: envelope (${envelope.epoch}) != session (${session.epoch}).',
        );
      }

      // 5. Peer trust verification
      final repo = messageRepository;
      if (repo != null) {
        final peer = await repo.getPeerIdentity(transfer.peerId);
        if (peer != null) {
          final trust = peer.trustStatus.trim().toLowerCase();
          if (trust == 'compromised') {
            throw PeerUntrustedReceivingException(
              'Cannot receive transfer from peer ${transfer.peerId}: peer is marked compromised.',
            );
          }
          if (requireVerifiedPeer && trust != 'verified') {
            throw PeerUntrustedReceivingException(
              'Cannot receive transfer from peer ${transfer.peerId}: peer trustStatus is "$trust" (verified required).',
            );
          }
          try {
            final storedKey = MeshIdentityService.decodePublicKey(peer.identityPublicKey);
            if (!EphemeralSession.constantTimeCompare(session.peerIdentityPublicKey, storedKey)) {
              throw PeerUntrustedReceivingException(
                'Peer ${transfer.peerId} presented session key mismatch against stored identity record.',
              );
            }
          } catch (e) {
            if (e is PeerUntrustedReceivingException) rethrow;
            throw PeerUntrustedReceivingException(
              'Invalid stored identity key for peer ${transfer.peerId}: $e',
              e,
            );
          }
        } else if (requireVerifiedPeer) {
          throw PeerUntrustedReceivingException(
            'Cannot receive transfer from peer ${transfer.peerId}: no peer identity record found (verified required).',
          );
        }
      }

      // 6. Metadata invariants validation
      if (envelope.totalChunks != transfer.totalChunks) {
        throw ChunkMetadataMismatchException(
          'Total chunk count mismatch: envelope (${envelope.totalChunks}) != transfer metadata (${transfer.totalChunks}).',
        );
      }

      if (envelope.chunkIndex < 0 || envelope.chunkIndex >= transfer.totalChunks) {
        throw ChunkMetadataMismatchException(
          'Chunk index ${envelope.chunkIndex} is out of bounds [0, ${transfer.totalChunks - 1}].',
        );
      }

      final expectedOffset = envelope.chunkIndex * transfer.chunkSize;
      if (envelope.offset != expectedOffset) {
        throw ChunkMetadataMismatchException(
          'Offset mismatch for chunk ${envelope.chunkIndex}: envelope offset (${envelope.offset}) != expected ($expectedOffset).',
        );
      }

      final fileSize = transfer.fileSize.toInt();
      final isLastChunk = envelope.chunkIndex == transfer.totalChunks - 1;
      final expectedLength = isLastChunk
          ? (fileSize - expectedOffset)
          : transfer.chunkSize;

      if (envelope.chunkLength != expectedLength) {
        throw ChunkMetadataMismatchException(
          'Chunk length mismatch for chunk ${envelope.chunkIndex}: envelope length (${envelope.chunkLength}) != expected ($expectedLength).',
        );
      }

      if (envelope.offset + envelope.chunkLength > fileSize) {
        throw ChunkMetadataMismatchException(
          'Chunk range [${envelope.offset}, ${envelope.offset + envelope.chunkLength}] exceeds total file size ($fileSize).',
        );
      }

      // 7. Phase 7 Replay Pre-verification
      final effectiveTimestamp = packetTimestamp ?? now ?? DateTime.now();
      final replayPacketId =
          '${envelope.transferId}:${envelope.chunkIndex}:${envelope.sequenceNumber}';

      if (_replayProtectionService != null) {
        final validation = _replayProtectionService.validatePacketMetadata(
          packetType: FileTransferCryptoService.defaultPacketType,
          originId: envelope.originId,
          packetId: replayPacketId,
          timestamp: effectiveTimestamp,
          now: now,
        );

        if (validation != ReplayValidationResult.accepted) {
          throw ChunkReplayException(
            'Packet rejected during replay metadata validation: ${validation.name}',
            validationResult: validation,
          );
        }

        final isSeen = await _replayProtectionService.isSeen(
          packetType: FileTransferCryptoService.defaultPacketType,
          originId: envelope.originId,
          packetId: replayPacketId,
        );
        if (isSeen) {
          throw const ChunkReplayException(
            'Replayed session message rejected by Phase 7 replay protection',
            validationResult: ReplayValidationResult.duplicate,
          );
        }
      }

      // 8. Cryptographic Authentication & Decryption (Fails closed)
      final Uint8List plaintext;
      try {
        plaintext = await _cryptoService.decryptChunk(
          session: session,
          envelope: envelope,
        );
      } on FileTransferCryptoException catch (e) {
        throw ChunkAuthenticationException(
          'Chunk cryptographic authentication failed: ${e.message}',
          e,
        );
      } catch (e) {
        throw ChunkAuthenticationException('Decryption failed: $e', e);
      }

      if (plaintext.length != envelope.chunkLength) {
        throw ChunkMetadataMismatchException(
          'Decrypted plaintext length (${plaintext.length}) does not match envelope chunkLength (${envelope.chunkLength}).',
        );
      }

      // 9. Atomic Replay Registration (Post-authentication)
      if (_replayProtectionService != null) {
        final outcome = await _replayProtectionService.checkAndMarkSeen(
          packetType: FileTransferCryptoService.defaultPacketType,
          originId: envelope.originId,
          packetId: replayPacketId,
          timestamp: effectiveTimestamp,
          now: now,
        );
        if (!outcome.isAccepted) {
          throw ChunkReplayException(
            'Session message rejected during atomic replay registration: ${outcome.result.name}',
            validationResult: outcome.result,
          );
        }
      }

      // 10. Duplicate chunk delivery & conflict detection in staging layer
      final existingChunk = await database.getFileChunk(
        envelope.transferId,
        envelope.chunkIndex,
      );

      if (existingChunk != null && existingChunk.status == 'received') {
        final writer = await _getOrCreateWriter(transfer);
        final stagedBytes = await writer.readAt(
          offset: envelope.offset,
          length: envelope.chunkLength,
        );

        final matches = stagedBytes.length == plaintext.length &&
            EphemeralSession.constantTimeCompare(stagedBytes, plaintext);

        if (matches) {
          // Idempotent duplicate: safe, no corruption, do not double-increment
          final allChunks = await database.getFileChunks(envelope.transferId);
          final receivedCount = allChunks.where((c) => c.status == 'received').length;

          return ChunkReceivingResult(
            transferId: envelope.transferId,
            chunkIndex: envelope.chunkIndex,
            offset: envelope.offset,
            bytesWritten: 0,
            totalBytes: fileSize,
            chunksReceived: receivedCount,
            totalChunks: transfer.totalChunks,
            status: currentStatus == FileTransferStatus.acceptSent
                ? FileTransferStatus.transferring
                : currentStatus,
            isDuplicate: true,
            isSuccess: true,
          );
        } else {
          throw ChunkContentConflictException(
            'Conflicting content for already-received chunk ${envelope.chunkIndex} of transfer ${envelope.transferId}. Staged bytes do not match decrypted plaintext.',
          );
        }
      }

      // 11. Safe Disk Write (Bounded random-access write via FileDiskWriter)
      final writer = await _getOrCreateWriter(transfer);
      try {
        await writer.writeAt(offset: envelope.offset, data: plaintext);
      } catch (e) {
        await closeWriter(envelope.transferId);
        throw ChunkDiskWriteException(
          'Failed to write chunk ${envelope.chunkIndex} to disk: $e',
          e,
        );
      }

      // 12. Consistent SQLite Persistence (Only updated AFTER write succeeds)
      await database.markChunkReceived(
        envelope.transferId,
        envelope.chunkIndex,
        status: 'received',
        receivedAt: now ?? DateTime.now(),
      );

      // Advance transfer status to transferring if currently in acceptSent or paused
      if (currentStatus == FileTransferStatus.acceptSent ||
          currentStatus == FileTransferStatus.paused) {
        await database.updateFileTransferStatus(
          envelope.transferId,
          FileTransferStatus.transferring.name,
          updatedAt: now ?? DateTime.now(),
        );
      }

      final allChunks = await database.getFileChunks(envelope.transferId);
      final receivedCount = allChunks.where((c) => c.status == 'received').length;

      // Note: In Step 11, the transfer is NEVER marked completed.
      // Whole-file assembly and hash verification belong strictly to Step 13.
      return ChunkReceivingResult(
        transferId: envelope.transferId,
        chunkIndex: envelope.chunkIndex,
        offset: envelope.offset,
        bytesWritten: plaintext.length,
        totalBytes: fileSize,
        chunksReceived: receivedCount,
        totalChunks: transfer.totalChunks,
        status: FileTransferStatus.transferring,
        isDuplicate: false,
        isSuccess: true,
      );
    } on ChunkReceivingException catch (e) {
      if (throwOnError) rethrow;
      return ChunkReceivingResult(
        transferId: envelope.transferId,
        chunkIndex: envelope.chunkIndex,
        offset: envelope.offset,
        bytesWritten: 0,
        totalBytes: 0,
        chunksReceived: 0,
        totalChunks: envelope.totalChunks,
        status: FileTransferStatus.failed,
        isDuplicate: false,
        isSuccess: false,
        error: e,
      );
    } catch (e) {
      if (throwOnError) {
        throw ChunkDiskWriteException('Unexpected chunk receiving error: $e', e);
      }
      return ChunkReceivingResult(
        transferId: envelope.transferId,
        chunkIndex: envelope.chunkIndex,
        offset: envelope.offset,
        bytesWritten: 0,
        totalBytes: 0,
        chunksReceived: 0,
        totalChunks: envelope.totalChunks,
        status: FileTransferStatus.failed,
        isDuplicate: false,
        isSuccess: false,
        error: e,
      );
    }
  }
}

/// Riverpod provider for [ChunkReceivingPipeline].
final chunkReceivingPipelineProvider = Provider<ChunkReceivingPipeline>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(messageRepositoryProvider);
  final replayService = ref.watch(replayProtectionServiceProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );

  final pipeline = ChunkReceivingPipeline(
    localDeviceId: discoveryController.localIdentity.id,
    database: db,
    messageRepository: repo,
    replayProtectionService: replayService,
  );
  ref.onDispose(() => pipeline.closeAll());
  return pipeline;
});
