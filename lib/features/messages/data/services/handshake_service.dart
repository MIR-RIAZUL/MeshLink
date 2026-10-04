// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
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
    if (version != currentProtocolVersion) {
      throw HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Expected protocol version $currentProtocolVersion, got $version',
      );
    }
  }

  static void _validateTimestamp(int timestamp) {
    if (timestamp <= 0) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidTimestamp,
        'Timestamp must be a positive integer',
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
    HandshakePacketValidator.validateIdentifier(value, fieldName);
    final result = Uint8List(1 + bytes.length);
    result[0] = bytes.length;
    result.setRange(1, 1 + bytes.length, bytes);
    return result;
  }
}

/// Interface for providing ephemeral X25519 public keys during handshake.
///
/// Implementations:
/// - [EphemeralSessionService] (Step 4): Real X25519 key pair generation with
///   ECDH shared secret agreement.
/// - [StaticEphemeralKeyProvider]: Test-only provider with a fixed key.
abstract class EphemeralKeyProvider {
  Future<Uint8List> getEphemeralPublicKey({String? requestId});
}

/// Test-only [EphemeralKeyProvider] supplying a fixed or randomly generated
/// 32-byte X25519 public key without session establishment.
class StaticEphemeralKeyProvider implements EphemeralKeyProvider {
  StaticEphemeralKeyProvider([Uint8List? key]) : _key = key;

  final Uint8List? _key;
  static final _x25519 = X25519();

  @override
  Future<Uint8List> getEphemeralPublicKey({String? requestId}) async {
    if (_key != null) return _key;
    final keyPair = await _x25519.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }
}

/// Service implementing the Step 3 authenticated Ed25519 handshake protocol
/// and Step 4 ephemeral X25519 session establishment.
///
/// Responsible for:
/// - Creating and signing v2 `key_request` packets using local Ed25519 identity key.
/// - Verifying incoming `key_request` packets against initiator Ed25519 identity key.
/// - Creating and signing v2 `key_response` packets binding initiator parameters.
/// - Verifying incoming `key_response` packets against initiator pending state and responder Ed25519 key.
/// - Checking known peer identity keys against [MessageRepository] to detect key mismatches.
/// - Establishing in-memory ephemeral X25519 Diffie-Hellman sessions via [EphemeralSessionService].
class HandshakeService {
  HandshakeService({
    required MeshIdentityService identityService,
    required String localId,
    MessageRepository? peerRepository,
    Ed25519? ed25519,
    EphemeralKeyProvider? ephemeralKeyProvider,
    EphemeralSessionService? sessionService,
  })  : _identityService = identityService,
        _localId = localId,
        _peerRepository = peerRepository,
        _ed25519 = ed25519 ?? Ed25519(),
        _sessionService = sessionService ??
            (ephemeralKeyProvider is EphemeralSessionService
                ? ephemeralKeyProvider
                : (ephemeralKeyProvider == null ? EphemeralSessionService() : null)),
        _ephemeralKeyProvider = ephemeralKeyProvider ??
            sessionService ??
            (ephemeralKeyProvider == null
                ? (sessionService ?? EphemeralSessionService())
                : StaticEphemeralKeyProvider());

  final MeshIdentityService _identityService;
  String _localId;
  final MessageRepository? _peerRepository;
  final Ed25519 _ed25519;
  final EphemeralKeyProvider _ephemeralKeyProvider;
  final EphemeralSessionService? _sessionService;

  final Map<String, HandshakePendingRequest> _pendingRequests = {};

  /// Returns the injected [EphemeralSessionService], if any.
  EphemeralSessionService? get sessionService => _sessionService;

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
    final active = _sessionService?.getSession(destinationId);
    if (active != null && !active.isDestroyed) {
      if (!(_sessionService?.isRekeyInProgress(destinationId) ?? false)) {
        final begun = _sessionService?.beginRekey(destinationId) ?? true;
        if (!begun) {
          throw const HandshakeException(
            HandshakeErrorCode.concurrentHandshake,
            'A rekey is already in progress for this peer',
          );
        }
      }
    } else {
      _sessionService?.setLifecycleState(destinationId, SessionLifecycleState.handshakeInit);
    }

