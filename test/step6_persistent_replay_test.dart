import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:path/path.dart' as p;

class MockDiscoveryService implements DeviceDiscoveryService {
  MockDiscoveryService({
    this.localIdentity = const LocalIdentity(id: 'ML-LOCAL', name: 'LocalDevice'),
  });

  final StreamController<DeviceDiscoveryEvent> _controller =
      StreamController<DeviceDiscoveryEvent>.broadcast();

  final List<Map<String, String>> sentTransmissions = [];
  bool shouldSendSucceed = true;
  final LocalIdentity localIdentity;

  @override
  Stream<DeviceDiscoveryEvent> get events => _controller.stream;

  void emit(DeviceDiscoveryEvent event) => _controller.add(event);

  @override
  Future<bool> sendMessage(String deviceId, String payload) async {
    if (!shouldSendSucceed) return false;
    sentTransmissions.add({'deviceId': deviceId, 'payload': payload});
    return true;
  }

  @override
  Future<BluetoothStateInfo> getBluetoothState() async =>
      const BluetoothStateInfo(state: BluetoothState.enabled);

  @override
  Future<bool> requestEnableBluetooth() async => true;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<LocalIdentity> getLocalIdentity() async => localIdentity;

  @override
  Future<void> setDisplayName(String name) async {}

  @override
  Future<DiscoveryAvailability> checkAvailability() async =>
      const DiscoveryAvailability(available: true);

  @override
  Future<DiscoveryStartResult> startDiscovery() async =>
      const DiscoveryStartResult(started: true);

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<ConnectionStartResult> connect(String deviceId) async =>
      const ConnectionStartResult(started: true);

  @override
  Future<bool> acceptConnection(String deviceId) async => true;

