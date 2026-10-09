import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_stream_reader.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase aliceDb;
  late DriftMessageRepository aliceRepo;

  late MeshIdentityService aliceIdentity;
  late MeshIdentityService bobIdentity;

  late EphemeralSessionService aliceSessionService;
  late EphemeralSessionService bobSessionService;

  late HandshakeService aliceHandshake;
  late HandshakeService bobHandshake;

  late DirectionalSessionEncryptionService directionalService;
  late FileTransferCryptoService cryptoService;
  late FileStreamReader streamReader;
  late ChunkSendingPipeline pipeline;

  final testNow = DateTime.utc(2026, 10, 9, 12, 0, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step10_test_');

    aliceDb = AppDatabase(NativeDatabase.memory());
    aliceRepo = DriftMessageRepository(aliceDb);

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
    streamReader = FileStreamReader();

    pipeline = ChunkSendingPipeline(
      localDeviceId: 'ML-DEVICE-ALICE',
      streamReader: streamReader,
      cryptoService: cryptoService,
      database: aliceDb,
      messageRepository: aliceRepo,
    );
  });

  tearDown(() async {
    await aliceDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a test file on disk with deterministic content.
  Future<File> createTestFile(String name, int size) async {
    final file = File(p.join(tempDir.path, name));
    final bytes = Uint8List(size);
    for (var i = 0; i < size; i++) {
      bytes[i] = (i ^ (i >> 8)) & 0xFF;
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Helper to establish an authenticated bidirectional session between Alice and Bob.
  Future<({EphemeralSession sessionAlice, EphemeralSession sessionBob})> establishSession({
    String requestId = 'REQ-STEP10-001',
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

  /// Helper to create and persist an outgoing FileTransfer domain model in the database.
  Future<FileTransfer> createAndPersistTransfer({
    required String transferId,
    required String filePath,
    required int fileSize,
    int chunkSize = 64,
    FileTransferStatus status = FileTransferStatus.acceptReceived,
    FileTransferDirection direction = FileTransferDirection.outgoing,
  }) async {
    final totalChunks = FileStreamReader.calculateTotalChunks(
      fileSize: fileSize,
      chunkSize: chunkSize,
    );

    final transfer = FileTransfer(
      transferId: transferId,
      conversationId: 'CONV-ALICE-BOB',
      peerId: 'ML-DEVICE-BOB',
      direction: direction,
      fileName: p.basename(filePath),
      fileSize: fileSize,
      mimeType: 'application/octet-stream',
      fileHash: 'mock-sha256-hash',
      localPath: filePath,
      stagingPath: '',
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      status: status,
      createdAt: testNow,
      updatedAt: testNow,
    );

    await aliceDb.insertFileTransfer(transfer.toCompanion());
    return transfer;
  }

  group('Requirement 1 & 3: Small File Splitting, Offsets and Lengths', () {
    test('1. A small file is split into the expected chunks with exact metadata', () async {
      final file = await createTestFile('small_exact.bin', 128);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-SMALL-001',
        filePath: file.path,
        fileSize: 128,
        chunkSize: 64,
      );

      final receivedEnvelopes = <EncryptedFileChunkEnvelope>[];
      final sender = FunctionalChunkTransportSender((env) async {
        receivedEnvelopes.add(env);
        return true;
      });

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      expect(result.isSuccess, isTrue);
      expect(result.chunksSent, 2);
      expect(result.totalChunks, 2);
      expect(result.bytesSent, 128);
      expect(result.totalBytes, 128);
      expect(receivedEnvelopes.length, 2);

      // Chunk 0
      expect(receivedEnvelopes[0].chunkIndex, 0);
      expect(receivedEnvelopes[0].offset, 0);
      expect(receivedEnvelopes[0].chunkLength, 64);
      expect(receivedEnvelopes[0].totalChunks, 2);
      expect(receivedEnvelopes[0].transferId, 'TX-SMALL-001');
      expect(receivedEnvelopes[0].originId, 'ML-DEVICE-ALICE');
      expect(receivedEnvelopes[0].destinationId, 'ML-DEVICE-BOB');

      // Chunk 1
      expect(receivedEnvelopes[1].chunkIndex, 1);
      expect(receivedEnvelopes[1].offset, 64);
      expect(receivedEnvelopes[1].chunkLength, 64);
      expect(receivedEnvelopes[1].totalChunks, 2);
    });

    test('2. An uneven file calculates correct offset and trailing chunk length', () async {
      final file = await createTestFile('small_uneven.bin', 250);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-UNEVEN-001',
        filePath: file.path,
        fileSize: 250,
        chunkSize: 64, // 64 * 3 = 192, last chunk is 58 bytes
      );

      final receivedEnvelopes = <EncryptedFileChunkEnvelope>[];
      final sender = FunctionalChunkTransportSender((env) async {
        receivedEnvelopes.add(env);
        return true;
      });

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      expect(result.chunksSent, 4);
      expect(receivedEnvelopes.length, 4);

      expect(receivedEnvelopes[0].chunkIndex, 0);
      expect(receivedEnvelopes[0].offset, 0);
      expect(receivedEnvelopes[0].chunkLength, 64);

      expect(receivedEnvelopes[1].chunkIndex, 1);
      expect(receivedEnvelopes[1].offset, 64);
      expect(receivedEnvelopes[1].chunkLength, 64);

      expect(receivedEnvelopes[2].chunkIndex, 2);
      expect(receivedEnvelopes[2].offset, 128);
      expect(receivedEnvelopes[2].chunkLength, 64);

      expect(receivedEnvelopes[3].chunkIndex, 3);
      expect(receivedEnvelopes[3].offset, 192);
      expect(receivedEnvelopes[3].chunkLength, 58);
    });
  });

  group('Requirement 2: Streaming Without Whole-File Buffering & Resource Cleanup', () {
    test('3. A file larger than several chunks streams incrementally with bounded handle count', () async {
      // 10 chunks of 1024 bytes = 10,240 bytes
      final file = await createTestFile('stream_multi.bin', 10240);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-STREAM-001',
        filePath: file.path,
        fileSize: 10240,
        chunkSize: 1024,
      );

      var maxObservedActiveHandles = 0;
      final emittedChunks = <int>[];

      final sender = FunctionalChunkTransportSender((env) async {
        emittedChunks.add(env.chunkIndex);
        if (streamReader.activeHandleCount > maxObservedActiveHandles) {
          maxObservedActiveHandles = streamReader.activeHandleCount;
        }
        return true;
      });

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      expect(result.isSuccess, isTrue);
      expect(result.chunksSent, 10);
      expect(emittedChunks, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

      // Exactly 1 handle open while streaming, never multiple
      expect(maxObservedActiveHandles, 1);

      // Promptly closed when finished
      expect(streamReader.activeHandleCount, 0);
    });
  });

  group('Requirement 4: Step 8 Encryption & Decryptability', () {
    test('4. Each emitted chunk is encrypted with Step 8 format and decryptable by peer session', () async {
      final file = await createTestFile('crypto_verify.bin', 180);
      final originalBytes = await file.readAsBytes();
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-CRYPTO-001',
        filePath: file.path,
        fileSize: 180,
        chunkSize: 64, // 64, 64, 52
      );

      final receivedEnvelopes = <EncryptedFileChunkEnvelope>[];
      final sender = FunctionalChunkTransportSender((env) async {
        receivedEnvelopes.add(env);
        return true;
      });

      await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      expect(receivedEnvelopes.length, 3);

      final reconstructed = BytesBuilder();
      for (final env in receivedEnvelopes) {
        // Step 8 envelope invariants
        expect(env.version, 2);
        expect(env.nonce.length, 12);
        expect(env.mac.length, 16);
        expect(env.ciphertext.length, env.chunkLength);

        // Ciphertext is not plaintext
        final chunkSlice = originalBytes.sublist(env.offset, env.offset + env.chunkLength);
        expect(env.ciphertext, isNot(equals(chunkSlice)));

        // Decrypt using Bob's session via Step 8 FileTransferCryptoService
        final decryptedChunk = await cryptoService.decryptChunk(
          session: sessions.sessionBob,
          envelope: env,
        );
        expect(decryptedChunk, equals(chunkSlice));
        reconstructed.add(decryptedChunk);
      }

      // Reconstructed matches original file 100%
      expect(reconstructed.toBytes(), equals(originalBytes));
    });
  });

  group('Requirement 5: Rate Control, Pacing & In-flight Window', () {
    test('5. Sending respects configured interChunkDelay using injected delay function', () async {
      final file = await createTestFile('rate_pacing.bin', 128);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-RATE-001',
        filePath: file.path,
        fileSize: 128,
        chunkSize: 32, // 4 chunks -> 3 inter-chunk delays
      );

      final recordedDelays = <Duration>[];
      final sender = FunctionalChunkTransportSender((env) async => true);

      final policy = ChunkSendingPolicy(
        interChunkDelay: const Duration(milliseconds: 25),
        delayFunction: (duration) async {
          recordedDelays.add(duration);
        },
      );

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
        policy: policy,
      );

      expect(result.chunksSent, 4);
      // Pacing delays occur between chunk 0->1, 1->2, and 2->3
      expect(recordedDelays.length, 3);
      for (final d in recordedDelays) {
        expect(d, const Duration(milliseconds: 25));
      }
    });

    test('6. Sending respects maxChunksPerSecond throughput calculation', () async {
      final file = await createTestFile('throughput.bin', 96);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-RATE-002',
        filePath: file.path,
        fileSize: 96,
        chunkSize: 32, // 3 chunks -> 2 delays
      );

      final recordedDelays = <Duration>[];
      final sender = FunctionalChunkTransportSender((env) async => true);

      // 50 chunks/sec => 1,000,000 / 50 = 20,000 microseconds = 20 ms
      final policy = ChunkSendingPolicy(
        maxChunksPerSecond: 50,
        delayFunction: (duration) async {
          recordedDelays.add(duration);
        },
      );

      expect(policy.effectiveChunkDelay, const Duration(milliseconds: 20));

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
        policy: policy,
      );

      expect(result.chunksSent, 3);
      expect(recordedDelays.length, 2);
      expect(recordedDelays[0], const Duration(milliseconds: 20));
      expect(recordedDelays[1], const Duration(milliseconds: 20));
    });

    test('7. Bounded in-flight queue (maxInFlightChunks: 2) maintains backpressure', () async {
      final file = await createTestFile('inflight.bin', 160);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-INFLIGHT-001',
        filePath: file.path,
        fileSize: 160,
        chunkSize: 32, // 5 chunks
      );

      var inFlightCount = 0;
      var maxObservedInFlight = 0;

      final sender = FunctionalChunkTransportSender((env) async {
        inFlightCount++;
        if (inFlightCount > maxObservedInFlight) {
          maxObservedInFlight = inFlightCount;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
        inFlightCount--;
        return true;
      });

      final policy = const ChunkSendingPolicy(
        maxInFlightChunks: 2,
      );

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
        policy: policy,
      );

      expect(result.chunksSent, 5);
      expect(maxObservedInFlight, lessThanOrEqualTo(2));
      expect(inFlightCount, 0);
    });
  });

  group('Requirement 6 & 7: Send Failure & Cancellation Handling', () {
    test('8. A send failure stops subsequent chunk production promptly and reports ChunkSendFailureException', () async {
      final file = await createTestFile('fail_midway.bin', 200);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-FAIL-001',
        filePath: file.path,
        fileSize: 200,
        chunkSize: 40, // 5 chunks: 0, 1, 2, 3, 4
      );

      final sentChunks = <int>[];
      final sender = FunctionalChunkTransportSender((env) async {
        sentChunks.add(env.chunkIndex);
        if (env.chunkIndex == 2) {
          // Reject handoff at chunk 2
          return false;
        }
        return true;
      });

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<ChunkSendFailureException>().having(
          (e) => e.chunkIndex,
          'chunkIndex',
          2,
        )),
      );

      // Chunks 3 and 4 must NEVER be sent
      expect(sentChunks, [0, 1, 2]);

      // File descriptor must be closed
      expect(streamReader.activeHandleCount, 0);
    });

    test('9. Transport exception is caught, stops production, and is surfaced with cause', () async {
      final file = await createTestFile('fail_throw.bin', 100);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-FAIL-THROW',
        filePath: file.path,
        fileSize: 100,
        chunkSize: 25,
      );

      final sender = FunctionalChunkTransportSender((env) async {
        if (env.chunkIndex == 1) {
          throw const SocketException('Simulated radio disconnect');
        }
        return true;
      });

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<ChunkSendFailureException>().having(
          (e) => e.chunkIndex,
          'chunkIndex',
          1,
        )),
      );

      expect(streamReader.activeHandleCount, 0);
    });

    test('10. Cancellation via FileTransferCancellationToken stops subsequent chunk production', () async {
      final file = await createTestFile('cancel_test.bin', 300);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-CANCEL-001',
        filePath: file.path,
        fileSize: 300,
        chunkSize: 50, // 6 chunks
      );

      final cancellationToken = FileTransferCancellationToken();
      final sentChunks = <int>[];

      final sender = FunctionalChunkTransportSender((env) async {
        sentChunks.add(env.chunkIndex);
        if (env.chunkIndex == 1) {
          cancellationToken.cancel('User clicked abort transfer');
        }
        return true;
      });

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
          cancellationToken: cancellationToken,
        ),
        throwsA(isA<ChunkSendCancelledException>().having(
          (e) => e.message,
          'message',
          contains('User clicked abort transfer'),
        )),
      );

      // Chunks after cancellation must not be produced
      expect(sentChunks.length, lessThanOrEqualTo(2));
      expect(streamReader.activeHandleCount, 0);
    });

    test('11. Pre-cancelled token stops before any chunk is read or encrypted', () async {
      final file = await createTestFile('cancel_pre.bin', 100);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-CANCEL-PRE',
        filePath: file.path,
        fileSize: 100,
        chunkSize: 20,
      );

      final cancellationToken = FileTransferCancellationToken()..cancel('Immediate abort');
      var sendCalled = false;

      final sender = FunctionalChunkTransportSender((env) async {
        sendCalled = true;
        return true;
      });

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
          cancellationToken: cancellationToken,
        ),
        throwsA(isA<ChunkSendCancelledException>()),
      );

      expect(sendCalled, isFalse);
      expect(streamReader.activeHandleCount, 0);
    });
  });

  group('Requirement 8: Empty File Zero-Chunk Convention', () {
    test('12. Empty file (0 bytes) emits 0 chunks and finishes cleanly', () async {
      final file = await createTestFile('empty.bin', 0);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-EMPTY-001',
        filePath: file.path,
        fileSize: 0,
        chunkSize: 1024,
      );

      var sendCalled = false;
      final sender = FunctionalChunkTransportSender((env) async {
        sendCalled = true;
        return true;
      });

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      expect(result.isSuccess, isTrue);
      expect(result.chunksSent, 0);
      expect(result.totalChunks, 0);
      expect(result.bytesSent, 0);
      expect(result.totalBytes, 0);
      expect(result.status, FileTransferStatus.transferring);
      expect(sendCalled, isFalse);
      expect(streamReader.activeHandleCount, 0);
    });
  });

  group('Requirement 9: Invalid Source Size and Metadata Rejection', () {
    test('13. Actual source file size mismatch on disk throws SourceFileSizeMismatchException', () async {
      final file = await createTestFile('size_mismatch.bin', 50);
      final sessions = await establishSession();
      // Transfer metadata claims 100 bytes, but disk file is 50 bytes
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-BAD-SIZE',
        filePath: file.path,
        fileSize: 100,
        chunkSize: 50,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<SourceFileSizeMismatchException>()),
      );
    });

    test('14. Total chunks count mismatch throws ChunkMetadataMismatchException', () async {
      final file = await createTestFile('chunks_mismatch.bin', 100);
      final sessions = await establishSession();

      // Create a transfer with totalChunks manually corrupted (claims 5 instead of 2)
      final transfer = FileTransfer(
        transferId: 'TX-BAD-CHUNKS',
        conversationId: 'CONV-1',
        peerId: 'ML-DEVICE-BOB',
        direction: FileTransferDirection.outgoing,
        fileName: 'chunks_mismatch.bin',
        fileSize: 100,
        mimeType: 'application/octet-stream',
        fileHash: 'hash',
        localPath: file.path,
        stagingPath: '',
        totalChunks: 5, // Correct is 2 for chunkSize 50
        chunkSize: 50,
        status: FileTransferStatus.acceptReceived,
        createdAt: testNow,
        updatedAt: testNow,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );
    });

    test('15. Incoming transfer direction throws InvalidSendingStateException', () async {
      final file = await createTestFile('incoming.bin', 50);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-INCOMING-FAIL',
        filePath: file.path,
        fileSize: 50,
        direction: FileTransferDirection.incoming,
        status: FileTransferStatus.acceptSent,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<InvalidSendingStateException>()),
      );
    });

    test('16. Unpermitted status (initiated, completed, failed) throws InvalidSendingStateException', () async {
      final file = await createTestFile('status_test.bin', 50);
      final sessions = await establishSession();

      for (final badStatus in [
        FileTransferStatus.initiated,
        FileTransferStatus.offerSent,
        FileTransferStatus.completed,
        FileTransferStatus.failed,
        FileTransferStatus.cancelled,
      ]) {
        final transfer = await createAndPersistTransfer(
          transferId: 'TX-BAD-STATUS-${badStatus.name}',
          filePath: file.path,
          fileSize: 50,
          status: badStatus,
        );

        final sender = FunctionalChunkTransportSender((env) async => true);

        await expectLater(
          pipeline.sendTransfer(
            transfer: transfer,
            session: sessions.sessionAlice,
            transportSender: sender,
          ),
          throwsA(isA<InvalidSendingStateException>()),
          reason: 'Status ${badStatus.name} should be rejected',
        );
      }
    });
  });

  group('Requirement 10: State Machine & Completion Invariant', () {
    test('17. Transfer moves from acceptReceived to transferring, NEVER completed upon handoff completion', () async {
      final file = await createTestFile('state_check.bin', 100);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-STATE-001',
        filePath: file.path,
        fileSize: 100,
        chunkSize: 50,
        status: FileTransferStatus.acceptReceived,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      // In result
      expect(result.status, FileTransferStatus.transferring);
      expect(result.status, isNot(equals(FileTransferStatus.completed)));

      // In SQLite persistence
      final record = await aliceDb.getFileTransfer('TX-STATE-001');
      expect(record, isNotNull);
      expect(record!.status, FileTransferStatus.transferring.toDbValue());
      expect(record.status, isNot(equals(FileTransferStatus.completed.toDbValue())));
    });

    test('18. Paused transfer transitions validly to transferring', () async {
      final file = await createTestFile('resume_state.bin', 64);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-PAUSED-001',
        filePath: file.path,
        fileSize: 64,
        chunkSize: 64,
        status: FileTransferStatus.paused,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      expect(result.isSuccess, isTrue);
      expect(result.status, FileTransferStatus.transferring);

      final record = await aliceDb.getFileTransfer('TX-PAUSED-001');
      expect(record!.status, FileTransferStatus.transferring.toDbValue());
    });
  });

  group('Requirement 11: Sequence Number & Concurrency Ordering', () {
    test('19. Session sequence numbers advance monotonically and match envelope sequenceNumber', () async {
      final file = await createTestFile('seq_order.bin', 160);
      final sessions = await establishSession();
      final initialSeq = sessions.sessionAlice.sequenceNumber;

      final transfer = await createAndPersistTransfer(
        transferId: 'TX-SEQ-001',
        filePath: file.path,
        fileSize: 160,
        chunkSize: 32, // 5 chunks
      );

      final capturedSequences = <int>[];
      final sender = FunctionalChunkTransportSender((env) async {
        capturedSequences.add(env.sequenceNumber);
        return true;
      });

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
      );

      expect(result.chunksSent, 5);
      // Monotonically increasing: initialSeq, initialSeq+1, ...
      expect(capturedSequences, [
        initialSeq,
        initialSeq + 1,
        initialSeq + 2,
        initialSeq + 3,
        initialSeq + 4,
      ]);

      // Session sentMessageCount advanced by exactly 5
      expect(sessions.sessionAlice.sequenceNumber, initialSeq + 5);
    });
  });

  group('Peer Trust & Security Validations', () {
    test('20. Compromised peer is rejected before reading source file', () async {
      final file = await createTestFile('untrusted.bin', 64);
      final sessions = await establishSession();

      // Record Bob as compromised in Alice's peer database
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

      final transfer = await createAndPersistTransfer(
        transferId: 'TX-UNTRUSTED',
        filePath: file.path,
        fileSize: 64,
        chunkSize: 64,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<PeerUntrustedSendingException>()),
      );
    });

    test('21. Unverified peer is rejected when requireVerifiedPeer is enabled', () async {
      final file = await createTestFile('require_verified.bin', 64);
      final sessions = await establishSession();

      // Record Bob as tofu_unverified
      await aliceRepo.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-DEVICE-BOB',
          identityPublicKey: 'mock-identity-key',
          safetyNumber: '123456',
          trustStatus: 'tofu_unverified',
          protocolVersion: 2,
          firstSeenAt: testNow,
          lastSeenAt: testNow,
        ),
      );

      final strictPipeline = ChunkSendingPipeline(
        localDeviceId: 'ML-DEVICE-ALICE',
        streamReader: streamReader,
        cryptoService: cryptoService,
        database: aliceDb,
        messageRepository: aliceRepo,
        requireVerifiedPeer: true,
      );

      final transfer = await createAndPersistTransfer(
        transferId: 'TX-TOFU-REJECT',
        filePath: file.path,
        fileSize: 64,
        chunkSize: 64,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      await expectLater(
        strictPipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<PeerUntrustedSendingException>()),
      );
    });

    test('22. Destroyed session is rejected', () async {
      final file = await createTestFile('destroyed_sess.bin', 64);
      final sessions = await establishSession();
      sessions.sessionAlice.destroy();

      final transfer = await createAndPersistTransfer(
        transferId: 'TX-DESTROYED-SESS',
        filePath: file.path,
        fileSize: 64,
        chunkSize: 64,
      );

      final sender = FunctionalChunkTransportSender((env) async => true);

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<InvalidSendingStateException>()),
      );
    });
  });

  group('Progress Reporting', () {
    test('23. onProgress callback reports monotonic progress fraction and percentage', () async {
      final file = await createTestFile('progress.bin', 200);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-PROG-001',
        filePath: file.path,
        fileSize: 200,
        chunkSize: 50, // 4 chunks
      );

      final reports = <ChunkSendProgress>[];
      final sender = FunctionalChunkTransportSender((env) async => true);

      await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
        onProgress: (p) => reports.add(p),
      );

      expect(reports.length, 4);
      expect(reports[0].chunkIndex, 0);
      expect(reports[0].bytesSent, 50);
      expect(reports[0].percentage, 25);

      expect(reports[1].chunkIndex, 1);
      expect(reports[1].bytesSent, 100);
      expect(reports[1].percentage, 50);

      expect(reports[2].chunkIndex, 2);
      expect(reports[2].bytesSent, 150);
      expect(reports[2].percentage, 75);

      expect(reports[3].chunkIndex, 3);
      expect(reports[3].bytesSent, 200);
      expect(reports[3].percentage, 100);
    });
  });

  group('Audit 1: In-Flight Concurrency, Asynchronous Failures & Draining', () {
    test('24. In-flight failure when maxInFlightChunks > 1 observes error without leaking async exceptions and drains pending sends', () async {
      // 5 chunks of 32 bytes = 160 bytes
      final file = await createTestFile('inflight_failure.bin', 160);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-INFLIGHT-FAIL',
        filePath: file.path,
        fileSize: 160,
        chunkSize: 32, // 5 chunks
      );

      final attemptedChunks = <int>[];

      // maxInFlightChunks: 3
      // Chunk 0: takes 40ms to complete successfully
      // Chunk 1: throws after 10ms
      // Chunk 2: takes 50ms to complete successfully
      final sender = FunctionalChunkTransportSender((env) async {
        attemptedChunks.add(env.chunkIndex);
        if (env.chunkIndex == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return true;
        } else if (env.chunkIndex == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw const SocketException('Simulated radio failure on chunk 1');
        } else if (env.chunkIndex == 2) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return true;
        }
        return true;
      });

      const policy = ChunkSendingPolicy(
        maxInFlightChunks: 3,
      );

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
          policy: policy,
        ),
        throwsA(isA<ChunkSendFailureException>().having(
          (e) => e.chunkIndex,
          'chunkIndex',
          1,
        )),
      );

      // Chunks 3 and 4 were never produced because chunk 1 failed and backpressure halted production
      expect(attemptedChunks.contains(3), isFalse);
      expect(attemptedChunks.contains(4), isFalse);

      // Stream handle must be closed cleanly
      expect(streamReader.activeHandleCount, 0);
    });

    test('25. In-flight cancellation with maxInFlightChunks > 1 drains pending sends cleanly', () async {
      final file = await createTestFile('inflight_cancel.bin', 160);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-INFLIGHT-CANCEL',
        filePath: file.path,
        fileSize: 160,
        chunkSize: 32,
      );

      final cancellationToken = FileTransferCancellationToken();
      final sender = FunctionalChunkTransportSender((env) async {
        if (env.chunkIndex == 1) {
          cancellationToken.cancel('User canceled during in-flight send');
        }
        await Future<void>.delayed(const Duration(milliseconds: 15));
        return true;
      });

      const policy = ChunkSendingPolicy(
        maxInFlightChunks: 3,
      );

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
          policy: policy,
          cancellationToken: cancellationToken,
        ),
        throwsA(isA<ChunkSendCancelledException>()),
      );

      expect(streamReader.activeHandleCount, 0);
    });

    test('26. Synchronous transport throw during sendChunk reports correct chunkIndex and closes resources', () async {
      final file = await createTestFile('sync_throw.bin', 64);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-SYNC-THROW',
        filePath: file.path,
        fileSize: 64,
        chunkSize: 32,
      );

      final sender = FunctionalChunkTransportSender((env) {
        if (env.chunkIndex == 0) {
          throw StateError('Synchronous driver crash');
        }
        return Future.value(true);
      });

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<ChunkSendFailureException>().having(
          (e) => e.chunkIndex,
          'chunkIndex',
          0,
        )),
      );

      expect(streamReader.activeHandleCount, 0);
    });
  });

  group('Audit 2: Rate Policy Validation & Pacing Semantics', () {
    test('27. ChunkSendingPolicy rejects negative delays, non-positive or non-finite rates', () {
      // Negative interChunkDelay
      expect(
        () => const ChunkSendingPolicy(interChunkDelay: Duration(seconds: -1)).validate(),
        throwsA(isA<ArgumentError>()),
      );

      // maxChunksPerSecond == 0
      expect(
        () => const ChunkSendingPolicy(maxChunksPerSecond: 0).validate(),
        throwsA(isA<ArgumentError>()),
      );

      // maxChunksPerSecond < 0
      expect(
        () => const ChunkSendingPolicy(maxChunksPerSecond: -5.0).validate(),
        throwsA(isA<ArgumentError>()),
      );

      // maxChunksPerSecond is NaN
      expect(
        () => const ChunkSendingPolicy(maxChunksPerSecond: double.nan).validate(),
        throwsA(isA<ArgumentError>()),
      );

      // maxChunksPerSecond is infinity
      expect(
        () => const ChunkSendingPolicy(maxChunksPerSecond: double.infinity).validate(),
        throwsA(isA<ArgumentError>()),
      );

      // maxInFlightChunks < 1
      expect(
        () => ChunkSendingPolicy(maxInFlightChunks: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('28. Effective chunk delay calculation handles combinations correctly', () {
      const policyDefault = ChunkSendingPolicy();
      expect(policyDefault.effectiveChunkDelay, Duration.zero);

      const policyDelayOnly = ChunkSendingPolicy(
        interChunkDelay: Duration(milliseconds: 50),
      );
      expect(policyDelayOnly.effectiveChunkDelay, const Duration(milliseconds: 50));

      const policyRateOnly = ChunkSendingPolicy(
        maxChunksPerSecond: 10, // 1,000,000 / 10 = 100,000 micros = 100ms
      );
      expect(policyRateOnly.effectiveChunkDelay, const Duration(milliseconds: 100));

      // When both are specified, max is selected
      const policyBoth = ChunkSendingPolicy(
        interChunkDelay: Duration(milliseconds: 150),
        maxChunksPerSecond: 10, // 100ms
      );
      expect(policyBoth.effectiveChunkDelay, const Duration(milliseconds: 150));
    });
  });

  group('Audit 3: State Persistence, Non-Completion & Resumption Semantics', () {
    test('29. Transport failure with throwOnError: false leaves transfer in transferring and never completed', () async {
      final file = await createTestFile('fail_result_check.bin', 64);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-NO-THROW-FAIL',
        filePath: file.path,
        fileSize: 64,
        chunkSize: 32,
      );

      final sender = FunctionalChunkTransportSender((env) async {
        if (env.chunkIndex == 1) return false;
        return true;
      });

      final result = await pipeline.sendTransfer(
        transfer: transfer,
        session: sessions.sessionAlice,
        transportSender: sender,
        throwOnError: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, isA<ChunkSendFailureException>());
      expect(result.status, FileTransferStatus.transferring);
      expect(result.status, isNot(equals(FileTransferStatus.completed)));
      expect(result.chunksSent, 1);

      // Verify database persistence never reached completed
      final dbRecord = await aliceDb.getFileTransfer('TX-NO-THROW-FAIL');
      expect(dbRecord!.status, FileTransferStatus.transferring.toDbValue());
      expect(dbRecord.status, isNot(equals(FileTransferStatus.completed.toDbValue())));
    });

    test('30. FileTransferStateMachine enforces that failed state is terminal and cannot transition', () {
      const sm = FileTransferStateMachine.instance;

      expect(sm.isTerminal(FileTransferStatus.failed), isTrue);

      for (final targetStatus in FileTransferStatus.values) {
        final transition = sm.transition(
          direction: FileTransferDirection.outgoing,
          from: FileTransferStatus.failed,
          to: targetStatus,
        );
        expect(
          transition.allowed,
          isFalse,
          reason: 'Failed transfer must not be allowed to transition to ${targetStatus.name}',
        );
      }
    });
  });

  group('Audit 4: Mid-Stream Source File Mutation', () {
    test('31. Truncating the source file mid-transfer throws ChunkMetadataMismatchException and cleans up handles', () async {
      final file = await createTestFile('mutate_truncate.bin', 128);
      final sessions = await establishSession();
      final transfer = await createAndPersistTransfer(
        transferId: 'TX-MUTATE-TRUNC',
        filePath: file.path,
        fileSize: 128,
        chunkSize: 32, // 4 chunks of 32 bytes
      );

      final sender = FunctionalChunkTransportSender((env) async {
        if (env.chunkIndex == 1) {
          // Truncate file on disk to 40 bytes while streaming
          await file.writeAsBytes(Uint8List(40), flush: true);
        }
        return true;
      });

      await expectLater(
        pipeline.sendTransfer(
          transfer: transfer,
          session: sessions.sessionAlice,
          transportSender: sender,
        ),
        throwsA(isA<ChunkMetadataMismatchException>()),
      );

      expect(streamReader.activeHandleCount, 0);

      final dbRecord = await aliceDb.getFileTransfer('TX-MUTATE-TRUNC');
      expect(dbRecord!.status, isNot(equals(FileTransferStatus.completed.toDbValue())));
    });
  });
}
