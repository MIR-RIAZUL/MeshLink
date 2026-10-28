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
  group('Handshake Security Lifecycle Tests', () {
    late DateTime simulatedNow;
    late MeshIdentityService identityServiceA;
    late MeshIdentityService identityServiceB;
    late EphemeralSessionService sessionServiceA;
    late EphemeralSessionService sessionServiceB;
    late HandshakeService handshakeA;
    late HandshakeService handshakeB;

    setUp(() async {
      simulatedNow = DateTime.utc(2026, 10, 29, 12, 0, 0);

      identityServiceA = MeshIdentityService(
        store: InMemorySecureIdentityStoreV2(),
      );
      identityServiceB = MeshIdentityService(
        store: InMemorySecureIdentityStoreV2(),
      );

      await identityServiceA.initialize();
      await identityServiceB.initialize();

      sessionServiceA = EphemeralSessionService(clock: () => simulatedNow);
      sessionServiceB = EphemeralSessionService(clock: () => simulatedNow);

      handshakeA = HandshakeService(
        identityService: identityServiceA,
        localId: 'ML-AAAAAA',
        sessionService: sessionServiceA,
        clock: () => simulatedNow,
      );
      handshakeB = HandshakeService(
        identityService: identityServiceB,
        localId: 'ML-BBBBBB',
        sessionService: sessionServiceB,
        clock: () => simulatedNow,
      );
    });

    // ── 1. Pending requests below limit are accepted ──
    test('1. Pending requests below limit are accepted', () async {
      final customHandshake = HandshakeService(
        identityService: identityServiceA,
        localId: 'ML-AAAAAA',
        sessionService: sessionServiceA,
        maxPendingRequests: 10,
        clock: () => simulatedNow,
      );

      for (int i = 0; i < 9; i++) {
        final req = await customHandshake.createKeyRequest(
          destinationId: 'ML-PEER-$i',
          requestId: 'REQ-SUB-$i',
        );
        expect(req.requestId, equals('REQ-SUB-$i'));
      }

      expect(customHandshake.pendingRequestsCount, equals(9));
      expect(customHandshake.getPendingRequest('REQ-SUB-0'), isNotNull);
      expect(customHandshake.getPendingRequest('REQ-SUB-8'), isNotNull);
    });

    // ── 2. Request beyond limit is rejected without evicting existing requests ──
    test('2. A request beyond limit is rejected without evicting existing requests', () async {
      final customHandshake = HandshakeService(
        identityService: identityServiceA,
        localId: 'ML-AAAAAA',
        sessionService: sessionServiceA,
        maxPendingRequests: 3,
        clock: () => simulatedNow,
      );

      await customHandshake.createKeyRequest(destinationId: 'ML-P1', requestId: 'REQ-1');
      await customHandshake.createKeyRequest(destinationId: 'ML-P2', requestId: 'REQ-2');
      await customHandshake.createKeyRequest(destinationId: 'ML-P3', requestId: 'REQ-3');

      expect(customHandshake.pendingRequestsCount, equals(3));

      // Attempt 4th request: must be rejected safely
      expect(
        () => customHandshake.createKeyRequest(destinationId: 'ML-P4', requestId: 'REQ-4'),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.concurrentHandshake,
        )),
      );

      // Verify no eviction occurred: REQ-1, REQ-2, REQ-3 still present
      expect(customHandshake.pendingRequestsCount, equals(3));
      expect(customHandshake.getPendingRequest('REQ-1'), isNotNull);
      expect(customHandshake.getPendingRequest('REQ-2'), isNotNull);
      expect(customHandshake.getPendingRequest('REQ-3'), isNotNull);
      expect(customHandshake.getPendingRequest('REQ-4'), isNull);
    });

    // ── 3. Concurrent handshake creation cannot exceed limit (Future.wait) ──
    test('3. Concurrent handshake creation cannot exceed limit (using Future.wait)', () async {
      final customHandshake = HandshakeService(
        identityService: identityServiceA,
        localId: 'ML-AAAAAA',
        sessionService: sessionServiceA,
        maxPendingRequests: 5,
        clock: () => simulatedNow,
      );

      final results = await Future.wait(
        List.generate(12, (index) async {
          try {
            final req = await customHandshake.createKeyRequest(
              destinationId: 'ML-CONCUR-$index',
              requestId: 'REQ-CONCUR-$index',
            );
            return req;
          } catch (e) {
            return e;
          }
        }),
      );

      final successes = results.whereType<KeyRequestPacket>().toList();
      final failures = results.whereType<HandshakeException>().toList();

      expect(successes.length, equals(5), reason: 'Only exactly 5 requests should succeed');
      expect(failures.length, equals(7), reason: 'Remaining 7 requests should fail with limit error');
      for (final f in failures) {
        expect(f.code, equals(HandshakeErrorCode.concurrentHandshake));
      }
      expect(customHandshake.pendingRequestsCount, equals(5));
    });

    // ── 4. Duplicate request IDs are rejected without overwriting original ──
    test('4. Duplicate request IDs are rejected without overwriting the original', () async {
      final req1 = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-DUP-TEST',
      );

      final pendingOriginal = handshakeA.getPendingRequest('REQ-DUP-TEST');
      expect(pendingOriginal, isNotNull);

      // Attempt to reuse same requestId
      expect(
        () => handshakeA.createKeyRequest(
          destinationId: 'ML-BBBBBB',
          requestId: 'REQ-DUP-TEST',
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidRequest,
        )),
      );

      // Verify original request remains unchanged
      final pendingAfter = handshakeA.getPendingRequest('REQ-DUP-TEST');
      expect(pendingAfter, isNotNull);
      expect(pendingAfter?.timestamp, equals(req1.timestamp));
      expect(pendingAfter?.initiatorEphemeralPublicKey,
          equals(pendingOriginal?.initiatorEphemeralPublicKey));
    });

    // ── 5. Expired requests cleaned up through production entry points ──
    test('5. Expired requests are cleaned up through production entry points', () async {
      final reqOld = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-OLD',
      );
      expect(handshakeA.getPendingRequest('REQ-OLD'), isNotNull);

      // Advance clock by 11 minutes (> default 10 minutes)
      simulatedNow = simulatedNow.add(const Duration(minutes: 11));

      // Trigger production entry point createKeyRequest
      final reqNew = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-NEW',
      );

      expect(handshakeA.getPendingRequest(reqOld.requestId), isNull,
          reason: 'Old expired request must be pruned by lazy cleanup');
      expect(handshakeA.getPendingRequest(reqNew.requestId), isNotNull);
      expect(handshakeA.pendingRequestsCount, equals(1));
    });

    // ── 6. Unexpired requests remain usable within window ──
    test('6. Unexpired requests remain usable within 10-minute window', () async {
      final req = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-USABLE-WINDOW',
      );

      // Advance clock by 5 minutes (< 10 minutes)
      simulatedNow = simulatedNow.add(const Duration(minutes: 5));

      final vReq = await handshakeB.verifyKeyRequest(req);
      final resp = await handshakeB.createKeyResponse(request: req);

      final vResp = await handshakeA.verifyKeyResponse(resp);
      expect(vResp.isValid, isTrue);

      final sessionA = await handshakeA.completeSessionAsInitiator(
        verifiedResponse: vResp,
      );
      final sessionB = await handshakeB.completeSessionAsResponder(
        verifiedRequest: vReq,
      );

      expect(sessionA.sessionId, equals(sessionB.sessionId));
    });

    // ── 7. Expired response rejected with default arguments ──
    test('7. An expired response is rejected even when default arguments are used', () async {
      final req = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-EXPIRE-DEFAULT-ARGS',
      );

      final resp = await handshakeB.createKeyResponse(request: req);

      // Advance clock by 11 minutes
      simulatedNow = simulatedNow.add(const Duration(minutes: 11));

      // verifyKeyResponse with default arguments (now: null, enforceTimestampHorizon: false)
      expect(
        () => handshakeA.verifyKeyResponse(resp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.requestExpired,
        )),
      );

      expect(handshakeA.getPendingRequest(req.requestId), isNull);
      expect(sessionServiceA.hasPendingKeyPair(req.requestId), isFalse);
    });

    // ── 8. Unknown and repeated responses cannot establish a session ──
    test('8. Unknown and repeated responses cannot establish a session', () async {
      // 8a. Unknown response ID
      final fakeResp = KeyResponsePacket(
        protocolVersion: 2,
        requestId: 'REQ-UNKNOWN-ID',
        originId: 'ML-BBBBBB',
        destinationId: 'ML-AAAAAA',
        timestamp: simulatedNow.millisecondsSinceEpoch,
        identityPublicKey: base64UrlEncode(Uint8List(32)),
        ephemeralPublicKey: base64UrlEncode(Uint8List(32)),
        signature: base64UrlEncode(Uint8List(64)),
      );

      expect(
        () => handshakeA.verifyKeyResponse(fakeResp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.requestIdMismatch,
        )),
      );

      // 8b. Repeated response replay
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final vReq = await handshakeB.verifyKeyRequest(req);
      final resp = await handshakeB.createKeyResponse(request: req);
      final vResp = await handshakeA.verifyKeyResponse(resp);

      // Complete session initially
      await handshakeA.completeSessionAsInitiator(verifiedResponse: vResp);
      await handshakeB.completeSessionAsResponder(verifiedRequest: vReq);

      // Replaying the response to verifyKeyResponse fails because pending request is gone
      expect(
        () => handshakeA.verifyKeyResponse(resp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.requestIdMismatch,
        )),
      );

      // Directly attempting to call completeSessionAsInitiator again fails because key pair is consumed
      expect(
        () => handshakeA.completeSessionAsInitiator(verifiedResponse: vResp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.sessionDerivationFailed,
        )),
      );
    });

    // ── 9. Failed handshakes release key references ──
    test('9. Failed handshakes release key references', () async {
      final req = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-FAIL-CLEANUP',
      );

      expect(sessionServiceA.hasPendingKeyPair(req.requestId), isTrue);

      final validResp = await handshakeB.createKeyResponse(request: req);
      // Corrupt signature
      final corruptResp = KeyResponsePacket(
        protocolVersion: validResp.protocolVersion,
        requestId: validResp.requestId,
        originId: validResp.originId,
        destinationId: validResp.destinationId,
        timestamp: validResp.timestamp,
        identityPublicKey: validResp.identityPublicKey,
        ephemeralPublicKey: validResp.ephemeralPublicKey,
        signature: base64UrlEncode(Uint8List(64)), // corrupted signature
      );

      await expectLater(
        () => handshakeA.verifyKeyResponse(corruptResp),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidSignature,
        )),
      );

      // Verify both pending request and key reference are released
      expect(handshakeA.getPendingRequest(req.requestId), isNull);
      expect(sessionServiceA.hasPendingKeyPair(req.requestId), isFalse,
          reason: 'Key reference must be released for garbage collection on verification failure');
    });

    // ── 10. Successful initiator and responder handshakes still establish sessions ──
    test('10. Successful initiator and responder handshakes establish sessions', () async {
      final req = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final vReq = await handshakeB.verifyKeyRequest(req);
      final resp = await handshakeB.createKeyResponse(request: req);
      final vResp = await handshakeA.verifyKeyResponse(resp);

      final sessionA = await handshakeA.completeSessionAsInitiator(verifiedResponse: vResp);
      final sessionB = await handshakeB.completeSessionAsResponder(verifiedRequest: vReq);

      expect(sessionA.sessionId, equals(sessionB.sessionId));
      expect(sessionA.state, equals(SessionLifecycleState.activeSession));
      expect(sessionB.state, equals(SessionLifecycleState.activeSession));

      final enc = DirectionalSessionEncryptionService();
      final keysA = await enc.getOrDeriveKeys(sessionA);
      final keysB = await enc.getOrDeriveKeys(sessionB);

      expect(keysA.sendKey, equals(keysB.receiveKey));
      expect(keysA.receiveKey, equals(keysB.sendKey));

      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ML-AAAAAA',
        destinationId: 'ML-BBBBBB',
        messageId: 'MSG-TEST-10',
      );

      final ciphertext = await enc.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(utf8.encode('Hello Bob')),
        aad: aad,
      );

      final decrypted = await enc.decrypt(
        session: sessionB,
        encrypted: ciphertext,
        aad: aad,
      );

      expect(utf8.decode(decrypted), equals('Hello Bob'));
    });

    // ── 11. Verified response retains key pair until session completion ──
    test('11. A verified response retains its key pair until session completion', () async {
      final req = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-RETAIN-TEST',
      );

      final resp = await handshakeB.createKeyResponse(request: req);
      final vResp = await handshakeA.verifyKeyResponse(resp);

      // Request is removed from pending, but ephemeral key pair MUST be retained for derivation
      expect(handshakeA.getPendingRequest(req.requestId), isNull);
      expect(sessionServiceA.hasPendingKeyPair(req.requestId), isTrue,
          reason: 'Key pair must NOT be dropped on verification success before session establishment');

      // Now complete the session
      final sessionA = await handshakeA.completeSessionAsInitiator(verifiedResponse: vResp);
      expect(sessionA.sessionId.isNotEmpty, isTrue);

      // Now the key pair should have been consumed
      expect(sessionServiceA.hasPendingKeyPair(req.requestId), isFalse);
    });

    // ── 12. Historical-timestamp tests remain deterministic through injected clock ──
    test('12. Historical-timestamp tests remain deterministic through injected clock', () async {
      // Historical wire timestamps from 2024
      const historicalTs = 1727800000000;

      final req = await handshakeA.createKeyRequest(
        destinationId: 'ML-BBBBBB',
        requestId: 'REQ-HISTORICAL',
        timestamp: historicalTs,
      );

      expect(req.timestamp, equals(historicalTs));

      final vReq = await handshakeB.verifyKeyRequest(req);
      expect(vReq.isValid, isTrue);

      final resp = await handshakeB.createKeyResponse(
        request: req,
        timestamp: historicalTs,
      );
      expect(resp.timestamp, equals(historicalTs));

      final vResp = await handshakeA.verifyKeyResponse(resp);
      expect(vResp.isValid, isTrue);

      final sessionA = await handshakeA.completeSessionAsInitiator(verifiedResponse: vResp);
      final sessionB = await handshakeB.completeSessionAsResponder(verifiedRequest: vReq);

      expect(sessionA.sessionId, equals(sessionB.sessionId));
    });

    // ── 13. Repeated malformed/abandoned handshakes cannot grow pending state without bound ──
    test('13. Repeated malformed/abandoned handshakes cannot grow pending state without bound', () async {
      final customHandshake = HandshakeService(
        identityService: identityServiceA,
        localId: 'ML-AAAAAA',
        sessionService: sessionServiceA,
        maxPendingRequests: 64,
        clock: () => simulatedNow,
      );

      // Attempt to flood with 80 requests
      int accepted = 0;
      int rejected = 0;

      for (int i = 0; i < 80; i++) {
        try {
          await customHandshake.createKeyRequest(
            destinationId: 'ML-FLOOD-$i',
            requestId: 'REQ-FLOOD-$i',
          );
          accepted++;
        } on HandshakeException catch (e) {
          if (e.code == HandshakeErrorCode.concurrentHandshake) {
            rejected++;
          }
        }
      }

      expect(accepted, equals(64));
      expect(rejected, equals(16));
      expect(customHandshake.pendingRequestsCount, equals(64));
      expect(sessionServiceA.pendingKeyPairsCount, equals(64));

      // After 11 minutes, next request cleans up all expired requests
      simulatedNow = simulatedNow.add(const Duration(minutes: 11));

      final freshReq = await customHandshake.createKeyRequest(
        destinationId: 'ML-FRESH',
        requestId: 'REQ-FRESH',
      );

      expect(freshReq.requestId, equals('REQ-FRESH'));
      expect(customHandshake.pendingRequestsCount, equals(1));
      expect(sessionServiceA.pendingKeyPairsCount, equals(1));
    });

    // ── 14. Existing tests for signatures, identity mismatch, transcript binding, and rekeying pass ──
    test('14. Rekey flow with bounded checks and lifecycle transitions completes cleanly', () async {
      // 1. Initial handshake
      final req1 = await handshakeA.createKeyRequest(destinationId: 'ML-BBBBBB');
      final vReq1 = await handshakeB.verifyKeyRequest(req1);
      final resp1 = await handshakeB.createKeyResponse(request: req1);
      final vResp1 = await handshakeA.verifyKeyResponse(resp1);

      final sessionA = await handshakeA.completeSessionAsInitiator(verifiedResponse: vResp1);
      final sessionB = await handshakeB.completeSessionAsResponder(verifiedRequest: vReq1);

      expect(handshakeA.getLifecycleState('ML-BBBBBB'), equals(SessionLifecycleState.activeSession));
      expect(sessionA.epoch, equals(0));
      expect(sessionB.epoch, equals(0));

      // 2. Initiate rekey
      final rekeyReq = await handshakeA.initiateRekey(destinationId: 'ML-BBBBBB');
      expect(handshakeA.getLifecycleState('ML-BBBBBB'), equals(SessionLifecycleState.rekeying));

      // 3. Responder processes rekey request
      final vRekeyReq = await handshakeB.verifyKeyRequest(rekeyReq);
      final rekeyResp = await handshakeB.createKeyResponse(request: rekeyReq);

      // 4. Initiator verifies rekey response
      final vRekeyResp = await handshakeA.verifyKeyResponse(rekeyResp);

      // 5. Complete rekey on both sides
      final rekeyedA = await handshakeA.completeSessionAsInitiator(verifiedResponse: vRekeyResp);
      final rekeyedB = await handshakeB.completeSessionAsResponder(verifiedRequest: vRekeyReq);

      expect(rekeyedA.epoch, equals(1));
      expect(rekeyedB.epoch, equals(1));
      expect(rekeyedA.sessionId, equals(rekeyedB.sessionId));
      expect(handshakeA.getLifecycleState('ML-BBBBBB'), equals(SessionLifecycleState.activeSession));
      expect(handshakeB.getLifecycleState('ML-AAAAAA'), equals(SessionLifecycleState.activeSession));

      // Verify pending request state is clean
      expect(handshakeA.pendingRequestsCount, equals(0));
      expect(sessionServiceA.hasPendingKeyPair(rekeyReq.requestId), isFalse);
    });
  });
}
