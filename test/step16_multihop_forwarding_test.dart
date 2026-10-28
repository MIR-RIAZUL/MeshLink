import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_ack_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart'
    hide ChunkMetadataMismatchException;
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/file_transfer.dart';
import 'package:path/path.dart' as p;

class MockDiscoveryService implements DeviceDiscoveryService {
  MockDiscoveryService({
    required this.localIdentity,
  });

  final LocalIdentity localIdentity;
  final StreamController<DeviceDiscoveryEvent> _controller =
      StreamController<DeviceDiscoveryEvent>.broadcast();

  final List<Map<String, String>> sentTransmissions = [];
  bool shouldSendSucceed = true;
  Future<bool> Function(String deviceId, String payload)? onSendMessage;

  @override
  Stream<DeviceDiscoveryEvent> get events => _controller.stream;

  void emit(DeviceDiscoveryEvent event) => _controller.add(event);

  @override
  Future<bool> sendMessage(String deviceId, String payload) async {
    if (!shouldSendSucceed) return false;
    sentTransmissions.add({'deviceId': deviceId, 'payload': payload});
    if (onSendMessage != null) {
      return await onSendMessage!(deviceId, payload);
    }
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

class TestMeshNode {
  TestMeshNode({
    required this.id,
    required this.name,
    required this.baseDir,
    required this.clock,
  }) {
    discovery = MockDiscoveryService(
      localIdentity: LocalIdentity(id: id, name: name),
    );
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMessageRepository(db);
    replayService = ReplayProtectionService(repository: repo);
    router = MeshRouter(
      discoveryService: discovery,
      localId: id,
      replayProtectionService: replayService,
      getConnectedPeers: () => connectedPeers,
    );
    identity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    sessionService = EphemeralSessionService(clock: clock);
    handshake = HandshakeService(
      identityService: identity,
      localId: id,
      sessionService: sessionService,
    );
    pathService = FilePathService(baseDirectory: baseDir);
    assemblyService = FileAssemblyService(
      database: db,
      pathService: pathService,
    );
    directionalService = DirectionalSessionEncryptionService();
    cryptoService = FileTransferCryptoService(encryptionService: directionalService);
    ackService = ChunkAckService(
      localDeviceId: id,
      database: db,
      messageRepository: repo,
      replayProtectionService: replayService,
      encryptionService: directionalService,
    );
    receivingPipeline = ChunkReceivingPipeline(
      localDeviceId: id,
      database: db,
      messageRepository: repo,
      replayProtectionService: replayService,
      cryptoService: cryptoService,
      pathService: pathService,
      assemblyService: assemblyService,
      ackService: ackService,
    );
    sendingPipeline = ChunkSendingPipeline(
      localDeviceId: id,
      database: db,
      messageRepository: repo,
      cryptoService: cryptoService,
    );
  }

  final String id;
  final String name;
  final Directory baseDir;
  final DateTime Function() clock;
  final Set<String> connectedPeers = {};

  late final MockDiscoveryService discovery;
  late final AppDatabase db;
  late final DriftMessageRepository repo;
  late final ReplayProtectionService replayService;
  late final MeshRouter router;
  late final MeshIdentityService identity;
  late final EphemeralSessionService sessionService;
  late final HandshakeService handshake;
  late final FilePathService pathService;
  late final FileAssemblyService assemblyService;
  late final DirectionalSessionEncryptionService directionalService;
  late final FileTransferCryptoService cryptoService;
  late final ChunkReceivingPipeline receivingPipeline;
  late final ChunkSendingPipeline sendingPipeline;
  late final ChunkAckService ackService;

  Future<void> initialize() async {
    await identity.initialize();
  }

  Future<void> dispose() async {
    await receivingPipeline.closeAll();
    await router.dispose();
    await db.close();
    await discovery.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDir;
  late TestMeshNode nodeA; // Alice
  late TestMeshNode nodeB; // Bob (Intermediate relay)
  late TestMeshNode nodeC; // Charlie (Destination)

  final testNow = DateTime.utc(2026, 10, 29, 14, 0, 0);

  Future<String> calculateSha256(Uint8List bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<FileTransfer> createTransferInDb({
    required AppDatabase db,
    required FilePathService pathService,
    required String transferId,
    required String fileName,
    required int fileSize,
    required int chunkSize,
    required int totalChunks,
    required String fileHash,
    required String direction,
    required String status,
    required String peerId,
    String? stagingPath,
    String? localPath,
  }) async {
    final staging = stagingPath ?? await pathService.getStagingPath(transferId);
    final dest = localPath ??
        p.join((await pathService.getCompletedDirectory()).path, fileName);
    final companion = FileTransfersTableCompanion.insert(
      transferId: transferId,
      conversationId: 'CONV-$transferId',
      peerId: peerId,
      direction: direction,
      fileName: fileName,
      fileSize: BigInt.from(fileSize),
      mimeType: 'application/octet-stream',
      fileHash: fileHash,
      localPath: dest,
      stagingPath: staging,
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      status: status,
      createdAt: testNow,
      updatedAt: testNow,
    );
    await db.insertFileTransfer(companion);
    return FileTransfer.fromEntry((await db.getFileTransfer(transferId))!);
  }

  Future<({EphemeralSession sessionAlice, EphemeralSession sessionCharlie})>
      establishSessionAC() async {
    final req = await nodeA.handshake.createKeyRequest(
      destinationId: nodeC.id,
      requestId: 'REQ-AC-001',
    );
    final resp = await nodeC.handshake.createKeyResponse(request: req);
    final verifiedResp = await nodeA.handshake.verifyKeyResponse(resp);
    final verifiedReq = await nodeC.handshake.verifyKeyRequest(req);

    final sessionA = await nodeA.handshake.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: testNow,
    );
    final sessionC = await nodeC.handshake.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: testNow,
    );
    return (sessionAlice: sessionA, sessionCharlie: sessionC);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step16_test_');

    final dirA = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
    final dirB = Directory(p.join(tempDir.path, 'nodeB'))..createSync();
    final dirC = Directory(p.join(tempDir.path, 'nodeC'))..createSync();

    nodeA = TestMeshNode(
      id: 'ML-DEVICE-ALICE',
      name: 'Alice',
      baseDir: dirA,
      clock: () => testNow,
    );
    nodeB = TestMeshNode(
      id: 'ML-DEVICE-BOB',
      name: 'Bob',
      baseDir: dirB,
      clock: () => testNow,
    );
    nodeC = TestMeshNode(
      id: 'ML-DEVICE-CHARLIE',
      name: 'Charlie',
      baseDir: dirC,
      clock: () => testNow,
    );

    await nodeA.initialize();
    await nodeB.initialize();
    await nodeC.initialize();

    // Topology: Alice (A) <-> Bob (B) <-> Charlie (C)
    // Alice and Charlie are NOT directly connected.
    nodeA.connectedPeers.add(nodeB.id);
    nodeB.connectedPeers.addAll([nodeA.id, nodeC.id]);
    nodeC.connectedPeers.add(nodeB.id);

    await nodeA.repo.savePeerIdentity(
      PeerIdentityEntry(
        peerId: nodeC.id,
        identityPublicKey: await nodeC.identity.getIdentityPublicKey(),
        safetyNumber: '111111',
        trustStatus: 'verified',
        protocolVersion: 2,
        firstSeenAt: testNow,
        lastSeenAt: testNow,
      ),
    );
    await nodeC.repo.savePeerIdentity(
      PeerIdentityEntry(
        peerId: nodeA.id,
        identityPublicKey: await nodeA.identity.getIdentityPublicKey(),
        safetyNumber: '333333',
        trustStatus: 'verified',
        protocolVersion: 2,
        firstSeenAt: testNow,
        lastSeenAt: testNow,
      ),
    );
  });

  tearDown(() async {
    await nodeA.dispose();
    await nodeB.dispose();
    await nodeC.dispose();
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase 8 Step 16: Multihop File-Transfer Forwarding', () {
    test('1. Forwarding a valid encrypted chunk through an intermediate node', () async {
      final sessions = await establishSessionAC();
      final cryptoService = nodeA.cryptoService;

      final chunkEnvelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-MH-001',
        originId: nodeA.id,
        destinationId: nodeC.id,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List.fromList(utf8.encode('Hello MultiHop MeshLink!')),
        chunkLength: 24,
      );

      // Alice sends chunk towards Charlie via router
      final sentByAlice = await nodeA.router.routeFileChunk(chunkEnvelope, ttl: 5);
      expect(sentByAlice, isTrue);
      expect(nodeA.discovery.sentTransmissions, hasLength(1));
      expect(nodeA.discovery.sentTransmissions.first['deviceId'], equals(nodeB.id));

      final wireFromAlice = nodeA.discovery.sentTransmissions.first['payload']!;

      // Bob receives payload from Alice
      final bobResult = await nodeB.router.handleIncomingPayload(
        wireFromAlice,
        fromPeerId: nodeA.id,
      );

      expect(bobResult, isA<RelayedFileChunk>());
      final relayed = bobResult as RelayedFileChunk;
      expect(relayed.transferId, equals('TX-MH-001'));
      expect(relayed.chunkIndex, equals(0));
      expect(relayed.destinationId, equals(nodeC.id));
      expect(relayed.newTtl, equals(4)); // Decremented by 1
      expect(relayed.newHopCount, equals(1)); // Incremented by 1
      expect(relayed.forwardedCount, equals(1));

      // Bob forwards to Charlie
      expect(nodeB.discovery.sentTransmissions, hasLength(1));
      expect(nodeB.discovery.sentTransmissions.first['deviceId'], equals(nodeC.id));

      final wireFromBob = nodeB.discovery.sentTransmissions.first['payload']!;

      // Charlie receives relayed payload from Bob
      final charlieResult = await nodeC.router.handleIncomingPayload(
        wireFromBob,
        fromPeerId: nodeB.id,
      );

      expect(charlieResult, isA<LocalFileChunkDelivery>());
      final delivery = charlieResult as LocalFileChunkDelivery;
      expect(delivery.envelope.transferId, equals(chunkEnvelope.transferId));
      expect(delivery.envelope.chunkIndex, equals(0));
      expect(delivery.envelope.originId, equals(nodeA.id));
      expect(delivery.envelope.destinationId, equals(nodeC.id));
      expect(delivery.envelope.ciphertext, equals(chunkEnvelope.ciphertext));
    });

    test('2. Intermediate forwarding without payload decryption', () async {
      final sessions = await establishSessionAC();
      final cryptoService = nodeA.cryptoService;
      final plaintext = Uint8List.fromList(utf8.encode('Top Secret E2E File Payload'));

      final chunkEnvelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-SECRET-001',
        originId: nodeA.id,
        destinationId: nodeC.id,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
        chunkLength: plaintext.length,
      );

      // Verify Bob DOES NOT have an active session with Alice or Charlie
      expect(
        nodeB.sessionService.getSession(nodeA.id),
        isNull,
      );
      expect(
        nodeB.sessionService.getSession(nodeC.id),
        isNull,
      );

      // Alice sends to Bob
      await nodeA.router.routeFileChunk(chunkEnvelope, ttl: 4);
      final wireFromAlice = nodeA.discovery.sentTransmissions.first['payload']!;

      // Bob relays to Charlie without possessing keys
      final bobResult = await nodeB.router.handleIncomingPayload(
        wireFromAlice,
        fromPeerId: nodeA.id,
      );
      expect(bobResult, isA<RelayedFileChunk>());

      final wireFromBob = nodeB.discovery.sentTransmissions.first['payload']!;

      // Charlie receives and decrypts with end-to-end session
      final charlieResult = await nodeC.router.handleIncomingPayload(
        wireFromBob,
        fromPeerId: nodeB.id,
      );
      expect(charlieResult, isA<LocalFileChunkDelivery>());
      final delivery = charlieResult as LocalFileChunkDelivery;

      final decrypted = await nodeC.cryptoService.decryptChunk(
        session: sessions.sessionCharlie,
        envelope: delivery.envelope,
      );
      expect(decrypted, equals(plaintext));
    });

    test('3. TTL exhaustion and hop-limit enforcement', () async {
      final sessions = await establishSessionAC();
      final cryptoService = nodeA.cryptoService;

      final envelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-TTL-001',
        originId: nodeA.id,
        destinationId: nodeC.id,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(32),
        chunkLength: 32,
      );

      // 3a. TTL = 1 arrives at Bob -> new TTL = 0 -> drops
      final ttl1Packet = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 1,
        'hopCount': 2,
        ...envelope.toMap(),
      });

