import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';

/// File replacement policy when the final destination file already exists.
enum FileReplacementPolicy {
  /// Default: automatically generates a collision-safe filename (e.g. `file (1).ext`).
  collisionSafe,

  /// Replaces any existing file at the target destination path atomically.
  overwrite,

  /// Aborts assembly with [DestinationFileExistsException] if destination already exists.
  failIfExists,
}

/// Base exception for all file assembly failures.
class FileAssemblyException implements Exception {
  const FileAssemblyException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? '$runtimeType: $message (caused by: $cause)'
      : '$runtimeType: $message';
}

/// Thrown when the transfer record does not exist in the database.
class TransferNotFoundAssemblyException extends FileAssemblyException {
  const TransferNotFoundAssemblyException(super.message, {super.cause});
}

/// Thrown when the transfer is in an invalid lifecycle state for assembly (e.g. cancelled, failed).
class InvalidTransferStateException extends FileAssemblyException {
  const InvalidTransferStateException(super.message, {super.cause});
}

/// Thrown when one or more required chunks have not been received or recorded.
class MissingChunksException extends FileAssemblyException {
  const MissingChunksException(
    super.message, {
    required this.missingChunkIndexes,
    required this.totalChunks,
    super.cause,
  });

  final List<int> missingChunkIndexes;
  final int totalChunks;
}

/// Thrown when chunk indices, offsets, lengths, or counts violate metadata invariants.
class InvalidChunkMetadataException extends FileAssemblyException {
  const InvalidChunkMetadataException(super.message, {super.cause});
}

/// Thrown when the staging file cannot be found on disk.
class StagingFileNotFoundException extends FileAssemblyException {
  const StagingFileNotFoundException(super.message, {super.cause});
}

/// Thrown when the physical file size does not match the expected transfer size.
class FileSizeMismatchException extends FileAssemblyException {
  const FileSizeMismatchException(
    super.message, {
    required this.expectedSize,
    required this.actualSize,
    super.cause,
  });

  final int expectedSize;
  final int actualSize;
}

/// Thrown when calculated whole-file SHA-256 hash does not match expected metadata hash.
class FileHashMismatchException extends FileAssemblyException {
  const FileHashMismatchException(
    super.message, {
    required this.expectedHash,
    required this.actualHash,
    super.cause,
  });

  final String expectedHash;
  final String actualHash;
}

/// Thrown when destination file exists and [FileReplacementPolicy.failIfExists] is specified.
class DestinationFileExistsException extends FileAssemblyException {
  const DestinationFileExistsException(super.message, {super.cause});
}

/// Thrown when updating the database state for the completed transfer fails.
class AssemblyPersistenceException extends FileAssemblyException {
  const AssemblyPersistenceException(super.message, {super.cause});
}

/// Structured result of a file assembly operation.
class FileAssemblyResult {
  const FileAssemblyResult({
    required this.transferId,
    required this.destinationPath,
    required this.fileSize,
    required this.fileHash,
    this.isSuccess = true,
    this.isIdempotent = false,
    this.error,
  });

  final String transferId;
  final String destinationPath;
  final int fileSize;
  final String fileHash;
  final bool isSuccess;
  final bool isIdempotent;
  final Object? error;

  @override
  String toString() =>
      'FileAssemblyResult(transferId: $transferId, path: $destinationPath, size: $fileSize, idempotent: $isIdempotent, success: $isSuccess)';
}

/// Service responsible for Step 13: Whole-File Integrity and Assembly.
///
/// Verifies that all required chunks are present and valid, verifies staging file size,
/// calculates whole-file SHA-256 hash using streaming without whole-file memory buffering,
/// performs constant-time cryptographic hash verification against persisted transfer metadata,
/// securely moves/copies the file to the destination directory while preventing path traversal
/// and partial output exposure, and transitions the transfer to [FileTransferStatus.completed].
class FileAssemblyService {
  FileAssemblyService({
    required this.database,
    FilePathService? pathService,
    FileTransferStateMachine? stateMachine,
    HashAlgorithm? hashAlgorithm,
  })  : pathService = pathService ?? FilePathService(),
        stateMachine = stateMachine ?? FileTransferStateMachine.instance,
        hashAlgorithm = hashAlgorithm ?? Sha256();

