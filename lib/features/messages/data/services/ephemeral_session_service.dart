import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';

/// Manages ephemeral X25519 key pair generation, concurrent handshake isolation,
/// X25519 Diffie-Hellman shared secret agreement, and in-memory session lifecycle.
///
/// Phase 7 Step 4 Security Hardening:
/// - Generates a fresh 32-byte X25519 key pair for every handshake.
/// - Concurrently isolates pending key pairs keyed by [requestId].
/// - Derives the 32-byte raw X25519 shared secret between peers.
/// - NO HKDF, NO directional keys (deferred to Step 5).
/// - In-memory only: session secrets and private keys are never persisted to disk.
class EphemeralSessionService implements EphemeralKeyProvider {
  EphemeralSessionService({
    X25519? x25519,
  }) : _x25519 = x25519 ?? X25519();

  final X25519 _x25519;

  /// Pending ephemeral key pairs keyed by handshake [requestId] to support
  /// concurrent handshakes without key collision.
  final Map<String, SimpleKeyPairData> _pendingKeyPairs = {};

  /// Fallback key pair used when getEphemeralPublicKey is called without requestId.
  SimpleKeyPairData? _defaultPendingKeyPair;

  /// Active established sessions keyed by remote peer ID.
  final Map<String, EphemeralSession> _sessions = {};

  /// Active established sessions keyed by unique sessionId.
  final Map<String, EphemeralSession> _sessionsById = {};

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
  ///
  /// After computing the shared secret, the ephemeral private key is discarded.
  Future<EphemeralSession> establishSession({
    required String requestId,
    required String localId,
    required String peerId,
    required bool isInitiator,
    required List<int> peerEphemeralPublicKey,
    required List<int> localIdentityPublicKey,
    required List<int> peerIdentityPublicKey,
    SimpleKeyPairData? localKeyPair,
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

    // 4. Deterministic session ID bound to requestId and sorted ephemeral public keys
    final sessionId = EphemeralSession.generateSessionId(
      requestId: requestId,
      localEphemeralPublicKey: kp.publicKey.bytes,
      peerEphemeralPublicKey: peerEphemeralPublicKey,
    );

    // 5. Session binding check against existing active session for this peer
    final existing = _sessions[peerId];
    if (existing != null && !existing.isDestroyed) {
      if (!EphemeralSession.constantTimeCompare(
          existing.peerIdentityPublicKey, peerIdentityPublicKey)) {
        throw const EphemeralSessionException(
          'Peer identity mismatch: cannot replace active session with a different peer identity key',
        );
      }
      if (existing.sessionId == sessionId &&
          (!EphemeralSession.constantTimeCompare(
                  existing.peerEphemeralPublicKey, peerEphemeralPublicKey) ||
              !EphemeralSession.constantTimeCompare(
                  existing.localEphemeralPublicKey, kp.publicKey.bytes))) {
        throw const EphemeralSessionException(
          'Session binding violation: ephemeral public keys do not match existing session',
        );
      }
    }

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
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // 7. Store session in memory
    _sessions[peerId] = session;
    _sessionsById[sessionId] = session;

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

  /// Returns the active established session for [peerId], if any.
  EphemeralSession? getSession(String peerId) {
    final session = _sessions[peerId];
    if (session != null && session.isDestroyed) {
      _sessions.remove(peerId);
      _sessionsById.remove(session.sessionId);
      return null;
    }
    return session;
  }

  /// Returns the active established session by [sessionId], if any.
  EphemeralSession? getSessionById(String sessionId) {
    final session = _sessionsById[sessionId];
    if (session != null && session.isDestroyed) {
      _sessionsById.remove(sessionId);
      _sessions.remove(session.peerId);
      return null;
    }
    return session;
  }

  /// Returns true if there is an active non-destroyed session for [peerId].
  bool hasSession(String peerId) {
    final session = getSession(peerId);
    return session != null && !session.isDestroyed;
  }

  /// Returns the most recently established session, if any.
  EphemeralSession? get activeSession {
    for (final session in _sessions.values.toList().reversed) {
      if (!session.isDestroyed) return session;
    }
    return null;
  }

  /// Tears down and removes the session for [peerId].
  EphemeralSession? removeSession(String peerId) {
    final session = _sessions.remove(peerId);
    if (session != null) {
      _sessionsById.remove(session.sessionId);
      session.destroy();
    }
    return session;
  }

  /// Tears down and removes the session with [sessionId].
  EphemeralSession? destroySession(String sessionId) {
    final session = _sessionsById.remove(sessionId);
    if (session != null) {
      _sessions.remove(session.peerId);
      session.destroy();
    }
    return session;
  }

  /// Clears all sessions, pending key pairs, and temporary secrets.
  void clearAll() {
    for (final session in _sessions.values) {
      session.destroy();
    }
    _sessions.clear();
    _sessionsById.clear();
    _pendingKeyPairs.clear();
    _defaultPendingKeyPair = null;
  }
}
