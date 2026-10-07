import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:path/path.dart' as p;

/// Base exception class for all [FileStreamReader] operations.
abstract class FileStreamReaderException implements Exception {
  const FileStreamReaderException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a requested file does not exist on disk.
class FileNotFoundException extends FileStreamReaderException {
  const FileNotFoundException(super.message);
}

/// Thrown when a file path is invalid, malformed, or points to a non-file entity (e.g., directory).
class InvalidFilePathException extends FileStreamReaderException {
  const InvalidFilePathException(super.message);
}

/// Thrown when an offset is negative, out of bounds, or causes an arithmetic overflow.
class InvalidOffsetException extends FileStreamReaderException {
  const InvalidOffsetException(super.message);
}

/// Thrown when a length parameter is negative or causes the range to exceed the file boundary.
class InvalidLengthException extends FileStreamReaderException {
  const InvalidLengthException(super.message);
}

/// Thrown when a chunk size is zero, negative, or invalid.
class InvalidChunkSizeException extends FileStreamReaderException {
  const InvalidChunkSizeException(super.message);
}

/// Thrown when an underlying filesystem read or open operation fails.
class FileReadException extends FileStreamReaderException {
  const FileReadException(super.message, [this.cause]);
  final Object? cause;

  @override
  String toString() => cause != null
      ? 'FileReadException: $message (caused by: $cause)'
      : 'FileReadException: $message';
}

/// Pure sender-side file I/O service for reading local files incrementally
/// and safely without buffering the entire file into memory.
class FileStreamReader {
  FileStreamReader({this.filePathService});

  final FilePathService? filePathService;

  /// Default chunk size recommended for future BLE transfers (16 KB).
  static const int defaultChunkSize = 16 * 1024;

  /// Tracks the number of currently open file handles managed by this instance.
  ///
  /// Useful for diagnostics, resource monitoring, and leak-free verification in tests.
  int _activeHandleCount = 0;
  int get activeHandleCount => _activeHandleCount;

  /// Validates that [filePath] represents an accessible regular file.
  ///
  /// Returns a [File] entity if valid.
  /// Throws [InvalidFilePathException] if path is empty, malformed, or points to a directory.
  /// Throws [FileNotFoundException] if the file does not exist.
  Future<File> validateSourceFile(String filePath) async {
    return _validateSourceFile(filePath);
  }

  /// Returns the file size in bytes after validating the file.
  ///
  /// Guarantees that the underlying file descriptor is promptly closed.
  Future<int> getFileSize(String filePath) async {
    final file = await _validateSourceFile(filePath);
    RandomAccessFile? raf;
    _activeHandleCount++;
    try {
      try {
        raf = await file.open(mode: FileMode.read);
      } catch (e) {
        throw FileReadException(
          'Failed to open file "$filePath" to check size: $e',
          e,
        );
      }

      final size = await raf.length();
      if (size < 0) {
        throw InvalidLengthException('File reported negative size ($size).');
      }
      return size;
    } on FileStreamReaderException {
      rethrow;
    } catch (e) {
      throw FileReadException(
        'Failed to read file size for "$filePath": $e',
        e,
      );
    } finally {
      _activeHandleCount--;
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }
    }
  }

