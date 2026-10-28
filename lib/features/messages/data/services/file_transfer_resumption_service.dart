import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_ack_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
import 'package:meshlink/features/messages/providers/messaging_providers.dart';

export 'package:meshlink/features/messages/data/services/file_assembly_service.dart';

/// Base exception for all file transfer resumption operations.
class FileTransferResumptionException implements Exception {
  const FileTransferResumptionException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? '$runtimeType: $message (caused by: $cause)'
      : '$runtimeType: $message';
}

/// Thrown when the transfer record does not exist in local persistence.
class TransferNotFoundResumptionException extends FileTransferResumptionException {
  const TransferNotFoundResumptionException(super.message, [super.cause]);
}

/// Thrown when a transfer is ineligible for resumption under the state machine
/// (e.g., terminal statuses such as completed, cancelled, or failed).
class IneligibleTransferException extends FileTransferResumptionException {
  const IneligibleTransferException(super.message, [super.cause]);
}

/// Thrown when persisted transfer metadata is malformed, inconsistent, or invalid.
class InconsistentTransferMetadataException extends FileTransferResumptionException {
  const InconsistentTransferMetadataException(super.message, [super.cause]);
}

/// Thrown when the staging file is missing, truncated, or corrupted.
class StagingFileCorruptedException extends FileTransferResumptionException {
  const StagingFileCorruptedException(super.message, [super.cause]);
}

/// Thrown when sending a resume request over the transport layer fails.
class ResumeTransportException extends FileTransferResumptionException {
  const ResumeTransportException(super.message, [super.cause]);
}

/// Typed model representing a request to resume an interrupted file transfer
/// by specifying the missing or invalid chunk indices.
class FileChunkResumeRequest {
  FileChunkResumeRequest({
    required this.transferId,
    required List<int> missingChunkIndexes,
    required this.originId,
    required this.destinationId,
    required this.sessionId,
    required this.epoch,
    required this.createdAt,
  }) : missingChunkIndexes = List<int>.unmodifiable(
          List<int>.from(missingChunkIndexes)..sort(),
        ) {
    validate();
  }

  final String transferId;
  final List<int> missingChunkIndexes;
  final String originId;
  final String destinationId;
  final String sessionId;
  final int epoch;
  final DateTime createdAt;

  /// Returns the first missing chunk index, or -1 if empty.
  int get fromChunkIndex =>
      missingChunkIndexes.isNotEmpty ? missingChunkIndexes.first : -1;

