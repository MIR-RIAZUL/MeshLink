import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
import 'package:meshlink/features/messages/providers/messaging_providers.dart';

/// Base exception for file transfer negotiation errors.
class FileTransferNegotiationException implements Exception {
  const FileTransferNegotiationException(this.message);
  final String message;

  @override
  String toString() => 'FileTransferNegotiationException: $message';
}

/// Thrown when an offer or decision timestamp has expired.
class OfferExpiredException extends FileTransferNegotiationException {
  const OfferExpiredException(super.message);
}

/// Thrown when a timestamp is invalid or skewed too far into the future.
class InvalidTimestampException extends FileTransferNegotiationException {
  const InvalidTimestampException(super.message);
}

/// Thrown when the remote peer is untrusted, compromised, or fails verification policy.
class PeerUntrustedException extends FileTransferNegotiationException {
  const PeerUntrustedException(super.message);
}

/// Thrown when an offer conflicts with an existing transfer.
class TransferConflictException extends FileTransferNegotiationException {
  const TransferConflictException(super.message);
}

/// Thrown when the referenced transfer cannot be found in persistence.
class TransferNotFoundException extends FileTransferNegotiationException {
  const TransferNotFoundException(super.message);
}

/// Thrown when an invalid state transition is requested during negotiation.
class InvalidNegotiationStateException extends FileTransferNegotiationException {
  const InvalidNegotiationStateException(super.message);
}

/// Service managing application-level file transfer negotiation handshakes.
///
/// Phase 8 Step 9: File Negotiation Handshake.
///
/// Flow:
/// ```text
/// Sender creates offer
///         ↓
/// Offer authenticated & encrypted (via Phase 7 session)
///         ↓
/// Recipient validates & decrypts offer
///         ↓
/// Recipient accepts or rejects
///         ↓
/// Sender validates decision
///         ↓
/// Both sides update transfer state machine
/// ```
///
/// Security and architectural properties:
/// - Reuses Phase 7 session encryption with canonical AAD.
/// - Validates remote peer trust status before recording incoming offers, accepting offers, or handling decisions.
/// - Supports strict peer verification policy (`requireVerifiedPeer`), rejecting `tofu_unverified` or missing records when required.
/// - Enforces strict state transitions via [FileTransferStateMachine].
/// - Handles duplicate messages and idempotent responses safely.
/// - Zero filesystem IO: no staging files created or buffers allocated during negotiation.
/// - Per-transfer async mutex prevents race conditions between concurrent decisions.
class FileTransferNegotiationService {
  FileTransferNegotiationService({
    required AppDatabase database,
    required this.localDeviceId,
    this.messageRepository,
    DirectionalSessionEncryptionService? encryptionService,
    FileTransferStateMachine? stateMachine,
    DateTime Function()? clock,
    this.defaultOfferValidity = const Duration(minutes: 5),
    this.maxFutureSkew = const Duration(minutes: 2),
    this.maxPendingOffers = 256,
    this.requireVerifiedPeer = false,
  })  : _db = database,
        _encryptionService =
            encryptionService ?? DirectionalSessionEncryptionService(),
        _stateMachine = stateMachine ?? FileTransferStateMachine.instance,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final String localDeviceId;
  final MessageRepository? messageRepository;
  final DirectionalSessionEncryptionService _encryptionService;
  final FileTransferStateMachine _stateMachine;
  final DateTime Function() _clock;
  final Duration defaultOfferValidity;
  final Duration maxFutureSkew;
  final int maxPendingOffers;
  final bool requireVerifiedPeer;

  /// Dedicated packet types for canonical AAD construction.
  static const String offerPacketType = 'file_offer';
  static const String decisionPacketType = 'file_decision';

  /// Bounded in-memory cache of pending offers for request/offer ID and expiration checks.
  final Map<String, FileTransferOffer> _pendingOffers = {};

  /// Per-transfer asynchronous locks to ensure serialized, atomic operations.
  final Map<String, Completer<void>> _transferLocks = {};

  /// Constructs canonical binary Authenticated Additional Data (AAD) for a file offer.
  static Uint8List buildOfferAad({
    int version = 2,
    required String sessionId,
    required String originId,
    required String destinationId,
    required String transferId,
    int? epoch,
    int? sequenceNumber,
  }) {
    return DirectionalSessionEncryptionService.buildCanonicalAad(
      version: version,
      packetType: offerPacketType,
      sessionId: sessionId,
      originId: originId,
      destinationId: destinationId,
      messageId: transferId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
    );
  }

