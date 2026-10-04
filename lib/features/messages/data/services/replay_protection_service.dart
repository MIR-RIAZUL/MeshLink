import 'dart:async';

import 'package:meshlink/features/messages/data/repositories/message_repository.dart';

/// Validation status of an incoming packet evaluated against persistent replay rules.
enum ReplayValidationResult {
  /// Packet is valid and has not been seen before.
  accepted,

  /// Packet has already been processed or recorded in persistent storage.
  duplicate,

  /// Packet timestamp is older than the replay horizon (7 days).
  expired,

  /// Packet timestamp is beyond the maximum allowed future skew (+1 hour).
  futureTimestamp,

  /// Packet identifier, origin, or type is empty, malformed, or exceeds length limits.
  invalidIdentifier,
}

/// Structured outcome of a persistent replay check.
class ReplayCheckOutcome {
  const ReplayCheckOutcome({
    required this.result,
    required this.replayKey,
    this.message,
  });

  final ReplayValidationResult result;
  final String replayKey;
  final String? message;

  /// True if the packet is accepted for processing.
  bool get isAccepted => result == ReplayValidationResult.accepted;

  /// True if the packet was rejected as a duplicate.
  bool get isDuplicate => result == ReplayValidationResult.duplicate;

  @override
  String toString() => 'ReplayCheckOutcome(result: ${result.name}, key: $replayKey)';
}

/// Service implementing persistent replay protection for MeshLink packets.
///
/// Phase 7 Step 6: Persistent Replay Protection
///
/// Security properties:
/// 1. **Persistence across restart**: Replay state is stored in SQLite `seen_packets_table`
///    via [MessageRepository], surviving app restarts and session teardowns.
/// 2. **Atomicity**: Replay registration is atomic (`INSERT OR IGNORE`) to prevent race
///    conditions between concurrent duplicate packets.
/// 3. **Canonical Replay Identity**: Format is `packetType:originId:packetId`, ensuring
///    isolation across different origins and packet types.
/// 4. **Replay Retention**: 7-day retention horizon; packets older than 7 days are rejected as expired.
/// 5. **Future Skew Protection**: Packets with timestamps more than 1 hour in the future
///    are rejected to prevent future timestamp poisoning.
/// 6. **Poisoning Resistance**: Unauthenticated or malformed packets must NEVER be recorded
///    in the replay database.
class ReplayProtectionService {
  ReplayProtectionService({
    required this.repository,
    Duration? replayHorizon,
    Duration? maxFutureSkew,
  })  : _replayHorizon = replayHorizon ?? defaultReplayHorizon,
        _maxFutureSkew = maxFutureSkew ?? defaultMaxFutureSkew;

  final MessageRepository repository;
  final Duration _replayHorizon;
  final Duration _maxFutureSkew;

  /// Approved replay retention horizon (7 days).
  static const Duration defaultReplayHorizon = Duration(days: 7);

  /// Approved maximum allowed future clock skew (1 hour).
  static const Duration defaultMaxFutureSkew = Duration(hours: 1);

  /// Maximum character length for packet identifiers, origin IDs, and packet types.
  static const int maxIdentifierLength = 128;

  /// Constructs the canonical composite replay key: `packetType:originId:packetId`.
  static String buildReplayKey({
    required String packetType,
    required String originId,
    required String packetId,
  }) {
    return '$packetType:$originId:$packetId';
  }

  /// Validates packet metadata before checking or modifying persistent replay state.
  ///
  /// Checks:
  /// - Non-empty, non-whitespace, bounded identifier lengths.
  /// - Timestamp not older than [defaultReplayHorizon] (7 days).
  /// - Timestamp not farther into the future than [defaultMaxFutureSkew] (1 hour).
  ReplayValidationResult validatePacketMetadata({
    required String packetType,
    required String originId,
    required String packetId,
    required DateTime timestamp,
    DateTime? now,
  }) {
    if (!_isValidIdentifier(packetType) ||
        !_isValidIdentifier(originId) ||
        !_isValidIdentifier(packetId)) {
      return ReplayValidationResult.invalidIdentifier;
    }

    final currentTime = now ?? DateTime.now();
    final earliestValid = currentTime.subtract(_replayHorizon);
    final latestValid = currentTime.add(_maxFutureSkew);

    if (timestamp.isBefore(earliestValid)) {
      return ReplayValidationResult.expired;
    }
    if (timestamp.isAfter(latestValid)) {
      return ReplayValidationResult.futureTimestamp;
    }

    return ReplayValidationResult.accepted;
  }

