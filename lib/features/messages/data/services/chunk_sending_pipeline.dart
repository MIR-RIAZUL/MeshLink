import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/file_stream_reader.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
import 'package:meshlink/features/messages/providers/messaging_providers.dart';

export 'package:meshlink/features/messages/data/models/encrypted_file_chunk_envelope.dart';

/// Abstract transport contract for handing off encrypted file chunk envelopes
/// to the underlying network/mesh transport subsystem.
///
/// Phase 8 Step 10: Transport Boundary.
///
/// CONTRACT SPECIFICATION:
/// Implementations must return `true` if and only if the chunk envelope was
/// successfully accepted by the local transport layer (e.g. buffered into a local
/// radio transmission queue or socket buffer).
///
/// IMPORTANT: A return value of `true` does NOT represent confirmed delivery to or
/// receipt by the remote peer. End-to-end receipt confirmation is governed
/// exclusively by Step 12 ACK/NACK protocol.
abstract class ChunkTransportSender {
  /// Hands off [envelope] to the local transport subsystem.
  ///
  /// Returns `true` if local handoff succeeded, or `false` if the transport
  /// rejected the chunk or cannot send.
  Future<bool> sendChunk(EncryptedFileChunkEnvelope envelope);
}

/// Convenience adapter converting a callback closure into a [ChunkTransportSender].
class FunctionalChunkTransportSender implements ChunkTransportSender {
  FunctionalChunkTransportSender(this._sendFunction);

  final Future<bool> Function(EncryptedFileChunkEnvelope envelope) _sendFunction;

  @override
  Future<bool> sendChunk(EncryptedFileChunkEnvelope envelope) =>
      _sendFunction(envelope);
}

/// Token allowing cooperative cancellation of an active chunk sending pipeline.
class FileTransferCancellationToken {
  FileTransferCancellationToken();

  bool _isCancelled = false;
  String? _reason;

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Optional descriptive reason for cancellation.
  String? get reason => _reason;

  /// Requests cancellation with an optional [reason].
  void cancel([String? reason]) {
    _isCancelled = true;
    _reason = reason;
  }
}

/// Configurable rate-control and pacing policy for chunk transmission.
///
/// Units and defaults:
/// - [maxInFlightChunks]: 1 (stop-and-wait handoff, strictly bounded memory).
/// - [interChunkDelay]: [Duration.zero] (microseconds/milliseconds).
/// - [maxChunksPerSecond]: null (chunks per second).
///
/// Note: This policy controls transmission pacing in terms of chunks (packets) per
/// second and inter-chunk delays. It does NOT claim byte-per-second bandwidth throttling.
class ChunkSendingPolicy {
  const ChunkSendingPolicy({
    this.maxInFlightChunks = 1,
    this.interChunkDelay = Duration.zero,
    this.maxChunksPerSecond,
    this.delayFunction,
  }) : assert(maxInFlightChunks >= 1, 'maxInFlightChunks must be at least 1');

  /// Maximum number of in-flight chunk handoffs before backpressure is asserted.
  /// Defaults to 1 (strict stop-and-wait handoff).
  final int maxInFlightChunks;

  /// Fixed pacing delay inserted between consecutive chunk transmissions.
  /// Defaults to [Duration.zero].
  final Duration interChunkDelay;

  /// Maximum chunk throughput in chunks per second.
  /// When specified (> 0), enforces a minimum spacing of `1,000,000 / maxChunksPerSecond`
  /// microseconds between successive chunk emissions.
  final double? maxChunksPerSecond;

  /// Optional injectable delay function for deterministic testing without real wall-clock sleeps.
  /// Defaults to [Future.delayed].
  final Future<void> Function(Duration duration)? delayFunction;

