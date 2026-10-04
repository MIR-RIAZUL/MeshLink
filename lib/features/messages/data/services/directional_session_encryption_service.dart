import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/models/directional_session_keys.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';

/// Directional session encryption service utilizing HKDF-SHA256 and ChaCha20-Poly1305.
///
/// Phase 7 Step 5: Directional Session Encryption
///
/// Flow:
/// ```text
/// Ed25519 authenticated handshake (Step 2, 3)
///         ↓
/// Ephemeral X25519 (Step 4)
///         ↓
/// X25519 shared secret (Step 4)
///         ↓
/// HKDF-SHA256 (Step 5)
///         ↓
/// K_send + K_recv (Step 5)
///         ↓
/// ChaCha20-Poly1305 (Step 5)
///         ↓
/// Authenticated encrypted payload (Step 5)
/// ```
///
/// Directional Key Derivation:
/// - Both peers canonically order their 32-byte Ed25519 identity public keys.
/// - Let P1 be the peer with the lower key and P2 with the higher key.
/// - Salt binds: protocolVersion (2), sessionId, requestId, both sorted identity keys, and both sorted ephemeral keys.
/// - Domain-separated HKDF info strings:
///     - P1 -> P2 key: `MESHLINK-v2-DIR-KEY:P1->P2|<sessionId>`
///     - P2 -> P1 key: `MESHLINK-v2-DIR-KEY:P2->P1|<sessionId>`
/// - Deterministic role mapping:
///     - If local is P1: sendKey = K_P1->P2, receiveKey = K_P2->P1.
///     - If local is P2: sendKey = K_P2->P1, receiveKey = K_P1->P2.
/// - Symmetry guarantee:
///     A.sendKey == B.receiveKey
///     A.receiveKey == B.sendKey
///     sendKey != receiveKey
///
/// Security constraints:
/// - In-memory only: raw keys and intermediate HKDF materials are NEVER persisted.
/// - Fails closed: any authentication mismatch (MAC, AAD, nonce, ciphertext tampering)
///   immediately throws [DirectionalEncryptionException] with zero plaintext leakage.
class DirectionalSessionEncryptionService {
  DirectionalSessionEncryptionService({
    Hkdf? hkdf,
    Cipher? aead,
  })  : _hkdf = hkdf ?? Hkdf(hmac: Hmac(Sha256()), outputLength: 32),
        _aead = aead ?? Chacha20.poly1305Aead();

  final Hkdf _hkdf;
  final Cipher _aead;

  /// Protocol version for canonical AAD binding.
  static const int protocolVersion = 2;

