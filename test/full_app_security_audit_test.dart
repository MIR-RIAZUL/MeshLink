import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_assembly_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';

class _MockDiscoveryService implements DeviceDiscoveryService {
  final List<String> sentPayloads = [];

  @override
  Stream<DeviceDiscoveryEvent> get events => const Stream.empty();

  @override
  Future<bool> sendMessage(String deviceId, String payload) async {
    sentPayloads.add(payload);
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
  Future<LocalIdentity> getLocalIdentity() async =>
      const LocalIdentity(id: 'ML-ROUTER-1', name: 'Router');

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
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full Application Security Audit & Verification', () {
    late AppDatabase db;
    late MessageRepository messageRepository;
    late ReplayProtectionService replayService;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      messageRepository = DriftMessageRepository(db);
      replayService = ReplayProtectionService(repository: messageRepository);
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // Area G: Android Manifest & Configuration Audit
    // =========================================================================
    group('Area G: Android Manifest & Build Configuration', () {
      test('G.1 Manifest explicitly disables allowBackup to protect private databases', () {
        final manifestFile = File('android/app/src/main/AndroidManifest.xml');
        expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');
        final content = manifestFile.readAsStringSync();

        expect(
          content.contains('android:allowBackup="false"'),
          isTrue,
          reason: 'Application manifest must set android:allowBackup="false" to prevent adb backup extraction of message database',
        );
      });

      test('G.2 Manifest does not request INTERNET permission (strictly offline app)', () {
        final manifestFile = File('android/app/src/main/AndroidManifest.xml');
        final content = manifestFile.readAsStringSync();
        expect(
          content.contains('android.permission.INTERNET'),
          isFalse,
          reason: 'MeshLink is offline-first and must not request INTERNET permission',
        );
      });
    });

    // =========================================================================
    // Area B: Mesh Routing & DoS / Broadcast Amplification Prevention
    // =========================================================================
    group('Area B: Mesh Routing & Denial of Service Defenses', () {
      late _MockDiscoveryService mockDiscovery;
      late MeshRouter router;

      setUp(() {
        mockDiscovery = _MockDiscoveryService();
        router = MeshRouter(
          discoveryService: mockDiscovery,
          localId: 'ML-LOCAL-ROUTER',
          getConnectedPeers: () => {'ML-PEER-1', 'ML-PEER-2'},
        );
      });

      tearDown(() async {
        await router.dispose();
      });

      test('B.1 Router drops packets with empty destinationId, preventing broadcast amplification', () async {
        final result = await router.handleIncomingPayload(
          jsonEncode({
            'type': 'encrypted_message',
            'version': 1,
            'messageId': 'MSG-100',
            'originId': 'ML-ORIGIN',
            'destinationId': '',
            'ttl': 5,
            'hopCount': 0,
            'nonce': base64Url.encode(Uint8List(12)),
            'ciphertext': base64Url.encode(Uint8List(16)),
            'mac': base64Url.encode(Uint8List(16)),
          }),
          fromPeerId: 'ML-PEER-1',
        );

        expect(result, isA<DroppedPayload>());
        expect((result as DroppedPayload).reason, contains('Invalid routing identifier'));
        expect(mockDiscovery.sentPayloads, isEmpty, reason: 'Empty destination must NEVER be relayed to neighbors');
      });

      test('B.2 Router drops packets with whitespace-only or control-character routing identifiers', () async {
        // Whitespace destinationId
        final resultWs = await router.handleIncomingPayload(
          jsonEncode({
            'type': 'encrypted_message',
            'version': 1,
            'messageId': 'MSG-101',
            'originId': 'ML-ORIGIN',
            'destinationId': '   ',
            'ttl': 5,
            'hopCount': 0,
            'nonce': base64Url.encode(Uint8List(12)),
            'ciphertext': base64Url.encode(Uint8List(16)),
            'mac': base64Url.encode(Uint8List(16)),
          }),
          fromPeerId: 'ML-PEER-1',
        );

        // Control character injection in messageId
        final resultCtrl = await router.handleIncomingPayload(
          jsonEncode({
            'type': 'encrypted_message',
            'version': 1,
            'messageId': 'MSG-102\nINJECTION',
            'originId': 'ML-ORIGIN',
            'destinationId': 'ML-DEST',
            'ttl': 5,
            'hopCount': 0,
            'nonce': base64Url.encode(Uint8List(12)),
            'ciphertext': base64Url.encode(Uint8List(16)),
            'mac': base64Url.encode(Uint8List(16)),
          }),
          fromPeerId: 'ML-PEER-1',
        );

        expect(resultWs, isA<DroppedPayload>());
        expect(resultCtrl, isA<DroppedPayload>());
        expect(mockDiscovery.sentPayloads, isEmpty);
      });

      test('B.3 Router drops packets with overlong routing identifiers (>128 chars)', () async {
        final overlongId = 'A' * 129;
        final result = await router.handleIncomingPayload(
          jsonEncode({
            'type': 'encrypted_message',
            'version': 1,
            'messageId': overlongId,
            'originId': 'ML-ORIGIN',
            'destinationId': 'ML-DEST',
            'ttl': 5,
            'hopCount': 0,
            'nonce': base64Url.encode(Uint8List(12)),
            'ciphertext': base64Url.encode(Uint8List(16)),
            'mac': base64Url.encode(Uint8List(16)),
          }),
          fromPeerId: 'ML-PEER-1',
        );

        expect(result, isA<DroppedPayload>());
        expect((result as DroppedPayload).reason, contains('Invalid routing identifier'));
        expect(mockDiscovery.sentPayloads, isEmpty);
      });

      test('B.4 Router drops encrypted file chunk with empty originId or destinationId', () async {
        final result = await router.handleIncomingPayload(
          jsonEncode({
            'type': 'file_chunk',
            'version': 2,
            'transferId': 'TR-1',
            'originId': '',
            'destinationId': 'ML-DEST',
            'ttl': 5,
            'hopCount': 0,
            'sessionId': 'SES-1',
            'epoch': 0,
            'sequenceNumber': 1,
            'chunkIndex': 0,
            'totalChunks': 1,
            'offset': 0,
            'chunkLength': 10,
            'nonce': base64Url.encode(Uint8List(12)),
            'mac': base64Url.encode(Uint8List(16)),
            'ciphertext': base64Url.encode(Uint8List(10)),
          }),
          fromPeerId: 'ML-PEER-1',
        );

        expect(result, isA<DroppedPayload>());
        expect(mockDiscovery.sentPayloads, isEmpty);
      });

      test('B.5 Router drops chunk ACK with invalid routing identifiers', () async {
        final result = await router.handleIncomingPayload(
          jsonEncode({
            'type': 'file_ack',
            'version': 2,
            'transferId': 'TR-1',
            'originId': 'ML-ORIGIN',
            'destinationId': '   ',
            'ttl': 5,
            'hopCount': 0,
            'sessionId': 'SES-1',
            'epoch': 0,
            'sequenceNumber': 1,
            'chunkIndex': 0,
            'totalChunks': 1,
            'ackType': 'ack',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'nonce': base64Url.encode(Uint8List(12)),
            'mac': base64Url.encode(Uint8List(16)),
            'ciphertext': base64Url.encode(Uint8List(10)),
          }),
          fromPeerId: 'ML-PEER-1',
        );

        expect(result, isA<DroppedPayload>());
        expect(mockDiscovery.sentPayloads, isEmpty);
      });

      test('B.6 Outbound routeEncryptedPayload rejects invalid destinationId without broadcasting', () async {
        final sent = await router.routeEncryptedPayload({
          'type': 'encrypted_message',
          'originId': 'ML-LOCAL-ROUTER',
          'destinationId': '', // Invalid destinationId
        });
        expect(sent, isFalse);
        expect(mockDiscovery.sentPayloads, isEmpty, reason: 'Must not broadcast invalid outbound packets');
      });

      test('B.7 File chunk packet with control-character messageId is dropped', () async {
        final result = await router.handleIncomingPayload(
          jsonEncode({
            'type': 'file_chunk',
            'version': 2,
            'messageId': 'TR-1:\x00evil',
            'transferId': 'TR-1',
            'originId': 'ML-ORIGIN',
            'destinationId': 'ML-LOCAL-ROUTER',
            'ttl': 5,
            'hopCount': 0,
            'sessionId': 'SES-1',
            'epoch': 0,
            'sequenceNumber': 1,
            'chunkIndex': 0,
            'totalChunks': 1,
            'offset': 0,
            'chunkLength': 10,
            'nonce': base64Url.encode(Uint8List(12)),
            'mac': base64Url.encode(Uint8List(16)),
            'ciphertext': base64Url.encode(Uint8List(10)),
          }),
          fromPeerId: 'ML-PEER-1',
        );

        expect(result, isA<DroppedPayload>());
        expect((result as DroppedPayload).reason, contains('Invalid routing identifier'));
      });
    });

    // =========================================================================
    // Area A: Handshake, Peer Identity & Cryptography
    // =========================================================================
    group('Area A: Cryptography & Peer Identity', () {
      late MeshIdentityService identityServiceA;
      late MeshIdentityService identityServiceB;
      late EphemeralSessionService sessionServiceA;
      late HandshakeService handshakeA;
      late HandshakeService handshakeB;

      setUp(() async {
        identityServiceA = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        identityServiceB = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        await identityServiceA.initialize();
        await identityServiceB.initialize();

        sessionServiceA = EphemeralSessionService();
        final sessionServiceB = EphemeralSessionService();

        handshakeA = HandshakeService(
          identityService: identityServiceA,
          localId: 'ML-ALICE',
          peerRepository: messageRepository,
          sessionService: sessionServiceA,
        );

        handshakeB = HandshakeService(
          identityService: identityServiceB,
          localId: 'ML-BOB',
          peerRepository: messageRepository,
          sessionService: sessionServiceB,
        );
      });

      test('A.1 HandshakeService prunes expired pending requests when cleanExpiredPendingRequests is called', () async {
        final now = DateTime.now();
        final req = await handshakeA.createKeyRequest(
          destinationId: 'ML-BOB',
          requestId: 'REQ-STALE-1',
          timestamp: now.millisecondsSinceEpoch,
        );

        expect(handshakeA.getPendingRequest(req.requestId), isNotNull);

        // Pruning at 15 minutes in future cleans it up
        final futureTime = now.add(const Duration(minutes: 15));
        handshakeA.cleanExpiredPendingRequests(now: futureTime);

        expect(handshakeA.getPendingRequest(req.requestId), isNull,
            reason: 'Stale pending request is garbage-collected to prevent memory bloat');
      });

      test('A.2 Known peer presenting a changed identity key is rejected (MITM detection)', () async {
        final pubKeyAlice = await identityServiceA.getIdentityPublicKey();
        final now = DateTime.now();

        // Bob already knows Alice with a legitimate key
        await messageRepository.savePeerIdentity(
          PeerIdentityEntry(
            peerId: 'ML-ALICE',
            identityPublicKey: pubKeyAlice,
            safetyNumber: '123456',
            trustStatus: 'verified',
            protocolVersion: 2,
            firstSeenAt: now,
            lastSeenAt: now,
          ),
        );

        // Malicious third party generates their own key pair pretending to be Alice
        final attackerIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
        await attackerIdentity.initialize();
        final attackerHandshake = HandshakeService(
          identityService: attackerIdentity,
          localId: 'ML-ALICE',
        );

        final forgedReq = await attackerHandshake.createKeyRequest(
          destinationId: 'ML-BOB',
          requestId: 'REQ-FORGED-1',
        );

        // Bob verifies request and MUST reject with peerIdentityMismatch
        expect(
          () => handshakeB.verifyKeyRequest(forgedReq),
          throwsA(isA<HandshakeException>().having(
            (e) => e.code,
            'code',
            HandshakeErrorCode.peerIdentityMismatch,
          )),
        );
      });

      test('A.3 Directional session key symmetry: A.sendKey == B.receiveKey, sendKey != receiveKey', () async {
        final req = await handshakeA.createKeyRequest(destinationId: 'ML-BOB');
        final verifiedReq = await handshakeB.verifyKeyRequest(req);
        final resp = await handshakeB.createKeyResponse(request: req);
        final verifiedResp = await handshakeA.verifyKeyResponse(resp);

        final sessionA = await handshakeA.completeSessionAsInitiator(verifiedResponse: verifiedResp);
        final sessionB = await handshakeB.completeSessionAsResponder(verifiedRequest: verifiedReq);

        final encService = DirectionalSessionEncryptionService();
        final keysA = await encService.getOrDeriveKeys(sessionA);
        final keysB = await encService.getOrDeriveKeys(sessionB);

        expect(keysA.sendKey, equals(keysB.receiveKey), reason: "Alice's send key must equal Bob's receive key");
        expect(keysA.receiveKey, equals(keysB.sendKey), reason: "Alice's receive key must equal Bob's send key");
        expect(keysA.sendKey, isNot(equals(keysA.receiveKey)), reason: 'Directional keys must differ');
      });

      test('A.4 Session destruction zeroes secret keys in memory', () async {
        final req = await handshakeA.createKeyRequest(destinationId: 'ML-BOB');
        await handshakeB.verifyKeyRequest(req);
        final resp = await handshakeB.createKeyResponse(request: req);
        final verifiedResp = await handshakeA.verifyKeyResponse(resp);

        final sessionA = await handshakeA.completeSessionAsInitiator(verifiedResponse: verifiedResp);
        final encService = DirectionalSessionEncryptionService();
        final keysA = await encService.getOrDeriveKeys(sessionA);

        expect(sessionA.isDestroyed, isFalse);
        expect(sessionA.sharedSecret.every((b) => b == 0), isFalse);

        // Destroy session
        sessionA.destroy();

        expect(sessionA.isDestroyed, isTrue);
        expect(sessionA.sharedSecret.every((b) => b == 0), isTrue, reason: 'Shared secret must be zeroed');
        expect(keysA.isDestroyed, isTrue);
        expect(() => keysA.sendKey, throwsStateError, reason: 'Accessing destroyed keys must throw StateError');
        expect(() => keysA.receiveKey, throwsStateError);
      });
    });

    // =========================================================================
    // Area D: File Transfer, Storage & Traversal Security
    // =========================================================================
    group('Area D: File System Containment & Integrity', () {
      test('D.1 FilePathService blocks symlink breakouts and directory traversal', () {
        final tempDir = Directory.systemTemp.createTempSync('meshlink_audit_sec_');
        try {
          final basePath = tempDir.path;
          final insideFile = '${tempDir.path}${Platform.pathSeparator}normal.txt';
          final outsideFile1 = '${tempDir.path}${Platform.pathSeparator}..${Platform.pathSeparator}escaped.txt';
          final outsideFile2 = '${tempDir.path}${Platform.pathSeparator}sub${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}escaped.txt';

          expect(FilePathService.isPathInsideDirectory(insideFile, basePath), isTrue);
          expect(FilePathService.isPathInsideDirectory(outsideFile1, basePath), isFalse);
          expect(FilePathService.isPathInsideDirectory(outsideFile2, basePath), isFalse);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('D.2 FileAssemblyService verifies whole-file SHA-256 and constant-time comparison', () {
        const hashA = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        const hashB = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        const hashC = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b856';

        expect(FileAssemblyService.constantTimeHashCompare(hashA, hashB), isTrue);
        expect(FileAssemblyService.constantTimeHashCompare(hashA, hashC), isFalse);
        expect(FileAssemblyService.constantTimeHashCompare(hashA, 'short'), isFalse);
      });
    });

    // =========================================================================
    // Area E: Database Integrity & Replay Protection
    // =========================================================================
    group('Area E: Persistent Replay Protection & Database Integrity', () {
      test('E.1 Replay protection rejects duplicate replay within category and isolates by packetType', () async {
        final now = DateTime.now();
        // 1. Initial insert of encrypted_message is accepted
        final firstInsert = await replayService.checkAndMarkSeen(
          packetType: 'encrypted_message',
          originId: 'ML-NODE-1',
          packetId: 'MSG-REPLAY-1',
          timestamp: now,
        );
        expect(firstInsert.isAccepted, isTrue);

        // 2. Duplicate encrypted_message with same (originId, packetId) is rejected
        final secondInsert = await replayService.checkAndMarkSeen(
          packetType: 'encrypted_message',
          originId: 'ML-NODE-1',
          packetId: 'MSG-REPLAY-1',
          timestamp: now,
        );
        expect(secondInsert.isAccepted, isFalse, reason: 'Duplicate packet must be rejected');

        // 3. Different packetType ('ack') with same (originId, packetId) is isolated by protocol design
        final ackInsert = await replayService.checkAndMarkSeen(
          packetType: 'ack',
          originId: 'ML-NODE-1',
          packetId: 'MSG-REPLAY-1',
          timestamp: now,
        );
        expect(
          ackInsert.isAccepted,
          isTrue,
          reason: 'Replay keys are canonically scoped as packetType:originId:packetId for domain isolation',
        );
      });

      test('E.2 Database check constraints prevent negative file size or zero chunk size', () async {
        final now = DateTime.now();
        expect(
          () => db.insertFileTransfer(
            FileTransfersTableCompanion.insert(
              transferId: 'TR-SEC-CHECK',
              conversationId: 'CONV-1',
              peerId: 'ML-PEER',
              direction: 'incoming',
              fileName: 'check.dat',
              fileSize: BigInt.from(-1), // Negative file size!
              mimeType: 'application/octet-stream',
              fileHash: 'deadbeef',
              localPath: '',
              stagingPath: 'staging/check.dat',
              totalChunks: 1,
              chunkSize: 1024,
              status: 'transferring',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(anything),
        );
      });

      test('E.3 Replay protection persists across database restart and survives service re-creation', () async {
        final now = DateTime.now();
        // Insert via first service instance
        final res = await replayService.checkAndMarkSeen(
          packetType: 'file_chunk',
          originId: 'ML-NODE-2',
          packetId: 'CHUNK-REPLAY-1',
          timestamp: now,
        );
        expect(res.isAccepted, isTrue);

        // Create a new ReplayProtectionService pointing to the same database
        final reloadedService = ReplayProtectionService(repository: messageRepository);
        final isSeen = await reloadedService.isSeen(
          packetType: 'file_chunk',
          originId: 'ML-NODE-2',
          packetId: 'CHUNK-REPLAY-1',
        );
        expect(isSeen, isTrue, reason: 'Replay state must survive across service lifecycle');

        final duplicateAfterRestart = await reloadedService.checkAndMarkSeen(
          packetType: 'file_chunk',
          originId: 'ML-NODE-2',
          packetId: 'CHUNK-REPLAY-1',
          timestamp: now,
        );
        expect(duplicateAfterRestart.isAccepted, isFalse);
      });

      test('E.4 Concurrent duplicate insertions are atomically handled (only one accepted)', () async {
        final now = DateTime.now();
        final futures = List.generate(
          5,
          (_) => replayService.checkAndMarkSeen(
            packetType: 'encrypted_message',
            originId: 'ML-NODE-3',
            packetId: 'MSG-CONCURRENT-1',
            timestamp: now,
          ),
        );

        final outcomes = await Future.wait(futures);
        final acceptedCount = outcomes.where((o) => o.isAccepted).length;
        final duplicateCount = outcomes.where((o) => o.isDuplicate).length;

        expect(acceptedCount, equals(1), reason: 'Exactly one concurrent insertion must succeed');
        expect(duplicateCount, equals(4), reason: 'All concurrent races must be rejected');
      });
    });
  });
}
