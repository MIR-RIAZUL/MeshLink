// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';

/// Deterministic, canonical binary transcript encoder for Phase 7 v2 handshake.
///
/// Encodes transcripts according to the approved binary layout using length-prefixed
/// strings, big-endian integers, and fixed 32-byte public key representations.
class HandshakeTranscriptEncoder {
  static const String requestDomainTag = 'MESHLINK-v2-REQ:';
  static const String responseDomainTag = 'MESHLINK-v2-RSP:';
  static const int currentProtocolVersion = 2;

  static final Uint8List _requestTagBytes =
      Uint8List.fromList(utf8.encode(requestDomainTag));
  static final Uint8List _responseTagBytes =
      Uint8List.fromList(utf8.encode(responseDomainTag));

  /// Encodes the canonical binary transcript for `key_request`.
  ///
  /// Layout:
  /// - `MESHLINK-v2-REQ:` (16 bytes UTF-8)
  /// - `uint16_be(protocolVersion)` (2 bytes)
  /// - `uint64_be(timestampMilliseconds)` (8 bytes)
  /// - `length(requestId)` (1 byte) + `requestId` (UTF-8 bytes)
  /// - `length(originId)` (1 byte) + `originId` (UTF-8 bytes)
  /// - `length(destinationId)` (1 byte) + `destinationId` (UTF-8 bytes)
  /// - `pk_idA` (32 bytes raw Ed25519 public key)
  /// - `pk_ephA` (32 bytes raw X25519 ephemeral public key)
  static Uint8List encodeKeyRequestTranscript({
    int protocolVersion = currentProtocolVersion,
    required int timestamp,
    required String requestId,
    required String originId,
    required String destinationId,
    required List<int> initiatorIdentityKey,
    required List<int> initiatorEphemeralKey,
  }) {
    _validateVersion(protocolVersion);
    _validateTimestamp(timestamp);
    _validateKey(initiatorIdentityKey, 'initiatorIdentityKey');
    _validateKey(initiatorEphemeralKey, 'initiatorEphemeralKey');

    final reqIdBytes = _encodeLengthPrefixedString(requestId, 'requestId');
    final origIdBytes = _encodeLengthPrefixedString(originId, 'originId');
    final destIdBytes = _encodeLengthPrefixedString(destinationId, 'destinationId');

    final builder = BytesBuilder(copy: false);
    builder.add(_requestTagBytes);

    final header = ByteData(10);
    header.setUint16(0, protocolVersion, Endian.big);
    header.setUint64(2, timestamp, Endian.big);
    builder.add(header.buffer.asUint8List());

    builder.add(reqIdBytes);
    builder.add(origIdBytes);
    builder.add(destIdBytes);
    builder.add(initiatorIdentityKey);
    builder.add(initiatorEphemeralKey);

    return builder.toBytes();
  }