  /// Derives the 32-byte directional keys (sendKey, receiveKey) for [session]
  /// via HKDF-SHA256 with session context binding and canonical peer ordering.
  Future<DirectionalSessionKeys> deriveDirectionalKeys(
    EphemeralSession session,
  ) async {
    if (session.isDestroyed) {
      throw const DirectionalEncryptionException(
        'Cannot derive directional keys: session is destroyed',
      );
    }

    if (session.sharedSecret.length != 32) {
      throw DirectionalEncryptionException(
        'Shared secret must be exactly 32 bytes (got ${session.sharedSecret.length})',
      );
    }

    // 1. Canonical ordering of peers based on their 32-byte Ed25519 identity keys
    final cmp = EphemeralSession.compareBytes(
      session.localIdentityPublicKey,
      session.peerIdentityPublicKey,
    );

    if (cmp == 0) {
      throw const DirectionalEncryptionException(
        'Cannot derive directional keys: local and peer identity keys are identical',
      );
    }

    final Uint8List p1IdentityKey;
    final Uint8List p2IdentityKey;
    final Uint8List p1EphemeralKey;
    final Uint8List p2EphemeralKey;

    if (cmp < 0) {
      p1IdentityKey = session.localIdentityPublicKey;
      p2IdentityKey = session.peerIdentityPublicKey;
      p1EphemeralKey = session.localEphemeralPublicKey;
      p2EphemeralKey = session.peerEphemeralPublicKey;
    } else {
      p1IdentityKey = session.peerIdentityPublicKey;
      p2IdentityKey = session.localIdentityPublicKey;
      p1EphemeralKey = session.peerEphemeralPublicKey;
      p2EphemeralKey = session.localEphemeralPublicKey;
    }

    // 2. Build canonical salt binding all authenticated session context:
    // [MESHLINK-v2-DIR-SALT|sessionId|requestId|][p1IdKey][p2IdKey][p1EphKey][p2EphKey]
    final saltBuilder = BytesBuilder(copy: false);
    saltBuilder.add(
      utf8.encode('MESHLINK-v2-DIR-SALT|${session.sessionId}|${session.requestId}|'),
    );
    saltBuilder.add(p1IdentityKey);
    saltBuilder.add(p2IdentityKey);
    saltBuilder.add(p1EphemeralKey);
    saltBuilder.add(p2EphemeralKey);
    final salt = saltBuilder.toBytes();

    // 3. Domain-separated info strings for the two directions
    final infoP1ToP2 = utf8.encode(
      'MESHLINK-v2-DIR-KEY:P1->P2|${session.sessionId}',
    );
    final infoP2ToP1 = utf8.encode(
      'MESHLINK-v2-DIR-KEY:P2->P1|${session.sessionId}',
    );

    // 4. Derive directional keys via HKDF-SHA256
    final secretKey = SecretKey(session.sharedSecret);

    final derivedP1ToP2 = await _hkdf.deriveKey(
      secretKey: secretKey,
      nonce: salt,
      info: infoP1ToP2,
    );
    final derivedP2ToP1 = await _hkdf.deriveKey(
      secretKey: secretKey,
      nonce: salt,
      info: infoP2ToP1,
    );

    final rawP1ToP2 = Uint8List.fromList(await derivedP1ToP2.extractBytes());
    final rawP2ToP1 = Uint8List.fromList(await derivedP2ToP1.extractBytes());

    if (rawP1ToP2.length != 32 || rawP2ToP1.length != 32) {
      throw const DirectionalEncryptionException(
        'Derived key lengths must be exactly 32 bytes',
      );
    }

    // 5. Assign directional keys based on canonical peer position
    final Uint8List sendKey;
    final Uint8List receiveKey;

    if (cmp < 0) {
      // Local peer is P1
      sendKey = rawP1ToP2;
      receiveKey = rawP2ToP1;
    } else {
      // Local peer is P2
      sendKey = rawP2ToP1;
      receiveKey = rawP1ToP2;
    }

    return DirectionalSessionKeys(
      sendKey: sendKey,
      receiveKey: receiveKey,
    );
  }

  /// Returns cached directional keys from [session], or derives and caches them.
  Future<DirectionalSessionKeys> getOrDeriveKeys(
    EphemeralSession session,
  ) async {
    if (session.isDestroyed) {
      throw const DirectionalEncryptionException(
        'Cannot get directional keys: session is destroyed',
      );
    }
    final cached = session.directionalKeys;
    if (cached != null && !cached.isDestroyed) {
      return cached;
    }
    final keys = await deriveDirectionalKeys(session);
    session.setDirectionalKeys(keys);
    return keys;
  }

  /// Encrypts [plaintext] using ChaCha20-Poly1305 with the session's directional sendKey
  /// and authenticates [aad].
  ///
  /// Parameters:
  /// - [session]: The active [EphemeralSession].
  /// - [plaintext]: Binary data to encrypt.
  /// - [aad]: Authenticated Additional Data bytes (must be identical at decryption).
  /// - [explicitNonce]: Optional 12-byte nonce override (e.g. for deterministic unit tests).
  ///   If omitted, a cryptographically secure random 12-byte nonce is generated.
  Future<SessionEncryptedPayload> encrypt({
    required EphemeralSession session,
    required Uint8List plaintext,
    required Uint8List aad,
    Uint8List? explicitNonce,
  }) async {
    if (session.isDestroyed) {
      throw const DirectionalEncryptionException(
        'Cannot encrypt: session is destroyed',
      );
    }

    final keys = await getOrDeriveKeys(session);
    if (keys.isDestroyed) {
      throw const DirectionalEncryptionException(
        'Cannot encrypt: session keys are destroyed',
      );
    }

    final Uint8List nonce;
    if (explicitNonce != null) {
      if (explicitNonce.length != 12) {
        throw DirectionalEncryptionException(
          'Nonce must be exactly 12 bytes (got ${explicitNonce.length})',
        );
      }
      nonce = explicitNonce;
    } else {
      nonce = Uint8List.fromList(_aead.newNonce());
    }

    final secretKey = SecretKey(keys.sendKey);
    final secretBox = await _aead.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    session.recordSentMessage();

    return SessionEncryptedPayload.fromSecretBox(secretBox);
  }