  /// Constructs canonical binary Authenticated Additional Data (AAD) for a file decision.
  static Uint8List buildDecisionAad({
    int version = 2,
    required String sessionId,
    required String originId,
    required String destinationId,
    required String transferId,
    int? epoch,
    int? sequenceNumber,
  }) {
    return DirectionalSessionEncryptionService.buildCanonicalAad(
      version: version,
      packetType: decisionPacketType,
      sessionId: sessionId,
      originId: originId,
      destinationId: destinationId,
      messageId: transferId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
    );
  }

  /// Executes [action] under a per-transfer async lock to prevent concurrency races.
  Future<T> _synchronized<T>(String transferId, Future<T> Function() action) async {
    while (_transferLocks.containsKey(transferId)) {
      await _transferLocks[transferId]!.future;
    }
    final completer = Completer<void>();
    _transferLocks[transferId] = completer;
    try {
      return await action();
    } finally {
      _transferLocks.remove(transferId);
      completer.complete();
    }
  }

  /// Internal helper to verify peer trust according to policy.
  Future<void> _verifyPeerTrust({
    required String peerId,
    required String operation,
  }) async {
    final repo = messageRepository;
    if (repo == null) return;

    final peer = await repo.getPeerIdentity(peerId);
    if (peer == null) {
      if (requireVerifiedPeer) {
        throw PeerUntrustedException(
          'Cannot $operation: peer $peerId identity is missing (verified identity required).',
        );
      }
      return; // Permitted under default TOFU
    }

    final status = peer.trustStatus.trim().toLowerCase();
    if (status == 'compromised') {
      throw PeerUntrustedException(
        'Cannot $operation: peer $peerId is marked as compromised.',
      );
    }

    if (requireVerifiedPeer && status != 'verified') {
      throw PeerUntrustedException(
        'Cannot $operation: peer $peerId has trustStatus "$status" (verified identity required).',
      );
    }
  }

  /// Internal helper to verify session identity key matches stored peer identity.
  Future<void> _verifySessionPeerKey({
    required EphemeralSession session,
    required String authenticatedSenderId,
  }) async {
    if (session.peerId != authenticatedSenderId) {
      throw PeerUntrustedException(
        'Session peer ID (${session.peerId}) does not match authenticated sender ($authenticatedSenderId).',
      );
    }

    final repo = messageRepository;
    if (repo != null) {
      final peer = await repo.getPeerIdentity(authenticatedSenderId);
      if (peer != null) {
        try {
          final storedKey = MeshIdentityService.decodePublicKey(peer.identityPublicKey);
          if (!EphemeralSession.constantTimeCompare(session.peerIdentityPublicKey, storedKey)) {
            throw PeerUntrustedException(
              'Peer $authenticatedSenderId presented identity key mismatch against stored identity record.',
            );
          }
        } catch (e) {
          if (e is PeerUntrustedException) rethrow;
          throw PeerUntrustedException(
            'Invalid stored identity key for peer $authenticatedSenderId: $e',
          );
        }
      }
    }
  }

