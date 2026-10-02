import 'dart:convert';
import 'dart:typed_data';

/// Error codes representing specific handshake failures.
enum HandshakeErrorCode {
  invalidProtocolVersion,
  invalidRequest,
  invalidResponse,
  invalidIdentityKey,
  invalidSignature,
  transcriptMismatch,
  requestIdMismatch,
  peerIdentityMismatch,
  invalidKeyLength,
  invalidEncoding,
  sessionDerivationFailed,
}

/// Structured exception thrown on handshake verification, validation, or protocol failures.
///
/// Deliberately avoids exposing private key material or secrets in error strings.
class HandshakeException implements Exception {
  const HandshakeException(this.code, this.message);

  final HandshakeErrorCode code;
  final String message;

  @override
  String toString() => 'HandshakeException(${code.name}): $message';
}

/// Represents the v2 authenticated `key_request` packet sent from initiator to responder.
class KeyRequestPacket {
  const KeyRequestPacket({
    required this.protocolVersion,
    required this.requestId,
    required this.originId,
    required this.destinationId,
    required this.timestamp,
    required this.identityPublicKey,
    required this.ephemeralPublicKey,
    required this.signature,
  });

  /// Must be 2 for Phase 7 v2 handshake.
  final int protocolVersion;

  /// Unique handshake session identifier.
  final String requestId;

  /// Initiator device identifier (e.g. ML-A1B2C3).
  final String originId;

  /// Target peer device identifier.
  final String destinationId;

  /// Milliseconds since Unix epoch.
  final int timestamp;

  /// Canonical Base64URL-encoded 32-byte Ed25519 public identity key.
  final String identityPublicKey;

  /// Canonical Base64URL-encoded 32-byte X25519 ephemeral public key (Step 4 placeholder).
  final String ephemeralPublicKey;

  /// Canonical Base64URL-encoded 64-byte Ed25519 signature over `Transcript_Req`.
  final String signature;

  Map<String, dynamic> toMap() => {
    'type': 'key_request',
    'version': protocolVersion,
    'requestId': requestId,
    'originId': originId,
    'destinationId': destinationId,
    'timestamp': timestamp,
    'identityPublicKey': identityPublicKey,
    'ephemeralPublicKey': ephemeralPublicKey,
    'signature': signature,
  };

  String toJson() => jsonEncode(toMap());

  factory KeyRequestPacket.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    if (type != 'key_request') {
      throw const HandshakeException(
        HandshakeErrorCode.invalidRequest,
        'Expected payload type "key_request"',
      );
    }

    final version = map['version'] as int?;
    if (version == null || version != 2) {
      throw HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Unsupported handshake protocol version: $version (expected 2)',
      );
    }

    final requestId = map['requestId'] as String?;
    final originId = map['originId'] as String?;
    final destinationId = map['destinationId'] as String?;
    final timestamp = map['timestamp'] as int?;
    final identityPublicKey = map['identityPublicKey'] as String?;
    final ephemeralPublicKey = map['ephemeralPublicKey'] as String?;
    final signature = map['signature'] as String?;

    if (requestId == null ||
        originId == null ||
        destinationId == null ||
        timestamp == null ||
        identityPublicKey == null ||
        ephemeralPublicKey == null ||
        signature == null) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidRequest,
        'Missing required fields in key_request packet',
      );
    }

    return KeyRequestPacket(
      protocolVersion: version,
      requestId: requestId,
      originId: originId,
      destinationId: destinationId,
      timestamp: timestamp,
      identityPublicKey: identityPublicKey,
      ephemeralPublicKey: ephemeralPublicKey,
      signature: signature,
    );
  }

  factory KeyRequestPacket.fromJson(String source) =>
      KeyRequestPacket.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Represents the v2 authenticated `key_response` packet sent from responder to initiator.
class KeyResponsePacket {
  const KeyResponsePacket({
    required this.protocolVersion,
    required this.requestId,
    required this.originId,
    required this.destinationId,
    required this.timestamp,
    required this.identityPublicKey,
    required this.ephemeralPublicKey,
    required this.signature,
    this.initiatorIdentityPublicKey,
    this.initiatorEphemeralPublicKey,
  });

  /// Must be 2 for Phase 7 v2 handshake.
  final int protocolVersion;

  /// Matching handshake request identifier.
  final String requestId;

  /// Responder device identifier (e.g. ML-D4E5F6).
  final String originId;

