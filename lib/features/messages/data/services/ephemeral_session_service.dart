import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';

/// Manages ephemeral X25519 key pair generation, ECDH shared secret computation,
/// and HKDF-based directional session key derivation for Phase 7 Step 4.
///
/// Session establishment flow:
/// 1. [generateEphemeralKeyPair] — Creates a fresh X25519 key pair for one handshake.
/// 2. [deriveSessionKeys] — After receiving the peer's ephemeral public key,
///    performs X25519 ECDH to produce a raw shared secret, then uses HKDF-SHA-256
///    to derive two 32-byte directional session keys.
///
/// HKDF parameters:
/// - IKM: Raw X25519 ECDH shared secret (32 bytes).
/// - Salt: Sorted concatenation of both peers' Ed25519 identity public keys (64 bytes).
///   Sorting ensures both sides compute the same salt regardless of role.
/// - Info: `"MESHLINK-v2-session|<requestId>"` encoded as UTF-8.
/// - Output: 64 bytes, split into two 32-byte directional keys.
///
/// The first 32 bytes are the initiator→responder key, the second 32 bytes are
/// the responder→initiator key. Both sides derive the same material because the
/// salt is order-independent and the HKDF info binds to the handshake request ID.
class EphemeralSessionService implements EphemeralKeyProvider {
  EphemeralSessionService({
    X25519? x25519,
  }) : _x25519 = x25519 ?? X25519();

  static const String hkdfInfoPrefix = 'MESHLINK-v2-session|';
  static const int sessionKeyLength = 32;
  static const int totalDerivedLength = 64; // 2 × 32 bytes

  final X25519 _x25519;

  /// Active ephemeral key pair for the current handshake.
  /// Cleared after session derivation to prevent reuse.
  SimpleKeyPairData? _currentKeyPair;

  /// Established sessions keyed by peer ID.
  final Map<String, EphemeralSession> _sessions = {};

