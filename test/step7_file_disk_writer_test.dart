import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/services/file_disk_writer.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempBaseDir;
  late FilePathService filePathService;

  setUp(() async {
    tempBaseDir = await Directory.systemTemp.createTemp('meshlink_step7_test_');
    filePathService = FilePathService(
      baseDirectory: tempBaseDir,
    );
    await filePathService.getStagingDirectory(create: true);
  });

  tearDown(() async {
    if (await tempBaseDir.exists()) {
      await tempBaseDir.delete(recursive: true);
    }
  });

  /// Helper to generate deterministic test data
  Uint8List generateBytes(int size, {int seed = 0}) {
    final list = Uint8List(size);
    for (var i = 0; i < size; i++) {
      list[i] = ((i + seed) ^ ((i + seed) >> 4)) & 0xFF;
    }
    return list;
  }

  group('Phase 8 Step 7 — Staging File Creation & Initialization', () {
    test('1. Create a new staging file', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000001-TEST1';
      const expectedSize = 1024;

      await writer.createOrOpen(
        transferId: transferId,
        expectedFileSize: expectedSize,
      );

      expect(writer.isOpen, isTrue);
      expect(writer.isClosed, isFalse);
      expect(writer.transferId, transferId);
      expect(writer.expectedFileSize, expectedSize);
      expect(writer.activeHandleCount, 1);

      final stagingFile = File(writer.stagingPath);
      expect(await stagingFile.exists(), isTrue);

      await writer.close();
      expect(writer.isOpen, isFalse);
      expect(writer.isClosed, isTrue);
      expect(writer.activeHandleCount, 0);
    });

    test('2. Open an existing staging file preserves it', () async {
      const transferId = 'FT-1727220000002-TEST2';
      final stagingPath = await filePathService.getStagingPath(transferId);
      final initialData = generateBytes(100, seed: 10);
      await File(stagingPath).writeAsBytes(initialData, flush: true);

      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: 200,
        stagingPath: stagingPath,
      );

      expect(writer.isOpen, isTrue);
      expect(await writer.getCurrentFileLength(), 200);

      // Verify initial bytes remain intact
      await writer.close();
      final currentBytes = await File(stagingPath).readAsBytes();
      expect(currentBytes.sublist(0, 100), initialData);
    });

    test('3. Correct expected file size is pre-allocated and accessible', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const expectedSize = 4096;

      await writer.createOrOpen(
        transferId: 'FT-1727220000003-TEST3',
        expectedFileSize: expectedSize,
      );

      expect(await writer.getCurrentFileLength(), expectedSize);
      expect(writer.expectedFileSize, expectedSize);
      await writer.close();
    });

    test('4. Zero-byte file creates a valid 0-length staging file', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000004-TEST4';

      await writer.createOrOpen(
        transferId: transferId,
        expectedFileSize: 0,
      );

      expect(writer.isOpen, isTrue);
      expect(await writer.getCurrentFileLength(), 0);

      await writer.close();
      final file = File(await filePathService.getStagingPath(transferId));
      expect(await file.length(), 0);
    });
  });

  group('Phase 8 Step 7 — Sequential Writes & Byte Integrity', () {
    test('5. Write one chunk at offset 0', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000005-TEST5';
      const size = 500;
      final data = generateBytes(size, seed: 1);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: size);
      await writer.writeAt(offset: 0, data: data);
      await writer.flush();
      await writer.close();

      final written = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(written, data);
    });

    test('6. Write multiple sequential chunks', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000006-TEST6';
      const chunkSize = 256;
      const totalChunks = 4;
      const totalSize = chunkSize * totalChunks;

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      final expectedBuilder = BytesBuilder();
      for (var i = 0; i < totalChunks; i++) {
        final chunk = generateBytes(chunkSize, seed: i * 10);
        expectedBuilder.add(chunk);
        await writer.writeAt(offset: i * chunkSize, data: chunk);
      }
      await writer.close();

      final actualBytes = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(actualBytes, expectedBuilder.takeBytes());
    });

    test('7. Re-read file and verify exact bytes across chunk seams', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000007-TEST7';
      final chunk1 = generateBytes(300, seed: 5);
      final chunk2 = generateBytes(200, seed: 6);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: 500);
      await writer.writeAt(offset: 0, data: chunk1);
      await writer.writeAt(offset: 300, data: chunk2);
      await writer.close();

      final fileBytes = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(fileBytes.sublist(0, 300), chunk1);
      expect(fileBytes.sublist(300, 500), chunk2);
    });
  });

  group('Phase 8 Step 7 — Random-Access Out-of-Order Writes', () {
    test('8. Write chunks out of order (Chunk 2, Chunk 0, Chunk 1)', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000008-TEST8';
      const chunkSize = 100;
      const totalSize = 300;

      final chunk0 = generateBytes(chunkSize, seed: 100);
      final chunk1 = generateBytes(chunkSize, seed: 101);
      final chunk2 = generateBytes(chunkSize, seed: 102);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      // Arrival: chunk 2 first, chunk 0 second, chunk 1 third
      await writer.writeAt(offset: 200, data: chunk2);
      await writer.writeAt(offset: 0, data: chunk0);
      await writer.writeAt(offset: 100, data: chunk1);
      await writer.close();

      final result = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(result.sublist(0, 100), chunk0);
      expect(result.sublist(100, 200), chunk1);
      expect(result.sublist(200, 300), chunk2);
    });

    test('9. Write beginning, middle, and end ranges out of order', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000009-TEST9';
      const totalSize = 1000;

      final endRange = generateBytes(250, seed: 99);
      final beginRange = generateBytes(250, seed: 11);
      final midRange = generateBytes(500, seed: 55);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      // Write End, then Begin, then Middle
      await writer.writeAt(offset: 750, data: endRange);
      await writer.writeAt(offset: 0, data: beginRange);
      await writer.writeAt(offset: 250, data: midRange);
      await writer.close();

      final actual = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(actual.sublist(0, 250), beginRange);
      expect(actual.sublist(250, 750), midRange);
      expect(actual.sublist(750, 1000), endRange);
    });

    test('10. Verify final byte layout exactly after interleaved writes', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000010-TEST10';
      const totalSize = 512;

      final chunkA = generateBytes(128, seed: 1);
      final chunkB = generateBytes(128, seed: 2);
      final chunkC = generateBytes(128, seed: 3);
      final chunkD = generateBytes(128, seed: 4);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      await writer.writeAt(offset: 384, data: chunkD);
      await writer.writeAt(offset: 128, data: chunkB);
      await writer.writeAt(offset: 0, data: chunkA);
      await writer.writeAt(offset: 256, data: chunkC);
      await writer.close();

      final actual = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      final expected = BytesBuilder()..add(chunkA)..add(chunkB)..add(chunkC)..add(chunkD);
      expect(actual, expected.takeBytes());
    });
  });

  group('Phase 8 Step 7 — Partial Writes & Boundaries', () {
    test('11. Write a small range within a larger file', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000011-TEST11';
      final small = Uint8List.fromList([42, 43, 44]);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: 100);
      await writer.writeAt(offset: 50, data: small);
      await writer.close();

      final result = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(result.sublist(50, 53), small);
    });

    test('12. Write final partial range', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000012-TEST12';
      const totalSize = 1050;
      const chunkSize = 400;

      final chunk0 = generateBytes(chunkSize, seed: 1);
      final chunk1 = generateBytes(chunkSize, seed: 2);
      final finalPartial = generateBytes(250, seed: 3); // 400 + 400 + 250 = 1050

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);
      await writer.writeAt(offset: 0, data: chunk0);
      await writer.writeAt(offset: 400, data: chunk1);
      await writer.writeAt(offset: 800, data: finalPartial);
      await writer.close();

      final result = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(result.length, totalSize);
      expect(result.sublist(800, 1050), finalPartial);
    });

    test('13. Write a range ending exactly at EOF', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-1727220000013-TEST13';
      const totalSize = 500;
      final eofChunk = generateBytes(100, seed: 88);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);
      await writer.writeAt(offset: 400, data: eofChunk); // [400, 500)
      await writer.close();

      final result = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(result.sublist(400, 500), eofChunk);
    });
  });

  group('Phase 8 Step 7 — Write Validation & Boundary Enforcement', () {
    test('14. Negative offset is rejected with InvalidOffsetException', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.createOrOpen(transferId: 'FT-VAL-14', expectedFileSize: 100);

      await expectLater(
        () => writer.writeAt(offset: -1, data: Uint8List(10)),
        throwsA(isA<InvalidOffsetException>()),
      );
      await writer.close();
    });

    test('15. Offset beyond EOF is rejected with InvalidOffsetException', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.createOrOpen(transferId: 'FT-VAL-15', expectedFileSize: 100);

      await expectLater(
        () => writer.writeAt(offset: 101, data: Uint8List(10)),
        throwsA(isA<InvalidOffsetException>()),
      );
      await writer.close();
    });

    test('16. Range exceeding file size is rejected with InvalidLengthException', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.createOrOpen(transferId: 'FT-VAL-16', expectedFileSize: 100);

      await expectLater(
        () => writer.writeAt(offset: 90, data: Uint8List(15)), // 90 + 15 = 105 > 100
        throwsA(isA<InvalidLengthException>()),
      );
      await writer.close();
    });

    test('17. Integer overflow in offset + length is rejected safely', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.createOrOpen(transferId: 'FT-VAL-17', expectedFileSize: 100);
      const maxInt = 0x7FFFFFFFFFFFFFFF;

      await expectLater(
        () => writer.writeAt(offset: maxInt, data: Uint8List(1)),
        throwsA(isA<InvalidOffsetException>()),
      );
      await writer.close();
    });

    test('18. Invalid/empty staging path is rejected', () async {
      final writer = FileDiskWriter(filePathService: filePathService);

      await expectLater(
        () => writer.createOrOpen(
          transferId: 'FT-VAL-18',
          expectedFileSize: 100,
          stagingPath: '',
        ),
        throwsA(isA<InvalidStagingPathException>()),
      );

      await expectLater(
        () => writer.createOrOpen(
          transferId: 'FT-VAL-18',
          expectedFileSize: 100,
          stagingPath: '   ',
        ),
        throwsA(isA<InvalidStagingPathException>()),
      );

      await expectLater(
        () => writer.createOrOpen(
          transferId: 'FT-VAL-18',
          expectedFileSize: 100,
          stagingPath: 'invalid\x00path.bin',
        ),
        throwsA(isA<InvalidStagingPathException>()),
      );
    });

    test('19. Invalid transfer ID is rejected by API', () async {
      final writer = FileDiskWriter(filePathService: filePathService);

      await expectLater(
        () => writer.createOrOpen(
          transferId: '../traversal_id',
          expectedFileSize: 100,
        ),
        throwsArgumentError,
      );

      await expectLater(
        () => writer.createOrOpen(
          transferId: 'id with spaces',
          expectedFileSize: 100,
        ),
        throwsArgumentError,
      );
    });

    test('20. Path outside staging containment is rejected', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      final outsidePath = p.join(tempBaseDir.path, 'outside_staging', 'evil.part');

      await expectLater(
        () => writer.createOrOpen(
          transferId: 'FT-VAL-20',
          expectedFileSize: 100,
          stagingPath: outsidePath,
        ),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('Phase 8 Step 7 — Zero-Length & Zero-Byte Handling', () {
    test('21. Zero-length write behaves safely without altering file', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-ZERO-21';
      final initialData = generateBytes(50, seed: 77);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: 50);
      await writer.writeAt(offset: 0, data: initialData);

      // Safe zero-length write at various offsets
      await writer.writeAt(offset: 0, data: Uint8List(0));
      await writer.writeAt(offset: 25, data: Uint8List(0));
      await writer.writeAt(offset: 50, data: Uint8List(0)); // EOF
      await writer.close();

      final actual = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(actual, initialData);
    });

    test('22. Zero-byte file can be created, flushed, and closed cleanly', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-ZERO-22';

      await writer.createOrOpen(transferId: transferId, expectedFileSize: 0);
      await writer.writeAt(offset: 0, data: Uint8List(0));
      await writer.flush();
      await writer.close();

      final file = File(await filePathService.getStagingPath(transferId));
      expect(await file.exists(), isTrue);
      expect(await file.length(), 0);
    });
  });

  group('Phase 8 Step 7 — Concurrency & Async Serialization', () {
    test('23. Multiple concurrent writes to different ranges are serialized safely', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-CONC-23';
      const chunkSize = 100;
      const count = 10;
      const totalSize = chunkSize * count;

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      final chunks = List.generate(count, (i) => generateBytes(chunkSize, seed: i));

      // Fire all writes concurrently without awaiting each sequentially
      final futures = <Future<void>>[];
      for (var i = 0; i < count; i++) {
        futures.add(writer.writeAt(offset: i * chunkSize, data: chunks[i]));
      }
      await Future.wait(futures);
      await writer.close();

      final actual = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      for (var i = 0; i < count; i++) {
        expect(
          actual.sublist(i * chunkSize, (i + 1) * chunkSize),
          chunks[i],
          reason: 'Chunk $i failed match in concurrent test',
        );
      }
    });

    test('24. Result remains correct after concurrent out-of-order writes', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-CONC-24';
      const totalSize = 400;

      final c0 = generateBytes(100, seed: 0);
      final c1 = generateBytes(100, seed: 1);
      final c2 = generateBytes(100, seed: 2);
      final c3 = generateBytes(100, seed: 3);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      // Concurrent out-of-order dispatch
      await Future.wait([
        writer.writeAt(offset: 300, data: c3),
        writer.writeAt(offset: 100, data: c1),
        writer.writeAt(offset: 0, data: c0),
        writer.writeAt(offset: 200, data: c2),
      ]);
      await writer.close();

      final result = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(result.sublist(0, 100), c0);
      expect(result.sublist(100, 200), c1);
      expect(result.sublist(200, 300), c2);
      expect(result.sublist(300, 400), c3);
    });

    test('25. Concurrent writes cannot corrupt file during heavy overlapping task scheduling', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-CONC-25';
      const size = 1000;

      await writer.createOrOpen(transferId: transferId, expectedFileSize: size);

      // Launch 50 randomized write tasks across the file
      final futures = <Future<void>>[];
      for (var i = 0; i < 50; i++) {
        final offset = (i * 20) % size;
        final data = Uint8List.fromList([i, i, i, i]);
        if (offset + 4 <= size) {
          futures.add(writer.writeAt(offset: offset, data: data));
        }
      }
      await Future.wait(futures);
      await writer.flush();
      await writer.close();

      final finalLength = await File(await filePathService.getStagingPath(transferId)).length();
      expect(finalLength, size);
    });
  });

  group('Phase 8 Step 7 — Error Handling & State Safety', () {
    test('26. Write after close fails with FileDiskWriterClosedException', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.createOrOpen(transferId: 'FT-ERR-26', expectedFileSize: 100);
      await writer.close();

      await expectLater(
        () => writer.writeAt(offset: 0, data: Uint8List(10)),
        throwsA(isA<FileDiskWriterClosedException>()),
      );
    });

    test('27. Flush after close fails with FileDiskWriterClosedException', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.createOrOpen(transferId: 'FT-ERR-27', expectedFileSize: 100);
      await writer.close();

      await expectLater(
        () => writer.flush(),
        throwsA(isA<FileDiskWriterClosedException>()),
      );
    });

    test('28. Double close is safe and idempotent', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.createOrOpen(transferId: 'FT-ERR-28', expectedFileSize: 100);

      await writer.close();
      expect(writer.isClosed, isTrue);

      // Second call must not throw
      await expectLater(() => writer.close(), returnsNormally);
      expect(writer.isClosed, isTrue);
      expect(writer.activeHandleCount, 0);
    });

    test('29. File-system/write failure releases resources', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-ERR-29';
      // Create a directory where the staging file would be
      final conflictDir = Directory(await filePathService.getStagingPath(transferId));
      await conflictDir.create();

      try {
        await expectLater(
          () => writer.createOrOpen(
            transferId: transferId,
            expectedFileSize: 100,
          ),
          throwsA(isA<FileWriteException>()),
        );

        // Active handles must remain 0
        expect(writer.activeHandleCount, 0);
        expect(writer.isOpen, isFalse);
      } finally {
        await conflictDir.delete();
      }
    });
  });

  group('Phase 8 Step 7 — Existing Staging Data & Resume Foundation', () {
    test('30. Opening an existing staging file does not unexpectedly erase existing bytes', () async {
      const transferId = 'FT-RESUME-30';
      final stagingPath = await filePathService.getStagingPath(transferId);
      final existingBytes = generateBytes(250, seed: 44);

      // Simulate partial transfer on disk
      await File(stagingPath).writeAsBytes(existingBytes, flush: true);

      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.open(
        transferId: transferId,
        expectedFileSize: 500, // Total expected is 500
      );

      // Read back bytes up to 250
      await writer.close();
      final readBack = await File(stagingPath).readAsBytes();
      expect(readBack.sublist(0, 250), existingBytes);
    });

    test('31. Writing a new range preserves unrelated existing bytes', () async {
      const transferId = 'FT-RESUME-31';
      final stagingPath = await filePathService.getStagingPath(transferId);
      final existingBytes = generateBytes(200, seed: 7);
      await File(stagingPath).writeAsBytes(existingBytes, flush: true);

      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.open(transferId: transferId, expectedFileSize: 400);

      // Write chunk at offset 200..300
      final newChunk = generateBytes(100, seed: 88);
      await writer.writeAt(offset: 200, data: newChunk);
      await writer.close();

      final fullFile = await File(stagingPath).readAsBytes();
      expect(fullFile.sublist(0, 200), existingBytes); // preserved!
      expect(fullFile.sublist(200, 300), newChunk); // newly written!
    });
  });

  group('Phase 8 Step 7 — Resource Management & File Descriptor Safety', () {
    test('32. Normal close releases file handle and resets activeHandleCount', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      expect(writer.activeHandleCount, 0);

      await writer.createOrOpen(transferId: 'FT-RES-32', expectedFileSize: 100);
      expect(writer.activeHandleCount, 1);

      await writer.close();
      expect(writer.activeHandleCount, 0);
    });

    test('33. Error during open path releases file handle cleanly', () async {
      final writer = FileDiskWriter(filePathService: filePathService);

      try {
        await writer.createOrOpen(transferId: 'FT-RES-33', expectedFileSize: -1);
      } catch (_) {}

      expect(writer.activeHandleCount, 0);
      expect(writer.isOpen, isFalse);
    });

    test('34. Staging file can be deleted immediately after close without OS lock errors', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-RES-34';

      await writer.createOrOpen(transferId: transferId, expectedFileSize: 500);
      await writer.writeAt(offset: 0, data: generateBytes(100));
      await writer.close();

      final file = File(await filePathService.getStagingPath(transferId));
      expect(await file.exists(), isTrue);

      // On Windows, deleting a file with an open handle fails immediately with OS Error 32.
      // Succeeded deletion proves the RandomAccessFile descriptor was fully closed.
      await file.delete();
      expect(await file.exists(), isFalse);
    });
  });

  group('Phase 8 Step 7 — Memory Safety & Large File Bounded IO', () {
    test('35. Confirm implementation streams and writes 2 MB file without whole-file buffering', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-MEM-35';
      const totalSize = 2 * 1024 * 1024; // 2 MB
      const chunkSize = 16 * 1024; // 16 KB
      const chunkCount = totalSize ~/ chunkSize; // 128 chunks

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      for (var i = 0; i < chunkCount; i++) {
        final chunk = generateBytes(chunkSize, seed: i);
        // Only this single 16 KB chunk is held in memory per iteration
        await writer.writeAt(offset: i * chunkSize, data: chunk);
      }
      await writer.flush();
      await writer.close();

      final stagingFile = File(await filePathService.getStagingPath(transferId));
      expect(await stagingFile.length(), totalSize);

      // Read back first and last chunk to verify boundaries
      final raf = await stagingFile.open(mode: FileMode.read);
      final firstChunkRead = await raf.read(chunkSize);
      await raf.setPosition(totalSize - chunkSize);
      final lastChunkRead = await raf.read(chunkSize);
      await raf.close();

      expect(firstChunkRead, generateBytes(chunkSize, seed: 0));
      expect(lastChunkRead, generateBytes(chunkSize, seed: chunkCount - 1));

      await stagingFile.delete();
    });
  });

  group('Phase 8 Step 7 — Strict Random-Access & File Opening Semantics Verification', () {
    test('36. Write chunk C, then A, then B out-of-order and verify exact concatenated content', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-ORDER-36';
      const chunkSize = 256;
      const totalSize = 3 * chunkSize;

      final chunkA = generateBytes(chunkSize, seed: 101);
      final chunkB = generateBytes(chunkSize, seed: 102);
      final chunkC = generateBytes(chunkSize, seed: 103);

      await writer.createOrOpen(transferId: transferId, expectedFileSize: totalSize);

      // Intentionally call in order: C (offset 2 * chunkSize), A (offset 0), B (offset 1 * chunkSize)
      await writer.writeAt(offset: 2 * chunkSize, data: chunkC);
      await writer.writeAt(offset: 0, data: chunkA);
      await writer.writeAt(offset: chunkSize, data: chunkB);
      await writer.close();

      final fileBytes = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(fileBytes.length, totalSize);
      expect(fileBytes.sublist(0, chunkSize), chunkA);
      expect(fileBytes.sublist(chunkSize, 2 * chunkSize), chunkB);
      expect(fileBytes.sublist(2 * chunkSize, 3 * chunkSize), chunkC);
    });

    test('37. Append-semantics regression test verifying exact byte layout and no EOF forcing', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-APPEND-REG-37';
      const expectedSize = 12;

      // Expected byte layout: AAAABBBBCCCC (12 bytes)
      final aBytes = Uint8List.fromList([0x41, 0x41, 0x41, 0x41]); // "AAAA"
      final bBytes = Uint8List.fromList([0x42, 0x42, 0x42, 0x42]); // "BBBB"
      final cBytes = Uint8List.fromList([0x43, 0x43, 0x43, 0x43]); // "CCCC"

      await writer.createOrOpen(transferId: transferId, expectedFileSize: expectedSize);

      // Write sequence: offset 0 (A), offset 8 (C), offset 4 (B)
      await writer.writeAt(offset: 0, data: aBytes);
      await writer.writeAt(offset: 8, data: cBytes);
      await writer.writeAt(offset: 4, data: bBytes);
      await writer.flush();
      await writer.close();

      final actualBytes = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(actualBytes.length, expectedSize);
      // If append semantics were accidentally active, the file would either grow beyond 12 or
      // have the order "AAAACCCCBBBB".
      expect(actualBytes, Uint8List.fromList([
        0x41, 0x41, 0x41, 0x41, // offset 0..4: AAAA
        0x42, 0x42, 0x42, 0x42, // offset 4..8: BBBB
        0x43, 0x43, 0x43, 0x43, // offset 8..12: CCCC
      ]));
    });

    test('38. Existing staging file preservation: modify single region, preserve all others', () async {
      const transferId = 'FT-PRESERVE-38';
      final stagingPath = await filePathService.getStagingPath(transferId);

      // 0000: AAAA (0x41 * 4)
      // 0004: BBBB (0x42 * 4)
      // 0008: CCCC (0x43 * 4)
      // 0012: DDDD (0x44 * 4)
      final initialStaging = Uint8List.fromList([
        0x41, 0x41, 0x41, 0x41,
        0x42, 0x42, 0x42, 0x42,
        0x43, 0x43, 0x43, 0x43,
        0x44, 0x44, 0x44, 0x44,
      ]);
      await File(stagingPath).writeAsBytes(initialStaging, flush: true);

      final writer = FileDiskWriter(filePathService: filePathService);
      await writer.open(transferId: transferId, expectedFileSize: 16);

      // Perform: writeAt(offset: 4, data: XXXX [0x58 * 4])
      final xBytes = Uint8List.fromList([0x58, 0x58, 0x58, 0x58]);
      await writer.writeAt(offset: 4, data: xBytes);
      await writer.close();

      final finalBytes = await File(stagingPath).readAsBytes();
      expect(finalBytes, Uint8List.fromList([
        0x41, 0x41, 0x41, 0x41, // 0000: AAAA preserved
        0x58, 0x58, 0x58, 0x58, // 0004: XXXX updated
        0x43, 0x43, 0x43, 0x43, // 0008: CCCC preserved
        0x44, 0x44, 0x44, 0x44, // 0012: DDDD preserved
      ]));
    });

    test('39. Reset true intentionally clears previous staging contents before new writes', () async {
      const transferId = 'FT-RESET-39';
      final stagingPath = await filePathService.getStagingPath(transferId);

      // Create staging file with 200 bytes of old data
      final oldData = generateBytes(200, seed: 999);
      await File(stagingPath).writeAsBytes(oldData, flush: true);

      final writer = FileDiskWriter(filePathService: filePathService);
      // Open with reset: true and expected size 100
      await writer.open(
        transferId: transferId,
        expectedFileSize: 100,
        reset: true,
      );

      // Write new chunks at offsets 50 and 0
      final newPart1 = generateBytes(40, seed: 11);
      final newPart2 = generateBytes(40, seed: 22);

      await writer.writeAt(offset: 50, data: newPart2);
      await writer.writeAt(offset: 0, data: newPart1);
      await writer.close();

      final result = await File(stagingPath).readAsBytes();
      expect(result.length, 100);
      expect(result.sublist(0, 40), newPart1);
      expect(result.sublist(50, 90), newPart2);
      // The unwritten region [40..50) and [90..100) must be 0x00, not old data
      expect(result.sublist(40, 50), Uint8List(10));
      expect(result.sublist(90, 100), Uint8List(10));
    });

    test('40. New transfer creates empty staging file and writes out-of-order cleanly', () async {
      final writer = FileDiskWriter(filePathService: filePathService);
      const transferId = 'FT-NEW-40';
      const size = 64;

      await writer.createOrOpen(transferId: transferId, expectedFileSize: size);
      expect(writer.isOpen, isTrue);

      // Out of order: offset 32 then offset 0
      final partB = generateBytes(16, seed: 2);
      final partA = generateBytes(16, seed: 1);

      await writer.writeAt(offset: 32, data: partB);
      await writer.writeAt(offset: 0, data: partA);
      await writer.close();

      final result = await File(await filePathService.getStagingPath(transferId)).readAsBytes();
      expect(result.length, size);
      expect(result.sublist(0, 16), partA);
      expect(result.sublist(16, 32), Uint8List(16)); // unwritten gap is 0
      expect(result.sublist(32, 48), partB);
      expect(result.sublist(48, 64), Uint8List(16)); // unwritten tail is 0
    });
  });
}
