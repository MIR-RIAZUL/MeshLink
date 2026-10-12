import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase bobDb;
  late DriftMessageRepository bobRepo;
  late ReplayProtectionService replayProtectionService;

  late MeshIdentityService aliceIdentity;
  late MeshIdentityService bobIdentity;

  late EphemeralSessionService aliceSessionService;
  late EphemeralSessionService bobSessionService;

  late HandshakeService aliceHandshake;
  late HandshakeService bobHandshake;

  late DirectionalSessionEncryptionService directionalService;
  late FileTransferCryptoService cryptoService;
  late FilePathService pathService;
  late ChunkReceivingPipeline pipeline;

  final testNow = DateTime.utc(2026, 10, 12, 12, 0, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step11_test_');

    bobDb = AppDatabase(NativeDatabase.memory());
    bobRepo = DriftMessageRepository(bobDb);
    replayProtectionService = ReplayProtectionService(repository: bobRepo);

    aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    await aliceIdentity.initialize();
    await bobIdentity.initialize();

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
    cryptoService = FileTransferCryptoService(encryptionService: directionalService);
    pathService = FilePathService(baseDirectory: tempDir);

    pipeline = ChunkReceivingPipeline(
      localDeviceId: 'ML-DEVICE-BOB',
      database: bobDb,
      messageRepository: bobRepo,
      replayProtectionService: replayProtectionService,
      cryptoService: cryptoService,
      pathService: pathService,
    );
  });

  tearDown(() async {
    await pipeline.closeAll();
    await bobDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to establish an authenticated bidirectional session between Alice and Bob.
  Future<({EphemeralSession sessionAlice, EphemeralSession sessionBob})> establishSession({
    String requestId = 'REQ-STEP11-001',
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

  /// Helper to record an incoming file transfer in Bob's database.
  Future<FileTransferEntry> createIncomingTransferRecord({
    String transferId = 'TX-STEP11-001',
    String peerId = 'ML-DEVICE-ALICE',
    String fileName = 'sample.bin',
    int fileSize = 40000,
    int chunkSize = 16384,
    int totalChunks = 3,
    FileTransferStatus status = FileTransferStatus.acceptSent,
    String? stagingPath,
  }) async {
    final staging = stagingPath ?? await pathService.getStagingPath(transferId);
    final companion = FileTransfersTableCompanion.insert(
      transferId: transferId,
      conversationId: 'CONV-STEP11-001',
      peerId: peerId,
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
    return (await bobDb.getFileTransfer(transferId))!;
  }

  /// Helper to generate deterministic test data bytes.
  Uint8List generateTestData(int size, {int seed = 0}) {
    final data = Uint8List(size);
    for (var i = 0; i < size; i++) {
      data[i] = ((i + seed) ^ ((i + seed) >> 8)) & 0xFF;
    }
    return data;
  }

  // ===========================================================================
  // Test 1: Valid encrypted chunks are decrypted and written at correct offsets
  // ===========================================================================
  group('Requirement 1: Valid encrypted chunk decryption and staging', () {
    test('1. Valid chunks are decrypted and written at correct offsets (sequential)', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(
        fileSize: 40000,
        chunkSize: 16384,
        totalChunks: 3,
      );

      final fullData = generateTestData(40000);
      final chunk0Data = fullData.sublist(0, 16384);
      final chunk1Data = fullData.sublist(16384, 32768);
      final chunk2Data = fullData.sublist(32768, 40000);

      // Alice encrypts chunk 0
      final env0 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: chunk0Data,
      );

      // Alice encrypts chunk 1
      final env1 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 3,
        offset: 16384,
        plaintext: chunk1Data,
      );

      // Alice encrypts chunk 2
      final env2 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 2,
        totalChunks: 3,
        offset: 32768,
        plaintext: chunk2Data,
      );

      // Bob receives chunk 0
      final res0 = await pipeline.receiveChunk(
        envelope: env0,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(res0.isSuccess, isTrue);
      expect(res0.chunkIndex, 0);
      expect(res0.offset, 0);
      expect(res0.bytesWritten, 16384);
      expect(res0.chunksReceived, 1);
      expect(res0.status, FileTransferStatus.transferring);

      // Bob receives chunk 1
      final res1 = await pipeline.receiveChunk(
        envelope: env1,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(res1.isSuccess, isTrue);
      expect(res1.chunkIndex, 1);
      expect(res1.offset, 16384);
      expect(res1.chunksReceived, 2);

      // Bob receives chunk 2
      final res2 = await pipeline.receiveChunk(
        envelope: env2,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(res2.isSuccess, isTrue);
      expect(res2.chunkIndex, 2);
      expect(res2.offset, 32768);
      expect(res2.chunksReceived, 3);

      // Close writer to flush all handles
      await pipeline.closeWriter(transfer.transferId);

      // Verify staged file content matches original 40,000 bytes exactly
      final stagedFile = File(transfer.stagingPath);
      expect(await stagedFile.exists(), isTrue);
      final stagedBytes = await stagedFile.readAsBytes();
      expect(stagedBytes.length, 40000);
      expect(stagedBytes, equals(fullData));

      // Verify database chunk records
      final chunksInDb = await bobDb.getFileChunks(transfer.transferId);
      expect(chunksInDb.length, 3);
      expect(chunksInDb.map((c) => c.status).toSet(), {'received'});
    });

    test('1b. Out-of-order chunk arrival correctly writes to random-access offsets', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(
        fileSize: 40000,
        chunkSize: 16384,
        totalChunks: 3,
      );

      final fullData = generateTestData(40000);
      final chunk0Data = fullData.sublist(0, 16384);
      final chunk1Data = fullData.sublist(16384, 32768);
      final chunk2Data = fullData.sublist(32768, 40000);

      final env0 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: chunk0Data,
      );
      final env1 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 3,
        offset: 16384,
        plaintext: chunk1Data,
      );
      final env2 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 2,
        totalChunks: 3,
        offset: 32768,
        plaintext: chunk2Data,
      );

      // Deliver in reverse order: Chunk 2, then Chunk 0, then Chunk 1
      await pipeline.receiveChunk(envelope: env2, session: sessions.sessionBob, now: testNow);
      await pipeline.receiveChunk(envelope: env0, session: sessions.sessionBob, now: testNow);
      await pipeline.receiveChunk(envelope: env1, session: sessions.sessionBob, now: testNow);

      await pipeline.closeWriter(transfer.transferId);

      final stagedBytes = await File(transfer.stagingPath).readAsBytes();
      expect(stagedBytes, equals(fullData));
    });
  });

  // ===========================================================================
  // Test 2: Incorrect transfer IDs and chunk indexes are rejected
  // ===========================================================================
  group('Requirement 2: Unknown transfer IDs and invalid chunk indexes', () {
    test('2a. Unknown transfer ID throws TransferNotFoundException', () async {
      final sessions = await establishSession();
      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-NON-EXISTENT-999',
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(10),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<TransferNotFoundException>()),
      );
    });

    test('2b. Chunk index >= totalChunks throws ChunkMetadataMismatchException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(totalChunks: 2, fileSize: 200);

      final validEnv = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        plaintext: Uint8List(100),
      );

      final outOfBoundsEnv = validEnv.copyWith(chunkIndex: 5);

      expect(
        () => pipeline.receiveChunk(envelope: outOfBoundsEnv, session: sessions.sessionBob),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });

    test('2c. Non-incoming (outgoing) transfer direction throws InvalidReceivingStateException', () async {
      final sessions = await establishSession();
      final outgoingCompanion = FileTransfersTableCompanion.insert(
        transferId: 'TX-OUTGOING-001',
        conversationId: 'CONV-STEP11-001',
        peerId: 'ML-DEVICE-ALICE',
        direction: FileTransferDirection.outgoing.name,
        fileName: 'out.bin',
        fileSize: BigInt.from(100),
        mimeType: 'application/octet-stream',
        fileHash: 'hash',
        localPath: p.join(tempDir.path, 'out.bin'),
        stagingPath: p.join(tempDir.path, 'out.part'),
        totalChunks: 1,
        chunkSize: 100,
        status: FileTransferStatus.transferring.name,
        createdAt: testNow,
        updatedAt: testNow,
      );
      await bobDb.into(bobDb.fileTransfersTable).insert(outgoingCompanion);

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-OUTGOING-001',
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(100),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<InvalidReceivingStateException>()),
      );
    });

    test('2d. Terminal status (cancelled/failed) throws InvalidReceivingStateException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(
        status: FileTransferStatus.cancelled,
      );

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<InvalidReceivingStateException>()),
      );
    });
  });

  // ===========================================================================
  // Test 3: Invalid offsets, lengths, and total-chunk metadata rejected
  // ===========================================================================
  group('Requirement 3: Chunk offset, length, and metadata invariants', () {
    test('3a. Offset mismatch throws ChunkMetadataMismatchException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(chunkSize: 100, fileSize: 200, totalChunks: 2);

      // Chunk 1 expected offset is 100, but envelope declares offset 50
      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 2,
        offset: 50,
        plaintext: Uint8List(100),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });

    test('3b. Chunk length mismatch throws ChunkMetadataMismatchException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(chunkSize: 100, fileSize: 200, totalChunks: 2);

      // Chunk 0 expected length is 100, but envelope has length 50
      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        plaintext: Uint8List(50),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });

    test('3c. Total chunks mismatch throws ChunkMetadataMismatchException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(totalChunks: 3);

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 5, // metadata mismatch
        offset: 0,
        plaintext: Uint8List(16384),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });

    test('3d. Chunk range exceeding total file size throws ChunkMetadataMismatchException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(fileSize: 150, chunkSize: 100, totalChunks: 2);

      // Final chunk offset 100 + length 100 = 200 > 150
      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 2,
        offset: 100,
        plaintext: Uint8List(100),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });
  });

  // ===========================================================================
  // Test 4: Authentication failures cause no plaintext disk write
  // ===========================================================================
  group('Requirement 4: Tampering and authentication failures leave zero disk artifacts', () {
    test('4a. Modified ciphertext fails decryption with zero disk write', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(fileSize: 100, chunkSize: 100, totalChunks: 1);

      final originalData = generateTestData(100);
      final validEnv = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: originalData,
      );

      final tamperedCiphertext = Uint8List.fromList(validEnv.ciphertext);
      tamperedCiphertext[0] ^= 0xFF; // tamper 1 byte

      final tamperedEnv = validEnv.copyWith(ciphertext: tamperedCiphertext);

      expect(
        () => pipeline.receiveChunk(envelope: tamperedEnv, session: sessions.sessionBob),
        throwsA(isA<ChunkAuthenticationException>()),
      );

      // Ensure no chunk record was inserted in database
      final chunk = await bobDb.getFileChunk(transfer.transferId, 0);
      expect(chunk, isNull);

      // Ensure staging file has 0 bytes written or does not exist
      final stagingFile = File(transfer.stagingPath);
      if (await stagingFile.exists()) {
        expect(await stagingFile.length(), 0);
      }
    });

    test('4b. Modified MAC tag fails authentication with zero disk write', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(fileSize: 100, chunkSize: 100, totalChunks: 1);

      final validEnv = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: generateTestData(100),
      );

      final tamperedMac = Uint8List.fromList(validEnv.mac);
      tamperedMac[5] ^= 0xAA;

      final tamperedEnv = validEnv.copyWith(mac: tamperedMac);

      expect(
        () => pipeline.receiveChunk(envelope: tamperedEnv, session: sessions.sessionBob),
        throwsA(isA<ChunkAuthenticationException>()),
      );

      expect(await bobDb.getFileChunk(transfer.transferId, 0), isNull);
    });

    test('4c. Modified nonce fails authentication with zero disk write', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(fileSize: 100, chunkSize: 100, totalChunks: 1);

      final validEnv = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: generateTestData(100),
      );

      final tamperedNonce = Uint8List.fromList(validEnv.nonce);
      tamperedNonce[0] ^= 0x01;

      final tamperedEnv = validEnv.copyWith(nonce: tamperedNonce);

      expect(
        () => pipeline.receiveChunk(envelope: tamperedEnv, session: sessions.sessionBob),
        throwsA(isA<ChunkAuthenticationException>()),
      );

      expect(await bobDb.getFileChunk(transfer.transferId, 0), isNull);
    });
  });

  // ===========================================================================
  // Test 5: Untrusted peers and destroyed sessions are rejected
  // ===========================================================================
  group('Requirement 5: Peer trust and session lifecycle enforcement', () {
    test('5a. Compromised peer is rejected before decryption or write', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      // Mark Alice as compromised in Bob's repository
      await bobRepo.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-DEVICE-ALICE',
          identityPublicKey: 'alice_pubkey',
          safetyNumber: '12345',
          trustStatus: 'compromised',
          protocolVersion: 2,
          firstSeenAt: testNow,
          lastSeenAt: testNow,
        ),
      );

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<PeerUntrustedReceivingException>()),
      );
    });

    test('5b. Unverified peer is rejected when requireVerifiedPeer is enabled', () async {
      final verifiedPipeline = ChunkReceivingPipeline(
        localDeviceId: 'ML-DEVICE-BOB',
        database: bobDb,
        messageRepository: bobRepo,
        cryptoService: cryptoService,
        pathService: pathService,
        requireVerifiedPeer: true,
      );

      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      // Alice is tofu_unverified
      await bobRepo.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-DEVICE-ALICE',
          identityPublicKey: 'alice_pubkey',
          safetyNumber: '12345',
          trustStatus: 'tofu_unverified',
          protocolVersion: 2,
          firstSeenAt: testNow,
          lastSeenAt: testNow,
        ),
      );

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      expect(
        () => verifiedPipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<PeerUntrustedReceivingException>()),
      );
    });

    test('5c. Destroyed session is rejected immediately', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      // Destroy Bob's session
      sessions.sessionBob.destroy();

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<SessionMismatchException>()),
      );
    });

    test('5d. Session ID or epoch mismatch is rejected', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      final wrongSessionEnv = env.copyWith(sessionId: 'WRONG-SESSION-ID');

      expect(
        () => pipeline.receiveChunk(envelope: wrongSessionEnv, session: sessions.sessionBob),
        throwsA(isA<SessionMismatchException>()),
      );
    });
  });

  // ===========================================================================
  // Test 6: Replayed or stale session messages handled according to Phase 7
  // ===========================================================================
  group('Requirement 6: Persistent Phase 7 replay and stale message defense', () {
    test('6a. Stale message older than 7 days is rejected by replay protection', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      // Packet timestamp 8 days in the past
      final staleTimestamp = testNow.subtract(const Duration(days: 8));

      expect(
        () => pipeline.receiveChunk(
          envelope: env,
          session: sessions.sessionBob,
          packetTimestamp: staleTimestamp,
          now: testNow,
        ),
        throwsA(
          isA<ChunkReplayException>().having(
            (e) => e.validationResult,
            'validationResult',
            ReplayValidationResult.expired,
          ),
        ),
      );
    });

    test('6b. Packet with future skew (> 1 hour) is rejected', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      // Packet timestamp 2 hours in the future
      final futureTimestamp = testNow.add(const Duration(hours: 2));

      expect(
        () => pipeline.receiveChunk(
          envelope: env,
          session: sessions.sessionBob,
          packetTimestamp: futureTimestamp,
          now: testNow,
        ),
        throwsA(
          isA<ChunkReplayException>().having(
            (e) => e.validationResult,
            'validationResult',
            ReplayValidationResult.futureTimestamp,
          ),
        ),
      );
    });

    test('6c. Replayed exact session message is rejected by Phase 7 replay protection', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      // First delivery succeeds
      final firstRes = await pipeline.receiveChunk(
        envelope: env,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(firstRes.isSuccess, isTrue);

      // Replaying the exact same envelope (same sequence number) is rejected
      expect(
        () => pipeline.receiveChunk(
          envelope: env,
          session: sessions.sessionBob,
          now: testNow,
        ),
        throwsA(
          isA<ChunkReplayException>().having(
            (e) => e.validationResult,
            'validationResult',
            ReplayValidationResult.duplicate,
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // Test 7: Duplicate valid chunk delivery does not corrupt staging file
  // ===========================================================================
  group('Requirement 7: Idempotent duplicate chunk handling', () {
    test('7. Repeated valid chunk delivery with fresh sequence number is handled idempotently without file corruption', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(
        fileSize: 40000,
        chunkSize: 16384,
        totalChunks: 3,
      );

      final chunk0Data = generateTestData(16384);

      // Initial transmission of Chunk 0 (sequenceNumber 0)
      final env0First = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: chunk0Data,
      );

      final resFirst = await pipeline.receiveChunk(
        envelope: env0First,
        session: sessions.sessionBob,
        now: testNow,
      );
      expect(resFirst.isSuccess, isTrue);
      expect(resFirst.isDuplicate, isFalse);
      expect(resFirst.bytesWritten, 16384);
      expect(resFirst.chunksReceived, 1);

      // Sender retransmits Chunk 0 (new session message, sequenceNumber 1)
      final env0Retransmit = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: chunk0Data, // Identical data
      );

      final resRetransmit = await pipeline.receiveChunk(
        envelope: env0Retransmit,
        session: sessions.sessionBob,
        now: testNow,
      );

      // Handled idempotently!
      expect(resRetransmit.isSuccess, isTrue);
      expect(resRetransmit.isDuplicate, isTrue);
      expect(resRetransmit.bytesWritten, 0); // No double write
      expect(resRetransmit.chunksReceived, 1); // No double progress

      await pipeline.closeWriter(transfer.transferId);

      // Staging file content remains completely intact
      final stagedBytes = await File(transfer.stagingPath).readAsBytes();
      expect(stagedBytes.sublist(0, 16384), equals(chunk0Data));
    });
  });

  // ===========================================================================
  // Test 8: Conflicting duplicate content is rejected safely
  // ===========================================================================
  group('Requirement 8: Conflicting duplicate content defense', () {
    test('8. Conflicting duplicate content is rejected and does not overwrite existing staging bytes', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(
        fileSize: 40000,
        chunkSize: 16384,
        totalChunks: 3,
      );

      final originalData = generateTestData(16384, seed: 100);
      final conflictingData = generateTestData(16384, seed: 999);

      // Initial transmission of Chunk 0
      final env0Original = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: originalData,
      );

      await pipeline.receiveChunk(
        envelope: env0Original,
        session: sessions.sessionBob,
        now: testNow,
      );

      // Conflicting transmission of Chunk 0 under same session (fresh sequenceNumber)
      final env0Conflict = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: conflictingData,
      );

      expect(
        () => pipeline.receiveChunk(
          envelope: env0Conflict,
          session: sessions.sessionBob,
          now: testNow,
        ),
        throwsA(isA<ChunkContentConflictException>()),
      );

      await pipeline.closeWriter(transfer.transferId);

      // Verify staging file was NOT overwritten with conflicting bytes
      final stagedBytes = await File(transfer.stagingPath).readAsBytes();
      expect(stagedBytes.sublist(0, 16384), equals(originalData));
      expect(stagedBytes.sublist(0, 16384), isNot(equals(conflictingData)));
    });
  });

  // ===========================================================================
  // Test 9: Disk write failures do not advance receive progress
  // ===========================================================================
  group('Requirement 9: Persistence ordering & write failure consistency', () {
    test('9. Disk write failure cleans up and does NOT record chunk in database', () async {
      final sessions = await establishSession();

      // Create transfer pointing to an illegal staging path outside authorized staging dir
      final illegalStaging = p.join(tempDir.parent.path, 'evil.part');
      final transfer = await createIncomingTransferRecord(
        stagingPath: illegalStaging,
      );

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob, now: testNow),
        throwsA(isA<ChunkDiskWriteException>()),
      );

      // Verify database chunk record was NEVER created
      final chunk = await bobDb.getFileChunk(transfer.transferId, 0);
      expect(chunk, isNull);

      final transferRecord = await bobDb.getFileTransfer(transfer.transferId);
      // Status did NOT advance
      expect(transferRecord!.status, FileTransferStatus.acceptSent.name);
    });
  });

  // ===========================================================================
  // Test 10: Chunk writes remain bounded-memory
  // ===========================================================================
  group('Requirement 10: Bounded memory during multi-chunk streaming', () {
    test('10. Memory is bounded to individual chunk operations without accumulation', () async {
      final sessions = await establishSession();
      const numChunks = 5;
      const chunkSize = 16384;
      const fileSize = numChunks * chunkSize;

      final transfer = await createIncomingTransferRecord(
        fileSize: fileSize,
        chunkSize: chunkSize,
        totalChunks: numChunks,
      );

      for (var i = 0; i < numChunks; i++) {
        final chunkData = generateTestData(chunkSize, seed: i);
        final env = await cryptoService.encryptChunk(
          session: sessions.sessionAlice,
          transferId: transfer.transferId,
          originId: 'ML-DEVICE-ALICE',
          destinationId: 'ML-DEVICE-BOB',
          chunkIndex: i,
          totalChunks: numChunks,
          offset: i * chunkSize,
          plaintext: chunkData,
        );

        final result = await pipeline.receiveChunk(
          envelope: env,
          session: sessions.sessionBob,
          now: testNow,
        );
        expect(result.isSuccess, isTrue);
        expect(result.chunksReceived, i + 1);
        expect(result.bytesWritten, chunkSize);
      }

      await pipeline.closeWriter(transfer.transferId);

      final fileOnDisk = File(transfer.stagingPath);
      expect(await fileOnDisk.length(), fileSize);
    });
  });

  // ===========================================================================
  // Test 11: Resource handles are released after errors and via closeWriter
  // ===========================================================================
  group('Requirement 11: Resource handle cleanup on error and close', () {
    test('11a. Explicit closeWriter releases file handle and removes from active map', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      await pipeline.receiveChunk(envelope: env, session: sessions.sessionBob, now: testNow);

      final writer = pipeline.getActiveWriter(transfer.transferId);
      expect(writer, isNotNull);
      expect(writer!.isOpen, isTrue);

      await pipeline.closeWriter(transfer.transferId);
      expect(pipeline.getActiveWriter(transfer.transferId), isNull);
      expect(writer.isOpen, isFalse);
    });

    test('11b. closeAll cleans up all writers across multiple transfers', () async {
      final sessions = await establishSession();
      final tx1 = await createIncomingTransferRecord(transferId: 'TX-MULTI-001');
      final tx2 = await createIncomingTransferRecord(transferId: 'TX-MULTI-002');

      final env1 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: tx1.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );
      final env2 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: tx2.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      await pipeline.receiveChunk(envelope: env1, session: sessions.sessionBob, now: testNow);
      await pipeline.receiveChunk(envelope: env2, session: sessions.sessionBob, now: testNow);

      expect(pipeline.getActiveWriter('TX-MULTI-001'), isNotNull);
      expect(pipeline.getActiveWriter('TX-MULTI-002'), isNotNull);

      await pipeline.closeAll();

      expect(pipeline.getActiveWriter('TX-MULTI-001'), isNull);
      expect(pipeline.getActiveWriter('TX-MULTI-002'), isNull);
    });
  });

  // ===========================================================================
  // Test 12: Receiving does not mark a transfer completed
  // ===========================================================================
  group('Requirement 12: Non-completion invariant (Deferred to Step 13)', () {
    test('12. Receiving all chunks leaves status in transferring, NEVER completed', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(
        fileSize: 200,
        chunkSize: 100,
        totalChunks: 2,
      );

      final env0 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        plaintext: Uint8List(100),
      );
      final env1 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 1,
        totalChunks: 2,
        offset: 100,
        plaintext: Uint8List(100),
      );

      final res0 = await pipeline.receiveChunk(envelope: env0, session: sessions.sessionBob, now: testNow);
      expect(res0.status, FileTransferStatus.transferring);

      final res1 = await pipeline.receiveChunk(envelope: env1, session: sessions.sessionBob, now: testNow);
      expect(res1.chunksReceived, 2);
      expect(res1.totalChunks, 2);
      // Status in result MUST be transferring, NOT completed
      expect(res1.status, FileTransferStatus.transferring);
      expect(res1.status, isNot(FileTransferStatus.completed));

      // Status in SQLite database MUST be transferring, NOT completed
      final updatedTransfer = await bobDb.getFileTransfer(transfer.transferId);
      expect(updatedTransfer!.status, FileTransferStatus.transferring.name);
      expect(updatedTransfer.status, isNot(FileTransferStatus.completed.name));
    });

    test('12b. Paused transfer transitions validly to transferring upon receiving next chunk', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord(
        status: FileTransferStatus.paused,
        fileSize: 200,
        chunkSize: 100,
        totalChunks: 2,
      );

      final env0 = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        plaintext: Uint8List(100),
      );

      final res0 = await pipeline.receiveChunk(envelope: env0, session: sessions.sessionBob, now: testNow);
      expect(res0.status, FileTransferStatus.transferring);

      final updated = await bobDb.getFileTransfer(transfer.transferId);
      expect(updated!.status, FileTransferStatus.transferring.name);
    });
  });

  // ===========================================================================
  // Additional Edge-Case & Error Mode Tests
  // ===========================================================================
  group('Additional Security & Error Handling Edge Cases', () {
    test('throwOnError: false returns ChunkReceivingResult with error populated and isSuccess: false', () async {
      final sessions = await establishSession();
      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: 'TX-NON-EXISTENT-404',
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: Uint8List(10),
      );

      final result = await pipeline.receiveChunk(
        envelope: env,
        session: sessions.sessionBob,
        throwOnError: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, isA<TransferNotFoundException>());
    });

    test('Destination ID mismatch throws ChunkMetadataMismatchException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-CHARLIE', // not Bob
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      expect(
        () => pipeline.receiveChunk(envelope: env, session: sessions.sessionBob),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });

    test('Authenticated sender ID mismatch throws SessionMismatchException', () async {
      final sessions = await establishSession();
      final transfer = await createIncomingTransferRecord();

      final env = await cryptoService.encryptChunk(
        session: sessions.sessionAlice,
        transferId: transfer.transferId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: Uint8List(16384),
      );

      expect(
        () => pipeline.receiveChunk(
          envelope: env,
          session: sessions.sessionBob,
          authenticatedSenderId: 'ML-IMPOSTOR',
        ),
        throwsA(isA<SessionMismatchException>()),
      );
    });
  });
}