  @override
  Future<bool> rejectConnection(String deviceId) async => true;

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Phase 7 Step 6: Persistent Replay Protection', () {
    late AppDatabase db;
    late MessageRepository repository;
    late ReplayProtectionService replayService;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftMessageRepository(db);
      replayService = ReplayProtectionService(repository: repository);
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // Test 1 — First packet accepted
    // -------------------------------------------------------------------------
    test('Test 1 — First packet accepted', () async {
      final now = DateTime.now();
      final outcome = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'pkt-001',
        timestamp: now,
      );

      expect(outcome.result, ReplayValidationResult.accepted);
      expect(outcome.isAccepted, isTrue);
      expect(outcome.isDuplicate, isFalse);
      expect(outcome.replayKey, 'encrypted_message:PEER-ALICE:pkt-001');

      final seen = await replayService.isSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'pkt-001',
      );
      expect(seen, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 2 — Exact duplicate rejected
    // -------------------------------------------------------------------------
    test('Test 2 — Exact duplicate rejected', () async {
      final now = DateTime.now();
      final first = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'pkt-dup-1',
        timestamp: now,
      );
      expect(first.isAccepted, isTrue);

      final second = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'pkt-dup-1',
        timestamp: now,
      );
      expect(second.result, ReplayValidationResult.duplicate);
      expect(second.isAccepted, isFalse);
      expect(second.isDuplicate, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 3 — Persistence across repository/service recreation
    // -------------------------------------------------------------------------
    test('Test 3 — Persistence across repository/service recreation', () async {
      final now = DateTime.now();
      final first = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'pkt-persist-1',
        timestamp: now,
      );
      expect(first.isAccepted, isTrue);

      // Recreate repository and service instances on top of the same database
      final freshRepo = DriftMessageRepository(db);
      final freshService = ReplayProtectionService(repository: freshRepo);

      final second = await freshService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'pkt-persist-1',
        timestamp: now,
      );
      expect(second.result, ReplayValidationResult.duplicate);
      expect(second.isAccepted, isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 4 — Persistence across database reopen (file-backed SQLite)
    // -------------------------------------------------------------------------
    test('Test 4 — Persistence across database close and reopen', () async {
      final tempDir = Directory.systemTemp.createTempSync('meshlink_db_reopen_');
      final dbFile = File(p.join(tempDir.path, 'seen_packets.sqlite'));

      try {
        // 1. Open database and record packet
        final db1 = AppDatabase(NativeDatabase(dbFile));
        final repo1 = DriftMessageRepository(db1);
        final service1 = ReplayProtectionService(repository: repo1);

        final now = DateTime.now();
        final firstOutcome = await service1.checkAndMarkSeen(
          packetType: 'encrypted_message',
          originId: 'PEER-ALICE',
          packetId: 'pkt-file-reopen-1',
          timestamp: now,
        );
        expect(firstOutcome.isAccepted, isTrue);

        // Close db1
        await db1.close();

        // 2. Reopen database from the exact same file
        final db2 = AppDatabase(NativeDatabase(dbFile));
        final repo2 = DriftMessageRepository(db2);
        final service2 = ReplayProtectionService(repository: repo2);

        expect(
          await service2.isSeen(
            packetType: 'encrypted_message',
            originId: 'PEER-ALICE',
            packetId: 'pkt-file-reopen-1',
          ),
          isTrue,
        );

        final duplicateOutcome = await service2.checkAndMarkSeen(
          packetType: 'encrypted_message',
          originId: 'PEER-ALICE',
          packetId: 'pkt-file-reopen-1',
          timestamp: now,
        );
        expect(duplicateOutcome.result, ReplayValidationResult.duplicate);
        expect(duplicateOutcome.isAccepted, isFalse);

        await db2.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    // -------------------------------------------------------------------------
    // Test 5 — Different origin
    // -------------------------------------------------------------------------
    test('Test 5 — Different origin with identical packetId are isolated', () async {
      final now = DateTime.now();
      const sharedPacketId = 'shared-packet-id-001';

      // Origin A
      final outcomeA = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-A',
        packetId: sharedPacketId,
        timestamp: now,
      );
      expect(outcomeA.isAccepted, isTrue);

      // Origin B with same packetId must be accepted
      final outcomeB = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-B',
        packetId: sharedPacketId,
        timestamp: now,
      );
      expect(outcomeB.isAccepted, isTrue);

      // Replaying Origin A again must be rejected
      final outcomeA2 = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-A',
        packetId: sharedPacketId,
        timestamp: now,
      );
      expect(outcomeA2.isDuplicate, isTrue);

      // Replaying Origin B again must be rejected
      final outcomeB2 = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-B',
        packetId: sharedPacketId,
        timestamp: now,
      );
      expect(outcomeB2.isDuplicate, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 6 — Different packet type
    // -------------------------------------------------------------------------
    test('Test 6 — Different packet type with same origin and id are isolated', () async {
      final now = DateTime.now();
      const origin = 'PEER-X';
      const id = 'packet-999';

      final outcomeMsg = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: origin,
        packetId: id,
        timestamp: now,
      );
      expect(outcomeMsg.isAccepted, isTrue);

      // Different packet type (e.g. ack)
      final outcomeAck = await replayService.checkAndMarkSeen(
        packetType: 'ack',
        originId: origin,
        packetId: id,
        timestamp: now,
      );
      expect(outcomeAck.isAccepted, isTrue);

      // Re-sending either must be rejected as duplicate
      final outcomeMsgDup = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: origin,
        packetId: id,
        timestamp: now,
      );
      expect(outcomeMsgDup.isDuplicate, isTrue);

      final outcomeAckDup = await replayService.checkAndMarkSeen(
        packetType: 'ack',
        originId: origin,
        packetId: id,
        timestamp: now,
      );
      expect(outcomeAckDup.isDuplicate, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 7 — Concurrent duplicate arrival
    // -------------------------------------------------------------------------
    test('Test 7 — Concurrent duplicate arrival (atomicity guarantee)', () async {
      final now = DateTime.now();
      const origin = 'PEER-CONCURRENT';
      const id = 'concurrent-msg-1';

      // Launch 5 simultaneous requests for the exact same packet
      final futures = List.generate(5, (_) {
        return replayService.checkAndMarkSeen(
          packetType: 'encrypted_message',
          originId: origin,
          packetId: id,
          timestamp: now,
        );
      });

      final outcomes = await Future.wait(futures);

      final acceptedCount = outcomes.where((o) => o.isAccepted).length;
      final duplicateCount = outcomes.where((o) => o.isDuplicate).length;

      expect(acceptedCount, 1, reason: 'Exactly one concurrent request must be accepted');
      expect(duplicateCount, 4, reason: 'All remaining concurrent requests must be rejected');
    });

    // -------------------------------------------------------------------------
    // Test 8 — Expired packet (> 7 days)
    // -------------------------------------------------------------------------
    test('Test 8 — Expired packet outside 7-day replay horizon is rejected', () async {
      final now = DateTime.now();
      final expiredTimestamp = now.subtract(const Duration(days: 7, minutes: 5));

      final outcome = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-OLD',
        packetId: 'expired-1',
        timestamp: expiredTimestamp,
        now: now,
      );

      expect(outcome.result, ReplayValidationResult.expired);
      expect(outcome.isAccepted, isFalse);

      // Verify it was NOT recorded in database
      final seen = await replayService.isSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-OLD',
        packetId: 'expired-1',
      );
      expect(seen, isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 9 — Future packet (> 1 hour future skew)
    // -------------------------------------------------------------------------
    test('Test 9 — Future packet beyond +1 hour future skew is rejected', () async {
      final now = DateTime.now();
      final futureTimestamp = now.add(const Duration(hours: 1, minutes: 2));

      final outcome = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-FUTURE',
        packetId: 'future-1',
        timestamp: futureTimestamp,
        now: now,
      );

      expect(outcome.result, ReplayValidationResult.futureTimestamp);
      expect(outcome.isAccepted, isFalse);

      final seen = await replayService.isSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-FUTURE',
        packetId: 'future-1',
      );
      expect(seen, isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 10 — Boundary timestamp (7 days, +1 hour)
    // -------------------------------------------------------------------------
    test('Test 10 — Boundary timestamp checks for replay horizon and future skew', () {
      final fixedNow = DateTime.utc(2026, 10, 4, 12, 0, 0);

      // Boundary: Exactly 7 days ago minus 1 second -> valid
      final validOld = fixedNow.subtract(const Duration(days: 7)).add(const Duration(seconds: 1));
      expect(
        replayService.validatePacketMetadata(
          packetType: 'encrypted_message',
          originId: 'PEER-1',
          packetId: 'id-valid-old',
          timestamp: validOld,
          now: fixedNow,
        ),
        ReplayValidationResult.accepted,
      );

      // Boundary: Exactly 7 days ago minus 1 second further -> expired
      final invalidOld = fixedNow.subtract(const Duration(days: 7, seconds: 1));
      expect(
        replayService.validatePacketMetadata(
          packetType: 'encrypted_message',
          originId: 'PEER-1',
          packetId: 'id-invalid-old',
          timestamp: invalidOld,
          now: fixedNow,
        ),
        ReplayValidationResult.expired,
      );

      // Boundary: Exactly 1 hour future minus 1 second -> valid
      final validFuture = fixedNow.add(const Duration(hours: 1)).subtract(const Duration(seconds: 1));
      expect(
        replayService.validatePacketMetadata(
          packetType: 'encrypted_message',
          originId: 'PEER-1',
          packetId: 'id-valid-future',
          timestamp: validFuture,
          now: fixedNow,
        ),
        ReplayValidationResult.accepted,
      );

      // Boundary: Exactly 1 hour future plus 1 second -> futureTimestamp
      final invalidFuture = fixedNow.add(const Duration(hours: 1, seconds: 1));
      expect(
        replayService.validatePacketMetadata(
          packetType: 'encrypted_message',
          originId: 'PEER-1',
          packetId: 'id-invalid-future',
          timestamp: invalidFuture,
          now: fixedNow,
        ),
        ReplayValidationResult.futureTimestamp,
      );
    });

    // -------------------------------------------------------------------------
    // Test 11 — Malformed packet ID validation
    // -------------------------------------------------------------------------
    test('Test 11 — Malformed, empty, or oversized packet IDs are rejected', () async {
      final now = DateTime.now();

      // Empty packet ID
      final emptyId = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-1',
        packetId: '',
        timestamp: now,
      );
      expect(emptyId.result, ReplayValidationResult.invalidIdentifier);

      // Whitespace packet ID
      final whitespaceId = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-1',
        packetId: '   ',
        timestamp: now,
      );
      expect(whitespaceId.result, ReplayValidationResult.invalidIdentifier);

      // Oversized packet ID (> 128 chars)
      final oversizedId = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-1',
        packetId: 'A' * 129,
        timestamp: now,
      );
      expect(oversizedId.result, ReplayValidationResult.invalidIdentifier);

      // Invalid origin ID
      final invalidOrigin = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: '',
        packetId: 'valid-id',
        timestamp: now,
      );
      expect(invalidOrigin.result, ReplayValidationResult.invalidIdentifier);

      // Verify no records were inserted into the database
      final allSeen = await db.customSelect('SELECT COUNT(*) AS cnt FROM seen_packets_table').getSingle();
      expect(allSeen.read<int>('cnt'), 0);
    });

    // -------------------------------------------------------------------------
    // Test 12 — Persistence after app/session restart
    // -------------------------------------------------------------------------
    test('Test 12 — Persistence across session lifecycle / re-handshake', () async {
      final now = DateTime.now();
      const origin = 'PEER-ALICE';
      const packetId = 'session-packet-42';

      // 1. Session 1 accepts the packet
      final outcome1 = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: origin,
        packetId: packetId,
        timestamp: now,
      );
      expect(outcome1.isAccepted, isTrue);

      // 2. Simulate session termination and establishing Session 2 (e.g. new ephemeral session)
      // The replay service and database persist across session lifecycles.
      final outcome2 = await replayService.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: origin,
        packetId: packetId,
        timestamp: now,
      );
      expect(outcome2.isDuplicate, isTrue);
      expect(outcome2.isAccepted, isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 13 — Duplicate does not process twice
    // -------------------------------------------------------------------------
    test('Test 13 — Duplicate packet is not processed twice via pipeline', () async {
      final now = DateTime.now();
      int executionCount = 0;

      Future<String> decryptPayload() async => 'decrypted-content';

      // First presentation of packet
      final res1 = await replayService.processAuthenticatedPacket<String>(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'process-once-1',
        timestamp: now,
        authenticateAndDecrypt: decryptPayload,
        onAccepted: (msg) async {
          executionCount++;
        },
      );
      expect(res1, 'decrypted-content');
      expect(executionCount, 1);

      // Second presentation of identical packet
      final res2 = await replayService.processAuthenticatedPacket<String>(
        packetType: 'encrypted_message',
        originId: 'PEER-ALICE',
        packetId: 'process-once-1',
        timestamp: now,
        authenticateAndDecrypt: decryptPayload,
        onAccepted: (msg) async {
          executionCount++;
        },
      );
      expect(res2, isNull);
      expect(executionCount, 1, reason: 'onAccepted must NOT be called for duplicate packet');
    });

    // -------------------------------------------------------------------------
    // Test 14 — Duplicate does not forward twice (Routing Safety)
    // -------------------------------------------------------------------------
    test('Test 14 — MeshRouter drops duplicate relayed packet to prevent loop/storm', () async {
      final discovery = MockDiscoveryService();
      final router = MeshRouter(
        discoveryService: discovery,
        localId: 'ROUTER-NODE',
        getConnectedPeers: () => {'PEER-NEXT-HOP'},
        replayProtectionService: replayService,
      );

      final payload = {
        'type': 'encrypted_message',
        'version': 1,
        'messageId': 'relayed-msg-123',
        'originId': 'ORIGIN-NODE',
        'destinationId': 'DESTINATION-NODE',
        'ttl': 5,
        'hopCount': 0,
        'timestamp': DateTime.now().toIso8601String(),
        'nonce': 'nonce123',
        'ciphertext': 'cipher123',
        'mac': 'mac123',
      };

      // First route: should be relayed
      final result1 = await router.handleIncomingPayload(jsonEncode(payload));
      expect(result1, isA<RelayedMessage>());
      expect((result1 as RelayedMessage).messageId, 'relayed-msg-123');
      expect(discovery.sentTransmissions.length, 1);

      // Second route: duplicate relayed packet must be dropped
      final result2 = await router.handleIncomingPayload(jsonEncode(payload));
      expect(result2, isA<DroppedPayload>());
      expect((result2 as DroppedPayload).reason, contains('Duplicate'));
      // No extra transmission forwarded
      expect(discovery.sentTransmissions.length, 1);
    });

    // -------------------------------------------------------------------------
    // Test 15 — Authentication ordering (prevents DB poisoning)
    // -------------------------------------------------------------------------
    test('Test 15 — Unauthenticated packet cannot poison replay database', () async {
      final now = DateTime.now();
      const packetId = 'poison-attempt-1';
      bool delivered = false;

      // Attacker sends malformed/tampered packet that fails authentication
      final result = await replayService.processAuthenticatedPacket<String>(
        packetType: 'encrypted_message',
        originId: 'ATTACKER',
        packetId: packetId,
        timestamp: now,
        authenticateAndDecrypt: () async {
          throw Exception('Cryptographic verification failed: invalid MAC tag');
        },
        onAccepted: (_) async {
          delivered = true;
        },
      ).catchError((_) => null);

      expect(result, isNull);
      expect(delivered, isFalse);

      // Verify that the replay database was NOT poisoned with this packet ID
      final isPoisoned = await replayService.isSeen(
        packetType: 'encrypted_message',
        originId: 'ATTACKER',
        packetId: packetId,
      );
      expect(isPoisoned, isFalse, reason: 'Replay database must not record unauthenticated packets');

      // A legitimate subsequent packet with this ID can now be authenticated and processed
      final legitimateResult = await replayService.processAuthenticatedPacket<String>(
        packetType: 'encrypted_message',
        originId: 'ATTACKER',
        packetId: packetId,
        timestamp: now,
        authenticateAndDecrypt: () async => 'legitimate-content',
        onAccepted: (_) async {
          delivered = true;
        },
      );
      expect(legitimateResult, 'legitimate-content');
      expect(delivered, isTrue);

      // Now it IS recorded as seen
      expect(
        await replayService.isSeen(
          packetType: 'encrypted_message',
          originId: 'ATTACKER',
          packetId: packetId,
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Test 16 — Valid encrypted packet (Directional Encryption integration)
    // -------------------------------------------------------------------------
    test('Test 16 — Valid Step 5 directional encrypted packet passes pipeline and registers replay', () async {
      final aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      final bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      await aliceIdentity.initialize();
      await bobIdentity.initialize();

      final aliceSessionService = EphemeralSessionService();
      final bobSessionService = EphemeralSessionService();

      final aliceHandshake = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ALICE',
        sessionService: aliceSessionService,
      );
      final bobHandshake = HandshakeService(
        identityService: bobIdentity,
        localId: 'BOB',
        sessionService: bobSessionService,
      );

      final encService = DirectionalSessionEncryptionService();

      // Establish Step 4/5 session
      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'BOB',
        requestId: 'REQ-STEP6-001',
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

      final now = DateTime.now();
      const messageId = 'step5-msg-001';
      final plaintext = utf8.encode('Hello Bob from Step 6!');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ALICE',
        destinationId: 'BOB',
        messageId: messageId,
      );

      // Alice encrypts for Bob
      final encryptedPayload = await encService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Bob receives and processes through ReplayProtectionService
      String? deliveredText;
      final outcome = await replayService.processAuthenticatedPacket<String>(
        packetType: 'encrypted_message',
        originId: 'ALICE',
        packetId: messageId,
        timestamp: now,
        authenticateAndDecrypt: () async {
          final decryptedBytes = await encService.decrypt(
            session: sessionB,
            encrypted: encryptedPayload,
            aad: aad,
          );
          return utf8.decode(decryptedBytes);
        },
        onAccepted: (text) async {
          deliveredText = text;
        },
      );

      expect(outcome, 'Hello Bob from Step 6!');
      expect(deliveredText, 'Hello Bob from Step 6!');

      // Verify packet is registered in replay database
      expect(
        await replayService.isSeen(
          packetType: 'encrypted_message',
          originId: 'ALICE',
          packetId: messageId,
        ),
        isTrue,
      );

      // Replaying the same encrypted packet is dropped
      final replayOutcome = await replayService.processAuthenticatedPacket<String>(
        packetType: 'encrypted_message',
        originId: 'ALICE',
        packetId: messageId,
        timestamp: now,
        authenticateAndDecrypt: () async {
          final decryptedBytes = await encService.decrypt(
            session: sessionB,
            encrypted: encryptedPayload,
            aad: aad,
          );
          return utf8.decode(decryptedBytes);
        },
        onAccepted: (_) async {
          fail('Should not be called for replayed packet');
        },
      );
      expect(replayOutcome, isNull);
    });

    // -------------------------------------------------------------------------
    // Test 17 — Tampered packet fails auth and is NOT registered
    // -------------------------------------------------------------------------
    test('Test 17 — Tampered encrypted packet fails auth and does not consume replay entry', () async {
      final aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      final bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
      await aliceIdentity.initialize();
      await bobIdentity.initialize();

      final aliceSessionService = EphemeralSessionService();
      final bobSessionService = EphemeralSessionService();

      final aliceHandshake = HandshakeService(
        identityService: aliceIdentity,
        localId: 'ALICE',
        sessionService: aliceSessionService,
      );
      final bobHandshake = HandshakeService(
        identityService: bobIdentity,
        localId: 'BOB',
        sessionService: bobSessionService,
      );

      final encService = DirectionalSessionEncryptionService();

      final request = await aliceHandshake.createKeyRequest(
        destinationId: 'BOB',
        requestId: 'REQ-STEP6-002',
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

      final now = DateTime.now();
      const messageId = 'tamper-msg-999';
      final plaintext = utf8.encode('Secret contents');
      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: sessionA.sessionId,
        originId: 'ALICE',
        destinationId: 'BOB',
        messageId: messageId,
      );

      final legitimatePayload = await encService.encrypt(
        session: sessionA,
        plaintext: Uint8List.fromList(plaintext),
        aad: aad,
      );

      // Tamper with the ciphertext byte
      final tamperedCiphertext = Uint8List.fromList(legitimatePayload.ciphertext);
      tamperedCiphertext[0] ^= 0xFF;
      final tamperedPayload = SessionEncryptedPayload(
        nonce: legitimatePayload.nonce,
        ciphertext: tamperedCiphertext,
        mac: legitimatePayload.mac,
      );

      bool delivered = false;
      try {
        await replayService.processAuthenticatedPacket<String>(
          packetType: 'encrypted_message',
          originId: 'ALICE',
          packetId: messageId,
          timestamp: now,
          authenticateAndDecrypt: () async {
            final decrypted = await encService.decrypt(
              session: sessionB,
              encrypted: tamperedPayload,
              aad: aad,
            );
            return utf8.decode(decrypted);
          },
          onAccepted: (_) async {
            delivered = true;
          },
        );
      } catch (_) {
        // Expected decrypt failure
      }

      expect(delivered, isFalse);

      // Verify tampered packet was NOT marked seen
      expect(
        await replayService.isSeen(
          packetType: 'encrypted_message',
          originId: 'ALICE',
          packetId: messageId,
        ),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    // Test 18 — Pruning expired packets & Step 1-5 regression verification
    // -------------------------------------------------------------------------
    test('Test 18 — Pruning expired packets cleans old entries while preserving valid ones', () async {
      final now = DateTime.now();

      // 1. Manually insert an expired packet entry (received 8 days ago)
      await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-OLD',
        packetId: 'old-packet',
        receivedAt: now.subtract(const Duration(days: 8)),
      );

      // 2. Insert a fresh packet entry (received today)
      await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-FRESH',
        packetId: 'fresh-packet',
        receivedAt: now,
      );

      // Verify both are currently in database
      expect(
        await replayService.isSeen(
          packetType: 'encrypted_message',
          originId: 'PEER-OLD',
          packetId: 'old-packet',
        ),
        isTrue,
      );
      expect(
        await replayService.isSeen(
          packetType: 'encrypted_message',
          originId: 'PEER-FRESH',
          packetId: 'fresh-packet',
        ),
        isTrue,
      );

      // 3. Prune packets older than 7 days
      final prunedCount = await replayService.pruneExpiredPackets();
      expect(prunedCount, 1);

      // 4. Verify old packet was removed, fresh packet remains
      expect(
        await replayService.isSeen(
          packetType: 'encrypted_message',
          originId: 'PEER-OLD',
          packetId: 'old-packet',
        ),
        isFalse,
      );
      expect(
        await replayService.isSeen(
          packetType: 'encrypted_message',
          originId: 'PEER-FRESH',
          packetId: 'fresh-packet',
        ),
        isTrue,
      );
    });
  });
}