  /// Decrypts [encrypted] using ChaCha20-Poly1305 with the session's directional receiveKey
  /// and verifies authentication against [aad].
  ///
  /// Fails closed:
  /// If ciphertext, nonce, MAC tag, AAD, or directional key does not match,
  /// throws [DirectionalEncryptionException] with zero plaintext returned.
  Future<Uint8List> decrypt({
    required EphemeralSession session,
    required SessionEncryptedPayload encrypted,
    required Uint8List aad,
  }) async {
    if (session.isDestroyed) {
      throw const DirectionalEncryptionException(
        'Cannot decrypt: session is destroyed',
      );
    }

    final keys = await getOrDeriveKeys(session);
    if (keys.isDestroyed) {
      throw const DirectionalEncryptionException(
        'Cannot decrypt: session keys are destroyed',
      );
    }

    if (encrypted.nonce.length != 12) {
      throw DirectionalEncryptionException(
        'Invalid nonce length: must be 12 bytes (got ${encrypted.nonce.length})',
      );
    }
    if (encrypted.mac.length != 16) {
      throw DirectionalEncryptionException(
        'Invalid MAC tag length: must be 16 bytes (got ${encrypted.mac.length})',
      );
    }

    final secretKey = SecretKey(keys.receiveKey);

    try {
      final decrypted = await _aead.decrypt(
        encrypted.toSecretBox(),
        secretKey: secretKey,
        aad: aad,
      );
      session.recordReceivedMessage();
      return Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError catch (e) {
      throw DirectionalEncryptionException(
        'Decryption authentication failed: invalid MAC tag or tampered data: $e',
      );
    } catch (e) {
      throw DirectionalEncryptionException('Decryption failed: $e');
    }
  }

  /// Convenience helper to encrypt a UTF-8 string payload.
  Future<SessionEncryptedPayload> encryptString({
    required EphemeralSession session,
    required String text,
    required Uint8List aad,
    Uint8List? explicitNonce,
  }) =>
      encrypt(
        session: session,
        plaintext: Uint8List.fromList(utf8.encode(text)),
        aad: aad,
        explicitNonce: explicitNonce,
      );

  /// Convenience helper to decrypt an encrypted payload to a UTF-8 string.
  Future<String> decryptString({
    required EphemeralSession session,
    required SessionEncryptedPayload encrypted,
    required Uint8List aad,
  }) async {
    final decryptedBytes = await decrypt(
      session: session,
      encrypted: encrypted,
      aad: aad,
    );
    try {
      return utf8.decode(decryptedBytes, allowMalformed: false);
    } catch (e) {
      throw DirectionalEncryptionException('Decrypted payload is not valid UTF-8: $e');
    }
  }

  /// Builds canonical AAD (Authenticated Additional Data) binding protocol version,
  /// packet type, session ID, origin, destination, and message ID.
  ///
  /// Format:
  /// `MESHLINK-v2-AAD|<version>|<packetType>|<sessionId>|<originId>|<destinationId>|<messageId>`
  static Uint8List buildCanonicalAad({
    int version = protocolVersion,
    String packetType = 'encrypted_message',
    required String sessionId,
    required String originId,
    required String destinationId,
    required String messageId,
  }) {
    return Uint8List.fromList(
      utf8.encode(
        'MESHLINK-v2-AAD|$version|$packetType|$sessionId|$originId|$destinationId|$messageId',
      ),
    );
  }
}

/// Thrown when directional encryption or decryption fails.
class DirectionalEncryptionException implements Exception {
  const DirectionalEncryptionException(this.message);
  final String message;

  @override
  String toString() => 'DirectionalEncryptionException: $message';
}