  /// Creates and records an outgoing file transfer offer.
  ///
  /// Transitions state: `initiated` -> `offerSent`.
  Future<FileTransferOffer> createOffer({
    required String transferId,
    required String recipientId,
    required String fileName,
    required int fileSize,
    String mimeType = 'application/octet-stream',
    int chunkSize = FileTransferOffer.defaultChunkSize,
    String? fileHash,
    String? conversationId,
    Duration? validityDuration,
  }) async {
    return _synchronized(transferId, () async {
      final now = _clock();
      final validity = validityDuration ?? defaultOfferValidity;
      final expiresAt = now.add(validity);
      final offerId = 'offer_$transferId';

      // 1. Peer trust verification
      await _verifyPeerTrust(
        peerId: recipientId,
        operation: 'create offer',
      );

      // 2. Calculate chunk count and validate
      final int totalChunks = fileSize == 0 ? 0 : (fileSize / chunkSize).ceil();

      final offer = FileTransferOffer(
        version: 2,
        transferId: transferId,
        offerId: offerId,
        senderId: localDeviceId,
        recipientId: recipientId,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        fileHash: fileHash,
        createdAt: now,
        expiresAt: expiresAt,
      );

      // 2. Check if a transfer with this ID already exists
      final existingEntry = await _db.getFileTransfer(transferId);
      if (existingEntry != null) {
        final existing = FileTransfer.fromEntry(existingEntry);
        final isIdentical = existing.fileName == fileName &&
            existing.fileSize == fileSize &&
            existing.peerId == recipientId &&
            existing.direction == FileTransferDirection.outgoing &&
            (existing.status == FileTransferStatus.initiated ||
                existing.status == FileTransferStatus.offerSent);

        if (isIdentical) {
          final cached = _pendingOffers[transferId];
          if (cached != null && !cached.isExpired(now)) {
            return cached;
          }
          _recordPendingOffer(offer);
          return offer;
        }

        throw TransferConflictException(
          'A transfer with ID "$transferId" already exists in status "${existing.status.name}".',
        );
      }

      // 3. Construct domain transfer record in initiated status
      final initialTransfer = FileTransfer(
        transferId: transferId,
        conversationId: conversationId ?? recipientId,
        peerId: recipientId,
        direction: FileTransferDirection.outgoing,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        fileHash: fileHash ?? '',
        localPath: '',
        stagingPath: '',
        totalChunks: totalChunks,
        chunkSize: chunkSize,
        status: FileTransferStatus.initiated,
        createdAt: now,
        updatedAt: now,
      );

      // 4. Transition: initiated -> offerSent
      final updatedTransfer = _stateMachine.applyTransition(
        transfer: initialTransfer,
        to: FileTransferStatus.offerSent,
        updatedAt: now,
      );

      // 5. Persist to database
      await _db.insertFileTransfer(updatedTransfer.toCompanion());
      _recordPendingOffer(offer);

      return offer;
    });
  }

  /// Validates and records an incoming file transfer offer.
  ///
  /// Requires [authenticatedSenderId] verified by the Phase 7 security layer.
  /// Transitions state: `initiated` -> `offerReceived`.
  Future<FileTransfer> receiveOffer({
    required FileTransferOffer offer,
    required String authenticatedSenderId,
  }) async {
    return _synchronized(offer.transferId, () async {
      // 1. Protocol version validation
      if (offer.version != 2) {
        throw FileTransferNegotiationException(
          'Unsupported protocol version: ${offer.version} (expected 2).',
        );
      }

      // 2. Recipient match validation
      if (offer.recipientId != localDeviceId) {
        throw FileTransferNegotiationException(
          'Offer recipient (${offer.recipientId}) does not match local device ($localDeviceId).',
        );
      }

      // 3. Sender authentication validation
      if (offer.senderId != authenticatedSenderId) {
        throw FileTransferNegotiationException(
          'Offer sender (${offer.senderId}) does not match authenticated peer ($authenticatedSenderId).',
        );
      }

      // 4. Peer trust verification
      await _verifyPeerTrust(
        peerId: offer.senderId,
        operation: 'receive offer',
      );

      // 5. Temporal validations
      final now = _clock();
      if (offer.isExpired(now)) {
        throw OfferExpiredException(
          'Offer for transfer "${offer.transferId}" expired at ${offer.expiresAt.toIso8601String()}.',
        );
      }
      if (offer.isFuture(now, maxFutureSkew)) {
        throw InvalidTimestampException(
          'Offer createdAt (${offer.createdAt.toIso8601String()}) is too far in the future.',
        );
      }

      // 6. Check existing transfer in database
      final existingEntry = await _db.getFileTransfer(offer.transferId);
      if (existingEntry != null) {
        final existing = FileTransfer.fromEntry(existingEntry);
        final isIdentical = existing.fileName == offer.fileName &&
            existing.fileSize == offer.fileSize &&
            existing.chunkSize == offer.chunkSize &&
            existing.totalChunks == offer.totalChunks &&
            existing.peerId == offer.senderId &&
            existing.direction == FileTransferDirection.incoming;

        if (isIdentical &&
            (existing.status == FileTransferStatus.initiated ||
                existing.status == FileTransferStatus.offerReceived)) {
          _recordPendingOffer(offer);
          return existing;
        }

        throw TransferConflictException(
          'Conflicting transfer with ID "${offer.transferId}" already exists in status "${existing.status.name}".',
        );
      }

      // 7. Create domain transfer record in initiated status
      final initialTransfer = FileTransfer(
        transferId: offer.transferId,
        conversationId: offer.senderId,
        peerId: offer.senderId,
        direction: FileTransferDirection.incoming,
        fileName: offer.fileName,
        fileSize: offer.fileSize,
        mimeType: offer.mimeType,
        fileHash: offer.fileHash ?? '',
        localPath: '',
        stagingPath: '',
        totalChunks: offer.totalChunks,
        chunkSize: offer.chunkSize,
        status: FileTransferStatus.initiated,
        createdAt: now,
        updatedAt: now,
      );

      // 8. Transition: initiated -> offerReceived
      final updatedTransfer = _stateMachine.applyTransition(
        transfer: initialTransfer,
        to: FileTransferStatus.offerReceived,
        updatedAt: now,
      );

      // 9. Persist to database
      await _db.insertFileTransfer(updatedTransfer.toCompanion());
      _recordPendingOffer(offer);

      return updatedTransfer;
    });
  }

