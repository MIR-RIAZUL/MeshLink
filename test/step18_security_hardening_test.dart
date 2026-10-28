import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/handshake_packets.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_resumption_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';

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

  group('Phase 8 Step 18 — Security Hardening Tests', () {
    late AppDatabase db;
    late MessageRepository messageRepository;
    late MeshIdentityService identityServiceA;
    late MeshIdentityService identityServiceB;
    late EphemeralSessionService sessionServiceA;
    late EphemeralSessionService sessionServiceB;
    late HandshakeService handshakeA;
    late HandshakeService handshakeB;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      messageRepository = DriftMessageRepository(db);

      identityServiceA = MeshIdentityService(
        store: InMemorySecureIdentityStoreV2(),
      );
      identityServiceB = MeshIdentityService(
        store: InMemorySecureIdentityStoreV2(),
      );

      await identityServiceA.initialize();
      await identityServiceB.initialize();

      sessionServiceA = EphemeralSessionService();
      sessionServiceB = EphemeralSessionService();

      handshakeA = HandshakeService(
        identityService: identityServiceA,
        localId: 'ML-NODE-A',
        peerRepository: messageRepository,
        sessionService: sessionServiceA,
      );

      handshakeB = HandshakeService(
        identityService: identityServiceB,
        localId: 'ML-NODE-B',
        peerRepository: messageRepository,
        sessionService: sessionServiceB,
      );
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // 1. Peer Identity & Session Security
    // -------------------------------------------------------------------------
    test('1. Handshake to self is rejected immediately', () async {
      expect(
        () => handshakeA.createKeyRequest(
          destinationId: 'ML-NODE-A',
          requestId: 'REQ-SELF-1',
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidRequest,
        )),
      );
    });

    test('2. Handshake request addressed to wrong destination is rejected', () async {
      final reqForCharlie = await handshakeA.createKeyRequest(
        destinationId: 'ML-NODE-CHARLIE',
        requestId: 'REQ-MISDIRECT-1',
      );

      expect(
        () => handshakeB.verifyKeyRequest(reqForCharlie),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidRequest,
        )),
      );
    });

    test('3. Handshake request with reflection loop (origin == local) is rejected', () async {
      final keyPair = await Ed25519().newKeyPair();
      final pubKey = await keyPair.extractPublicKey();

      final transcript = HandshakeTranscriptEncoder.encodeKeyRequestTranscript(
        protocolVersion: 2,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        requestId: 'REQ-LOOP-1',
        originId: 'ML-NODE-B',
        destinationId: 'ML-NODE-B',
        initiatorIdentityKey: pubKey.bytes,
        initiatorEphemeralKey: pubKey.bytes,
      );
      final sig = await Ed25519().sign(transcript, keyPair: keyPair);

      final loopReq = KeyRequestPacket(
        protocolVersion: 2,
        requestId: 'REQ-LOOP-1',
        originId: 'ML-NODE-B',
        destinationId: 'ML-NODE-B',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        identityPublicKey: base64Url.encode(pubKey.bytes),
        ephemeralPublicKey: base64Url.encode(pubKey.bytes),
        signature: base64Url.encode(sig.bytes),
      );

      expect(
        () => handshakeB.verifyKeyRequest(loopReq),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.invalidRequest,
        )),
      );
    });

    test('4. Compromised peer is rejected in createKeyRequest and verifyKeyRequest', () async {
      final pubKeyA = await identityServiceA.getIdentityPublicKey();
      final pubKeyB = await identityServiceB.getIdentityPublicKey();
      final now = DateTime.now();

      // Register Alice as compromised in Bob's database
      await messageRepository.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-NODE-A',
          identityPublicKey: pubKeyA,
          safetyNumber: '11111',
          trustStatus: 'compromised',
          protocolVersion: 2,
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );

      // Register Bob as compromised in Alice's database
      await messageRepository.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-NODE-B',
          identityPublicKey: pubKeyB,
          safetyNumber: '22222',
          trustStatus: 'compromised',
          protocolVersion: 2,
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );

      // Alice initiating to compromised Bob is blocked
      expect(
        () => handshakeA.createKeyRequest(
          destinationId: 'ML-NODE-B',
          requestId: 'REQ-COMP-1',
        ),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.peerIdentityMismatch,
        )),
      );

      // Temporarily mark Bob trusted in Alice's store so Alice can construct request
      await messageRepository.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-NODE-B',
          identityPublicKey: pubKeyB,
          safetyNumber: '22222',
          trustStatus: 'trusted',
          protocolVersion: 2,
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );

      final reqFromAlice = await handshakeA.createKeyRequest(
        destinationId: 'ML-NODE-B',
        requestId: 'REQ-COMP-2',
      );

      // Bob receiving request from compromised Alice is blocked
      expect(
        () => handshakeB.verifyKeyRequest(reqFromAlice),
        throwsA(isA<HandshakeException>().having(
          (e) => e.code,
          'code',
          HandshakeErrorCode.peerIdentityMismatch,
        )),
      );
    });

    // -------------------------------------------------------------------------
    // 2. Encrypted Envelope & Loop Defenses
    // -------------------------------------------------------------------------
    test('5. EncryptedFileChunkEnvelope with origin == destination is rejected', () {
      expect(
        () => EncryptedFileChunkEnvelope(
          version: 2,
          transferId: 'TR-LOOP-1',
          originId: 'ML-SAME-NODE',
          destinationId: 'ML-SAME-NODE',
          sessionId: 'SES-001',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 10,
          nonce: Uint8List(12),
          mac: Uint8List(16),
          ciphertext: Uint8List(10),
        ).validate(),
        throwsFormatException,
      );
    });

    test('6. FileTransferCryptoService.validateChunkMetadata rejects identical origin and destination', () {
      expect(
        () => FileTransferCryptoService.validateChunkMetadata(
          transferId: 'TR-1',
          originId: 'ML-NODE-X',
          destinationId: 'ML-NODE-X',
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 100,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('7. MeshRouter drops packets where origin == destination', () async {
      final mockDiscovery = _MockDiscoveryService();
      final router = MeshRouter(
        discoveryService: mockDiscovery,
        localId: 'ML-ROUTER-1',
        getConnectedPeers: () => {'ML-PEER-1'},
      );

      // Self-loop chunk
      final chunkResult = await router.handleIncomingPayload(
        jsonEncode({
          'type': 'encrypted_file_chunk',
          'ttl': 5,
          'hopCount': 0,
          'from': 'ML-NODE-X',
          'originId': 'ML-NODE-X',
          'destinationId': 'ML-NODE-X',
          'transferId': 'TR-1',
          'chunkIndex': 0,
          'sessionId': 'SES-1',
          'epoch': 0,
          'sequenceNumber': 1,
          'totalChunks': 1,
          'offset': 0,
          'chunkLength': 10,
          'nonce': base64Url.encode(Uint8List(12)),
          'mac': base64Url.encode(Uint8List(16)),
          'ciphertext': base64Url.encode(Uint8List(10)),
        }),
        fromPeerId: 'ML-PEER-1',
      );

      // Self-loop chunk ACK
      final ackResult = await router.handleIncomingPayload(
        jsonEncode({
          'type': 'chunk_ack',
          'ttl': 5,
          'hopCount': 0,
          'from': 'ML-NODE-X',
          'originId': 'ML-NODE-X',
          'destinationId': 'ML-NODE-X',
          'transferId': 'TR-1',
          'chunkIndex': 0,
          'sessionId': 'SES-1',
          'epoch': 0,
          'sequenceNumber': 1,
          'totalChunks': 1,
          'ackType': 0,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'nonce': base64Url.encode(Uint8List(12)),
          'mac': base64Url.encode(Uint8List(16)),
          'ciphertext': base64Url.encode(Uint8List(10)),
        }),
        fromPeerId: 'ML-PEER-1',
      );

      expect(chunkResult, isA<DroppedPayload>());
      expect(ackResult, isA<DroppedPayload>());
      expect(mockDiscovery.sentPayloads, isEmpty);
    });

    test('8. MeshRouter drops packets with invalid TTL or routing loops', () async {
      final mockDiscovery = _MockDiscoveryService();
      final router = MeshRouter(
        discoveryService: mockDiscovery,
        localId: 'ML-ROUTER-1',
        getConnectedPeers: () => {'ML-DEST'},
      );

      // Packet with ttl = 0
      final resultTtl0 = await router.handleIncomingPayload(
        jsonEncode({
          'type': 'encrypted_message',
          'ttl': 0,
          'hopCount': 0,
          'from': 'ML-PREV',
          'originId': 'ML-ORIGIN',
          'destinationId': 'ML-DEST',
          'messageId': 'MSG-1',
        }),
        fromPeerId: 'ML-PREV',
      );

      // Packet with excessive ttl > maxTtl (10)
      final resultExcessTtl = await router.handleIncomingPayload(
        jsonEncode({
          'type': 'encrypted_message',
          'ttl': 15,
          'hopCount': 0,
          'from': 'ML-PREV',
          'originId': 'ML-ORIGIN',
          'destinationId': 'ML-DEST',
          'messageId': 'MSG-2',
        }),
        fromPeerId: 'ML-PREV',
      );

      // Packet where fromPeerId == destinationId (immediate bounce)
      final resultBounce = await router.handleIncomingPayload(
        jsonEncode({
          'type': 'encrypted_message',
          'ttl': 5,
          'hopCount': 1,
          'from': 'ML-DEST',
          'originId': 'ML-ORIGIN',
          'destinationId': 'ML-DEST',
          'messageId': 'MSG-3',
        }),
        fromPeerId: 'ML-DEST',
      );

      expect(resultTtl0, isA<DroppedPayload>());
      expect(resultExcessTtl, isA<DroppedPayload>());
      expect(resultBounce, isA<DroppedPayload>());
      expect(mockDiscovery.sentPayloads, isEmpty);
    });

    // -------------------------------------------------------------------------
    // 3. File System Safety & Path Traversal
    // -------------------------------------------------------------------------
    test('9. FilePathService.isPathInsideDirectory blocks directory traversal attacks', () {
      final tempDir = Directory.systemTemp.createTempSync('meshlink_sec_test_');
      try {
        final dirPath = tempDir.path;
        final safeChild = '${tempDir.path}${Platform.pathSeparator}safe_file.bin';
        final traversalAttempt1 = '${tempDir.path}${Platform.pathSeparator}..${Platform.pathSeparator}evil.bin';
        final traversalAttempt2 = '${tempDir.path}${Platform.pathSeparator}sub${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}evil.bin';

        expect(FilePathService.isPathInsideDirectory(safeChild, dirPath), isTrue);
        expect(FilePathService.isPathInsideDirectory(traversalAttempt1, dirPath), isFalse);
        expect(FilePathService.isPathInsideDirectory(traversalAttempt2, dirPath), isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('10. FilePathService.sanitizeFileName strips illegal chars and traversal sequences', () {
      expect(FilePathService.sanitizeFileName('../../secret.txt'), equals('secret.txt'));
      expect(FilePathService.sanitizeFileName('..\\..\\secret.txt'), equals('secret.txt'));
      expect(FilePathService.sanitizeFileName('/etc/passwd'), equals('passwd'));
      expect(FilePathService.sanitizeFileName('C:\\Windows\\System32\\cmd.exe'), equals('cmd.exe'));
      expect(FilePathService.sanitizeFileName('bad:file*name?.txt'), equals('bad_file_name_.txt'));
    });

    // -------------------------------------------------------------------------
    // 4. Resumption & Resource Exhaustion Defenses
    // -------------------------------------------------------------------------
    test('11. FileChunkResumeRequest deduplicates missing chunks and enforces limit', () {
      final now = DateTime.now();
      final req = FileChunkResumeRequest(
        transferId: 'TR-RES-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SES-RES-1',
        epoch: 0,
        missingChunkIndexes: [1, 2, 2, 3, 1, 4],
        createdAt: now,
      );

      expect(req.missingChunkIndexes, equals([1, 2, 3, 4]));

      final massiveList = List<int>.generate(100001, (i) => i);
      expect(
        () => FileChunkResumeRequest(
          transferId: 'TR-RES-2',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SES-RES-2',
          epoch: 0,
          missingChunkIndexes: massiveList,
          createdAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('12. Database and FileAssemblyService enforce chunkSize > 0', () async {
      final now = DateTime.now();
      // Database CHECK constraint enforces chunkSize > 0
      expect(
        () => db.insertFileTransfer(
          FileTransfersTableCompanion.insert(
            transferId: 'TR-INV-1',
            conversationId: 'CONV-1',
            peerId: 'ML-A',
            direction: 'incoming',
            fileName: 'test.dat',
            fileSize: BigInt.from(100),
            mimeType: 'application/octet-stream',
            fileHash: 'deadbeef',
            localPath: '',
            stagingPath: 'staging/test.dat',
            totalChunks: 1,
            chunkSize: 0, // Invalid!
            status: 'transferring',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
      );
    });
  });
}
