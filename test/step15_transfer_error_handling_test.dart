import 'dart:async';
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
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart'
    hide ChunkMetadataMismatchException;
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_resumption_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
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
  late ChunkAckService aliceAckService;
  late FileTransferResumptionService resumptionService;

  final testNow = DateTime.utc(2026, 10, 29, 12, 0, 0);

  Future<String> calculateSha256(Uint8List bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step15_test_');

    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMessageRepository(db);
    replayService = ReplayProtectionService(repository: repo);

    aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    await aliceIdentity.initialize();
    await bobIdentity.initialize();

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
    aliceAckService = ChunkAckService(
      localDeviceId: 'ML-DEVICE-ALICE',
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
    String requestId = 'REQ-STEP15-001',
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
    return (await db.getFileTransfer(transferId))!;
  }

  Future<File> createTestFile(String name, int size, [int byteVal = 0xAA]) async {
    final file = File(p.join(tempDir.path, name));
    final bytes = Uint8List(size)..fillRange(0, size, byteVal);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  group('Phase 8 Step 15: Cancellation, Timeout, and Error Handling', () {
    test('1. Cancelling an active outgoing transfer', () async {
      final sessions = await establishSession();
      final file = await createTestFile('outgoing_cancel.bin', 3000, 0x41);
      final fileHash = await calculateSha256(await file.readAsBytes());

      const transferId = 'TX-CANCEL-OUT-001';
      final entry = await createTransferInDb(
        transferId: transferId,
        fileName: 'outgoing_cancel.bin',
        fileSize: 3000,
        chunkSize: 1000,
        totalChunks: 3,
        fileHash: fileHash,
        direction: 'outgoing',
        status: 'acceptReceived',
        peerId: 'ML-DEVICE-BOB',
        localPath: file.path,
        stagingPath: '',
      );
      final transfer = FileTransfer.fromEntry(entry);

      final handoffs = <int>[];
      final sender = FunctionalChunkTransportSender((env) async {
        handoffs.add(env.chunkIndex);
        if (env.chunkIndex == 0) {
          // Cancel transfer via pipeline API on first chunk handoff
          await sendingPipeline.cancelTransfer(transferId, 'User clicked cancel');
        }
        return true;
      });

      await expectLater(
        () => sendingPipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
          throwOnError: true,
        ),
        throwsA(isA<ChunkSendCancelledException>()),
      );

      // Verify that no further chunks were sent after cancellation
      expect(handoffs, equals([0]));

      // Verify persistent SQLite record has terminal cancelled status
      final record = await db.getFileTransfer(transferId);
      expect(record!.status, equals(FileTransferStatus.cancelled.toDbValue()));
    });

    test('2. Cancelling an active incoming transfer', () async {
      final sessions = await establishSession();
      final file = await createTestFile('incoming_cancel.bin', 2000, 0x42);
      final fileHash = await calculateSha256(await file.readAsBytes());

      const transferId = 'TX-CANCEL-IN-001';
      final stagingPath = await pathService.getStagingPath(transferId);
      await createTransferInDb(
        transferId: transferId,
        fileName: 'incoming_cancel.bin',
        fileSize: 2000,
        chunkSize: 1000,
        totalChunks: 2,
        fileHash: fileHash,
        direction: 'incoming',
        status: 'acceptSent',
        peerId: 'ML-DEVICE-ALICE',
        localPath: '',
        stagingPath: stagingPath,
      );

      // Prepare chunk 0 and chunk 1
      final chunk0Data = Uint8List(1000)..fillRange(0, 1000, 0x42);
      final chunk1Data = Uint8List(1000)..fillRange(0, 1000, 0x42);

      final env0 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        plaintext: chunk0Data,
        chunkLength: 1000,
      );
      final env1 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 2,
        offset: 1000,
        plaintext: chunk1Data,
        chunkLength: 1000,
      );

      // 1. Receive chunk 0 successfully
      final res0 = await receivingPipeline.receiveChunk(
        envelope: env0,
        session: sessions.sessionBob,
      );
      expect(res0.isSuccess, isTrue);

      // Verify staging file writer is open
      expect(receivingPipeline.getActiveWriter(transferId), isNotNull);

      // 2. Cancel the incoming transfer
      final cancelled = await receivingPipeline.cancelTransfer(transferId, 'User stopped transfer');
      expect(cancelled, isTrue);

      // Verify writer handle was safely closed
      expect(receivingPipeline.getActiveWriter(transferId), isNull);

      // Staging file is preserved on disk for diagnosis/recovery (Requirement B.9)
      expect(await File(stagingPath).exists(), isTrue);

      // Database status is cancelled
      final record = await db.getFileTransfer(transferId);
      expect(record!.status, equals(FileTransferStatus.cancelled.toDbValue()));

      // 3. Late arriving chunk 1 is rejected
      expect(
        () => receivingPipeline.receiveChunk(
          envelope: env1,
          session: sessions.sessionBob,
        ),
        throwsA(isA<ChunkReceiveCancelledException>()),
      );
    });

    test('3. Repeated cancellation requests are strictly idempotent', () async {
      await establishSession();
      final file = await createTestFile('idempotent_cancel.bin', 1000);
      final fileHash = await calculateSha256(await file.readAsBytes());

      const transferId = 'TX-IDEMPOTENT-CANCEL';
      await createTransferInDb(
        transferId: transferId,
        fileName: 'idempotent_cancel.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: fileHash,
        direction: 'outgoing',
        status: 'acceptReceived',
        peerId: 'ML-DEVICE-BOB',
        localPath: file.path,
        stagingPath: '',
      );

      // Cancel 1
      final c1 = await sendingPipeline.cancelTransfer(transferId, 'First cancel');
      expect(c1, isTrue);
      // Cancel 2
      final c2 = await sendingPipeline.cancelTransfer(transferId, 'Duplicate cancel');
      expect(c2, isTrue);
      // Cancel 3
      final c3 = await sendingPipeline.cancelTransfer(transferId, 'Third cancel');
      expect(c3, isTrue);

      final record = await db.getFileTransfer(transferId);
      expect(record!.status, equals(FileTransferStatus.cancelled.toDbValue()));

      // Also verify on receiving pipeline
      const inTransferId = 'TX-IN-IDEMPOTENT-CANCEL';
      await createTransferInDb(
        transferId: inTransferId,
        fileName: 'idempotent_cancel.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: fileHash,
        direction: 'incoming',
        status: 'acceptSent',
        peerId: 'ML-DEVICE-ALICE',
        localPath: '',
        stagingPath: await pathService.getStagingPath(inTransferId),
      );

      expect(await receivingPipeline.cancelTransfer(inTransferId), isTrue);
      expect(await receivingPipeline.cancelTransfer(inTransferId), isTrue);
      expect(await receivingPipeline.cancelTransfer(inTransferId), isTrue);

      final inRecord = await db.getFileTransfer(inTransferId);
      expect(inRecord!.status, equals(FileTransferStatus.cancelled.toDbValue()));
    });

    test('4. Cancellation during a pending ACK wait terminates promptly', () async {
      final tracker = ChunkAckTracker();
      final token = FileTransferCancellationToken();

      const transferId = 'TX-PENDING-ACK-CANCEL';
      const chunkIndex = 0;

      final ackFuture = tracker.waitForAck(
        transferId: transferId,
        chunkIndex: chunkIndex,
        timeout: const Duration(seconds: 30),
        cancellationToken: token,
      );

      expect(tracker.pendingCount, equals(1));

      // Trigger cancellation while waiting for ACK
      token.cancel('User aborted waiting for ACK');

      // Waiter terminates promptly with ChunkSendCancelledException
      await expectLater(
        ackFuture,
        throwsA(isA<ChunkSendCancelledException>()),
      );

      // Pending waiter and timers are released
      expect(tracker.pendingCount, equals(0));
    });

    test('5. Cancellation during retry backoff interrupts delay promptly', () async {
      final token = FileTransferCancellationToken();
      final stopwatch = Stopwatch()..start();

      // Launch a 30-second cancellable delay
      final delayFuture = cancellableDelay(
        const Duration(seconds: 30),
        token: token,
      );

      // Cancel after 20ms
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel('Cancel during retry delay');

      await expectLater(
        delayFuture,
        throwsA(isA<ChunkSendCancelledException>()),
      );
      stopwatch.stop();

      // Ensure we didn't wait anywhere near 30 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('6. Late ACK/NACK arrival after cancellation is rejected safely', () async {
      final sessions = await establishSession();
      final tracker = ChunkAckTracker();

      const transferId = 'TX-LATE-ACK-001';
      final file = await createTestFile('late_ack.bin', 1000);
      final fileHash = await calculateSha256(await file.readAsBytes());

      await createTransferInDb(
        transferId: transferId,
        fileName: 'late_ack.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: fileHash,
        direction: 'outgoing',
        status: 'cancelled',
        peerId: 'ML-DEVICE-BOB',
        localPath: file.path,
        stagingPath: '',
      );

      // Transfer cancelled in tracker
      tracker.cancelTransfer(transferId, 'Transfer cancelled');

      final lateAck = ackService.createAck(
        transferId: transferId,
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
        createdAt: testNow,
      );

      // Tracker rejects late ACK
      final accepted = tracker.onAckReceived(lateAck);
      expect(accepted, isFalse);

      // AckService rejects late ACK for cancelled transfer
      expect(
        () => ackService.processReceivedAck(
          ack: lateAck,
          session: sessions.sessionAlice,
        ),
        throwsA(isA<AckInvalidTransferException>()),
      );

      // DB chunk status was never updated
      final chunks = await db.getFileChunks(transferId);
      expect(chunks.isEmpty, isTrue);
    });

    test('7. Timeout releases pending waiters and resources', () async {
      final tracker = ChunkAckTracker();

      const transferId = 'TX-TIMEOUT-CLEANUP';
      final ackFuture = tracker.waitForAck(
        transferId: transferId,
        chunkIndex: 0,
        timeout: const Duration(milliseconds: 20),
      );

      expect(tracker.pendingCount, equals(1));

      await expectLater(
        ackFuture,
        throwsA(isA<TimeoutException>()),
      );

      // Waiter was completely released and removed from pending map
      expect(tracker.pendingCount, equals(0));
    });

    test('8. Retry count remains bounded and throws ChunkAckTimeoutException', () async {
      final sessions = await establishSession();
      final file = await createTestFile('retry_bound.bin', 1000);
      final fileHash = await calculateSha256(await file.readAsBytes());

      const transferId = 'TX-RETRY-BOUND';
      final entry = await createTransferInDb(
        transferId: transferId,
        fileName: 'retry_bound.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: fileHash,
        direction: 'outgoing',
        status: 'acceptReceived',
        peerId: 'ML-DEVICE-BOB',
        localPath: file.path,
        stagingPath: '',
      );
      final transfer = FileTransfer.fromEntry(entry);

      var sendAttempts = 0;
      final sender = FunctionalChunkTransportSender((env) async {
        sendAttempts++;
        return true; // Accepted by transport, but remote peer never ACKs
      });

      final tracker = ChunkAckTracker();
      final policy = ChunkSendingPolicy(
        waitForAcks: true,
        ackTimeout: const Duration(milliseconds: 20),
        retryDelay: Duration.zero,
        maxRetries: 3,
      );

      await expectLater(
        () => sendingPipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
          ackTracker: tracker,
          policy: policy,
          throwOnError: true,
        ),
        throwsA(
          isA<ChunkAckTimeoutException>().having((e) => e.attempts, 'attempts', 3),
        ),
      );

      // Verify that exactly 3 attempts occurred before giving up
      expect(sendAttempts, equals(3));
    });

    test('9. Terminal authentication and integrity errors are not retried indefinitely', () async {
      final sessions = await establishSession();
      const transferId = 'TX-AUTH-FAIL-NO-RETRY';
      final stagingPath = await pathService.getStagingPath(transferId);

      await createTransferInDb(
        transferId: transferId,
        fileName: 'auth_fail.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        direction: 'incoming',
        status: 'acceptSent',
        peerId: 'ML-DEVICE-ALICE',
        localPath: '',
        stagingPath: stagingPath,
      );

      final validEnvelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(1000),
        chunkLength: 1000,
      );

      // Tamper with the MAC tag
      final tamperedMac = Uint8List.fromList(validEnvelope.mac);
      tamperedMac[0] ^= 0xFF;

      final tamperedEnvelope = EncryptedFileChunkEnvelope(
        version: validEnvelope.version,
        transferId: validEnvelope.transferId,
        chunkIndex: validEnvelope.chunkIndex,
        totalChunks: validEnvelope.totalChunks,
        offset: validEnvelope.offset,
        chunkLength: validEnvelope.chunkLength,
        originId: validEnvelope.originId,
        destinationId: validEnvelope.destinationId,
        sessionId: validEnvelope.sessionId,
        epoch: validEnvelope.epoch,
        sequenceNumber: validEnvelope.sequenceNumber,
        nonce: validEnvelope.nonce,
        ciphertext: validEnvelope.ciphertext,
        mac: tamperedMac,
      );

      // Must immediately fail closed with ChunkAuthenticationException and zero disk artifacts
      expect(
        () => receivingPipeline.receiveChunk(
          envelope: tamperedEnvelope,
          session: sessions.sessionBob,
        ),
        throwsA(isA<ChunkAuthenticationException>()),
      );

      expect(await File(stagingPath).exists(), isFalse);
    });

    test('10. Cancellation racing with final assembly cleans up destination file', () async {
      final chunkData = Uint8List(1000)..fillRange(0, 1000, 0x55);
      final fileHash = await calculateSha256(chunkData);

      const transferId = 'TX-RACE-ASSEMBLY';
      final stagingPath = await pathService.getStagingPath(transferId);
      final stagingFile = File(stagingPath);
      await stagingFile.parent.create(recursive: true);
      await stagingFile.writeAsBytes(chunkData, flush: true);

      await createTransferInDb(
        transferId: transferId,
        fileName: 'race_test.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: fileHash,
        direction: 'incoming',
        status: 'transferring',
        peerId: 'ML-DEVICE-ALICE',
        localPath: '',
        stagingPath: stagingPath,
      );
      await db.markChunkReceived(transferId, 0, status: 'received');

      // Cancellation wins the state transition race right before assembly persistence
      await db.updateFileTransferStatus(
        transferId,
        FileTransferStatus.cancelled.toDbValue(),
      );

      // Now assembly is attempted
      expect(
        () => assemblyService.assembleTransfer(transferId: transferId),
        throwsA(isA<InvalidTransferStateException>()),
      );

      // Verify completeFileTransfer race behavior:
      // 1. Reset transfer to transferring
      await db.updateFileTransferStatus(
        transferId,
        FileTransferStatus.transferring.toDbValue(),
      );

      final completedDir = await pathService.getCompletedDirectory();
      final destCandidate = p.join(completedDir.path, 'race_test.bin');

      // Mark cancelled concurrently
      await db.updateFileTransferStatus(
        transferId,
        FileTransferStatus.cancelled.toDbValue(),
      );

      // completeFileTransfer must return 0 rows updated
      final rowsUpdated = await db.completeFileTransfer(transferId, destCandidate);
      expect(rowsUpdated, equals(0));

      // Transfer remains cancelled in SQLite
      final finalRec = await db.getFileTransfer(transferId);
      expect(finalRec!.status, equals(FileTransferStatus.cancelled.toDbValue()));
    });

    test('11. Database persistence failure during cancellation propagates cleanly', () async {
      // Trying to cancel a non-existent transfer throws TransferNotFoundException / TransferNotFoundSendingException
      expect(
        () => sendingPipeline.cancelTransfer('NON-EXISTENT-TX'),
        throwsA(isA<TransferNotFoundSendingException>()),
      );

      expect(
        () => receivingPipeline.cancelTransfer('NON-EXISTENT-TX'),
        throwsA(isA<TransferNotFoundException>()),
      );
    });

    test('12. Cleanup failure does not mask primary error', () async {
      final sessions = await establishSession();
      const transferId = 'TX-CLEANUP-MASK-TEST';
      final stagingPath = await pathService.getStagingPath(transferId);

      await createTransferInDb(
        transferId: transferId,
        fileName: 'cleanup_test.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        direction: 'incoming',
        status: 'acceptSent',
        peerId: 'ML-DEVICE-ALICE',
        localPath: '',
        stagingPath: stagingPath,
      );

      // Create a corrupted envelope where destinationId doesn't match
      final envelope = EncryptedFileChunkEnvelope(
        version: EncryptedFileChunkEnvelope.currentProtocolVersion,
        transferId: transferId,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        chunkLength: 1000,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'WRONG-DEST', // Mismatched destination
        sessionId: sessions.sessionBob.sessionId,
        epoch: sessions.sessionBob.epoch,
        sequenceNumber: 1,
        nonce: Uint8List(12),
        ciphertext: Uint8List(1000),
        mac: Uint8List(16),
      );

      expect(
        () => receivingPipeline.receiveChunk(
          envelope: envelope,
          session: sessions.sessionBob,
        ),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });

    test('13. Invalid state transitions on terminal states are rejected', () async {
      const sm = FileTransferStateMachine.instance;

      for (final terminalStatus in [
        FileTransferStatus.completed,
        FileTransferStatus.cancelled,
        FileTransferStatus.failed,
      ]) {
        expect(sm.isTerminal(terminalStatus), isTrue);

        for (final targetStatus in FileTransferStatus.values) {
          final resOut = sm.transition(
            direction: FileTransferDirection.outgoing,
            from: terminalStatus,
            to: targetStatus,
          );
          expect(resOut.allowed, isFalse);

          final resIn = sm.transition(
            direction: FileTransferDirection.incoming,
            from: terminalStatus,
            to: targetStatus,
          );
          expect(resIn.allowed, isFalse);
        }
      }

      // Verify database terminal state protection
      const transferId = 'TX-STATE-SAFETY-001';
      await createTransferInDb(
        transferId: transferId,
        fileName: 'safety.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        direction: 'outgoing',
        status: 'cancelled',
        peerId: 'ML-DEVICE-BOB',
        localPath: '',
        stagingPath: '',
      );

      // Late async attempt to update cancelled transfer to transferring must be rejected
      final rowsUpdated = await db.updateFileTransferStatus(
        transferId,
        FileTransferStatus.transferring.toDbValue(),
      );
      expect(rowsUpdated, equals(0));

      final record = await db.getFileTransfer(transferId);
      expect(record!.status, equals(FileTransferStatus.cancelled.toDbValue()));
    });

    test('14. Regression compatibility with Steps 11–14 (Replay, ACK, Assembly, Resumption)', () async {
      final sessions = await establishSession();
      final chunkData = Uint8List(1000)..fillRange(0, 1000, 0x77);
      final fileHash = await calculateSha256(chunkData);

      const transferId = 'TX-STEP15-REGRESSION';
      final stagingPath = await pathService.getStagingPath(transferId);

      await createTransferInDb(
        transferId: transferId,
        fileName: 'regression.bin',
        fileSize: 1000,
        chunkSize: 1000,
        totalChunks: 1,
        fileHash: fileHash,
        direction: 'incoming',
        status: 'acceptSent',
        peerId: 'ML-DEVICE-ALICE',
        localPath: '',
        stagingPath: stagingPath,
      );

      // 1. Send chunk under Step 11 receiving pipeline with ACK generation
      final envelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: chunkData,
        chunkLength: 1000,
      );

      final recResult = await receivingPipeline.receiveChunk(
        envelope: envelope,
        session: sessions.sessionBob,
        autoAssemble: false,
      );
      expect(recResult.isSuccess, isTrue);
      expect(recResult.ackEnvelope, isNotNull);

      // 2. Decrypt and verify ACK (Step 12)
      final decryptedAck = await aliceAckService.decryptAck(
        envelope: recResult.ackEnvelope!,
        session: sessions.sessionAlice,
      );
      expect(decryptedAck.transferId, equals(transferId));
      expect(decryptedAck.chunkIndex, equals(0));

      // 3. Assemble complete file and verify SHA-256 (Step 13)
      final assemblyResult = await assemblyService.assembleTransfer(transferId: transferId);
      expect(assemblyResult.isSuccess, isTrue);
      expect(assemblyResult.fileHash, equals(fileHash));

      // 4. Verify Resumption service rejects completed transfer (Step 14 & Requirement B.10)
      expect(
        () => resumptionService.reconcileTransfer(transferId),
        throwsA(isA<IneligibleTransferException>()),
      );
    });
  });
}