  /// Incrementally reads [filePath] in sequential chunks of [chunkSize] bytes.
  ///
  /// Never loads the entire file into memory; each emitted chunk is bounded by [chunkSize].
  /// Guarantees that file handles are cleanly closed on stream completion, read errors,
  /// or when the consumer cancels the subscription.
  ///
  /// If the file is 0 bytes (empty), emits 0 chunks and closes resources cleanly.
  ///
  /// Throws [InvalidChunkSizeException] if [chunkSize] <= 0.
  /// Throws [FileNotFoundException] if the file does not exist.
  /// Throws [InvalidFilePathException] if the path is invalid or points to a directory.
  /// Throws [FileReadException] if an I/O error occurs during reading.
  Stream<Uint8List> readFile({
    required String filePath,
    int chunkSize = defaultChunkSize,
  }) async* {
    if (chunkSize <= 0) {
      throw InvalidChunkSizeException(
        'chunkSize must be greater than zero ($chunkSize).',
      );
    }

    final file = await _validateSourceFile(filePath);

    RandomAccessFile? raf;
    _activeHandleCount++;
    try {
      try {
        raf = await file.open(mode: FileMode.read);
      } catch (e) {
        throw FileReadException(
          'Failed to open file "$filePath" for reading: $e',
          e,
        );
      }

      final fileSize = await raf.length();
      if (fileSize < 0) {
        throw InvalidLengthException('File reported negative size ($fileSize).');
      }

      if (fileSize == 0) {
        // Empty file: emit 0 chunks, clean close
        return;
      }

      var bytesRead = 0;
      while (bytesRead < fileSize) {
        final remaining = fileSize - bytesRead;
        final toRead = remaining < chunkSize ? remaining : chunkSize;
        final chunk = await _readExact(raf, toRead, filePath: filePath);
        if (chunk.isEmpty) {
          // Reached EOF before expected fileSize
          break;
        }
        bytesRead += chunk.length;
        yield chunk;
      }
    } on FileStreamReaderException {
      rethrow;
    } catch (e) {
      throw FileReadException(
        'Failed while reading stream from file "$filePath": $e',
        e,
      );
    } finally {
      _activeHandleCount--;
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }
    }
  }

  /// Reads an exact bounded byte range [[offset], [offset] + [length]) from [filePath].
  ///
  /// Guarantees bounded memory usage by only allocating memory for the requested range.
  /// Guarantees that the underlying file descriptor is promptly closed upon return or exception.
  ///
  /// Validations:
  /// - [offset] >= 0
  /// - [length] >= 0
  /// - [offset] + [length] <= fileSize
  /// - Rejects 64-bit integer overflow
  ///
  /// If [length] == 0 and [offset] <= fileSize, returns an empty [Uint8List].
  Future<Uint8List> readRange({
    required String filePath,
    required int offset,
    required int length,
  }) async {
    if (offset < 0) {
      throw InvalidOffsetException('offset cannot be negative ($offset).');
    }
    if (length < 0) {
      throw InvalidLengthException('length cannot be negative ($length).');
    }
    // Prevent 64-bit integer overflow
    if (offset > 0x7FFFFFFFFFFFFFFF - length || offset + length < 0) {
      throw InvalidOffsetException(
        'offset ($offset) + length ($length) causes integer overflow.',
      );
    }

    final file = await _validateSourceFile(filePath);

    RandomAccessFile? raf;
    _activeHandleCount++;
    try {
      try {
        raf = await file.open(mode: FileMode.read);
      } catch (e) {
        throw FileReadException(
          'Failed to open file "$filePath" for reading: $e',
          e,
        );
      }

      final fileSize = await raf.length();
      if (fileSize < 0) {
        throw InvalidLengthException('File reported negative size ($fileSize).');
      }

      if (offset > fileSize) {
        throw InvalidOffsetException(
          'offset ($offset) exceeds file size ($fileSize).',
        );
      }
      if (offset + length > fileSize) {
        throw InvalidLengthException(
          'Requested range [$offset, ${offset + length}) exceeds file size ($fileSize).',
        );
      }

      if (length == 0) {
        return Uint8List(0);
      }

      await raf.setPosition(offset);
      return await _readExact(raf, length, filePath: filePath);
    } on FileStreamReaderException {
      rethrow;
    } catch (e) {
      throw FileReadException(
        'Failed to read range from file "$filePath": $e',
        e,
      );
    } finally {
      _activeHandleCount--;
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }
    }
  }

  /// Pure helper: Calculates the total number of chunks required to transmit a file
  /// of [fileSize] bytes using chunks of [chunkSize] bytes.
  ///
  /// Returns 0 for empty files (0 bytes).
  /// Throws [ArgumentError] if [fileSize] < 0.
  /// Throws [InvalidChunkSizeException] if [chunkSize] <= 0.
  static int calculateTotalChunks({
    required int fileSize,
    required int chunkSize,
  }) {
    if (fileSize < 0) {
      throw ArgumentError('fileSize cannot be negative ($fileSize).');
    }
    if (chunkSize <= 0) {
      throw InvalidChunkSizeException(
        'chunkSize must be greater than zero ($chunkSize).',
      );
    }
    if (fileSize == 0) {
      return 0;
    }
    var chunks = fileSize ~/ chunkSize;
    if (fileSize % chunkSize != 0) {
      chunks += 1;
    }
    return chunks;
  }

  /// Pure helper: Calculates the byte offset for the chunk at [chunkIndex] with [chunkSize].
  ///
  /// Throws [ArgumentError] if [chunkIndex] < 0.
  /// Throws [InvalidChunkSizeException] if [chunkSize] <= 0.
  /// Throws [InvalidOffsetException] if integer overflow occurs.
  static int calculateChunkOffset({
    required int chunkIndex,
    required int chunkSize,
  }) {
    if (chunkIndex < 0) {
      throw ArgumentError('chunkIndex cannot be negative ($chunkIndex).');
    }
    if (chunkSize <= 0) {
      throw InvalidChunkSizeException(
        'chunkSize must be greater than zero ($chunkSize).',
      );
    }
    if (chunkIndex == 0) {
      return 0;
    }
    // Prevent 64-bit integer overflow
    if (chunkIndex > 0x7FFFFFFFFFFFFFFF ~/ chunkSize) {
      throw InvalidOffsetException(
        'chunkIndex ($chunkIndex) * chunkSize ($chunkSize) causes integer overflow.',
      );
    }
    final offset = chunkIndex * chunkSize;
    if (offset < 0) {
      throw InvalidOffsetException(
        'Calculated chunk offset overflowed to negative: $offset',
      );
    }
    return offset;
  }

  /// Pure helper: Calculates the byte length of the chunk at [chunkIndex] for a file
  /// of [fileSize] bytes and [chunkSize] bytes per chunk.
  ///
  /// Throws [ArgumentError] if [fileSize] < 0 or [chunkIndex] < 0.
  /// Throws [InvalidChunkSizeException] if [chunkSize] <= 0.
  /// Throws [RangeError] if [chunkIndex] is out of range for the file.
  static int calculateChunkLength({
    required int chunkIndex,
    required int fileSize,
    required int chunkSize,
  }) {
    if (fileSize < 0) {
      throw ArgumentError('fileSize cannot be negative ($fileSize).');
    }
    if (chunkIndex < 0) {
      throw ArgumentError('chunkIndex cannot be negative ($chunkIndex).');
    }
    if (chunkSize <= 0) {
      throw InvalidChunkSizeException(
        'chunkSize must be greater than zero ($chunkSize).',
      );
    }
    final total = calculateTotalChunks(fileSize: fileSize, chunkSize: chunkSize);
    if (chunkIndex >= total) {
      throw RangeError.range(
        chunkIndex,
        0,
        total > 0 ? total - 1 : 0,
        'chunkIndex',
        'chunkIndex ($chunkIndex) is out of range for totalChunks ($total).',
      );
    }
    final offset = calculateChunkOffset(
      chunkIndex: chunkIndex,
      chunkSize: chunkSize,
    );
    final remaining = fileSize - offset;
    return remaining < chunkSize ? remaining : chunkSize;
  }

  /// Extracts and sanitizes the file name from a path using [FilePathService].
  static String extractFileName(String filePath) {
    final base = p.basename(filePath);
    return FilePathService.sanitizeFileName(base);
  }

  // --- Internal Helpers ---

  Future<File> _validateSourceFile(String filePath) async {
    if (filePath.trim().isEmpty) {
      throw const InvalidFilePathException('File path must not be empty.');
    }
    if (filePath.contains('\x00')) {
      throw const InvalidFilePathException(
        'File path contains illegal null character.',
      );
    }

    try {
      final type = await FileSystemEntity.type(filePath, followLinks: true);
      if (type == FileSystemEntityType.notFound) {
        throw FileNotFoundException('File not found: "$filePath"');
      }
      if (type == FileSystemEntityType.directory) {
        throw InvalidFilePathException(
          'Path points to a directory, not a regular file: "$filePath"',
        );
      }
      if (type != FileSystemEntityType.file) {
        throw InvalidFilePathException(
          'Path is not a regular file (entity type: $type): "$filePath"',
        );
      }

      return File(filePath);
    } on FileStreamReaderException {
      rethrow;
    } catch (e) {
      throw InvalidFilePathException('Invalid file path "$filePath": $e');
    }
  }

  Future<Uint8List> _readExact(
    RandomAccessFile raf,
    int length, {
    required String filePath,
  }) async {
    if (length == 0) return Uint8List(0);

    final first = await raf.read(length);
    if (first.length == length) {
      return first;
    }
    if (first.isEmpty) {
      return Uint8List(0);
    }

    // Defensive handling for OS short reads
    final builder = BytesBuilder(copy: false);
    builder.add(first);
    var remaining = length - first.length;

    while (remaining > 0) {
      final next = await raf.read(remaining);
      if (next.isEmpty) {
        throw FileReadException(
          'Unexpected EOF while reading file "$filePath": expected $length bytes, got ${builder.length}.',
        );
      }
      builder.add(next);
      remaining -= next.length;
    }

    return builder.takeBytes();
  }
}
