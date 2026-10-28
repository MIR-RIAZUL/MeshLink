import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_ack_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_disk_writer.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_resumption_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late DriftMessageRepository repo;
  late ReplayProtectionService replayService;

  late MeshIdentityService aliceIdentity;
  late MeshIdentityService bobIdentity;

  late EphemeralSessionService aliceSessionService;
  late EphemeralSessionService bobSessionService;

  late HandshakeService aliceHandshake;
  late HandshakeService bobHandshake;

  late DirectionalSessionEncryptionService directionalService;
  late FileTransferCryptoService cryptoService;
  late FilePathService pathService;
  late FileAssemblyService assemblyService;
  late ChunkReceivingPipeline receivingPipeline;
  late ChunkSendingPipeline sendingPipeline;
  late ChunkAckService ackService;
  late FileTransferResumptionService resumptionService;

  final testNow = DateTime.utc(2026, 10, 28, 12, 0, 0);

  Future<String> calculateSha256(Uint8List bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step14_test_');

    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMessageRepository(db);
    replayService = ReplayProtectionService(repository: repo);

    aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    await aliceIdentity.initialize();
    await bobIdentity.initialize();

    // Store peer identities in repo for trust checks
    await repo.savePeerIdentity(
      PeerIdentityEntry(
        peerId: 'ML-DEVICE-ALICE',
        identityPublicKey: await aliceIdentity.getIdentityPublicKey(),
        safetyNumber: '123456',
        trustStatus: 'verified',
        protocolVersion: 2,
        firstSeenAt: testNow,
        lastSeenAt: testNow,
      ),
    );
    await repo.savePeerIdentity(
      PeerIdentityEntry(
        peerId: 'ML-DEVICE-BOB',
        identityPublicKey: await bobIdentity.getIdentityPublicKey(),
        safetyNumber: '654321',
        trustStatus: 'verified',
        protocolVersion: 2,
        firstSeenAt: testNow,
        lastSeenAt: testNow,
      ),
    );

    aliceSessionService = EphemeralSessionService(clock: () => testNow);
    bobSessionService = EphemeralSessionService(clock: () => testNow);

    aliceHandshake = HandshakeService(
      identityService: aliceIdentity,
      localId: 'ML-DEVICE-ALICE',
      sessionService: aliceSessionService,
    );
    bobHandshake = HandshakeService(
      identityService: bobIdentity,
      localId: 'ML-DEVICE-BOB',
      sessionService: bobSessionService,
    );

    directionalService = DirectionalSessionEncryptionService();
    cryptoService =
        FileTransferCryptoService(encryptionService: directionalService);
    pathService = FilePathService(baseDirectory: tempDir);
    assemblyService = FileAssemblyService(
      database: db,
      pathService: pathService,
    );
    ackService = ChunkAckService(
      localDeviceId: 'ML-DEVICE-BOB',
      database: db,
      messageRepository: repo,
      replayProtectionService: replayService,
      encryptionService: directionalService,
    );
    receivingPipeline = ChunkReceivingPipeline(
      localDeviceId: 'ML-DEVICE-BOB',
      database: db,
      messageRepository: repo,
      replayProtectionService: replayService,
      cryptoService: cryptoService,
      pathService: pathService,
      assemblyService: assemblyService,
      ackService: ackService,
    );
    sendingPipeline = ChunkSendingPipeline(
      localDeviceId: 'ML-DEVICE-ALICE',
      database: db,
      messageRepository: repo,
      cryptoService: cryptoService,
    );

    resumptionService = FileTransferResumptionService(
      database: db,
      localDeviceId: 'ML-DEVICE-BOB',
      pathService: pathService,
      assemblyService: assemblyService,
      receivingPipeline: receivingPipeline,
      sendingPipeline: sendingPipeline,
      messageRepository: repo,
      replayProtectionService: replayService,
    );
  });

  tearDown(() async {
    await receivingPipeline.closeAll();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<({EphemeralSession sessionAlice, EphemeralSession sessionBob})>
      establishSession({
    String requestId = 'REQ-STEP14-001',
  }) async {
    final request = await aliceHandshake.createKeyRequest(
      destinationId: 'ML-DEVICE-BOB',
      requestId: requestId,
    );
    final verifiedReq = await bobHandshake.verifyKeyRequest(request);
    final response = await bobHandshake.createKeyResponse(request: request);
    final verifiedResp = await aliceHandshake.verifyKeyResponse(response);

    final sessionAlice = await aliceHandshake.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: testNow,
    );
    final sessionBob = await bobHandshake.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: testNow,
    );

    return (sessionAlice: sessionAlice, sessionBob: sessionBob);
  }

  Future<FileTransferEntry> createTransferInDb({
    required String transferId,
    required String fileName,
    required int fileSize,
    required int chunkSize,
    required int totalChunks,
    required String fileHash,
    String direction = 'incoming',
    String status = 'transferring',
    String peerId = 'ML-DEVICE-ALICE',
    String? stagingPath,
    String? localPath,
  }) async {
    final staging = stagingPath ?? await pathService.getStagingPath(transferId);
    final dest = localPath ?? p.join((await pathService.getCompletedDirectory()).path, fileName);
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
    return (await db.getFileTransfer(transferId))!;
  }

  group('Phase 8 Step 14: Interruption and Resumption', () {
    test('1. Restoring an interrupted transfer after service recreation', () async {
      final transferId = 'FT-RESTORE-001';
      final fileName = 'interrupted_doc.bin';
      const fileSize = 300;
      const chunkSize = 100;
      const totalChunks = 3;

      final chunk0 = Uint8List.fromList(List.generate(100, (i) => i));
      final chunk1 = Uint8List.fromList(List.generate(100, (i) => 100 + i));
      final chunk2 = Uint8List.fromList(List.generate(100, (i) => 200 + i));
      final fullBytes = Uint8List.fromList([...chunk0, ...chunk1, ...chunk2]);
      final fileHash = await calculateSha256(fullBytes);

      // Create staging file with chunks 0 and 1 written, chunk 2 missing
      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      await writer.writeAt(offset: 0, data: chunk0);
      await writer.writeAt(offset: 100, data: chunk1);
      await writer.flush();
      await writer.close();

      // Persist transfer and chunks 0 and 1 in database
      await createTransferInDb(
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        fileHash: fileHash,
        status: 'transferring',
      );
      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 1);

      // SIMULATE APP RESTART: Recreate service instance using the same database and path service
      final restoredService = FileTransferResumptionService(
        database: db,
        localDeviceId: 'ML-DEVICE-BOB',
        pathService: pathService,
        assemblyService: assemblyService,
        messageRepository: repo,
        replayProtectionService: replayService,
      );

      final interruptedList = await restoredService.getInterruptedTransfers();
      expect(interruptedList.length, equals(1));
      final restored = interruptedList.first;
      expect(restored.transferId, equals(transferId));
      expect(restored.fileName, equals(fileName));
      expect(restored.fileSize, equals(fileSize));
      expect(restored.totalChunks, equals(totalChunks));
      expect(restored.chunkSize, equals(chunkSize));
      expect(restored.fileHash, equals(fileHash));
      expect(restored.status, equals(FileTransferStatus.transferring));
      expect(restored.direction, equals(FileTransferDirection.incoming));
    });

    test('2. Resuming an eligible transfer with previously received chunks', () async {
      final transferId = 'FT-RESUME-002';
      const fileSize = 200;
      const chunkSize = 50;
      const totalChunks = 4;

      final chunk0 = Uint8List.fromList(List.generate(50, (i) => i));
      final chunk1 = Uint8List.fromList(List.generate(50, (i) => 50 + i));
      final chunk2 = Uint8List.fromList(List.generate(50, (i) => 100 + i));
      final chunk3 = Uint8List.fromList(List.generate(50, (i) => 150 + i));
      final fullBytes = Uint8List.fromList([...chunk0, ...chunk1, ...chunk2, ...chunk3]);
      final fileHash = await calculateSha256(fullBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      // Write chunk 0 and chunk 1
      await writer.writeAt(offset: 0, data: chunk0);
      await writer.writeAt(offset: 50, data: chunk1);
      await writer.flush();
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'resume_partial.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        fileHash: fileHash,
        status: 'paused',
      );
      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 1);

      final reconciliation = await resumptionService.reconcileTransfer(transferId);
      expect(reconciliation.transferId, equals(transferId));
      expect(reconciliation.receivedChunkIndexes, equals([0, 1]));
      expect(reconciliation.missingChunkIndexes, equals([2, 3]));
      expect(reconciliation.isComplete, isFalse);
      expect(reconciliation.stagingFileExists, isTrue);

      // Verify intact staged bytes on disk were preserved without modification
      final reader = FileDiskWriter(filePathService: pathService);
      await reader.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      final readChunk0 = await reader.readAt(offset: 0, length: 50);
      final readChunk1 = await reader.readAt(offset: 50, length: 50);
      await reader.close();
      expect(readChunk0, equals(chunk0));
      expect(readChunk1, equals(chunk1));
    });

    test('3. Identifying missing chunks correctly', () async {
      final transferId = 'FT-IDENTIFY-003';
      const fileSize = 500;
      const chunkSize = 100;
      const totalChunks = 5;

      final dummyBytes = Uint8List(500);
      final fileHash = await calculateSha256(dummyBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'sparse.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        fileHash: fileHash,
      );

      // Only chunks 0, 2, 4 are recorded
      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 2);
      await db.markChunkReceived(transferId, 4);

      final result = await resumptionService.reconcileTransfer(transferId);
      expect(result.receivedChunkIndexes, equals([0, 2, 4]));
      expect(result.missingChunkIndexes, equals([1, 3]));
      expect(result.isComplete, isFalse);
      expect(result.missingCount, equals(2));
      expect(result.receivedCount, equals(3));
    });

    test('4. Detecting truncated or corrupted staged data', () async {
      final transferId = 'FT-TRUNC-004';
      const fileSize = 300;
      const chunkSize = 100;
      const totalChunks = 3;

      final dummyBytes = Uint8List(300);
      final fileHash = await calculateSha256(dummyBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      // Staging file is truncated to 150 bytes (e.g. crash during write of chunk 1)
      await writer.truncate(150);
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'truncated.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        fileHash: fileHash,
      );

      // SQLite had marked chunks 0, 1, 2 as received before crash
      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 1);
      await db.markChunkReceived(transferId, 2);

      // Reconcile with repairDatabase: true
      final result = await resumptionService.reconcileTransfer(transferId, repairDatabase: true);
      expect(result.hasCorruptedOrTruncatedChunks, isTrue);
      // Chunk 0 is within 150 bytes [0..100). Chunk 1 [100..200) and Chunk 2 [200..300) are truncated!
      expect(result.receivedChunkIndexes, equals([0]));
      expect(result.missingChunkIndexes, equals([1, 2]));

      // Verify that database was repaired and invalid chunk records for 1 and 2 were removed
      final remainingDbChunks = await db.getFileChunks(transferId);
      expect(remainingDbChunks.length, equals(1));
      expect(remainingDbChunks.first.chunkIndex, equals(0));

      // Test complete missing staging file case
      final transferIdMissingFile = 'FT-NOFILE-004';
      await createTransferInDb(
        transferId: transferIdMissingFile,
        fileName: 'nofile.bin',
        fileSize: 100,
        chunkSize: 50,
        totalChunks: 2,
        fileHash: fileHash,
        stagingPath: p.join((await pathService.getStagingDirectory(create: true)).path, 'nonexistent.part'),
      );
      await db.markChunkReceived(transferIdMissingFile, 0);

      final resultNoFile = await resumptionService.reconcileTransfer(transferIdMissingFile, repairDatabase: true);
      expect(resultNoFile.stagingFileExists, isFalse);
      expect(resultNoFile.receivedChunkIndexes, isEmpty);
      expect(resultNoFile.missingChunkIndexes, equals([0, 1]));
      expect(resultNoFile.hasCorruptedOrTruncatedChunks, isTrue);
    });

    test('5. Rejecting completed, cancelled, and failed transfers', () async {
      const statuses = [
        FileTransferStatus.completed,
        FileTransferStatus.cancelled,
        FileTransferStatus.failed,
      ];

      for (final st in statuses) {
        final transferId = 'FT-TERMINAL-${st.name}';
        await createTransferInDb(
          transferId: transferId,
          fileName: 'terminal_${st.name}.bin',
          fileSize: 100,
          chunkSize: 50,
          totalChunks: 2,
          fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          status: st.name,
        );

        // Verify getInterruptedTransfers filters them out
        final eligible = await resumptionService.getInterruptedTransfers();
        expect(eligible.any((t) => t.transferId == transferId), isFalse);

        // Verify reconcileTransfer rejects them
        expect(
          () => resumptionService.reconcileTransfer(transferId),
          throwsA(isA<IneligibleTransferException>()),
        );
      }
    });

    test('6. Rejecting inconsistent persisted metadata', () async {
      // Negative fileSize
      expect(
        () => resumptionService.validatePersistedMetadata(
          FileTransfer(
            transferId: 'FT-BAD-SIZE',
            conversationId: 'CONV-1',
            peerId: 'PEER-1',
            direction: FileTransferDirection.incoming,
            fileName: 'file.bin',
            fileSize: -10,
            mimeType: 'text/plain',
            fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            localPath: '',
            stagingPath: '',
            totalChunks: 1,
            chunkSize: 64,
            status: FileTransferStatus.transferring,
            createdAt: testNow,
            updatedAt: testNow,
          ),
        ),
        throwsA(isA<ArgumentError>()), // Caught by domain constructor
      );

      // Inconsistent totalChunks calculation
      final badChunkTransfer = FileTransfer(
        transferId: 'FT-BAD-CHUNKS',
        conversationId: 'CONV-1',
        peerId: 'PEER-1',
        direction: FileTransferDirection.incoming,
        fileName: 'file.bin',
        fileSize: 100,
        mimeType: 'text/plain',
        fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        localPath: '',
        stagingPath: await pathService.getStagingPath('FT-BAD-CHUNKS'),
        totalChunks: 5, // Expected (100+64-1)/64 = 2, but declares 5!
        chunkSize: 64,
        status: FileTransferStatus.transferring,
        createdAt: testNow,
        updatedAt: testNow,
      );
      expect(
        () => resumptionService.validatePersistedMetadata(badChunkTransfer),
        throwsA(isA<InconsistentTransferMetadataException>()),
      );

      // Invalid SHA-256 hash length
      final badHashTransfer = FileTransfer(
        transferId: 'FT-BAD-HASH',
        conversationId: 'CONV-1',
        peerId: 'PEER-1',
        direction: FileTransferDirection.incoming,
        fileName: 'file.bin',
        fileSize: 100,
        mimeType: 'text/plain',
        fileHash: 'too_short_hash',
        localPath: '',
        stagingPath: await pathService.getStagingPath('FT-BAD-HASH'),
        totalChunks: 2,
        chunkSize: 64,
        status: FileTransferStatus.transferring,
        createdAt: testNow,
        updatedAt: testNow,
      );
      expect(
        () => resumptionService.validatePersistedMetadata(badHashTransfer),
        throwsA(isA<InconsistentTransferMetadataException>()),
      );

      // Path traversal in staging path
      final badStagingTransfer = FileTransfer(
        transferId: 'FT-BAD-STAGING',
        conversationId: 'CONV-1',
        peerId: 'PEER-1',
        direction: FileTransferDirection.incoming,
        fileName: 'file.bin',
        fileSize: 100,
        mimeType: 'text/plain',
        fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        localPath: '',
        stagingPath: p.join(tempDir.path, '..', 'evil.part'),
        totalChunks: 2,
        chunkSize: 64,
        status: FileTransferStatus.transferring,
        createdAt: testNow,
        updatedAt: testNow,
      );
      expect(
        () => resumptionService.validatePersistedMetadata(badStagingTransfer),
        throwsA(isA<InconsistentTransferMetadataException>()),
      );
    });

    test('7. Preserving replay protection across restarts', () async {
      final sessions = await establishSession();
      final transferId = 'FT-REPLAY-SURVIVAL';
      const fileSize = 100;
      const chunkSize = 50;

      final chunk0Data = Uint8List.fromList(List.generate(50, (i) => i));
      final chunk1Data = Uint8List.fromList(List.generate(50, (i) => 50 + i));
      final fullBytes = Uint8List.fromList([...chunk0Data, ...chunk1Data]);
      final fileHash = await calculateSha256(fullBytes);

      await createTransferInDb(
        transferId: transferId,
        fileName: 'replay_test.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: 2,
        fileHash: fileHash,
      );

      // Encrypt chunk 0
      final chunk0Envelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        plaintext: chunk0Data,
        chunkLength: 50,
      );

      // Receive chunk 0 in Bob pipeline (records packet in seen_packets_table)
      final receiveRes = await receivingPipeline.receiveChunk(
        envelope: chunk0Envelope,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(receiveRes.isSuccess, isTrue);

      // SIMULATE APP RESTART: Recreate ReplayProtectionService and ChunkReceivingPipeline
      // using the persistent SQLite database
      final freshReplayService = ReplayProtectionService(repository: repo);
      final freshPipeline = ChunkReceivingPipeline(
        localDeviceId: 'ML-DEVICE-BOB',
        database: db,
        messageRepository: repo,
        replayProtectionService: freshReplayService,
        cryptoService: cryptoService,
        pathService: pathService,
      );

      // Replay the exact same chunk envelope from before restart
      expect(
        () => freshPipeline.receiveChunk(
          envelope: chunk0Envelope,
          session: sessions.sessionBob,
          now: testNow,
        ),
        throwsA(isA<ChunkReplayException>()),
      );

      await freshPipeline.closeAll();
    });

    test('8. Repeated resume requests being idempotent', () async {
      final sessions = await establishSession();
      final transferId = 'FT-IDEMPOTENT-008';
      const fileSize = 150;
      const chunkSize = 50;

      final chunk0 = Uint8List.fromList(List.generate(50, (i) => i));
      final fileHash = await calculateSha256(Uint8List(150));

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      await writer.writeAt(offset: 0, data: chunk0);
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'idempotent.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: 3,
        fileHash: fileHash,
        status: 'paused',
      );
      await db.markChunkReceived(transferId, 0);

      var sentRequests = <FileChunkResumeRequest>[];
      final mockSender = FunctionalChunkResumeTransportSender((req) async {
        sentRequests.add(req);
        return true;
      });

      // Issue resume request 1
      final req1 = await resumptionService.requestMissingChunks(
        transferId: transferId,
        session: sessions.sessionBob,
        transportSender: mockSender,
      );
      expect(req1.missingChunkIndexes, equals([1, 2]));

      // Issue resume request 2 (repeated)
      final req2 = await resumptionService.requestMissingChunks(
        transferId: transferId,
        session: sessions.sessionBob,
        transportSender: mockSender,
      );
      expect(req2.missingChunkIndexes, equals([1, 2]));

      // Results must be identical
      expect(req1.missingChunkIndexes, equals(req2.missingChunkIndexes));
      expect(sentRequests.length, equals(2));

      // Reconcile remains identical
      final recon1 = await resumptionService.reconcileTransfer(transferId);
      final recon2 = await resumptionService.reconcileTransfer(transferId);
      expect(recon1.receivedChunkIndexes, equals(recon2.receivedChunkIndexes));
      expect(recon1.missingChunkIndexes, equals(recon2.missingChunkIndexes));
    });

    test('9. Correct resumption when several chunks are missing', () async {
      final sessions = await establishSession();
      final transferId = 'FT-SEVERAL-MISSING';
      const fileSize = 300;
      const chunkSize = 50;
      const totalChunks = 6;

      final chunks = List.generate(6, (idx) {
        return Uint8List.fromList(List.generate(50, (i) => (idx * 50 + i) % 256));
      });
      final fullBytes = Uint8List.fromList(chunks.expand((c) => c).toList());
      final fileHash = await calculateSha256(fullBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      // Chunks 0 and 3 are present on disk
      await writer.writeAt(offset: 0, data: chunks[0]);
      await writer.writeAt(offset: 150, data: chunks[3]);
      await writer.flush();
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'several_missing.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        fileHash: fileHash,
        status: 'paused',
      );
      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 3);

      final requested = <FileChunkResumeRequest>[];
      final transportSender = FunctionalChunkResumeTransportSender((req) async {
        requested.add(req);
        return true;
      });

      final resumeReq = await resumptionService.requestMissingChunks(
        transferId: transferId,
        session: sessions.sessionBob,
        transportSender: transportSender,
      );

      // Chunks 1, 2, 4, 5 were missing!
      expect(resumeReq.missingChunkIndexes, equals([1, 2, 4, 5]));

      // Sender peer transmits missing chunks 1, 2, 4, 5
      for (final idx in resumeReq.missingChunkIndexes) {
        final offset = idx * chunkSize;
        final envelope = await cryptoService.encryptChunk(
          session: sessions.sessionAlice,
          transferId: transferId,
          originId: 'ML-DEVICE-ALICE',
          destinationId: 'ML-DEVICE-BOB',
          chunkIndex: idx,
          totalChunks: totalChunks,
          offset: offset,
          plaintext: chunks[idx],
          chunkLength: chunkSize,
        );

        final recRes = await receivingPipeline.receiveChunk(
          envelope: envelope,
          session: sessions.sessionBob,
          now: testNow,
        );
        expect(recRes.isSuccess, isTrue);
      }

      // Reconcile again: now all 6 chunks are present!
      final recon = await resumptionService.reconcileTransfer(transferId);
      expect(recon.isComplete, isTrue);
      expect(recon.receivedChunkIndexes, equals([0, 1, 2, 3, 4, 5]));
      expect(recon.missingChunkIndexes, isEmpty);

      // Complete assembly
      final assembly = await resumptionService.assembleIfComplete(transferId);
      expect(assembly.isSuccess, isTrue);
      expect(assembly.fileSize, equals(fileSize));
      expect(File(assembly.destinationPath).existsSync(), isTrue);
      expect(await File(assembly.destinationPath).readAsBytes(), equals(fullBytes));
    });

    test('10. Path traversal and unrelated-file overwrite prevention', () async {
      final transferId = 'FT-SAFETY-010';
      final completedDir = await pathService.getCompletedDirectory(create: true);

      // Create an existing unrelated destination file
      final existingFile = File(p.join(completedDir.path, 'important_doc.pdf'));
      await existingFile.writeAsString('CRITICAL UNRELATED SYSTEM DATA');

      final dummyBytes = Uint8List.fromList(List.generate(100, (i) => i));
      final fileHash = await calculateSha256(dummyBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: 100,
        stagingPath: stagingPath,
      );
      await writer.writeAt(offset: 0, data: dummyBytes);
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'important_doc.pdf',
        fileSize: 100,
        chunkSize: 100,
        totalChunks: 1,
        fileHash: fileHash,
        localPath: existingFile.path,
      );
      await db.markChunkReceived(transferId, 0);

      // Assembling with default collisionSafe policy must NOT overwrite the existing file
      final assemblyResult = await resumptionService.assembleIfComplete(
        transferId,
        replacementPolicy: FileReplacementPolicy.collisionSafe,
      );

      expect(assemblyResult.isSuccess, isTrue);
      expect(assemblyResult.destinationPath, isNot(equals(existingFile.path)));
      expect(p.basename(assemblyResult.destinationPath), equals('important_doc (1).pdf'));

      // Verify the original file content was completely preserved
      expect(await existingFile.readAsString(), equals('CRITICAL UNRELATED SYSTEM DATA'));
    });

    test('11. Successful completion only after Step 13 integrity verification', () async {
      final transferId = 'FT-HASH-CHECK-011';
      const fileSize = 100;
      final actualBytes = Uint8List.fromList(List.generate(100, (i) => i));
      final correctHash = await calculateSha256(actualBytes);

      // Setup corrupted staging file where 1 byte is modified
      final corruptedBytes = Uint8List.fromList(actualBytes);
      corruptedBytes[10] = 99; // Tamper 1 byte!

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      await writer.writeAt(offset: 0, data: corruptedBytes);
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'tampered.bin',
        fileSize: fileSize,
        chunkSize: 100,
        totalChunks: 1,
        fileHash: correctHash, // Expected hash corresponds to untampered data
      );
      await db.markChunkReceived(transferId, 0);

      // Whole-file SHA-256 verification must catch the tampered byte and reject assembly
      try {
        await resumptionService.assembleIfComplete(transferId);
        fail('Should have thrown FileHashMismatchException');
      } on FileHashMismatchException catch (e) {
        expect(e.expectedHash, equals(correctHash));
      }

      // SQLite status must be marked failed
      final transferEntry = await db.getFileTransfer(transferId);
      expect(transferEntry!.status, equals('failed'));

      // Partial file must NEVER be exposed in completed directory
      final completedDir = await pathService.getCompletedDirectory();
      expect(File(p.join(completedDir.path, 'tampered.bin')).existsSync(), isFalse);
    });

    test('12. Recovery failures not falsely advancing progress', () async {
      final sessions = await establishSession();
      final transferId = 'FT-FAILURE-NO-ADVANCE';
      const fileSize = 200;
      const chunkSize = 100;

      final chunk0Data = Uint8List.fromList(List.generate(100, (i) => i));
      final fileHash = await calculateSha256(Uint8List(200));

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: fileSize,
        stagingPath: stagingPath,
      );
      await writer.writeAt(offset: 0, data: chunk0Data);
      await writer.close();

      await createTransferInDb(
        transferId: transferId,
        fileName: 'fail_advance.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: 2,
        fileHash: fileHash,
      );
      await db.markChunkReceived(transferId, 0);

      // Create an envelope with invalid ciphertext/MAC (tampered)
      final validEnvelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 2,
        offset: 100,
        plaintext: Uint8List(100),
        chunkLength: 100,
      );

      final tamperedCiphertext = Uint8List.fromList(validEnvelope.ciphertext);
      tamperedCiphertext[0] ^= 0xFF; // Corrupt ciphertext byte
      final tamperedEnvelope = validEnvelope.copyWith(ciphertext: tamperedCiphertext);

      // Attempt to receive tampered chunk
      try {
        await receivingPipeline.receiveChunk(
          envelope: tamperedEnvelope,
          session: sessions.sessionBob,
          now: testNow,
        );
        fail('Should have failed authentication');
      } catch (e) {
        expect(e, isA<ChunkAuthenticationException>());
      }

      // Progress must NOT have advanced: only chunk 0 is received
      final chunks = await db.getFileChunks(transferId);
      expect(chunks.length, equals(1));
      expect(chunks.first.chunkIndex, equals(0));

      final recon = await resumptionService.reconcileTransfer(transferId);
      expect(recon.receivedChunkIndexes, equals([0]));
      expect(recon.missingChunkIndexes, equals([1]));
      expect(recon.isComplete, isFalse);
    });

    test('13. Regression compatibility with existing Steps 11, 12, and 13', () async {
      final sessions = await establishSession();
      final transferId = 'FT-REGRESSION-ALL-STEPS';
      const fileSize = 150;
      const chunkSize = 50;
      const totalChunks = 3;

      final chunk0 = Uint8List.fromList(List.generate(50, (i) => i));
      final chunk1 = Uint8List.fromList(List.generate(50, (i) => 50 + i));
      final chunk2 = Uint8List.fromList(List.generate(50, (i) => 100 + i));
      final fullBytes = Uint8List.fromList([...chunk0, ...chunk1, ...chunk2]);
      final fileHash = await calculateSha256(fullBytes);

      await createTransferInDb(
        transferId: transferId,
        fileName: 'full_regression.bin',
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        fileHash: fileHash,
        status: 'acceptSent',
      );

      // Step 11 & Step 12: Receive Chunk 0 out-of-order? No, receive Chunk 0, then Chunk 2 (leaving Chunk 1 missing)
      final env0 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: chunk0,
        chunkLength: 50,
      );
      final res0 = await receivingPipeline.receiveChunk(
        envelope: env0,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(res0.isSuccess, isTrue);
      expect(res0.ackEnvelope, isNotNull); // Step 12 ACK produced!

      final env2 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 2,
        totalChunks: 3,
        offset: 100,
        plaintext: chunk2,
        chunkLength: 50,
      );
      final res2 = await receivingPipeline.receiveChunk(
        envelope: env2,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(res2.isSuccess, isTrue);

      // Step 14 Resumption: Reconcile detects chunk 1 is missing
      final recon = await resumptionService.reconcileTransfer(transferId);
      expect(recon.receivedChunkIndexes, equals([0, 2]));
      expect(recon.missingChunkIndexes, equals([1]));

      // Receive the missing chunk 1
      final env1 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 3,
        offset: 50,
        plaintext: chunk1,
        chunkLength: 50,
      );
      final res1 = await receivingPipeline.receiveChunk(
        envelope: env1,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(res1.isSuccess, isTrue);

      // Step 13 Assembly via resumption service
      final assemblyResult = await resumptionService.assembleIfComplete(transferId);
      expect(assemblyResult.isSuccess, isTrue);
      expect(assemblyResult.fileSize, equals(fileSize));
      expect(assemblyResult.fileHash, equals(fileHash));

      // Verify destination file
      final placedFile = File(assemblyResult.destinationPath);
      expect(placedFile.existsSync(), isTrue);
      expect(await placedFile.readAsBytes(), equals(fullBytes));

      // Verify SQLite status is completed
      final finalEntry = await db.getFileTransfer(transferId);
      expect(finalEntry!.status, equals('completed'));
      expect(finalEntry.localPath, equals(assemblyResult.destinationPath));

      // Verify Idempotent assembly call
      final idempotentResult = await resumptionService.assembleIfComplete(transferId);
      expect(idempotentResult.isSuccess, isTrue);
      expect(idempotentResult.isIdempotent, isTrue);
    });
  });
}