  /// Explicitly accepts an incoming file offer.
  ///
  /// Transitions state: `offerReceived` -> `acceptSent`.
  Future<FileTransferDecision> acceptOffer({
    required String transferId,
    required String offerId,
  }) async {
    return _synchronized(transferId, () async {
      final entry = await _db.getFileTransfer(transferId);
      if (entry == null) {
        throw TransferNotFoundException(
          'Transfer with ID "$transferId" not found.',
        );
      }
      final transfer = FileTransfer.fromEntry(entry);

      if (transfer.direction != FileTransferDirection.incoming) {
        throw InvalidNegotiationStateException(
          'Cannot accept an outgoing file transfer.',
        );
      }

      // Check terminal states
      if (transfer.status == FileTransferStatus.cancelled ||
          transfer.status == FileTransferStatus.failed ||
          transfer.status == FileTransferStatus.completed) {
        throw InvalidNegotiationStateException(
          'Cannot accept transfer in terminal status "${transfer.status.name}".',
        );
      }

      // Idempotency: if already accepted, return existing decision
      if (transfer.status == FileTransferStatus.acceptSent) {
        return FileTransferDecision(
          version: 2,
          transferId: transferId,
          offerId: offerId,
          decisionType: FileTransferDecisionType.accept,
          senderId: localDeviceId,
          recipientId: transfer.peerId,
          createdAt: _clock(),
        );
      }

      if (transfer.status != FileTransferStatus.offerReceived) {
        throw InvalidNegotiationStateException(
          'Cannot accept transfer in status "${transfer.status.name}" (must be offerReceived).',
        );
      }

      // Verify peer trust before accepting
      await _verifyPeerTrust(
        peerId: transfer.peerId,
        operation: 'accept offer',
      );

      // Pending offer validation
      final pending = _pendingOffers[transferId];
      if (pending != null) {
        if (pending.offerId != offerId) {
          throw FileTransferNegotiationException(
            'Offer ID mismatch: expected "${pending.offerId}", got "$offerId".',
          );
        }
        final now = _clock();
        if (pending.isExpired(now)) {
          throw OfferExpiredException(
            'Offer for transfer "$transferId" has expired.',
          );
        }
      }

      final now = _clock();

      // Transition: offerReceived -> acceptSent
      final updated = _stateMachine.applyTransition(
        transfer: transfer,
        to: FileTransferStatus.acceptSent,
        updatedAt: now,
      );

      await _db.updateFileTransferStatus(
        transferId,
        updated.status.toDbValue(),
        updatedAt: now,
      );

      return FileTransferDecision(
        version: 2,
        transferId: transferId,
        offerId: offerId,
        decisionType: FileTransferDecisionType.accept,
        senderId: localDeviceId,
        recipientId: transfer.peerId,
        createdAt: now,
      );
    });
  }

