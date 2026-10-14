import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/file_disk_writer.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late FilePathService pathService;
  late FileAssemblyService assemblyService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step13_test_');
    db = AppDatabase(NativeDatabase.memory());
    pathService = FilePathService(baseDirectory: tempDir);
    assemblyService = FileAssemblyService(
      database: db,
      pathService: pathService,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> calculateSha256(Uint8List bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  group('Phase 8 Step 13: Whole-File Integrity & Assembly', () {
    test('1. Correct assembly of multiple chunks in order', () async {
      final transferId = 'FT-TEST-ORDER-1';
      final fileName = 'test_document.txt';

      // 3 chunks: chunk 0 = 64 bytes, chunk 1 = 64 bytes, chunk 2 = 72 bytes (200 bytes total)
      final chunk0Data = Uint8List.fromList(List.generate(64, (i) => i % 256));
      final chunk1Data = Uint8List.fromList(List.generate(64, (i) => (64 + i) % 256));
      final chunk2Data = Uint8List.fromList(List.generate(72, (i) => (128 + i) % 256));
      final fullBytes = Uint8List.fromList([...chunk0Data, ...chunk1Data, ...chunk2Data]);
      final expectedHash = await calculateSha256(fullBytes);

      // Setup staging file using FileDiskWriter
      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: 200,
        stagingPath: stagingPath,
      );
      await writer.writeAt(offset: 0, data: chunk0Data);
      await writer.writeAt(offset: 64, data: chunk1Data);
      await writer.writeAt(offset: 128, data: chunk2Data);
      await writer.flush();
      await writer.close();

      // Persist transfer record in SQLite
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(200),
          mimeType: 'text/plain',
          fileHash: expectedHash,
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 3,
          chunkSize: 64,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      // Record chunks in SQLite
      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 1);
      await db.markChunkReceived(transferId, 2);

      // Perform assembly
      final result = await assemblyService.assembleTransfer(transferId: transferId);

      expect(result.isSuccess, isTrue);
      expect(result.isIdempotent, isFalse);
      expect(result.fileSize, 200);
      expect(result.fileHash, expectedHash);
      expect(File(result.destinationPath).existsSync(), isTrue);

      // Verify destination file content
      final assembledBytes = await File(result.destinationPath).readAsBytes();
      expect(assembledBytes, equals(fullBytes));

      // Verify SQLite state is transitioned to completed
      final updatedTransfer = await db.getFileTransfer(transferId);
      expect(updatedTransfer!.status, equals('completed'));
      expect(updatedTransfer.localPath, equals(result.destinationPath));
    });

    test('2. Missing chunk rejection', () async {
      final transferId = 'FT-TEST-MISSING-1';
      final fileName = 'test_missing.bin';

      final fullBytes = Uint8List.fromList(List.generate(150, (i) => i));
      final expectedHash = await calculateSha256(fullBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: 150,
        stagingPath: stagingPath,
      );
      await writer.writeAt(offset: 0, data: fullBytes);
      await writer.close();

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(150),
          mimeType: 'application/octet-stream',
          fileHash: expectedHash,
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 3,
          chunkSize: 50,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      // Only record chunks 0 and 2 (chunk 1 is missing!)
      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 2);

      try {
        await assemblyService.assembleTransfer(transferId: transferId);
        fail('Should have thrown MissingChunksException');
      } on MissingChunksException catch (e) {
        expect(e.missingChunkIndexes, equals([1]));
        expect(e.totalChunks, equals(3));
      }

      // Check SQLite transfer status is NOT completed
      final transfer = await db.getFileTransfer(transferId);
      expect(transfer!.status, equals('transferring'));
    });

    test('3. Incorrect chunk metadata / length rejection', () async {
      final transferId = 'FT-TEST-METADATA-1';
      final fileName = 'bad_meta.bin';

      final stagingPath = await pathService.getStagingPath(transferId);
      final file = File(stagingPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.generate(100, (i) => i));

      // totalChunks is negative or chunk calculations overflow
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(100),
          mimeType: 'application/octet-stream',
          fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 2,
          chunkSize: 200, // Chunk 0 length would exceed file size
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await db.markChunkReceived(transferId, 0);
      await db.markChunkReceived(transferId, 1);

      expect(
        () => assemblyService.assembleTransfer(transferId: transferId),
        throwsA(isA<InvalidChunkMetadataException>()),
      );

      final transfer = await db.getFileTransfer(transferId);
      expect(transfer!.status, equals('transferring'));
    });

    test('4. Incorrect expected file size rejection', () async {
      final transferId = 'FT-TEST-SIZE-1';
      final fileName = 'size_mismatch.bin';

      final actualBytes = Uint8List.fromList([1, 2, 3, 4, 5]); // 5 bytes
      final stagingPath = await pathService.getStagingPath(transferId);
      final file = File(stagingPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(actualBytes);

      // Expected file size is 10 bytes, but staging file is only 5 bytes
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(10), // mismatch!
          mimeType: 'application/octet-stream',
          fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 1,
          chunkSize: 10,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await db.markChunkReceived(transferId, 0);

      try {
        await assemblyService.assembleTransfer(transferId: transferId);
        fail('Should have thrown FileSizeMismatchException');
      } on FileSizeMismatchException catch (e) {
        expect(e.expectedSize, 10);
        expect(e.actualSize, 5);
      }

      final transfer = await db.getFileTransfer(transferId);
      expect(transfer!.status, equals('transferring'));
    });

    test('5. SHA-256 match and mismatch', () async {
      final transferId = 'FT-TEST-HASH-1';
      final fileName = 'hash_test.bin';

      final realBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      final realHash = await calculateSha256(realBytes);
      final tamperedHash = '0000000000000000000000000000000000000000000000000000000000000000';

      final stagingPath = await pathService.getStagingPath(transferId);
      final file = File(stagingPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(realBytes);

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(5),
          mimeType: 'application/octet-stream',
          fileHash: tamperedHash, // Corrupted expected hash
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 1,
          chunkSize: 5,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await db.markChunkReceived(transferId, 0);

      // Hash mismatch throws FileHashMismatchException
      try {
        await assemblyService.assembleTransfer(transferId: transferId);
        fail('Should have thrown FileHashMismatchException');
      } on FileHashMismatchException catch (e) {
        expect(e.expectedHash, equals(tamperedHash));
        expect(e.actualHash, equals(realHash));
      }

      // Requirement 7 & 8: Transfer status transitioned to failed, staging file preserved, no completed file
      final transfer = await db.getFileTransfer(transferId);
      expect(transfer!.status, equals('failed'));
      expect(await file.exists(), isTrue, reason: 'Staging file must be preserved for recovery');

      final completedDir = await pathService.getCompletedDirectory();
      expect(File(p.join(completedDir.path, fileName)).existsSync(), isFalse);
    });

    test('6. No completed state after verification failure', () async {
      final transferId = 'FT-TEST-NO-COMPLETE';
      final fileName = 'fail_complete.bin';

      final stagingPath = await pathService.getStagingPath(transferId);
      final file = File(stagingPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(3),
          mimeType: 'application/octet-stream',
          fileHash: 'invalid_short_hash',
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 1,
          chunkSize: 3,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await db.markChunkReceived(transferId, 0);

      expect(
        () => assemblyService.assembleTransfer(transferId: transferId),
        throwsA(isA<FileHashMismatchException>()),
      );

      final transfer = await db.getFileTransfer(transferId);
      expect(transfer!.status, isNot(equals('completed')));
    });

    test('7. No partial output exposed as a completed file', () async {
      final transferId = 'FT-TEST-NO-PARTIAL';
      final fileName = 'test_partial.bin';
      final completedDir = await pathService.getCompletedDirectory();
      final destination = p.join(completedDir.path, fileName);

      final stagingPath = await pathService.getStagingPath(transferId);
      final file = File(stagingPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([10, 20, 30, 40]);

      // Record expected hash that does NOT match
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(4),
          mimeType: 'application/octet-stream',
          fileHash: '1111111111111111111111111111111111111111111111111111111111111111',
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 1,
          chunkSize: 4,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await db.markChunkReceived(transferId, 0);

      expect(
        () => assemblyService.assembleTransfer(transferId: transferId),
        throwsA(isA<FileHashMismatchException>()),
      );

      // Verify destination path does NOT exist (no partial file exposed!)
      expect(File(destination).existsSync(), isFalse);

      // Also verify no temp files left behind in completed directory
      final filesInDir = completedDir.existsSync()
          ? completedDir.listSync().map((f) => f.path).toList()
          : <String>[];
      expect(filesInDir.any((p) => p.contains('tmp_')), isFalse);
    });

    test('8. Destination path traversal rejection', () async {
      final transferId = 'FT-TEST-TRAVERSAL-1';

      final realBytes = Uint8List.fromList([1, 2, 3]);
      final realHash = await calculateSha256(realBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      final file = File(stagingPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(realBytes);

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: 'legit.txt',
          fileSize: BigInt.from(3),
          mimeType: 'text/plain',
          fileHash: realHash,
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 1,
          chunkSize: 3,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await db.markChunkReceived(transferId, 0);

      // Attempt explicit destination outside authorized app directory
      final outsidePath = p.join(tempDir.parent.path, 'evil_escape.bin');

      expect(
        () => assemblyService.assembleTransfer(
          transferId: transferId,
          explicitDestinationPath: outsidePath,
        ),
        throwsA(isA<SecurityException>()),
      );

      // Attempt path containing '..'
      final completedDir = await pathService.getCompletedDirectory();
      final traversalPath = p.join(completedDir.path, '..', 'evil.bin');

      expect(
        () => assemblyService.assembleTransfer(
          transferId: transferId,
          explicitDestinationPath: traversalPath,
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('9. File replacement policies: collisionSafe, failIfExists, overwrite', () async {
      final completedDir = await pathService.getCompletedDirectory(create: true);
      final existingFile = File(p.join(completedDir.path, 'doc.txt'));
      await existingFile.writeAsString('Original existing file content');

      final newBytes = Uint8List.fromList([100, 101, 102]);
      final newHash = await calculateSha256(newBytes);

      // Test 9a: failIfExists throws DestinationFileExistsException
      final transferId1 = 'FT-TEST-POLICY-1';
      final stagingPath1 = await pathService.getStagingPath(transferId1);
      final file1 = File(stagingPath1);
      await file1.parent.create(recursive: true);
      await file1.writeAsBytes(newBytes);

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId1,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: 'doc.txt',
          fileSize: BigInt.from(3),
          mimeType: 'text/plain',
          fileHash: newHash,
          localPath: '',
          stagingPath: stagingPath1,
          totalChunks: 1,
          chunkSize: 3,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await db.markChunkReceived(transferId1, 0);

      expect(
        () => assemblyService.assembleTransfer(
          transferId: transferId1,
          replacementPolicy: FileReplacementPolicy.failIfExists,
        ),
        throwsA(isA<DestinationFileExistsException>()),
      );

      // Test 9b: collisionSafe creates 'doc (1).txt' without overwriting 'doc.txt'
      final resultSafe = await assemblyService.assembleTransfer(
        transferId: transferId1,
        replacementPolicy: FileReplacementPolicy.collisionSafe,
      );
      expect(resultSafe.isSuccess, isTrue);
      expect(p.basename(resultSafe.destinationPath), equals('doc (1).txt'));
      expect(await existingFile.readAsString(), equals('Original existing file content'));
      expect(await File(resultSafe.destinationPath).readAsBytes(), equals(newBytes));

      // Test 9c: overwrite atomically replaces 'doc.txt'
      final transferId2 = 'FT-TEST-POLICY-2';
      final stagingPath2 = await pathService.getStagingPath(transferId2);
      final file2 = File(stagingPath2);
      await file2.parent.create(recursive: true);
      await file2.writeAsBytes(newBytes);

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId2,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: 'doc.txt',
          fileSize: BigInt.from(3),
          mimeType: 'text/plain',
          fileHash: newHash,
          localPath: '',
          stagingPath: stagingPath2,
          totalChunks: 1,
          chunkSize: 3,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await db.markChunkReceived(transferId2, 0);

      final resultOverwrite = await assemblyService.assembleTransfer(
        transferId: transferId2,
        replacementPolicy: FileReplacementPolicy.overwrite,
      );
      expect(resultOverwrite.isSuccess, isTrue);
      expect(p.basename(resultOverwrite.destinationPath), equals('doc.txt'));
      expect(await existingFile.readAsBytes(), equals(newBytes));
    });

    test('10. Repeated assembly idempotency', () async {
      final transferId = 'FT-TEST-IDEMPOTENT-1';
      final fileName = 'idempotent.dat';

      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final hash = await calculateSha256(data);

      final stagingPath = await pathService.getStagingPath(transferId);
      final file = File(stagingPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data);

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(8),
          mimeType: 'application/octet-stream',
          fileHash: hash,
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 1,
          chunkSize: 8,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await db.markChunkReceived(transferId, 0);

      // Initial assembly
      final firstResult = await assemblyService.assembleTransfer(transferId: transferId);
      expect(firstResult.isSuccess, isTrue);
      expect(firstResult.isIdempotent, isFalse);
      final destPath = firstResult.destinationPath;

      // Second assembly (idempotent)
      final secondResult = await assemblyService.assembleTransfer(transferId: transferId);
      expect(secondResult.isSuccess, isTrue);
      expect(secondResult.isIdempotent, isTrue);
      expect(secondResult.destinationPath, equals(destPath));

      // Third assembly (still idempotent)
      final thirdResult = await assemblyService.assembleTransfer(transferId: transferId);
      expect(thirdResult.isSuccess, isTrue);
      expect(thirdResult.isIdempotent, isTrue);

      // Destination file was not corrupted
      expect(await File(destPath).readAsBytes(), equals(data));
    });

    test('11. Zero-byte file handling', () async {
      final transferId = 'FT-TEST-ZERO-BYTE';
      final fileName = 'empty.txt';

      final emptyBytes = Uint8List(0);
      final emptyHash = await calculateSha256(emptyBytes);

      final stagingPath = await pathService.getStagingPath(transferId);

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(0),
          mimeType: 'text/plain',
          fileHash: emptyHash,
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 0,
          chunkSize: 1024,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final result = await assemblyService.assembleTransfer(transferId: transferId);
      expect(result.isSuccess, isTrue);
      expect(result.fileSize, 0);
      expect(result.fileHash, equals(emptyHash));
      expect(File(result.destinationPath).existsSync(), isTrue);
      expect(await File(result.destinationPath).length(), 0);

      final transfer = await db.getFileTransfer(transferId);
      expect(transfer!.status, equals('completed'));
    });

    test('12. Large-file streaming behavior (512 KB multi-chunk)', () async {
      final transferId = 'FT-TEST-LARGE-STREAM';
      final fileName = 'large_payload.bin';

      // 512 KB generated in 8 chunks of 64 KB
      const chunkSize = 64 * 1024;
      const totalChunks = 8;
      const totalSize = chunkSize * totalChunks;

      final stagingPath = await pathService.getStagingPath(transferId);
      final writer = FileDiskWriter(filePathService: pathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: totalSize,
        stagingPath: stagingPath,
      );

      final sink = Sha256().newHashSink();
      for (var i = 0; i < totalChunks; i++) {
        final chunk = Uint8List(chunkSize);
        for (var j = 0; j < chunkSize; j++) {
          chunk[j] = ((i * 17) + j) % 256;
        }
        sink.add(chunk);
        await writer.writeAt(offset: i * chunkSize, data: chunk);
      }
      await writer.flush();
      await writer.close();

      sink.close();
      final hashObj = await sink.hash();
      final expectedHash = hashObj.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(totalSize),
          mimeType: 'application/octet-stream',
          fileHash: expectedHash,
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: totalChunks,
          chunkSize: chunkSize,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      for (var i = 0; i < totalChunks; i++) {
        await db.markChunkReceived(transferId, i);
      }

      final result = await assemblyService.assembleTransfer(transferId: transferId);
      expect(result.isSuccess, isTrue);
      expect(result.fileSize, totalSize);
      expect(result.fileHash, expectedHash);

      final destFile = File(result.destinationPath);
      expect(await destFile.length(), totalSize);

      // Verify streamed hash of assembled file
      final calculatedDestHash = await assemblyService.calculateFileSha256(destFile);
      expect(calculatedDestHash, equals(expectedHash));
    });

    test('13. Pipeline integration with autoAssemble: false and true', () async {
      final pipeline = ChunkReceivingPipeline(
        localDeviceId: 'ML-LOCAL',
        database: db,
        pathService: pathService,
        assemblyService: assemblyService,
      );

      final cryptoService = FileTransferCryptoService();
      final aliceIdentityKey = Uint8List.fromList(List.generate(32, (i) => 1));
      final bobIdentityKey = Uint8List.fromList(List.generate(32, (i) => 2));
      final alicePub = Uint8List.fromList(List.generate(32, (i) => 3));
      final bobPub = Uint8List.fromList(List.generate(32, (i) => 4));
      final sharedSecret = Uint8List.fromList(List.generate(32, (i) => 5));

      final sessionAlice = EphemeralSession(
        sessionId: 'SESSION-STEP13-1',
        requestId: 'REQ-1',
        localId: 'ML-SENDER',
        peerId: 'ML-LOCAL',
        isInitiator: true,
        localIdentityPublicKey: aliceIdentityKey,
        peerIdentityPublicKey: bobIdentityKey,
        localEphemeralPublicKey: alicePub,
        peerEphemeralPublicKey: bobPub,
        sharedSecret: sharedSecret,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final sessionBob = EphemeralSession(
        sessionId: 'SESSION-STEP13-1',
        requestId: 'REQ-1',
        localId: 'ML-LOCAL',
        peerId: 'ML-SENDER',
        isInitiator: false,
        localIdentityPublicKey: bobIdentityKey,
        peerIdentityPublicKey: aliceIdentityKey,
        localEphemeralPublicKey: bobPub,
        peerEphemeralPublicKey: alicePub,
        sharedSecret: sharedSecret,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final transferId = 'FT-TEST-PIPELINE-AUTO';
      final fileName = 'auto_assembled.txt';

      final chunk0Data = Uint8List.fromList([1, 2, 3, 4]);
      final chunk1Data = Uint8List.fromList([5, 6, 7, 8]);
      final fullBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final expectedHash = await calculateSha256(fullBytes);

      final stagingPath = await pathService.getStagingPath(transferId);
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: transferId,
          conversationId: 'CONV-1',
          peerId: 'ML-SENDER',
          direction: 'incoming',
          fileName: fileName,
          fileSize: BigInt.from(8),
          mimeType: 'text/plain',
          fileHash: expectedHash,
          localPath: '',
          stagingPath: stagingPath,
          totalChunks: 2,
          chunkSize: 4,
          status: 'transferring',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final env0 = await cryptoService.encryptChunk(
        session: sessionAlice,
        transferId: transferId,
        originId: 'ML-SENDER',
        destinationId: 'ML-LOCAL',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        plaintext: chunk0Data,
      );

      final env1 = await cryptoService.encryptChunk(
        session: sessionAlice,
        transferId: transferId,
        originId: 'ML-SENDER',
        destinationId: 'ML-LOCAL',
        chunkIndex: 1,
        totalChunks: 2,
        offset: 4,
        plaintext: chunk1Data,
      );

      // Part A: autoAssemble = false (default) on chunk 0
      final res0 = await pipeline.receiveChunk(
        envelope: env0,
        session: sessionBob,
        autoAssemble: false,
      );
      expect(res0.isSuccess, isTrue);
      expect(res0.status, equals(FileTransferStatus.transferring));
      expect(res0.assemblyResult, isNull);

      // Part B: autoAssemble = true on chunk 1 (final chunk)
      final res1 = await pipeline.receiveChunk(
        envelope: env1,
        session: sessionBob,
        autoAssemble: true,
      );
      expect(res1.isSuccess, isTrue);
      expect(res1.status, equals(FileTransferStatus.completed));
      expect(res1.assemblyResult, isNotNull);
      expect(res1.assemblyResult!.isSuccess, isTrue);
      expect(res1.assemblyResult!.fileSize, 8);
      expect(res1.assemblyResult!.fileHash, equals(expectedHash));

      // Assembled output matches
      final assembledBytes = await File(res1.assemblyResult!.destinationPath).readAsBytes();
      expect(assembledBytes, equals(fullBytes));

      // SQLite is completed
      final finalTransfer = await db.getFileTransfer(transferId);
      expect(finalTransfer!.status, equals('completed'));
      expect(finalTransfer.localPath, equals(res1.assemblyResult!.destinationPath));

      await pipeline.closeAll();
    });
  });
}