  /// Validates policy parameters at runtime, throwing [ArgumentError] on invalid values.
  void validate() {
    if (maxInFlightChunks < 1) {
      throw ArgumentError.value(
        maxInFlightChunks,
        'maxInFlightChunks',
        'maxInFlightChunks must be at least 1',
      );
    }
    if (interChunkDelay.isNegative) {
      throw ArgumentError.value(
        interChunkDelay,
        'interChunkDelay',
        'interChunkDelay cannot be negative',
      );
    }
    if (maxChunksPerSecond != null) {
      if (maxChunksPerSecond!.isNaN ||
          maxChunksPerSecond!.isInfinite ||
          maxChunksPerSecond! <= 0) {
        throw ArgumentError.value(
          maxChunksPerSecond,
          'maxChunksPerSecond',
          'maxChunksPerSecond must be a finite positive number (> 0)',
        );
      }
    }
  }

  /// Computes the effective delay required between chunk emissions based on
  /// [interChunkDelay] and [maxChunksPerSecond].
  Duration get effectiveChunkDelay {
    var delay = interChunkDelay;
    if (maxChunksPerSecond != null && maxChunksPerSecond! > 0) {
      final rateMicros = (1000000 / maxChunksPerSecond!).round();
      final rateDuration = Duration(microseconds: rateMicros);
      if (rateDuration > delay) {
        delay = rateDuration;
      }
    }
    return delay;
  }
}

/// Immutable progress report emitted during file chunk sending.
class ChunkSendProgress {
  const ChunkSendProgress({
    required this.transferId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.bytesSent,
    required this.totalBytes,
  });

  final String transferId;
  final int chunkIndex;
  final int totalChunks;
  final int bytesSent;
  final int totalBytes;

  /// Fraction of bytes sent in range [0.0, 1.0].
  double get fraction =>
      totalBytes > 0 ? (bytesSent / totalBytes).clamp(0.0, 1.0) : 1.0;

  /// Integer percentage in range [0, 100].
  int get percentage => (fraction * 100).round();

  @override
  String toString() =>
      'ChunkSendProgress(transferId: $transferId, chunk: $chunkIndex/$totalChunks, bytes: $bytesSent/$totalBytes, $percentage%)';
}

/// Progress callback signature.
typedef ChunkProgressCallback = void Function(ChunkSendProgress progress);

/// Summary result of a chunk sending pipeline execution.
class ChunkSendingResult {
  const ChunkSendingResult({
    required this.transferId,
    required this.chunksSent,
    required this.totalChunks,
    required this.bytesSent,
    required this.totalBytes,
    required this.status,
    this.isCancelled = false,
    this.error,
  });

  final String transferId;
  final int chunksSent;
  final int totalChunks;
  final int bytesSent;
  final int totalBytes;
  final FileTransferStatus status;
  final bool isCancelled;
  final Object? error;

  bool get isSuccess => error == null && !isCancelled;

  @override
  String toString() =>
      'ChunkSendingResult(transferId: $transferId, chunksSent: $chunksSent/$totalChunks, bytesSent: $bytesSent/$totalBytes, status: ${status.name}, isCancelled: $isCancelled, error: $error)';
}

/// Base exception class for chunk sending errors.
abstract class ChunkSendingException implements Exception {
  const ChunkSendingException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? '$runtimeType: $message (caused by: $cause)'
      : '$runtimeType: $message';
}

/// Thrown when chunk sending is cancelled via a [FileTransferCancellationToken].
class ChunkSendCancelledException extends ChunkSendingException {
  const ChunkSendCancelledException(super.message, [super.cause]);
}

/// Thrown when local transport handoff fails or rejects a chunk.
class ChunkSendFailureException extends ChunkSendingException {
  const ChunkSendFailureException(
    String message, {
    this.chunkIndex,
    Object? cause,
  }) : super(message, cause);

  final int? chunkIndex;
}

/// Thrown when the source file on disk does not match the transfer metadata.
class SourceFileSizeMismatchException extends ChunkSendingException {
  const SourceFileSizeMismatchException(super.message, [super.cause]);
}

