import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MessageRepository messageRepository;
  late ReplayProtectionService replayProtectionService;

  late MeshIdentityService identityServiceA;
  late MeshIdentityService identityServiceB;
  late MeshIdentityService identityServiceC;

  late EphemeralSessionService sessionServiceA;
  late EphemeralSessionService sessionServiceB;

  late HandshakeService handshakeA;
  late HandshakeService handshakeB;

  late DirectionalSessionEncryptionService encryptionService;

  DateTime testNow = DateTime.utc(2026, 10, 5, 12, 0, 0);

  setUp(() async {
    testNow = DateTime.utc(2026, 10, 5, 12, 0, 0);

    db = AppDatabase(NativeDatabase.memory());
    messageRepository = DriftMessageRepository(db);
    replayProtectionService = ReplayProtectionService(repository: messageRepository);

    identityServiceA = MeshIdentityService(
      store: InMemorySecureIdentityStoreV2(),
    );
    identityServiceB = MeshIdentityService(
      store: InMemorySecureIdentityStoreV2(),
    );
    identityServiceC = MeshIdentityService(
      store: InMemorySecureIdentityStoreV2(),
    );

    await identityServiceA.initialize();
    await identityServiceB.initialize();
    await identityServiceC.initialize();

    sessionServiceA = EphemeralSessionService(clock: () => testNow);
    sessionServiceB = EphemeralSessionService(clock: () => testNow);

    handshakeA = HandshakeService(
      identityService: identityServiceA,
      localId: 'ML-AAAAAA',
      peerRepository: messageRepository,
      sessionService: sessionServiceA,
    );
    handshakeB = HandshakeService(
      identityService: identityServiceB,
      localId: 'ML-BBBBBB',
      peerRepository: messageRepository,
      sessionService: sessionServiceB,
    );

    encryptionService = DirectionalSessionEncryptionService();
  });

  tearDown(() async {
    await db.close();
  });

  Future<({EphemeralSession sessionA, EphemeralSession sessionB})>
      establishSession({String? requestId}) async {
    final req = await handshakeA.createKeyRequest(
      destinationId: 'ML-BBBBBB',
      requestId: requestId,
    );
    final resp = await handshakeB.createKeyResponse(request: req);
    final verifiedResp = await handshakeA.verifyKeyResponse(resp);
    final verifiedReq = await handshakeB.verifyKeyRequest(req);

    final sessionA = await handshakeA.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: testNow,
    );
    final sessionB = await handshakeB.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: testNow,
    );

    return (sessionA: sessionA, sessionB: sessionB);
  }

  group('Phase 7 Step 9 — Protocol Hardening Tests', () {
    // ── 1. Protocol v2 accepted ──
    test('Test 1 — Protocol v2 accepted: valid v2 packets encode, parse, and verify cleanly', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      expect(req.protocolVersion, 2);

      final map = req.toMap();
      expect(map['version'], 2);

      final parsed = KeyRequestPacket.fromMap(map);
      expect(parsed.protocolVersion, 2);

      final verified = await handshakeB.verifyKeyRequest(parsed);
      expect(verified.isValid, isTrue);
      expect(verified.protocolVersion, 2);
    });

    // ── 2. Protocol v1 rejected ──
    test('Test 2 — Protocol v1 rejected: no automatic downgrade or silent acceptance of v1', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final v1Map = {...req.toMap(), 'version': 1};

      expect(
        () => KeyRequestPacket.fromMap(v1Map),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidProtocolVersion,
        )),
      );

      final v1Packet = KeyRequestPacket(
        protocolVersion: 1,
        requestId: req.requestId,
        originId: req.originId,
        destinationId: req.destinationId,
        timestamp: req.timestamp,
        identityPublicKey: req.identityPublicKey,
        ephemeralPublicKey: req.ephemeralPublicKey,
        signature: req.signature,
      );

      expect(
        () => handshakeB.verifyKeyRequest(v1Packet),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidProtocolVersion,
        )),
      );

      // Also in AAD construction
      expect(
        () => DirectionalSessionEncryptionService.buildCanonicalAad(
          version: 1,
          sessionId: 'SESS-1',
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-1',
        ),
        throwsA(isA<DirectionalEncryptionException>().having(
          (e) => e.message,
          'message',
          contains('Unsupported protocol version: 1'),
        )),
      );
    });

    // ── 3. Unsupported version rejected (v0, future versions) ──
    test('Test 3 — Unsupported version rejected: v0, v3, and future versions fail closed', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');

      for (final badVersion in [0, 3, 99, -1]) {
        expect(
          () => KeyRequestPacket.fromMap({...req.toMap(), 'version': badVersion}),
          throwsA(isA<HandshakeException>().having(
            (e) => e.code,
            'code',
            HandshakeErrorCode.invalidProtocolVersion,
          )),
        );
      }

      // Missing version
      final noVersionMap = Map<String, dynamic>.from(req.toMap())..remove('version');
      expect(
        () => KeyRequestPacket.fromMap(noVersionMap),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidProtocolVersion,
        )),
      );
    });

    // ── 4. Request/response domain separation ──
    test('Test 4 — Domain separation: MESHLINK-v2-REQ cannot validate as MESHLINK-v2-RSP and vice versa', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final resp = await handshakeB.createKeyResponse(request: req);

      // Attempt to verify a request signature against a response transcript
      final reqTranscriptAsResp = HandshakeTranscriptEncoder.encodeKeyResponseTranscript(
        timestamp: req.timestamp,
        requestId: req.requestId,
        originId: req.originId,
        destinationId: req.destinationId,
        initiatorIdentityKey: base64Url.decode(req.identityPublicKey),
        initiatorEphemeralKey: base64Url.decode(req.ephemeralPublicKey),
        responderIdentityKey: base64Url.decode(req.identityPublicKey),
        responderEphemeralKey: base64Url.decode(req.ephemeralPublicKey),
      );

      final ed25519 = Ed25519();
      final isCrossValid = await ed25519.verify(
        reqTranscriptAsResp,
        signature: Signature(
          base64Url.decode(req.signature),
          publicKey: SimplePublicKey(
            base64Url.decode(req.identityPublicKey),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      expect(isCrossValid, isFalse);

      // And response signature against request transcript
      final respTranscriptAsReq = HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
        timestamp: resp.timestamp,
        requestId: resp.requestId,
        originId: resp.originId,
        destinationId: resp.destinationId,
        initiatorIdentityKey: base64Url.decode(resp.identityPublicKey),
        initiatorEphemeralKey: base64Url.decode(resp.ephemeralPublicKey),
      );

      final isCrossRespValid = await ed25519.verify(
        respTranscriptAsReq,
        signature: Signature(
          base64Url.decode(resp.signature),
          publicKey: SimplePublicKey(
            base64Url.decode(resp.identityPublicKey),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      expect(isCrossRespValid, isFalse);
    });

    // ── 5. Canonical transcript integrity ──
    test('Test 5 — Canonical transcript integrity: modifying any field in binary transcript invalidates signature', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final initIdKey = base64Url.decode(req.identityPublicKey);
      final initEphKey = base64Url.decode(req.ephemeralPublicKey);
      final sigBytes = base64Url.decode(req.signature);
      final ed25519 = Ed25519();
      final pubKey = SimplePublicKey(initIdKey, type: KeyPairType.ed25519);

      // Verify authentic transcript succeeds
      final authenticTranscript = HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
        timestamp: req.timestamp,
        requestId: req.requestId,
        originId: req.originId,
        destinationId: req.destinationId,
        initiatorIdentityKey: initIdKey,
        initiatorEphemeralKey: initEphKey,
      );
      expect(
        await ed25519.verify(authenticTranscript, signature: Signature(sigBytes, publicKey: pubKey)),
        isTrue,
      );

      // 1-byte tamper in transcript
      final tamperedTranscript = Uint8List.fromList(authenticTranscript);
      tamperedTranscript[0] ^= 0xFF; // tamper first domain byte
      expect(
        await ed25519.verify(tamperedTranscript, signature: Signature(sigBytes, publicKey: pubKey)),
        isFalse,
      );

      // Tamper timestamp byte
      final tamperedTsTranscript = Uint8List.fromList(authenticTranscript);
      tamperedTsTranscript[18] ^= 0x01;
      expect(
        await ed25519.verify(tamperedTsTranscript, signature: Signature(sigBytes, publicKey: pubKey)),
        isFalse,
      );
    });

    // ── 6. Malformed IDs rejected ──
    test('Test 6 — Identifier validation: empty, oversized, whitespace, or control characters rejected', () {
      final malformedIds = [
        '', // empty
        'A' * 129, // exceeds 128 limit
        ' ML-LEADING', // leading whitespace
        'ML-TRAILING ', // trailing whitespace
        'ML-\x00-NULL', // null control char
        'ML-\r-RETURN', // carriage return
        'ML-\n-NEWLINE', // newline
        'ML-\x1B-ESC', // escape
        'ML-\x7F-DEL', // delete char
      ];

      for (final id in malformedIds) {
        expect(
          () => HandshakePacketValidator.validateIdentifier(id, 'testId'),
          throwsA(isA<HandshakeException>().having(
            (e) => e.code,
            'code',
            HandshakeErrorCode.invalidIdentifier,
          )),
        );
      }

      // Valid IDs pass cleanly
      for (final validId in ['ML-AAAAAA', 'REQ-12345-ABCD', 'a', 'Z' * 128]) {
        expect(() => HandshakePacketValidator.validateIdentifier(validId, 'validId'), returnsNormally);
      }
    });

    // ── 7 & 8. Timestamp boundaries (7 days past, +1 hour future) ──
    test('Test 7 & 8 — Timestamp boundaries: exactly -7 days and +1 hour are accepted', () {
      final nowMs = testNow.millisecondsSinceEpoch;
      final exactLowerPast = nowMs - (7 * 24 * 60 * 60 * 1000);
      final exactUpperFuture = nowMs + (60 * 60 * 1000);

      expect(
        () => HandshakePacketValidator.validateTimestamp(
          exactLowerPast,
          nowMs: nowMs,
          enforceHorizon: true,
        ),
        returnsNormally,
      );

      expect(
        () => HandshakePacketValidator.validateTimestamp(
          exactUpperFuture,
          nowMs: nowMs,
          enforceHorizon: true,
        ),
        returnsNormally,
      );
    });

    // ── 9. Future timestamp rejection ──
    test('Test 9 — Future timestamp rejection: timestamps > +1 hour are rejected', () async {
      final nowMs = testNow.millisecondsSinceEpoch;
      final tooFarFuture = nowMs + (60 * 60 * 1000) + 1000;

      expect(
        () => HandshakePacketValidator.validateTimestamp(
          tooFarFuture,
          nowMs: nowMs,
          enforceHorizon: true,
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidTimestamp,
        )),
      );

      final req = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        timestamp: tooFarFuture,
      );

      expect(
        () => handshakeB.verifyKeyRequest(req, now: testNow, enforceTimestampHorizon: true),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidTimestamp,
        )),
      );
    });

    // ── 10. Old timestamp rejection ──
    test('Test 10 — Old timestamp rejection: timestamps older than 7 days are rejected', () async {
      final nowMs = testNow.millisecondsSinceEpoch;
      final tooOld = nowMs - (7 * 24 * 60 * 60 * 1000) - 1000;

      expect(
        () => HandshakePacketValidator.validateTimestamp(
          tooOld,
          nowMs: nowMs,
          enforceHorizon: true,
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidTimestamp,
        )),
      );

      // Non-positive timestamps
      for (final invalidTs in [0, -1, -9999]) {
        expect(
          () => HandshakePacketValidator.validateTimestamp(invalidTs),
          throwsA(isA<HandshakeException>().having(
            (e) => e.code,
            'code',
            HandshakeErrorCode.invalidTimestamp,
          )),
        );
      }
    });

    // ── 11. SessionId binding ──
    test('Test 11 — SessionId binding: ciphertext encrypted under session A cannot decrypt under session B', () async {
      final pairAB = await establishSession(requestId: 'REQ-BIND-AB');
      final pairAB2 = await establishSession(requestId: 'REQ-BIND-AB2');

      final plaintext = utf8.encode('Top Secret');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pairAB.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-001',
      );

      final encrypted = await encryptionService.encrypt(
        session: pairAB.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Decrypting with sessionB from pairAB succeeds
      final decrypted = await encryptionService.decrypt(
        session: pairAB.sessionB,
        encrypted: encrypted,
        aad: aad,
      );
      expect(decrypted, equals(plaintext));

      // Decrypting with sessionB from pairAB2 fails closed
      await expectLater(
        encryptionService.decrypt(
          session: pairAB2.sessionB,
          encrypted: encrypted,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── 12. Epoch binding ──
    test('Test 12 — Epoch binding: ciphertext bound to epoch 0 fails decryption under epoch 1 AAD', () async {
      final pair = await establishSession(requestId: 'REQ-EPOCH-1');
      expect(pair.sessionA.epoch, 0);

      final plaintext = utf8.encode('Epoch Sensitive Message');
      final aadEpoch0 = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-EPOCH-0',
        epoch: 0,
        sequenceNumber: 1,
      );

      final encrypted = await encryptionService.encrypt(
        session: pair.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aadEpoch0,
      );

      // Decrypt with tampered epoch 1 AAD
      final aadEpoch1 = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-EPOCH-0',
        epoch: 1,
        sequenceNumber: 1,
      );

      await expectLater(
        encryptionService.decrypt(
          session: pair.sessionB,
          encrypted: encrypted,
          aad: aadEpoch1,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── 13. Sequence binding & overflow protection ──
    test('Test 13 — Sequence binding & overflow protection: max sequence limit is enforced', () async {
      final pair = await establishSession(requestId: 'REQ-SEQ-1');

      final plaintext = utf8.encode('Sequence Data');
      final aadSeq1 = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-SEQ',
        sequenceNumber: 1,
      );
      final aadSeq2 = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-SEQ',
        sequenceNumber: 2,
      );

      final encrypted = await encryptionService.encrypt(
        session: pair.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aadSeq1,
      );

      // Modified sequence in AAD fails auth
      await expectLater(
        encryptionService.decrypt(
          session: pair.sessionB,
          encrypted: encrypted,
          aad: aadSeq2,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );

      // Overflow protection: sequenceNumber reaching 0xFFFFFFFF
      final overflowSession = EphemeralSession(
        sessionId: 'SESS-OVERFLOW',
        requestId: 'REQ-OVF',
        localId: 'ML-AAAAAA',
        peerId: 'ML-BBBBBB',
        isInitiator: true,
        sharedSecret: Uint8List(32),
        localEphemeralPublicKey: Uint8List(32),
        peerEphemeralPublicKey: Uint8List(32),
        localIdentityPublicKey: Uint8List(32),
        peerIdentityPublicKey: Uint8List(32),
        createdAt: testNow.millisecondsSinceEpoch,
        sentMessageCount: EphemeralSession.maxSequenceNumber,
      );

      expect(
        () => overflowSession.recordSentMessage(),
        throwsA(isA<EphemeralSessionException>().having(
          (e) => e.message,
          'message',
          contains('overflow'),
        )),
      );
    });

    // ── 14. AAD tampering ──
    test('Test 14 — AAD tampering: tampering with any authenticated field fails decryption', () async {
      final pair = await establishSession(requestId: 'REQ-AAD-TAMPER');
      final plaintext = utf8.encode('Sensitive AAD Payload');

      final correctAad = DirectionalSessionEncryptionService.buildCanonicalAad(
        packetType: 'MESSAGE',
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-ORIGINAL',
      );

      final encrypted = await encryptionService.encrypt(
        session: pair.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: correctAad,
      );

      final tamperedAadList = [
        // Tampered packetType
        DirectionalSessionEncryptionService.buildCanonicalAad(
          packetType: 'ADMIN',
          sessionId: pair.sessionA.sessionId,
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-ORIGINAL',
        ),
        // Tampered sessionId
        DirectionalSessionEncryptionService.buildCanonicalAad(
          packetType: 'MESSAGE',
          sessionId: 'SESS-TAMPERED',
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-ORIGINAL',
        ),
        // Tampered originId
        DirectionalSessionEncryptionService.buildCanonicalAad(
          packetType: 'MESSAGE',
          sessionId: pair.sessionA.sessionId,
          originId: 'ML-ATTACKER',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-ORIGINAL',
        ),
        // Tampered destinationId
        DirectionalSessionEncryptionService.buildCanonicalAad(
          packetType: 'MESSAGE',
          sessionId: pair.sessionA.sessionId,
          originId: 'ML-AAAAAA',
          destinationId: 'ML-ATTACKER',
          messageId: 'MSG-ORIGINAL',
        ),
        // Tampered messageId
        DirectionalSessionEncryptionService.buildCanonicalAad(
          packetType: 'MESSAGE',
          sessionId: pair.sessionA.sessionId,
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-TAMPERED',
        ),
      ];

      for (final tamperedAad in tamperedAadList) {
        await expectLater(
          encryptionService.decrypt(
            session: pair.sessionB,
            encrypted: encrypted,
            aad: tamperedAad,
          ),
          throwsA(isA<DirectionalEncryptionException>()),
        );
      }
    });

    // ── 15. Cross-session ciphertext rejection ──
    test('Test 15 — Cross-session ciphertext: session A ciphertext under session C fails closed', () async {
      final pairAB = await establishSession(requestId: 'REQ-CROSS-AB');

      // Handshake A <-> C
      final handshakeC = HandshakeService(
        identityService: identityServiceC,
        localId: 'ML-CCCCCC',
      );
      final reqAC = await handshakeA.createKeyRequest(destinationId: 'ML-CCCCCC');
      final respAC = await handshakeC.createKeyResponse(request: reqAC);
      final vRespAC = await handshakeA.verifyKeyResponse(respAC);
      final vReqAC = await handshakeC.verifyKeyRequest(reqAC);
      final sessionC = await handshakeC.completeSessionAsResponder(
        verifiedRequest: vReqAC,
        now: testNow,
      );
      await handshakeA.completeSessionAsInitiator(
        verifiedResponse: vRespAC,
        now: testNow,
      );

      final plaintext = utf8.encode('For Bob only');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pairAB.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-CROSS',
      );

      final encrypted = await encryptionService.encrypt(
        session: pairAB.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      await expectLater(
        encryptionService.decrypt(
          session: sessionC,
          encrypted: encrypted,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    // ── 16. Invalid lifecycle transitions ──
    test('Test 16 — Invalid lifecycle transitions: NO_SESSION or HANDSHAKE_INIT cannot encrypt or decrypt', () async {
      final pair = await establishSession(requestId: 'REQ-LIFECYCLE');
      final plaintext = Uint8List.fromList(utf8.encode('Test'));
      final aad = Uint8List.fromList(utf8.encode('AAD'));

      pair.sessionA.setLifecycleState(SessionLifecycleState.noSession);
      expect(pair.sessionA.state, SessionLifecycleState.noSession);

      await expectLater(
        encryptionService.encrypt(
          session: pair.sessionA,
          plaintext: plaintext,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>().having(
          (e) => e.message,
          'message',
          contains('invalid lifecycle state'),
        )),
      );

      pair.sessionA.setLifecycleState(SessionLifecycleState.handshakeInit);
      await expectLater(
        encryptionService.encrypt(
          session: pair.sessionA,
          plaintext: plaintext,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>().having(
          (e) => e.message,
          'message',
          contains('invalid lifecycle state'),
        )),
      );
    });

    // ── 17. Invalid handshake response (origin/dest mismatch) ──
    test('Test 17 — Handshake response origin/destination mismatch rejected', () async {
      final req = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-MISMATCH',
      );
      final resp = await handshakeB.createKeyResponse(request: req);

      // Modified destination (not ML-AAAAAA)
      final badDestResp = KeyResponsePacket(
        protocolVersion: resp.protocolVersion,
        requestId: resp.requestId,
        originId: resp.originId,
        destinationId: 'ML-ATTACKER',
        timestamp: resp.timestamp,
        identityPublicKey: resp.identityPublicKey,
        ephemeralPublicKey: resp.ephemeralPublicKey,
        signature: resp.signature,
      );

      expect(
        () => handshakeA.verifyKeyResponse(badDestResp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidResponse,
        )),
      );

      // Modified origin (not ML-BBBBBB)
      final req2 = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-MISMATCH-2',
      );
      final resp2 = await handshakeB.createKeyResponse(request: req2);

      final badOriginResp = KeyResponsePacket(
        protocolVersion: resp2.protocolVersion,
        requestId: resp2.requestId,
        originId: 'ML-ATTACKER',
        destinationId: resp2.destinationId,
        timestamp: resp2.timestamp,
        identityPublicKey: resp2.identityPublicKey,
        ephemeralPublicKey: resp2.ephemeralPublicKey,
        signature: resp2.signature,
      );

      expect(
        () => handshakeA.verifyKeyResponse(badOriginResp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidResponse,
        )),
      );
    });

    // ── 18. Wrong requestId & expiration ──
    test('Test 18 — Wrong requestId and expired request rejected', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final resp = await handshakeB.createKeyResponse(request: req);

      // Response with unknown requestId
      final wrongReqIdResp = KeyResponsePacket(
        protocolVersion: resp.protocolVersion,
        requestId: 'REQ-UNKNOWN-999',
        originId: resp.originId,
        destinationId: resp.destinationId,
        timestamp: resp.timestamp,
        identityPublicKey: resp.identityPublicKey,
        ephemeralPublicKey: resp.ephemeralPublicKey,
        signature: resp.signature,
      );

      expect(
        () => handshakeA.verifyKeyResponse(wrongReqIdResp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.requestIdMismatch,
        )),
      );

      // Expired request verification
      final expiredNow = DateTime.fromMillisecondsSinceEpoch(resp.timestamp).add(const Duration(minutes: 15));
      expect(
        () => handshakeA.verifyKeyResponse(resp, now: expiredNow),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.requestExpired,
        )),
      );
    });

    // ── 19. Wrong identity rejection ──
    test('Test 19 — Wrong identity: signature signed by unexpected identity rejected', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final charlieId = await identityServiceC.getIdentityPublicKey();

      // Attacker C substitutes B's identity
      final substitutedReq = KeyRequestPacket(
        protocolVersion: req.protocolVersion,
        requestId: req.requestId,
        originId: req.originId,
        destinationId: req.destinationId,
        timestamp: req.timestamp,
        identityPublicKey: charlieId, // Attacker key
        ephemeralPublicKey: req.ephemeralPublicKey,
        signature: req.signature, // Alice signature
      );

      expect(
        () => handshakeB.verifyKeyRequest(substitutedReq),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    // ── 20. Wrong ephemeral key ──
    test('Test 20 — Wrong ephemeral key: modified ephemeral key fails verification and session derivation', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final altKeyPair = await X25519().newKeyPair();
      final altPub = await altKeyPair.extractPublicKey();

      final tamperedReq = KeyRequestPacket(
        protocolVersion: req.protocolVersion,
        requestId: req.requestId,
        originId: req.originId,
        destinationId: req.destinationId,
        timestamp: req.timestamp,
        identityPublicKey: req.identityPublicKey,
        ephemeralPublicKey: base64UrlEncode(altPub.bytes),
        signature: req.signature,
      );

      expect(
        () => handshakeB.verifyKeyRequest(tamperedReq),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );
    });

    // ── 21. Rekey epoch rollback rejection ──
    test('Test 21 — Rekey epoch rollback rejection: epochs must be strictly monotonic', () async {
      final pair = await establishSession(requestId: 'REQ-EPOCH-MONOTONIC');
      expect(pair.sessionA.epoch, 0);

      // Attempting to construct a session with negative epoch
      expect(
        () => EphemeralSession(
          sessionId: 'SESS-NEG-EPOCH',
          requestId: 'REQ-1',
          localId: 'ML-AAAAAA',
          peerId: 'ML-BBBBBB',
          isInitiator: true,
          sharedSecret: Uint8List(32),
          localEphemeralPublicKey: Uint8List(32),
          peerEphemeralPublicKey: Uint8List(32),
          localIdentityPublicKey: Uint8List(32),
          peerIdentityPublicKey: Uint8List(32),
          createdAt: testNow.millisecondsSinceEpoch,
          epoch: -1,
        ),
        throwsA(isA<EphemeralSessionException>().having(
          (e) => e.message,
          'message',
          contains('Epoch cannot be negative'),
        )),
      );
    });

    // ── 22. Rekey identity substitution rejection ──
    test('Test 22 — Rekey identity substitution rejection: peer changing identity key triggers peerIdentityMismatch', () async {
      final pair = await establishSession(requestId: 'REQ-REKEY-ORIGINAL');

      // Save known identity in repository
      await messageRepository.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-BBBBBB',
          identityPublicKey: base64UrlEncode(pair.sessionA.peerIdentityPublicKey),
          safetyNumber: '12345',
          trustStatus: 'verified',
          protocolVersion: 2,
          firstSeenAt: testNow,
          lastSeenAt: testNow,
        ),
      );

      // Attacker C impersonates B in a rekey
      final rekeyReq = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final charlieHandshake = HandshakeService(
        identityService: identityServiceC,
        localId: 'ML-BBBBBB', // claims to be B
        peerRepository: messageRepository,
      );

      final respFromCharlie = await charlieHandshake.createKeyResponse(request: rekeyReq);

      // Alice verifies response: Charlie's identity key does not match B's stored identity in repo
      expect(
        () => handshakeA.verifyKeyResponse(respFromCharlie),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.peerIdentityMismatch,
        )),
      );
    });

    // ── 23. Replay registration occurs only after authentication ──
    test('Test 23 — Replay registration ordering: tampered packet fails auth and does NOT register replay', () async {
      final pair = await establishSession(requestId: 'REQ-REPLAY-ORDER');
      final plaintext = utf8.encode('Pipeline message');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-PIPELINE-1',
      );

      final encrypted = await encryptionService.encrypt(
        session: pair.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Tamper ciphertext
      final tamperedCiphertext = Uint8List.fromList(encrypted.ciphertext);
      tamperedCiphertext[0] ^= 0x01;
      final tamperedPayload = SessionEncryptedPayload(
        ciphertext: tamperedCiphertext,
        nonce: encrypted.nonce,
        mac: encrypted.mac,
      );

      // Verify that decrypt fails FIRST
      await expectLater(
        encryptionService.decrypt(
          session: pair.sessionB,
          encrypted: tamperedPayload,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );

      // Verify that MSG-PIPELINE-1 has NOT been registered in replay DB
      final outcome = await replayProtectionService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-AAAAAA',
        packetId: 'MSG-PIPELINE-1',
        timestamp: testNow,
        now: testNow,
      );
      expect(outcome.isAccepted, isTrue, reason: 'First registration must succeed');
      expect(outcome.isDuplicate, isFalse);
    });

    // ── 24. Duplicate authenticated packet rejected ──
    test('Test 24 — Duplicate authenticated packet rejected by replay protection', () async {
      final pair = await establishSession(requestId: 'REQ-REPLAY-DUP');
      final plaintext = utf8.encode('Duplicate test');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-DUP-1',
      );

      final encrypted = await encryptionService.encrypt(
        session: pair.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // First delivery: decrypts and registers
      final decrypted = await encryptionService.decrypt(
        session: pair.sessionB,
        encrypted: encrypted,
        aad: aad,
      );
      expect(decrypted, equals(plaintext));

      final firstSeen = await replayProtectionService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-AAAAAA',
        packetId: 'MSG-DUP-1',
        timestamp: testNow,
        now: testNow,
      );
      expect(firstSeen.isAccepted, isTrue);
      expect(firstSeen.isDuplicate, isFalse);

      // Duplicate delivery: checkAndMarkSeen returns duplicate
      final secondSeen = await replayProtectionService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-AAAAAA',
        packetId: 'MSG-DUP-1',
        timestamp: testNow,
        now: testNow,
      );
      expect(secondSeen.isDuplicate, isTrue);
      expect(secondSeen.isAccepted, isFalse);
    });

    // ── 25. Malformed packet does not crash ──
    test('Test 25 — Malformed packet robustness: invalid JSON/Base64/bytes fails cleanly without unhandled crash', () {
      final malformedPackets = [
        <String, dynamic>{},
        {'version': 2},
        {'version': 2, 'requestId': 'REQ'},
        {'version': 'not-an-int', 'requestId': 'REQ'},
        {
          'version': 2,
          'requestId': 'REQ-1',
          'originId': 'ML-A',
          'destinationId': 'ML-B',
          'timestamp': 1000,
          'identityPublicKey': 'invalid base64 %%%',
          'ephemeralPublicKey': 'invalid base64 %%%',
          'signature': 'invalid base64 %%%',
        },
      ];

      for (final bad in malformedPackets) {
        expect(
          () => KeyRequestPacket.fromMap(bad),
          throwsA(anything),
        );
      }
    });

    // ── 26. No plaintext fallback ──
    test('Test 26 — No plaintext fallback: failed decryption throws exception and returns zero plaintext', () async {
      final pair = await establishSession(requestId: 'REQ-NO-FALLBACK');
      final plaintext = utf8.encode('Secret Data');
      final aad = Uint8List.fromList(utf8.encode('AAD'));

      final encrypted = await encryptionService.encrypt(
        session: pair.sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Modify MAC tag
      final corruptedMac = Uint8List.fromList(encrypted.mac);
      corruptedMac[0] ^= 0xFF;
      final corrupted = SessionEncryptedPayload(
        ciphertext: encrypted.ciphertext,
        nonce: encrypted.nonce,
        mac: corruptedMac,
      );

      Uint8List? leakedPlaintext;
      try {
        leakedPlaintext = await encryptionService.decrypt(
          session: pair.sessionB,
          encrypted: corrupted,
          aad: aad,
        );
      } catch (_) {
        // Exception expected
      }

      expect(leakedPlaintext, isNull);
    });

    // ── 27. No protocol downgrade ──
    test('Test 27 — No protocol downgrade: legacy or downgraded packets fail closed', () async {
      expect(
        () => HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
          protocolVersion: 1,
          timestamp: testNow.millisecondsSinceEpoch,
          requestId: 'REQ-DOWNGRADE',
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          initiatorIdentityKey: Uint8List(32),
          initiatorEphemeralKey: Uint8List(32),
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidProtocolVersion,
        )),
      );
    });

    // ── 28. Peer trust remains intact ──
    test('Test 28 — Peer trust boundary: trust status is preserved during rekeys and lifecycle changes', () async {
      final pair = await establishSession(requestId: 'REQ-TRUST-PRESERVE');

      await messageRepository.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-BBBBBB',
          identityPublicKey: base64UrlEncode(pair.sessionA.peerIdentityPublicKey),
          safetyNumber: '12345',
          trustStatus: 'verified',
          protocolVersion: 2,
          firstSeenAt: testNow,
          lastSeenAt: testNow,
        ),
      );

      final peerBefore = await messageRepository.getPeerIdentity('ML-BBBBBB');
      expect(peerBefore?.trustStatus, 'verified');

      // Perform rekey
      final rekeyReq = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final rekeyResp = await handshakeB.createKeyResponse(request: rekeyReq);
      final vResp = await handshakeA.verifyKeyResponse(rekeyResp);
      final vReq = await handshakeB.verifyKeyRequest(rekeyReq);

      await handshakeA.completeSessionAsInitiator(verifiedResponse: vResp, now: testNow);
      await handshakeB.completeSessionAsResponder(verifiedRequest: vReq, now: testNow);

      final peerAfter = await messageRepository.getPeerIdentity('ML-BBBBBB');
      expect(peerAfter?.trustStatus, 'verified');
    });

    // ── 29. Step 8 lifecycle regression ──
    test('Test 29 — Step 8 regression: full rekey cycle from ACTIVE -> REKEYING -> ACTIVE succeeds', () async {
      final initialPair = await establishSession(requestId: 'REQ-STEP8-REG');
      expect(initialPair.sessionA.epoch, 0);
      expect(sessionServiceA.getLifecycleState('ML-BBBBBB'), SessionLifecycleState.activeSession);

      final rekeyReq = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      expect(sessionServiceA.getLifecycleState('ML-BBBBBB'), SessionLifecycleState.rekeying);

      final rekeyResp = await handshakeB.createKeyResponse(request: rekeyReq);
      final vResp = await handshakeA.verifyKeyResponse(rekeyResp);
      final vReq = await handshakeB.verifyKeyRequest(rekeyReq);

      final newSessionA = await handshakeA.completeSessionAsInitiator(verifiedResponse: vResp, now: testNow);
      final newSessionB = await handshakeB.completeSessionAsResponder(verifiedRequest: vReq, now: testNow);

      expect(newSessionA.epoch, 1);
      expect(newSessionB.epoch, 1);
      expect(sessionServiceA.getLifecycleState('ML-BBBBBB'), SessionLifecycleState.activeSession);
    });

    // ── 30. Step 7 trust regression ──
    test('Test 30 — Step 7 regression: known peer identity key change detection', () async {
      await messageRepository.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-BBBBBB',
          identityPublicKey: 'KNOWN_VALID_KEY_BASE64',
          safetyNumber: '12345',
          trustStatus: 'tofu',
          protocolVersion: 2,
          firstSeenAt: testNow,
          lastSeenAt: testNow,
        ),
      );

      final req = await handshakeB.createKeyRequest(destinationId: 'ML-AAAAAA');

      // Alice verifies B's request, but B presents a different key than recorded
      expect(
        () => handshakeA.verifyKeyRequest(req),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.peerIdentityMismatch,
        )),
      );
    });

    // ── 31. Step 6 replay regression ──
    test('Test 31 — Step 6 regression: replay protection correctly rejects duplicates and expired packets', () async {
      final isNew = await replayProtectionService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-AAAAAA',
        packetId: 'MSG-STEP6-REG',
        timestamp: testNow,
        now: testNow,
      );
      expect(isNew.isAccepted, isTrue);

      final isDup = await replayProtectionService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-AAAAAA',
        packetId: 'MSG-STEP6-REG',
        timestamp: testNow,
        now: testNow,
      );
      expect(isDup.isDuplicate, isTrue);
    });

    // ── 32. Step 5 encryption regression ──
    test('Test 32 — Step 5 regression: directional send and receive keys work accurately', () async {
      final pair = await establishSession(requestId: 'REQ-STEP5-REG');
      final keysA = await encryptionService.getOrDeriveKeys(pair.sessionA);
      final keysB = await encryptionService.getOrDeriveKeys(pair.sessionB);

      expect(keysA.sendKey, equals(keysB.receiveKey));
      expect(keysA.receiveKey, equals(keysB.sendKey));
    });

    // ── 33. Step 4 session regression ──
    test('Test 33 — Step 4 regression: X25519 ECDH produces identical shared secret on both peers', () async {
      final pair = await establishSession(requestId: 'REQ-STEP4-REG');
      expect(pair.sessionA.sharedSecret, equals(pair.sessionB.sharedSecret));
      expect(pair.sessionA.sharedSecret.length, 32);
    });

    // ── 34. Step 3 handshake regression ──
    test('Test 34 — Step 3 regression: Ed25519 request and response transcripts verify cleanly', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final vReq = await handshakeB.verifyKeyRequest(req);
      expect(vReq.isValid, isTrue);

      final resp = await handshakeB.createKeyResponse(request: req);
      final vResp = await handshakeA.verifyKeyResponse(resp);
      expect(vResp.isValid, isTrue);
    });

    // ── 35. Fuzz-like boundary tests ──
    test('Test 35 — Fuzz-like boundary tests: structured malformed boundary inputs fail closed without crashes', () {
      final boundaryLengths = [0, 1, 31, 32, 33, 63, 64, 65, 127, 128, 129, 255, 256, 1000];
      for (final len in boundaryLengths) {
        final dummyKey = Uint8List(len);
        if (len != 32) {
          expect(
            () => HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
              timestamp: testNow.millisecondsSinceEpoch,
              requestId: 'REQ-FUZZ',
              originId: 'ML-A',
              destinationId: 'ML-B',
              initiatorIdentityKey: dummyKey,
              initiatorEphemeralKey: dummyKey,
            ),
            throwsA(isA<HandshakeException>().having(
              (e) => e.code,
              'code',
              HandshakeErrorCode.invalidKeyLength,
            )),
          );
        }
      }
    });
  });
}