  /// Validates internal invariants.
  void validate() {
    FilePathService.validateTransferId(transferId);
    if (originId.trim().isEmpty) {
      throw ArgumentError('originId must not be empty.');
    }
    if (destinationId.trim().isEmpty) {
      throw ArgumentError('destinationId must not be empty.');
    }
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('sessionId must not be empty.');
    }
    if (epoch < 0) {
      throw ArgumentError('epoch cannot be negative ($epoch).');
    }
    for (final idx in missingChunkIndexes) {
      if (idx < 0) {
        throw ArgumentError('Chunk index cannot be negative ($idx).');
      }
    }
  }

  Map<String, dynamic> toMap() => {
        'transferId': transferId,
        'missingChunkIndexes': missingChunkIndexes,
        'originId': originId,
        'destinationId': destinationId,
        'sessionId': sessionId,
        'epoch': epoch,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FileChunkResumeRequest.fromMap(Map<String, dynamic> map) {
    return FileChunkResumeRequest(
      transferId: map['transferId'] as String? ?? '',
      missingChunkIndexes: (map['missingChunkIndexes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
      originId: map['originId'] as String? ?? '',
      destinationId: map['destinationId'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      epoch: (map['epoch'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FileChunkResumeRequest.fromJson(String source) =>
      FileChunkResumeRequest.fromMap(
          jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileChunkResumeRequest &&
          runtimeType == other.runtimeType &&
          transferId == other.transferId &&
          originId == other.originId &&
          destinationId == other.destinationId &&
          sessionId == other.sessionId &&
          epoch == other.epoch &&
          createdAt == other.createdAt &&
          _listEquals(missingChunkIndexes, other.missingChunkIndexes);

  @override
  int get hashCode => Object.hash(
        transferId,
        originId,
        destinationId,
        sessionId,
        epoch,
        createdAt,
        Object.hashAll(missingChunkIndexes),
      );

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'FileChunkResumeRequest(transferId: $transferId, missing: ${missingChunkIndexes.length} chunks, from: $fromChunkIndex, dest: $destinationId)';
}

/// Abstract transport boundary for transmitting typed resume requests.
abstract class ChunkResumeTransportSender {
  /// Hands off [request] to the underlying transport subsystem.
  ///
  /// Returns `true` if successfully accepted by local transport.
  Future<bool> sendResumeRequest(FileChunkResumeRequest request);
}

/// Convenience adapter converting a closure into a [ChunkResumeTransportSender].
class FunctionalChunkResumeTransportSender
    implements ChunkResumeTransportSender {
  FunctionalChunkResumeTransportSender(this._sendFunction);

  final Future<bool> Function(FileChunkResumeRequest request) _sendFunction;

  @override
  Future<bool> sendResumeRequest(FileChunkResumeRequest request) =>
      _sendFunction(request);
}

/// Detailed result of reconciling persisted transfer and chunk metadata against
/// the physical staging file on disk.
class TransferReconciliationResult {
  const TransferReconciliationResult({
    required this.transferId,
    required this.direction,
    required this.status,
    required this.expectedFileSize,
    required this.totalChunks,
    required this.stagingPath,
    required this.stagingFileExists,
    required this.stagingFileSize,
    required this.receivedChunkIndexes,
    required this.missingChunkIndexes,
    required this.isComplete,
    required this.hasCorruptedOrTruncatedChunks,
  });

  final String transferId;
  final FileTransferDirection direction;
  final FileTransferStatus status;
  final int expectedFileSize;
  final int totalChunks;
  final String stagingPath;
  final bool stagingFileExists;
  final int stagingFileSize;

  /// Ordered list of chunk indices that have been received and verified to exist
  /// within physical staging file bounds.
  final List<int> receivedChunkIndexes;

  /// Ordered list of chunk indices that are absent, incomplete, or truncated.
  final List<int> missingChunkIndexes;

  /// Whether all expected chunks are present and valid on disk.
  final bool isComplete;

  /// Whether any previously recorded chunks were detected as truncated or missing on disk.
  final bool hasCorruptedOrTruncatedChunks;

  int get receivedCount => receivedChunkIndexes.length;
  int get missingCount => missingChunkIndexes.length;

  @override
  String toString() =>
      'TransferReconciliationResult(transferId: $transferId, status: ${status.name}, '
      'exists: $stagingFileExists ($stagingFileSize/$expectedFileSize B), '
      'received: $receivedCount/$totalChunks, missing: $missingCount/$totalChunks, complete: $isComplete, '
      'repaired: $hasCorruptedOrTruncatedChunks)';
}

/// Core service managing recovery, reconciliation, and resumption of interrupted
/// file transfers across app/service restarts.
///
/// Phase 8 Step 14: Interruption and Resumption.
///
/// Architectural properties:
/// 1. Safe Restoration: Restores eligible transfers (`transferring`, `paused`, `acceptSent`, `acceptReceived`)
///    from SQLite. Strictly rejects terminal states (`completed`, `cancelled`, `failed`).
/// 2. Deep Reconciliation: Never blindly trusts SQLite records. Cross-references persisted chunk
///    records against physical staging file bounds on disk to detect truncation or missing files.
/// 3. Documented Integrity Guarantee: `FileChunksTable` in Drift schema version 3 stores
///    `(transferId, chunkIndex, status, receivedAt)` without individual per-chunk cryptographic hashes.
///    Individual chunk integrity relies on ChaCha20-Poly1305 MAC verification at time of receipt in Step 11,
///    physical staging file bounds checks during reconciliation, and whole-file SHA-256 cryptographic
///    verification at Step 13 completion.
/// 4. Resumption from Missing Ranges: Generates typed [FileChunkResumeRequest] identifying missing chunks,
///    preserving existing ACK/NACK, replay protection, and session encryption semantics.
/// 5. Step 13 Invocation: When all chunks are present, invokes [FileAssemblyService.assembleTransfer]
///    to perform whole-file streaming SHA-256 verification and atomic collision-safe placement.
/// 6. Idempotent & Crash-safe: Repeated resume requests safely reuse intact staged data without
///    double counting or corrupting disk state. Partial recovery never exposes files as completed.
class FileTransferResumptionService {
  FileTransferResumptionService({
    required this.database,
    required this.localDeviceId,
    FilePathService? pathService,
    FileTransferStateMachine? stateMachine,
    FileAssemblyService? assemblyService,
    this.receivingPipeline,
    this.sendingPipeline,
    this.messageRepository,
    this.replayProtectionService,
    this.requireVerifiedPeer = false,
  })  : pathService = pathService ?? FilePathService(),
        stateMachine = stateMachine ?? FileTransferStateMachine.instance,
        assemblyService = assemblyService ??
            FileAssemblyService(
              database: database,
              pathService: pathService ?? FilePathService(),
              stateMachine: stateMachine ?? FileTransferStateMachine.instance,
            );

  final AppDatabase database;
  final String localDeviceId;
  final FilePathService pathService;
  final FileTransferStateMachine stateMachine;
  final FileAssemblyService assemblyService;
  final ChunkReceivingPipeline? receivingPipeline;
  final ChunkSendingPipeline? sendingPipeline;
  final MessageRepository? messageRepository;
  final ReplayProtectionService? replayProtectionService;
  final bool requireVerifiedPeer;

  /// Eligible non-terminal transfer statuses that can be resumed.
  static const Set<FileTransferStatus> eligibleIncomingStatuses = {
    FileTransferStatus.acceptSent,
    FileTransferStatus.transferring,
    FileTransferStatus.paused,
  };

  static const Set<FileTransferStatus> eligibleOutgoingStatuses = {
    FileTransferStatus.acceptReceived,
    FileTransferStatus.transferring,
    FileTransferStatus.paused,
  };

  /// Restores all interrupted transfers eligible for resumption from persistent SQLite records.
  ///
  /// Optionally filters by [direction].
  ///
  /// Guarantees:
  /// - Excludes all terminal transfers (`completed`, `cancelled`, `failed`).
  /// - Excludes transfers not yet accepted/started (`initiated`, `offerSent`, `offerReceived`).
  Future<List<FileTransfer>> getInterruptedTransfers({
    FileTransferDirection? direction,
  }) async {
    final entries = await database.getAllFileTransfers();
    final results = <FileTransfer>[];

    for (final entry in entries) {
      final status = FileTransferStatus.tryFromString(entry.status);
      if (status == null || stateMachine.isTerminal(status)) {
        continue;
      }

      final transferDirection = FileTransferDirection.tryFromString(entry.direction);
      if (transferDirection == null) {
        continue;
      }

      if (direction != null && transferDirection != direction) {
        continue;
      }

      final eligible = transferDirection == FileTransferDirection.incoming
          ? eligibleIncomingStatuses.contains(status)
          : eligibleOutgoingStatuses.contains(status);

      if (eligible) {
        results.add(FileTransfer.fromEntry(entry));
      }
    }

    return results;
  }

  /// Strictly validates persisted transfer metadata.
  ///
  /// Throws [InconsistentTransferMetadataException] if any invariant is violated.
  Future<void> validatePersistedMetadata(FileTransfer transfer) async {
    // 1. Transfer ID validation
    try {
      FilePathService.validateTransferId(transfer.transferId);
    } catch (e) {
      throw InconsistentTransferMetadataException(
        'Invalid transfer ID "${transfer.transferId}": $e',
        e,
      );
    }

    // 2. Peer ID validation
    if (transfer.peerId.trim().isEmpty || transfer.peerId.length > 128) {
      throw const InconsistentTransferMetadataException(
        'Peer ID is empty or exceeds maximum limit of 128 characters.',
      );
    }

    // 3. File size and chunk parameters
    if (transfer.fileSize < 0) {
      throw InconsistentTransferMetadataException(
        'Persisted fileSize cannot be negative (${transfer.fileSize}).',
      );
    }
    if (transfer.chunkSize <= 0) {
      throw InconsistentTransferMetadataException(
        'Persisted chunkSize must be positive (${transfer.chunkSize}).',
      );
    }
    if (transfer.totalChunks < 0) {
      throw InconsistentTransferMetadataException(
        'Persisted totalChunks cannot be negative (${transfer.totalChunks}).',
      );
    }

    if (transfer.fileSize == 0) {
      if (transfer.totalChunks > 1) {
        throw InconsistentTransferMetadataException(
          'Zero-byte transfer cannot declare multiple chunks (${transfer.totalChunks}).',
        );
      }
    } else {
      final expectedChunks =
          (transfer.fileSize + transfer.chunkSize - 1) ~/ transfer.chunkSize;
      if (transfer.totalChunks != expectedChunks) {
        throw InconsistentTransferMetadataException(
          'Persisted totalChunks (${transfer.totalChunks}) does not match expected chunk count ($expectedChunks) for fileSize ${transfer.fileSize} and chunkSize ${transfer.chunkSize}.',
        );
      }
    }

    // 4. SHA-256 whole-file hash format (64-character lowercase or uppercase hex)
    final hash = transfer.fileHash.trim();
    if (hash.length != 64 || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
      throw InconsistentTransferMetadataException(
        'Persisted fileHash "$hash" is not a valid 64-character hex SHA-256 string.',
      );
    }

    // 5. Chunk index, offset, and length invariants
    if (transfer.totalChunks > 0 && transfer.fileSize > 0) {
      for (var i = 0; i < transfer.totalChunks; i++) {
        final expectedOffset = i * transfer.chunkSize;
        final isLast = i == transfer.totalChunks - 1;
        final expectedLength = isLast
            ? (transfer.fileSize - expectedOffset)
            : transfer.chunkSize;

        if (expectedOffset < 0 || expectedLength <= 0) {
          throw InconsistentTransferMetadataException(
            'Chunk $i metadata range has invalid offset ($expectedOffset) or length ($expectedLength).',
          );
        }
        if (expectedOffset + expectedLength > transfer.fileSize) {
          throw InconsistentTransferMetadataException(
            'Chunk $i metadata range [$expectedOffset, ${expectedOffset + expectedLength}] exceeds total file size (${transfer.fileSize}).',
          );
        }
      }
    }

    // 6. Staging path containment
    final stagingPath = transfer.stagingPath.trim().isNotEmpty
        ? transfer.stagingPath.trim()
        : await pathService.getStagingPath(transfer.transferId);

    if (stagingPath.contains('\x00') || stagingPath.contains('..')) {
      throw InconsistentTransferMetadataException(
        'Staging path "$stagingPath" contains illegal characters or directory traversal ("..").',
      );
    }

    final stagingDir = await pathService.getStagingDirectory();
    if (!FilePathService.isPathInsideDirectory(stagingPath, stagingDir.path)) {
      throw InconsistentTransferMetadataException(
        'Staging path "$stagingPath" escapes authorized staging directory "${stagingDir.path}".',
      );
    }

    // 7. Destination path containment (if specified)
    if (transfer.localPath.trim().isNotEmpty) {
      final localPath = transfer.localPath.trim();
      if (localPath.contains('\x00') || localPath.contains('..')) {
        throw InconsistentTransferMetadataException(
          'Local path "$localPath" contains illegal characters or directory traversal ("..").',
        );
      }

      if (transfer.direction == FileTransferDirection.incoming) {
        final completedDir = await pathService.getCompletedDirectory();
        final baseTransfersDir = await pathService.getBaseTransfersDirectory();
        final isInsideCompleted =
            FilePathService.isPathInsideDirectory(localPath, completedDir.path);
        final isInsideBase =
            FilePathService.isPathInsideDirectory(localPath, baseTransfersDir.path);

        if (!isInsideCompleted && !isInsideBase) {
          throw InconsistentTransferMetadataException(
            'Local destination path "$localPath" is outside authorized directory.',
          );
        }
      }
    }
  }

  /// Reconciles SQLite transfer and chunk records against the physical staging file on disk.
  ///
  /// Guarantees:
  /// - Never assumes bytes on disk exist merely because SQLite records a chunk.
  /// - Identifies truncated or missing staging files.
  /// - If [repairDatabase] is true, purges or corrects invalid/truncated chunk records in SQLite.
  /// - Identifies all valid chunks and all missing chunks that must be re-requested.
  Future<TransferReconciliationResult> reconcileTransfer(
    String transferId, {
    bool repairDatabase = true,
  }) async {
    FilePathService.validateTransferId(transferId);

    final entry = await database.getFileTransfer(transferId);
    if (entry == null) {
      throw TransferNotFoundResumptionException(
        'Transfer "$transferId" not found in database.',
      );
    }

    final transfer = FileTransfer.fromEntry(entry);
    final status = transfer.status;

    // Terminal status check: never resume terminal transfers
    if (stateMachine.isTerminal(status)) {
      throw IneligibleTransferException(
        'Cannot resume transfer "$transferId": transfer is in terminal status "${status.name}".',
      );
    }

    final isEligible = transfer.direction == FileTransferDirection.incoming
        ? eligibleIncomingStatuses.contains(status)
        : eligibleOutgoingStatuses.contains(status);

    if (!isEligible) {
      throw IneligibleTransferException(
        'Cannot resume transfer "$transferId": status "${status.name}" is not eligible for resumption.',
      );
    }

    // Validate persisted metadata invariants
    await validatePersistedMetadata(transfer);

    final stagingPath = transfer.stagingPath.trim().isNotEmpty
        ? transfer.stagingPath.trim()
        : await pathService.getStagingPath(transferId);

    final stagingFile = File(stagingPath);
    final fileExists = await stagingFile.exists();
    final fileSize = transfer.fileSize;
    final totalChunks = transfer.totalChunks;

    final dbChunks = await database.getFileChunks(transferId);
    final recordedChunkMap = <int, FileChunkEntry>{};
    for (final c in dbChunks) {
      if (c.status == 'received' || c.status == 'verified' || c.status == 'acked') {
        recordedChunkMap[c.chunkIndex] = c;
      }
    }

    // Case 1: Empty file (0 bytes)
    if (fileSize == 0) {
      if (!fileExists) {
        if (!await stagingFile.parent.exists()) {
          await stagingFile.parent.create(recursive: true);
        }
        await stagingFile.create(recursive: true);
      }
      return TransferReconciliationResult(
        transferId: transferId,
        direction: transfer.direction,
        status: status,
        expectedFileSize: 0,
        totalChunks: totalChunks,
        stagingPath: stagingPath,
        stagingFileExists: true,
        stagingFileSize: 0,
        receivedChunkIndexes: const [],
        missingChunkIndexes: const [],
        isComplete: true,
        hasCorruptedOrTruncatedChunks: false,
      );
    }

    // Case 2: Staging file does NOT exist on disk
    if (!fileExists) {
      final missing = List<int>.generate(totalChunks, (i) => i);
      final hasCorrupted = recordedChunkMap.isNotEmpty;

      if (repairDatabase && hasCorrupted) {
        // Staged data was lost or never created: reset database chunk records
        await database.deleteFileChunks(transferId);
      }

      return TransferReconciliationResult(
        transferId: transferId,
        direction: transfer.direction,
        status: status,
        expectedFileSize: fileSize,
        totalChunks: totalChunks,
        stagingPath: stagingPath,
        stagingFileExists: false,
        stagingFileSize: 0,
        receivedChunkIndexes: const [],
        missingChunkIndexes: missing,
        isComplete: false,
        hasCorruptedOrTruncatedChunks: hasCorrupted,
      );
    }

    // Case 3: Staging file exists on disk: verify physical length and chunk bounds
    final physicalLength = await stagingFile.length();
    final received = <int>[];
    final missing = <int>[];
    var hasTruncated = false;

    for (var i = 0; i < totalChunks; i++) {
      final offset = i * transfer.chunkSize;
      final isLast = i == totalChunks - 1;
      final length = isLast ? (fileSize - offset) : transfer.chunkSize;

      final isRecordedReceived = recordedChunkMap.containsKey(i);
      final isWithinPhysicalFile = (offset + length) <= physicalLength;

      if (isRecordedReceived && isWithinPhysicalFile) {
        // Chunk is both recorded in SQLite and contained within the staging file
        received.add(i);
      } else {
        missing.add(i);
        if (isRecordedReceived && !isWithinPhysicalFile) {
          // Chunk was recorded as received, but staging file was truncated!
          hasTruncated = true;
          if (repairDatabase) {
            await database.deleteFileChunk(transferId, i);
          }
        }
      }
    }

    return TransferReconciliationResult(
      transferId: transferId,
      direction: transfer.direction,
      status: status,
      expectedFileSize: fileSize,
      totalChunks: totalChunks,
      stagingPath: stagingPath,
      stagingFileExists: true,
      stagingFileSize: physicalLength,
      receivedChunkIndexes: List<int>.unmodifiable(received),
      missingChunkIndexes: List<int>.unmodifiable(missing),
      isComplete: missing.isEmpty,
      hasCorruptedOrTruncatedChunks: hasTruncated,
    );
  }

  /// Reconciles an incoming transfer and sends a typed [FileChunkResumeRequest]
  /// for missing chunks to the sender peer.
  ///
  /// Guarantees:
  /// - Authenticates session matches transfer peer identity.
  /// - Only requests chunks that are genuinely missing or truncated.
  /// - Updates transfer status to `transferring` in SQLite upon sending.
  /// - If all chunks are already present, does not send request.
  Future<FileChunkResumeRequest> requestMissingChunks({
    required String transferId,
    required EphemeralSession session,
    required ChunkResumeTransportSender transportSender,
    DateTime? now,
  }) async {
    final entry = await database.getFileTransfer(transferId);
    if (entry == null) {
      throw TransferNotFoundResumptionException(
        'Transfer "$transferId" not found in database.',
      );
    }

    final transfer = FileTransfer.fromEntry(entry);
    if (transfer.direction != FileTransferDirection.incoming) {
      throw IneligibleTransferException(
        'Cannot request missing chunks for outgoing transfer "$transferId".',
      );
    }

    // Session validation
    if (session.isDestroyed || session.state != SessionLifecycleState.activeSession) {
      throw const IneligibleTransferException(
        'Cannot request chunks: ephemeral session is destroyed or inactive.',
      );
    }

    if (session.peerId != transfer.peerId) {
      throw InconsistentTransferMetadataException(
        'Session peerId (${session.peerId}) does not match transfer peerId (${transfer.peerId}).',
      );
    }

    // Peer trust verification
    if (messageRepository != null) {
      final peer = await messageRepository!.getPeerIdentity(transfer.peerId);
      if (peer != null) {
        final trust = peer.trustStatus.trim().toLowerCase();
        if (trust == 'compromised') {
          throw IneligibleTransferException(
            'Cannot resume transfer: peer ${transfer.peerId} is marked compromised.',
          );
        }
        if (requireVerifiedPeer && trust != 'verified') {
          throw IneligibleTransferException(
            'Cannot resume transfer: peer trustStatus is "$trust" (verified required).',
          );
        }
        try {
          final storedKey = MeshIdentityService.decodePublicKey(peer.identityPublicKey);
          if (!EphemeralSession.constantTimeCompare(session.peerIdentityPublicKey, storedKey)) {
            throw const InconsistentTransferMetadataException(
              'Session identity key does not match stored peer identity.',
            );
          }
        } catch (e) {
          if (e is FileTransferResumptionException) rethrow;
          throw InconsistentTransferMetadataException('Peer key validation failed: $e', e);
        }
      } else if (requireVerifiedPeer) {
        throw IneligibleTransferException(
          'Cannot resume transfer: no peer identity record found for ${transfer.peerId}.',
        );
      }
    }

    // Reconcile database and disk state
    final reconciliation = await reconcileTransfer(transferId, repairDatabase: true);

    final request = FileChunkResumeRequest(
      transferId: transferId,
      missingChunkIndexes: reconciliation.missingChunkIndexes,
      originId: localDeviceId,
      destinationId: transfer.peerId,
      sessionId: session.sessionId,
      epoch: session.epoch,
      createdAt: now ?? DateTime.now().toUtc(),
    );

    if (reconciliation.missingChunkIndexes.isNotEmpty) {
      final sent = await transportSender.sendResumeRequest(request);
      if (!sent) {
        throw ResumeTransportException(
          'Transport failed or rejected sending resume request for transfer "$transferId".',
        );
      }

      // Update transfer status to transferring if currently in paused or acceptSent
      if (transfer.status == FileTransferStatus.paused ||
          transfer.status == FileTransferStatus.acceptSent) {
        await database.updateFileTransferStatus(
          transferId,
          FileTransferStatus.transferring.name,
          updatedAt: now ?? DateTime.now(),
        );
      }
    }

    return request;
  }

  /// High-level resumption coordinator for incoming transfers.
  ///
  /// Reconciles state, requests missing chunks via [transportSender], or completes
  /// assembly if all chunks are already present.
  Future<TransferReconciliationResult> resumeIncomingTransfer({
    required String transferId,
    required EphemeralSession session,
    required ChunkResumeTransportSender transportSender,
    bool autoAssemble = true,
    FileReplacementPolicy replacementPolicy = FileReplacementPolicy.collisionSafe,
    String? explicitDestinationPath,
    DateTime? now,
  }) async {
    final reconciliation = await reconcileTransfer(transferId, repairDatabase: true);

    if (reconciliation.isComplete) {
      if (autoAssemble) {
        if (receivingPipeline != null) {
          await receivingPipeline!.closeWriter(transferId);
        }
        await assemblyService.assembleTransfer(
          transferId: transferId,
          replacementPolicy: replacementPolicy,
          explicitDestinationPath: explicitDestinationPath,
          now: now,
        );
      }
      return reconciliation;
    }

    await requestMissingChunks(
      transferId: transferId,
      session: session,
      transportSender: transportSender,
      now: now,
    );

    return reconciliation;
  }

  /// High-level resumption coordinator for outgoing transfers.
  ///
  /// Sends the missing chunk indices (or all unacknowledged chunks) through [sendingPipeline].
  Future<ChunkSendingResult> resumeOutgoingTransfer({
    required String transferId,
    required EphemeralSession session,
    required ChunkTransportSender transportSender,
    List<int>? requestedChunkIndexes,
    ChunkSendingPolicy? policy,
    FileTransferCancellationToken? cancellationToken,
    ChunkProgressCallback? onProgress,
    bool throwOnError = true,
    ChunkAckTracker? ackTracker,
    ChunkAckService? ackService,
  }) async {
    if (sendingPipeline == null) {
      throw const FileTransferResumptionException(
        'Cannot resume outgoing transfer: ChunkSendingPipeline is not configured.',
      );
    }

    final entry = await database.getFileTransfer(transferId);
    if (entry == null) {
      throw TransferNotFoundResumptionException(
        'Transfer "$transferId" not found in database.',
      );
    }

    final transfer = FileTransfer.fromEntry(entry);
    if (transfer.direction != FileTransferDirection.outgoing) {
      throw IneligibleTransferException(
        'Cannot resume outgoing transfer for non-outgoing transfer "$transferId".',
      );
    }

    // Lifecycle check
    if (stateMachine.isTerminal(transfer.status)) {
      throw IneligibleTransferException(
        'Cannot resume outgoing transfer "$transferId" with terminal status "${transfer.status.name}".',
      );
    }

    await validatePersistedMetadata(transfer);

    // Validate local source file exists on disk
    final sourceFile = File(transfer.localPath);
    if (!await sourceFile.exists()) {
      throw SourceFileSizeMismatchException(
        'Local source file does not exist at "${transfer.localPath}".',
      );
    }

    final sourceSize = await sourceFile.length();
    if (sourceSize != transfer.fileSize) {
      throw SourceFileSizeMismatchException(
        'Source file size on disk ($sourceSize B) does not match transfer metadata (${transfer.fileSize} B).',
      );
    }

    // Resolve which chunk indices to send
    late final List<int> chunksToSend;
    if (requestedChunkIndexes != null) {
      chunksToSend = requestedChunkIndexes;
    } else {
      // Determine unacknowledged chunks from SQLite
      final dbChunks = await database.getFileChunks(transferId);
      final ackedIndices = dbChunks
          .where((c) => c.status == 'acked')
          .map((c) => c.chunkIndex)
          .toSet();

      final missing = <int>[];
      for (var i = 0; i < transfer.totalChunks; i++) {
        if (!ackedIndices.contains(i)) {
          missing.add(i);
        }
      }
      chunksToSend = missing;
    }

    return sendingPipeline!.sendTransfer(
      transfer: transfer,
      session: session,
      transportSender: transportSender,
      policy: policy,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
      throwOnError: throwOnError,
      ackTracker: ackTracker,
      ackService: ackService,
      chunkIndexesToSend: chunksToSend,
    );
  }

  /// Assembles the transfer through Step 13 if all chunks are reconciled and complete.
  Future<FileAssemblyResult> assembleIfComplete(
    String transferId, {
    FileReplacementPolicy replacementPolicy = FileReplacementPolicy.collisionSafe,
    String? explicitDestinationPath,
    DateTime? now,
  }) async {
    if (receivingPipeline != null) {
      await receivingPipeline!.closeWriter(transferId);
    }

    final entry = await database.getFileTransfer(transferId);
    if (entry != null && entry.status == FileTransferStatus.completed.name) {
      return assemblyService.assembleTransfer(
        transferId: transferId,
        replacementPolicy: replacementPolicy,
        explicitDestinationPath: explicitDestinationPath,
        now: now,
      );
    }

    final reconciliation = await reconcileTransfer(transferId, repairDatabase: false);
    if (!reconciliation.isComplete) {
      throw MissingChunksException(
        'Cannot assemble transfer "$transferId": ${reconciliation.missingCount} chunks missing (${reconciliation.missingChunkIndexes}).',
        missingChunkIndexes: reconciliation.missingChunkIndexes,
        totalChunks: reconciliation.totalChunks,
      );
    }

    return assemblyService.assembleTransfer(
      transferId: transferId,
      replacementPolicy: replacementPolicy,
      explicitDestinationPath: explicitDestinationPath,
      now: now,
    );
  }
}

/// Riverpod provider for [FileTransferResumptionService].
final fileTransferResumptionServiceProvider =
    Provider<FileTransferResumptionService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(messageRepositoryProvider);
  final replayService = ref.watch(replayProtectionServiceProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );
  final receivingPipeline = ref.watch(chunkReceivingPipelineProvider);

  return FileTransferResumptionService(
    database: db,
    localDeviceId: discoveryController.localIdentity.id,
    messageRepository: repo,
    replayProtectionService: replayService,
    receivingPipeline: receivingPipeline,
  );
});
