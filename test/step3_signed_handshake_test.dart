import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 3: Signed Handshake Foundation (Ed25519 Authentication)', () {
    late MeshIdentityService aliceIdentity;
    late MeshIdentityService bobIdentity;
    late HandshakeService aliceHandshake;
    late HandshakeService bobHandshake;

    setUp(() async {
      aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());

      await aliceIdentity.initialize();
      await bobIdentity.initialize();

      aliceHandshake = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ML-DEVICE-A',
      );
      bobHandshake = HandshakeService(
        identityService: bobIdentity,
        localId: 'ML-DEVICE-B',
      );
    });

    test('Test 1 — Valid request signature: A generates request, B verifies successfully', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-001',
        timestamp: 1727800000000,
      );

      expect(request.protocolVersion, 2);
      expect(request.requestId, 'REQ-001');
      expect(request.originId, 'ML-DEVICE-A');
      expect(request.destinationId, 'ML-DEVICE-B');
      expect(request.timestamp, 1727800000000);
      expect(request.identityPublicKey, await aliceIdentity.getIdentityPublicKey());
      expect(request.signature, isNotEmpty);

      final result = await bobHandshake.verifyKeyRequest(request);
      expect(result.isValid, isTrue);
      expect(result.protocolVersion, 2);
      expect(result.requestId, 'REQ-001');
      expect(result.originId, 'ML-DEVICE-A');
      expect(result.destinationId, 'ML-DEVICE-B');
      expect(base64UrlEncode(result.peerIdentityPublicKey), request.identityPublicKey);
      expect(base64UrlEncode(result.peerEphemeralPublicKey), request.ephemeralPublicKey);
    });

    test('Test 2 — Modified requestId: tampering after signing causes verification failure', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-002-ORIGINAL',
      );

      final tamperedRequest = KeyRequestPacket(
        protocolVersion: request.protocolVersion,
        requestId: 'REQ-002-TAMPERED',
        originId: request.originId,
        destinationId: request.destinationId,
        timestamp: request.timestamp,
        identityPublicKey: request.identityPublicKey,
        ephemeralPublicKey: request.ephemeralPublicKey,
        signature: request.signature,
      );

      expect(
        () => bobHandshake.verifyKeyRequest(tamperedRequest),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 3 — Modified originId: tampering after signing causes verification failure', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-003',
      );

      final tamperedRequest = KeyRequestPacket(
        protocolVersion: request.protocolVersion,
        requestId: request.requestId,
        originId: 'ML-DEVICE-MALLORY',
        destinationId: request.destinationId,
        timestamp: request.timestamp,
        identityPublicKey: request.identityPublicKey,
        ephemeralPublicKey: request.ephemeralPublicKey,
        signature: request.signature,
      );

      expect(
        () => bobHandshake.verifyKeyRequest(tamperedRequest),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 4 — Modified destinationId: tampering after signing causes verification failure', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-004',
      );

      final tamperedRequest = KeyRequestPacket(
        protocolVersion: request.protocolVersion,
        requestId: request.requestId,
        originId: request.originId,
        destinationId: 'ML-DEVICE-EVE',
        timestamp: request.timestamp,
        identityPublicKey: request.identityPublicKey,
        ephemeralPublicKey: request.ephemeralPublicKey,
        signature: request.signature,
      );

      expect(
        () => bobHandshake.verifyKeyRequest(tamperedRequest),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 5 — Modified protocol version: rejected immediately', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-005',
      );

      // 5a. Tampering protocolVersion on wire payload
      expect(
        () => KeyRequestPacket.fromMap({
          ...request.toMap(),
          'version': 1,
        }),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidProtocolVersion,
        )),
      );

      // 5b. Direct verification with modified version
      final tamperedRequest = KeyRequestPacket(
        protocolVersion: 3,
        requestId: request.requestId,
        originId: request.originId,
        destinationId: request.destinationId,
        timestamp: request.timestamp,
        identityPublicKey: request.identityPublicKey,
        ephemeralPublicKey: request.ephemeralPublicKey,
        signature: request.signature,
      );

      expect(
        () => bobHandshake.verifyKeyRequest(tamperedRequest),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidProtocolVersion,
        )),
      );
    });

    test('Test 6 — Modified timestamp: tampering after signing causes verification failure', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-006',
        timestamp: 1727800000000,
      );

      final tamperedRequest = KeyRequestPacket(
        protocolVersion: request.protocolVersion,
        requestId: request.requestId,
        originId: request.originId,
        destinationId: request.destinationId,
        timestamp: 1727800099999, // Tampered timestamp
        identityPublicKey: request.identityPublicKey,
        ephemeralPublicKey: request.ephemeralPublicKey,
        signature: request.signature,
      );

      expect(
        () => bobHandshake.verifyKeyRequest(tamperedRequest),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 7 — Modified initiator identity key: verification fails', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-007',
      );

      // Generate unrelated Ed25519 identity key
      final unrelatedIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      final unrelatedPk = await unrelatedIdentity.getIdentityPublicKey();

      final tamperedRequest = KeyRequestPacket(
        protocolVersion: request.protocolVersion,
        requestId: request.requestId,
        originId: request.originId,
        destinationId: request.destinationId,
        timestamp: request.timestamp,
        identityPublicKey: unrelatedPk, // Tampered pk_idA
        ephemeralPublicKey: request.ephemeralPublicKey,
        signature: request.signature,
      );

      expect(
        () => bobHandshake.verifyKeyRequest(tamperedRequest),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 8 — Modified initiator ephemeral public key: verification fails', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-008',
      );

      final tamperedEphPk = base64UrlEncode(List.filled(32, 77));

      final tamperedRequest = KeyRequestPacket(
        protocolVersion: request.protocolVersion,
        requestId: request.requestId,
        originId: request.originId,
        destinationId: request.destinationId,
        timestamp: request.timestamp,
        identityPublicKey: request.identityPublicKey,
        ephemeralPublicKey: tamperedEphPk, // Tampered pk_ephA
        signature: request.signature,
      );

      expect(
        () => bobHandshake.verifyKeyRequest(tamperedRequest),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 9 — Valid response signature: B creates response binding pk_idA, pk_ephA, pk_idB, pk_ephB; A verifies successfully', () async {
      // 1. A creates request
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-009',
        timestamp: 1727800000000,
      );

      // 2. B creates response
      final response = await bobHandshake.createKeyResponse(
        request: request,
        timestamp: 1727800001000,
      );

      expect(response.protocolVersion, 2);
      expect(response.requestId, 'REQ-009');
      expect(response.originId, 'ML-DEVICE-B');
      expect(response.destinationId, 'ML-DEVICE-A');
      expect(response.timestamp, 1727800001000);
      expect(response.identityPublicKey, await bobIdentity.getIdentityPublicKey());
      expect(response.signature, isNotEmpty);

      // 3. A verifies response
      final result = await aliceHandshake.verifyKeyResponse(response);
      expect(result.isValid, isTrue);
      expect(result.protocolVersion, 2);
      expect(result.requestId, 'REQ-009');
      expect(result.originId, 'ML-DEVICE-B');
      expect(result.destinationId, 'ML-DEVICE-A');
      expect(base64UrlEncode(result.peerIdentityPublicKey), response.identityPublicKey);
      expect(base64UrlEncode(result.peerEphemeralPublicKey), response.ephemeralPublicKey);
    });

    test('Test 10 — Response transcript tampering: modifying pk_idA causes verification failure', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-010',
      );

      final response = await bobHandshake.createKeyResponse(request: request);

      // Tamper pk_idA by passing an altered expected initiator identity key
      final tamperedPkIdA = Uint8List.fromList(List.filled(32, 99));

      expect(
        () => aliceHandshake.verifyKeyResponse(
          response,
          overrideExpectedInitiatorIdentityKey: tamperedPkIdA,
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          anyOf(HandshakeErrorCode.invalidSignature, HandshakeErrorCode.transcriptMismatch),
        )),
      );
    });

    test('Test 11 — Response ephemeral-key tampering: modifying pk_ephA or pk_ephB causes verification failure', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-011',
      );

      final response = await bobHandshake.createKeyResponse(request: request);

      // 11a: Tamper pk_ephA
      final tamperedPkEphA = Uint8List.fromList(List.filled(32, 88));
      expect(
        () => aliceHandshake.verifyKeyResponse(
          response,
          overrideExpectedInitiatorEphemeralKey: tamperedPkEphA,
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          anyOf(HandshakeErrorCode.invalidSignature, HandshakeErrorCode.transcriptMismatch),
        )),
      );

      // 11b: Tamper pk_ephB on the wire
      final tamperedResponse = KeyResponsePacket(
        protocolVersion: response.protocolVersion,
        requestId: response.requestId,
        originId: response.originId,
        destinationId: response.destinationId,
        timestamp: response.timestamp,
        identityPublicKey: response.identityPublicKey,
        ephemeralPublicKey: base64UrlEncode(List.filled(32, 55)), // Tampered pk_ephB
        signature: response.signature,
        initiatorIdentityPublicKey: response.initiatorIdentityPublicKey,
        initiatorEphemeralPublicKey: response.initiatorEphemeralPublicKey,
      );

      expect(
        () => aliceHandshake.verifyKeyResponse(tamperedResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 12 — Request/response mismatch: response with different requestId is rejected', () async {
      await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-012-EXPECTED',
      );

      final mismatchedResponse = KeyResponsePacket(
        protocolVersion: 2,
        requestId: 'REQ-012-UNKNOWN',
        originId: 'ML-DEVICE-B',
        destinationId: 'ML-DEVICE-A',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        identityPublicKey: await bobIdentity.getIdentityPublicKey(),
        ephemeralPublicKey: base64UrlEncode(List.filled(32, 1)),
        signature: base64UrlEncode(List.filled(64, 2)),
      );

      expect(
        () => aliceHandshake.verifyKeyResponse(mismatchedResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.requestIdMismatch,
        )),
      );
    });

    test('Test 13 — Wrong identity key: verifying B response using unrelated Ed25519 key fails', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-013',
      );

      final response = await bobHandshake.createKeyResponse(request: request);

      // Replace responder identity key with Mallory's key while keeping B's signature
      final malloryIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      final malloryPk = await malloryIdentity.getIdentityPublicKey();

      final alteredResponse = KeyResponsePacket(
        protocolVersion: response.protocolVersion,
        requestId: response.requestId,
        originId: response.originId,
        destinationId: response.destinationId,
        timestamp: response.timestamp,
        identityPublicKey: malloryPk, // Wrong identity key
        ephemeralPublicKey: response.ephemeralPublicKey,
        signature: response.signature,
        initiatorIdentityPublicKey: response.initiatorIdentityPublicKey,
        initiatorEphemeralPublicKey: response.initiatorEphemeralPublicKey,
      );

      expect(
        () => aliceHandshake.verifyKeyResponse(alteredResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    test('Test 14 — Deterministic encoding: encoding same transcript twice yields identical bytes', () {
      final pkIdA = List.filled(32, 10);
      final pkEphA = List.filled(32, 20);
      final pkIdB = List.filled(32, 30);
      final pkEphB = List.filled(32, 40);

      // Request transcript determinism
      final reqBytes1 = HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
        timestamp: 1727800000000,
        requestId: 'REQ-DETERMINISTIC',
        originId: 'NODE-A',
        destinationId: 'NODE-B',
        initiatorIdentityKey: pkIdA,
        initiatorEphemeralKey: pkEphA,
      );

      final reqBytes2 = HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
        timestamp: 1727800000000,
        requestId: 'REQ-DETERMINISTIC',
        originId: 'NODE-A',
        destinationId: 'NODE-B',
        initiatorIdentityKey: pkIdA,
        initiatorEphemeralKey: pkEphA,
      );

      expect(reqBytes1, reqBytes2);

      // Response transcript determinism
      final rspBytes1 = HandshakeTranscriptEncoder.encodeKeyResponseTranscript(
        timestamp: 1727800001000,
        requestId: 'REQ-DETERMINISTIC',
        originId: 'NODE-B',
        destinationId: 'NODE-A',
        initiatorIdentityKey: pkIdA,
        initiatorEphemeralKey: pkEphA,
        responderIdentityKey: pkIdB,
        responderEphemeralKey: pkEphB,
      );

      final rspBytes2 = HandshakeTranscriptEncoder.encodeKeyResponseTranscript(
        timestamp: 1727800001000,
        requestId: 'REQ-DETERMINISTIC',
        originId: 'NODE-B',
        destinationId: 'NODE-A',
        initiatorIdentityKey: pkIdA,
        initiatorEphemeralKey: pkEphA,
        responderIdentityKey: pkIdB,
        responderEphemeralKey: pkEphB,
      );

      expect(rspBytes1, rspBytes2);
    });

    test('Test 15 — Length validation: oversized variable-length fields are rejected', () {
      final validKey = List.filled(32, 1);
      final oversizedId = 'A' * 256; // Max is 255

      expect(
        () => HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
          timestamp: 1727800000000,
          requestId: oversizedId,
          originId: 'NODE-A',
          destinationId: 'NODE-B',
          initiatorIdentityKey: validKey,
          initiatorEphemeralKey: validKey,
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidEncoding,
        )),
      );

      expect(
        () => HandshakeTranscriptEncoder.encodeKeyResponseTranscript(
          timestamp: 1727800000000,
          requestId: 'REQ-VALID',
          originId: oversizedId,
          destinationId: 'NODE-B',
          initiatorIdentityKey: validKey,
          initiatorEphemeralKey: validKey,
          responderIdentityKey: validKey,
          responderEphemeralKey: validKey,
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidEncoding,
        )),
      );
    });

    test('Test 16 — Legacy compatibility: existing MeshCryptoService tests and X25519 operations remain completely unchanged', () async {
      final aliceCrypto = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
      final bobCrypto = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());

      aliceCrypto.rememberPeerKey('bob', await bobCrypto.localPublicKey());
      bobCrypto.rememberPeerKey('alice', await aliceCrypto.localPublicKey());

      final encrypted = await aliceCrypto.encrypt(
        messageId: 'msg-phase7-compat',
        originId: 'alice',
        destinationId: 'bob',
        text: 'MeshLink legacy compatibility preserved',
      );

      final decrypted = await bobCrypto.decrypt(
        messageId: 'msg-phase7-compat',
        originId: 'alice',
        destinationId: 'bob',
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
        mac: encrypted.mac,
      );

      expect(decrypted, 'MeshLink legacy compatibility preserved');
    });

    test('Test 17 — Known peer identity key change detection (PeerIdentitiesTable integration)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = DriftMessageRepository(db);
      addTearDown(() => db.close());

      final now = DateTime.utc(2026, 10, 1, 10, 0, 0);

      // Store Bob's original known identity key in the database
      final originalBobIdentityKey = await bobIdentity.getIdentityPublicKey();
      await repository.savePeerIdentity(PeerIdentityEntry(
        peerId: 'ML-DEVICE-B',
        identityPublicKey: originalBobIdentityKey,
        safetyNumber: '123456',
        trustStatus: 'tofu_unverified',
        protocolVersion: 2,
        firstSeenAt: now,
        lastSeenAt: now,
      ));

      // Alice handshake configured with repository
      final aliceWithRepo = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ML-DEVICE-A',
        peerRepository: repository,
      );

      final request = await aliceWithRepo.createKeyRequest(destinationId: 'ML-DEVICE-B');

      // Bob responds with his original key -> Alice accepts
      final validResponse = await bobHandshake.createKeyResponse(request: request);
      final verifiedResult = await aliceWithRepo.verifyKeyResponse(validResponse);
      expect(verifiedResult.isValid, isTrue);

      // Now simulate Bob's key changing (new key pair from Mallory or compromised device)
      final rogueBobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      final rogueBobHandshake = HandshakeService(
        identityService: rogueBobIdentity,
        localId: 'ML-DEVICE-B',
      );

      final newRequest = await aliceWithRepo.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-KEY-CHANGE',
      );

      final rogueResponse = await rogueBobHandshake.createKeyResponse(request: newRequest);

      // Alice must detect the mismatch against stored repository and reject!
      expect(
        () => aliceWithRepo.verifyKeyResponse(rogueResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.peerIdentityMismatch,
        )),
      );

      // Stored repository record must remain untouched
      final storedBob = await repository.getPeerIdentity('ML-DEVICE-B');
      expect(storedBob!.identityPublicKey, originalBobIdentityKey);
    });

    test('Test 18 — JSON wire protocol serialization and deserialization round trip', () async {
      final req = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-SERIALIZE',
      );

      final jsonReq = req.toJson();
      final parsedReq = KeyRequestPacket.fromJson(jsonReq);
      expect(parsedReq.protocolVersion, req.protocolVersion);
      expect(parsedReq.requestId, req.requestId);
      expect(parsedReq.originId, req.originId);
      expect(parsedReq.destinationId, req.destinationId);
      expect(parsedReq.timestamp, req.timestamp);
      expect(parsedReq.identityPublicKey, req.identityPublicKey);
      expect(parsedReq.ephemeralPublicKey, req.ephemeralPublicKey);
      expect(parsedReq.signature, req.signature);

      final resp = await bobHandshake.createKeyResponse(request: req);
      final jsonResp = resp.toJson();
      final parsedResp = KeyResponsePacket.fromJson(jsonResp);
      expect(parsedResp.protocolVersion, resp.protocolVersion);
      expect(parsedResp.requestId, resp.requestId);
      expect(parsedResp.originId, resp.originId);
      expect(parsedResp.destinationId, resp.destinationId);
      expect(parsedResp.timestamp, resp.timestamp);
      expect(parsedResp.identityPublicKey, resp.identityPublicKey);
      expect(parsedResp.ephemeralPublicKey, resp.ephemeralPublicKey);
      expect(parsedResp.signature, resp.signature);
      expect(parsedResp.initiatorIdentityPublicKey, req.identityPublicKey);
      expect(parsedResp.initiatorEphemeralPublicKey, req.ephemeralPublicKey);
    });
  });
}