    try {
      final reqId = requestId ?? generateRequestId();
      final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;

      final idPubKeyBytes = await _identityService.getIdentityPublicKeyBytes();
      final Uint8List ephPubKeyBytes;
      if (ephemeralPublicKey != null) {
        ephPubKeyBytes = Uint8List.fromList(ephemeralPublicKey);
      } else if (_sessionService != null) {
        final kp =
            await _sessionService.generateEphemeralKeyPair(requestId: reqId);
        ephPubKeyBytes = Uint8List.fromList(kp.publicKey.bytes);
      } else {
        ephPubKeyBytes =
            await _ephemeralKeyProvider.getEphemeralPublicKey(requestId: reqId);
      }

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
    } catch (e) {
      if (active != null && !active.isDestroyed) {
        _sessionService?.abortRekey(destinationId);
      } else {
        _sessionService?.setLifecycleState(destinationId, SessionLifecycleState.noSession);
      }
      rethrow;
    }
  }

  /// Verifies an incoming `key_request` packet from an initiator peer.
  Future<HandshakeVerificationResult> verifyKeyRequest(
    KeyRequestPacket request, {
    DateTime? now,
    bool enforceTimestampHorizon = false,
  }) async {
    if (request.protocolVersion != 2) {
      throw HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Expected protocol version 2, got ${request.protocolVersion}',
      );
    }

    HandshakePacketValidator.validateIdentifier(request.requestId, 'requestId');
    HandshakePacketValidator.validateIdentifier(request.originId, 'originId');
    HandshakePacketValidator.validateIdentifier(request.destinationId, 'destinationId');
    HandshakePacketValidator.validateTimestamp(
      request.timestamp,
      nowMs: now?.millisecondsSinceEpoch,
      enforceHorizon: enforceTimestampHorizon,
    );

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
    DateTime? now,
    bool enforceTimestampHorizon = false,
  }) async {
    final active = _sessionService?.getSession(request.originId);
    if (active != null && !active.isDestroyed) {
      if (!(_sessionService?.isRekeyInProgress(request.originId) ?? false)) {
        _sessionService?.beginRekey(request.originId);
      }
    } else {
      _sessionService?.setLifecycleState(request.originId, SessionLifecycleState.handshakeInit);
    }

    try {
      // 1. Verify the request first
      await verifyKeyRequest(
        request,
        now: now,
        enforceTimestampHorizon: enforceTimestampHorizon,
      );

      final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
      final responderIdBytes = await _identityService.getIdentityPublicKeyBytes();
      final Uint8List responderEphBytes;
      if (ephemeralPublicKey != null) {
        responderEphBytes = Uint8List.fromList(ephemeralPublicKey);
      } else if (_sessionService != null) {
        final kp = await _sessionService
            .generateEphemeralKeyPair(requestId: request.requestId);
        responderEphBytes = Uint8List.fromList(kp.publicKey.bytes);
      } else {
        responderEphBytes = await _ephemeralKeyProvider.getEphemeralPublicKey(
            requestId: request.requestId);
      }

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
    } catch (e) {
      if (active != null && !active.isDestroyed) {
        _sessionService?.abortRekey(request.originId);
      } else {
        _sessionService?.setLifecycleState(request.originId, SessionLifecycleState.noSession);
      }
      rethrow;
    }
  }

  /// Verifies an incoming `key_response` packet against our original request parameters.
  Future<HandshakeVerificationResult> verifyKeyResponse(
    KeyResponsePacket response, {
    HandshakePendingRequest? expectedRequest,
    List<int>? overrideExpectedInitiatorIdentityKey,
    List<int>? overrideExpectedInitiatorEphemeralKey,
    DateTime? now,
    bool enforceTimestampHorizon = false,
  }) async {
    if (response.protocolVersion != 2) {
      throw HandshakeException(
        HandshakeErrorCode.invalidProtocolVersion,
        'Expected protocol version 2, got ${response.protocolVersion}',
      );
    }

    HandshakePacketValidator.validateIdentifier(response.requestId, 'requestId');
    HandshakePacketValidator.validateIdentifier(response.originId, 'originId');
    HandshakePacketValidator.validateIdentifier(response.destinationId, 'destinationId');
    HandshakePacketValidator.validateTimestamp(
      response.timestamp,
      nowMs: now?.millisecondsSinceEpoch,
      enforceHorizon: enforceTimestampHorizon,
    );

    final pending =
        expectedRequest ?? _pendingRequests[response.requestId];
    if (pending == null) {
      _sessionService?.abortRekey(response.originId);
      throw HandshakeException(
        HandshakeErrorCode.requestIdMismatch,
        'No pending request found matching requestId ${response.requestId}',
      );
    }

    if (response.requestId != pending.requestId) {
      _pendingRequests.remove(response.requestId);
      _sessionService?.clearPendingKeyPair(response.requestId);
      _sessionService?.abortRekey(pending.peerId);
      throw HandshakeException(
        HandshakeErrorCode.requestIdMismatch,
        'Response requestId ${response.requestId} does not match pending ${pending.requestId}',
      );
    }

    if (now != null || enforceTimestampHorizon) {
      final currentMs = now?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
      if (currentMs - pending.timestamp > 10 * 60 * 1000) {
        _pendingRequests.remove(response.requestId);
        _sessionService?.clearPendingKeyPair(response.requestId);
        _sessionService?.abortRekey(pending.peerId);
        throw HandshakeException(
          HandshakeErrorCode.requestExpired,
          'Pending request ${response.requestId} has expired',
        );
      }
    }

    try {
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
        final knownPeer =
            await _peerRepository.getPeerIdentity(response.originId);
        if (knownPeer != null &&
            knownPeer.identityPublicKey != response.identityPublicKey) {
          throw HandshakeException(
            HandshakeErrorCode.peerIdentityMismatch,
            'Known peer ${response.originId} presented a different identity key',
          );
        }
      }

      final effectiveInitIdKey = overrideExpectedInitiatorIdentityKey ??
          pending.initiatorIdentityPublicKey;
      final effectiveInitEphKey = overrideExpectedInitiatorEphemeralKey ??
          pending.initiatorEphemeralPublicKey;

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
          publicKey:
              SimplePublicKey(responderIdBytes, type: KeyPairType.ed25519),
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
    } catch (e) {
      _pendingRequests.remove(response.requestId);
      _sessionService?.clearPendingKeyPair(response.requestId);
      _sessionService?.abortRekey(pending.peerId);
      rethrow;
    }
  }

  /// Completes the ephemeral session as the handshake **initiator** (A).
  ///
  /// Called after [verifyKeyResponse] succeeds. Uses the original pending
  /// request's ephemeral key pair and the responder's ephemeral public key
  /// from the verified response to establish the ephemeral X25519 shared secret.
  ///
  /// Requires an [EphemeralSessionService] to be injected via constructor or default.
  Future<EphemeralSession> completeSessionAsInitiator({
    required HandshakeVerificationResult verifiedResponse,
    HandshakePendingRequest? originalRequest,
    DateTime? now,
  }) async {
    final svc = _sessionService;
    if (svc == null) {
      throw const HandshakeException(
        HandshakeErrorCode.sessionDerivationFailed,
        'No EphemeralSessionService available for session derivation',
      );
    }

    final localIdPubKey = await _identityService.getIdentityPublicKeyBytes();

    try {
      final session = await svc.establishSession(
        requestId: verifiedResponse.requestId,
        localId: _localId,
        peerId: verifiedResponse.originId,
        isInitiator: true,
        peerEphemeralPublicKey: verifiedResponse.peerEphemeralPublicKey,
        localIdentityPublicKey: localIdPubKey,
        peerIdentityPublicKey: verifiedResponse.peerIdentityPublicKey,
        now: now,
      );
      _pendingRequests.remove(verifiedResponse.requestId);
      return session;
    } on EphemeralSessionException catch (e) {
      _pendingRequests.remove(verifiedResponse.requestId);
      svc.clearPendingKeyPair(verifiedResponse.requestId);
      svc.abortRekey(verifiedResponse.originId, now: now);
      throw HandshakeException(
        HandshakeErrorCode.sessionDerivationFailed,
        'Session derivation failed (initiator): ${e.message}',
      );
    } catch (e) {
      _pendingRequests.remove(verifiedResponse.requestId);
      svc.clearPendingKeyPair(verifiedResponse.requestId);
      svc.abortRekey(verifiedResponse.originId, now: now);
      rethrow;
    }
  }

  /// Completes the ephemeral session as the handshake **responder** (B).
  ///
  /// Called after [createKeyResponse] succeeds. Uses the responder's ephemeral
  /// key pair and the initiator's ephemeral public key from the verified
  /// request to establish the ephemeral X25519 shared secret.
  ///
  /// Requires an [EphemeralSessionService] to be injected via constructor or default.
  Future<EphemeralSession> completeSessionAsResponder({
    required HandshakeVerificationResult verifiedRequest,
    DateTime? now,
  }) async {
    final svc = _sessionService;
    if (svc == null) {
      throw const HandshakeException(
        HandshakeErrorCode.sessionDerivationFailed,
        'No EphemeralSessionService available for session derivation',
      );
    }

    final localIdPubKey = await _identityService.getIdentityPublicKeyBytes();

    try {
      return await svc.establishSession(
        requestId: verifiedRequest.requestId,
        localId: _localId,
        peerId: verifiedRequest.originId,
        isInitiator: false,
        peerEphemeralPublicKey: verifiedRequest.peerEphemeralPublicKey,
        localIdentityPublicKey: localIdPubKey,
        peerIdentityPublicKey: verifiedRequest.peerIdentityPublicKey,
        now: now,
      );
    } on EphemeralSessionException catch (e) {
      svc.clearPendingKeyPair(verifiedRequest.requestId);
      svc.abortRekey(verifiedRequest.originId, now: now);
      throw HandshakeException(
        HandshakeErrorCode.sessionDerivationFailed,
        'Session derivation failed (responder): ${e.message}',
      );
    } catch (e) {
      svc.clearPendingKeyPair(verifiedRequest.requestId);
      svc.abortRekey(verifiedRequest.originId, now: now);
      rethrow;
    }
  }

  /// Initiates an authenticated rekey procedure for an existing active session with [destinationId].
  ///
  /// Throws [HandshakeException] if no active session exists or if a rekey is
  /// already in progress for [destinationId].
  Future<KeyRequestPacket> initiateRekey({
    required String destinationId,
    String? requestId,
  }) async {
    final session = _sessionService?.getSession(destinationId);
    if (session == null || session.isDestroyed) {
      throw const HandshakeException(
        HandshakeErrorCode.invalidState,
        'Cannot initiate rekey: no active session exists for peer',
      );
    }

    final begun = _sessionService?.beginRekey(destinationId) ?? true;
    if (!begun) {
      throw const HandshakeException(
        HandshakeErrorCode.concurrentHandshake,
        'A rekey is already in progress for this peer',
      );
    }

    try {
      return await createKeyRequest(
        destinationId: destinationId,
        requestId: requestId,
      );
    } catch (e) {
      _sessionService?.abortRekey(destinationId);
      rethrow;
    }
  }

  /// Returns the current session lifecycle state for [peerId].
  SessionLifecycleState getLifecycleState(String peerId, {DateTime? now}) {
    return _sessionService?.getLifecycleState(peerId, now: now) ??
        SessionLifecycleState.noSession;
  }

  /// Returns the active established session for [peerId], if any.
  EphemeralSession? getActiveSession(String peerId) =>
      _sessionService?.getSession(peerId);

  /// Returns the most recently established active session, if any.
  EphemeralSession? get activeSession => _sessionService?.activeSession;

  /// Tears down and removes the established session for [peerId].
  void clearSession(String peerId) {
    _sessionService?.removeSession(peerId);
  }

  /// Returns pending request matching [requestId], if any.
  HandshakePendingRequest? getPendingRequest(String requestId) =>
      _pendingRequests[requestId];

  /// Clears in-memory pending request and ephemeral key state for [requestId].
  void clearPendingRequest(String requestId) {
    _pendingRequests.remove(requestId);
    _sessionService?.clearPendingKeyPair(requestId);
  }
}