  /// Explicitly rejects an incoming file offer.
  ///
  /// Transitions state: `offerReceived` -> `cancelled`.
  Future<FileTransferDecision> rejectOffer({
    required String transferId,
    required String offerId,
    FileTransferRejectionReason reason = FileTransferRejectionReason.userRejected,
  }) async {
    return _synchronized(transferId, () async {
      final entry = await _db.getFileTransfer(transferId);
      if (entry == null) {
        throw TransferNotFoundException(
          'Transfer with ID "$transferId" not found.',
        );
      }
      final transfer = FileTransfer.fromEntry(entry);

      if (transfer.direction != FileTransferDirection.incoming) {
        throw InvalidNegotiationStateException(
          'Cannot reject an outgoing file transfer.',
        );
      }

      // Idempotency: if already cancelled, return decision idempotently
      if (transfer.status == FileTransferStatus.cancelled) {
        return FileTransferDecision(
          version: 2,
          transferId: transferId,
          offerId: offerId,
          decisionType: FileTransferDecisionType.reject,
          rejectionReason: reason,
          senderId: localDeviceId,
          recipientId: transfer.peerId,
          createdAt: _clock(),
        );
      }

      // Disallow rejection after acceptance
      if (transfer.status == FileTransferStatus.acceptSent ||
          transfer.status == FileTransferStatus.transferring) {
        throw InvalidNegotiationStateException(
          'Cannot reject transfer after acceptance (current status: "${transfer.status.name}").',
        );
      }

      if (transfer.status != FileTransferStatus.offerReceived) {
        throw InvalidNegotiationStateException(
          'Cannot reject transfer in status "${transfer.status.name}".',
        );
      }

      final pending = _pendingOffers[transferId];
      if (pending != null && pending.offerId != offerId) {
        throw FileTransferNegotiationException(
          'Offer ID mismatch: expected "${pending.offerId}", got "$offerId".',
        );
      }

      final now = _clock();

      // Transition: offerReceived -> cancelled
      final updated = _stateMachine.applyTransition(
        transfer: transfer,
        to: FileTransferStatus.cancelled,
        updatedAt: now,
      );

      await _db.updateFileTransferStatus(
        transferId,
        updated.status.toDbValue(),
        updatedAt: now,
      );

      _pendingOffers.remove(transferId);

      return FileTransferDecision(
        version: 2,
        transferId: transferId,
        offerId: offerId,
        decisionType: FileTransferDecisionType.reject,
        rejectionReason: reason,
        senderId: localDeviceId,
        recipientId: transfer.peerId,
        createdAt: now,
      );
    });
  }