  /// Original initiator device identifier (e.g. ML-A1B2C3).
  final String destinationId;

  /// Milliseconds since Unix epoch.
  final int timestamp;

  /// Responder's canonical Base64URL-encoded 32-byte Ed25519 identity key.
  final String identityPublicKey;

  /// Responder's canonical Base64URL-encoded 32-byte X25519 ephemeral key.
  final String ephemeralPublicKey;

  /// Canonical Base64URL-encoded 64-byte Ed25519 signature over `Transcript_Resp`.
  final String signature;

  /// Optional echo of initiator's identity key for transport convenience.
  final String? initiatorIdentityPublicKey;

  /// Optional echo of initiator's ephemeral key for transport convenience.
  final String? initiatorEphemeralPublicKey;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': 'key_response',
      'version': protocolVersion,
      'requestId': requestId,
      'originId': originId,
      'destinationId': destinationId,
      'timestamp': timestamp,
      'identityPublicKey': identityPublicKey,
      'ephemeralPublicKey': ephemeralPublicKey,
      'signature': signature,
    };
    if (initiatorIdentityPublicKey != null) {
      map['initiatorIdentityPublicKey'] = initiatorIdentityPublicKey;
    }
    if (initiatorEphemeralPublicKey != null) {
      map['initiatorEphemeralPublicKey'] = initiatorEphemeralPublicKey;
    }
    return map;
  }

  String toJson() => jsonEncode(toMap());

  factory KeyResponsePacket.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    if (type != 'key_response') {
      throw const HandshakeException(
        HandshakeErrorCode.invalidResponse,
        'Expected payload type "key_response"',
      );
    }

    final version = map['version'] as int?;
    if (version == null || version != 2) {
      throw HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Unsupported handshake protocol version: $version (expected 2)',
      );
    }

    final requestId = map['requestId'] as String?;
    final originId = map['originId'] as String?;
    final destinationId = map['destinationId'] as String?;
    final timestamp = map['timestamp'] as int?;
    final identityPublicKey = map['identityPublicKey'] as String?;
    final ephemeralPublicKey = map['ephemeralPublicKey'] as String?;
    final signature = map['signature'] as String?;

    if (requestId == null ||
        originId == null ||
        destinationId == null ||
        timestamp == null ||
        identityPublicKey == null ||
        ephemeralPublicKey == null ||
        signature == null) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidResponse,
        'Missing required fields in key_response packet',
      );
    }

    return KeyResponsePacket(
      protocolVersion: version,
      requestId: requestId,
      originId: originId,
      destinationId: destinationId,
      timestamp: timestamp,
      identityPublicKey: identityPublicKey,
      ephemeralPublicKey: ephemeralPublicKey,
      signature: signature,
      initiatorIdentityPublicKey: map['initiatorIdentityPublicKey'] as String?,
      initiatorEphemeralPublicKey: map['initiatorEphemeralPublicKey'] as String?,
    );
  }

  factory KeyResponsePacket.fromJson(String source) =>
      KeyResponsePacket.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// In-memory transient state for an ongoing handshake request initiated by this device.
class HandshakePendingRequest {
  const HandshakePendingRequest({
    required this.requestId,
    required this.peerId,
    required this.localId,
    required this.initiatorIdentityPublicKey,
    required this.initiatorEphemeralPublicKey,
    required this.timestamp,
    required this.requestTranscript,
    required this.requestSignature,
  });

  final String requestId;
  final String peerId;
  final String localId;
  final Uint8List initiatorIdentityPublicKey;
  final Uint8List initiatorEphemeralPublicKey;
  final int timestamp;
  final Uint8List requestTranscript;
  final Uint8List requestSignature;
}

/// Result of an authenticated handshake verification.
class HandshakeVerificationResult {
  const HandshakeVerificationResult({
    required this.isValid,
    required this.protocolVersion,
    required this.requestId,
    required this.originId,
    required this.destinationId,
    required this.peerIdentityPublicKey,
    required this.peerEphemeralPublicKey,
    required this.timestamp,
    this.errorMessage,
  });

  final bool isValid;
  final int protocolVersion;
  final String requestId;
  final String originId;
  final String destinationId;
  final Uint8List peerIdentityPublicKey;
  final Uint8List peerEphemeralPublicKey;
  final int timestamp;
  final String? errorMessage;
}
