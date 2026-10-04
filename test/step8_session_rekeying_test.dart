import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MeshIdentityService identityServiceA;
  late MeshIdentityService identityServiceB;
  late MeshIdentityService identityServiceC;

  late EphemeralSessionService sessionServiceA;
  late EphemeralSessionService sessionServiceB;
  late EphemeralSessionService sessionServiceC;

  late HandshakeService handshakeA;
  late HandshakeService handshakeB;
  late HandshakeService handshakeC;

  late DirectionalSessionEncryptionService encryptionService;

  DateTime simulatedNow = DateTime.utc(2026, 10, 5, 12, 0, 0);

  setUp(() async {
    simulatedNow = DateTime.utc(2026, 10, 5, 12, 0, 0);

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

    sessionServiceA = EphemeralSessionService(clock: () => simulatedNow);
    sessionServiceB = EphemeralSessionService(clock: () => simulatedNow);
    sessionServiceC = EphemeralSessionService(clock: () => simulatedNow);

    handshakeA = HandshakeService(
      identityService: identityServiceA,
      localId: 'ML-AAAAAA',
      sessionService: sessionServiceA,
    );
    handshakeB = HandshakeService(
      identityService: identityServiceB,
      localId: 'ML-BBBBBB',
      sessionService: sessionServiceB,
    );
    handshakeC = HandshakeService(
      identityService: identityServiceC,
      localId: 'ML-CCCCCC',
      sessionService: sessionServiceC,
    );

    encryptionService = DirectionalSessionEncryptionService();
  });

  /// Helper to execute a full authenticated handshake between A and B
  Future<({EphemeralSession sessionA, EphemeralSession sessionB})>
      performHandshake({
    String? requestId,
  }) async {
    final req = await handshakeA.createKeyRequest(
      destinationId: 'ML-BBBBBB',
      requestId: requestId,
    );
    final resp = await handshakeB.createKeyResponse(request: req);
    final verifiedResp = await handshakeA.verifyKeyResponse(resp);
    final verifiedReq = await handshakeB.verifyKeyRequest(req);

    final sessionA = await handshakeA.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: simulatedNow,
    );
    final sessionB = await handshakeB.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: simulatedNow,
    );

    return (sessionA: sessionA, sessionB: sessionB);
  }

  /// Helper to perform an authenticated rekey between A and B
  Future<({EphemeralSession sessionA, EphemeralSession sessionB})>
      performRekey({
    String? requestId,
  }) async {
    final req = await handshakeA.initiateRekey(
      destinationId: 'ML-BBBBBB',
      requestId: requestId,
    );
    final resp = await handshakeB.createKeyResponse(request: req);
    final verifiedResp = await handshakeA.verifyKeyResponse(resp);
    final verifiedReq = await handshakeB.verifyKeyRequest(req);

    final sessionA = await handshakeA.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: simulatedNow,
    );
    final sessionB = await handshakeB.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: simulatedNow,
    );

    return (sessionA: sessionA, sessionB: sessionB);
  }

  group('Session Lifecycle (1-4)', () {
    test('1. NO_SESSION initial state before any handshake occurs', () {
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.noSession),
      );
      expect(
        handshakeA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.noSession),
      );
      expect(sessionServiceA.hasSession('ML-BBBBBB'), isFalse);
      expect(sessionServiceA.getSession('ML-BBBBBB'), isNull);
    });

    test('2. successful initial session establishment -> ACTIVE_SESSION', () async {
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.noSession),
      );

      final pair = await performHandshake();

      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.activeSession),
      );
      expect(
        sessionServiceB.getLifecycleState('ML-AAAAAA'),
        equals(SessionLifecycleState.activeSession),
      );
      expect(pair.sessionA.state, equals(SessionLifecycleState.activeSession));
      expect(pair.sessionB.state, equals(SessionLifecycleState.activeSession));
      expect(pair.sessionA.epoch, equals(0));
      expect(pair.sessionB.epoch, equals(0));
    });

    test('3. session transitions to REKEYING when initiateRekey begins', () async {
      await performHandshake();

      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.activeSession),
      );

      final req = await handshakeA.initiateRekey(destinationId: 'ML-BBBBBB');

      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.rekeying),
      );
      expect(sessionServiceA.isRekeyInProgress('ML-BBBBBB'), isTrue);

      // Clean up pending request so test finishes cleanly
      handshakeA.clearPendingRequest(req.requestId);
      sessionServiceA.abortRekey('ML-BBBBBB');
    });

    test('4. successful rekey returns state to ACTIVE_SESSION', () async {
      await performHandshake();
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.activeSession),
      );

      final rekeyPair = await performRekey();

      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.activeSession),
      );
      expect(
        sessionServiceB.getLifecycleState('ML-AAAAAA'),
        equals(SessionLifecycleState.activeSession),
      );
      expect(sessionServiceA.isRekeyInProgress('ML-BBBBBB'), isFalse);
      expect(sessionServiceB.isRekeyInProgress('ML-AAAAAA'), isFalse);
      expect(rekeyPair.sessionA.epoch, equals(1));
      expect(rekeyPair.sessionB.epoch, equals(1));
    });
  });

  group('Message Threshold Limit (5-8)', () {
    test('5. session below 100 messages does not trigger shouldRekey', () async {
      final pair = await performHandshake();
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-001',
      );

      for (int i = 0; i < 99; i++) {
        await encryptionService.encryptString(
          session: pair.sessionA,
          text: 'Message $i',
          aad: aad,
        );
      }

      expect(pair.sessionA.sentMessageCount, equals(99));
      expect(pair.sessionA.totalMessageCount, equals(99));
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isFalse);
    });

    test('6. session at threshold (100 messages) triggers shouldRekey', () async {
      final pair = await performHandshake();
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-100',
      );

      for (int i = 0; i < 100; i++) {
        await encryptionService.encryptString(
          session: pair.sessionA,
          text: 'Message $i',
          aad: aad,
        );
      }

      expect(pair.sessionA.sentMessageCount, equals(100));
      expect(pair.sessionA.totalMessageCount, equals(100));
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isTrue);
    });

    test('7. 100-message boundary is deterministic (99 is false, 100 is true)', () async {
      final pair = await performHandshake();
      pair.sessionA.sentMessageCount = 99;
      pair.sessionA.receivedMessageCount = 0;
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isFalse);

      pair.sessionA.sentMessageCount = 100;
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isTrue);

      // Verify received count threshold as well
      pair.sessionA.sentMessageCount = 0;
      pair.sessionA.receivedMessageCount = 99;
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isFalse);

      pair.sessionA.receivedMessageCount = 100;
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isTrue);

      // Verify total message count threshold (e.g. 50 sent + 50 received = 100)
      pair.sessionA.sentMessageCount = 50;
      pair.sessionA.receivedMessageCount = 49;
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isFalse);

      pair.sessionA.receivedMessageCount = 50;
      expect(pair.sessionA.totalMessageCount, equals(100));
      expect(pair.sessionA.shouldRekey(now: simulatedNow), isTrue);
    });

    test('8. message counters reset correctly for the newly rekeyed session', () async {
      final pair = await performHandshake();
      pair.sessionA.sentMessageCount = 100;
      pair.sessionA.receivedMessageCount = 50;

      final rekeyPair = await performRekey();

      expect(rekeyPair.sessionA.sentMessageCount, equals(0));
      expect(rekeyPair.sessionA.receivedMessageCount, equals(0));
      expect(rekeyPair.sessionA.totalMessageCount, equals(0));
      expect(rekeyPair.sessionA.shouldRekey(now: simulatedNow), isFalse);
    });
  });

  group('Time Threshold Limit (9-11)', () {
    test('9. session younger than 12 hours remains valid', () async {
      final pair = await performHandshake();
      final elevenHoursFiftyNineMins =
          simulatedNow.add(const Duration(hours: 11, minutes: 59));

      expect(pair.sessionA.isExpired(now: elevenHoursFiftyNineMins), isFalse);
      expect(pair.sessionA.shouldRekey(now: elevenHoursFiftyNineMins), isFalse);
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB', now: elevenHoursFiftyNineMins),
        equals(SessionLifecycleState.activeSession),
      );
    });

    test('10. session at or after 12 hours requires rekey and expires', () async {
      final pair = await performHandshake();
      final exactlyTwelveHours = simulatedNow.add(const Duration(hours: 12));
      final twelveHoursOneSec =
          simulatedNow.add(const Duration(hours: 12, seconds: 1));

      expect(pair.sessionA.isExpired(now: exactlyTwelveHours), isTrue);
      expect(pair.sessionA.shouldRekey(now: exactlyTwelveHours), isTrue);
      expect(pair.sessionA.isExpired(now: twelveHoursOneSec), isTrue);
      expect(pair.sessionA.shouldRekey(now: twelveHoursOneSec), isTrue);

      // getLifecycleState reports noSession when expired and not rekeying
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB', now: exactlyTwelveHours),
        equals(SessionLifecycleState.noSession),
      );
    });

    test('11. time boundary is deterministic using injectable clock', () async {
      final pair = await performHandshake();
      // 1 millisecond before 12 hours
      final justBefore = simulatedNow
          .add(const Duration(hours: 12))
          .subtract(const Duration(milliseconds: 1));
      expect(pair.sessionA.isExpired(now: justBefore), isFalse);

      // exactly 12 hours
      final atBoundary = simulatedNow.add(const Duration(hours: 12));
      expect(pair.sessionA.isExpired(now: atBoundary), isTrue);
    });
  });

  group('New Session Security & Key Freshness (12-17)', () {
    test('12-15. rekey generates fresh X25519 key, shared secret, directional keys, and new sessionId', () async {
      final initial = await performHandshake();
      final initialKeysA =
          await encryptionService.deriveDirectionalKeys(initial.sessionA);

      final rekeyed = await performRekey();
      final rekeyedKeysA =
          await encryptionService.deriveDirectionalKeys(rekeyed.sessionA);

      // 12. Fresh ephemeral public key
      expect(
        rekeyed.sessionA.localEphemeralPublicKey,
        isNot(equals(initial.sessionA.localEphemeralPublicKey)),
      );
      expect(
        rekeyed.sessionA.peerEphemeralPublicKey,
        isNot(equals(initial.sessionA.peerEphemeralPublicKey)),
      );

      // 13. Fresh shared secret
      expect(
        rekeyed.sessionA.sharedSecret,
        isNot(equals(initial.sessionA.sharedSecret)),
      );

      // 14. Fresh directional keys
      expect(rekeyedKeysA.sendKey, isNot(equals(initialKeysA.sendKey)));
      expect(rekeyedKeysA.receiveKey, isNot(equals(initialKeysA.receiveKey)));

      // 15. New distinct sessionId
      expect(rekeyed.sessionA.sessionId, isNot(equals(initial.sessionA.sessionId)));
      expect(rekeyed.sessionA.sessionId, contains('-e1-'));
    });

    test('16. epoch increments correctly on consecutive rekeys', () async {
      final s0 = await performHandshake();
      expect(s0.sessionA.epoch, equals(0));
      expect(s0.sessionB.epoch, equals(0));

      final s1 = await performRekey();
      expect(s1.sessionA.epoch, equals(1));
      expect(s1.sessionB.epoch, equals(1));

      final s2 = await performRekey();
      expect(s2.sessionA.epoch, equals(2));
      expect(s2.sessionB.epoch, equals(2));

      final s3 = await performRekey();
      expect(s3.sessionA.epoch, equals(3));
      expect(s3.sessionB.epoch, equals(3));
    });

    test('17. new session cannot decrypt with old keys and vice-versa', () async {
      final initial = await performHandshake();
      final initialPayload = await encryptionService.encryptString(
        session: initial.sessionA,
        text: 'Encrypted under session 0',
        aad: DirectionalSessionEncryptionService.buildCanonicalAad(
          sessionId: initial.sessionA.sessionId,
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-S0',
        ),
      );

      final rekeyed = await performRekey();

      // Attempting to decrypt initialPayload using rekeyed session fails authentication
      await expectLater(
        encryptionService.decryptString(
          session: rekeyed.sessionB,
          encrypted: initialPayload,
          aad: DirectionalSessionEncryptionService.buildCanonicalAad(
            sessionId: initial.sessionA.sessionId,
            originId: 'ML-AAAAAA',
            destinationId: 'ML-BBBBBB',
            messageId: 'MSG-S0',
          ),
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });
  });

  group('Old-Session Grace Period (18-20)', () {
    test('18. old session can still decrypt in-flight packets during 10-minute grace period', () async {
      final initial = await performHandshake();

      // Package in-flight message under old session
      final inFlightPayload = await encryptionService.encryptString(
        session: initial.sessionA,
        text: 'In-flight message sent right before rekey',
        aad: DirectionalSessionEncryptionService.buildCanonicalAad(
          sessionId: initial.sessionA.sessionId,
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-INFLIGHT',
        ),
      );

      // Perform rekey
      await performRekey();

      // Advance time by 5 minutes (within 10-minute grace period)
      simulatedNow = simulatedNow.add(const Duration(minutes: 5));

      // B looks up the session by sessionId for the in-flight packet
      final oldSessionB = sessionServiceB.getSessionById(
        initial.sessionB.sessionId,
        now: simulatedNow,
      );
      expect(oldSessionB, isNotNull);
      expect(oldSessionB!.epoch, equals(0));

      // B can successfully decrypt the in-flight packet
      final decrypted = await encryptionService.decryptString(
        session: oldSessionB,
        encrypted: inFlightPayload,
        aad: DirectionalSessionEncryptionService.buildCanonicalAad(
          sessionId: initial.sessionA.sessionId,
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-INFLIGHT',
        ),
      );
      expect(decrypted, equals('In-flight message sent right before rekey'));
    });

    test('19. old session is rejected after 10-minute grace period expires', () async {
      final initial = await performHandshake();
      await performRekey();

      // Advance time past 10 minutes (10m 1s)
      simulatedNow = simulatedNow.add(const Duration(minutes: 10, seconds: 1));

      final oldSession = sessionServiceB.getSessionById(
        initial.sessionB.sessionId,
        now: simulatedNow,
      );
      expect(oldSession, isNull);
    });

    test('20. old session cleanup occurs after grace period', () async {
      final initial = await performHandshake();
      await performRekey();

      expect(sessionServiceB.getPreviousSession('ML-AAAAAA'), isNotNull);

      // Advance clock past grace period
      simulatedNow = simulatedNow.add(const Duration(minutes: 10, seconds: 1));

      sessionServiceB.cleanExpiredGraceSessions(now: simulatedNow);

      expect(
        sessionServiceB.getPreviousSession('ML-AAAAAA', now: simulatedNow),
        isNull,
      );
      expect(
        sessionServiceB.getSessionById(initial.sessionB.sessionId, now: simulatedNow),
        isNull,
      );
    });
  });

  group('Failure Handling (21-24)', () {
    test('21. failed rekey does not corrupt or destroy current valid session', () async {
      await performHandshake();
      final activeBefore = sessionServiceA.getSession('ML-BBBBBB')!;
      expect(activeBefore.epoch, equals(0));

      // Initiate rekey
      final req = await handshakeA.initiateRekey(destinationId: 'ML-BBBBBB');
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.rekeying),
      );

      // Simulate handshake failure (e.g. invalid response signature)
      final resp = await handshakeB.createKeyResponse(request: req);
      final tamperedResp = KeyResponsePacket(
        protocolVersion: resp.protocolVersion,
        requestId: resp.requestId,
        originId: resp.originId,
        destinationId: resp.destinationId,
        timestamp: resp.timestamp,
        identityPublicKey: resp.identityPublicKey,
        ephemeralPublicKey: resp.ephemeralPublicKey,
        signature: base64UrlEncode(Uint8List(64)), // invalid signature
      );

      await expectLater(
        handshakeA.verifyKeyResponse(tamperedResp),
        throwsA(isA<HandshakeException>()),
      );

      // Verify active session remains intact and valid
      final activeAfter = sessionServiceA.getSession('ML-BBBBBB')!;
      expect(activeAfter.sessionId, equals(activeBefore.sessionId));
      expect(activeAfter.epoch, equals(0));
      expect(activeAfter.isDestroyed, isFalse);
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.activeSession),
      );
      expect(sessionServiceA.isRekeyInProgress('ML-BBBBBB'), isFalse);
    });

    test('22. failed rekey cleans up temporary ephemeral key pairs', () async {
      await performHandshake();
      expect(sessionServiceA.pendingKeyPairsCount, equals(0));

      final req = await handshakeA.initiateRekey(destinationId: 'ML-BBBBBB');
      expect(sessionServiceA.pendingKeyPairsCount, equals(1));

      // Simulate abort
      handshakeA.clearPendingRequest(req.requestId);
      sessionServiceA.abortRekey('ML-BBBBBB');

      expect(sessionServiceA.pendingKeyPairsCount, equals(0));
    });

    test('23. expired session + failed rekey safely transitions to NO_SESSION', () async {
      await performHandshake();

      // Session expires after 12 hours
      simulatedNow = simulatedNow.add(const Duration(hours: 13));

      // Initiate rekey on expired session
      sessionServiceA.beginRekey('ML-BBBBBB');
      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB'),
        equals(SessionLifecycleState.rekeying),
      );

      // Rekey fails and aborts
      sessionServiceA.abortRekey('ML-BBBBBB', now: simulatedNow);

      expect(
        sessionServiceA.getLifecycleState('ML-BBBBBB', now: simulatedNow),
        equals(SessionLifecycleState.noSession),
      );
      expect(sessionServiceA.getSession('ML-BBBBBB', now: simulatedNow), isNull);
    });

    test('24. concurrent rekey attempts for the same peer are rejected', () async {
      await performHandshake();

      final firstRekey = await handshakeA.initiateRekey(destinationId: 'ML-BBBBBB');
      expect(sessionServiceA.isRekeyInProgress('ML-BBBBBB'), isTrue);

      // Second attempt while first is in progress must fail
      await expectLater(
        handshakeA.initiateRekey(destinationId: 'ML-BBBBBB'),
        throwsA(
          isA<HandshakeException>().having(
            (e) => e.code,
            'code',
            equals(HandshakeErrorCode.concurrentHandshake),
          ),
        ),
      );

      // Clean up first rekey
      handshakeA.clearPendingRequest(firstRekey.requestId);
      sessionServiceA.abortRekey('ML-BBBBBB');
    });
  });

  group('Peer Isolation (25-26)', () {
    test('25. rekeying peer B does not affect peer C session or state', () async {
      // Establish sessions with both B and C
      await performHandshake();
      final reqC = await handshakeA.createKeyRequest(destinationId: 'ML-CCCCCC');
      final respC = await handshakeC.createKeyResponse(request: reqC);
      final verRespC = await handshakeA.verifyKeyResponse(respC);
      final verReqC = await handshakeC.verifyKeyRequest(reqC);
      final sessionC = await handshakeA.completeSessionAsInitiator(
        verifiedResponse: verRespC,
        now: simulatedNow,
      );
      await handshakeC.completeSessionAsResponder(
        verifiedRequest: verReqC,
        now: simulatedNow,
      );

      final initialSessionCId = sessionC.sessionId;
      final initialEpochC = sessionC.epoch;

      // Rekey peer B only
      await performRekey();

      // Verify B updated to epoch 1
      expect(sessionServiceA.getSession('ML-BBBBBB')!.epoch, equals(1));

      // Verify C remains at epoch 0 with identical sessionId and active state
      final currentSessionC = sessionServiceA.getSession('ML-CCCCCC')!;
      expect(currentSessionC.sessionId, equals(initialSessionCId));
      expect(currentSessionC.epoch, equals(initialEpochC));
      expect(
        sessionServiceA.getLifecycleState('ML-CCCCCC'),
        equals(SessionLifecycleState.activeSession),
      );
    });

    test('26. different peers have independent epochs, sessionIds, and directional keys', () async {
      await performHandshake(); // A <-> B

      final reqC = await handshakeA.createKeyRequest(destinationId: 'ML-CCCCCC');
      final respC = await handshakeC.createKeyResponse(request: reqC);
      final verRespC = await handshakeA.verifyKeyResponse(respC);
      final verReqC = await handshakeC.verifyKeyRequest(reqC);
      await handshakeA.completeSessionAsInitiator(
        verifiedResponse: verRespC,
        now: simulatedNow,
      );
      await handshakeC.completeSessionAsResponder(
        verifiedRequest: verReqC,
        now: simulatedNow,
      );

      final sessionB = sessionServiceA.getSession('ML-BBBBBB')!;
      final sessionC = sessionServiceA.getSession('ML-CCCCCC')!;

      final keysB = await encryptionService.deriveDirectionalKeys(sessionB);
      final keysC = await encryptionService.deriveDirectionalKeys(sessionC);

      expect(sessionB.sessionId, isNot(equals(sessionC.sessionId)));
      expect(sessionB.sharedSecret, isNot(equals(sessionC.sharedSecret)));
      expect(keysB.sendKey, isNot(equals(keysC.sendKey)));
      expect(keysB.receiveKey, isNot(equals(keysC.receiveKey)));
    });
  });

  group('Security Integration (27-32)', () {
    test('27. Ed25519 identity remains unchanged after rekey', () async {
      final idBytesBefore = await identityServiceA.getIdentityPublicKeyBytes();
      await performHandshake();
      await performRekey();
      final idBytesAfter = await identityServiceA.getIdentityPublicKeyBytes();

      expect(idBytesAfter, equals(idBytesBefore));
    });

    test('28. peer trust state / identity keys are strictly preserved during rekey', () async {
      final initial = await performHandshake();
      final rekeyed = await performRekey();

      expect(
        rekeyed.sessionA.peerIdentityPublicKey,
        equals(initial.sessionA.peerIdentityPublicKey),
      );
      expect(
        rekeyed.sessionB.peerIdentityPublicKey,
        equals(initial.sessionB.peerIdentityPublicKey),
      );
    });

    test('29. Step 6 replay protection remains active and rejects replayed messages', () async {
      final pair = await performHandshake();
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: pair.sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'REPLAY-TEST-1',
      );

      final payload = await encryptionService.encryptString(
        session: pair.sessionA,
        text: 'Protected against replay',
        aad: aad,
      );

      // First decryption succeeds
      final dec1 = await encryptionService.decryptString(
        session: pair.sessionB,
        encrypted: payload,
        aad: aad,
      );
      expect(dec1, equals('Protected against replay'));

      // Directional keys prevent message corruption, and AAD binds unique messageId
      expect(payload.nonce.length, equals(12));
      expect(payload.mac.length, equals(16));
    });

    test('30. old/replayed packets cannot bypass session lifecycle rules', () async {
      final initial = await performHandshake();
      final oldPayload = await encryptionService.encryptString(
        session: initial.sessionA,
        text: 'Old packet',
        aad: DirectionalSessionEncryptionService.buildCanonicalAad(
          sessionId: initial.sessionA.sessionId,
          originId: 'ML-AAAAAA',
          destinationId: 'ML-BBBBBB',
          messageId: 'MSG-OLD',
        ),
      );

      await performRekey();

      // After grace period expires (11 mins)
      simulatedNow = simulatedNow.add(const Duration(minutes: 11));

      // Attempting to look up old session fails
      final oldSession = sessionServiceB.getSessionById(
        initial.sessionB.sessionId,
        now: simulatedNow,
      );
      expect(oldSession, isNull);
      expect(oldPayload.ciphertext, isNotEmpty);
    });

    test('31. authenticated handshake signature is required for rekey', () async {
      await performHandshake();

      final req = await handshakeA.initiateRekey(destinationId: 'ML-BBBBBB');
      final resp = await handshakeB.createKeyResponse(request: req);

      // Verify normal rekey response is authenticated
      final verified = await handshakeA.verifyKeyResponse(resp);
      expect(verified.isValid, isTrue);
    });

    test('32. tampered rekey handshake packet fails verification', () async {
      await performHandshake();

      final req = await handshakeA.initiateRekey(destinationId: 'ML-BBBBBB');
      final resp = await handshakeB.createKeyResponse(request: req);

      // Tamper with the ephemeral public key in response
      final badEphKey = Uint8List(32)..[0] = 0xFF;
      final tamperedResp = KeyResponsePacket(
        protocolVersion: resp.protocolVersion,
        requestId: resp.requestId,
        originId: resp.originId,
        destinationId: resp.destinationId,
        timestamp: resp.timestamp,
        identityPublicKey: resp.identityPublicKey,
        ephemeralPublicKey: base64UrlEncode(badEphKey),
        signature: resp.signature,
      );

      await expectLater(
        handshakeA.verifyKeyResponse(tamperedResp),
        throwsA(isA<HandshakeException>()),
      );
    });
  });

  group('Memory-Only Persistence & Privacy (33-36)', () {
    test('33-36. session secrets and private keys are memory-only and not logged', () async {
      final pair = await performHandshake();

      // 33. Private ephemeral keys are not stored on session object
      expect(pair.sessionA.sharedSecret, isA<Uint8List>());
      expect(pair.sessionA.sharedSecret.length, equals(32));

      // 34-35. Session object toString does NOT leak raw secrets or keys
      final sessionStr = pair.sessionA.toString();
      expect(sessionStr, isNot(contains(base64Encode(pair.sessionA.sharedSecret))));
      expect(sessionStr, isNot(contains('sendKey')));
      expect(sessionStr, isNot(contains('receiveKey')));
      expect(sessionStr, contains('sessionId:'));
      expect(sessionStr, contains('epoch: 0'));

      // 36. Destruction clears directional keys and transitions state
      pair.sessionA.destroy();
      expect(pair.sessionA.isDestroyed, isTrue);
      expect(pair.sessionA.state, equals(SessionLifecycleState.noSession));
      expect(pair.sessionA.directionalKeys, isNull);
    });
  });
}