  /// Encodes the canonical binary transcript for `key_response`.
  ///
  /// Layout:
  /// - `MESHLINK-v2-RSP:` (16 bytes UTF-8)
  /// - `uint16_be(protocolVersion)` (2 bytes)
  /// - `uint64_be(timestampMilliseconds)` (8 bytes)
  /// - `length(requestId)` (1 byte) + `requestId` (UTF-8 bytes)
  /// - `length(originId)` (1 byte) + `originId` (UTF-8 bytes)
  /// - `length(destinationId)` (1 byte) + `destinationId` (UTF-8 bytes)
  /// - `pk_idA` (32 bytes raw Ed25519 public key of initiator)
  /// - `pk_ephA` (32 bytes raw X25519 ephemeral public key of initiator)
  /// - `pk_idB` (32 bytes raw Ed25519 public key of responder)
  /// - `pk_ephB` (32 bytes raw X25519 ephemeral public key of responder)
  static Uint8List encodeKeyResponseTranscript({
    int protocolVersion = currentProtocolVersion,
    required int timestamp,
    required String requestId,
    required String originId,
    required String destinationId,
    required List<int> initiatorIdentityKey,
    required List<int> initiatorEphemeralKey,
    required List<int> responderIdentityKey,
    required List<int> responderEphemeralKey,
  }) {
    _validateVersion(protocolVersion);
    _validateTimestamp(timestamp);
    _validateKey(initiatorIdentityKey, 'initiatorIdentityKey');
    _validateKey(initiatorEphemeralKey, 'initiatorEphemeralKey');
    _validateKey(responderIdentityKey, 'responderIdentityKey');
    _validateKey(responderEphemeralKey, 'responderEphemeralKey');

    final reqIdBytes = _encodeLengthPrefixedString(requestId, 'requestId');
    final origIdBytes = _encodeLengthPrefixedString(originId, 'originId');
    final destIdBytes = _encodeLengthPrefixedString(destinationId, 'destinationId');

    final builder = BytesBuilder(copy: false);
    builder.add(_responseTagBytes);

    final header = ByteData(10);
    header.setUint16(0, protocolVersion, Endian.big);
    header.setUint64(2, timestamp, Endian.big);
    builder.add(header.buffer.asUint8List());

    builder.add(reqIdBytes);
    builder.add(origIdBytes);
    builder.add(destIdBytes);
    builder.add(initiatorIdentityKey);
    builder.add(initiatorEphemeralKey);
    builder.add(responderIdentityKey);
    builder.add(responderEphemeralKey);

    return builder.toBytes();
  }

  static void _validateVersion(int version) {
    if (version < 0 || version > 65535) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Protocol version must fit in uint16',
      );
    }
  }

  static void _validateTimestamp(int timestamp) {
    if (timestamp < 0) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidRequest,
        'Timestamp cannot be negative',
      );
    }
  }

  static void _validateKey(List<int> key, String fieldName) {
    if (key.length != 32) {
      throw HandshakeException(
        HandshakeErrorCode.invalidKeyLength,
        '$fieldName must be exactly 32 bytes (got ${key.length})',
      );
    }
  }

  static Uint8List _encodeLengthPrefixedString(String value, String fieldName) {
    final bytes = utf8.encode(value);
    if (bytes.isEmpty || bytes.length > 255) {
      throw HandshakeException(
        HandshakeErrorCode.invalidEncoding,
        '$fieldName length must be between 1 and 255 bytes (got ${bytes.length})',
      );
    }
    final result = Uint8List(1 + bytes.length);
    result[0] = bytes.length;
    result.setRange(1, 1 + bytes.length, bytes);
    return result;
  }
}

/// Interface for providing ephemeral X25519 public keys during handshake.
///
/// In Step 3, ephemeral public keys are bound into the signed transcripts and
/// message packets. Ephemeral key agreement, shared-secret derivation, and HKDF
/// session keys are strictly deferred to Step 4.
abstract class EphemeralKeyProvider {
  Future<Uint8List> getEphemeralPublicKey();
}

/// Step 4 placeholder providing genuine 32-byte X25519 public keys for protocol
/// integrity without establishing or storing ephemeral sessions.
class Step4EphemeralKeyPlaceholder implements EphemeralKeyProvider {
  Step4EphemeralKeyPlaceholder([Uint8List? key]) : _key = key;

  final Uint8List? _key;
  static final _x25519 = X25519();

  @override
  Future<Uint8List> getEphemeralPublicKey() async {
    if (_key != null) return _key;
    final keyPair = await _x25519.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }
}

/// Service implementing the Step 3 authenticated Ed25519 handshake protocol.
///
/// Responsible for:
/// - Creating and signing v2 `key_request` packets using local Ed25519 identity key.
/// - Verifying incoming `key_request` packets against initiator Ed25519 identity key.
/// - Creating and signing v2 `key_response` packets binding initiator parameters.
/// - Verifying incoming `key_response` packets against initiator pending state and responder Ed25519 key.
/// - Checking known peer identity keys against [MessageRepository] to detect key mismatches.
class HandshakeService {
  HandshakeService({
    required MeshIdentityService identityService,
    required String localId,
    MessageRepository? peerRepository,
    Ed25519? ed25519,
    EphemeralKeyProvider? ephemeralKeyProvider,
  })  : _identityService = identityService,
        _localId = localId,
        _peerRepository = peerRepository,
        _ed25519 = ed25519 ?? Ed25519(),
        _ephemeralKeyProvider =
            ephemeralKeyProvider ?? Step4EphemeralKeyPlaceholder();