  /// Generates a fresh X25519 ephemeral key pair for a handshake.
  ///
  /// Replaces any previous ephemeral key pair. The key pair is held in memory
  /// only until [deriveSessionKeys] consumes it.
  Future<SimpleKeyPairData> generateEphemeralKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final extracted = await keyPair.extract();
    _currentKeyPair = extracted;
    return extracted;
  }

  /// Returns the current ephemeral public key bytes for inclusion in handshake packets.
  ///
  /// Implements [EphemeralKeyProvider] so this service can be injected directly
  /// into [HandshakeService].
  @override
  Future<Uint8List> getEphemeralPublicKey() async {
    final kp = _currentKeyPair ?? await generateEphemeralKeyPair();
    return Uint8List.fromList(kp.publicKey.bytes);
  }

  /// Returns the current ephemeral key pair, generating one if needed.
  Future<SimpleKeyPairData> getCurrentKeyPair() async {
    return _currentKeyPair ?? await generateEphemeralKeyPair();
  }

  /// Derives directional session keys from the ECDH shared secret.
  ///
  /// Parameters:
  /// - [requestId]: The handshake request ID, bound into the HKDF info string.
  /// - [localId]: This device's identifier.
  /// - [peerId]: The remote peer's identifier.
  /// - [isInitiator]: Whether this device initiated the handshake.
  /// - [peerEphemeralPublicKey]: The peer's 32-byte X25519 ephemeral public key.
  /// - [localIdentityPublicKey]: This device's 32-byte Ed25519 identity public key.
  /// - [peerIdentityPublicKey]: The peer's 32-byte Ed25519 identity public key.
  /// - [localKeyPair]: Optional override for the local ephemeral key pair.
  ///   If null, uses the key pair from [generateEphemeralKeyPair].
  ///
  /// After derivation, the ephemeral key pair is cleared from memory.
  Future<EphemeralSession> deriveSessionKeys({
    required String requestId,
    required String localId,
    required String peerId,
    required bool isInitiator,
    required List<int> peerEphemeralPublicKey,
    required List<int> localIdentityPublicKey,
    required List<int> peerIdentityPublicKey,
    SimpleKeyPairData? localKeyPair,
  }) async {
    // Validate inputs
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

    final kp = localKeyPair ?? _currentKeyPair;
    if (kp == null) {
      throw const EphemeralSessionException(
        'No ephemeral key pair available. Call generateEphemeralKeyPair() first.',
      );
    }

    // Perform X25519 ECDH
    final peerPubKey = SimplePublicKey(
      peerEphemeralPublicKey,
      type: KeyPairType.x25519,
    );

    final SecretKey sharedSecret;
    try {
      sharedSecret = await _x25519.sharedSecretKey(
        keyPair: kp,
        remotePublicKey: peerPubKey,
      );
    } catch (e) {
      throw EphemeralSessionException('ECDH key agreement failed: $e');
    }

    // Build HKDF salt: sorted concatenation of identity public keys.
    // Lexicographic sort on raw bytes ensures both sides compute the same salt.
    final salt = _buildSortedSalt(localIdentityPublicKey, peerIdentityPublicKey);

    // Build HKDF info: "MESHLINK-v2-session|<requestId>"
    final info = utf8.encode('$hkdfInfoPrefix$requestId');

    // Derive 64 bytes of key material via HKDF-SHA-256
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: totalDerivedLength);
    final derivedKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: salt,
      info: info,
    );
    final derivedBytes = await derivedKey.extractBytes();

    if (derivedBytes.length != totalDerivedLength) {
      throw EphemeralSessionException(
        'HKDF output length mismatch: expected $totalDerivedLength, got ${derivedBytes.length}',
      );
    }

    // Split: first 32 bytes = initiator→responder, last 32 bytes = responder→initiator
    final initiatorToResponderKey =
        Uint8List.fromList(derivedBytes.sublist(0, sessionKeyLength));
    final responderToInitiatorKey =
        Uint8List.fromList(derivedBytes.sublist(sessionKeyLength, totalDerivedLength));

    final session = EphemeralSession(
      requestId: requestId,
      localId: localId,
      peerId: peerId,
      isInitiator: isInitiator,
      localEphemeralPublicKey: Uint8List.fromList(kp.publicKey.bytes),
      peerEphemeralPublicKey: Uint8List.fromList(peerEphemeralPublicKey),
      initiatorToResponderKey: initiatorToResponderKey,
      responderToInitiatorKey: responderToInitiatorKey,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Store session and clear ephemeral key pair
    _sessions[peerId] = session;
    _currentKeyPair = null;

    return session;
  }

  /// Returns the established session for [peerId], if any.
  EphemeralSession? getSession(String peerId) => _sessions[peerId];

  /// Returns true if there is an active session with [peerId].
  bool hasSession(String peerId) => _sessions.containsKey(peerId);

  /// Removes and returns the session for [peerId], if any.
  EphemeralSession? removeSession(String peerId) => _sessions.remove(peerId);

  /// Clears all sessions and any pending ephemeral key material.
  void clearAll() {
    _sessions.clear();
    _currentKeyPair = null;
  }

  /// Builds a 64-byte salt by sorting the two 32-byte identity public keys
  /// lexicographically and concatenating them.
  ///
  /// This ensures both the initiator and responder compute the same salt,
  /// regardless of which role they play.
  static Uint8List _buildSortedSalt(List<int> keyA, List<int> keyB) {
    final cmp = _compareBytes(keyA, keyB);
    final first = cmp <= 0 ? keyA : keyB;
    final second = cmp <= 0 ? keyB : keyA;

    final salt = Uint8List(64);
    salt.setRange(0, 32, first);
    salt.setRange(32, 64, second);
    return salt;
  }

  /// Lexicographic byte comparison.
  static int _compareBytes(List<int> a, List<int> b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }
}