  /// Processes a decision received in response to an outgoing offer.
  ///
  /// Transitions state:
  /// - `offerSent` -> `acceptReceived` (if accepted)
  /// - `offerSent` -> `cancelled` (if rejected)
  Future<FileTransfer> handleDecision({
    required FileTransferDecision decision,
    required String authenticatedSenderId,
  }) async {
    return _synchronized(decision.transferId, () async {
      // 1. Protocol version validation
      if (decision.version != 2) {
        throw FileTransferNegotiationException(
          'Unsupported protocol version: ${decision.version} (expected 2).',
        );
      }

      // 2. Recipient match validation
      if (decision.recipientId != localDeviceId) {
        throw FileTransferNegotiationException(
          'Decision recipient (${decision.recipientId}) does not match local device ($localDeviceId).',
        );
      }

      // 3. Sender authentication validation
      if (decision.senderId != authenticatedSenderId) {
        throw FileTransferNegotiationException(
          'Decision sender (${decision.senderId}) does not match authenticated peer ($authenticatedSenderId).',
        );
      }

      // 4. Peer trust verification
      await _verifyPeerTrust(
        peerId: decision.senderId,
        operation: 'handle decision',
      );

      // 5. Future timestamp skew check
      final now = _clock();
      if (decision.isFuture(now, maxFutureSkew)) {
        throw InvalidTimestampException(
          'Decision createdAt (${decision.createdAt.toIso8601String()}) is too far in the future.',
        );
      }

      // 6. Query transfer from database
      final entry = await _db.getFileTransfer(decision.transferId);
      if (entry == null) {
        throw TransferNotFoundException(
          'Transfer with ID "${decision.transferId}" not found.',
        );
      }
      final transfer = FileTransfer.fromEntry(entry);

      if (transfer.direction != FileTransferDirection.outgoing) {
        throw InvalidNegotiationStateException(
          'Received decision for an incoming file transfer.',
        );
      }

      if (transfer.peerId != decision.senderId) {
        throw FileTransferNegotiationException(
          'Decision sender (${decision.senderId}) does not match transfer peer (${transfer.peerId}).',
        );
      }

      final pending = _pendingOffers[decision.transferId];
      if (pending != null) {
        if (pending.offerId != decision.offerId) {
          throw FileTransferNegotiationException(
            'Decision offerId "${decision.offerId}" does not match offerId "${pending.offerId}".',
          );
        }
        if (pending.isExpired(now)) {
          throw OfferExpiredException('Decision received for expired offer.');
        }
      }

      if (decision.isAccepted) {
        // Idempotency: if already in acceptReceived, return transfer
        if (transfer.status == FileTransferStatus.acceptReceived) {
          return transfer;
        }

        // Terminal transfer check
        if (transfer.status == FileTransferStatus.cancelled ||
            transfer.status == FileTransferStatus.failed) {
          throw InvalidNegotiationStateException(
            'Cannot accept a cancelled or failed transfer (status: "${transfer.status.name}"). Terminal transfer cannot be reopened.',
          );
        }

        if (transfer.status != FileTransferStatus.offerSent) {
          throw InvalidNegotiationStateException(
            'Cannot transition to acceptReceived from status "${transfer.status.name}".',
          );
        }

        // Transition: offerSent -> acceptReceived
        final updated = _stateMachine.applyTransition(
          transfer: transfer,
          to: FileTransferStatus.acceptReceived,
          updatedAt: now,
        );

        await _db.updateFileTransferStatus(
          decision.transferId,
          updated.status.toDbValue(),
          updatedAt: now,
        );

        return updated;
      } else {
        // isRejected
        if (transfer.status == FileTransferStatus.cancelled) {
          return transfer;
        }

        if (transfer.status == FileTransferStatus.acceptReceived ||
            transfer.status == FileTransferStatus.transferring) {
          throw InvalidNegotiationStateException(
            'Cannot reject transfer after acceptance (current status: "${transfer.status.name}").',
          );
        }

        if (transfer.status != FileTransferStatus.offerSent) {
          throw InvalidNegotiationStateException(
            'Cannot reject transfer in status "${transfer.status.name}".',
          );
        }

        // Transition: offerSent -> cancelled
        final updated = _stateMachine.applyTransition(
          transfer: transfer,
          to: FileTransferStatus.cancelled,
          updatedAt: now,
        );

        await _db.updateFileTransferStatus(
          decision.transferId,
          updated.status.toDbValue(),
          updatedAt: now,
        );

        _pendingOffers.remove(decision.transferId);

        return updated;
      }
    });
  }

  // --- Cryptographic Protocol Helpers ---

  /// Encrypts a [FileTransferOffer] into a [SessionEncryptedPayload] using ChaCha20-Poly1305
  /// and canonical AAD via [DirectionalSessionEncryptionService].
  Future<SessionEncryptedPayload> encryptOffer({
    required EphemeralSession session,
    required FileTransferOffer offer,
    int? epoch,
    int? sequenceNumber,
    Uint8List? explicitNonce,
  }) async {
    if (session.peerId != offer.recipientId) {
      throw FileTransferNegotiationException(
        'Session peer ID (${session.peerId}) does not match offer recipient (${offer.recipientId}).',
      );
    }

    final aad = buildOfferAad(
      version: offer.version,
      sessionId: session.sessionId,
      originId: offer.senderId,
      destinationId: offer.recipientId,
      transferId: offer.transferId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
    );

    return _encryptionService.encryptString(
      session: session,
      text: offer.toJson(),
      aad: aad,
      explicitNonce: explicitNonce,
    );
  }

  /// Decrypts a [SessionEncryptedPayload] into a [FileTransferOffer].
  Future<FileTransferOffer> decryptOffer({
    required EphemeralSession session,
    required SessionEncryptedPayload encrypted,
    required Uint8List aad,
  }) async {
    final jsonText = await _encryptionService.decryptString(
      session: session,
      encrypted: encrypted,
      aad: aad,
    );
    try {
      final offer = FileTransferOffer.fromJson(jsonText);
      if (offer.senderId != session.peerId) {
        throw FileTransferNegotiationException(
          'Decrypted offer sender (${offer.senderId}) does not match session peer (${session.peerId}).',
        );
      }
      return offer;
    } on FileTransferNegotiationException {
      rethrow;
    } catch (e) {
      throw FileTransferNegotiationException('Malformed offer payload: $e');
    }
  }