/// Thrown when chunk index, offset, length, or total chunk count violates metadata invariants.
class ChunkMetadataMismatchException extends ChunkSendingException {
  const ChunkMetadataMismatchException(super.message, [super.cause]);
}

/// Thrown when attempting to send a transfer from an invalid or unpermitted state.
class InvalidSendingStateException extends ChunkSendingException {
  const InvalidSendingStateException(super.message, [super.cause]);
}

/// Thrown when the destination peer fails trust policy verification.
class PeerUntrustedSendingException extends ChunkSendingException {
  const PeerUntrustedSendingException(super.message, [super.cause]);
}

/// Internal tracked in-flight chunk representation.
class _InFlightSend {
  _InFlightSend({
    required this.chunkIndex,
    required this.chunkLength,
    required this.future,
  });

  final int chunkIndex;
  final int chunkLength;
  final Future<bool> future;
}

/// Core pipeline service for streaming, encrypting, rate-limiting, and handing off
/// file chunks to the local transport subsystem.
///
/// Phase 8 Step 10: Chunk Sending Pipeline & Rate Control.
///
/// Architectural properties:
/// 1. Incremental Streaming: Reads the source file via [FileStreamReader] in bounded
///    chunks without loading the whole file into memory.
/// 2. Bounded Memory: Backpressure limits the number of un-awaited chunk handoffs to
///    [ChunkSendingPolicy.maxInFlightChunks] (default 1).
/// 3. Step 8 Cryptography: Encrypts each chunk under ChaCha20-Poly1305 with canonical
///    AAD binding protocol metadata into an [EncryptedFileChunkEnvelope].
/// 4. Serialized Encryption: Enforces sequential execution of chunk encryption so
///    ephemeral session sequence numbers and AEAD nonces advance monotonically ($N, N+1, \dots$).
/// 5. Configurable Rate Control: Enforces inter-chunk delays and throughput limits with
///    an injectable delay function for deterministic testing.
/// 6. Prompt Cancellation: Monitors [FileTransferCancellationToken] between and during chunk operations,
///    promptly terminating chunk reading, draining pending sends, and closing all file handles.
/// 7. State Machine Compliance: Transitions transfer from `acceptReceived` or `paused` to
///    `transferring`. NEVER marks the transfer `completed` upon finishing handoffs.
/// 8. Source-File Mutation Semantics: Does not take OS-level snapshot locks. If the source
///    file changes size or structure while streaming, length and boundary mismatches are
///    strictly caught and rejected with [ChunkMetadataMismatchException]. Whole-file assembly
///    and SHA-256 hash validation are deferred to Step 13.
class ChunkSendingPipeline {
  ChunkSendingPipeline({
    required this.localDeviceId,
    FileStreamReader? streamReader,
    FileTransferCryptoService? cryptoService,
    FileTransferStateMachine? stateMachine,
    this.database,
    this.messageRepository,
    ChunkSendingPolicy? defaultPolicy,
    this.requireVerifiedPeer = false,
  })  : _streamReader = streamReader ?? FileStreamReader(),
        _cryptoService = cryptoService ?? FileTransferCryptoService(),
        _stateMachine = stateMachine ?? FileTransferStateMachine.instance,
        _defaultPolicy = defaultPolicy ?? const ChunkSendingPolicy();

  final String localDeviceId;
  final FileStreamReader _streamReader;
  final FileTransferCryptoService _cryptoService;
  final FileTransferStateMachine _stateMachine;
  final AppDatabase? database;
  final MessageRepository? messageRepository;
  final ChunkSendingPolicy _defaultPolicy;
  final bool requireVerifiedPeer;

  /// Returns the underlying [FileStreamReader] for resource diagnostics in tests.
  FileStreamReader get streamReader => _streamReader;

  /// Returns the underlying [FileTransferCryptoService].
  FileTransferCryptoService get cryptoService => _cryptoService;

