import 'dart:typed_data';

/// Represents a negotiated ephemeral X25519 session between two peers.
///
/// Created after a successful handshake (Step 3 + Step 4) where both peers
/// have exchanged ephemeral X25519 public keys and derived directional
/// session keys via ECDH + HKDF.
///
/// Session keys are directional:
/// - [initiatorToResponderKey]: Key used by the initiator to encrypt and
///   the responder to decrypt.
/// - [responderToInitiatorKey]: Key used by the responder to encrypt and
///   the initiator to decrypt.
class EphemeralSession {
  const EphemeralSession({
    required this.requestId,
    required this.localId,
    required this.peerId,
    required this.isInitiator,
    required this.localEphemeralPublicKey,
    required this.peerEphemeralPublicKey,
    required this.initiatorToResponderKey,
    required this.responderToInitiatorKey,
    required this.createdAt,
  });

  /// The handshake request ID that produced this session.
  final String requestId;

  /// Local device identifier.
  final String localId;

  /// Remote peer device identifier.
  final String peerId;

  /// Whether the local device was the handshake initiator.
  final bool isInitiator;

  /// Local ephemeral X25519 public key (32 bytes).
  final Uint8List localEphemeralPublicKey;

  /// Peer's ephemeral X25519 public key (32 bytes).
  final Uint8List peerEphemeralPublicKey;

  /// 32-byte symmetric key: initiator → responder direction.
  final Uint8List initiatorToResponderKey;

  /// 32-byte symmetric key: responder → initiator direction.
  final Uint8List responderToInitiatorKey;

  /// When this session was established (milliseconds since epoch).
  final int createdAt;

  /// Returns the encryption key for the local device.
  Uint8List get localEncryptionKey =>
      isInitiator ? initiatorToResponderKey : responderToInitiatorKey;

  /// Returns the decryption key for the local device.
  Uint8List get localDecryptionKey =>
      isInitiator ? responderToInitiatorKey : initiatorToResponderKey;
}

/// Exception for ephemeral session failures.
class EphemeralSessionException implements Exception {
  const EphemeralSessionException(this.message);
  final String message;

  @override
  String toString() => 'EphemeralSessionException: $message';
}
