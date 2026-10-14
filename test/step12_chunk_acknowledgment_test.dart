import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_stream_reader.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;

  // Alice (Sender)
  late AppDatabase aliceDb;
  late DriftMessageRepository aliceRepo;
  late ReplayProtectionService aliceReplay;
  late MeshIdentityService aliceIdentity;
  late EphemeralSessionService aliceSessionService;
  late HandshakeService aliceHandshake;
  late ChunkSendingPipeline aliceSendingPipeline;
  late ChunkAckService aliceAckService;

  // Bob (Receiver)
  late AppDatabase bobDb;
  late DriftMessageRepository bobRepo;
  late ReplayProtectionService bobReplay;
  late MeshIdentityService bobIdentity;
  late EphemeralSessionService bobSessionService;
  late HandshakeService bobHandshake;
  late ChunkReceivingPipeline bobReceivingPipeline;
  late ChunkAckService bobAckService;

  late DirectionalSessionEncryptionService directionalService;
  late FileTransferCryptoService cryptoService;
  late FilePathService bobPathService;

  final testNow = DateTime.utc(2026, 10, 12, 14, 0, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step12_test_');

    // Setup Alice
    aliceDb = AppDatabase(NativeDatabase.memory());
    aliceRepo = DriftMessageRepository(aliceDb);
    aliceReplay = ReplayProtectionService(repository: aliceRepo);
    aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    await aliceIdentity.initialize();
    aliceSessionService = EphemeralSessionService(clock: () => testNow);
    aliceHandshake = HandshakeService(
      identityService: aliceIdentity,
      localId: 'ML-DEVICE-ALICE',
      sessionService: aliceSessionService,
    );

    // Setup Bob
    bobDb = AppDatabase(NativeDatabase.memory());
    bobRepo = DriftMessageRepository(bobDb);
    bobReplay = ReplayProtectionService(repository: bobRepo);
    bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    await bobIdentity.initialize();
    bobSessionService = EphemeralSessionService(clock: () => testNow);
    bobHandshake = HandshakeService(
      identityService: bobIdentity,
      localId: 'ML-DEVICE-BOB',
      sessionService: bobSessionService,
    );

    directionalService = DirectionalSessionEncryptionService();
    cryptoService = FileTransferCryptoService(encryptionService: directionalService);
    bobPathService = FilePathService(baseDirectory: tempDir);

    aliceAckService = ChunkAckService(
      localDeviceId: 'ML-DEVICE-ALICE',
      database: aliceDb,
      messageRepository: aliceRepo,
      replayProtectionService: aliceReplay,
      encryptionService: directionalService,
    );

    bobAckService = ChunkAckService(
      localDeviceId: 'ML-DEVICE-BOB',
      database: bobDb,
      messageRepository: bobRepo,
      replayProtectionService: bobReplay,
      encryptionService: directionalService,
    );

    aliceSendingPipeline = ChunkSendingPipeline(
      localDeviceId: 'ML-DEVICE-ALICE',
      streamReader: FileStreamReader(),
      cryptoService: cryptoService,
      database: aliceDb,
      messageRepository: aliceRepo,
    );

    bobReceivingPipeline = ChunkReceivingPipeline(
      localDeviceId: 'ML-DEVICE-BOB',
      database: bobDb,
      messageRepository: bobRepo,
      replayProtectionService: bobReplay,
      cryptoService: cryptoService,
      pathService: bobPathService,
      ackService: bobAckService,
    );
  });

  tearDown(() async {
    await bobReceivingPipeline.closeAll();
    await aliceDb.close();
    await bobDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<({EphemeralSession sessionAlice, EphemeralSession sessionBob})> establishSession({
    String requestId = 'REQ-STEP12-001',
  }) async {
    final request = await aliceHandshake.createKeyRequest(
      destinationId: 'ML-DEVICE-BOB',
      requestId: requestId,
    );
    final verifiedReq = await bobHandshake.verifyKeyRequest(request);
    final response = await bobHandshake.createKeyResponse(request: request);
    final sessionBob = await bobHandshake.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: testNow,
    );
    final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
    final sessionAlice = await aliceHandshake.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: testNow,
    );
    return (sessionAlice: sessionAlice, sessionBob: sessionBob);
  }

  Future<File> createTestFile(String name, int size) async {
    final file = File(p.join(tempDir.path, name));
    final bytes = Uint8List(size);
    for (var i = 0; i < size; i++) {
      bytes[i] = (i ^ (i >> 8)) & 0xFF;
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<FileTransfer> createSenderTransferRecord({
    String transferId = 'XFER-STEP12-001',
    String fileName = 'test.bin',
    int fileSize = 32768,
    int chunkSize = 16384,
    int totalChunks = 2,
    FileTransferStatus status = FileTransferStatus.acceptReceived,
    required String filePath,
  }) async {
    final companion = FileTransfersTableCompanion.insert(
      transferId: transferId,
      conversationId: 'CONV-STEP12-001',
      peerId: 'ML-DEVICE-BOB',
      direction: FileTransferDirection.outgoing.name,
      fileName: fileName,
      fileSize: BigInt.from(fileSize),
      mimeType: 'application/octet-stream',
      fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      localPath: filePath,
      stagingPath: p.join(tempDir.path, 'staging', transferId),
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      status: status.name,
      createdAt: testNow,
      updatedAt: testNow,
    );
    await aliceDb.into(aliceDb.fileTransfersTable).insert(companion);
    final entry = (await aliceDb.getFileTransfer(transferId))!;
    return FileTransfer.fromEntry(entry);
  }

  Future<FileTransfer> createReceiverTransferRecord({
    String transferId = 'XFER-STEP12-001',
    String fileName = 'test.bin',
    int fileSize = 32768,
    int chunkSize = 16384,
    int totalChunks = 2,
    FileTransferStatus status = FileTransferStatus.acceptSent,
  }) async {
    final staging = await bobPathService.getStagingPath(transferId);
    final companion = FileTransfersTableCompanion.insert(
      transferId: transferId,
      conversationId: 'CONV-STEP12-001',
      peerId: 'ML-DEVICE-ALICE',
      direction: FileTransferDirection.incoming.name,
      fileName: fileName,
      fileSize: BigInt.from(fileSize),
      mimeType: 'application/octet-stream',
      fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      localPath: p.join(tempDir.path, fileName),
      stagingPath: staging,
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      status: status.name,
      createdAt: testNow,
      updatedAt: testNow,
    );
    await bobDb.into(bobDb.fileTransfersTable).insert(companion);
    final entry = (await bobDb.getFileTransfer(transferId))!;
    return FileTransfer.fromEntry(entry);
  }

  group('Requirement 1: Typed acknowledgment protocol & cryptographic verification', () {
    test('1.1 Binary serialization round-trip for positive ACK and NACK', () {
      final ack = ChunkAcknowledgment(
        transferId: 'XFER-100',
        chunkIndex: 3,
        totalChunks: 10,
        ackType: ChunkAckType.ack,
        originId: 'ML-BOB',
        destinationId: 'ML-ALICE',
        sessionId: 'SESSION-01',
        epoch: 2,
        sequenceNumber: 42,
        createdAt: DateTime.utc(2026, 10, 12, 10, 0, 0),
      );

      final bytes = ack.toBytes();
      final decoded = ChunkAcknowledgment.fromBytes(bytes);

      expect(decoded.transferId, equals('XFER-100'));
      expect(decoded.chunkIndex, equals(3));
      expect(decoded.totalChunks, equals(10));
      expect(decoded.ackType, equals(ChunkAckType.ack));
      expect(decoded.nackReason, isNull);
      expect(decoded.originId, equals('ML-BOB'));
      expect(decoded.destinationId, equals('ML-ALICE'));
      expect(decoded.sessionId, equals('SESSION-01'));
      expect(decoded.epoch, equals(2));
      expect(decoded.sequenceNumber, equals(42));
      expect(decoded.isAck, isTrue);

      final nack = ChunkAcknowledgment(
        transferId: 'XFER-200',
        chunkIndex: 5,
        totalChunks: 12,
        ackType: ChunkAckType.nack,
        nackReason: ChunkNackReason.contentConflict,
        originId: 'ML-BOB',
        destinationId: 'ML-ALICE',
        sessionId: 'SESSION-01',
        epoch: 2,
        sequenceNumber: 43,
        createdAt: DateTime.utc(2026, 10, 12, 10, 0, 1),
      );

      final nackBytes = nack.toBytes();
      final decodedNack = ChunkAcknowledgment.fromBytes(nackBytes);
      expect(decodedNack.isNack, isTrue);
      expect(decodedNack.nackReason, equals(ChunkNackReason.contentConflict));
    });

    test('1.2 Encrypted envelope serialization round-trip', () {
      final envelope = EncryptedChunkAckEnvelope(
        version: 2,
        transferId: 'XFER-100',
        originId: 'ML-BOB',
        destinationId: 'ML-ALICE',
        sessionId: 'SESSION-01',
        epoch: 1,
        sequenceNumber: 7,
        chunkIndex: 0,
        totalChunks: 5,
        ackType: ChunkAckType.ack,
        createdAt: DateTime.utc(2026, 10, 12, 12, 0, 0),
        nonce: Uint8List(12),
        mac: Uint8List(16),
        ciphertext: Uint8List.fromList([1, 2, 3, 4]),
      );

      final bytes = envelope.toBytes();
      final decoded = EncryptedChunkAckEnvelope.fromBytes(bytes);

      expect(decoded.transferId, equals('XFER-100'));
      expect(decoded.sequenceNumber, equals(7));
      expect(decoded.chunkIndex, equals(0));
      expect(decoded.totalChunks, equals(5));
      expect(decoded.ackType, equals(ChunkAckType.ack));
      expect(decoded.ciphertext, equals([1, 2, 3, 4]));
    });

    test('1.3 Tampered ciphertext or MAC is rejected with AckAuthenticationException', () async {
      final sessions = await establishSession();

      final ack = bobAckService.createAck(
        transferId: 'XFER-001',
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
      );

      final envelope = await bobAckService.encryptAck(
        ack: ack,
        session: sessions.sessionBob,
      );

      // Tamper ciphertext
      final tamperedCiphertext = Uint8List.fromList(envelope.ciphertext);
      tamperedCiphertext[0] ^= 0xFF;

      final tamperedEnvelope = envelope.copyWith(ciphertext: tamperedCiphertext);

      expect(
        () => aliceAckService.decryptAck(
          session: sessions.sessionAlice,
          envelope: tamperedEnvelope,
        ),
        throwsA(isA<AckAuthenticationException>()),
      );
    });

    test('1.4 Mismatched session ID, epoch, sender, or destination is rejected', () async {
      final sessions = await establishSession();

      final ack = bobAckService.createAck(
        transferId: 'XFER-001',
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
      );

      final envelope = await bobAckService.encryptAck(
        ack: ack,
        session: sessions.sessionBob,
      );

      // Mismatched session ID
      final badSessionEnv = envelope.copyWith(sessionId: 'WRONG-SESSION');
      expect(
        () => aliceAckService.decryptAck(
          session: sessions.sessionAlice,
          envelope: badSessionEnv,
        ),
        throwsA(isA<AckSessionMismatchException>()),
      );

      // Mismatched epoch
      final badEpochEnv = envelope.copyWith(epoch: 99);
      expect(
        () => aliceAckService.decryptAck(
          session: sessions.sessionAlice,
          envelope: badEpochEnv,
        ),
        throwsA(isA<AckSessionMismatchException>()),
      );

      // Mismatched destination (not Alice)
      final badDestEnv = envelope.copyWith(destinationId: 'ML-SOMEONE-ELSE');
      expect(
        () => aliceAckService.decryptAck(
          session: sessions.sessionAlice,
          envelope: badDestEnv,
        ),
        throwsA(isA<AckMetadataMismatchException>()),
      );

      // Mismatched origin (not Bob)
      final badOriginEnv = envelope.copyWith(originId: 'ML-IMPOSTOR');
      expect(
        () => aliceAckService.decryptAck(
          session: sessions.sessionAlice,
          envelope: badOriginEnv,
        ),
        throwsA(isA<AckSessionMismatchException>()),
      );
    });

    test('1.5 ACK rejection for unknown transfer, mismatched totalChunks, or out-of-bounds chunk index', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('ack_reject.bin', 32768);
      final transfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 32768,
        chunkSize: 16384,
        totalChunks: 2,
        status: FileTransferStatus.transferring,
      );

      // Unknown transfer
      final ackBadXfer = bobAckService.createAck(
        transferId: 'UNKNOWN-XFER-999',
        chunkIndex: 0,
        totalChunks: 2,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
      );
      await expectLater(
        () => aliceAckService.processReceivedAck(
          ack: ackBadXfer,
          session: sessions.sessionAlice,
        ),
        throwsA(isA<AckInvalidTransferException>()),
      );

      // Out-of-bounds chunk index rejected at domain model level
      expect(
        () => bobAckService.createAck(
          transferId: transfer.transferId,
          chunkIndex: 5,
          totalChunks: 2,
          destinationId: 'ML-DEVICE-ALICE',
          session: sessions.sessionBob,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Mismatched totalChunks against transfer metadata in database
      final ackBadTotal = bobAckService.createAck(
        transferId: transfer.transferId,
        chunkIndex: 0,
        totalChunks: 10,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
      );
      await expectLater(
        () => aliceAckService.processReceivedAck(
          ack: ackBadTotal,
          session: sessions.sessionAlice,
        ),
        throwsA(isA<AckMetadataMismatchException>()),
      );
    });
  });

  group('Requirement 2: Receiver integration & positive ACK generation', () {
    test('2.1 Authenticated positive ACK generated only after successful write and persistence', () async {
      final sessions = await establishSession();
      final transfer = await createReceiverTransferRecord(
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final plaintext = Uint8List(16384);
      plaintext[0] = 0xAA;

      final chunkEnvelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
        chunkLength: 16384,
      );

      final result = await bobReceivingPipeline.receiveChunk(
        envelope: chunkEnvelope,
        session: sessions.sessionBob,
      );

      expect(result.isSuccess, isTrue);
      expect(result.ackEnvelope, isNotNull);

      // Verify chunk record was persisted in database
      final chunkInDb = await bobDb.getFileChunk(transfer.transferId, 0);
      expect(chunkInDb, isNotNull);
      expect(chunkInDb!.status, equals('received'));

      // Alice decrypts the returned ACK
      final decryptedAck = await aliceAckService.decryptAck(
        session: sessions.sessionAlice,
        envelope: result.ackEnvelope!,
      );

      expect(decryptedAck.isAck, isTrue);
      expect(decryptedAck.transferId, equals(transfer.transferId));
      expect(decryptedAck.chunkIndex, equals(0));
      expect(decryptedAck.originId, equals('ML-DEVICE-BOB'));
      expect(decryptedAck.destinationId, equals('ML-DEVICE-ALICE'));
    });

    test('2.2 Authentication failure before write never produces an ACK', () async {
      final sessions = await establishSession();
      final transfer = await createReceiverTransferRecord(
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final plaintext = Uint8List(16384);

      final chunkEnvelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
        chunkLength: 16384,
      );

      // Corrupt envelope ciphertext to fail authentication before write
      final badEnvelope = chunkEnvelope.copyWith(
        ciphertext: Uint8List.fromList(chunkEnvelope.ciphertext)..first ^= 0x01,
      );

      await expectLater(
        () => bobReceivingPipeline.receiveChunk(
          envelope: badEnvelope,
          session: sessions.sessionBob,
        ),
        throwsA(isA<ChunkAuthenticationException>()),
      );

      // Verify no ACK in DB or result
      final chunkInDb = await bobDb.getFileChunk(transfer.transferId, 0);
      expect(chunkInDb, isNull);
    });

    test('2.3 Legitimate retransmission is acknowledged idempotently', () async {
      final sessions = await establishSession();
      final transfer = await createReceiverTransferRecord(
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final plaintext = Uint8List(16384);

      // First transmission with sequence number N
      final chunkEnv1 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
        chunkLength: 16384,
      );

      final result1 = await bobReceivingPipeline.receiveChunk(
        envelope: chunkEnv1,
        session: sessions.sessionBob,
      );
      expect(result1.isSuccess, isTrue);
      expect(result1.isDuplicate, isFalse);

      // Retransmission with fresh sequence number N+1 (since session sequence advances)
      final chunkEnv2 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
        chunkLength: 16384,
      );

      final result2 = await bobReceivingPipeline.receiveChunk(
        envelope: chunkEnv2,
        session: sessions.sessionBob,
      );
      expect(result2.isSuccess, isTrue);
      expect(result2.isDuplicate, isTrue);
      expect(result2.ackEnvelope, isNotNull);
      expect(result2.chunksReceived, equals(1)); // No double counting!
    });

    test('2.4 Receiver disk write failure never produces a successful ACK', () async {
      final sessions = await establishSession();
      // Insert transfer with unauthorized staging path
      final badTransferCompanion = FileTransfersTableCompanion.insert(
        transferId: 'XFER-BAD-DISK-001',
        conversationId: 'CONV-STEP12-001',
        peerId: 'ML-DEVICE-ALICE',
        direction: FileTransferDirection.incoming.name,
        fileName: 'bad_disk.bin',
        fileSize: BigInt.from(16384),
        mimeType: 'application/octet-stream',
        fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        localPath: p.join(tempDir.path, 'bad_disk.bin'),
        stagingPath: 'D:\\unauthorized_path_outside_sandbox\\bad.staging',
        totalChunks: 1,
        chunkSize: 16384,
        status: FileTransferStatus.acceptSent.name,
        createdAt: testNow,
        updatedAt: testNow,
      );
      await bobDb.into(bobDb.fileTransfersTable).insert(badTransferCompanion);

      final plaintext = Uint8List(16384);
      final chunkEnvelope = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'XFER-BAD-DISK-001',
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
        chunkLength: 16384,
      );

      await expectLater(
        () => bobReceivingPipeline.receiveChunk(
          envelope: chunkEnvelope,
          session: sessions.sessionBob,
        ),
        throwsA(isA<ChunkDiskWriteException>()),
      );

      // Verify no chunk record was marked as received in Bob's DB
      final chunkInDb = await bobDb.getFileChunk('XFER-BAD-DISK-001', 0);
      expect(chunkInDb, isNull);
    });
  });

  group('Requirement 3: Sender integration, bounded wait, timeout, and retry', () {
    test('3.1 Full pipeline: Sender waits for and receives positive ACK', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('alice_source.bin', 32768);

      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 32768,
        chunkSize: 16384,
        totalChunks: 2,
      );
      await createReceiverTransferRecord(
        fileSize: 32768,
        chunkSize: 16384,
        totalChunks: 2,
      );

      final ackTracker = ChunkAckTracker();

      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        // Direct local handoff to Bob's receiving pipeline
        final receiveResult = await bobReceivingPipeline.receiveChunk(
          envelope: chunkEnvelope,
          session: sessions.sessionBob,
        );

        if (receiveResult.ackEnvelope != null) {
          // Bob sends ACK back to Alice
          final decryptedAck = await aliceAckService.decryptAck(
            session: sessions.sessionAlice,
            envelope: receiveResult.ackEnvelope!,
          );
          ackTracker.onAckReceived(decryptedAck);
        }
        return true;
      });

      final sendResult = await aliceSendingPipeline.sendTransfer(
        transfer: senderTransfer,
        session: sessions.sessionAlice,
        transportSender: transport,
        ackTracker: ackTracker,
        ackService: aliceAckService,
        policy: const ChunkSendingPolicy(
          waitForAcks: true,
          ackTimeout: Duration(seconds: 2),
        ),
      );

      expect(sendResult.isSuccess, isTrue);
      expect(sendResult.chunksSent, equals(2));

      // Check Alice's database: both chunks should be marked 'acked'
      final ackedCount = await aliceAckService.getAckedChunkCount(senderTransfer.transferId);
      expect(ackedCount, equals(2));
      expect(await aliceAckService.areAllChunksAcked(senderTransfer.transferId), isTrue);

      // Verify transfer NEVER becomes completed in Step 12
      final updatedSenderTransfer = await aliceDb.getFileTransfer(senderTransfer.transferId);
      expect(updatedSenderTransfer!.status, equals(FileTransferStatus.transferring.name));
    });

    test('3.2 Timeout and retry exhaustion triggers ChunkAckTimeoutException', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('timeout_source.bin', 16384);

      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final ackTracker = ChunkAckTracker();
      var attempts = 0;

      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        attempts++;
        // Drop all ACKs (never respond)
        return true;
      });

      await expectLater(
        () => aliceSendingPipeline.sendTransfer(
          transfer: senderTransfer,
          session: sessions.sessionAlice,
          transportSender: transport,
          ackTracker: ackTracker,
          policy: const ChunkSendingPolicy(
            waitForAcks: true,
            ackTimeout: Duration(milliseconds: 50),
            maxRetries: 3,
          ),
        ),
        throwsA(isA<ChunkAckTimeoutException>()),
      );

      expect(attempts, equals(3));
      final ackedCount = await aliceAckService.getAckedChunkCount(senderTransfer.transferId);
      expect(ackedCount, equals(0));
    });

    test('3.3 Recovered retry on lost ACK completes successfully', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('retry_source.bin', 16384);

      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );
      await createReceiverTransferRecord(
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final ackTracker = ChunkAckTracker();
      var sendAttempts = 0;

      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        sendAttempts++;
        final receiveResult = await bobReceivingPipeline.receiveChunk(
          envelope: chunkEnvelope,
          session: sessions.sessionBob,
        );

        if (sendAttempts == 1) {
          // Drop the first ACK to simulate lost packet in transit
          return true;
        }

        // Second attempt delivers the ACK
        if (receiveResult.ackEnvelope != null) {
          final decryptedAck = await aliceAckService.decryptAck(
            session: sessions.sessionAlice,
            envelope: receiveResult.ackEnvelope!,
          );
          ackTracker.onAckReceived(decryptedAck);
        }
        return true;
      });

      final result = await aliceSendingPipeline.sendTransfer(
        transfer: senderTransfer,
        session: sessions.sessionAlice,
        transportSender: transport,
        ackTracker: ackTracker,
        ackService: aliceAckService,
        policy: const ChunkSendingPolicy(
          waitForAcks: true,
          ackTimeout: Duration(milliseconds: 100),
          maxRetries: 3,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(sendAttempts, equals(2));
      expect(await aliceAckService.getAckedChunkCount(senderTransfer.transferId), equals(1));
    });

    test('3.4 Cancellation during ACK waiting promptly terminates without hanging', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('cancel_source.bin', 16384);

      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final ackTracker = ChunkAckTracker();
      final cancellationToken = FileTransferCancellationToken();

      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        // Trigger cancellation immediately after transport handoff
        cancellationToken.cancel('User aborted');
        return true;
      });

      await expectLater(
        () => aliceSendingPipeline.sendTransfer(
          transfer: senderTransfer,
          session: sessions.sessionAlice,
          transportSender: transport,
          ackTracker: ackTracker,
          cancellationToken: cancellationToken,
          policy: const ChunkSendingPolicy(
            waitForAcks: true,
            ackTimeout: Duration(seconds: 10),
          ),
        ),
        throwsA(isA<ChunkSendCancelledException>()),
      );
    });

    test('3.5 NACK received terminates send with ChunkNackReceivedException', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('nack_source.bin', 16384);

      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final ackTracker = ChunkAckTracker();

      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        // Receiver simulates generating a NACK (e.g. disk storage failure)
        final nack = bobAckService.createNack(
          transferId: chunkEnvelope.transferId,
          chunkIndex: chunkEnvelope.chunkIndex,
          totalChunks: chunkEnvelope.totalChunks,
          destinationId: 'ML-DEVICE-ALICE',
          session: sessions.sessionBob,
          reason: ChunkNackReason.storageFailure,
        );
        ackTracker.onAckReceived(nack);
        return true;
      });

      await expectLater(
        () => aliceSendingPipeline.sendTransfer(
          transfer: senderTransfer,
          session: sessions.sessionAlice,
          transportSender: transport,
          ackTracker: ackTracker,
          ackService: aliceAckService,
          policy: const ChunkSendingPolicy(waitForAcks: true),
        ),
        throwsA(
          isA<ChunkNackReceivedException>().having(
            (e) => e.reason,
            'reason',
            equals(ChunkNackReason.storageFailure),
          ),
        ),
      );
    });

    test('3.6 Bounded in-flight window enforces backpressure while waiting for ACKs', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('inflight_source.bin', 49152);
      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 49152,
        chunkSize: 16384,
        totalChunks: 3,
      );
      await createReceiverTransferRecord(
        fileSize: 49152,
        chunkSize: 16384,
        totalChunks: 3,
      );

      final ackTracker = ChunkAckTracker();
      var maxObservedInFlight = 0;
      var currentInFlight = 0;

      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        currentInFlight++;
        if (currentInFlight > maxObservedInFlight) {
          maxObservedInFlight = currentInFlight;
        }

        final receiveResult = await bobReceivingPipeline.receiveChunk(
          envelope: chunkEnvelope,
          session: sessions.sessionBob,
        );

        if (receiveResult.ackEnvelope != null) {
          final decryptedAck = await aliceAckService.decryptAck(
            session: sessions.sessionAlice,
            envelope: receiveResult.ackEnvelope!,
          );
          currentInFlight--;
          ackTracker.onAckReceived(decryptedAck);
        }
        return true;
      });

      final result = await aliceSendingPipeline.sendTransfer(
        transfer: senderTransfer,
        session: sessions.sessionAlice,
        transportSender: transport,
        ackTracker: ackTracker,
        ackService: aliceAckService,
        policy: const ChunkSendingPolicy(
          waitForAcks: true,
          maxInFlightChunks: 1,
          ackTimeout: Duration(seconds: 2),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.chunksSent, equals(3));
      expect(maxObservedInFlight, equals(1));
      expect(await aliceAckService.getAckedChunkCount(senderTransfer.transferId), equals(3));
    });

    test('3.7 Lost ACK followed by fresh-sequence retransmission and delayed duplicate ACK', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('lost_ack_dup.bin', 16384);
      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );
      await createReceiverTransferRecord(
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final ackTracker = ChunkAckTracker();
      ChunkAcknowledgment? delayedFirstAck;
      var attempt = 0;

      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        attempt++;
        final receiveResult = await bobReceivingPipeline.receiveChunk(
          envelope: chunkEnvelope,
          session: sessions.sessionBob,
        );

        if (attempt == 1) {
          delayedFirstAck = await aliceAckService.decryptAck(
            session: sessions.sessionAlice,
            envelope: receiveResult.ackEnvelope!,
          );
          return true; // Simulate lost/delayed ACK
        }

        if (receiveResult.ackEnvelope != null) {
          final freshAck = await aliceAckService.decryptAck(
            session: sessions.sessionAlice,
            envelope: receiveResult.ackEnvelope!,
          );
          ackTracker.onAckReceived(freshAck);
        }
        return true;
      });

      final result = await aliceSendingPipeline.sendTransfer(
        transfer: senderTransfer,
        session: sessions.sessionAlice,
        transportSender: transport,
        ackTracker: ackTracker,
        ackService: aliceAckService,
        policy: const ChunkSendingPolicy(
          waitForAcks: true,
          ackTimeout: Duration(milliseconds: 100),
          maxRetries: 3,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(attempt, equals(2));
      expect(await aliceAckService.getAckedChunkCount(senderTransfer.transferId), equals(1));

      expect(delayedFirstAck, isNotNull);
      final delayedAckResult = await aliceAckService.processReceivedAck(
        ack: delayedFirstAck!,
        session: sessions.sessionAlice,
      );

      expect(delayedAckResult.isSuccess, isTrue);
      expect(delayedAckResult.isDuplicate, isTrue);
      expect(await aliceAckService.getAckedChunkCount(senderTransfer.transferId), equals(1));
    });
  });

  group('Requirement 4: Persistence, idempotency, and concurrency', () {
    test('4.1 Duplicate valid ACK handling is idempotent without double counting', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('idem_source.bin', 16384);
      final transfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
        status: FileTransferStatus.transferring,
      );

      final ack = bobAckService.createAck(
        transferId: transfer.transferId,
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
      );

      // Process ACK first time
      final result1 = await aliceAckService.processReceivedAck(
        ack: ack,
        session: sessions.sessionAlice,
      );
      expect(result1.isSuccess, isTrue);
      expect(result1.isDuplicate, isFalse);

      var ackedCount = await aliceAckService.getAckedChunkCount(transfer.transferId);
      expect(ackedCount, equals(1));

      // Process duplicate ACK (e.g. packet re-delivered by transport)
      final result2 = await aliceAckService.processReceivedAck(
        ack: ack,
        session: sessions.sessionAlice,
      );
      expect(result2.isSuccess, isTrue);
      expect(result2.isDuplicate, isTrue);

      ackedCount = await aliceAckService.getAckedChunkCount(transfer.transferId);
      expect(ackedCount, equals(1)); // Still 1, no double counting!
    });

    test('4.2 Replayed exact ACK packet rejected by Phase 7 replay protection', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('replay_source.bin', 16384);
      final transfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
        status: FileTransferStatus.transferring,
      );

      final ack = bobAckService.createAck(
        transferId: transfer.transferId,
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
        sequenceNumber: 10,
      );

      // First time
      final res1 = await aliceAckService.processReceivedAck(
        ack: ack,
        session: sessions.sessionAlice,
      );
      expect(res1.isSuccess, isTrue);

      // Second time with identical packet ID returns duplicate result
      final res2 = await aliceAckService.processReceivedAck(
        ack: ack,
        session: sessions.sessionAlice,
      );
      expect(res2.isDuplicate, isTrue);
    });

    test('4.3 Concurrent ACK processing updates distinct chunks safely', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('conc_source.bin', 65536);
      final transfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 65536,
        chunkSize: 16384,
        totalChunks: 4,
        status: FileTransferStatus.transferring,
      );

      final acks = List.generate(4, (i) {
        return bobAckService.createAck(
          transferId: transfer.transferId,
          chunkIndex: i,
          totalChunks: 4,
          destinationId: 'ML-DEVICE-ALICE',
          session: sessions.sessionBob,
          sequenceNumber: 100 + i,
        );
      });

      // Process all 4 ACKs concurrently
      final results = await Future.wait(
        acks.map((ack) => aliceAckService.processReceivedAck(
              ack: ack,
              session: sessions.sessionAlice,
            )),
      );

      for (final r in results) {
        expect(r.isSuccess, isTrue);
        expect(r.isDuplicate, isFalse);
      }

      final ackedIndices = await aliceAckService.getAckedChunkIndices(transfer.transferId);
      expect(ackedIndices.length, equals(4));
      expect(ackedIndices, containsAll([0, 1, 2, 3]));
    });

    test('4.4 Out-of-order ACKs are accepted without error', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('ooo_source.bin', 32768);
      final transfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 32768,
        chunkSize: 16384,
        totalChunks: 2,
        status: FileTransferStatus.transferring,
      );

      final ack1 = bobAckService.createAck(
        transferId: transfer.transferId,
        chunkIndex: 1,
        totalChunks: 2,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
        sequenceNumber: 101,
      );
      final ack0 = bobAckService.createAck(
        transferId: transfer.transferId,
        chunkIndex: 0,
        totalChunks: 2,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
        sequenceNumber: 102,
      );

      // Process chunk 1 before chunk 0
      final res1 = await aliceAckService.processReceivedAck(
        ack: ack1,
        session: sessions.sessionAlice,
      );
      expect(res1.isSuccess, isTrue);

      final res0 = await aliceAckService.processReceivedAck(
        ack: ack0,
        session: sessions.sessionAlice,
      );
      expect(res0.isSuccess, isTrue);

      final ackedIndices = await aliceAckService.getAckedChunkIndices(transfer.transferId);
      expect(ackedIndices, containsAll([0, 1]));
    });
  });

  group('Requirement 5: Security constraints & peer trust', () {
    test('5.1 Compromised peer ACK is rejected with AckAuthenticationException', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('sec_source.bin', 16384);
      await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
        status: FileTransferStatus.transferring,
      );

      // Mark Bob as compromised in Alice's repository
      await aliceRepo.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-DEVICE-BOB',
          identityPublicKey: 'mock-identity-key',
          safetyNumber: '123456',
          trustStatus: 'compromised',
          protocolVersion: 2,
          firstSeenAt: testNow,
          lastSeenAt: testNow,
        ),
      );

      final ack = bobAckService.createAck(
        transferId: 'XFER-STEP12-001',
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
      );

      final envelope = await bobAckService.encryptAck(
        ack: ack,
        session: sessions.sessionBob,
      );

      expect(
        () => aliceAckService.decryptAck(
          session: sessions.sessionAlice,
          envelope: envelope,
        ),
        throwsA(isA<AckAuthenticationException>()),
      );
    });

    test('5.2 Stale timestamp on ACK rejected by replay protection', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('stale_source.bin', 16384);
      final transfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
        status: FileTransferStatus.transferring,
      );

      final staleAck = bobAckService.createAck(
        transferId: transfer.transferId,
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions.sessionBob,
        createdAt: testNow.subtract(const Duration(days: 8)), // exceeds 7 days limit
      );

      expect(
        () => aliceAckService.processReceivedAck(
          ack: staleAck,
          session: sessions.sessionAlice,
          now: testNow,
        ),
        throwsA(isA<AckReplayException>()),
      );
    });

    test('5.3 Transfer state is NEVER marked completed in Step 12', () async {
      final sessions = await establishSession();
      final sourceFile = await createTestFile('never_completed.bin', 16384);
      final senderTransfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );
      final receiverTransfer = await createReceiverTransferRecord(
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
      );

      final ackTracker = ChunkAckTracker();
      final transport = FunctionalChunkTransportSender((chunkEnvelope) async {
        final receiveResult = await bobReceivingPipeline.receiveChunk(
          envelope: chunkEnvelope,
          session: sessions.sessionBob,
        );
        if (receiveResult.ackEnvelope != null) {
          final decryptedAck = await aliceAckService.decryptAck(
            session: sessions.sessionAlice,
            envelope: receiveResult.ackEnvelope!,
          );
          ackTracker.onAckReceived(decryptedAck);
        }
        return true;
      });

      await aliceSendingPipeline.sendTransfer(
        transfer: senderTransfer,
        session: sessions.sessionAlice,
        transportSender: transport,
        ackTracker: ackTracker,
        ackService: aliceAckService,
        policy: const ChunkSendingPolicy(waitForAcks: true),
      );

      final finalSender = await aliceDb.getFileTransfer(senderTransfer.transferId);
      final finalReceiver = await bobDb.getFileTransfer(receiverTransfer.transferId);

      expect(finalSender!.status, isNot(equals(FileTransferStatus.completed.name)));
      expect(finalReceiver!.status, isNot(equals(FileTransferStatus.completed.name)));
      expect(finalSender.status, equals(FileTransferStatus.transferring.name));
      expect(finalReceiver.status, equals(FileTransferStatus.transferring.name));
    });

    test('5.4 Delayed ACK from old session or epoch is rejected', () async {
      final sessions1 = await establishSession(requestId: 'REQ-OLD');
      final sessions2 = await establishSession(requestId: 'REQ-NEW');
      final sourceFile = await createTestFile('old_session_source.bin', 16384);
      final transfer = await createSenderTransferRecord(
        filePath: sourceFile.path,
        fileSize: 16384,
        chunkSize: 16384,
        totalChunks: 1,
        status: FileTransferStatus.transferring,
      );

      // ACK generated under old session 1
      final oldAck = bobAckService.createAck(
        transferId: transfer.transferId,
        chunkIndex: 0,
        totalChunks: 1,
        destinationId: 'ML-DEVICE-ALICE',
        session: sessions1.sessionBob,
      );

      // Alice now active in session 2 tries to process old session ACK
      await expectLater(
        () => aliceAckService.processReceivedAck(
          ack: oldAck,
          session: sessions2.sessionAlice,
        ),
        throwsA(isA<AckSessionMismatchException>()),
      );
    });
  });
}
