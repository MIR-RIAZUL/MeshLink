import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 7 Step 5: Directional Session Encryption', () {
    late MeshIdentityService aliceIdentity;
    late MeshIdentityService bobIdentity;
    late MeshIdentityService charlieIdentity;

    late EphemeralSessionService aliceSessionService;
    late EphemeralSessionService bobSessionService;
    late EphemeralSessionService charlieSessionService;

    late HandshakeService aliceHandshake;
    late HandshakeService bobHandshake;
    late HandshakeService charlieHandshake;

    late DirectionalSessionEncryptionService encryptionService;

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

      encryptionService = DirectionalSessionEncryptionService();
    });

    /// Helper to execute a full authenticated Step 3 + Step 4 handshake between two peers
    /// and return the established [EphemeralSession] pair.
    Future<({EphemeralSession sessionA, EphemeralSession sessionB})> establishTestSession({
      String requestId = 'REQ-TEST-SESS-001',
    }) async {
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: requestId,
      );
      final verifiedReq = await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);
      final sessionB = await bobHandshake.completeSessionAsResponder(
        verifiedRequest: verifiedReq,
      );
      final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
      final sessionA = await aliceHandshake.completeSessionAsInitiator(
        verifiedResponse: verifiedResp,
      );
      return (sessionA: sessionA, sessionB: sessionB);
    }

    // ── Test 1 — HKDF determinism ──
    test('Test 1 — HKDF determinism: same shared secret + same session context produces identical keys', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-HKDF-DET-1');

      final keysA1 = await encryptionService.deriveDirectionalKeys(sessionA);
      final keysA2 = await encryptionService.deriveDirectionalKeys(sessionA);

      expect(keysA1.sendKey.length, 32);
      expect(keysA1.receiveKey.length, 32);

      // Determinism check: repeated derivation yields exact same bytes
      expect(keysA1.sendKey, equals(keysA2.sendKey));
      expect(keysA1.receiveKey, equals(keysA2.receiveKey));
      expect(
        EphemeralSession.constantTimeCompare(keysA1.sendKey, keysA2.sendKey),
        isTrue,
      );
      expect(
        EphemeralSession.constantTimeCompare(keysA1.receiveKey, keysA2.receiveKey),
        isTrue,
      );
    });

    // ── Test 2 — Directional key symmetry ──
    test('Test 2 — Directional key symmetry: A.sendKey == B.receiveKey and A.receiveKey == B.sendKey', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-DIR-SYM-1');

      final keysA = await encryptionService.deriveDirectionalKeys(sessionA);
      final keysB = await encryptionService.deriveDirectionalKeys(sessionB);

      // A's sending key must match B's receiving key
      expect(keysA.sendKey, equals(keysB.receiveKey),
          reason: 'A.sendKey must equal B.receiveKey');
      expect(
        EphemeralSession.constantTimeCompare(keysA.sendKey, keysB.receiveKey),
        isTrue,
      );

      // A's receiving key must match B's sending key
      expect(keysA.receiveKey, equals(keysB.sendKey),
          reason: 'A.receiveKey must equal B.sendKey');
      expect(
        EphemeralSession.constantTimeCompare(keysA.receiveKey, keysB.sendKey),
        isTrue,
      );
    });

    // ── Test 3 — Directional separation ──
    test('Test 3 — Directional separation: sendKey != receiveKey on both peers', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-DIR-SEP-1');

      final keysA = await encryptionService.deriveDirectionalKeys(sessionA);
      final keysB = await encryptionService.deriveDirectionalKeys(sessionB);

      expect(keysA.sendKey, isNot(equals(keysA.receiveKey)),
          reason: 'A.sendKey must not equal A.receiveKey');
      expect(keysB.sendKey, isNot(equals(keysB.receiveKey)),
          reason: 'B.sendKey must not equal B.receiveKey');

      expect(
        EphemeralSession.constantTimeCompare(keysA.sendKey, keysA.receiveKey),
        isFalse,
      );
      expect(
        EphemeralSession.constantTimeCompare(keysB.sendKey, keysB.receiveKey),
        isFalse,
      );
    });

    // ── Test 4 — Session isolation ──
    test('Test 4 — Session isolation: two different sessions produce completely different directional keys', () async {
      final pair1 = await establishTestSession(requestId: 'REQ-ISO-SESS-1');
      final keys1 = await encryptionService.deriveDirectionalKeys(pair1.sessionA);

      aliceHandshake.clearSession('ML-DEVICE-B');
      bobHandshake.clearSession('ML-DEVICE-A');

      final pair2 = await establishTestSession(requestId: 'REQ-ISO-SESS-2');
      final keys2 = await encryptionService.deriveDirectionalKeys(pair2.sessionA);

      expect(keys1.sendKey, isNot(equals(keys2.sendKey)),
          reason: 'Different sessions must derive distinct send keys');
      expect(keys1.receiveKey, isNot(equals(keys2.receiveKey)),
          reason: 'Different sessions must derive distinct receive keys');
    });

    // ── Test 5 — Encrypt/decrypt A → B ──
    test('Test 5 — Encrypt/decrypt A → B: encrypted on A and decrypted on B produces exact plaintext', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-ENC-AB-1');

      final plaintext = utf8.encode('Hello Bob from Alice via ChaCha20-Poly1305!');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-001',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      expect(encrypted.nonce.length, 12);
      expect(encrypted.mac.length, 16);
      expect(encrypted.ciphertext.length, plaintext.length);
      expect(encrypted.ciphertext, isNot(equals(plaintext)));

      final decrypted = await encryptionService.decrypt(
        session: sessionB,
        encrypted: encrypted,
        aad: aad,
      );

      expect(decrypted, equals(plaintext));
      expect(utf8.decode(decrypted), 'Hello Bob from Alice via ChaCha20-Poly1305!');
    });

    // ── Test 6 — Encrypt/decrypt B → A ──
    test('Test 6 — Encrypt/decrypt B → A: encrypted on B and decrypted on A produces exact plaintext', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-ENC-BA-1');

      final plaintext = utf8.encode('Acknowledged, Alice! Returning secure response.');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionB.sessionId,
        originId: 'ML-DEVICE-B',
        destinationId: 'ML-DEVICE-A',
        messageId: 'MSG-002',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionB,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      final decrypted = await encryptionService.decrypt(
        session: sessionA,
        encrypted: encrypted,
        aad: aad,
      );

      expect(decrypted, equals(plaintext));
      expect(utf8.decode(decrypted), 'Acknowledged, Alice! Returning secure response.');
    });

    // ── Test 7 — Wrong direction ──
    test('Test 7 — Wrong direction: using wrong directional key fails decryption closed', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-WRONG-DIR-1');

      final plaintext = utf8.encode('Directional secret message');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-003',
      );

      // Encrypted with A.sendKey
      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Attempt to decrypt on A (which uses A.receiveKey == B.sendKey != A.sendKey)
      await expectLater(
        encryptionService.decrypt(
          session: sessionA,
          encrypted: encrypted,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>().having(
          (e) => e.message,
          'message',
          contains('Decryption authentication failed'),
        )),
      );
    });

    // ── Test 8 — Tampered ciphertext ──
    test('Test 8 — Tampered ciphertext fails decryption with zero plaintext returned', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-TAMPER-CT-1');

      final plaintext = utf8.encode('Sensitive message to protect from tampering');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-004',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Tamper 1 byte in ciphertext
      final tamperedCt = Uint8List.fromList(encrypted.ciphertext);
      tamperedCt[0] ^= 0x01;

      final tamperedPayload = SessionEncryptedPayload(
        nonce: encrypted.nonce,
        ciphertext: tamperedCt,
        mac: encrypted.mac,
      );

      await expectLater(
        encryptionService.decrypt(
          session: sessionB,
          encrypted: tamperedPayload,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── Test 9 — Tampered nonce ──
    test('Test 9 — Tampered nonce fails decryption', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-TAMPER-NONCE-1');

      final plaintext = utf8.encode('Message tested with tampered nonce');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-005',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Tamper 1 byte in nonce
      final tamperedNonce = Uint8List.fromList(encrypted.nonce);
      tamperedNonce[0] ^= 0xFF;

      final tamperedPayload = SessionEncryptedPayload(
        nonce: tamperedNonce,
        ciphertext: encrypted.ciphertext,
        mac: encrypted.mac,
      );

      await expectLater(
        encryptionService.decrypt(
          session: sessionB,
          encrypted: tamperedPayload,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── Test 10 — Tampered AAD ──
    test('Test 10 — Tampered AAD: decrypting with mismatched AAD fails authentication', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-TAMPER-AAD-1');

      final plaintext = utf8.encode('Message with bound AAD');
      final aadA = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-006',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aadA,
      );

      // Different AAD (tampered destinationId)
      final aadB = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-C', // Tampered!
        messageId: 'MSG-006',
      );

      await expectLater(
        encryptionService.decrypt(
          session: sessionB,
          encrypted: encrypted,
          aad: aadB,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── Test 11 — Binary payload ──
    test('Test 11 — Binary payload: handles arbitrary non-UTF8 bytes [0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD]', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-BIN-PAYLOAD-1');

      final binaryData = Uint8List.fromList([
        0x00, 0x01, 0x02, 0x7F, 0x80, 0xAA, 0x55, 0xFE, 0xFD, 0xFF,
        0x00, 0x00, 0xFF, 0xFF, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC,
      ]);

      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-BIN-1',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: binaryData,
        aad: aad,
      );

      final decrypted = await encryptionService.decrypt(
        session: sessionB,
        encrypted: encrypted,
        aad: aad,
      );

      expect(decrypted, equals(binaryData));
      expect(
        EphemeralSession.constantTimeCompare(decrypted, binaryData),
        isTrue,
      );
    });

    // ── Test 12 — Empty payload ──
    test('Test 12 — Empty payload: encrypts and decrypts empty byte list correctly', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-EMPTY-PAYLOAD-1');

      final emptyData = Uint8List(0);
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-EMPTY-1',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: emptyData,
        aad: aad,
      );

      expect(encrypted.ciphertext.length, 0);
      expect(encrypted.nonce.length, 12);
      expect(encrypted.mac.length, 16);

      final decrypted = await encryptionService.decrypt(
        session: sessionB,
        encrypted: encrypted,
        aad: aad,
      );

      expect(decrypted.length, 0);
      expect(decrypted, equals(emptyData));
    });

    // ── Test 13 — Wrong session ──
    test('Test 13 — Wrong session: encrypted for A↔B fails to decrypt under A↔C session', () async {
      // 1. Establish session A <-> B
      final pairAB = await establishTestSession(requestId: 'REQ-WRONG-SESS-AB');

      // 2. Establish session A <-> C
      final reqAC = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-C',
        requestId: 'REQ-WRONG-SESS-AC',
      );
      final vReqAC = await charlieHandshake.verifyKeyRequest(reqAC);
      final respAC = await charlieHandshake.createKeyResponse(request: reqAC);
      final sessionC = await charlieHandshake.completeSessionAsResponder(
        verifiedRequest: vReqAC,
      );
      final vRespAC = await aliceHandshake.verifyKeyResponse(respAC);
      await aliceHandshake.completeSessionAsInitiator(
        verifiedResponse: vRespAC,
      );

      final plaintext = utf8.encode('Message meant solely for Bob');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pairAB.sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-SESS-ISO',
      );

      // Encrypted using A's session with B
      final encrypted = await encryptionService.encrypt(
        session: pairAB.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Charlie attempts to decrypt with Charlie's session
      await expectLater(
        encryptionService.decrypt(
          session: sessionC,
          encrypted: encrypted,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── Test 14 — Destroyed session ──
    test('Test 14 — Destroyed session: encryption and decryption cannot continue after teardown', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-DESTROY-TEST-1');

      final plaintext = utf8.encode('Pre-destruction message');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-PRE-DESTROY',
      );

      final encrypted = await encryptionService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Destroy session A
      sessionA.destroy();
      expect(sessionA.isDestroyed, isTrue);

      // Encryption on destroyed session must fail
      await expectLater(
        encryptionService.encrypt(
          session: sessionA,
          plaintext: Uint8List.fromList(plaintext),
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>().having(
          (e) => e.message,
          'message',
          contains('session is destroyed'),
        )),
      );

      // Destroy session B
      sessionB.destroy();
      expect(sessionB.isDestroyed, isTrue);

      // Decryption on destroyed session must fail
      await expectLater(
        encryptionService.decrypt(
          session: sessionB,
          encrypted: encrypted,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>().having(
          (e) => e.message,
          'message',
          contains('session is destroyed'),
        )),
      );
    });

    // ── Test 15 — No persistence ──
    test('Test 15 — No persistence: directional keys and shared secrets are never stored to database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftMessageRepository(db);

      final aliceWithDb = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ML-DEVICE-A',
        peerRepository: repo,
        sessionService: aliceSessionService,
      );

      final request = await aliceWithDb.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-NO-PERSIST-S5',
      );
      final vReq = await bobHandshake.verifyKeyRequest(request);
      final response = await bobHandshake.createKeyResponse(request: request);
      await bobHandshake.completeSessionAsResponder(verifiedRequest: vReq);
      final vResp = await aliceWithDb.verifyKeyResponse(response);
      final session = await aliceWithDb.completeSessionAsInitiator(
        verifiedResponse: vResp,
      );

      final keys = await encryptionService.deriveDirectionalKeys(session);

      // Perform encryption
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: session.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-NP-1',
      );
      await encryptionService.encrypt(
        session: session,
        plaintext: Uint8List.fromList(utf8.encode('Memory only payload')),
        aad: aad,
      );

      // Query database tables
      final peerIdentities = await db.select(db.peerIdentitiesTable).get();
      final messages = await db.select(db.messagesTable).get();
      final seenPackets = await db.select(db.seenPacketsTable).get();

      // Messages table and seenPackets table are completely empty
      expect(messages, isEmpty);
      expect(seenPackets, isEmpty);

      // Verify no keys or shared secret in peerIdentitiesTable
      final sendKeyBase64 = base64UrlEncode(keys.sendKey);
      final recvKeyBase64 = base64UrlEncode(keys.receiveKey);
      final secretBase64 = base64UrlEncode(session.sharedSecret);

      for (final p in peerIdentities) {
        expect(p.identityPublicKey, isNot(contains(sendKeyBase64)));
        expect(p.identityPublicKey, isNot(contains(recvKeyBase64)));
        expect(p.identityPublicKey, isNot(contains(secretBase64)));
      }

      await db.close();
    });

    // ── Test 16 — Full security flow ──
    test('Test 16 — Full security flow: Ed25519 identity -> signed handshake -> ephemeral X25519 -> HKDF -> ChaCha20-Poly1305 -> peer decryption', () async {
      // 1. Ed25519 identity keys exist and are valid
      final aliceIdBytes = await aliceIdentity.getIdentityPublicKeyBytes();
      final bobIdBytes = await bobIdentity.getIdentityPublicKeyBytes();
      expect(aliceIdBytes.length, 32);
      expect(bobIdBytes.length, 32);

      // 2. Signed handshake exchange
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-FULL-FLOW-S5',
      );
      final vReq = await bobHandshake.verifyKeyRequest(request);
      expect(vReq.isValid, isTrue);

      final response = await bobHandshake.createKeyResponse(request: request);
      final vResp = await aliceHandshake.verifyKeyResponse(response);
      expect(vResp.isValid, isTrue);

      // 3. Ephemeral X25519 session establishment
      final sessionB = await bobHandshake.completeSessionAsResponder(
        verifiedRequest: vReq,
      );
      final sessionA = await aliceHandshake.completeSessionAsInitiator(
        verifiedResponse: vResp,
      );

      expect(sessionA.sharedSecret, equals(sessionB.sharedSecret));

      // 4. HKDF-SHA256 directional key derivation
      final keysA = await encryptionService.getOrDeriveKeys(sessionA);
      final keysB = await encryptionService.getOrDeriveKeys(sessionB);

      expect(keysA.sendKey, equals(keysB.receiveKey));
      expect(keysA.receiveKey, equals(keysB.sendKey));
      expect(keysA.sendKey, isNot(equals(keysA.receiveKey)));

      // 5. ChaCha20-Poly1305 encrypt on A
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-FULL-FLOW-01',
      );
      final encryptedA = await encryptionService.encryptString(
        session: sessionA,
        text: 'Full security pipeline functional test message',
        aad: aad,
      );

      // 6. ChaCha20-Poly1305 decrypt on B
      final decryptedB = await encryptionService.decryptString(
        session: sessionB,
        encrypted: encryptedA,
        aad: aad,
      );
      expect(decryptedB, 'Full security pipeline functional test message');

      // 7. Reverse flow: encrypt on B and decrypt on A
      final aadBack = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionB.sessionId,
        originId: 'ML-DEVICE-B',
        destinationId: 'ML-DEVICE-A',
        messageId: 'MSG-FULL-FLOW-02',
      );
      final encryptedB = await encryptionService.encryptString(
        session: sessionB,
        text: 'Bidirectional security pipeline confirmed',
        aad: aadBack,
      );
      final decryptedA = await encryptionService.decryptString(
        session: sessionA,
        encrypted: encryptedB,
        aad: aadBack,
      );
      expect(decryptedA, 'Bidirectional security pipeline confirmed');
    });

    // ── Test 17 — Key substitution resistance ──
    test('Test 17 — Key substitution resistance: altered identity or ephemeral keys alter derived encryption keys', () async {
      final (:sessionA, :sessionB) = await establishTestSession(requestId: 'REQ-KEY-SUBST-1');

      final legitimateKeys = await encryptionService.deriveDirectionalKeys(sessionA);

      // Synthetic session with substituted identity key
      final substitutedIdentityKey = Uint8List.fromList(sessionA.peerIdentityPublicKey);
      substitutedIdentityKey[0] ^= 0x42; // Alter peer identity key

      final substitutedSession = EphemeralSession(
        sessionId: sessionA.sessionId,
        requestId: sessionA.requestId,
        localId: sessionA.localId,
        peerId: sessionA.peerId,
        isInitiator: sessionA.isInitiator,
        localIdentityPublicKey: sessionA.localIdentityPublicKey,
        peerIdentityPublicKey: substitutedIdentityKey,
        localEphemeralPublicKey: sessionA.localEphemeralPublicKey,
        peerEphemeralPublicKey: sessionA.peerEphemeralPublicKey,
        sharedSecret: sessionA.sharedSecret,
        createdAt: sessionA.createdAt,
      );

      final substitutedKeys = await encryptionService.deriveDirectionalKeys(substitutedSession);

      // The derived directional keys MUST differ completely due to salt binding
      expect(legitimateKeys.sendKey, isNot(equals(substitutedKeys.sendKey)),
          reason: 'Altering peer identity key must alter derived sendKey');
      expect(legitimateKeys.receiveKey, isNot(equals(substitutedKeys.receiveKey)),
          reason: 'Altering peer identity key must alter derived receiveKey');

      // Attempting to decrypt with legitimate session B must fail if encrypted with substituted keys
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        messageId: 'MSG-SUBST-1',
      );

      final encryptedSubstituted = await encryptionService.encrypt(
        session: substitutedSession,
        plaintext: Uint8List.fromList(utf8.encode('Substituted key test')),
        aad: aad,
      );

      await expectLater(
        encryptionService.decrypt(
          session: sessionB,
          encrypted: encryptedSubstituted,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── Test 18 — Binary and JSON Serialization of Encrypted Payload ──
    test('Test 18 — SessionEncryptedPayload binary and JSON serialization roundtrips', () {
      final nonce = Uint8List(12)..fillRange(0, 12, 0x07);
      final mac = Uint8List(16)..fillRange(0, 16, 0x09);
      final ct = Uint8List.fromList([1, 2, 3, 4, 5]);

      final payload = SessionEncryptedPayload(
        nonce: nonce,
        ciphertext: ct,
        mac: mac,
      );

      // Binary roundtrip
      final bytes = payload.toBytes();
      expect(bytes.length, 12 + 16 + 5);
      final fromBytes = SessionEncryptedPayload.fromBytes(bytes);
      expect(fromBytes, equals(payload));
      expect(fromBytes.nonce, equals(nonce));
      expect(fromBytes.mac, equals(mac));
      expect(fromBytes.ciphertext, equals(ct));

      // JSON roundtrip
      final jsonStr = payload.toJson();
      final fromJson = SessionEncryptedPayload.fromJson(jsonStr);
      expect(fromJson, equals(payload));
    });
  });
}
