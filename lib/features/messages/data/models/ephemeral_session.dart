import 'dart:convert';
import 'dart:typed_data';

/// Represents an established in-memory ephemeral X25519 session between two peers.
///
/// Established during Phase 7 Step 4 after exchanging authenticated ephemeral
/// public keys and performing X25519 Diffie-Hellman key agreement.
///
/// Holds the temporary 32-byte X25519 shared secret.
/// Directional encryption keys (via HKDF) are NOT implemented in Step 4 (deferred to Step 5).
///
/// In-memory only: session secrets must NEVER be written to persistent storage.
class EphemeralSession {
  EphemeralSession({
    required this.sessionId,
    required this.requestId,
    required this.localId,
    required this.peerId,
    required this.isInitiator,
    required this.localIdentityPublicKey,
    required this.peerIdentityPublicKey,
    required this.localEphemeralPublicKey,
    required this.peerEphemeralPublicKey,
    required this.sharedSecret,
    required this.createdAt,
  });

  /// Deterministic unique session identifier bound to requestId and ephemeral keys.
  final String sessionId;

  /// Handshake request ID that established this session.
  final String requestId;

  /// Local device identifier.
  final String localId;

  /// Remote peer device identifier.
  final String peerId;

  /// Whether the local device initiated the handshake.
  final bool isInitiator;

  /// Local 32-byte Ed25519 identity public key.
  final Uint8List localIdentityPublicKey;

  /// Remote peer's 32-byte Ed25519 identity public key.
  final Uint8List peerIdentityPublicKey;

  /// Local 32-byte X25519 ephemeral public key.
  final Uint8List localEphemeralPublicKey;

  /// Remote peer's 32-byte X25519 ephemeral public key.
  final Uint8List peerEphemeralPublicKey;

  /// 32-byte X25519 Diffie-Hellman shared secret.
  ///
  /// NOT an encryption key yet (Step 5 will derive directional keys via HKDF).
  final Uint8List sharedSecret;

  /// Timestamp in milliseconds when the session was created.
  final int createdAt;

  bool _isDestroyed = false;

  /// Returns true if this session has been torn down.
  bool get isDestroyed => _isDestroyed;

  /// Marks this session as destroyed and releases references.
  void destroy() {
    _isDestroyed = true;
  }

  /// Verifies that this session matches the given binding parameters.
  bool matchesBinding({
    required String expectedRequestId,
    required List<int> expectedLocalIdentityKey,
    required List<int> expectedPeerIdentityKey,
    required List<int> expectedLocalEphemeralKey,
    required List<int> expectedPeerEphemeralKey,
  }) {
    if (_isDestroyed) return false;
    if (requestId != expectedRequestId) return false;
    if (!constantTimeCompare(localIdentityPublicKey, expectedLocalIdentityKey)) return false;
    if (!constantTimeCompare(peerIdentityPublicKey, expectedPeerIdentityKey)) return false;
    if (!constantTimeCompare(localEphemeralPublicKey, expectedLocalEphemeralKey)) return false;
    if (!constantTimeCompare(peerEphemeralPublicKey, expectedPeerEphemeralKey)) return false;
    return true;
  }

  /// Performs constant-time comparison of two byte lists to mitigate timing attacks.
  static bool constantTimeCompare(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Deterministically generates a unique session ID bound to the handshake context.
  ///
  /// Uses [requestId] and sorted ephemeral public keys so both peers produce
  /// the identical [sessionId] without exposing any secret material.
  static String generateSessionId({
    required String requestId,
    required List<int> localEphemeralPublicKey,
    required List<int> peerEphemeralPublicKey,
  }) {
    final cmp = _compareBytes(localEphemeralPublicKey, peerEphemeralPublicKey);
    final first = cmp <= 0 ? localEphemeralPublicKey : peerEphemeralPublicKey;
    final second = cmp <= 0 ? peerEphemeralPublicKey : localEphemeralPublicKey;

    final firstTag = base64UrlEncode(first.sublist(0, 8));
    final secondTag = base64UrlEncode(second.sublist(0, 8));
    return 'SESSION-$requestId-$firstTag-$secondTag';
  }

  static int _compareBytes(List<int> a, List<int> b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }
}

/// Exception thrown when ephemeral session operations fail.
class EphemeralSessionException implements Exception {
  const EphemeralSessionException(this.message);
  final String message;

  @override
  String toString() => 'EphemeralSessionException: $message';
}