  /// Checks if a packet has already been seen in the persistent repository without modifying state.
  Future<bool> isSeen({
    required String packetType,
    required String originId,
    required String packetId,
  }) {
    final key = buildReplayKey(
      packetType: packetType,
      originId: originId,
      packetId: packetId,
    );
    return repository.hasSeenPacket(key);
  }

  /// Atomically validates metadata and registers an authenticated packet as seen.
  ///
  /// The database operation is atomic:
  /// - If the packet has not been seen before, it is inserted and accepted.
  /// - If already recorded, returns [ReplayValidationResult.duplicate].
  Future<ReplayCheckOutcome> checkAndMarkSeen({
    required String packetType,
    required String originId,
    required String packetId,
    required DateTime timestamp,
    DateTime? now,
  }) async {
    final validation = validatePacketMetadata(
      packetType: packetType,
      originId: originId,
      packetId: packetId,
      timestamp: timestamp,
      now: now,
    );

    final replayKey = buildReplayKey(
      packetType: packetType,
      originId: originId,
      packetId: packetId,
    );

    if (validation != ReplayValidationResult.accepted) {
      return ReplayCheckOutcome(
        result: validation,
        replayKey: replayKey,
        message: 'Packet rejected during metadata validation: ${validation.name}',
      );
    }

    final isNew = await repository.checkAndMarkSeen(
      packetType: packetType,
      originId: originId,
      packetId: packetId,
      receivedAt: now ?? DateTime.now(),
    );

    if (isNew) {
      return ReplayCheckOutcome(
        result: ReplayValidationResult.accepted,
        replayKey: replayKey,
      );
    } else {
      return ReplayCheckOutcome(
        result: ReplayValidationResult.duplicate,
        replayKey: replayKey,
        message: 'Packet has already been recorded in persistent storage',
      );
    }
  }

  /// Executes the secure processing pipeline for an incoming packet:
  /// 1. Validate structure and timestamp.
  /// 2. Pre-check if already known duplicate.
  /// 3. Execute [authenticateAndDecrypt] closure.
  /// 4. Atomically register authenticated packet as seen via [checkAndMarkSeen].
  /// 5. Execute [onAccepted] with decrypted payload.
  ///
  /// Guarantees that unauthenticated/tampered packets never poison the replay database.
  Future<T?> processAuthenticatedPacket<T>({
    required String packetType,
    required String originId,
    required String packetId,
    required DateTime timestamp,
    DateTime? now,
    required Future<T> Function() authenticateAndDecrypt,
    required Future<void> Function(T decrypted) onAccepted,
  }) async {
    // 1. Basic structural and timestamp validation
    final validation = validatePacketMetadata(
      packetType: packetType,
      originId: originId,
      packetId: packetId,
      timestamp: timestamp,
      now: now,
    );
    if (validation != ReplayValidationResult.accepted) {
      return null;
    }

    // 2. Pre-check to drop known duplicates before expensive crypto
    if (await isSeen(packetType: packetType, originId: originId, packetId: packetId)) {
      return null;
    }

    // 3. Cryptographic authentication / decryption
    // If this throws, execution halts and the packet is NEVER marked seen.
    final decrypted = await authenticateAndDecrypt();

    // 4. Atomically mark as seen
    final outcome = await checkAndMarkSeen(
      packetType: packetType,
      originId: originId,
      packetId: packetId,
      timestamp: timestamp,
      now: now,
    );

    if (!outcome.isAccepted) {
      return null;
    }

    // 5. Deliver / process
    await onAccepted(decrypted);
    return decrypted;
  }

  /// Prunes expired replay records older than [maxAge] (defaults to 7 days).
  Future<int> pruneExpiredPackets({Duration? maxAge}) {
    return repository.pruneExpiredPackets(maxAge ?? _replayHorizon);
  }

  /// Triggers best-effort asynchronous pruning of expired replay records at startup/initialization.
  void pruneOnStartup() {
    unawaited(pruneExpiredPackets().catchError((_) => 0));
  }

  static bool _isValidIdentifier(String id) {
    if (id.isEmpty || id.length > maxIdentifierLength) return false;
    // Disallow leading/trailing whitespace
    return id.trim() == id;
  }
}
