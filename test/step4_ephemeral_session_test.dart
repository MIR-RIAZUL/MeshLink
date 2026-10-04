import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7 Step 4: Ephemeral Session Establishment', () {
    late MeshIdentityService aliceIdentity;
    late MeshIdentityService bobIdentity;
    late MeshIdentityService charlieIdentity;
    late EphemeralSessionService aliceSessionService;
    late EphemeralSessionService bobSessionService;
    late EphemeralSessionService charlieSessionService;
    late HandshakeService aliceHandshake;
    late HandshakeService bobHandshake;
    late HandshakeService charlieHandshake;

    setUp(() async {
      aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      charlieIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());

      await aliceIdentity.initialize();
      await bobIdentity.initialize();
      await charlieIdentity.initialize();

      aliceSessionService = EphemeralSessionService();
      bobSessionService = EphemeralSessionService();
      charlieSessionService = EphemeralSessionService();

      aliceHandshake = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ML-DEVICE-A',
        sessionService: aliceSessionService,
      );

      bobHandshake = HandshakeService(
        identityService: bobIdentity,
        localId: 'ML-DEVICE-B',
        sessionService: bobSessionService,
      );

      charlieHandshake = HandshakeService(
        identityService: charlieIdentity,
        localId: 'ML-DEVICE-C',
        sessionService: charlieSessionService,
      );
    });

    // ── Test 1 — Real X25519 key generation ──
    test('Test 1 — Real X25519 key generation produces valid 32-byte key pairs', () async {
      final keyPair = await aliceSessionService.generateEphemeralKeyPair(requestId: 'REQ-TEST-1');

      expect(keyPair.type, KeyPairType.x25519);
      expect(keyPair.publicKey.bytes.length, 32, reason: 'Public key must be 32 bytes');
      expect(keyPair.bytes.length, 32, reason: 'Private key seed must be 32 bytes');
      expect(keyPair.publicKey.bytes, isNot(equals(Uint8List(32))), reason: 'Public key cannot be all zeros');
      expect(keyPair.bytes, isNot(equals(Uint8List(32))), reason: 'Private key cannot be all zeros');

      // EphemeralKeyProvider interface returns matching bytes
      final pubBytes = await aliceSessionService.getEphemeralPublicKey(requestId: 'REQ-TEST-1');
      expect(pubBytes, Uint8List.fromList(keyPair.publicKey.bytes));
      expect(pubBytes.length, 32);
    });

    // ── Test 2 — Fresh ephemeral key per handshake ──
    test('Test 2 — Fresh ephemeral key per handshake: keys are unique and not reused', () async {
      final req1 = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-FRESH-1',
      );

      final req2 = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-FRESH-2',
      );

      expect(req1.ephemeralPublicKey, isNot(equals(req2.ephemeralPublicKey)),
          reason: 'Every handshake must generate a fresh, distinct X25519 ephemeral key pair');

      final pub1 = base64Url.decode(req1.ephemeralPublicKey);
      final pub2 = base64Url.decode(req2.ephemeralPublicKey);
      expect(pub1.length, 32);
      expect(pub2.length, 32);
      expect(pub1, isNot(equals(pub2)));
    });

    // ── Test 3 — X25519 shared-secret agreement ──
    test('Test 3 — X25519 shared-secret agreement: DH(A_priv, B_pub) == DH(B_priv, A_pub)', () async {
      final kpA = await aliceSessionService.generateEphemeralKeyPair(requestId: 'REQ-DH-1');
      final kpB = await bobSessionService.generateEphemeralKeyPair(requestId: 'REQ-DH-1');

      final aliceIdBytes = await aliceIdentity.getIdentityPublicKeyBytes();
      final bobIdBytes = await bobIdentity.getIdentityPublicKeyBytes();

      // Alice computes DH with Bob's ephemeral public key
      final sessionA = await aliceSessionService.establishSession(
        requestId: 'REQ-DH-1',
        localId: 'ML-DEVICE-A',
        peerId: 'ML-DEVICE-B',
        isInitiator: true,
        peerEphemeralPublicKey: kpB.publicKey.bytes,
        localIdentityPublicKey: aliceIdBytes,
        peerIdentityPublicKey: bobIdBytes,
        localKeyPair: kpA,
      );

      // Bob computes DH with Alice's ephemeral public key
      final sessionB = await bobSessionService.establishSession(
        requestId: 'REQ-DH-1',
        localId: 'ML-DEVICE-B',
        peerId: 'ML-DEVICE-A',
        isInitiator: false,
        peerEphemeralPublicKey: kpA.publicKey.bytes,
        localIdentityPublicKey: bobIdBytes,
        peerIdentityPublicKey: aliceIdBytes,
        localKeyPair: kpB,
      );

      expect(sessionA.sharedSecret.length, 32, reason: 'X25519 shared secret must be 32 bytes');
      expect(sessionB.sharedSecret.length, 32, reason: 'X25519 shared secret must be 32 bytes');
      expect(sessionA.sharedSecret, equals(sessionB.sharedSecret),
          reason: 'Both sides must compute the identical shared secret');
      expect(
        EphemeralSession.constantTimeCompare(sessionA.sharedSecret, sessionB.sharedSecret),
        isTrue,
        reason: 'Constant-time comparison must confirm equality',
      );
    });

    // ── Test 4 — Full Step 3 + Step 4 handshake ──
    test('Test 4 — Full Step 3 + Step 4 handshake establishes matching ephemeral sessions', () async {
      // 1. A creates key_request
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-FULL-001',
        timestamp: 1728000000000,
      );

      expect(request.protocolVersion, 2);
      expect(request.ephemeralPublicKey.length, greaterThan(0));
      expect(request.signature.length, greaterThan(0));

      // 2. B verifies request
      final verifiedReq = await bobHandshake.verifyKeyRequest(request);
      expect(verifiedReq.isValid, isTrue);

      // 3. B creates key_response
      final response = await bobHandshake.createKeyResponse(
        request: request,
        timestamp: 1728000001000,
      );

      expect(response.protocolVersion, 2);
      expect(response.requestId, 'REQ-FULL-001');

      // 4. B derives shared secret and completes session as responder
      final sessionB = await bobHandshake.completeSessionAsResponder(
        verifiedRequest: verifiedReq,
      );

      // 5. A verifies response
      final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
      expect(verifiedResp.isValid, isTrue);

      // 6. A derives shared secret and completes session as initiator
      final sessionA = await aliceHandshake.completeSessionAsInitiator(
        verifiedResponse: verifiedResp,
      );

      // Verify sessions are established on both sides
      expect(sessionA.isInitiator, isTrue);
      expect(sessionB.isInitiator, isFalse);
      expect(sessionA.peerId, 'ML-DEVICE-B');
      expect(sessionB.peerId, 'ML-DEVICE-A');
      expect(sessionA.requestId, 'REQ-FULL-001');
      expect(sessionB.requestId, 'REQ-FULL-001');

      // Shared secret agreement: secretA == secretB
      expect(sessionA.sharedSecret.length, 32);
      expect(sessionB.sharedSecret.length, 32);
      expect(sessionA.sharedSecret, equals(sessionB.sharedSecret),
          reason: 'secretA == secretB');
      expect(
        EphemeralSession.constantTimeCompare(sessionA.sharedSecret, sessionB.sharedSecret),
        isTrue,
      );

      // Session IDs must match across peers for the same handshake
      expect(sessionA.sessionId, equals(sessionB.sessionId));
      expect(sessionA.sessionId, startsWith('SESSION-REQ-FULL-001-'));

      // Both handshake services report active sessions
      expect(aliceHandshake.getActiveSession('ML-DEVICE-B'), isNotNull);
      expect(bobHandshake.getActiveSession('ML-DEVICE-A'), isNotNull);
    });

    // ── Test 5 — Tampered responder ephemeral key ──
    test('Test 5 — Tampered responder ephemeral key fails signature verification with no session', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-TAMPER-EPH-1',
      );

      await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);

      // Mallory alters Bob's ephemeral public key
      final alteredEphKeyBytes = Uint8List(32)..fillRange(0, 32, 0x42);
      final tamperedResponse = KeyResponsePacket(
        protocolVersion: response.protocolVersion,
        requestId: response.requestId,
        originId: response.originId,
        destinationId: response.destinationId,
        timestamp: response.timestamp,
        identityPublicKey: response.identityPublicKey,
        ephemeralPublicKey: base64UrlEncode(alteredEphKeyBytes),
        signature: response.signature,
        initiatorIdentityPublicKey: response.initiatorIdentityPublicKey,
        initiatorEphemeralPublicKey: response.initiatorEphemeralPublicKey,
      );

      await expectLater(
        aliceHandshake.verifyKeyResponse(tamperedResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );

      // Alice must have NO active session and pending request must be cleaned up
      expect(aliceHandshake.getActiveSession('ML-DEVICE-B'), isNull);
      expect(aliceSessionService.getSession('ML-DEVICE-B'), isNull);
      expect(aliceHandshake.getPendingRequest('REQ-TAMPER-EPH-1'), isNull);
    });

    // ── Test 6 — Tampered request ID ──
    test('Test 6 — Tampered request ID results in no session and clean state', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-ORIGINAL-ID',
      );

      await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);

      // Response with mismatched requestId
      final tamperedResponse = KeyResponsePacket(
        protocolVersion: response.protocolVersion,
        requestId: 'REQ-FORGED-ID',
        originId: response.originId,
        destinationId: response.destinationId,
        timestamp: response.timestamp,
        identityPublicKey: response.identityPublicKey,
        ephemeralPublicKey: response.ephemeralPublicKey,
        signature: response.signature,
      );

      await expectLater(
        aliceHandshake.verifyKeyResponse(tamperedResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.requestIdMismatch,
        )),
      );

      expect(aliceHandshake.getActiveSession('ML-DEVICE-B'), isNull);
      expect(aliceSessionService.hasSession('ML-DEVICE-B'), isFalse);
    });

    // ── Test 7 — Wrong peer identity ──
    test('Test 7 — Wrong peer identity key causes verification failure and no session', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftMessageRepository(db);

      // Alice records Bob with a known identity
      final bobRealPub = await bobIdentity.getIdentityPublicKey();
      await repo.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-DEVICE-B',
          identityPublicKey: bobRealPub,
          safetyNumber: '123456',
          trustStatus: 'tofu_unverified',
          protocolVersion: 2,
          firstSeenAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
        ),
      );

      final aliceWithRepo = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ML-DEVICE-A',
        peerRepository: repo,
        sessionService: aliceSessionService,
      );

      final request = await aliceWithRepo.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-WRONG-ID-1',
      );

      // Impostor Eve responds claiming to be Bob but with Eve's identity
      final eveIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      await eveIdentity.initialize();
      final eveHandshake = HandshakeService(
        identityService: eveIdentity,
        localId: 'ML-DEVICE-B', // Impersonating Bob
      );

      final eveResponse = await eveHandshake.createKeyResponse(request: request);

      // Alice verifies against repo and rejects the key mismatch
      await expectLater(
        aliceWithRepo.verifyKeyResponse(eveResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.peerIdentityMismatch,
        )),
      );

      expect(aliceWithRepo.getActiveSession('ML-DEVICE-B'), isNull);
      await db.close();
    });

    // ── Test 8 — Invalid X25519 public key lengths ──
    test('Test 8 — Invalid X25519 public key lengths (empty, 31 bytes, 33 bytes) are rejected', () async {
      final aliceIdBytes = await aliceIdentity.getIdentityPublicKeyBytes();
      final bobIdBytes = await bobIdentity.getIdentityPublicKeyBytes();
      await aliceSessionService.generateEphemeralKeyPair(requestId: 'REQ-LEN-TEST');

      // Empty key
      await expectLater(
        aliceSessionService.establishSession(
          requestId: 'REQ-LEN-TEST',
          localId: 'ML-DEVICE-A',
          peerId: 'ML-DEVICE-B',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List(0),
          localIdentityPublicKey: aliceIdBytes,
          peerIdentityPublicKey: bobIdBytes,
        ),
        throwsA(isA<EphemeralSessionException>().having(
          (e) => e.message,
          'message',
          contains('must be 32 bytes (got 0)'),
        )),
      );

      // 31 bytes
      await expectLater(
        aliceSessionService.establishSession(
          requestId: 'REQ-LEN-TEST',
          localId: 'ML-DEVICE-A',
          peerId: 'ML-DEVICE-B',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List(31),
          localIdentityPublicKey: aliceIdBytes,
          peerIdentityPublicKey: bobIdBytes,
        ),
        throwsA(isA<EphemeralSessionException>().having(
          (e) => e.message,
          'message',
          contains('must be 32 bytes (got 31)'),
        )),
      );

      // 33 bytes
      await expectLater(
        aliceSessionService.establishSession(
          requestId: 'REQ-LEN-TEST',
          localId: 'ML-DEVICE-A',
          peerId: 'ML-DEVICE-B',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List(33),
          localIdentityPublicKey: aliceIdBytes,
          peerIdentityPublicKey: bobIdBytes,
        ),
        throwsA(isA<EphemeralSessionException>().having(
          (e) => e.message,
          'message',
          contains('must be 32 bytes (got 33)'),
        )),
      );
    });

    // ── Test 9 — Failed handshake leaves no session ──
    test('Test 9 — Failed handshake leaves no active session and cleans up pending material', () async {
      await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-FAIL-CLEAN-1',
      );

      expect(aliceHandshake.getPendingRequest('REQ-FAIL-CLEAN-1'), isNotNull);
      expect(aliceSessionService.hasPendingKeyPair('REQ-FAIL-CLEAN-1'), isTrue);

      // Malformed signature response
      final invalidResponse = KeyResponsePacket(
        protocolVersion: 2,
        requestId: 'REQ-FAIL-CLEAN-1',
        originId: 'ML-DEVICE-B',
        destinationId: 'ML-DEVICE-A',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        identityPublicKey: await bobIdentity.getIdentityPublicKey(),
        ephemeralPublicKey: base64UrlEncode(Uint8List(32)),
        signature: base64UrlEncode(Uint8List(64)), // Bogus signature
      );

      await expectLater(
        aliceHandshake.verifyKeyResponse(invalidResponse),
        throwsA(isA<HandshakeException>()),
      );

      // Active session must be null
      expect(aliceHandshake.getActiveSession('ML-DEVICE-B'), isNull);
      expect(aliceSessionService.activeSession, isNull);
      expect(aliceSessionService.hasSession('ML-DEVICE-B'), isFalse);

      // Pending state must be removed
      expect(aliceHandshake.getPendingRequest('REQ-FAIL-CLEAN-1'), isNull);
      expect(aliceSessionService.hasPendingKeyPair('REQ-FAIL-CLEAN-1'), isFalse);
    });

    // ── Test 10 — Session teardown ──
    test('Test 10 — Session teardown destroys session and prevents reuse', () async {
      // Establish session
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-TEARDOWN-1',
      );
      final verifiedReq = await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);
      await bobHandshake.completeSessionAsResponder(verifiedRequest: verifiedReq);
      final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
      final session = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: verifiedResp);

      expect(aliceHandshake.getActiveSession('ML-DEVICE-B'), isNotNull);
      expect(aliceSessionService.hasSession('ML-DEVICE-B'), isTrue);
      expect(session.isDestroyed, isFalse);

      // Destroy session
      aliceHandshake.clearSession('ML-DEVICE-B');

      // Verify session no longer exists
      expect(aliceHandshake.getActiveSession('ML-DEVICE-B'), isNull);
      expect(aliceSessionService.hasSession('ML-DEVICE-B'), isFalse);
      expect(aliceSessionService.getSession('ML-DEVICE-B'), isNull);
      expect(aliceSessionService.getSessionById(session.sessionId), isNull);
      expect(session.isDestroyed, isTrue);
    });

    // ── Test 11 — New session after teardown ──
    test('Test 11 — New session after teardown produces fresh sessionId and ephemeral keys', () async {
      // Handshake 1
      final req1 = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-TD-NEW-1',
      );
      final vReq1 = await bobHandshake.verifyKeyRequest(req1);
      final resp1 = await bobHandshake.createKeyResponse(request: req1);
      final bSess1 = await bobHandshake.completeSessionAsResponder(verifiedRequest: vReq1);
      final vResp1 = await aliceHandshake.verifyKeyResponse(resp1);
      final aSess1 = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: vResp1);

      // Teardown both sides
      aliceHandshake.clearSession('ML-DEVICE-B');
      bobHandshake.clearSession('ML-DEVICE-A');

      // Handshake 2
      final req2 = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-TD-NEW-2',
      );
      final vReq2 = await bobHandshake.verifyKeyRequest(req2);
      final resp2 = await bobHandshake.createKeyResponse(request: req2);
      final bSess2 = await bobHandshake.completeSessionAsResponder(verifiedRequest: vReq2);
      final vResp2 = await aliceHandshake.verifyKeyResponse(resp2);
      final aSess2 = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: vResp2);

      // Session IDs must differ
      expect(aSess1.sessionId, isNot(equals(aSess2.sessionId)));
      expect(bSess1.sessionId, isNot(equals(bSess2.sessionId)));

      // Ephemeral keys must differ
      expect(aSess1.localEphemeralPublicKey, isNot(equals(aSess2.localEphemeralPublicKey)));
      expect(bSess1.localEphemeralPublicKey, isNot(equals(bSess2.localEphemeralPublicKey)));

      // Shared secrets must differ
      expect(aSess1.sharedSecret, isNot(equals(aSess2.sharedSecret)));
    });

    // ── Test 12 — Peer isolation ──
    test('Test 12 — Peer isolation: independent sessions A ↔ B and A ↔ C do not leak secrets or keys', () async {
      // 1. A ↔ B handshake
      final reqAB = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-ISO-AB',
      );
      final vReqAB = await bobHandshake.verifyKeyRequest(reqAB);
      final respAB = await bobHandshake.createKeyResponse(request: reqAB);
      final sessB = await bobHandshake.completeSessionAsResponder(verifiedRequest: vReqAB);
      final vRespAB = await aliceHandshake.verifyKeyResponse(respAB);
      final sessAB = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: vRespAB);

      // 2. A ↔ C handshake
      final reqAC = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-C',
        requestId: 'REQ-ISO-AC',
      );
      final vReqAC = await charlieHandshake.verifyKeyRequest(reqAC);
      final respAC = await charlieHandshake.createKeyResponse(request: reqAC);
      final sessC = await charlieHandshake.completeSessionAsResponder(verifiedRequest: vReqAC);
      final vRespAC = await aliceHandshake.verifyKeyResponse(respAC);
      final sessAC = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: vRespAC);

      // Peers are distinct
      expect(sessAB.peerId, 'ML-DEVICE-B');
      expect(sessAC.peerId, 'ML-DEVICE-C');
      expect(sessAB.peerId, isNot(equals(sessAC.peerId)));

      // Secrets are completely independent
      expect(sessAB.sharedSecret, isNot(equals(sessAC.sharedSecret)));
      expect(sessAB.sessionId, isNot(equals(sessAC.sessionId)));
      expect(sessAB.localEphemeralPublicKey, isNot(equals(sessAC.localEphemeralPublicKey)));

      // Matching verification
      expect(sessAB.sharedSecret, equals(sessB.sharedSecret));
      expect(sessAC.sharedSecret, equals(sessC.sharedSecret));
    });

    // ── Test 13 — Concurrent handshakes ──
    test('Test 13 — Concurrent handshakes: multiple in-flight requests retain correct ephemeral private keys', () async {
      // Alice initiates two handshakes to Bob concurrently
      final req1 = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-CONCURRENT-1',
      );
      final req2 = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-CONCURRENT-2',
      );

      // Both pending requests exist simultaneously in memory
      expect(aliceSessionService.hasPendingKeyPair('REQ-CONCURRENT-1'), isTrue);
      expect(aliceSessionService.hasPendingKeyPair('REQ-CONCURRENT-2'), isTrue);
      expect(aliceSessionService.pendingKeyPairsCount, greaterThanOrEqualTo(2));

      // Bob verifies and responds to both
      final vReq1 = await bobHandshake.verifyKeyRequest(req1);
      final vReq2 = await bobHandshake.verifyKeyRequest(req2);

      final resp1 = await bobHandshake.createKeyResponse(request: req1);
      final resp2 = await bobHandshake.createKeyResponse(request: req2);

      final bobSess1 = await bobHandshake.completeSessionAsResponder(verifiedRequest: vReq1);
      final bobSess2 = await bobHandshake.completeSessionAsResponder(verifiedRequest: vReq2);

      // Alice verifies responses out of order (2 then 1) to test correlation isolation
      final vResp2 = await aliceHandshake.verifyKeyResponse(resp2);
      final vResp1 = await aliceHandshake.verifyKeyResponse(resp1);

      final aliceSess2 = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: vResp2);
      final aliceSess1 = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: vResp1);

      // Both sessions derive the correct matching shared secrets for their respective request IDs
      expect(aliceSess1.sharedSecret, equals(bobSess1.sharedSecret));
      expect(aliceSess2.sharedSecret, equals(bobSess2.sharedSecret));

      // Secrets between the two concurrent handshakes are distinct
      expect(aliceSess1.sharedSecret, isNot(equals(aliceSess2.sharedSecret)));
      expect(aliceSess1.sessionId, isNot(equals(aliceSess2.sessionId)));
    });

    // ── Test 14 — No persistence of session secrets ──
    test('Test 14 — No persistence of session secrets: private keys and shared secrets are never stored', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftMessageRepository(db);

      final aliceWithDb = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ML-DEVICE-A',
        peerRepository: repo,
        sessionService: aliceSessionService,
      );

      // Establish session
      final request = await aliceWithDb.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-NO-PERSIST-1',
      );
      final vReq = await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);
      await bobHandshake.completeSessionAsResponder(verifiedRequest: vReq);
      final vResp = await aliceWithDb.verifyKeyResponse(response);
      final session = await aliceWithDb.completeSessionAsInitiator(verifiedResponse: vResp);

      // Inspect SQLite database tables
      final peerIdentities = await db.select(db.peerIdentitiesTable).get();
      final messages = await db.select(db.messagesTable).get();
      final seenPackets = await db.select(db.seenPacketsTable).get();

      // Messages table and seenPackets table are clean
      expect(messages, isEmpty);
      expect(seenPackets, isEmpty);

      // Verify that secret bytes do not appear in peerIdentitiesTable
      final secretBase64 = base64UrlEncode(session.sharedSecret);
      for (final p in peerIdentities) {
        expect(p.identityPublicKey, isNot(contains(secretBase64)));
      }

      await db.close();
    });

    // ── Test 15 — Existing Step 3 regression ──
    test('Test 15 — Existing Step 3 regression: authenticated Ed25519 handshake operates cleanly', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-STEP3-REG',
        timestamp: 1728050000000,
      );

      expect(request.protocolVersion, 2);
      expect(request.originId, 'ML-DEVICE-A');
      expect(request.destinationId, 'ML-DEVICE-B');
      expect(request.identityPublicKey, await aliceIdentity.getIdentityPublicKey());

      final vReq = await bobHandshake.verifyKeyRequest(request);
      expect(vReq.isValid, isTrue);

      final response = await bobHandshake.createKeyResponse(
        request: request,
        timestamp: 1728050001000,
      );

      expect(response.protocolVersion, 2);
      expect(response.originId, 'ML-DEVICE-B');
      expect(response.destinationId, 'ML-DEVICE-A');
      expect(response.identityPublicKey, await bobIdentity.getIdentityPublicKey());

      final vResp = await aliceHandshake.verifyKeyResponse(response);
      expect(vResp.isValid, isTrue);
    });

    // ── Test 16 — Existing encryption regression ──
    test('Test 16 — Existing encryption regression: MeshCryptoService operates independently and unchanged', () async {
      final aliceCrypto = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
      final bobCrypto = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());

      final alicePub = await aliceCrypto.localPublicKey();
      final bobPub = await bobCrypto.localPublicKey();

      aliceCrypto.rememberPeerKey('ML-BOB', bobPub);
      bobCrypto.rememberPeerKey('ML-ALICE', alicePub);

      final encrypted = await aliceCrypto.encrypt(
        messageId: 'MSG-001',
        originId: 'ML-ALICE',
        destinationId: 'ML-BOB',
        text: 'Hello MeshLink!',
      );

      final decrypted = await bobCrypto.decrypt(
        messageId: 'MSG-001',
        originId: 'ML-ALICE',
        destinationId: 'ML-BOB',
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
        mac: encrypted.mac,
      );

      expect(decrypted, 'Hello MeshLink!');
    });

    // ── Test 17 (Section 20) — Ephemeral key substitution security test ──
    test('Test 17 — Security Test: Ephemeral key substitution fails Ed25519 signature and prevents session', () async {
      // Alice creates signed key_request
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-SEC-SUBST',
      );

      // Bob verifies and creates signed key_response
      await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);

      // Attacker intercepts and substitutes Bob's ephemeral public key with attacker's key
      final attackerAlgorithm = X25519();
      final attackerKp = await attackerAlgorithm.newKeyPair();
      final attackerPub = await attackerKp.extractPublicKey();

      final substitutedResponse = KeyResponsePacket(
        protocolVersion: response.protocolVersion,
        requestId: response.requestId,
        originId: response.originId,
        destinationId: response.destinationId,
        timestamp: response.timestamp,
        identityPublicKey: response.identityPublicKey,
        ephemeralPublicKey: base64UrlEncode(attackerPub.bytes), // Substituted key!
        signature: response.signature,                          // Original Bob signature
        initiatorIdentityPublicKey: response.initiatorIdentityPublicKey,
        initiatorEphemeralPublicKey: response.initiatorEphemeralPublicKey,
      );

      // Alice's signature verification must reject the substituted ephemeral key
      await expectLater(
        aliceHandshake.verifyKeyResponse(substitutedResponse),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );

      // Confirm X25519 session is NOT established
      expect(aliceHandshake.getActiveSession('ML-DEVICE-B'), isNull);
      expect(aliceSessionService.hasSession('ML-DEVICE-B'), isFalse);
    });

    // ── Additional Test: Session binding verification ──
    test('Test 18 — Session binding: matchesBinding validates identity and ephemeral keys', () async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-BINDING-1',
      );
      final vReq = await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);
      await bobHandshake.completeSessionAsResponder(verifiedRequest: vReq);
      final vResp = await aliceHandshake.verifyKeyResponse(response);
      final session = await aliceHandshake.completeSessionAsInitiator(verifiedResponse: vResp);

      final aliceIdBytes = await aliceIdentity.getIdentityPublicKeyBytes();
      final bobIdBytes = await bobIdentity.getIdentityPublicKeyBytes();

      // Valid binding
      expect(
        session.matchesBinding(
          expectedRequestId: 'REQ-BINDING-1',
          expectedLocalIdentityKey: aliceIdBytes,
          expectedPeerIdentityKey: bobIdBytes,
          expectedLocalEphemeralKey: session.localEphemeralPublicKey,
          expectedPeerEphemeralKey: session.peerEphemeralPublicKey,
        ),
        isTrue,
      );

      // Wrong request ID
      expect(
        session.matchesBinding(
          expectedRequestId: 'REQ-WRONG',
          expectedLocalIdentityKey: aliceIdBytes,
          expectedPeerIdentityKey: bobIdBytes,
          expectedLocalEphemeralKey: session.localEphemeralPublicKey,
          expectedPeerEphemeralKey: session.peerEphemeralPublicKey,
        ),
        isFalse,
      );

      // Wrong peer identity key
      expect(
        session.matchesBinding(
          expectedRequestId: 'REQ-BINDING-1',
          expectedLocalIdentityKey: aliceIdBytes,
          expectedPeerIdentityKey: Uint8List(32),
          expectedLocalEphemeralKey: session.localEphemeralPublicKey,
          expectedPeerEphemeralKey: session.peerEphemeralPublicKey,
        ),
        isFalse,
      );
    });

    // ── Additional Test: Clear pending requests ──
    test('Test 19 — clearPendingRequest clears both pending handshake and ephemeral key material', () async {
      await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-CLR-1',
      );

      expect(aliceHandshake.getPendingRequest('REQ-CLR-1'), isNotNull);
      expect(aliceSessionService.hasPendingKeyPair('REQ-CLR-1'), isTrue);

      aliceHandshake.clearPendingRequest('REQ-CLR-1');

      expect(aliceHandshake.getPendingRequest('REQ-CLR-1'), isNull);
      expect(aliceSessionService.hasPendingKeyPair('REQ-CLR-1'), isFalse);
    });
  });
}
