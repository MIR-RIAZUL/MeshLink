import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';

/// Manages ephemeral X25519 key pair generation, concurrent handshake isolation,
/// X25519 Diffie-Hellman shared secret agreement, in-memory session lifecycle,
/// and rekeying state transitions.
///
/// Phase 7 Step 8: Session Rekeying & Session Lifecycle
/// - Generates a fresh 32-byte X25519 key pair for every handshake/rekey.
/// - Concurrently isolates pending key pairs keyed by [requestId].
/// - Derives the 32-byte raw X25519 shared secret between peers.
/// - Manages session lifecycle states (NO_SESSION, HANDSHAKE_INIT, ACTIVE_SESSION, REKEYING).
/// - Enforces 100-message limit, 12-hour session lifetime, and 10-minute old session grace period.
/// - Controls concurrent rekeys for the same peer to prevent state corruption.
/// - In-memory only: session secrets and private keys are NEVER persisted to disk.
// ignore_for_file: prefer_initializing_formals

class EphemeralSessionService implements EphemeralKeyProvider {
  EphemeralSessionService({
    X25519? x25519,
    DateTime Function()? clock,
  })  : _x25519 = x25519 ?? X25519(),
        _clock = clock;

  final X25519 _x25519;
  final DateTime Function()? _clock;

  DateTime get _now => _clock != null ? _clock() : DateTime.now();

  /// Pending ephemeral key pairs keyed by handshake [requestId] to support
  /// concurrent handshakes without key collision.
  final Map<String, SimpleKeyPairData> _pendingKeyPairs = {};

  /// Fallback key pair used when getEphemeralPublicKey is called without requestId.
  SimpleKeyPairData? _defaultPendingKeyPair;

  /// Active established sessions keyed by remote peer ID.
  final Map<String, EphemeralSession> _sessions = {};

  /// All known active and grace-period sessions keyed by unique sessionId.
  final Map<String, EphemeralSession> _sessionsById = {};

  /// Superseded previous sessions undergoing the 10-minute grace period, keyed by peer ID.
  final Map<String, EphemeralSession> _previousSessions = {};

  /// Explicit lifecycle states per peer ID.
  final Map<String, SessionLifecycleState> _lifecycleStates = {};

  /// Set of peer IDs currently executing a rekey handshake to prevent concurrent rekeys.
  final Set<String> _rekeyInProgress = {};

  /// Returns the current lifecycle state for [peerId].
  SessionLifecycleState getLifecycleState(String peerId, {DateTime? now}) {
    if (_rekeyInProgress.contains(peerId)) {
      return SessionLifecycleState.rekeying;
    }
    final explicit = _lifecycleStates[peerId];
    if (explicit == SessionLifecycleState.handshakeInit) {
      return SessionLifecycleState.handshakeInit;
    }
    final session = _sessions[peerId];
    if (session != null && !session.isDestroyed) {
      if (session.isExpired(now: now ?? _now)) {
        return SessionLifecycleState.noSession;
      }
      return SessionLifecycleState.activeSession;
    }
    return SessionLifecycleState.noSession;
  }

  /// Sets the explicit lifecycle state for [peerId].
  void setLifecycleState(String peerId, SessionLifecycleState state) {
    _lifecycleStates[peerId] = state;
    final session = _sessions[peerId];
    if (session != null && !session.isDestroyed) {
      session.setState(state);
    }
  }

  /// Checks if a rekey is currently in progress for [peerId].
  bool isRekeyInProgress(String peerId) => _rekeyInProgress.contains(peerId);

  /// Begins a rekey operation for [peerId].
  ///
  /// Returns false if a rekey is already in progress for this peer, ensuring
  /// concurrent rekeys are rejected and do not corrupt session state.
  bool beginRekey(String peerId) {
    if (_rekeyInProgress.contains(peerId)) {
      return false;
    }
    _rekeyInProgress.add(peerId);
    _lifecycleStates[peerId] = SessionLifecycleState.rekeying;
    final session = _sessions[peerId];
    if (session != null && !session.isDestroyed) {
      session.setState(SessionLifecycleState.rekeying);
    }
    return true;
  }

  /// Completes a rekey operation for [peerId], clearing in-progress state.
  void finishRekey(String peerId) {
    _rekeyInProgress.remove(peerId);
    _lifecycleStates[peerId] = SessionLifecycleState.activeSession;
    final session = _sessions[peerId];
    if (session != null && !session.isDestroyed) {
      session.setState(SessionLifecycleState.activeSession);
    }
  }

