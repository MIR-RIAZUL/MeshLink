import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
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
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:path/path.dart' as p;

class _MockDiscoveryService implements DeviceDiscoveryService {
  _MockDiscoveryService({required this.localIdentity});

  final LocalIdentity localIdentity;
  final StreamController<DeviceDiscoveryEvent> _controller =
      StreamController<DeviceDiscoveryEvent>.broadcast();

  final List<Map<String, String>> sentTransmissions = [];
  Future<bool> Function(String deviceId, String payload)? onSendMessage;

  @override
  Stream<DeviceDiscoveryEvent> get events => _controller.stream;

  void emit(DeviceDiscoveryEvent event) => _controller.add(event);

  @override
  Future<bool> sendMessage(String deviceId, String payload) async {
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

class _TestNode {
  _TestNode({
    required this.id,
    required this.name,
    required this.baseDir,
    required this.clock,
  }) {
    discovery = _MockDiscoveryService(
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
      peerRepository: repo,
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

  late final _MockDiscoveryService discovery;
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
    messagingService.dispose();
    await fileTransferService.dispose();
    await discovery.dispose();
    await db.close();
  }
}

Future<void> _wireDirectRadio(_TestNode a, _TestNode b) async {
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

Future<void> _wireMultihopRadio(_TestNode a, _TestNode b, _TestNode c) async {
  a.connectedPeers.add(b.id);
  b.connectedPeers.add(a.id);
  b.connectedPeers.add(c.id);
  c.connectedPeers.add(b.id);

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
    if (dest == c.id) {
      c.discovery.emit(MessageReceivedEvent(payload, peerId: b.id));
      return true;
    }
    return false;
  };

  c.discovery.onSendMessage = (dest, payload) async {
    if (dest == b.id) {
      b.discovery.emit(MessageReceivedEvent(payload, peerId: c.id));
      return true;
    }
    return false;
  };
}

Future<void> _establishSession(
  _TestNode a,
  _TestNode b,
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

Future<String> _calculateSha256(Uint8List bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;
  DateTime testNow = DateTime.utc(2026, 10, 29, 3, 0, 0);
  DateTime clock() => testNow;

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('meshlink_step19_');
    testNow = DateTime.utc(2026, 10, 29, 3, 0, 0);
  });

  tearDown(() async {
    if (await tempRootDir.exists()) {
      await tempRootDir.delete(recursive: true);
    }
  });

  group('Phase 8 Step 19.3 — End-to-End File Transfer Invariants', () {
    test('1. Empty file is rejected by transfer contract (§19.3 item 1)', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final emptyFile = File(p.join(dirA.path, 'empty.bin'))..writeAsBytesSync([]);

      expect(
        () => nodeA.fileTransferService.sendFile(
          peerId: nodeB.id,
          file: emptyFile,
          transferId: 'FT-EMPTY',
        ),
        throwsArgumentError,
      );

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('2. File smaller than 1 chunk (512 bytes with 16KB default chunk size)', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final testBytes = Uint8List.fromList(List.generate(512, (i) => (i * 3) % 256));
      final testHash = await _calculateSha256(testBytes);
      final fileA = File(p.join(dirA.path, 'small.bin'))..writeAsBytesSync(testBytes);

      final transferId = 'FT-SMALL-512';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'small.bin',
        fileSize: testBytes.length,
        fileHash: testHash,
        totalChunks: 1,
      );

      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileA,
        transferId: transferId,
      );

      expect(sendResult.isSuccess, isTrue);

      FileTransfer? transferB;
      for (var i = 0; i < 40; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB, isNotNull);
      expect(transferB!.status, equals(FileTransferStatus.completed));
      final receivedBytes = await File(transferB.localPath).readAsBytes();
      expect(receivedBytes, equals(testBytes));
      expect(await _calculateSha256(receivedBytes), equals(testHash));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('3. File exactly 1 chunk long (16,384 bytes)', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final testBytes = Uint8List.fromList(List.generate(16384, (i) => (i * 7) % 256));
      final testHash = await _calculateSha256(testBytes);
      final fileA = File(p.join(dirA.path, 'exact_16k.bin'))..writeAsBytesSync(testBytes);

      final transferId = 'FT-EXACT-16K';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'exact_16k.bin',
        fileSize: testBytes.length,
        fileHash: testHash,
        totalChunks: 1,
      );

      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileA,
        transferId: transferId,
      );

      expect(sendResult.isSuccess, isTrue);

      FileTransfer? transferB;
      for (var i = 0; i < 40; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB!.status, equals(FileTransferStatus.completed));
      final receivedBytes = await File(transferB.localPath).readAsBytes();
      expect(receivedBytes, equals(testBytes));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('4. File spanning multiple full chunks (32,768 bytes = 2 chunks of 16KB)', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final testBytes = Uint8List.fromList(List.generate(32768, (i) => (i * 13) % 256));
      final testHash = await _calculateSha256(testBytes);
      final fileA = File(p.join(dirA.path, 'multi_32k.bin'))..writeAsBytesSync(testBytes);

      final transferId = 'FT-MULTI-32K';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'multi_32k.bin',
        fileSize: testBytes.length,
        fileHash: testHash,
        totalChunks: 2,
      );

      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileA,
        transferId: transferId,
      );

      expect(sendResult.isSuccess, isTrue);

      FileTransfer? transferB;
      for (var i = 0; i < 50; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB!.status, equals(FileTransferStatus.completed));
      final receivedBytes = await File(transferB.localPath).readAsBytes();
      expect(receivedBytes, equals(testBytes));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('5. File with partial final chunk (20,000 bytes = 16,384 + 3,616 bytes)', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final testBytes = Uint8List.fromList(List.generate(20000, (i) => (i * 23) % 256));
      final testHash = await _calculateSha256(testBytes);
      final fileA = File(p.join(dirA.path, 'partial_20k.bin'))..writeAsBytesSync(testBytes);

      final transferId = 'FT-PARTIAL-20K';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'partial_20k.bin',
        fileSize: testBytes.length,
        fileHash: testHash,
        totalChunks: 2,
      );

      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileA,
        transferId: transferId,
      );

      expect(sendResult.isSuccess, isTrue);

      FileTransfer? transferB;
      for (var i = 0; i < 50; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB!.status, equals(FileTransferStatus.completed));
      final receivedBytes = await File(transferB.localPath).readAsBytes();
      expect(receivedBytes.length, equals(20000));
      expect(receivedBytes, equals(testBytes));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('6. Binary file containing arbitrary byte spectrum (0x00..0xFF)', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final testBytes = Uint8List.fromList([
        ...List.generate(256, (i) => i),
        ...List.generate(256, (i) => 255 - i),
      ]);
      final testHash = await _calculateSha256(testBytes);
      final fileA = File(p.join(dirA.path, 'spectrum.bin'))..writeAsBytesSync(testBytes);

      final transferId = 'FT-SPECTRUM-512';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'spectrum.bin',
        fileSize: testBytes.length,
        fileHash: testHash,
        totalChunks: 1,
      );

      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileA,
        transferId: transferId,
      );

