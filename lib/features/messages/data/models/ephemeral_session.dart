import 'dart:convert';
import 'dart:typed_data';

import 'package:meshlink/features/messages/data/models/directional_session_keys.dart';

/// Represents the explicit lifecycle state of an authenticated peer session.
///
/// Phase 7 Step 8: Session Rekeying & Session Lifecycle
enum SessionLifecycleState {
  /// No session currently exists for the peer.
  noSession,

  /// Handshake is currently being negotiated (initial establishment).
  handshakeInit,

  /// Session is active and usable for encrypted messaging.
  activeSession,

  /// Session has reached a rekey threshold and a new authenticated session is being established.
  rekeying,
}

/// Represents an established in-memory ephemeral X25519 session between two peers.
///
/// Holds the temporary 32-byte X25519 shared secret, derived directional keys,
/// epoch, and message counters.
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
    this.epoch = 0,
    this.sentMessageCount = 0,
    this.receivedMessageCount = 0,
    this.rekeyedAt,
    SessionLifecycleState? state,
  }) : _state = state ?? SessionLifecycleState.activeSession;

  /// Deterministic unique session identifier bound to requestId, epoch, and ephemeral keys.
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
  final Uint8List sharedSecret;

  /// Timestamp in milliseconds when the session was created.
  final int createdAt;

  /// Monotonically increasing epoch for this peer session lifecycle (initial = 0, rekeys = 1, 2, ...).
  final int epoch;

  /// Number of outbound messages encrypted under this session.
  int sentMessageCount;

  /// Number of inbound messages decrypted under this session.
  int receivedMessageCount;

  /// Timestamp in milliseconds when this session was superseded during a rekey, entering grace period.
  int? rekeyedAt;

  SessionLifecycleState _state;

  /// Current lifecycle state of this session.
  SessionLifecycleState get state =>
      _isDestroyed ? SessionLifecycleState.noSession : _state;

  /// Updates the lifecycle state of this session.
  void setState(SessionLifecycleState newState) {
    _state = newState;
  }

  /// Total messages processed (sent + received) under this session.
  int get totalMessageCount => sentMessageCount + receivedMessageCount;

  /// Outgoing message sequence number for this session.
  int get sequenceNumber => sentMessageCount;

  /// Maximum allowed messages before a rekey is required (100 messages).
  static const int maxMessagesPerSession = 100;

  /// Maximum active session lifetime before rekey is required (12 hours).
  static const Duration maxSessionLifetime = Duration(hours: 12);

  /// Grace period during which a superseded previous session remains valid for in-flight packets (10 minutes).
  static const Duration gracePeriodDuration = Duration(minutes: 10);

  /// Increments the sent message count.
  void recordSentMessage() {
    sentMessageCount++;
  }

  /// Increments the received message count.
  void recordReceivedMessage() {
    receivedMessageCount++;
  }

  /// Resets message counters (used for fresh sessions).
  void resetMessageCounters() {
    sentMessageCount = 0;
    receivedMessageCount = 0;
  }

  /// Checks if this session requires rekeying due to message threshold (100) or time expiry (12h).
  bool shouldRekey({DateTime? now}) {
    if (_isDestroyed) return false;
    if (totalMessageCount >= maxMessagesPerSession) return true;
    if (sentMessageCount >= maxMessagesPerSession) return true;
    if (receivedMessageCount >= maxMessagesPerSession) return true;
    return isExpired(now: now);
  }

  /// Checks if this session has exceeded its maximum 12-hour lifetime.
  bool isExpired({DateTime? now}) {
    if (_isDestroyed) return true;
    final currentMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final ageMs = currentMs - createdAt;
    return ageMs >= maxSessionLifetime.inMilliseconds;
  }

  /// Checks if this superseded session has exceeded its 10-minute grace period.
  bool isGracePeriodExpired({DateTime? now}) {
    if (rekeyedAt == null) return false;
    final currentMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final elapsed = currentMs - rekeyedAt!;
    return elapsed >= gracePeriodDuration.inMilliseconds;
  }

  bool _isDestroyed = false;
  DirectionalSessionKeys? _directionalKeys;

  /// In-memory directional session keys derived via HKDF-SHA256 for this session.
  DirectionalSessionKeys? get directionalKeys => _directionalKeys;

  /// Attaches derived directional keys to this session in memory.
  void setDirectionalKeys(DirectionalSessionKeys keys) {
    if (_isDestroyed) {
      throw const EphemeralSessionException(
        'Cannot attach directional keys to a destroyed session',
      );
    }
    _directionalKeys = keys;
  }

  /// Returns true if this session has been torn down.
  bool get isDestroyed => _isDestroyed;

  /// Marks this session as destroyed and releases references.
  void destroy() {
    _isDestroyed = true;
    _state = SessionLifecycleState.noSession;
    _directionalKeys?.destroy();
    _directionalKeys = null;
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
  /// Uses [requestId], sorted ephemeral public keys, and [epoch] so both peers produce
  /// the identical [sessionId] without exposing any secret material.
  static String generateSessionId({
    required String requestId,
    required List<int> localEphemeralPublicKey,
    required List<int> peerEphemeralPublicKey,
    int epoch = 0,
  }) {
    final cmp = compareBytes(localEphemeralPublicKey, peerEphemeralPublicKey);
    final first = cmp <= 0 ? localEphemeralPublicKey : peerEphemeralPublicKey;
    final second = cmp <= 0 ? peerEphemeralPublicKey : localEphemeralPublicKey;

    final firstTag = base64UrlEncode(first.sublist(0, 8));
    final secondTag = base64UrlEncode(second.sublist(0, 8));
    if (epoch > 0) {
      return 'SESSION-e$epoch-$requestId-$firstTag-$secondTag';
    }
    return 'SESSION-$requestId-$firstTag-$secondTag';
  }

  /// Lexicographically compares two byte lists.
  static int compareBytes(List<int> a, List<int> b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  @override
  String toString() =>
      'EphemeralSession(sessionId: $sessionId, peerId: $peerId, epoch: $epoch, state: ${_state.name}, totalMessages: $totalMessageCount, isDestroyed: $_isDestroyed)';
}

/// Exception thrown when ephemeral session operations fail.
class EphemeralSessionException implements Exception {
  const EphemeralSessionException(this.message);
  final String message;

  @override
  String toString() => 'EphemeralSessionException: $message';
}
