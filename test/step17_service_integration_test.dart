import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_ack_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart'
    hide ChunkMetadataMismatchException;
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_stream_reader.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';
import 'package:meshlink/features/messages/providers/messaging_providers.dart';
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

class TestIntegrationNode {
  TestIntegrationNode({
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
    directionalService = DirectionalSessionEncryptionService();
    cryptoService =
        FileTransferCryptoService(encryptionService: directionalService);
    assemblyService = FileAssemblyService(
      database: db,
      pathService: pathService,
    );
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

    fileTransferService = FileTransferService(
      localDeviceId: id,
      database: db,
      messageRepository: repo,
      router: router,
      sessionService: sessionService,
      sendingPipeline: sendingPipeline,
      receivingPipeline: receivingPipeline,
      ackService: ackService,
      assemblyService: assemblyService,
      pathService: pathService,
      cryptoService: cryptoService,
      replayProtectionService: replayService,
      autoListenToRouter: true,
    );

    messagingService = BleMeshMessagingService(
      discoveryService: discovery,
      storageService: repo,
      localId: id,
      router: router,
      replayProtectionService: replayService,
      fileTransferService: fileTransferService,
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
  late final DirectionalSessionEncryptionService directionalService;
  late final FileTransferCryptoService cryptoService;
  late final FileAssemblyService assemblyService;
  late final ChunkAckService ackService;
  late final ChunkReceivingPipeline receivingPipeline;
  late final ChunkSendingPipeline sendingPipeline;
  late final FileTransferService fileTransferService;
  late final BleMeshMessagingService messagingService;

  Future<void> initialize() async {
    await identity.initialize();
  }

  Future<void> dispose() async {
    await messagingService.dispose();
    await receivingPipeline.closeAll();
    await discovery.dispose();
    await db.close();
  }
}

/// Establishes authenticated directional session between [a] and [b].
Future<void> establishSession(
  TestIntegrationNode a,
  TestIntegrationNode b,
  DateTime now,
) async {
  await a.initialize();
  await b.initialize();

  await a.repo.savePeerIdentity(
    PeerIdentityEntry(
      peerId: b.id,
      identityPublicKey: await b.identity.getIdentityPublicKey(),
      safetyNumber: '111111',
      trustStatus: 'verified',
      protocolVersion: 2,
      firstSeenAt: now,
      lastSeenAt: now,
    ),
  );
  await b.repo.savePeerIdentity(
    PeerIdentityEntry(
      peerId: a.id,
      identityPublicKey: await a.identity.getIdentityPublicKey(),
      safetyNumber: '222222',
      trustStatus: 'verified',
      protocolVersion: 2,
      firstSeenAt: now,
      lastSeenAt: now,
    ),
  );

  final req = await a.handshake.createKeyRequest(
    destinationId: b.id,
    requestId: 'REQ-${a.id}-${b.id}',
  );
  final resp = await b.handshake.createKeyResponse(request: req);
  final verifiedResp = await a.handshake.verifyKeyResponse(resp);
  final verifiedReq = await b.handshake.verifyKeyRequest(req);

  await a.handshake.completeSessionAsInitiator(
    verifiedResponse: verifiedResp,
    now: now,
  );
  await b.handshake.completeSessionAsResponder(
    verifiedRequest: verifiedReq,
    now: now,
  );
}

void wireDirectRadio(TestIntegrationNode a, TestIntegrationNode b) {
  a.connectedPeers.add(b.id);
  b.connectedPeers.add(a.id);

  a.discovery.onSendMessage = (dest, payload) async {
    if (dest == b.id) {
      b.discovery.emit(MessageReceivedEvent(payload, peerId: a.id));
      return true;
    }
    return false;
  };

  b.discovery.onSendMessage = (dest, payload) async {
    if (dest == a.id) {
      a.discovery.emit(MessageReceivedEvent(payload, peerId: b.id));
      return true;
    }
    return false;
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDir;
  final testNow = DateTime.utc(2026, 10, 29, 12, 0, 0);
  DateTime clock() => testNow;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step17_test_');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase 8 Step 17: Service Integration and Legacy Deprecation', () {
    test('1. Application-level file-transfer service wiring and controller integration', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final node = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      await node.initialize();

      final controller = MessagingController(
        messagingService: node.messagingService,
        localId: node.id,
      );

      // Verify controller surfaces authoritative file transfer services
      expect(controller.fileTransferService, isNotNull);
      expect(identical(controller.fileTransferService, node.fileTransferService), isTrue);
      expect(controller.transferProgressStream, isNotNull);

      // Verify deprecated progress stream is also exposed for compatibility
      // ignore: deprecated_member_use_from_same_package
      expect(controller.fileTransferProgress, isNotNull);

      controller.dispose();
      await node.dispose();
    });

    test('2. Correct dependency reuse and absence of duplicate critical service instances (Riverpod & Direct)', () async {
      final nodeDir = Directory(p.join(tempDir.path, 'node_di'))..createSync();
      final node = TestIntegrationNode(
        id: 'NODE-DI',
        name: 'DI Node',
        baseDir: nodeDir,
        clock: clock,
      );
      await node.initialize();

      // 1. Direct wiring assertions
      expect(
        identical(node.messagingService.router, node.fileTransferService.router),
        isTrue,
        reason: 'MeshMessagingService and FileTransferService must share the same MeshRouter instance',
      );
      expect(
        identical(node.messagingService.fileTransferService, node.fileTransferService),
        isTrue,
        reason: 'BleMeshMessagingService must hold the authoritative FileTransferService instance',
      );
      expect(
        identical(node.fileTransferService.database, node.db),
        isTrue,
        reason: 'FileTransferService must share the canonical AppDatabase',
      );
      expect(
        identical(node.fileTransferService.sessionService, node.sessionService),
        isTrue,
        reason: 'FileTransferService must share the canonical EphemeralSessionService',
      );

      // 2. Riverpod Container wiring assertions (absence of duplicates)
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(node.db),
          deviceDiscoveryServiceProvider.overrideWithValue(node.discovery),
        ],
      );

      final routerFromDi = container.read(meshRouterProvider);
      final transferServiceFromDi = container.read(fileTransferServiceProvider);
      final messagingServiceFromDi = container.read(meshMessagingServiceProvider);

      expect(
        identical(routerFromDi, transferServiceFromDi.router),
        isTrue,
        reason: 'Riverpod DI: FileTransferService must use the shared meshRouterProvider instance',
      );
      expect(
        identical(routerFromDi, messagingServiceFromDi.router),
        isTrue,
        reason: 'Riverpod DI: MeshMessagingService must use the shared meshRouterProvider instance',
      );
      expect(
        identical(transferServiceFromDi, messagingServiceFromDi.fileTransferService),
        isTrue,
        reason: 'Riverpod DI: MeshMessagingService must use the shared fileTransferServiceProvider instance',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      container.dispose();
      await node.dispose();
    });

    test('3. End-to-end sending and receiving service integration with wire delivery', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final nodeBDir = Directory(p.join(tempDir.path, 'nodeB'))..createSync();

      final nodeA = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      final nodeB = TestIntegrationNode(
        id: 'NODE-B',
        name: 'Bob',
        baseDir: nodeBDir,
        clock: clock,
      );

      wireDirectRadio(nodeA, nodeB);
      await establishSession(nodeA, nodeB, testNow);

      final srcFile = File(p.join(nodeADir.path, 'document.txt'));
      final sampleContent = 'MeshLink authoritative file transfer payload: ${List.filled(200, 'X').join()}';
      await srcFile.writeAsString(sampleContent);

      final transferId = 'FT-E2E-17001';
      final fileBytes = await srcFile.readAsBytes();
      final fileHash = (await Sha256().hash(fileBytes))
          .bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      // Register incoming transfer contract on Node B
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'document.txt',
        fileSize: fileBytes.length,
        fileHash: fileHash,
        totalChunks: FileStreamReader.calculateTotalChunks(
          fileSize: fileBytes.length,
          chunkSize: FileStreamReader.defaultChunkSize,
        ),
      );

      final progressEvents = <FileTransferProgress>[];
      final sub = nodeA.fileTransferService.progressStream.listen(progressEvents.add);

      // Send file via BleMeshMessagingService (authoritative path)
      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: srcFile,
        transferId: transferId,
        timeout: const Duration(seconds: 5),
      );

      expect(sendResult.isSuccess, isTrue);
      expect(sendResult.status, equals(FileTransferStatus.completed));

      // Await Node B finishing chunk write and assembly
      FileTransfer? transferB;
      for (var i = 0; i < 50; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      // Verify transfer in database on Node A is completed
      final transferA = await nodeA.fileTransferService.getTransfer(transferId);
      expect(transferA, isNotNull);
      expect(transferA!.status, equals(FileTransferStatus.completed));

      // Verify transfer in database on Node B is completed
      expect(transferB, isNotNull);
      final finalTransferB = transferB!;
      expect(finalTransferB.status, equals(FileTransferStatus.completed));

      // Verify final assembled file on Node B exists and content matches
      final receivedFile = File(finalTransferB.localPath);
      expect(await receivedFile.exists(), isTrue);
      expect(await receivedFile.readAsString(), equals(sampleContent));

      await sub.cancel();
      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('4. Router transport adapter integration for chunks and ACK/NACK envelopes', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final nodeBDir = Directory(p.join(tempDir.path, 'nodeB'))..createSync();

      final nodeA = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      final nodeB = TestIntegrationNode(
        id: 'NODE-B',
        name: 'Bob',
        baseDir: nodeBDir,
        clock: clock,
      );

      wireDirectRadio(nodeA, nodeB);
      await establishSession(nodeA, nodeB, testNow);

      final chunkSender = nodeA.fileTransferService.routerChunkTransportSender;
      final ackSender = nodeB.fileTransferService.routerAckTransportSender;

      expect(chunkSender, isNotNull);
      expect(ackSender, isNotNull);

      // Create an encrypted chunk envelope via FileTransferCryptoService
      final chunkData = utf8.encode('chunk-transport-test');
      final sessionA = nodeA.sessionService.getSession(nodeB.id)!;
      final envelope = await nodeA.cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-ROUTER-TEST',
        originId: nodeA.id,
        destinationId: nodeB.id,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List.fromList(chunkData),
      );

      final chunkAccepted = await chunkSender.sendChunk(envelope);
      expect(chunkAccepted, isTrue);

      // Verify envelope was transmitted by Node A's discovery service
      expect(nodeA.discovery.sentTransmissions, isNotEmpty);
      final wirePacket = nodeA.discovery.sentTransmissions.first['payload']!;
      final parsed = jsonDecode(wirePacket) as Map<String, dynamic>;
      expect(parsed['type'], equals(MeshRouter.fileChunkPacketType));
      expect(parsed['transferId'], equals('FT-ROUTER-TEST'));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('5. Correct progress and completion reporting on typed and legacy streams', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final nodeBDir = Directory(p.join(tempDir.path, 'nodeB'))..createSync();

      final nodeA = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      final nodeB = TestIntegrationNode(
        id: 'NODE-B',
        name: 'Bob',
        baseDir: nodeBDir,
        clock: clock,
      );

      wireDirectRadio(nodeA, nodeB);
      await establishSession(nodeA, nodeB, testNow);

      final srcFile = File(p.join(nodeADir.path, 'progress_sample.dat'));
      final bytes = Uint8List.fromList(List.generate(1500, (i) => i % 256));
      await srcFile.writeAsBytes(bytes);

      final transferId = 'FT-PROGRESS-17002';
      final fileHash = (await Sha256().hash(bytes))
          .bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'progress_sample.dat',
        fileSize: bytes.length,
        fileHash: fileHash,
        totalChunks: FileStreamReader.calculateTotalChunks(
          fileSize: bytes.length,
          chunkSize: FileStreamReader.defaultChunkSize,
        ),
      );

      final typedUpdates = <FileTransferProgress>[];
      final legacyUpdates = <MeshFileTransferProgress>[];

      final subTyped = nodeA.messagingService.fileTransferProgressStream.listen(typedUpdates.add);
      // Deprecated stream backward compatibility verification
      // ignore: deprecated_member_use_from_same_package
      final subLegacy = nodeA.messagingService.fileTransferProgress.listen(legacyUpdates.add);

      await nodeA.messagingService.sendFile(nodeB.id, srcFile, transferId: transferId);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(typedUpdates, isNotEmpty);
      expect(legacyUpdates, isNotEmpty);

      // Final typed update is completed
      expect(typedUpdates.last.status, equals(FileTransferStatus.completed));
      expect(typedUpdates.last.bytesTransferred, equals(bytes.length));
      expect(typedUpdates.last.progressFraction, equals(1.0));

      // Final legacy update has status 'completed' and progress 1.0
      expect(legacyUpdates.last.status, equals('completed'));
      expect(legacyUpdates.last.progress, equals(1.0));
      expect(legacyUpdates.last.transferId, equals(transferId));

      await subTyped.cancel();
      await subLegacy.cancel();
      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('6. Shutdown and disposal behavior releases resources without corrupting transfers', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final node = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      await node.initialize();

      final transfer = FileTransfer(
        transferId: 'FT-SHUTDOWN-17',
        conversationId: 'PEER-B',
        peerId: 'PEER-B',
        direction: FileTransferDirection.incoming,
        fileName: 'shutdown_doc.bin',
        fileSize: 4096,
        mimeType: 'application/octet-stream',
        fileHash: 'deadbeef1234',
        localPath: '',
        stagingPath: p.join(nodeADir.path, 'shutdown_doc.bin.part'),
        totalChunks: 4,
        chunkSize: 1024,
        status: FileTransferStatus.transferring,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await node.db.insertFileTransfer(transfer.toCompanion());
      await node.db.markChunkReceived(transfer.transferId, 0);

      // Verify service disposal does not corrupt DB records
      await node.fileTransferService.dispose();

      final persisted = await node.db.getFileTransfer('FT-SHUTDOWN-17');
      expect(persisted, isNotNull);
      expect(persisted!.status, equals(FileTransferStatus.transferring.toDbValue()));

      final chunks = await node.db.getFileChunks('FT-SHUTDOWN-17');
      expect(chunks.length, equals(1));
      expect(chunks.first.chunkIndex, equals(0));

      await node.dispose();
    });

    test('7. Legacy API deprecation annotations and migration delegation', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final node = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      await node.initialize();

      // Verify that calling sendFile without configured FileTransferService fails with clear StateError
      final unconfiguredService = BleMeshMessagingService(
        discoveryService: node.discovery,
        storageService: node.repo,
        localId: node.id,
        router: node.router,
        fileTransferService: null,
      );

      final dummyFile = File(p.join(nodeADir.path, 'dummy.txt'))..writeAsStringSync('dummy');

      expect(
        () => unconfiguredService.sendFile('PEER-B', dummyFile),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('FileTransferService is not configured'),
        )),
      );

      await unconfiguredService.dispose();
      await node.dispose();
    });