  /// Validates pre-flight conditions and streams all chunks of [transfer] through
  /// encryption, rate-limiting, and local transport handoff via [transportSender].
  ///
  /// Parameters:
  /// - [transfer]: Outgoing [FileTransfer] record in `acceptReceived` or `paused` status.
  /// - [session]: Active authenticated [EphemeralSession] established with the recipient.
  /// - [transportSender]: Local transport handoff boundary.
  /// - [policy]: Optional override for rate control and in-flight window.
  /// - [cancellationToken]: Optional cancellation token for early termination.
  /// - [onProgress]: Optional callback invoked after each chunk is successfully handed off.
  /// - [throwOnError]: If true (default), throws [ChunkSendingException] on errors; if false,
  ///   returns [ChunkSendingResult] containing error information.
  Future<ChunkSendingResult> sendTransfer({
    required FileTransfer transfer,
    required EphemeralSession session,
    required ChunkTransportSender transportSender,
    ChunkSendingPolicy? policy,
    FileTransferCancellationToken? cancellationToken,
    ChunkProgressCallback? onProgress,
    bool throwOnError = true,
  }) async {
    final effectivePolicy = policy ?? _defaultPolicy;
    effectivePolicy.validate();

    var currentStatus = transfer.status;
    var chunksSent = 0;
    var bytesSent = 0;
    final inFlightSends = <_InFlightSend>[];

    Object? inFlightError;
    int? failedInFlightChunkIndex;
    final failureCompleter = Completer<void>();

    void recordInFlightError(int chunkIndex, Object error) {
      if (inFlightError == null && failedInFlightChunkIndex == null) {
        inFlightError = error;
        failedInFlightChunkIndex = chunkIndex;
        if (!failureCompleter.isCompleted) {
          failureCompleter.complete();
        }
      }
    }

    void recordInFlightRejection(int chunkIndex) {
      if (inFlightError == null && failedInFlightChunkIndex == null) {
        failedInFlightChunkIndex = chunkIndex;
        if (!failureCompleter.isCompleted) {
          failureCompleter.complete();
        }
      }
    }

    void checkInFlightFailure() {
      if (inFlightError != null) {
        throw ChunkSendFailureException(
          'Transport threw exception during local handoff of chunk $failedInFlightChunkIndex: $inFlightError',
          chunkIndex: failedInFlightChunkIndex,
          cause: inFlightError,
        );
      }
      if (failedInFlightChunkIndex != null) {
        throw ChunkSendFailureException(
          'Transport refused or failed local handoff for chunk $failedInFlightChunkIndex of transfer ${transfer.transferId}.',
          chunkIndex: failedInFlightChunkIndex,
        );
      }
    }

    Future<void> drainInFlightSends() async {
      final pending = List<_InFlightSend>.from(inFlightSends);
      inFlightSends.clear();
      for (final item in pending) {
        try {
          await item.future;
        } catch (_) {
          // Observed to prevent unhandled asynchronous exceptions in the event loop.
        }
      }
    }

    try {
      // 1. Initial cancellation check
      if (cancellationToken != null && cancellationToken.isCancelled) {
        throw ChunkSendCancelledException(
          'Transfer ${transfer.transferId} was cancelled before sending started: ${cancellationToken.reason ?? "no reason specified"}',
        );
      }

      // 2. Pre-flight validations
      await _validatePreFlight(
        transfer: transfer,
        session: session,
      );

      // 3. State transition: acceptReceived / paused -> transferring
      final transitionResult = _stateMachine.transition(
        direction: transfer.direction,
        from: transfer.status,
        to: FileTransferStatus.transferring,
      );
      if (!transitionResult.allowed) {
        throw InvalidSendingStateException(
          'Cannot start sending transfer ${transfer.transferId}: ${transitionResult.error}',
        );
      }

      currentStatus = FileTransferStatus.transferring;

      // Persist status change to database if database is configured
      if (database != null) {
        await database!.updateFileTransferStatus(
          transfer.transferId,
          FileTransferStatus.transferring.toDbValue(),
        );
      }

      // 4. Handle empty file (0 bytes -> 0 chunks)
      if (transfer.fileSize == 0) {
        if (cancellationToken != null && cancellationToken.isCancelled) {
          throw ChunkSendCancelledException(
            'Transfer ${transfer.transferId} was cancelled before zero-byte completion: ${cancellationToken.reason ?? "no reason specified"}',
          );
        }

        return ChunkSendingResult(
          transferId: transfer.transferId,
          chunksSent: 0,
          totalChunks: 0,
          bytesSent: 0,
          totalBytes: 0,
          status: FileTransferStatus.transferring,
        );
      }

      // 5. Stream and send chunks with bounded backpressure and serialized encryption
      var chunksProduced = 0;

      final chunkStream = _streamReader.readFile(
        filePath: transfer.localPath,
        chunkSize: transfer.chunkSize,
      );

      Future<void> awaitOldestInFlight() async {
        if (inFlightSends.isEmpty) return;
        checkInFlightFailure();

        final inFlight = inFlightSends.removeAt(0);

        bool success;
        try {
          if (!failureCompleter.isCompleted) {
            await Future.any([inFlight.future, failureCompleter.future]);
          }
          checkInFlightFailure();
          success = await inFlight.future;
        } catch (e) {
          await drainInFlightSends();
          if (e is ChunkSendFailureException) rethrow;
          throw ChunkSendFailureException(
            'Transport threw exception during local handoff of chunk ${inFlight.chunkIndex}: $e',
            chunkIndex: inFlight.chunkIndex,
            cause: e,
          );
        }

        if (!success) {
          await drainInFlightSends();
          throw ChunkSendFailureException(
            'Transport refused or failed local handoff for chunk ${inFlight.chunkIndex} of transfer ${transfer.transferId}.',
            chunkIndex: inFlight.chunkIndex,
          );
        }

        // Successfully confirmed local handoff: update completed progress counters
        chunksSent++;
        bytesSent += inFlight.chunkLength;
        onProgress?.call(
          ChunkSendProgress(
            transferId: transfer.transferId,
            chunkIndex: inFlight.chunkIndex,
            totalChunks: transfer.totalChunks,
            bytesSent: bytesSent,
            totalBytes: transfer.fileSize,
          ),
        );
      }

      Future<void> awaitAllInFlight() async {
        while (inFlightSends.isNotEmpty) {
          await awaitOldestInFlight();
        }
      }

      await for (final chunk in chunkStream) {
        checkInFlightFailure();

        // A. Cooperative cancellation check
        if (cancellationToken != null && cancellationToken.isCancelled) {
          await drainInFlightSends();
          throw ChunkSendCancelledException(
            'Transfer ${transfer.transferId} cancelled by token: ${cancellationToken.reason ?? "no reason specified"}',
          );
        }

        final chunkIndex = chunksProduced;
        if (chunkIndex >= transfer.totalChunks) {
          throw ChunkMetadataMismatchException(
            'Chunk index ($chunkIndex) exceeded totalChunks (${transfer.totalChunks}) for transfer ${transfer.transferId}.',
          );
        }

        // B. Validate chunk offset and length against metadata invariants
        final expectedOffset = FileStreamReader.calculateChunkOffset(
          chunkIndex: chunkIndex,
          chunkSize: transfer.chunkSize,
        );
        final expectedLength = FileStreamReader.calculateChunkLength(
          chunkIndex: chunkIndex,
          fileSize: transfer.fileSize,
          chunkSize: transfer.chunkSize,
        );

        if (chunk.length != expectedLength) {
          throw ChunkMetadataMismatchException(
            'Chunk $chunkIndex actual length (${chunk.length}) does not match expected length ($expectedLength) for transfer ${transfer.transferId}.',
          );
        }

        // C. Backpressure: await in-flight capacity if window is full
        while (inFlightSends.length >= effectivePolicy.maxInFlightChunks) {
          await awaitOldestInFlight();
        }

        checkInFlightFailure();

        // D. Rate control and pacing (applied between chunks, i.e. chunkIndex > 0)
        if (chunkIndex > 0 && effectivePolicy.effectiveChunkDelay > Duration.zero) {
          final delayFn = effectivePolicy.delayFunction ?? Future.delayed;
          await delayFn(effectivePolicy.effectiveChunkDelay);

          checkInFlightFailure();

          // Re-check cancellation after pacing delay
          if (cancellationToken != null && cancellationToken.isCancelled) {
            await drainInFlightSends();
            throw ChunkSendCancelledException(
              'Transfer ${transfer.transferId} cancelled during pacing delay: ${cancellationToken.reason ?? "no reason specified"}',
            );
          }
        }

        // E. Serialized chunk encryption
        final envelope = await _cryptoService.encryptChunk(
          session: session,
          transferId: transfer.transferId,
          originId: localDeviceId,
          destinationId: transfer.peerId,
          chunkIndex: chunkIndex,
          totalChunks: transfer.totalChunks,
          offset: expectedOffset,
          plaintext: chunk,
          chunkLength: expectedLength,
        );

        checkInFlightFailure();

        // F. Hand off chunk to transport sender
        Future<bool> sendFuture;
        try {
          sendFuture = transportSender.sendChunk(envelope);
          sendFuture.then(
            (success) {
              if (!success) {
                recordInFlightRejection(chunkIndex);
              }
            },
            onError: (err) {
              recordInFlightError(chunkIndex, err as Object);
            },
          );
        } catch (e) {
          recordInFlightError(chunkIndex, e);
          await drainInFlightSends();
          throw ChunkSendFailureException(
            'Transport threw exception during local handoff of chunk $chunkIndex: $e',
            chunkIndex: chunkIndex,
            cause: e,
          );
        }

        inFlightSends.add(
          _InFlightSend(
            chunkIndex: chunkIndex,
            chunkLength: chunk.length,
            future: sendFuture,
          ),
        );
        chunksProduced++;

        // If stop-and-wait (maxInFlight == 1), await immediately
        if (effectivePolicy.maxInFlightChunks == 1) {
          await awaitOldestInFlight();
        }
      }

      // Await any remaining in-flight handoffs
      await awaitAllInFlight();

      // H. Validate full stream completion
      if (chunksSent != transfer.totalChunks || bytesSent != transfer.fileSize) {
        throw ChunkMetadataMismatchException(
          'Stream ended prematurely: sent $chunksSent/${transfer.totalChunks} chunks and $bytesSent/${transfer.fileSize} bytes.',
        );
      }

      // IMPORTANT CONTRACT: The transfer remains in `transferring` status!
      // Do NOT mark it completed, as confirmed remote delivery is Step 12 (ACK/NACK).
      return ChunkSendingResult(
        transferId: transfer.transferId,
        chunksSent: chunksSent,
        totalChunks: transfer.totalChunks,
        bytesSent: bytesSent,
        totalBytes: transfer.fileSize,
        status: FileTransferStatus.transferring,
      );
    } on ChunkSendingException catch (e) {
      await drainInFlightSends();
      if (throwOnError) rethrow;
      return ChunkSendingResult(
        transferId: transfer.transferId,
        chunksSent: chunksSent,
        totalChunks: transfer.totalChunks,
        bytesSent: bytesSent,
        totalBytes: transfer.fileSize,
        status: currentStatus,
        isCancelled: e is ChunkSendCancelledException,
        error: e,
      );
    } catch (e) {
      await drainInFlightSends();
      if (throwOnError) {
        throw ChunkSendFailureException(
          'Unexpected error in chunk sending pipeline: $e',
          cause: e,
        );
      }
      return ChunkSendingResult(
        transferId: transfer.transferId,
        chunksSent: chunksSent,
        totalChunks: transfer.totalChunks,
        bytesSent: bytesSent,
        totalBytes: transfer.fileSize,
        status: currentStatus,
        error: e,
      );
    }
  }