  /// Aborts a rekey operation for [peerId] after a failure.
  ///
  /// Restores [SessionLifecycleState.activeSession] if the existing session is
  /// still valid and within its lifetime. If the existing session is expired or destroyed,
  /// safely transitions to [SessionLifecycleState.noSession].
  void abortRekey(String peerId, {DateTime? now}) {
    _rekeyInProgress.remove(peerId);
    final session = _sessions[peerId];
    final currentNow = now ?? _now;
    if (session != null && !session.isDestroyed && !session.isExpired(now: currentNow)) {
      _lifecycleStates[peerId] = SessionLifecycleState.activeSession;
      session.setState(SessionLifecycleState.activeSession);
    } else {
      if (session != null && session.isExpired(now: currentNow)) {
        removeSession(peerId);
      }
      _lifecycleStates[peerId] = SessionLifecycleState.noSession;
    }
  }

  /// Generates a fresh X25519 ephemeral key pair for a handshake.
  ///
  /// The key pair is associated with [requestId] so concurrent handshakes
  /// do not overwrite each other's ephemeral private keys.
  Future<SimpleKeyPairData> generateEphemeralKeyPair({String? requestId}) async {
    final keyPair = await _x25519.newKeyPair();
    final extracted = await keyPair.extract();

    if (requestId != null) {
      _pendingKeyPairs[requestId] = extracted;
    } else {
      _defaultPendingKeyPair = extracted;
    }
    return extracted;
  }

  /// Returns the ephemeral public key bytes for inclusion in handshake packets.
  ///
  /// Implements [EphemeralKeyProvider]. If [requestId] is provided and has
  /// a pending key pair, its public key is returned; otherwise a fresh key pair is created.
  @override
  Future<Uint8List> getEphemeralPublicKey({String? requestId}) async {
    if (requestId != null) {
      final existing = _pendingKeyPairs[requestId];
      if (existing != null) {
        return Uint8List.fromList(existing.publicKey.bytes);
      }
      final fresh = await generateEphemeralKeyPair(requestId: requestId);
      return Uint8List.fromList(fresh.publicKey.bytes);
    }

    final kp = _defaultPendingKeyPair ?? await generateEphemeralKeyPair();
    return Uint8List.fromList(kp.publicKey.bytes);
  }

  /// Returns the pending key pair for [requestId], if any.
  SimpleKeyPairData? getPendingKeyPair(String requestId) =>
      _pendingKeyPairs[requestId];

  /// Checks if a pending key pair exists for [requestId].
  bool hasPendingKeyPair(String requestId) =>
      _pendingKeyPairs.containsKey(requestId);

  /// Clears pending ephemeral key material for [requestId] (e.g. on handshake failure or timeout).
  void clearPendingKeyPair(String requestId) {
    _pendingKeyPairs.remove(requestId);
  }

  /// Returns the number of currently pending ephemeral key pairs.
  int get pendingKeyPairsCount => _pendingKeyPairs.length;