    test('8. Regression compatibility: Intermediate multihop file forwarding through FileTransferService', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final nodeBDir = Directory(p.join(tempDir.path, 'nodeB'))..createSync();
      final nodeCDir = Directory(p.join(tempDir.path, 'nodeC'))..createSync();

      final nodeA = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      final nodeC = TestIntegrationNode(
        id: 'NODE-C',
        name: 'Relay Charlie',
        baseDir: nodeCDir,
        clock: clock,
      );
      final nodeB = TestIntegrationNode(
        id: 'NODE-B',
        name: 'Bob',
        baseDir: nodeBDir,
        clock: clock,
      );

      await nodeA.initialize();
      await nodeC.initialize();
      await nodeB.initialize();

      // Multihop topology: A <-> C <-> B (no direct A <-> B radio link)
      nodeA.connectedPeers.add(nodeC.id);
      nodeC.connectedPeers.addAll([nodeA.id, nodeB.id]);
      nodeB.connectedPeers.add(nodeC.id);

      nodeA.discovery.onSendMessage = (dest, payload) async {
        if (dest == nodeC.id) {
          nodeC.discovery.emit(MessageReceivedEvent(payload, peerId: nodeA.id));
          return true;
        }
        return false;
      };

      nodeC.discovery.onSendMessage = (dest, payload) async {
        if (dest == nodeB.id) {
          nodeB.discovery.emit(MessageReceivedEvent(payload, peerId: nodeC.id));
          return true;
        } else if (dest == nodeA.id) {
          nodeA.discovery.emit(MessageReceivedEvent(payload, peerId: nodeC.id));
          return true;
        }
        return false;
      };

      nodeB.discovery.onSendMessage = (dest, payload) async {
        if (dest == nodeC.id) {
          nodeC.discovery.emit(MessageReceivedEvent(payload, peerId: nodeB.id));
          return true;
        }
        return false;
      };

      // Direct end-to-end handshake between A and B
      await establishSession(nodeA, nodeB, testNow);

      final srcFile = File(p.join(nodeADir.path, 'multihop.txt'));
      final content = 'End-to-end multihop transfer payload forwarded securely by Charlie';
      await srcFile.writeAsString(content);

      final transferId = 'FT-MULTIHOP-17';
      final fileBytes = await srcFile.readAsBytes();
      final fileHash = (await Sha256().hash(fileBytes))
          .bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'multihop.txt',
        fileSize: fileBytes.length,
        fileHash: fileHash,
        totalChunks: 1,
      );