  /// Encrypts a [FileTransferDecision] into a [SessionEncryptedPayload].
  Future<SessionEncryptedPayload> encryptDecision({
    required EphemeralSession session,
    required FileTransferDecision decision,
    int? epoch,
    int? sequenceNumber,
    Uint8List? explicitNonce,
  }) async {
    if (session.peerId != decision.recipientId) {
      throw FileTransferNegotiationException(
        'Session peer ID (${session.peerId}) does not match decision recipient (${decision.recipientId}).',
      );
    }

    final aad = buildDecisionAad(
      version: decision.version,
      sessionId: session.sessionId,
      originId: decision.senderId,
      destinationId: decision.recipientId,
      transferId: decision.transferId,
      epoch: epoch,
      sequenceNumber: sequenceNumber,
    );

    return _encryptionService.encryptString(
      session: session,
      text: decision.toJson(),
      aad: aad,
      explicitNonce: explicitNonce,
    );
  }

  /// Decrypts a [SessionEncryptedPayload] into a [FileTransferDecision].
  Future<FileTransferDecision> decryptDecision({
    required EphemeralSession session,
    required SessionEncryptedPayload encrypted,
    required Uint8List aad,
  }) async {
    final jsonText = await _encryptionService.decryptString(
      session: session,
      encrypted: encrypted,
      aad: aad,
    );
    try {
      final decision = FileTransferDecision.fromJson(jsonText);
      if (decision.senderId != session.peerId) {
        throw FileTransferNegotiationException(
          'Decrypted decision sender (${decision.senderId}) does not match session peer (${session.peerId}).',
        );
      }
      return decision;
    } on FileTransferNegotiationException {
      rethrow;
    } catch (e) {
      throw FileTransferNegotiationException('Malformed decision payload: $e');
    }
  }

  /// Convenience end-to-end method to decrypt and process an incoming encrypted offer.
  Future<FileTransfer> receiveEncryptedOffer({
    required EphemeralSession session,
    required SessionEncryptedPayload encrypted,
    required Uint8List aad,
    required String authenticatedSenderId,
  }) async {
    await _verifySessionPeerKey(
      session: session,
      authenticatedSenderId: authenticatedSenderId,
    );
    final offer = await decryptOffer(
      session: session,
      encrypted: encrypted,
      aad: aad,
    );
    return receiveOffer(
      offer: offer,
      authenticatedSenderId: authenticatedSenderId,
    );
  }

  /// Convenience end-to-end method to decrypt and process an incoming encrypted decision.
  Future<FileTransfer> handleEncryptedDecision({
    required EphemeralSession session,
    required SessionEncryptedPayload encrypted,
    required Uint8List aad,
    required String authenticatedSenderId,
  }) async {
    await _verifySessionPeerKey(
      session: session,
      authenticatedSenderId: authenticatedSenderId,
    );
    final decision = await decryptDecision(
      session: session,
      encrypted: encrypted,
      aad: aad,
    );
    return handleDecision(
      decision: decision,
      authenticatedSenderId: authenticatedSenderId,
    );
  }

  // --- Internal Cache Helpers ---

  void _recordPendingOffer(FileTransferOffer offer) {
    _pruneExpiredOffers();
    if (_pendingOffers.length >= maxPendingOffers) {
      final oldestKey = _pendingOffers.keys.first;
      _pendingOffers.remove(oldestKey);
    }
    _pendingOffers[offer.transferId] = offer;
  }

  void _pruneExpiredOffers() {
    final now = _clock();
    _pendingOffers.removeWhere((_, o) => o.isExpired(now));
  }
}

/// Riverpod provider family creating a [FileTransferNegotiationService] for a given device ID.
final fileTransferNegotiationServiceProvider =
    Provider.family<FileTransferNegotiationService, String>((ref, localDeviceId) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(messageRepositoryProvider);
  final crypto = ref.watch(directionalSessionEncryptionServiceProvider);
  return FileTransferNegotiationService(
    database: db,
    localDeviceId: localDeviceId,
    messageRepository: repo,
    encryptionService: crypto,
  );
});