  /// Strict pre-flight validations verifying transfer direction, lifecycle state,
  /// peer trust, session health, and source file consistency.
  Future<void> _validatePreFlight({
    required FileTransfer transfer,
    required EphemeralSession session,
  }) async {
    // 1. Direction check
    if (transfer.direction != FileTransferDirection.outgoing) {
      throw InvalidSendingStateException(
        'Cannot send transfer ${transfer.transferId}: direction is ${transfer.direction.name} (must be outgoing).',
      );
    }

    // 2. Lifecycle state check: must be acceptReceived or paused
    if (transfer.status != FileTransferStatus.acceptReceived &&
        transfer.status != FileTransferStatus.paused) {
      throw InvalidSendingStateException(
        'Cannot send transfer ${transfer.transferId}: current status is ${transfer.status.name} (must be acceptReceived or paused).',
      );
    }

    // 3. Session state check
    if (session.isDestroyed) {
      throw const InvalidSendingStateException(
        'Cannot send transfer: ephemeral session is destroyed.',
      );
    }
    if (session.state != SessionLifecycleState.activeSession) {
      throw InvalidSendingStateException(
        'Cannot send transfer: ephemeral session is in invalid state (${session.state}).',
      );
    }

    // 4. Peer trust verification
    final repo = messageRepository;
    if (repo != null) {
      final peerIdentity = await repo.getPeerIdentity(transfer.peerId);
      if (peerIdentity != null) {
        if (peerIdentity.trustStatus == 'compromised') {
          throw PeerUntrustedSendingException(
            'Cannot send transfer to peer ${transfer.peerId}: peer identity is marked compromised.',
          );
        }
        if (requireVerifiedPeer && peerIdentity.trustStatus != 'verified') {
          throw PeerUntrustedSendingException(
            'Cannot send transfer to peer ${transfer.peerId}: peer identity status is ${peerIdentity.trustStatus} (verified required).',
          );
        }
      } else if (requireVerifiedPeer) {
        throw PeerUntrustedSendingException(
          'Cannot send transfer to peer ${transfer.peerId}: no peer identity record found and verified peer is required.',
        );
      }
    }

    // 5. Source file validation on disk
    final actualFileSize = await _streamReader.getFileSize(transfer.localPath);
    if (actualFileSize != transfer.fileSize) {
      throw SourceFileSizeMismatchException(
        'Actual file size on disk ($actualFileSize bytes) does not match transfer metadata (${transfer.fileSize} bytes) for ${transfer.localPath}.',
      );
    }

    // 6. Total chunk count consistency
    final expectedTotalChunks = FileStreamReader.calculateTotalChunks(
      fileSize: transfer.fileSize,
      chunkSize: transfer.chunkSize,
    );
    if (transfer.totalChunks != expectedTotalChunks) {
      throw ChunkMetadataMismatchException(
        'Transfer totalChunks (${transfer.totalChunks}) does not match computed chunk count ($expectedTotalChunks) for file size ${transfer.fileSize} and chunk size ${transfer.chunkSize}.',
      );
    }
  }
}

/// Riverpod provider exposing the [ChunkSendingPipeline] service.
final chunkSendingPipelineProvider = Provider<ChunkSendingPipeline>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(messageRepositoryProvider);
  final crypto = FileTransferCryptoService(
    encryptionService: ref.watch(directionalSessionEncryptionServiceProvider),
  );
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );
  return ChunkSendingPipeline(
    localDeviceId: discoveryController.localIdentity.id,
    database: db,
    messageRepository: repo,
    cryptoService: crypto,
  );
});
