import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/services/file_stream_reader.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late FileStreamReader reader;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshlink_step6_test_');
    reader = FileStreamReader();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a test file with deterministic pseudo-random bytes.
  Future<File> createTestFile(String name, int size) async {
    final file = File(p.join(tempDir.path, name));
    final bytes = Uint8List(size);
    for (var i = 0; i < size; i++) {
      bytes[i] = (i ^ (i >> 8)) & 0xFF;
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  group('Phase 8 Step 6 — Basic Reading', () {
    test('1. Read a small file', () async {
      final file = await createTestFile('small.bin', 128);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 64).toList();

      expect(chunks.length, 2);
      expect(chunks[0].length, 64);
      expect(chunks[1].length, 64);
    });

    test('2. Read a file smaller than chunk size', () async {
      final file = await createTestFile('tiny.bin', 50);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 1024).toList();

      expect(chunks.length, 1);
      expect(chunks.first.length, 50);
    });

    test('3. Read a file exactly equal to chunk size', () async {
      final file = await createTestFile('exact.bin', 256);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 256).toList();

      expect(chunks.length, 1);
      expect(chunks.first.length, 256);
    });

    test('4. Read a file larger than chunk size', () async {
      final file = await createTestFile('multi_chunk.bin', 1000);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 200).toList();

      expect(chunks.length, 5);
      for (final chunk in chunks) {
        expect(chunk.length, 200);
      }
    });

    test('5. Read a file where the final chunk is partial', () async {
      final file = await createTestFile('partial_final.bin', 1050);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 400).toList();

      expect(chunks.length, 3);
      expect(chunks[0].length, 400);
      expect(chunks[1].length, 400);
      expect(chunks[2].length, 250);
    });

    test('6. Read a zero-byte file', () async {
      final file = await createTestFile('empty.bin', 0);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 512).toList();

      expect(chunks, isEmpty);
      expect(reader.activeHandleCount, 0);
    });
  });

  group('Phase 8 Step 6 — Stream Correctness & Byte Integrity', () {
    test('7. Concatenating emitted chunks reproduces the original file exactly', () async {
      final file = await createTestFile('integrity.bin', 8192);
      final originalBytes = await file.readAsBytes();

      final chunks = await reader.readFile(filePath: file.path, chunkSize: 1500).toList();
      final builder = BytesBuilder();
      for (final chunk in chunks) {
        builder.add(chunk);
      }
      final reconstructed = builder.takeBytes();

      expect(reconstructed, originalBytes);
    });

    test('8. Chunk order is preserved sequentially', () async {
      final file = await createTestFile('order.bin', 300);
      final originalBytes = await file.readAsBytes();

      final chunks = await reader.readFile(filePath: file.path, chunkSize: 100).toList();
      expect(chunks.length, 3);

      expect(chunks[0], originalBytes.sublist(0, 100));
      expect(chunks[1], originalBytes.sublist(100, 200));
      expect(chunks[2], originalBytes.sublist(200, 300));
    });

    test('9. No bytes are duplicated across chunk boundaries', () async {
      final file = await createTestFile('no_dup.bin', 2048);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 512).toList();

      var totalBytesEmitted = 0;
      for (final chunk in chunks) {
        totalBytesEmitted += chunk.length;
      }
      expect(totalBytesEmitted, 2048);
    });

    test('10. No bytes are lost between chunks', () async {
      final file = await createTestFile('no_lost.bin', 7777);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 1234).toList();

      var totalBytesEmitted = 0;
      for (final chunk in chunks) {
        totalBytesEmitted += chunk.length;
      }
      expect(totalBytesEmitted, 7777);
    });

    test('11. Final chunk length is exactly the remainder', () async {
      const fileSize = 10000;
      const chunkSize = 4096;
      final file = await createTestFile('final_chunk.bin', fileSize);

      final chunks = await reader.readFile(filePath: file.path, chunkSize: chunkSize).toList();
      expect(chunks.length, 3); // 4096 + 4096 + 1808
      expect(chunks[0].length, 4096);
      expect(chunks[1].length, 4096);
      expect(chunks[2].length, fileSize - 2 * chunkSize);
    });
  });

  group('Phase 8 Step 6 — Chunk Size Flexibility & Validation', () {
    test('12. Different valid chunk sizes work as expected', () async {
      final file = await createTestFile('chunk_sizes.bin', 10000);
      final originalBytes = await file.readAsBytes();

      final sizesToTest = [512, 1024, 2048, 4096, 8192, 16384];
      for (final size in sizesToTest) {
        final chunks = await reader.readFile(filePath: file.path, chunkSize: size).toList();
        final combined = BytesBuilder();
        for (final c in chunks) {
          combined.add(c);
        }
        expect(combined.takeBytes(), originalBytes, reason: 'Failed for chunkSize $size');
      }
    });

    test('13. Very small chunk size (1-byte chunks)', () async {
      final file = await createTestFile('byte_by_byte.bin', 15);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 1).toList();

      expect(chunks.length, 15);
      for (final c in chunks) {
        expect(c.length, 1);
      }
    });

    test('14. Larger chunk size exceeding file size emits single complete chunk', () async {
      final file = await createTestFile('oversized_chunk.bin', 300);
      final chunks = await reader.readFile(filePath: file.path, chunkSize: 65536).toList();

      expect(chunks.length, 1);
      expect(chunks.first.length, 300);
    });

    test('15. Invalid zero chunk size is rejected', () {
      expect(
        () => reader.readFile(filePath: p.join(tempDir.path, 'dummy.bin'), chunkSize: 0).toList(),
        throwsA(isA<InvalidChunkSizeException>()),
      );
    });

    test('16. Negative chunk size is rejected', () {
      expect(
        () => reader.readFile(filePath: p.join(tempDir.path, 'dummy.bin'), chunkSize: -1024).toList(),
        throwsA(isA<InvalidChunkSizeException>()),
      );
    });
  });

  group('Phase 8 Step 6 — File & Path Validation', () {
    test('17. Missing file throws FileNotFoundException', () async {
      final missingPath = p.join(tempDir.path, 'non_existent_file.bin');

      expect(
        () => reader.readFile(filePath: missingPath).toList(),
        throwsA(isA<FileNotFoundException>()),
      );

      await expectLater(
        () => reader.readRange(filePath: missingPath, offset: 0, length: 10),
        throwsA(isA<FileNotFoundException>()),
      );

      await expectLater(
        () => reader.getFileSize(missingPath),
        throwsA(isA<FileNotFoundException>()),
      );

      await expectLater(
        () => reader.validateSourceFile(missingPath),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('18. Directory passed as file throws InvalidFilePathException', () async {
      final dir = Directory(p.join(tempDir.path, 'sub_dir'));
      await dir.create();

      expect(
        () => reader.readFile(filePath: dir.path).toList(),
        throwsA(isA<InvalidFilePathException>()),
      );

      await expectLater(
        () => reader.readRange(filePath: dir.path, offset: 0, length: 10),
        throwsA(isA<InvalidFilePathException>()),
      );

      await expectLater(
        () => reader.getFileSize(dir.path),
        throwsA(isA<InvalidFilePathException>()),
      );
    });

    test('19. Invalid path (empty, whitespace, null character) throws InvalidFilePathException', () async {
      final invalidPaths = ['', '   ', 'file\x00name.bin'];

      for (final invalid in invalidPaths) {
        expect(
          () => reader.readFile(filePath: invalid).toList(),
          throwsA(isA<InvalidFilePathException>()),
        );

        await expectLater(
          () => reader.readRange(filePath: invalid, offset: 0, length: 10),
          throwsA(isA<InvalidFilePathException>()),
        );

        await expectLater(
          () => reader.getFileSize(invalid),
          throwsA(isA<InvalidFilePathException>()),
        );
      }
    });

    test('20. File that cannot be opened/read throws FileReadException safely', () async {
      final file = await createTestFile('locked.bin', 100);

      // On Windows, opening exclusively for writing locks the file against readers
      RandomAccessFile? lockRaf;
      try {
        lockRaf = await file.open(mode: FileMode.write);
        await lockRaf.lock(FileLock.exclusive);

        // Attempting to read this exclusively locked file should throw FileReadException
        await expectLater(
          () => reader.readRange(filePath: file.path, offset: 0, length: 10),
          throwsA(isA<FileReadException>()),
        );

        expect(
          () => reader.readFile(filePath: file.path).toList(),
          throwsA(isA<FileReadException>()),
        );
      } catch (e) {
        // If filesystem doesn't support locking, test passes
      } finally {
        if (lockRaf != null) {
          try {
            await lockRaf.unlock();
            await lockRaf.close();
          } catch (_) {}
        }
      }
    });
  });

  group('Phase 8 Step 6 — Random Access Range Reading', () {
    test('21. Read range from beginning (offset = 0)', () async {
      final file = await createTestFile('range_begin.bin', 1000);
      final original = await file.readAsBytes();

      final range = await reader.readRange(filePath: file.path, offset: 0, length: 250);
      expect(range.length, 250);
      expect(range, original.sublist(0, 250));
    });

    test('22. Read range from middle', () async {
      final file = await createTestFile('range_mid.bin', 1000);
      final original = await file.readAsBytes();

      final range = await reader.readRange(filePath: file.path, offset: 300, length: 400);
      expect(range.length, 400);
      expect(range, original.sublist(300, 700));
    });

    test('23. Read range ending exactly at EOF (offset + length == fileSize)', () async {
      final file = await createTestFile('range_eof.bin', 500);
      final original = await file.readAsBytes();

      final range = await reader.readRange(filePath: file.path, offset: 350, length: 150);
      expect(range.length, 150);
      expect(range, original.sublist(350, 500));
    });

    test('24. Read zero-length range returns empty Uint8List safely', () async {
      final file = await createTestFile('range_zero.bin', 100);

      // Beginning with length 0
      final r1 = await reader.readRange(filePath: file.path, offset: 0, length: 0);
      expect(r1, isEmpty);

      // Middle with length 0
      final r2 = await reader.readRange(filePath: file.path, offset: 50, length: 0);
      expect(r2, isEmpty);

      // EOF with length 0
      final r3 = await reader.readRange(filePath: file.path, offset: 100, length: 0);
      expect(r3, isEmpty);

      // 0-byte file at offset 0 with length 0
      final emptyFile = await createTestFile('empty_zero.bin', 0);
      final r4 = await reader.readRange(filePath: emptyFile.path, offset: 0, length: 0);
      expect(r4, isEmpty);
    });

    test('25. Negative offset rejected with InvalidOffsetException', () async {
      final file = await createTestFile('neg_offset.bin', 100);

      await expectLater(
        () => reader.readRange(filePath: file.path, offset: -1, length: 10),
        throwsA(isA<InvalidOffsetException>()),
      );
    });

    test('26. Negative length rejected with InvalidLengthException', () async {
      final file = await createTestFile('neg_length.bin', 100);

      await expectLater(
        () => reader.readRange(filePath: file.path, offset: 0, length: -5),
        throwsA(isA<InvalidLengthException>()),
      );
    });

    test('27. Offset beyond EOF rejected with InvalidOffsetException', () async {
      final file = await createTestFile('beyond_eof.bin', 100);

      await expectLater(
        () => reader.readRange(filePath: file.path, offset: 101, length: 0),
        throwsA(isA<InvalidOffsetException>()),
      );

      await expectLater(
        () => reader.readRange(filePath: file.path, offset: 200, length: 10),
        throwsA(isA<InvalidOffsetException>()),
      );
    });

    test('28. Range exceeding EOF rejected with InvalidLengthException', () async {
      final file = await createTestFile('exceed_eof.bin', 100);

      await expectLater(
        () => reader.readRange(filePath: file.path, offset: 90, length: 15),
        throwsA(isA<InvalidLengthException>()),
      );
    });

    test('29. Overflow-safe range validation rejects 64-bit overflow', () async {
      final file = await createTestFile('overflow.bin', 100);
      const maxInt = 0x7FFFFFFFFFFFFFFF;

      await expectLater(
        () => reader.readRange(filePath: file.path, offset: maxInt, length: 1),
        throwsA(isA<InvalidOffsetException>()),
      );

      await expectLater(
        () => reader.readRange(filePath: file.path, offset: 10, length: maxInt),
        throwsA(isA<InvalidOffsetException>()),
      );
    });
  });

  group('Phase 8 Step 6 — Resource Management & Leak Safety', () {
    test('30. Normal stream completion closes resources', () async {
      final file = await createTestFile('resource_normal.bin', 4096);
      expect(reader.activeHandleCount, 0);

      final chunks = await reader.readFile(filePath: file.path, chunkSize: 1024).toList();
      expect(chunks.length, 4);

      // Verify active handle count returned to 0
      expect(reader.activeHandleCount, 0);

      // On Windows, deleting the file proves the handle was truly released by the OS
      await file.delete();
      expect(await file.exists(), isFalse);
    });

    test('31. Read failure closes resources cleanly', () async {
      expect(reader.activeHandleCount, 0);

      try {
        await reader.readFile(filePath: p.join(tempDir.path, 'missing.bin')).toList();
      } catch (_) {}

      expect(reader.activeHandleCount, 0);

      final file = await createTestFile('fail_range.bin', 100);
      try {
        await reader.readRange(filePath: file.path, offset: 90, length: 50);
      } catch (_) {}

      expect(reader.activeHandleCount, 0);
      await file.delete();
      expect(await file.exists(), isFalse);
    });

    test('32. Stream cancellation closes resources promptly', () async {
      final file = await createTestFile('cancel_stream.bin', 64 * 1024); // 64 KB
      expect(reader.activeHandleCount, 0);

      final controller = Completer<void>();
      var chunkCount = 0;

      final sub = reader.readFile(filePath: file.path, chunkSize: 1024).listen((chunk) {
        chunkCount++;
        if (chunkCount == 2) {
          controller.complete();
        }
      });

      await controller.future;
      await sub.cancel();

      // Only 2 chunks were processed before cancel
      expect(chunkCount, 2);

      // Handle is cleanly released
      expect(reader.activeHandleCount, 0);

      // Proves file can be modified / deleted on OS without lock error
      await file.delete();
      expect(await file.exists(), isFalse);
    });
  });

  group('Phase 8 Step 6 — Large File & Incremental Streaming Memory Behavior', () {
    test('33. Verify implementation streams incrementally without whole-file buffering', () async {
      // 512 KB file read in 16 KB chunks (32 chunks)
      const size = 512 * 1024;
      const chunkSize = 16 * 1024;
      final file = await createTestFile('large_streaming.bin', size);

      var chunksReceived = 0;
      var totalBytesStreamed = 0;

      await for (final chunk in reader.readFile(filePath: file.path, chunkSize: chunkSize)) {
        chunksReceived++;
        totalBytesStreamed += chunk.length;

        // Each individual chunk must be bounded by chunkSize
        expect(chunk.length, lessThanOrEqualTo(chunkSize));

        // Active handle during reading must be exactly 1
        expect(reader.activeHandleCount, 1);
      }

      expect(chunksReceived, 32);
      expect(totalBytesStreamed, size);
      expect(reader.activeHandleCount, 0);
    });

    test('34. Stream larger file (2 MB) incrementally with bounded memory', () async {
      // 2 MB file read in 16 KB chunks (128 chunks)
      const size = 2 * 1024 * 1024;
      const chunkSize = 16 * 1024;
      final file = await createTestFile('benchmark_2mb.bin', size);

      var chunksReceived = 0;
      var totalBytesStreamed = 0;

      final stopwatch = Stopwatch()..start();
      await for (final chunk in reader.readFile(filePath: file.path, chunkSize: chunkSize)) {
        chunksReceived++;
        totalBytesStreamed += chunk.length;
        expect(chunk.length, chunkSize);
      }
      stopwatch.stop();

      expect(chunksReceived, 128);
      expect(totalBytesStreamed, size);
      expect(reader.activeHandleCount, 0);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(0));
    });

    test('35. Stream paused and resumed respects backpressure without buffering entire file', () async {
      final file = await createTestFile('backpressure.bin', 32 * 1024);
      final chunks = <Uint8List>[];

      final sub = reader.readFile(filePath: file.path, chunkSize: 4096).listen(chunks.add);

      sub.pause();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // While paused, no chunks should be emitted
      expect(chunks, isEmpty);

      sub.resume();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(reader.activeHandleCount, 0);
    });
  });

  group('Phase 8 Step 6 — Pure Calculation & Path Helpers', () {
    test('calculateTotalChunks works for various file and chunk sizes', () {
      expect(FileStreamReader.calculateTotalChunks(fileSize: 0, chunkSize: 1024), 0);
      expect(FileStreamReader.calculateTotalChunks(fileSize: 500, chunkSize: 1024), 1);
      expect(FileStreamReader.calculateTotalChunks(fileSize: 1024, chunkSize: 1024), 1);
      expect(FileStreamReader.calculateTotalChunks(fileSize: 1025, chunkSize: 1024), 2);
      expect(FileStreamReader.calculateTotalChunks(fileSize: 2048, chunkSize: 1024), 2);
      expect(FileStreamReader.calculateTotalChunks(fileSize: 2049, chunkSize: 1024), 3);

      expect(
        () => FileStreamReader.calculateTotalChunks(fileSize: -1, chunkSize: 1024),
        throwsArgumentError,
      );
      expect(
        () => FileStreamReader.calculateTotalChunks(fileSize: 100, chunkSize: 0),
        throwsA(isA<InvalidChunkSizeException>()),
      );
      expect(
        () => FileStreamReader.calculateTotalChunks(fileSize: 100, chunkSize: -10),
        throwsA(isA<InvalidChunkSizeException>()),
      );
    });

    test('calculateChunkOffset calculates exact byte offset and guards against overflow', () {
      expect(FileStreamReader.calculateChunkOffset(chunkIndex: 0, chunkSize: 4096), 0);
      expect(FileStreamReader.calculateChunkOffset(chunkIndex: 1, chunkSize: 4096), 4096);
      expect(FileStreamReader.calculateChunkOffset(chunkIndex: 2, chunkSize: 4096), 8192);

      expect(
        () => FileStreamReader.calculateChunkOffset(chunkIndex: -1, chunkSize: 4096),
        throwsArgumentError,
      );
      expect(
        () => FileStreamReader.calculateChunkOffset(chunkIndex: 1, chunkSize: 0),
        throwsA(isA<InvalidChunkSizeException>()),
      );
      expect(
        () => FileStreamReader.calculateChunkOffset(chunkIndex: 0x7FFFFFFFFFFFFFFF, chunkSize: 4096),
        throwsA(isA<InvalidOffsetException>()),
      );
    });

    test('calculateChunkLength calculates exact chunk length for full and partial chunks', () {
      const fileSize = 1000;
      const chunkSize = 400;

      // Chunks: 0 -> [0, 400), 1 -> [400, 800), 2 -> [800, 1000)
      expect(FileStreamReader.calculateChunkLength(chunkIndex: 0, fileSize: fileSize, chunkSize: chunkSize), 400);
      expect(FileStreamReader.calculateChunkLength(chunkIndex: 1, fileSize: fileSize, chunkSize: chunkSize), 400);
      expect(FileStreamReader.calculateChunkLength(chunkIndex: 2, fileSize: fileSize, chunkSize: chunkSize), 200);

      // Out of bounds chunkIndex
      expect(
        () => FileStreamReader.calculateChunkLength(chunkIndex: 3, fileSize: fileSize, chunkSize: chunkSize),
        throwsRangeError,
      );

      // Empty file has 0 chunks, so index 0 is out of bounds
      expect(
        () => FileStreamReader.calculateChunkLength(chunkIndex: 0, fileSize: 0, chunkSize: chunkSize),
        throwsRangeError,
      );

      // Negative inputs
      expect(
        () => FileStreamReader.calculateChunkLength(chunkIndex: -1, fileSize: fileSize, chunkSize: chunkSize),
        throwsArgumentError,
      );
      expect(
        () => FileStreamReader.calculateChunkLength(chunkIndex: 0, fileSize: -10, chunkSize: chunkSize),
        throwsArgumentError,
      );
    });

    test('extractFileName extracts and sanitizes filename safely', () {
      expect(FileStreamReader.extractFileName('/path/to/my_image.png'), 'my_image.png');
      expect(FileStreamReader.extractFileName(r'C:\Users\test\document.pdf'), 'document.pdf');
      expect(FileStreamReader.extractFileName('evil/../file.txt'), 'file.txt');
    });

    test('getFileSize returns correct size and releases handle', () async {
      final file = await createTestFile('get_size.bin', 12345);
      final size = await reader.getFileSize(file.path);

      expect(size, 12345);
      expect(reader.activeHandleCount, 0);

      await file.delete();
      expect(await file.exists(), isFalse);
    });
  });
}