      final res1 = await nodeB.router.handleIncomingPayload(ttl1Packet, fromPeerId: nodeA.id);
      expect(res1, isA<DroppedPayload>());
      expect((res1 as DroppedPayload).reason, contains('TTL expired'));
      expect(nodeB.discovery.sentTransmissions, isEmpty);

      // 3b. TTL <= 0 arrives at Bob -> drops
      final ttl0Packet = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 0,
        'hopCount': 0,
        ...envelope.toMap(),
      });
      final res0 = await nodeB.router.handleIncomingPayload(ttl0Packet, fromPeerId: nodeA.id);
      expect(res0, isA<DroppedPayload>());
      expect((res0 as DroppedPayload).reason, contains('TTL expired'));

      // 3c. HopCount >= maxHopCount (32) arrives at Bob -> drops
      final hop32Packet = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 10,
        'hopCount': 32,
        ...envelope.toMap(),
      });
      final resHop = await nodeB.router.handleIncomingPayload(hop32Packet, fromPeerId: nodeA.id);
      expect(resHop, isA<DroppedPayload>());
      expect((resHop as DroppedPayload).reason, contains('Hop limit exceeded'));

      // 3d. TTL > maxTtl (64) arrives at Bob -> drops
      final highTtlPacket = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 70,
        'hopCount': 0,
        ...envelope.toMap(),
      });
      final resHighTtl = await nodeB.router.handleIncomingPayload(highTtlPacket, fromPeerId: nodeA.id);
      expect(resHighTtl, isA<DroppedPayload>());
      expect((resHighTtl as DroppedPayload).reason, contains('exceeds maximum allowed TTL'));
    });

    test('4. Duplicate packets and routing-loop prevention', () async {
      final sessions = await establishSessionAC();
      final cryptoService = nodeA.cryptoService;

      final envelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-DUP-001',
        originId: nodeA.id,
        destinationId: nodeC.id,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(32),
        chunkLength: 32,
      );

      final wirePayload = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 5,
        'hopCount': 0,
        ...envelope.toMap(),
      });

      // First time: relays successfully
      final res1 = await nodeB.router.handleIncomingPayload(wirePayload, fromPeerId: nodeA.id);
      expect(res1, isA<RelayedFileChunk>());
      expect(nodeB.discovery.sentTransmissions, hasLength(1));

      // Second time (duplicate): dropped and suppressed
      final res2 = await nodeB.router.handleIncomingPayload(wirePayload, fromPeerId: nodeA.id);
      expect(res2, isA<DroppedPayload>());
      expect((res2 as DroppedPayload).reason, contains('Duplicate'));
      expect(nodeB.discovery.sentTransmissions, hasLength(1)); // No extra forward

      // Routing loop A: received from packet destination itself
      final loopFromDest = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 5,
        'hopCount': 1,
        ...envelope.toMap(),
      });
      final resLoopDest = await nodeB.router.handleIncomingPayload(
        loopFromDest,
        fromPeerId: nodeC.id, // Received from destination!
      );
      expect(resLoopDest, isA<DroppedPayload>());
      expect((resLoopDest as DroppedPayload).reason, contains('Routing loop detected'));

      // Routing loop B: packet originated locally on Bob
      final loopLocalOrigin = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 5,
        'hopCount': 0,
        'originId': nodeB.id, // Bob's own localId
        'destinationId': nodeC.id,
        'transferId': 'TX-LOCAL-001',
        'chunkIndex': 0,
        'totalChunks': 1,
        'offset': 0,
        'chunkLength': 32,
        'sessionId': 'SESS-001',
        'epoch': 0,
        'sequenceNumber': 1,
        'nonce': base64UrlEncode(Uint8List(12)),
        'mac': base64UrlEncode(Uint8List(16)),
        'ciphertext': base64UrlEncode(Uint8List(32)),
      });
      final resLocal = await nodeB.router.handleIncomingPayload(loopLocalOrigin, fromPeerId: nodeA.id);
      expect(resLocal, isA<DroppedPayload>());
      expect((resLocal as DroppedPayload).reason, contains('originated locally'));
    });

    test('5. Preservation of immutable envelope fields', () async {
      final sessions = await establishSessionAC();
      final cryptoService = nodeA.cryptoService;

      final envelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-IMMUTABLE-001',
        originId: nodeA.id,
        destinationId: nodeC.id,
        chunkIndex: 7,
        totalChunks: 10,
        offset: 448,
        plaintext: Uint8List.fromList(List.generate(64, (i) => i * 3)),
        chunkLength: 64,
      );

      final wireFromAlice = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 5,
        'hopCount': 0,
        ...envelope.toMap(),
      });

      await nodeB.router.handleIncomingPayload(wireFromAlice, fromPeerId: nodeA.id);
      expect(nodeB.discovery.sentTransmissions, hasLength(1));

      final forwardedWire = nodeB.discovery.sentTransmissions.first['payload']!;
      final forwardedMap = jsonDecode(forwardedWire) as Map<String, dynamic>;

      // Envelope fields must remain 100% identical
      expect(forwardedMap['version'], equals(2));
      expect(forwardedMap['transferId'], equals('TX-IMMUTABLE-001'));
      expect(forwardedMap['originId'], equals(nodeA.id));
      expect(forwardedMap['destinationId'], equals(nodeC.id));
      expect(forwardedMap['sessionId'], equals(envelope.sessionId));
      expect(forwardedMap['epoch'], equals(envelope.epoch));
      expect(forwardedMap['sequenceNumber'], equals(envelope.sequenceNumber));
      expect(forwardedMap['chunkIndex'], equals(7));
      expect(forwardedMap['totalChunks'], equals(10));
      expect(forwardedMap['offset'], equals(448));
      expect(forwardedMap['chunkLength'], equals(64));
      expect(forwardedMap['nonce'], equals(base64UrlEncode(envelope.nonce)));
      expect(forwardedMap['mac'], equals(base64UrlEncode(envelope.mac)));
      expect(forwardedMap['ciphertext'], equals(base64UrlEncode(envelope.ciphertext)));

      // Only TTL & hopCount change in outer metadata
      expect(forwardedMap['ttl'], equals(4));
      expect(forwardedMap['hopCount'], equals(1));
    });

    test('6. Rejection of malformed or oversized packets', () async {
      // 6a. Malformed JSON
      final resMalformed = await nodeB.router.handleIncomingPayload('{not valid json}');
      expect(resMalformed, isA<DroppedPayload>());
      expect((resMalformed as DroppedPayload).reason, contains('Malformed payload'));

      // 6b. Missing routing metadata
      final resMissingMeta = await nodeB.router.handleIncomingPayload(
        jsonEncode({'type': 'file_chunk', 'version': 2}),
      );
      expect(resMissingMeta, isA<DroppedPayload>());
      expect((resMissingMeta as DroppedPayload).reason, contains('missing routing metadata'));

      // 6c. Malformed envelope (e.g. invalid base64 in nonce)
      final resBadCrypto = await nodeB.router.handleIncomingPayload(
        jsonEncode({
          'type': 'file_chunk',
          'version': 2,
          'ttl': 5,
          'originId': nodeA.id,
          'destinationId': nodeC.id,
          'transferId': 'TX-BAD-001',
          'chunkIndex': 0,
          'totalChunks': 1,
          'offset': 0,
          'chunkLength': 32,
          'sessionId': 'SESS-001',
          'epoch': 0,
          'sequenceNumber': 1,
          'nonce': 'not_valid_base64!',
          'mac': base64UrlEncode(Uint8List(16)),
          'ciphertext': base64UrlEncode(Uint8List(32)),
        }),
      );
      expect(resBadCrypto, isA<DroppedPayload>());
      expect((resBadCrypto as DroppedPayload).reason, contains('Malformed or invalid file chunk envelope'));

      // 6d. Oversized wire payload (> 512 KB)
      final hugePayload = 'A' * (513 * 1024);
      final resHuge = await nodeB.router.handleIncomingPayload(hugePayload);
      expect(resHuge, isA<DroppedPayload>());
      expect((resHuge as DroppedPayload).reason, contains('Payload size limit exceeded'));

      // 6e. Chunk length exceeding maximum allowed chunk length (> 128 KB)
      final hugeChunkPacket = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 5,
        'originId': nodeA.id,
        'destinationId': nodeC.id,
        'transferId': 'TX-HUGE-001',
        'chunkIndex': 0,
        'totalChunks': 1,
        'offset': 0,
        'chunkLength': 129 * 1024, // > 128 KB
        'sessionId': 'SESS-001',
        'epoch': 0,
        'sequenceNumber': 1,
        'nonce': base64UrlEncode(Uint8List(12)),
        'mac': base64UrlEncode(Uint8List(16)),
        'ciphertext': base64UrlEncode(Uint8List(129 * 1024)),
      });
      final resHugeChunk = await nodeB.router.handleIncomingPayload(hugeChunkPacket);
      expect(resHugeChunk, isA<DroppedPayload>());
      expect((resHugeChunk as DroppedPayload).reason, contains('exceeds maximum allowed chunk length'));
    });

    test('7. Unknown destination and unavailable next-hop handling', () async {
      final sessions = await establishSessionAC();
      final cryptoService = nodeA.cryptoService;

      final envelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-UNREACHABLE-001',
        originId: nodeA.id,
        destinationId: 'ML-DEVICE-UNKNOWN',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(16),
        chunkLength: 16,
      );

      // Create an isolated node with zero connected peers
      final isolatedDiscovery = MockDiscoveryService(
        localIdentity: const LocalIdentity(id: 'ML-DEVICE-ISOLATED', name: 'Isolated'),
      );
      final isolatedRouter = MeshRouter(
        discoveryService: isolatedDiscovery,
        localId: 'ML-DEVICE-ISOLATED',
      );

      final wirePacket = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 5,
        'hopCount': 0,
        ...envelope.toMap(),
      });

      final result = await isolatedRouter.handleIncomingPayload(wirePacket);
      expect(result, isA<DroppedPayload>());
      expect((result as DroppedPayload).reason, contains('destination unreachable'));

      await isolatedRouter.dispose();
      await isolatedDiscovery.dispose();
    });

    test('8. End-to-end ACK/NACK authentication across multihop', () async {
      final sessions = await establishSessionAC();

      // Charlie creates an authentic ACK envelope for Alice
      final ack = nodeC.ackService.createAck(
        transferId: 'TX-ACK-001',
        chunkIndex: 0,
        totalChunks: 3,
        destinationId: nodeA.id,
        session: sessions.sessionCharlie,
      );
      final ackEnvelope = await nodeC.ackService.encryptAck(
        ack: ack,
        session: sessions.sessionCharlie,
      );

      // Charlie sends ACK to Bob
      final sentByCharlie = await nodeC.router.routeFileAck(ackEnvelope, ttl: 5);
      expect(sentByCharlie, isTrue);
      expect(nodeC.discovery.sentTransmissions, hasLength(1));

      final wireFromCharlie = nodeC.discovery.sentTransmissions.first['payload']!;

      // Bob relays ACK to Alice
      final bobResult = await nodeB.router.handleIncomingPayload(
        wireFromCharlie,
        fromPeerId: nodeC.id,
      );
      expect(bobResult, isA<RelayedFileAck>());
      final relayedAck = bobResult as RelayedFileAck;
      expect(relayedAck.transferId, equals('TX-ACK-001'));
      expect(relayedAck.chunkIndex, equals(0));
      expect(relayedAck.destinationId, equals(nodeA.id));
      expect(relayedAck.newTtl, equals(4));
      expect(relayedAck.newHopCount, equals(1));

      final wireFromBob = nodeB.discovery.sentTransmissions.first['payload']!;

      // Alice receives relayed ACK
      final aliceResult = await nodeA.router.handleIncomingPayload(
        wireFromBob,
        fromPeerId: nodeB.id,
      );
      expect(aliceResult, isA<LocalFileChunkAckDelivery>());
      final delivery = aliceResult as LocalFileChunkAckDelivery;

      // Alice verifies ACK cryptographically
      final decryptedAck = await nodeA.ackService.decryptAck(
        envelope: delivery.envelope,
        session: sessions.sessionAlice,
      );
      expect(decryptedAck.isAck, isTrue);
      expect(decryptedAck.transferId, equals('TX-ACK-001'));
      expect(decryptedAck.chunkIndex, equals(0));
      expect(decryptedAck.originId, equals(nodeC.id));

      // Tampered ACK test: A mutated envelope field causes MAC verification to fail
      final tamperedEnvelope = delivery.envelope.copyWith(
        chunkIndex: 1, // Mutated chunkIndex without valid MAC tag!
      );
      expect(
        () => nodeA.ackService.decryptAck(
          envelope: tamperedEnvelope,
          session: sessions.sessionAlice,
        ),
        throwsA(isA<AckAuthenticationException>()),
      );
    });

    test('9. Intermediate nodes not falsely advancing transfer progress', () async {
      final sessions = await establishSessionAC();
      final cryptoService = nodeA.cryptoService;

      for (var i = 0; i < 3; i++) {
        final chunk = await cryptoService.encryptChunk(
          session: sessions.sessionAlice,
          transferId: 'TX-STATELESS-001',
          originId: nodeA.id,
          destinationId: nodeC.id,
          chunkIndex: i,
          totalChunks: 3,
          offset: i * 32,
          plaintext: Uint8List(32),
          chunkLength: 32,
        );

        final wire = jsonEncode({
          'type': 'file_chunk',
          'version': 2,
          'ttl': 5,
          'hopCount': 0,
          ...chunk.toMap(),
        });
        await nodeB.router.handleIncomingPayload(wire, fromPeerId: nodeA.id);
      }

      // Assert Bob has ZERO database records for TX-STATELESS-001
      final transfersOnBob = await nodeB.db.select(nodeB.db.fileTransfersTable).get();
      final chunksOnBob = await nodeB.db.select(nodeB.db.fileChunksTable).get();

      expect(transfersOnBob, isEmpty);
      expect(chunksOnBob, isEmpty);

      // Assert Bob has written ZERO files to disk
      final bobFiles = nodeB.baseDir.listSync(recursive: true);
      expect(bobFiles, isEmpty);
    });

    test('10. Bounded queues and cleanup after forwarding failure', () async {
      // 10a. Duplicate cache boundedness: route 1050 unique packets
      for (var i = 0; i < 1050; i++) {
        final uniquePacket = jsonEncode({
          'type': 'file_chunk',
          'version': 2,
          'ttl': 5,
          'hopCount': 0,
          'originId': nodeA.id,
          'destinationId': nodeC.id,
          'transferId': 'TX-CACHE-BOUND',
          'chunkIndex': i,
          'totalChunks': 2000,
          'offset': i * 16,
          'chunkLength': 16,
          'sessionId': 'SESS-001',
          'epoch': 0,
          'sequenceNumber': i,
          'nonce': base64UrlEncode(Uint8List(12)),
          'mac': base64UrlEncode(Uint8List(16)),
          'ciphertext': base64UrlEncode(Uint8List(16)),
        });
        await nodeB.router.handleIncomingPayload(uniquePacket, fromPeerId: nodeA.id);
      }

      // Send to Bob when destination send fails
      nodeB.discovery.shouldSendSucceed = false;
      final failPacket = jsonEncode({
        'type': 'file_chunk',
        'version': 2,
        'ttl': 5,
        'hopCount': 0,
        'originId': nodeA.id,
        'destinationId': nodeC.id,
        'transferId': 'TX-FAIL-CLEANUP',
        'chunkIndex': 9999,
        'totalChunks': 10000,
        'offset': 0,
        'chunkLength': 16,
        'sessionId': 'SESS-001',
        'epoch': 0,
        'sequenceNumber': 9999,
        'nonce': base64UrlEncode(Uint8List(12)),
        'mac': base64UrlEncode(Uint8List(16)),
        'ciphertext': base64UrlEncode(Uint8List(16)),
      });

      final failResult = await nodeB.router.handleIncomingPayload(failPacket, fromPeerId: nodeA.id);
      expect(failResult, isA<DroppedPayload>());
      expect((failResult as DroppedPayload).reason, contains('destination unreachable'));

      // Test dispose cleans up controllers
      final testRouter = MeshRouter(
        discoveryService: nodeB.discovery,
        localId: 'TEMP-ROUTER',
      );
      await expectLater(testRouter.dispose(), completes);
    });

    test('11. Regression compatibility with Steps 11–15: Full multihop transfer with Sending and Receiving pipelines', () async {
      final sessions = await establishSessionAC();

      // Create a 192-byte test file (3 chunks of 64 bytes)
      final sourceBytes = Uint8List.fromList(List.generate(192, (i) => (i * 7) % 256));
      final sourceFile = File(p.join(nodeA.baseDir.path, 'multihop_test_file.bin'))..writeAsBytesSync(sourceBytes);
      final fileHash = await calculateSha256(sourceBytes);

      // Create Alice transfer record
      final aliceTransfer = await createTransferInDb(
        db: nodeA.db,
        pathService: nodeA.pathService,
        transferId: 'TX-FULL-MH-001',
        fileName: 'multihop_test_file.bin',
        fileSize: 192,
        chunkSize: 64,
        totalChunks: 3,
        fileHash: fileHash,
        direction: 'outgoing',
        status: 'acceptReceived',
        peerId: nodeC.id,
        localPath: sourceFile.path,
        stagingPath: '',
      );

      // Create Charlie transfer record
      final charlieStaging = await nodeC.pathService.getStagingPath('TX-FULL-MH-001');
      await createTransferInDb(
        db: nodeC.db,
        pathService: nodeC.pathService,
        transferId: 'TX-FULL-MH-001',
        fileName: 'multihop_test_file.bin',
        fileSize: 192,
        chunkSize: 64,
        totalChunks: 3,
        fileHash: fileHash,
        direction: 'incoming',
        status: 'acceptSent',
        peerId: nodeA.id,
        localPath: '',
        stagingPath: charlieStaging,
      );

      final aliceAckTracker = ChunkAckTracker();

      // Wire automatic network forwarding:
      // Alice -> Bob
      nodeA.discovery.onSendMessage = (destId, payload) async {
        if (destId == nodeB.id) {
          final res = await nodeB.router.handleIncomingPayload(payload, fromPeerId: nodeA.id);
          expect(res, isA<RelayedFileChunk>());
          return true;
        }
        return false;
      };

      // Bob -> Charlie (chunks) and Bob -> Alice (ACKs)
      nodeB.discovery.onSendMessage = (destId, payload) async {
        if (destId == nodeC.id) {
          final res = await nodeC.router.handleIncomingPayload(payload, fromPeerId: nodeB.id);
          expect(res, isA<LocalFileChunkDelivery>());
          final delivery = res as LocalFileChunkDelivery;

          // Charlie receives chunk into pipeline and transmits ACK back
          await nodeC.receivingPipeline.receiveChunk(
            envelope: delivery.envelope,
            session: sessions.sessionCharlie,
            ackTransportSender: RouterChunkAckTransportSender(router: nodeC.router),
            autoAssemble: false,
          );
          return true;
        }
        if (destId == nodeA.id) {
          final res = await nodeA.router.handleIncomingPayload(payload, fromPeerId: nodeB.id);
          expect(res, isA<LocalFileChunkAckDelivery>());
          final delivery = res as LocalFileChunkAckDelivery;

          // Alice receives and decrypts ACK, satisfying ackTracker
          final decryptedAck = await nodeA.ackService.decryptAck(
            envelope: delivery.envelope,
            session: sessions.sessionAlice,
          );
          aliceAckTracker.onAckReceived(decryptedAck);
          return true;
        }
        return false;
      };

      // Charlie -> Bob (ACKs)
      nodeC.discovery.onSendMessage = (destId, payload) async {
        if (destId == nodeB.id) {
          final res = await nodeB.router.handleIncomingPayload(payload, fromPeerId: nodeC.id);
          expect(res, isA<RelayedFileAck>());
          return true;
        }
        return false;
      };

      // Alice sends transfer using RouterChunkTransportSender
      final sendResult = await nodeA.sendingPipeline.sendTransfer(
        transfer: aliceTransfer,
        session: sessions.sessionAlice,
        transportSender: RouterChunkTransportSender(router: nodeA.router),
        ackTracker: aliceAckTracker,
        policy: const ChunkSendingPolicy(
          waitForAcks: true,
          ackTimeout: Duration(seconds: 3),
          maxRetries: 2,
        ),
      );

      expect(sendResult.isSuccess, isTrue);
      expect(sendResult.chunksSent, 3);
      expect(sendResult.bytesSent, 192);

      // Verify file assembly on Charlie
      final assemblyResult = await nodeC.assemblyService.assembleTransfer(
        transferId: 'TX-FULL-MH-001',
      );
      expect(assemblyResult.isSuccess, isTrue);
      expect(assemblyResult.fileHash, equals(fileHash));

      final assembledFile = File(assemblyResult.destinationPath);
      expect(assembledFile.existsSync(), isTrue);
      expect(assembledFile.readAsBytesSync(), equals(sourceBytes));

      // Verify intermediate node Bob remains completely clean
      final bobTransfers = await nodeB.db.select(nodeB.db.fileTransfersTable).get();
      expect(bobTransfers, isEmpty);
      expect(nodeB.baseDir.listSync(), isEmpty);
    });
  });
}