  /// Establishes an in-memory [EphemeralSession] by performing X25519 Diffie-Hellman key agreement.
  ///
  /// Parameters:
  /// - [requestId]: The handshake request ID, used to retrieve the local ephemeral private key.
  /// - [localId]: Local device identifier.
  /// - [peerId]: Remote peer identifier.
  /// - [isInitiator]: True if this device initiated the handshake.
  /// - [peerEphemeralPublicKey]: 32-byte raw X25519 public key received from peer.
  /// - [localIdentityPublicKey]: 32-byte local Ed25519 identity key.
  /// - [peerIdentityPublicKey]: 32-byte peer Ed25519 identity key.
  /// - [localKeyPair]: Optional explicit key pair override. If null, the pending key pair
  ///   for [requestId] is consumed.
  /// - [now]: Optional clock override for deterministic unit testing.
  ///
  /// After computing the shared secret, the ephemeral private key is discarded.
  /// If an existing active session existed for [peerId], it enters a 10-minute grace period
  /// and the new session increments the epoch.
  Future<EphemeralSession> establishSession({
    required String requestId,
    required String localId,
    required String peerId,
    required bool isInitiator,
    required List<int> peerEphemeralPublicKey,
    required List<int> localIdentityPublicKey,
    required List<int> peerIdentityPublicKey,
    SimpleKeyPairData? localKeyPair,
    DateTime? now,
  }) async {
    // 1. Strict input validation
    if (peerEphemeralPublicKey.length != 32) {
      throw EphemeralSessionException(
        'Peer ephemeral public key must be 32 bytes (got ${peerEphemeralPublicKey.length})',
      );
    }
    if (localIdentityPublicKey.length != 32) {
      throw EphemeralSessionException(
        'Local identity public key must be 32 bytes (got ${localIdentityPublicKey.length})',
      );
    }
    if (peerIdentityPublicKey.length != 32) {
      throw EphemeralSessionException(
        'Peer identity public key must be 32 bytes (got ${peerIdentityPublicKey.length})',
      );
    }

    // 2. Retrieve and consume local ephemeral key pair
    final kp = localKeyPair ??
        _pendingKeyPairs.remove(requestId) ??
        _defaultPendingKeyPair;

    if (kp == null) {
      throw EphemeralSessionException(
        'No ephemeral key pair available for requestId $requestId. Call generateEphemeralKeyPair() first.',
      );
    }

    // Clear default key pair if consumed
    if (identical(kp, _defaultPendingKeyPair)) {
      _defaultPendingKeyPair = null;
    }

    // 3. Perform real X25519 Diffie-Hellman key agreement
    final remotePub = SimplePublicKey(
      peerEphemeralPublicKey,
      type: KeyPairType.x25519,
    );

    final SecretKey sharedSecretKeyObj;
    try {
      sharedSecretKeyObj = await _x25519.sharedSecretKey(
        keyPair: kp,
        remotePublicKey: remotePub,
      );
    } catch (e) {
      throw EphemeralSessionException('ECDH key agreement failed: $e');
    }

    final rawSecretBytes = await sharedSecretKeyObj.extractBytes();
    if (rawSecretBytes.length != 32) {
      throw EphemeralSessionException(
        'Derived shared secret must be 32 bytes (got ${rawSecretBytes.length})',
      );
    }
    final sharedSecret = Uint8List.fromList(rawSecretBytes);

    // 4. Epoch calculation & existing session binding check
    final existing = _sessions[peerId];
    final int nextEpoch;
    if (existing != null && !existing.isDestroyed) {
      if (!EphemeralSession.constantTimeCompare(
          existing.peerIdentityPublicKey, peerIdentityPublicKey)) {
        throw const EphemeralSessionException(
          'Peer identity mismatch: cannot replace active session with a different peer identity key',
        );
      }
      nextEpoch = existing.epoch + 1;
    } else {
      nextEpoch = 0;
    }

    // 5. Deterministic session ID bound to requestId, sorted ephemeral public keys, and epoch
    final sessionId = EphemeralSession.generateSessionId(
      requestId: requestId,
      localEphemeralPublicKey: kp.publicKey.bytes,
      peerEphemeralPublicKey: peerEphemeralPublicKey,
      epoch: nextEpoch,
    );

    if (existing != null &&
        !existing.isDestroyed &&
        existing.sessionId == sessionId &&
        (!EphemeralSession.constantTimeCompare(
                existing.peerEphemeralPublicKey, peerEphemeralPublicKey) ||
            !EphemeralSession.constantTimeCompare(
                existing.localEphemeralPublicKey, kp.publicKey.bytes))) {
      throw const EphemeralSessionException(
        'Session binding violation: ephemeral public keys do not match existing session',
      );
    }

    final currentNow = now ?? _now;
    final currentNowMs = currentNow.millisecondsSinceEpoch;

    // 6. Create in-memory session object
    final session = EphemeralSession(
      sessionId: sessionId,
      requestId: requestId,
      localId: localId,
      peerId: peerId,
      isInitiator: isInitiator,
      localIdentityPublicKey: Uint8List.fromList(localIdentityPublicKey),
      peerIdentityPublicKey: Uint8List.fromList(peerIdentityPublicKey),
      localEphemeralPublicKey: Uint8List.fromList(kp.publicKey.bytes),
      peerEphemeralPublicKey: Uint8List.fromList(peerEphemeralPublicKey),
      sharedSecret: sharedSecret,
      createdAt: currentNowMs,
      epoch: nextEpoch,
      state: SessionLifecycleState.activeSession,
    );

    // 7. Transition existing session to 10-minute grace period
    if (existing != null && !existing.isDestroyed) {
      existing.rekeyedAt = currentNowMs;
      final older = _previousSessions[peerId];
      if (older != null) {
        _sessionsById.remove(older.sessionId);
        older.destroy();
      }
      _previousSessions[peerId] = existing;
    }

    // 8. Store session in memory
    _sessions[peerId] = session;
    _sessionsById[sessionId] = session;

    finishRekey(peerId);

    return session;
  }

  /// Backward-compatible alias for [establishSession].
  Future<EphemeralSession> deriveSessionKeys({
    required String requestId,
    required String localId,
    required String peerId,
    required bool isInitiator,
    required List<int> peerEphemeralPublicKey,
    required List<int> localIdentityPublicKey,
    required List<int> peerIdentityPublicKey,
    SimpleKeyPairData? localKeyPair,
  }) {
    return establishSession(
      requestId: requestId,
      localId: localId,
      peerId: peerId,
      isInitiator: isInitiator,
      peerEphemeralPublicKey: peerEphemeralPublicKey,
      localIdentityPublicKey: localIdentityPublicKey,
      peerIdentityPublicKey: peerIdentityPublicKey,
      localKeyPair: localKeyPair,
    );
  }