  final MeshIdentityService _identityService;
  String _localId;
  final MessageRepository? _peerRepository;
  final Ed25519 _ed25519;
  final EphemeralKeyProvider _ephemeralKeyProvider;

  final Map<String, HandshakePendingRequest> _pendingRequests = {};

  String get localId => _localId;

  void setLocalId(String id) {
    _localId = id;
  }

  /// Generates a standardized unique request ID.
  static String generateRequestId() {
    final rand = Random()
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return 'REQ-${DateTime.now().millisecondsSinceEpoch}-$rand';
  }

  /// Initiates an authenticated handshake by creating and signing a `key_request` packet.
  Future<KeyRequestPacket> createKeyRequest({
    required String destinationId,
    String? requestId,
    List<int>? ephemeralPublicKey,
    int? timestamp,
  }) async {
    final reqId = requestId ?? generateRequestId();
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    final idPubKeyBytes = await _identityService.getIdentityPublicKeyBytes();
    final ephPubKeyBytes = ephemeralPublicKey != null
        ? Uint8List.fromList(ephemeralPublicKey)
        : await _ephemeralKeyProvider.getEphemeralPublicKey();

    final transcript = HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
      protocolVersion: 2,
      timestamp: ts,
      requestId: reqId,
      originId: _localId,
      destinationId: destinationId,
      initiatorIdentityKey: idPubKeyBytes,
      initiatorEphemeralKey: ephPubKeyBytes,
    );

    final keyPair = await _identityService.getKeyPair();
    final signatureObj = await _ed25519.sign(transcript, keyPair: keyPair);
    final signatureBytes = Uint8List.fromList(signatureObj.bytes);

    // Register pending request in memory for matching incoming responses
    final pending = HandshakePendingRequest(
      requestId: reqId,
      peerId: destinationId,
      localId: _localId,
      initiatorIdentityPublicKey: idPubKeyBytes,
      initiatorEphemeralPublicKey: ephPubKeyBytes,
      timestamp: ts,
      requestTranscript: transcript,
      requestSignature: signatureBytes,
    );
    _pendingRequests[reqId] = pending;

