import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 4: Ephemeral X25519 Session Establishment', () {
    // ── EphemeralSessionService Unit Tests ──

    group('EphemeralSessionService — Key Pair Generation', () {
      late EphemeralSessionService service;

      setUp(() {
        service = EphemeralSessionService();
      });

      test('Test 1 — generateEphemeralKeyPair produces valid 32-byte X25519 key pair', () async {
        final keyPair = await service.generateEphemeralKeyPair();

        expect(keyPair.bytes.length, 32, reason: 'Private key seed must be 32 bytes');
        expect(keyPair.publicKey.bytes.length, 32, reason: 'Public key must be 32 bytes');
        expect(keyPair.type, KeyPairType.x25519);
      });

      test('Test 2 — getEphemeralPublicKey returns current key pair public key', () async {
        final keyPair = await service.generateEphemeralKeyPair();
        final pubKey = await service.getEphemeralPublicKey();

        expect(pubKey, Uint8List.fromList(keyPair.publicKey.bytes));
        expect(pubKey.length, 32);
      });

      test('Test 3 — getEphemeralPublicKey auto-generates if no key pair exists', () async {
        // No explicit generateEphemeralKeyPair call
        final pubKey = await service.getEphemeralPublicKey();

        expect(pubKey.length, 32);
        expect(pubKey, isNot(Uint8List(32)), reason: 'Should not be all zeros');
      });

      test('Test 4 — Successive generateEphemeralKeyPair calls produce distinct key pairs', () async {
        final kp1 = await service.generateEphemeralKeyPair();
        final kp2 = await service.generateEphemeralKeyPair();

        expect(
          kp1.publicKey.bytes,
          isNot(equals(kp2.publicKey.bytes)),
          reason: 'Each call must generate a fresh random key pair',
        );
      });
    });

    group('EphemeralSessionService — Session Derivation', () {
      late EphemeralSessionService aliceSession;
      late EphemeralSessionService bobSession;
      late MeshIdentityService aliceIdentity;
      late MeshIdentityService bobIdentity;

      setUp(() async {
        aliceSession = EphemeralSessionService();
        bobSession = EphemeralSessionService();
        aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        await aliceIdentity.initialize();
        await bobIdentity.initialize();
      });

      test('Test 5 — Symmetric session derivation: both sides derive identical keys', () async {
        // Alice generates her ephemeral key pair
        final aliceEphKp = await aliceSession.generateEphemeralKeyPair();
        final aliceEphPub = Uint8List.fromList(aliceEphKp.publicKey.bytes);

        // Bob generates his ephemeral key pair
        final bobEphKp = await bobSession.generateEphemeralKeyPair();
        final bobEphPub = Uint8List.fromList(bobEphKp.publicKey.bytes);

        final aliceIdPub = await aliceIdentity.getIdentityPublicKeyBytes();
        final bobIdPub = await bobIdentity.getIdentityPublicKeyBytes();

        // Alice derives session as initiator
        final aliceResult = await aliceSession.deriveSessionKeys(
          requestId: 'REQ-SYM-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: bobEphPub,
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
        );

        // Bob derives session as responder
        final bobResult = await bobSession.deriveSessionKeys(
          requestId: 'REQ-SYM-001',
          localId: 'ML-BOB',
          peerId: 'ML-ALICE',
          isInitiator: false,
          peerEphemeralPublicKey: aliceEphPub,
          localIdentityPublicKey: bobIdPub,
          peerIdentityPublicKey: aliceIdPub,
        );

        // Both must derive the same directional keys
        expect(aliceResult.initiatorToResponderKey, bobResult.initiatorToResponderKey,
            reason: 'initiator→responder key must match');
        expect(aliceResult.responderToInitiatorKey, bobResult.responderToInitiatorKey,
            reason: 'responder→initiator key must match');

        // Directional keys must be different from each other
        expect(aliceResult.initiatorToResponderKey,
            isNot(equals(aliceResult.responderToInitiatorKey)),
            reason: 'Directional keys must differ');
      });

      test('Test 6 — Convenience getters: localEncryptionKey and localDecryptionKey', () async {
        final aliceEphKp = await aliceSession.generateEphemeralKeyPair();
        final bobEphKp = await bobSession.generateEphemeralKeyPair();

        final aliceIdPub = await aliceIdentity.getIdentityPublicKeyBytes();
        final bobIdPub = await bobIdentity.getIdentityPublicKeyBytes();

        final aliceResult = await aliceSession.deriveSessionKeys(
          requestId: 'REQ-CONV-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
        );

        final bobResult = await bobSession.deriveSessionKeys(
          requestId: 'REQ-CONV-001',
          localId: 'ML-BOB',
          peerId: 'ML-ALICE',
          isInitiator: false,
          peerEphemeralPublicKey: Uint8List.fromList(aliceEphKp.publicKey.bytes),
          localIdentityPublicKey: bobIdPub,
          peerIdentityPublicKey: aliceIdPub,
        );

        // Alice's encrypt key = Bob's decrypt key
        expect(aliceResult.localEncryptionKey, bobResult.localDecryptionKey,
            reason: "Alice's encryption key must be Bob's decryption key");
        // Bob's encrypt key = Alice's decrypt key
        expect(bobResult.localEncryptionKey, aliceResult.localDecryptionKey,
            reason: "Bob's encryption key must be Alice's decryption key");
      });

      test('Test 7 — Session stored and retrievable by peer ID', () async {
        final _ = await aliceSession.generateEphemeralKeyPair();
        final bobEphKp = await bobSession.generateEphemeralKeyPair();

        final aliceIdPub = await aliceIdentity.getIdentityPublicKeyBytes();
        final bobIdPub = await bobIdentity.getIdentityPublicKeyBytes();

        expect(aliceSession.hasSession('ML-BOB'), isFalse);

        await aliceSession.deriveSessionKeys(
          requestId: 'REQ-STORE-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
        );

        expect(aliceSession.hasSession('ML-BOB'), isTrue);
        expect(aliceSession.getSession('ML-BOB'), isNotNull);
        expect(aliceSession.getSession('ML-BOB')!.requestId, 'REQ-STORE-001');
        expect(aliceSession.getSession('ML-BOB')!.peerId, 'ML-BOB');
        expect(aliceSession.getSession('ML-BOB')!.isInitiator, isTrue);
      });

      test('Test 8 — Ephemeral key pair cleared after session derivation', () async {
        final bobEphKp = await bobSession.generateEphemeralKeyPair();
        final aliceIdPub = await aliceIdentity.getIdentityPublicKeyBytes();
        final bobIdPub = await bobIdentity.getIdentityPublicKeyBytes();

        await aliceSession.generateEphemeralKeyPair();

        // Derive session consumes the key pair
        await aliceSession.deriveSessionKeys(
          requestId: 'REQ-CLEAR-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
        );

        // Attempting to derive again without new key pair should throw
        expect(
          () async => aliceSession.deriveSessionKeys(
            requestId: 'REQ-CLEAR-002',
            localId: 'ML-ALICE',
            peerId: 'ML-CHARLIE',
            isInitiator: true,
            peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
            localIdentityPublicKey: aliceIdPub,
            peerIdentityPublicKey: bobIdPub,
          ),
          throwsA(isA<EphemeralSessionException>().having(
            (e) => e.message,
            'message',
            contains('No ephemeral key pair available'),
          )),
        );
      });

      test('Test 9 — Different requestId produces different session keys', () async {
        final aliceIdPub = await aliceIdentity.getIdentityPublicKeyBytes();
        final bobIdPub = await bobIdentity.getIdentityPublicKeyBytes();

        // Session 1
        final aliceKp1 = await aliceSession.generateEphemeralKeyPair();
        final bobKp1 = await bobSession.generateEphemeralKeyPair();

        final session1 = await aliceSession.deriveSessionKeys(
          requestId: 'REQ-DIFF-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobKp1.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
          localKeyPair: aliceKp1,
        );

        // Session 2 with same keys but different requestId
        final session2 = await aliceSession.deriveSessionKeys(
          requestId: 'REQ-DIFF-002',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobKp1.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
          localKeyPair: aliceKp1,
        );

        expect(session1.initiatorToResponderKey,
            isNot(equals(session2.initiatorToResponderKey)),
            reason: 'Different requestId must yield different keys');
      });

      test('Test 10 — removeSession and clearAll work correctly', () async {
        final _ = await aliceSession.generateEphemeralKeyPair();
        final bobEphKp = await bobSession.generateEphemeralKeyPair();
        final aliceIdPub = await aliceIdentity.getIdentityPublicKeyBytes();
        final bobIdPub = await bobIdentity.getIdentityPublicKeyBytes();

        await aliceSession.deriveSessionKeys(
          requestId: 'REQ-RM-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
        );

        expect(aliceSession.hasSession('ML-BOB'), isTrue);

        final removed = aliceSession.removeSession('ML-BOB');
        expect(removed, isNotNull);
        expect(removed!.peerId, 'ML-BOB');
        expect(aliceSession.hasSession('ML-BOB'), isFalse);

        // Re-create and clearAll
        await aliceSession.generateEphemeralKeyPair();
        await aliceSession.deriveSessionKeys(
          requestId: 'REQ-RM-002',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
          localKeyPair: await aliceSession.generateEphemeralKeyPair(),
        );

        aliceSession.clearAll();
        expect(aliceSession.hasSession('ML-BOB'), isFalse);
      });
    });

    group('EphemeralSessionService — Input Validation', () {
      late EphemeralSessionService service;

      setUp(() {
        service = EphemeralSessionService();
      });

      test('Test 11 — Rejects peer ephemeral key with wrong length', () async {
        await service.generateEphemeralKeyPair();

        expect(
          () async => service.deriveSessionKeys(
            requestId: 'REQ-VAL-001',
            localId: 'ML-A',
            peerId: 'ML-B',
            isInitiator: true,
            peerEphemeralPublicKey: Uint8List(16), // wrong length
            localIdentityPublicKey: Uint8List(32),
            peerIdentityPublicKey: Uint8List(32),
          ),
          throwsA(isA<EphemeralSessionException>().having(
            (e) => e.message,
            'message',
            contains('Peer ephemeral public key must be 32 bytes'),
          )),
        );
      });

      test('Test 12 — Rejects local identity key with wrong length', () async {
        await service.generateEphemeralKeyPair();

        expect(
          () async => service.deriveSessionKeys(
            requestId: 'REQ-VAL-002',
            localId: 'ML-A',
            peerId: 'ML-B',
            isInitiator: true,
            peerEphemeralPublicKey: Uint8List(32),
            localIdentityPublicKey: Uint8List(16), // wrong length
            peerIdentityPublicKey: Uint8List(32),
          ),
          throwsA(isA<EphemeralSessionException>().having(
            (e) => e.message,
            'message',
            contains('Local identity public key must be 32 bytes'),
          )),
        );
      });

      test('Test 13 — Rejects peer identity key with wrong length', () async {
        await service.generateEphemeralKeyPair();

        expect(
          () async => service.deriveSessionKeys(
            requestId: 'REQ-VAL-003',
            localId: 'ML-A',
            peerId: 'ML-B',
            isInitiator: true,
            peerEphemeralPublicKey: Uint8List(32),
            localIdentityPublicKey: Uint8List(32),
            peerIdentityPublicKey: Uint8List(16), // wrong length
          ),
          throwsA(isA<EphemeralSessionException>().having(
            (e) => e.message,
            'message',
            contains('Peer identity public key must be 32 bytes'),
          )),
        );
      });

      test('Test 14 — Throws when no ephemeral key pair has been generated', () async {
        // No generateEphemeralKeyPair call, _currentKeyPair is null
        // But getEphemeralPublicKey auto-generates, so we need to test the
        // direct deriveSessionKeys path after clearAll
        final svc = EphemeralSessionService();
        await svc.generateEphemeralKeyPair();
        svc.clearAll(); // clears both sessions and key pair

        expect(
          () async => svc.deriveSessionKeys(
            requestId: 'REQ-VAL-004',
            localId: 'ML-A',
            peerId: 'ML-B',
            isInitiator: true,
            peerEphemeralPublicKey: Uint8List(32),
            localIdentityPublicKey: Uint8List(32),
            peerIdentityPublicKey: Uint8List(32),
          ),
          throwsA(isA<EphemeralSessionException>().having(
            (e) => e.message,
            'message',
            contains('No ephemeral key pair available'),
          )),
        );
      });
    });

    group('EphemeralSessionService — HKDF Salt Symmetry', () {
      test('Test 15 — Salt symmetry: swapping identity keys yields same session keys', () async {
        // This test verifies that the HKDF salt is order-independent by
        // deriving session keys from both sides with swapped identity keys.
        final x25519 = X25519();
        final aliceEphKp = await (await x25519.newKeyPair()).extract();
        final bobEphKp = await (await x25519.newKeyPair()).extract();

        // Use synthetic identity keys to prove order-independence
        final keyA = Uint8List.fromList(List.generate(32, (i) => i));
        final keyB = Uint8List.fromList(List.generate(32, (i) => 255 - i));

        final svc1 = EphemeralSessionService();
        final session1 = await svc1.deriveSessionKeys(
          requestId: 'REQ-SALT-001',
          localId: 'ML-A',
          peerId: 'ML-B',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: keyA,
          peerIdentityPublicKey: keyB,
          localKeyPair: aliceEphKp,
        );

        // Same material but swapped roles — salt must be identical
        final svc2 = EphemeralSessionService();
        final session2 = await svc2.deriveSessionKeys(
          requestId: 'REQ-SALT-001',
          localId: 'ML-B',
          peerId: 'ML-A',
          isInitiator: false,
          peerEphemeralPublicKey: Uint8List.fromList(aliceEphKp.publicKey.bytes),
          localIdentityPublicKey: keyB,
          peerIdentityPublicKey: keyA,
          localKeyPair: bobEphKp,
        );

        expect(session1.initiatorToResponderKey, session2.initiatorToResponderKey,
            reason: 'Swapping identity keys must not change derived keys');
        expect(session1.responderToInitiatorKey, session2.responderToInitiatorKey);
      });

      test('Test 16 — Same identity keys on both sides still produces valid session', () async {
        // Edge case: what if both peers somehow have the same identity key?
        // The service must still derive valid, non-zero session keys.
        final x25519 = X25519();
        final aliceEphKp = await (await x25519.newKeyPair()).extract();
        final bobEphKp = await (await x25519.newKeyPair()).extract();

        final sameKey = Uint8List.fromList(List.generate(32, (i) => 42));

        final svc = EphemeralSessionService();
        final session = await svc.deriveSessionKeys(
          requestId: 'REQ-SAME-001',
          localId: 'ML-A',
          peerId: 'ML-B',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: sameKey,
          peerIdentityPublicKey: sameKey,
          localKeyPair: aliceEphKp,
        );

        expect(session.initiatorToResponderKey.length, 32);
        expect(session.responderToInitiatorKey.length, 32);
        expect(session.initiatorToResponderKey,
            isNot(equals(Uint8List(32))),
            reason: 'Keys should not be all zeros');
      });
    });

    // ── Integrated Handshake + Session Tests ──

    group('Integrated Handshake + Ephemeral Session', () {
      late MeshIdentityService aliceIdentity;
      late MeshIdentityService bobIdentity;
      late EphemeralSessionService aliceSession;
      late EphemeralSessionService bobSession;
      late HandshakeService aliceHandshake;
      late HandshakeService bobHandshake;

      setUp(() async {
        aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        await aliceIdentity.initialize();
        await bobIdentity.initialize();

        aliceSession = EphemeralSessionService();
        bobSession = EphemeralSessionService();

        aliceHandshake = HandshakeService(
          identityService: aliceIdentity,
          localId: 'ML-ALICE',
          ephemeralKeyProvider: aliceSession,
          sessionService: aliceSession,
        );

        bobHandshake = HandshakeService(
          identityService: bobIdentity,
          localId: 'ML-BOB',
          ephemeralKeyProvider: bobSession,
          sessionService: bobSession,
        );
      });

      test('Test 17 — Full handshake + session establishment end-to-end', () async {
        // 1. Alice creates key_request (auto-generates ephemeral key pair via session service)
        final request = await aliceHandshake.createKeyRequest(
          destinationId: 'ML-BOB',
          requestId: 'REQ-E2E-001',
          timestamp: 1727900000000,
        );

        expect(request.protocolVersion, 2);
        expect(request.ephemeralPublicKey, isNotEmpty);

        // 2. Bob verifies the request
        final verifiedReq = await bobHandshake.verifyKeyRequest(request);
        expect(verifiedReq.isValid, isTrue);

        // 3. Bob creates key_response (auto-generates his own ephemeral key pair)
        final response = await bobHandshake.createKeyResponse(
          request: request,
          timestamp: 1727900001000,
        );

        expect(response.protocolVersion, 2);
        expect(response.ephemeralPublicKey, isNotEmpty);

        // 4. Bob completes session as responder
        final bobSess = await bobHandshake.completeSessionAsResponder(
          verifiedRequest: verifiedReq,
        );

        expect(bobSess.isInitiator, isFalse);
        expect(bobSess.localId, 'ML-BOB');
        expect(bobSess.peerId, 'ML-ALICE');
        expect(bobSess.requestId, 'REQ-E2E-001');
        expect(bobSess.initiatorToResponderKey.length, 32);
        expect(bobSess.responderToInitiatorKey.length, 32);

        // 5. Retrieve pending request before verification clears it
        final pending = aliceHandshake.getPendingRequest('REQ-E2E-001');
        expect(pending, isNotNull);

        // 6. Alice verifies Bob's response
        final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
        expect(verifiedResp.isValid, isTrue);

        // 7. Alice completes session as initiator
        final aliceSess = await aliceHandshake.completeSessionAsInitiator(
          verifiedResponse: verifiedResp,
          originalRequest: pending!,
        );

        expect(aliceSess.isInitiator, isTrue);
        expect(aliceSess.localId, 'ML-ALICE');
        expect(aliceSess.peerId, 'ML-BOB');

        // 8. Both sides derived the same directional keys
        expect(aliceSess.initiatorToResponderKey, bobSess.initiatorToResponderKey);
        expect(aliceSess.responderToInitiatorKey, bobSess.responderToInitiatorKey);

        // 9. Cross-verify convenience getters
        expect(aliceSess.localEncryptionKey, bobSess.localDecryptionKey);
        expect(bobSess.localEncryptionKey, aliceSess.localDecryptionKey);
      });

      test('Test 18 — Session completion fails without EphemeralSessionService', () async {
        // Create a HandshakeService without sessionService
        final noSessionHandshake = HandshakeService(
          identityService: aliceIdentity,
          localId: 'ML-ALICE',
        );

        final request = await noSessionHandshake.createKeyRequest(
          destinationId: 'ML-BOB',
          requestId: 'REQ-NO-SVC-001',
        );

        await bobHandshake.verifyKeyRequest(request);
        final response = await bobHandshake.createKeyResponse(request: request);

        final pending = noSessionHandshake.getPendingRequest('REQ-NO-SVC-001');
        final verifiedResp = await noSessionHandshake.verifyKeyResponse(response);

        expect(
          () async => noSessionHandshake.completeSessionAsInitiator(
            verifiedResponse: verifiedResp,
            originalRequest: pending!,
          ),
          throwsA(isA<HandshakeException>().having(
            (e) => e.code,
            'code',
            HandshakeErrorCode.sessionDerivationFailed,
          )),
        );
      });

      test('Test 19 — Session keys differ for different peer pairs', () async {
        // Alice ↔ Bob session
        final request1 = await aliceHandshake.createKeyRequest(
          destinationId: 'ML-BOB',
          requestId: 'REQ-PAIR-001',
        );
        final verifiedReq1 = await bobHandshake.verifyKeyRequest(request1);
        final response1 = await bobHandshake.createKeyResponse(request: request1);
        await bobHandshake.completeSessionAsResponder(
          verifiedRequest: verifiedReq1,
        );

        final pending1 = aliceHandshake.getPendingRequest('REQ-PAIR-001');
        final verifiedResp1 = await aliceHandshake.verifyKeyResponse(response1);
        final aliceSess1 = await aliceHandshake.completeSessionAsInitiator(
          verifiedResponse: verifiedResp1,
          originalRequest: pending1!,
        );

        // Alice ↔ Charlie session (using a third identity)
        final charlieIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        await charlieIdentity.initialize();
        final charlieSession = EphemeralSessionService();
        final charlieHandshake = HandshakeService(
          identityService: charlieIdentity,
          localId: 'ML-CHARLIE',
          ephemeralKeyProvider: charlieSession,
          sessionService: charlieSession,
        );

        // Need fresh ephemeral key pair for Alice's second handshake
        final aliceSession2 = EphemeralSessionService();
        final aliceHandshake2 = HandshakeService(
          identityService: aliceIdentity,
          localId: 'ML-ALICE',
          ephemeralKeyProvider: aliceSession2,
          sessionService: aliceSession2,
        );

        final request2 = await aliceHandshake2.createKeyRequest(
          destinationId: 'ML-CHARLIE',
          requestId: 'REQ-PAIR-002',
        );
        final verifiedReq2 = await charlieHandshake.verifyKeyRequest(request2);
        final response2 = await charlieHandshake.createKeyResponse(request: request2);
        await charlieHandshake.completeSessionAsResponder(
          verifiedRequest: verifiedReq2,
        );

        final pending2 = aliceHandshake2.getPendingRequest('REQ-PAIR-002');
        final verifiedResp2 = await aliceHandshake2.verifyKeyResponse(response2);
        final aliceSess2 = await aliceHandshake2.completeSessionAsInitiator(
          verifiedResponse: verifiedResp2,
          originalRequest: pending2!,
        );

        // Keys for different peers must differ
        expect(aliceSess1.initiatorToResponderKey,
            isNot(equals(aliceSess2.initiatorToResponderKey)),
            reason: 'Different peer pairs must yield different session keys');
      });

      test('Test 20 — EphemeralSession data model fields are correct', () async {
        final request = await aliceHandshake.createKeyRequest(
          destinationId: 'ML-BOB',
          requestId: 'REQ-MODEL-001',
          timestamp: 1727800000000,
        );

        final verifiedReq = await bobHandshake.verifyKeyRequest(request);

        // Bob must create the response first (generates ephemeral key pair)
        await bobHandshake.createKeyResponse(
          request: request,
          timestamp: 1727800001000,
        );

        final bobSess = await bobHandshake.completeSessionAsResponder(
          verifiedRequest: verifiedReq,
        );

        expect(bobSess, isA<EphemeralSession>());
        expect(bobSess.requestId, 'REQ-MODEL-001');
        expect(bobSess.localId, 'ML-BOB');
        expect(bobSess.peerId, 'ML-ALICE');
        expect(bobSess.isInitiator, isFalse);
        expect(bobSess.localEphemeralPublicKey.length, 32);
        expect(bobSess.peerEphemeralPublicKey.length, 32);
        expect(bobSess.initiatorToResponderKey.length, 32);
        expect(bobSess.responderToInitiatorKey.length, 32);
        expect(bobSess.createdAt, greaterThan(0));
      });

      test('Test 21 — Session derivation is deterministic for same ECDH material', () async {
        // Generate key pairs manually to reuse
        final x25519 = X25519();
        final aliceEphKp = await (await x25519.newKeyPair()).extract();
        final bobEphKp = await (await x25519.newKeyPair()).extract();

        final aliceIdPub = await aliceIdentity.getIdentityPublicKeyBytes();
        final bobIdPub = await bobIdentity.getIdentityPublicKeyBytes();

        // Derive twice with same material
        final svc1 = EphemeralSessionService();
        final session1 = await svc1.deriveSessionKeys(
          requestId: 'REQ-DET-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
          localKeyPair: aliceEphKp,
        );

        final svc2 = EphemeralSessionService();
        final session2 = await svc2.deriveSessionKeys(
          requestId: 'REQ-DET-001',
          localId: 'ML-ALICE',
          peerId: 'ML-BOB',
          isInitiator: true,
          peerEphemeralPublicKey: Uint8List.fromList(bobEphKp.publicKey.bytes),
          localIdentityPublicKey: aliceIdPub,
          peerIdentityPublicKey: bobIdPub,
          localKeyPair: aliceEphKp,
        );

        expect(session1.initiatorToResponderKey, session2.initiatorToResponderKey);
        expect(session1.responderToInitiatorKey, session2.responderToInitiatorKey);
      });
    });

    // ── Backward Compatibility ──

    group('Backward Compatibility with Step 3', () {
      test('Test 22 — Step 3 handshake still works without session service', () async {
        final aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        final bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        await aliceIdentity.initialize();
        await bobIdentity.initialize();

        // No sessionService, uses StaticEphemeralKeyProvider
        final aliceHandshake = HandshakeService(
          identityService: aliceIdentity,
          localId: 'ML-ALICE',
        );
        final bobHandshake = HandshakeService(
          identityService: bobIdentity,
          localId: 'ML-BOB',
        );

        final request = await aliceHandshake.createKeyRequest(
          destinationId: 'ML-BOB',
          requestId: 'REQ-COMPAT-001',
        );

        final verifiedReq = await bobHandshake.verifyKeyRequest(request);
        expect(verifiedReq.isValid, isTrue);

        final response = await bobHandshake.createKeyResponse(request: request);

        final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
        expect(verifiedResp.isValid, isTrue);
      });

      test('Test 23 — sessionService getter returns null when not injected', () {
        final identity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        final hs = HandshakeService(
          identityService: identity,
          localId: 'ML-TEST',
        );

        expect(hs.sessionService, isNull);
      });

      test('Test 24 — sessionService getter returns injected service', () {
        final identity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        final svc = EphemeralSessionService();
        final hs = HandshakeService(
          identityService: identity,
          localId: 'ML-TEST',
          sessionService: svc,
        );

        expect(hs.sessionService, same(svc));
      });
    });

    // ── EphemeralSession Model Tests ──

    group('EphemeralSession Model', () {
      test('Test 25 — EphemeralSessionException toString format', () {
        const e = EphemeralSessionException('test error message');
        expect(e.toString(), 'EphemeralSessionException: test error message');
        expect(e.message, 'test error message');
      });
    });
  });
}