  /// Purges superseded previous sessions whose 10-minute grace period has expired.
  void cleanExpiredGraceSessions({DateTime? now}) {
    final currentNow = now ?? _now;
    final toRemove = <String>[];
    for (final entry in _previousSessions.entries) {
      final session = entry.value;
      if (session.isDestroyed || session.isGracePeriodExpired(now: currentNow)) {
        toRemove.add(entry.key);
        _sessionsById.remove(session.sessionId);
        session.destroy();
      }
    }
    for (final peerId in toRemove) {
      _previousSessions.remove(peerId);
    }
  }

  /// Returns the active established session for [peerId], if any.
  EphemeralSession? getSession(String peerId, {DateTime? now}) {
    cleanExpiredGraceSessions(now: now);
    final session = _sessions[peerId];
    if (session != null && session.isDestroyed) {
      _sessions.remove(peerId);
      _sessionsById.remove(session.sessionId);
      return null;
    }
    return session;
  }

  /// Returns the active or grace-period session matching [sessionId], if any.
  ///
  /// If the session is a previous session whose 10-minute grace period has expired,
  /// it is destroyed, removed, and returns null.
  EphemeralSession? getSessionById(String sessionId, {DateTime? now}) {
    cleanExpiredGraceSessions(now: now);
    final session = _sessionsById[sessionId];
    if (session != null) {
      if (session.isDestroyed) {
        _sessionsById.remove(sessionId);
        return null;
      }
      if (session.rekeyedAt != null && session.isGracePeriodExpired(now: now ?? _now)) {
        _sessionsById.remove(sessionId);
        _previousSessions.remove(session.peerId);
        session.destroy();
        return null;
      }
    }
    return session;
  }

  /// Returns the superseded session in grace period for [peerId], if any and still valid.
  EphemeralSession? getPreviousSession(String peerId, {DateTime? now}) {
    cleanExpiredGraceSessions(now: now);
    final prev = _previousSessions[peerId];
    if (prev != null) {
      if (prev.isDestroyed || prev.isGracePeriodExpired(now: now ?? _now)) {
        _previousSessions.remove(peerId);
        _sessionsById.remove(prev.sessionId);
        prev.destroy();
        return null;
      }
    }
    return prev;
  }

  /// Returns true if there is an active non-destroyed session for [peerId].
  bool hasSession(String peerId, {DateTime? now}) {
    final session = getSession(peerId, now: now);
    return session != null && !session.isDestroyed;
  }

  /// Returns the most recently established session, if any.
  EphemeralSession? get activeSession {
    for (final session in _sessions.values.toList().reversed) {
      if (!session.isDestroyed) return session;
    }
    return null;
  }

  /// Tears down and removes both active and grace-period sessions for [peerId].
  EphemeralSession? removeSession(String peerId) {
    _rekeyInProgress.remove(peerId);
    _lifecycleStates[peerId] = SessionLifecycleState.noSession;
    final session = _sessions.remove(peerId);
    if (session != null) {
      _sessionsById.remove(session.sessionId);
      session.destroy();
    }
    final prev = _previousSessions.remove(peerId);
    if (prev != null) {
      _sessionsById.remove(prev.sessionId);
      prev.destroy();
    }
    return session;
  }

  /// Tears down and removes the session with [sessionId].
  EphemeralSession? destroySession(String sessionId) {
    final session = _sessionsById.remove(sessionId);
    if (session != null) {
      if (_sessions[session.peerId]?.sessionId == sessionId) {
        _sessions.remove(session.peerId);
        _lifecycleStates[session.peerId] = SessionLifecycleState.noSession;
      }
      if (_previousSessions[session.peerId]?.sessionId == sessionId) {
        _previousSessions.remove(session.peerId);
      }
      session.destroy();
    }
    return session;
  }

  /// Clears all sessions, pending key pairs, rekey states, and temporary secrets.
  void clearAll() {
    _rekeyInProgress.clear();
    _lifecycleStates.clear();
    for (final session in _sessions.values) {
      session.destroy();
    }
    _sessions.clear();
    for (final prev in _previousSessions.values) {
      prev.destroy();
    }
    _previousSessions.clear();
    _sessionsById.clear();
    _pendingKeyPairs.clear();
    _defaultPendingKeyPair = null;
  }
}