  final AppDatabase database;
  final FilePathService pathService;
  final FileTransferStateMachine stateMachine;
  final HashAlgorithm hashAlgorithm;

  /// Calculates the lowercase hex SHA-256 hash of [file] using memory-efficient streaming.
  Future<String> calculateFileSha256(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('File does not exist: "${file.path}"');
    }
    final sink = hashAlgorithm.newHashSink();
    final inStream = file.openRead();
    await for (final block in inStream) {
      sink.add(block);
    }
    sink.close();
    final hashObj = await sink.hash();
    return hashObj.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Performs constant-time comparison of two 64-character hex hash strings.
  static bool constantTimeHashCompare(String hexA, String hexB) {
    final cleanA = hexA.trim().toLowerCase();
    final cleanB = hexB.trim().toLowerCase();
    if (cleanA.length != cleanB.length) return false;
    if (cleanA.length != 64) return false; // SHA-256 produces 32 bytes = 64 hex characters
    try {
      final bytesA = _hexToBytes(cleanA);
      final bytesB = _hexToBytes(cleanB);
      return EphemeralSession.constantTimeCompare(bytesA, bytesB);
    } catch (_) {
      return false;
    }
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  /// Resolves a collision-safe path for [candidatePath], generating `stem (1).ext`
  /// if a file already exists at that path.
  static Future<String> resolveCollisionSafePath(String candidatePath) async {
    if (!await File(candidatePath).exists()) {
      return candidatePath;
    }
    final dir = p.dirname(candidatePath);
    final ext = p.extension(candidatePath);
    final stem = p.basenameWithoutExtension(candidatePath);
    var counter = 1;
    while (true) {
      final nextCandidate = p.join(dir, '$stem ($counter)$ext');
      if (!await File(nextCandidate).exists()) {
        return nextCandidate;
      }
      counter++;
      if (counter > 10000) {
        throw FileSystemException(
          'Excessive file collisions encountered for: "$candidatePath"',
        );
      }
    }
  }

  /// Securely assembles the file for [transferId], verifies its integrity, and transitions
  /// the transfer to [FileTransferStatus.completed].
  ///
  /// Guarantees:
  /// - Verifies every chunk index from 0 to totalChunks - 1 is recorded in SQLite.
  /// - Uses persisted transfer metadata for expected file size and expected SHA-256 hash.
  /// - Validates physical staging file size against expected size.
  /// - Calculates whole-file SHA-256 via streaming without whole-file memory accumulation.
  /// - Verifies hash in constant time, preventing timing attacks.
  /// - Enforces path containment to prevent path traversal.
  /// - Assembles via a temporary file so no partial file is ever exposed on failure.
  /// - Retains staging file on failure for recovery/diagnostics.
  /// - Idempotent: repeated assembly calls on a completed transfer safely return the existing path.
  Future<FileAssemblyResult> assembleTransfer({
    required String transferId,
    FileReplacementPolicy replacementPolicy = FileReplacementPolicy.collisionSafe,
    String? explicitDestinationPath,
    DateTime? now,
  }) async {
    // 1. Validate transferId & Fetch Transfer Metadata from SQLite
    FilePathService.validateTransferId(transferId);
    final transfer = await database.getFileTransfer(transferId);
    if (transfer == null) {
      throw TransferNotFoundAssemblyException(
        'File transfer "$transferId" not found in database.',
      );
    }

    final currentStatus = FileTransferStatus.fromString(transfer.status);
    final expectedFileSize = transfer.fileSize.toInt();

    // 2. Idempotency Check: if already completed, verify destination file integrity
    if (currentStatus == FileTransferStatus.completed) {
      final localPath = transfer.localPath.trim();
      if (localPath.isNotEmpty) {
        final destFile = File(localPath);
        if (await destFile.exists()) {
          final destSize = await destFile.length();
          if (destSize == expectedFileSize) {
            return FileAssemblyResult(
              transferId: transferId,
              destinationPath: localPath,
              fileSize: expectedFileSize,
              fileHash: transfer.fileHash,
              isSuccess: true,
              isIdempotent: true,
            );
          }
        }
      }
      throw InvalidTransferStateException(
        'Transfer "$transferId" is recorded as completed but destination file "${transfer.localPath}" is missing or truncated.',
      );
    }

    // 3. Lifecycle State Check
    if (stateMachine.isTerminal(currentStatus)) {
      throw InvalidTransferStateException(
        'Cannot assemble transfer "$transferId" with terminal status "${currentStatus.name}".',
      );
    }

    final direction = FileTransferDirection.fromString(transfer.direction);
    final transitionEval = stateMachine.transition(
      direction: direction,
      from: currentStatus == FileTransferStatus.acceptSent
          ? FileTransferStatus.transferring
          : currentStatus,
      to: FileTransferStatus.completed,
    );
    if (!transitionEval.allowed) {
      throw InvalidTransferStateException(
        'Cannot transition transfer "$transferId" from "${currentStatus.name}" to completed: ${transitionEval.error}',
      );
    }

    // 4. Verify Chunk Presence and Metadata in SQLite
    final totalChunks = transfer.totalChunks;
    if (expectedFileSize < 0) {
      throw InvalidChunkMetadataException(
        'Persisted file size cannot be negative ($expectedFileSize).',
      );
    }
    if (totalChunks < 0) {
      throw InvalidChunkMetadataException(
        'Persisted total chunks cannot be negative ($totalChunks).',
      );
    }
    if (transfer.chunkSize <= 0) {
      throw InvalidChunkMetadataException(
        'Persisted chunk size must be positive (${transfer.chunkSize}).',
      );
    }
    if (expectedFileSize == 0 && totalChunks > 1) {
      throw InvalidChunkMetadataException(
        'Zero-byte file cannot declare multiple chunks ($totalChunks).',
      );
    }

    final chunks = await database.getFileChunks(transferId);
    final receivedChunks = <int, FileChunkEntry>{};
    for (final c in chunks) {
      if (c.status == 'received' || c.status == 'verified') {
        receivedChunks[c.chunkIndex] = c;
      }
    }

    if (totalChunks > 0) {
      final missingIndexes = <int>[];
      for (var i = 0; i < totalChunks; i++) {
        if (!receivedChunks.containsKey(i)) {
          missingIndexes.add(i);
        }
      }
      if (missingIndexes.isNotEmpty) {
        throw MissingChunksException(
          'Cannot assemble transfer "$transferId": missing ${missingIndexes.length} chunk(s) (total: $totalChunks). Missing indices: $missingIndexes',
          missingChunkIndexes: missingIndexes,
          totalChunks: totalChunks,
        );
      }

      // Verify offsets and lengths
      for (var i = 0; i < totalChunks; i++) {
        final expectedOffset = i * transfer.chunkSize;
        final isLast = i == totalChunks - 1;
        final expectedLength = isLast
            ? (expectedFileSize - expectedOffset)
            : transfer.chunkSize;

        if (expectedOffset < 0 || expectedLength < 0) {
          throw InvalidChunkMetadataException(
            'Chunk $i has negative offset ($expectedOffset) or length ($expectedLength).',
          );
        }
        if (expectedOffset + expectedLength > expectedFileSize) {
          throw InvalidChunkMetadataException(
            'Chunk $i range [$expectedOffset, ${expectedOffset + expectedLength}] exceeds total file size ($expectedFileSize).',
          );
        }
      }
    }

    // 5. Verify Staging File Existence & Physical Length
    var stagingPath = transfer.stagingPath.trim();
    if (stagingPath.isEmpty) {
      stagingPath = await pathService.getStagingPath(transferId);
    }

    final stagingFile = File(stagingPath);
    if (expectedFileSize == 0 && !await stagingFile.exists()) {
      if (!await stagingFile.parent.exists()) {
        await stagingFile.parent.create(recursive: true);
      }
      await stagingFile.create(recursive: true);
    } else if (!await stagingFile.exists()) {
      throw StagingFileNotFoundException(
        'Staging file does not exist at "$stagingPath".',
      );
    }

    final actualStagingLength = await stagingFile.length();
    if (actualStagingLength != expectedFileSize) {
      throw FileSizeMismatchException(
        'Staging file physical size ($actualStagingLength bytes) does not match expected file size ($expectedFileSize bytes).',
        expectedSize: expectedFileSize,
        actualSize: actualStagingLength,
      );
    }

    // 6. Streaming Whole-File SHA-256 Calculation & Constant-Time Verification
    final expectedHash = transfer.fileHash.trim().toLowerCase();
    if (expectedHash.isEmpty || expectedHash.length != 64) {
      await database.updateFileTransferStatus(
        transferId,
        FileTransferStatus.failed.name,
        updatedAt: now ?? DateTime.now(),
      );
      throw FileHashMismatchException(
        'Persisted expected hash is invalid (expected 64 hex characters): "$expectedHash"',
        expectedHash: expectedHash,
        actualHash: '',
      );
    }

    final calculatedHex = await calculateFileSha256(stagingFile);
    final hashMatches = constantTimeHashCompare(calculatedHex, expectedHash);

    if (!hashMatches) {
      // Mark transfer failed in SQLite, but preserve staging file for diagnosis
      await database.updateFileTransferStatus(
        transferId,
        FileTransferStatus.failed.name,
        updatedAt: now ?? DateTime.now(),
      );
      throw FileHashMismatchException(
        'Whole-file SHA-256 hash mismatch for transfer "$transferId": calculated ($calculatedHex) != expected ($expectedHash).',
        expectedHash: expectedHash,
        actualHash: calculatedHex,
      );
    }

    // 7. Destination Path Resolution & Traversal Prevention
    late final String targetDestinationPath;
    final completedDir = await pathService.getCompletedDirectory(create: true);
    final baseTransfersDir = await pathService.getBaseTransfersDirectory(create: true);

    if (explicitDestinationPath != null) {
      final trimmed = explicitDestinationPath.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('explicitDestinationPath must not be empty.');
      }
      if (trimmed.contains('\x00')) {
        throw const SecurityException('explicitDestinationPath contains null character.');
      }
      if (trimmed.contains('..')) {
        throw const SecurityException('explicitDestinationPath contains directory traversal ("..").');
      }

      final isInsideBase = FilePathService.isPathInsideDirectory(trimmed, baseTransfersDir.path);
      final isInsideCompleted = FilePathService.isPathInsideDirectory(trimmed, completedDir.path);

      if (!isInsideBase && !isInsideCompleted) {
        throw SecurityException(
          'Destination path "$trimmed" is outside designated application transfer storage.',
        );
      }

      if (await File(trimmed).exists()) {
        if (replacementPolicy == FileReplacementPolicy.failIfExists) {
          throw DestinationFileExistsException(
            'Destination file already exists at "$trimmed".',
          );
        } else if (replacementPolicy == FileReplacementPolicy.collisionSafe) {
          targetDestinationPath = await resolveCollisionSafePath(trimmed);
        } else {
          targetDestinationPath = trimmed;
        }
      } else {
        targetDestinationPath = trimmed;
      }
    } else {
      final safeName = FilePathService.sanitizeFileName(transfer.fileName);
      if (replacementPolicy == FileReplacementPolicy.collisionSafe) {
        targetDestinationPath = await pathService.getSafeCompletedPath(
          transferId: transferId,
          fileName: safeName,
        );
      } else {
        final candidate = p.join(completedDir.path, safeName);
        if (!FilePathService.isPathInsideDirectory(candidate, completedDir.path)) {
          throw SecurityException(
            'Destination path "$candidate" escapes completed directory.',
          );
        }
        if (await File(candidate).exists()) {
          if (replacementPolicy == FileReplacementPolicy.failIfExists) {
            throw DestinationFileExistsException(
              'Destination file already exists at "$candidate".',
            );
          }
        }
        targetDestinationPath = candidate;
      }
    }

    // 8. Atomic Placement: Stream to Temporary File, Verify Size, then Rename
    final destFile = File(targetDestinationPath);
    final destParent = destFile.parent;
    if (!await destParent.exists()) {
      await destParent.create(recursive: true);
    }

    final tempDestPath = '$targetDestinationPath.tmp_${DateTime.now().millisecondsSinceEpoch}_$pid';
    final tempDestFile = File(tempDestPath);

    try {
      final inStream = stagingFile.openRead();
      final outSink = tempDestFile.openWrite();
      await inStream.pipe(outSink);
      await outSink.close();

      // Verify temp assembled file size
      final tempLength = await tempDestFile.length();
      if (tempLength != expectedFileSize) {
        throw FileSizeMismatchException(
          'Assembled temporary file size ($tempLength bytes) does not match expected size ($expectedFileSize bytes).',
          expectedSize: expectedFileSize,
          actualSize: tempLength,
        );
      }

      // If target exists and overwrite is allowed, remove target first (Windows File.rename requirement)
      if (await destFile.exists()) {
        if (replacementPolicy == FileReplacementPolicy.overwrite) {
          await destFile.delete();
        } else {
          throw DestinationFileExistsException(
            'Destination file "$targetDestinationPath" already exists.',
          );
        }
      }

      // Atomic rename
      await tempDestFile.rename(targetDestinationPath);
    } catch (e) {
      // Ensure NO partial output is ever exposed at destination or temp path
      if (await tempDestFile.exists()) {
        try {
          await tempDestFile.delete();
        } catch (_) {}
      }
      rethrow;
    }

    // Double check completed file on disk
    if (!await destFile.exists()) {
      throw const FileAssemblyException('Destination file was not successfully placed.');
    }
    final finalLength = await destFile.length();
    if (finalLength != expectedFileSize) {
      try {
        await destFile.delete();
      } catch (_) {}
      throw FileSizeMismatchException(
        'Final destination file size ($finalLength bytes) does not match expected size ($expectedFileSize bytes).',
        expectedSize: expectedFileSize,
        actualSize: finalLength,
      );
    }

    // 9. Atomic SQLite Persistence to Completed
    final effectiveNow = now ?? DateTime.now();
    final int rowsUpdated;
    try {
      rowsUpdated = await database.completeFileTransfer(
        transferId,
        targetDestinationPath,
        updatedAt: effectiveNow,
      );
    } catch (e) {
      if (await destFile.exists()) {
        try {
          await destFile.delete();
        } catch (_) {
          // Requirement D.5: Cleanup failure must not mask primary error
        }
      }
      throw AssemblyPersistenceException(
        'Failed to record completed state for transfer "$transferId" in database: $e',
        cause: e,
      );
    }

    if (rowsUpdated == 0) {
      if (await destFile.exists()) {
        try {
          await destFile.delete();
        } catch (_) {
          // Requirement D.5: Cleanup failure must not mask primary error
        }
      }
      throw AssemblyPersistenceException(
        'Failed to record completed state for transfer "$transferId" in database. Transfer may have been cancelled, failed, or completed concurrently.',
      );
    }

    return FileAssemblyResult(
      transferId: transferId,
      destinationPath: targetDestinationPath,
      fileSize: expectedFileSize,
      fileHash: calculatedHex,
      isSuccess: true,
      isIdempotent: false,
    );
  }
}