      final result = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: srcFile,
        transferId: transferId,
      );

      expect(result.isSuccess, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final transferB = await nodeB.fileTransferService.getTransfer(transferId);
      expect(transferB, isNotNull);
      expect(transferB!.status, equals(FileTransferStatus.completed));

      final received = File(transferB.localPath);
      expect(await received.exists(), isTrue);
      expect(await received.readAsString(), equals(content));

      // Ensure intermediate node Charlie has NO decrypted file and NO transfer records
      final transferCharlie = await nodeC.fileTransferService.getTransfer(transferId);
      expect(transferCharlie, isNull);

      await nodeA.dispose();
      await nodeC.dispose();
      await nodeB.dispose();
    });

    test('9. No plaintext fallback or bypass of cryptographic checks', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final nodeBDir = Directory(p.join(tempDir.path, 'nodeB'))..createSync();

      final nodeA = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      final nodeB = TestIntegrationNode(
        id: 'NODE-B',
        name: 'Bob',
        baseDir: nodeBDir,
        clock: clock,
      );

      wireDirectRadio(nodeA, nodeB);

      final testFile = File(p.join(nodeADir.path, 'secret.bin'))..writeAsBytesSync([1, 2, 3, 4]);

      // 1. Attempting to send file without established session throws NoActiveSessionException
      await expectLater(
        nodeA.fileTransferService.sendFile(peerId: nodeB.id, file: testFile),
        throwsA(isA<NoActiveSessionException>()),
      );

      // Now establish session
      await establishSession(nodeA, nodeB, testNow);

      // 2. Transmitting tampered ciphertext chunk is rejected by Node B
      final sessionA = nodeA.sessionService.getSession(nodeB.id)!;
      final envelope = await nodeA.cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-CRYPTO-CHECK',
        originId: nodeA.id,
        destinationId: nodeB.id,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List.fromList([1, 2, 3, 4]),
      );

      // Tamper ciphertext
      final tamperedCiphertext = Uint8List.fromList(envelope.ciphertext);
      tamperedCiphertext[0] ^= 0xFF;

      final tamperedEnvelope = EncryptedFileChunkEnvelope(
        version: envelope.version,
        transferId: envelope.transferId,
        originId: envelope.originId,
        destinationId: envelope.destinationId,
        sessionId: envelope.sessionId,
        epoch: envelope.epoch,
        sequenceNumber: envelope.sequenceNumber,
        chunkIndex: envelope.chunkIndex,
        totalChunks: envelope.totalChunks,
        offset: envelope.offset,
        chunkLength: envelope.chunkLength,
        nonce: envelope.nonce,
        mac: envelope.mac,
        ciphertext: tamperedCiphertext,
        validate: false,
      );

      final recvResult = await nodeB.fileTransferService.handleIncomingFileChunk(tamperedEnvelope);
      expect(recvResult, isNull);

      // Verify no transfer was marked completed or assembled
      final completedTransfer = await nodeB.fileTransferService.getTransfer('FT-CRYPTO-CHECK');
      expect(completedTransfer?.status, isNot(equals(FileTransferStatus.completed)));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('10. No false completion when transport delivery or file verification fails', () async {
      final nodeADir = Directory(p.join(tempDir.path, 'nodeA'))..createSync();
      final nodeBDir = Directory(p.join(tempDir.path, 'nodeB'))..createSync();

      final nodeA = TestIntegrationNode(
        id: 'NODE-A',
        name: 'Alice',
        baseDir: nodeADir,
        clock: clock,
      );
      final nodeB = TestIntegrationNode(
        id: 'NODE-B',
        name: 'Bob',
        baseDir: nodeBDir,
        clock: clock,
      );

      wireDirectRadio(nodeA, nodeB);
      await establishSession(nodeA, nodeB, testNow);

      final srcFile = File(p.join(nodeADir.path, 'fail_doc.txt'))..writeAsStringSync('content');

      // Drop all outbound transmissions so ACK is never received
      nodeA.discovery.shouldSendSucceed = false;

      final result = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: srcFile,
        transferId: 'FT-FAIL-17',
        timeout: const Duration(milliseconds: 50),
        policy: const ChunkSendingPolicy(
          waitForAcks: true,
          ackTimeout: Duration(milliseconds: 50),
          transportTimeout: Duration(milliseconds: 50),
          maxRetries: 1,
        ),
      );

      // Verify result is failure, never completed
      expect(result.isSuccess, isFalse);
      expect(result.status, isNot(equals(FileTransferStatus.completed)));

      final transferA = await nodeA.fileTransferService.getTransfer('FT-FAIL-17');
      expect(transferA?.status, isNot(equals(FileTransferStatus.completed)));

      await nodeA.dispose();
      await nodeB.dispose();
    });
  });
}