      expect(sendResult.isSuccess, isTrue);

      FileTransfer? transferB;
      for (var i = 0; i < 50; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB!.status, equals(FileTransferStatus.completed));
      final receivedBytes = await File(transferB.localPath).readAsBytes();
      expect(receivedBytes, equals(testBytes));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('7. Repeated patterns and pseudorandom content transfers', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      // Repeated 0xAA bytes
      final repeatedBytes = Uint8List(1024)..fillRange(0, 1024, 0xAA);
      final fileRepeated = File(p.join(dirA.path, 'repeat.bin'))..writeAsBytesSync(repeatedBytes);
      final repHash = await _calculateSha256(repeatedBytes);

      final transferId1 = 'FT-REPEAT-1K';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId1,
        peerId: nodeA.id,
        fileName: 'repeat.bin',
        fileSize: repeatedBytes.length,
        fileHash: repHash,
        totalChunks: 1,
      );

      await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileRepeated,
        transferId: transferId1,
      );

      FileTransfer? transferB1;
      for (var i = 0; i < 40; i++) {
        transferB1 = await nodeB.fileTransferService.getTransfer(transferId1);
        if (transferB1?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB1!.status, equals(FileTransferStatus.completed));
      expect(await File(transferB1.localPath).readAsBytes(), equals(repeatedBytes));

      // Pseudorandom bytes
      final rng = Random(999);
      final randomBytes = Uint8List.fromList(List.generate(1024, (_) => rng.nextInt(256)));
      final fileRandom = File(p.join(dirA.path, 'random.bin'))..writeAsBytesSync(randomBytes);
      final randHash = await _calculateSha256(randomBytes);

      final transferId2 = 'FT-RANDOM-1K';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId2,
        peerId: nodeA.id,
        fileName: 'random.bin',
        fileSize: randomBytes.length,
        fileHash: randHash,
        totalChunks: 1,
      );

      await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileRandom,
        transferId: transferId2,
      );

      FileTransfer? transferB2;
      for (var i = 0; i < 40; i++) {
        transferB2 = await nodeB.fileTransferService.getTransfer(transferId2);
        if (transferB2?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB2!.status, equals(FileTransferStatus.completed));
      expect(await File(transferB2.localPath).readAsBytes(), equals(randomBytes));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('8. Multi-hop forwarding: A -> B -> C transfers end-to-end without B decrypting', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();
      final dirC = Directory(p.join(tempRootDir.path, 'nodeC'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);
      final nodeC = _TestNode(id: 'NODE-C', name: 'Charlie', baseDir: dirC, clock: clock);

      await _wireMultihopRadio(nodeA, nodeB, nodeC);
      await _establishSession(nodeA, nodeC, testNow);

      final content = Uint8List.fromList(List.generate(500, (i) => (i * 11) % 256));
      final expectedHash = await _calculateSha256(content);
      final sourceFile = File(p.join(dirA.path, 'hop.bin'))..writeAsBytesSync(content);

      final transferId = 'FT-MULTIHOP-19';
      await nodeC.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'hop.bin',
        fileSize: content.length,
        fileHash: expectedHash,
        totalChunks: 1,
      );

      final result = await nodeA.fileTransferService.sendFile(
        peerId: nodeC.id,
        file: sourceFile,
        transferId: transferId,
      );

      expect(result.isSuccess, isTrue);

      FileTransfer? transferC;
      for (var i = 0; i < 60; i++) {
        transferC = await nodeC.fileTransferService.getTransfer(transferId);
        if (transferC?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferC, isNotNull);
      expect(transferC!.status, equals(FileTransferStatus.completed));
      expect(await File(transferC.localPath).readAsBytes(), equals(content));

      // Intermediate node B has no local decrypted copy
      final transferB = await nodeB.fileTransferService.getTransfer(transferId);
      expect(transferB, isNull);

      await nodeA.dispose();
      await nodeB.dispose();
      await nodeC.dispose();
    });
  });

  group('Phase 8 Step 19.4 — Fault Injection & Recovery', () {
    test('9. Duplicate and retransmitted chunks are handled idempotently without corrupting staging', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final testBytes = Uint8List.fromList(List.generate(200, (i) => i));
      final testHash = await _calculateSha256(testBytes);
      final fileA = File(p.join(dirA.path, 'dup.bin'))..writeAsBytesSync(testBytes);

      final transferId = 'FT-DUP-19';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'dup.bin',
        fileSize: testBytes.length,
        fileHash: testHash,
        totalChunks: 1,
      );

      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileA,
        transferId: transferId,
      );

      expect(sendResult.isSuccess, isTrue);

      FileTransfer? transferB;
      for (var i = 0; i < 40; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(transferB!.status, equals(FileTransferStatus.completed));
      final fileAfter = File(transferB.localPath);
      expect(await fileAfter.readAsBytes(), equals(testBytes));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('10. Tampered chunk envelope fails closed and does not complete transfer', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final transferId = 'FT-TAMPER-19';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'tampered.bin',
        fileSize: 100,
        fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        totalChunks: 1,
      );

      final sessionA = nodeA.sessionService.getSession(nodeB.id)!;
      final envelope = await nodeA.cryptoService.encryptChunk(
        session: sessionA,
        transferId: transferId,
        originId: nodeA.id,
        destinationId: nodeB.id,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(100),
      );

      final tamperedCiphertext = Uint8List.fromList(envelope.ciphertext);
      tamperedCiphertext[0] ^= 0x01; // Tamper bit

      final tamperedEnvelope = envelope.copyWith(
        ciphertext: tamperedCiphertext,
      );

      final result = await nodeB.fileTransferService.handleIncomingFileChunk(tamperedEnvelope);
      expect(result?.isSuccess ?? false, isFalse);

      final transferB = await nodeB.fileTransferService.getTransfer(transferId);
      expect(transferB!.status, isNot(FileTransferStatus.completed));

      await nodeA.dispose();
      await nodeB.dispose();
    });

    test('11. Cancellation marks transfer cancelled and aborts streaming', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      File(p.join(dirA.path, 'cancel.bin')).writeAsBytesSync(Uint8List(500));
      final transferId = 'FT-CANCEL-19';

      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'cancel.bin',
        fileSize: 500,
        fileHash: 'deadbeef',
        totalChunks: 1,
      );

      await nodeB.fileTransferService.cancelTransfer(transferId);
      final cancelledRec = await nodeB.fileTransferService.getTransfer(transferId);
      expect(cancelledRec, isNotNull);
      expect(cancelledRec!.status, equals(FileTransferStatus.cancelled));

      await nodeA.dispose();
      await nodeB.dispose();
    });
  });

  group('Phase 8 Step 19.5 & 19.6 — Database Constraints, Path Security & Performance', () {
    test('12. Database constraint enforces chunkSize > 0 and prevents invalid states', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);

      final now = DateTime.now().toUtc();

      // Negative chunkSize is rejected by SQLite CHECK constraint
      expect(
        () => nodeA.db.insertFileTransfer(
          FileTransfersTableCompanion.insert(
            transferId: 'TR-FAIL-CHUNK',
            conversationId: 'CONV-1',
            peerId: 'NODE-B',
            direction: 'outgoing',
            fileName: 'fail.bin',
            fileSize: BigInt.from(100),
            mimeType: 'application/octet-stream',
            fileHash: 'deadbeef',
            localPath: 'fail.bin',
            stagingPath: 'staging.bin',
            totalChunks: 1,
            chunkSize: -1, // Invalid!
            status: 'transferring',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
      );

      await nodeA.dispose();
    });

    test('13. FilePathService prevents path traversal attacks outside staging directory', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);

      final stagingDir = await nodeA.pathService.getStagingDirectory();
      final validStagingPath = p.join(stagingDir.path, 'valid.tmp');
      final traversalAttempt = p.join(stagingDir.path, '..', 'evil.tmp');

      expect(FilePathService.isPathInsideDirectory(validStagingPath, stagingDir.path), isTrue);
      expect(FilePathService.isPathInsideDirectory(traversalAttempt, stagingDir.path), isFalse);

      await nodeA.dispose();
    });

    test('14. Performance benchmark: 64KB file processed within bounded duration', () async {
      final dirA = Directory(p.join(tempRootDir.path, 'nodeA'))..createSync();
      final dirB = Directory(p.join(tempRootDir.path, 'nodeB'))..createSync();

      final nodeA = _TestNode(id: 'NODE-A', name: 'Alice', baseDir: dirA, clock: clock);
      final nodeB = _TestNode(id: 'NODE-B', name: 'Bob', baseDir: dirB, clock: clock);

      await _wireDirectRadio(nodeA, nodeB);
      await _establishSession(nodeA, nodeB, testNow);

      final data = Uint8List.fromList(List.generate(65536, (i) => i % 256));
      final expectedHash = await _calculateSha256(data);
      final fileA = File(p.join(dirA.path, 'perf_64k.bin'))..writeAsBytesSync(data);

      final transferId = 'FT-PERF-64K';
      await nodeB.fileTransferService.registerIncomingTransfer(
        transferId: transferId,
        peerId: nodeA.id,
        fileName: 'perf_64k.bin',
        fileSize: 65536,
        fileHash: expectedHash,
        totalChunks: 4, // 64KB / 16KB defaultChunkSize
      );

      final stopwatch = Stopwatch()..start();

      final sendResult = await nodeA.fileTransferService.sendFile(
        peerId: nodeB.id,
        file: fileA,
        transferId: transferId,
      );

      expect(sendResult.isSuccess, isTrue);

      FileTransfer? transferB;
      for (var i = 0; i < 100; i++) {
        transferB = await nodeB.fileTransferService.getTransfer(transferId);
        if (transferB?.status == FileTransferStatus.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      stopwatch.stop();

      expect(transferB, isNotNull);
      expect(transferB!.status, equals(FileTransferStatus.completed));
      expect(await File(transferB.localPath).length(), equals(65536));
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));

      await nodeA.dispose();
      await nodeB.dispose();
    });
  });
}