    return KeyRequestPacket(
      protocolVersion: 2,
      requestId: reqId,
      originId: _localId,
      destinationId: destinationId,
      timestamp: ts,
      identityPublicKey: base64UrlEncode(idPubKeyBytes),
      ephemeralPublicKey: base64UrlEncode(ephPubKeyBytes),
      signature: base64UrlEncode(signatureBytes),
    );
  }

  /// Verifies an incoming `key_request` packet from an initiator peer.
  Future<HandshakeVerificationResult> verifyKeyRequest(
    KeyRequestPacket request,
  ) async {
    if (request.protocolVersion != 2) {
      throw HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Expected protocol version 2, got ${request.protocolVersion}',
      );
    }

    final Uint8List idPubKeyBytes;
    final Uint8List ephPubKeyBytes;
    final Uint8List sigBytes;

    try {
      idPubKeyBytes = Uint8List.fromList(base64Url.decode(request.identityPublicKey));
      ephPubKeyBytes = Uint8List.fromList(base64Url.decode(request.ephemeralPublicKey));
      sigBytes = Uint8List.fromList(base64Url.decode(request.signature));
    } catch (e) {
      throw HandshakeException(
        HandshakeErrorCode.invalidEncoding,
        'Malformed Base64URL in request keys or signature: $e',
      );
    }

    if (idPubKeyBytes.length != 32 || ephPubKeyBytes.length != 32) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidKeyLength,
        'Public keys must be 32 bytes',
      );
    }

    if (sigBytes.length != 64) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidSignature,
        'Signature must be 64 bytes',
      );
    }

    // Check if the peer's identity key is already known and has changed
    if (_peerRepository != null) {
      final knownPeer = await _peerRepository.getPeerIdentity(request.originId);
      if (knownPeer != null &&
          knownPeer.identityPublicKey != request.identityPublicKey) {
        throw HandshakeException(
          HandshakeErrorCode.peerIdentityMismatch,
          'Known peer ${request.originId} presented a different identity key',
        );
      }
    }

    final transcript = HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
      protocolVersion: request.protocolVersion,
      timestamp: request.timestamp,
      requestId: request.requestId,
      originId: request.originId,
      destinationId: request.destinationId,
      initiatorIdentityKey: idPubKeyBytes,
      initiatorEphemeralKey: ephPubKeyBytes,
    );

    final isValid = await _ed25519.verify(
      transcript,
      signature: Signature(
        sigBytes,
        publicKey: SimplePublicKey(idPubKeyBytes, type: KeyPairType.ed25519),
      ),
    );

    if (!isValid) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidSignature,
        'Request signature verification failed',
      );
    }

    return HandshakeVerificationResult(
      isValid: true,
      protocolVersion: request.protocolVersion,
      requestId: request.requestId,
      originId: request.originId,
      destinationId: request.destinationId,
      peerIdentityPublicKey: idPubKeyBytes,
      peerEphemeralPublicKey: ephPubKeyBytes,
      timestamp: request.timestamp,
    );
  }

  /// Creates and signs a `key_response` packet in response to a verified `key_request`.
  Future<KeyResponsePacket> createKeyResponse({
    required KeyRequestPacket request,
    List<int>? ephemeralPublicKey,
    int? timestamp,
  }) async {
    // 1. Verify the request first
    await verifyKeyRequest(request);

    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final responderIdBytes = await _identityService.getIdentityPublicKeyBytes();
    final responderEphBytes = ephemeralPublicKey != null
        ? Uint8List.fromList(ephemeralPublicKey)
        : await _ephemeralKeyProvider.getEphemeralPublicKey();

    final initiatorIdBytes =
        Uint8List.fromList(base64Url.decode(request.identityPublicKey));
    final initiatorEphBytes =
        Uint8List.fromList(base64Url.decode(request.ephemeralPublicKey));

    // 2. Build response transcript binding A's original parameters
    final transcript = HandshakeTranscriptEncoder.encodeKeyResponseTranscript(
      protocolVersion: 2,
      timestamp: ts,
      requestId: request.requestId,
      originId: _localId,
      destinationId: request.originId,
      initiatorIdentityKey: initiatorIdBytes,
      initiatorEphemeralKey: initiatorEphBytes,
      responderIdentityKey: responderIdBytes,
      responderEphemeralKey: responderEphBytes,
    );

    final keyPair = await _identityService.getKeyPair();
    final signatureObj = await _ed25519.sign(transcript, keyPair: keyPair);
    final signatureBytes = Uint8List.fromList(signatureObj.bytes);

    return KeyResponsePacket(
      protocolVersion: 2,
      requestId: request.requestId,
      originId: _localId,
      destinationId: request.originId,
      timestamp: ts,
      identityPublicKey: base64UrlEncode(responderIdBytes),
      ephemeralPublicKey: base64UrlEncode(responderEphBytes),
      signature: base64UrlEncode(signatureBytes),
      initiatorIdentityPublicKey: request.identityPublicKey,
      initiatorEphemeralPublicKey: request.ephemeralPublicKey,
    );
  }

  /// Verifies an incoming `key_response` packet against our original request parameters.
  Future<HandshakeVerificationResult> verifyKeyResponse(
    KeyResponsePacket response, {
    HandshakePendingRequest? expectedRequest,
    List<int>? overrideExpectedInitiatorIdentityKey,
    List<int>? overrideExpectedInitiatorEphemeralKey,
  }) async {
    if (response.protocolVersion != 2) {
      throw HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Expected protocol version 2, got ${response.protocolVersion}',
      );
    }

    final pending =
        expectedRequest ?? _pendingRequests[response.requestId];
    if (pending == null) {
      throw HandshakeException(
        HandshakeErrorCode.requestIdMismatch,
        'No pending request found matching requestId ${response.requestId}',
      );
    }

    if (response.requestId != pending.requestId) {
      throw HandshakeException(
        HandshakeErrorCode.requestIdMismatch,
        'Response requestId ${response.requestId} does not match pending ${pending.requestId}',
      );
    }

    if (response.originId != pending.peerId ||
        response.destinationId != pending.localId) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidResponse,
        'Origin or destination ID mismatch in key_response',
      );
    }

    // Verify echoes if present in payload
    if (response.initiatorIdentityPublicKey != null &&
        response.initiatorIdentityPublicKey !=
            base64UrlEncode(pending.initiatorIdentityPublicKey)) {
      throw const HandshakeException(
        HandshakeErrorCode.transcriptMismatch,
        'Initiator identity key in response does not match original request',
      );
    }

    if (response.initiatorEphemeralPublicKey != null &&
        response.initiatorEphemeralPublicKey !=
            base64UrlEncode(pending.initiatorEphemeralPublicKey)) {
      throw const HandshakeException(
        HandshakeErrorCode.transcriptMismatch,
        'Initiator ephemeral key in response does not match original request',
      );
    }

    final Uint8List responderIdBytes;
    final Uint8List responderEphBytes;
    final Uint8List sigBytes;

    try {
      responderIdBytes =
          Uint8List.fromList(base64Url.decode(response.identityPublicKey));
      responderEphBytes =
          Uint8List.fromList(base64Url.decode(response.ephemeralPublicKey));
      sigBytes = Uint8List.fromList(base64Url.decode(response.signature));
    } catch (e) {
      throw HandshakeException(
        HandshakeErrorCode.invalidEncoding,
        'Malformed Base64URL in response keys or signature: $e',
      );
    }

    if (responderIdBytes.length != 32 || responderEphBytes.length != 32) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidKeyLength,
        'Public keys must be 32 bytes',
      );
    }

    if (sigBytes.length != 64) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidSignature,
        'Signature must be 64 bytes',
      );
    }

    // Check if the peer's identity key has changed against stored records
    if (_peerRepository != null) {
      final knownPeer = await _peerRepository.getPeerIdentity(response.originId);
      if (knownPeer != null &&
          knownPeer.identityPublicKey != response.identityPublicKey) {
        throw HandshakeException(
          HandshakeErrorCode.peerIdentityMismatch,
          'Known peer ${response.originId} presented a different identity key',
        );
      }
    }

    final effectiveInitIdKey =
        overrideExpectedInitiatorIdentityKey ?? pending.initiatorIdentityPublicKey;
    final effectiveInitEphKey =
        overrideExpectedInitiatorEphemeralKey ?? pending.initiatorEphemeralPublicKey;

    final transcript = HandshakeTranscriptEncoder.encodeKeyResponseTranscript(
      protocolVersion: response.protocolVersion,
      timestamp: response.timestamp,
      requestId: response.requestId,
      originId: response.originId,
      destinationId: response.destinationId,
      initiatorIdentityKey: effectiveInitIdKey,
      initiatorEphemeralKey: effectiveInitEphKey,
      responderIdentityKey: responderIdBytes,
      responderEphemeralKey: responderEphBytes,
    );

    final isValid = await _ed25519.verify(
      transcript,
      signature: Signature(
        sigBytes,
        publicKey: SimplePublicKey(responderIdBytes, type: KeyPairType.ed25519),
      ),
    );

    if (!isValid) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidSignature,
        'Response signature verification failed',
      );
    }

    // Remove pending request on successful verification
    _pendingRequests.remove(response.requestId);

    return HandshakeVerificationResult(
      isValid: true,
      protocolVersion: response.protocolVersion,
      requestId: response.requestId,
      originId: response.originId,
      destinationId: response.destinationId,
      peerIdentityPublicKey: responderIdBytes,
      peerEphemeralPublicKey: responderEphBytes,
      timestamp: response.timestamp,
    );
  }

  /// Returns pending request matching [requestId], if any.
  HandshakePendingRequest? getPendingRequest(String requestId) =>
      _pendingRequests[requestId];

  /// Clears in-memory pending request state.
  void clearPendingRequest(String requestId) {
    _pendingRequests.remove(requestId);
  }
}
