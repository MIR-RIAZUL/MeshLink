import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meshlink/features/messages/data/services/file_path_service.dart';

/// Base exception class for all [FileDiskWriter] operations.
abstract class FileDiskWriterException implements Exception {
  const FileDiskWriterException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when an offset parameter is negative, beyond expected file size, or causes integer overflow.
class InvalidOffsetException extends FileDiskWriterException {
  const InvalidOffsetException(super.message);
}

/// Thrown when a length parameter is negative or causes the range to exceed the expected file size.
class InvalidLengthException extends FileDiskWriterException {
  const InvalidLengthException(super.message);
}

/// Thrown when an expected file size parameter is negative or invalid.
class InvalidFileSizeException extends FileDiskWriterException {
  const InvalidFileSizeException(super.message);
}

/// Thrown when a staging path is empty, malformed, or violates path containment.
class InvalidStagingPathException extends FileDiskWriterException {
  const InvalidStagingPathException(super.message);
}

/// Thrown when an operation is attempted on a writer that has been closed or was never opened.
class FileDiskWriterClosedException extends FileDiskWriterException {
  const FileDiskWriterClosedException([
    super.message = 'FileDiskWriter is closed or not opened.',
  ]);
}

/// Thrown when an underlying filesystem write, truncate, or flush operation fails.
class FileWriteException extends FileDiskWriterException {
  const FileWriteException(super.message, [this.cause]);
  final Object? cause;

  @override
  String toString() => cause != null
      ? 'FileWriteException: $message (caused by: $cause)'
      : 'FileWriteException: $message';
}

/// Pure receiver-side filesystem component that writes incoming file chunks directly
/// to a staging file at specified random-access offsets without buffering the entire
/// file in memory.
class FileDiskWriter {
  FileDiskWriter({this.filePathService});

  /// Optional [FilePathService] used for resolving and validating staging directories.
  final FilePathService? filePathService;

  String? _transferId;
  String? _stagingPath;
  int? _expectedFileSize;
  RandomAccessFile? _raf;
  bool _isClosed = false;
  int _activeHandleCount = 0;

  /// Internal FIFO operation queue ensuring all asynchronous operations on the
  /// underlying [RandomAccessFile] are strictly serialized per writer instance.
  Future<void> _operationQueue = Future<void>.value();

  /// The transfer ID associated with the currently open staging file.
  String get transferId =>
      _transferId ??
      (throw const FileDiskWriterClosedException('FileDiskWriter is not open.'));

  /// The canonical file path of the currently open staging file.
  String get stagingPath =>
      _stagingPath ??
      (throw const FileDiskWriterClosedException('FileDiskWriter is not open.'));

  /// The declared expected total file size in bytes.
  int get expectedFileSize =>
      _expectedFileSize ??
      (throw const FileDiskWriterClosedException('FileDiskWriter is not open.'));

  /// Whether the writer currently holds an open file handle.
  bool get isOpen => _raf != null && !_isClosed;

  /// Whether this writer has been explicitly closed.
  bool get isClosed => _isClosed;

  /// Diagnostic counter of active open file handles managed by this instance.
  int get activeHandleCount => _activeHandleCount;

  /// Creates a new staging file or opens an existing one for [transferId].
  ///
  /// - [transferId]: Strictly validated transfer identifier.
  /// - [expectedFileSize]: Expected total size of the final file in bytes (>= 0).
  /// - [stagingPath]: Optional explicit path. If omitted, resolved via [filePathService].
  /// - [reset]: If true, truncates any existing file content to 0 before pre-allocating.
  ///   If false (default), preserves any already received bytes for resume operations.
  ///
  /// Throws [StateError] if this writer is already open.
  /// Throws [ArgumentError] if [transferId] is invalid.
  /// Throws [InvalidFileSizeException] if [expectedFileSize] < 0.
  /// Throws [InvalidStagingPathException] or [SecurityException] if path is unsafe.
  /// Throws [FileWriteException] if underlying filesystem opening fails.
  Future<void> createOrOpen({
    required String transferId,
    required int expectedFileSize,
    String? stagingPath,
    bool reset = false,
  }) async {
    if (isOpen) {
      throw StateError(
        'FileDiskWriter is already open for transfer "$_transferId".',
      );
    }
    _isClosed = false;

    // 1. Validate transferId
    FilePathService.validateTransferId(transferId);

    // 2. Validate expectedFileSize
    if (expectedFileSize < 0) {
      throw InvalidFileSizeException(
        'expectedFileSize cannot be negative ($expectedFileSize).',
      );
    }

    // 3. Resolve and validate stagingPath
    late final String resolvedPath;
    if (stagingPath != null) {
      final trimmed = stagingPath.trim();
      if (trimmed.isEmpty) {
        throw const InvalidStagingPathException('stagingPath must not be empty.');
      }
      if (trimmed.contains('\x00')) {
        throw const InvalidStagingPathException(
          'stagingPath contains illegal null character.',
        );
      }
      if (trimmed.contains('..')) {
        throw const InvalidStagingPathException(
          'stagingPath contains directory traversal ("..").',
        );
      }

      if (filePathService != null) {
        final stagingDir = await filePathService!.getStagingDirectory(create: true);
        if (!FilePathService.isPathInsideDirectory(trimmed, stagingDir.path)) {
          throw SecurityException(
            'Staging path escapes staging directory: "$trimmed"',
          );
        }
      }
      resolvedPath = trimmed;
    } else {
      if (filePathService == null) {
        throw ArgumentError(
          'stagingPath must be provided if filePathService is not configured.',
        );
      }
      resolvedPath = await filePathService!.getStagingPath(transferId);
    }

    // 4. Ensure parent staging directory exists
    final targetFile = File(resolvedPath);
    final parentDir = targetFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    // 5. Open RandomAccessFile (using FileMode.append to avoid accidental truncation of resumes)
    RandomAccessFile? raf;
    try {
      raf = await targetFile.open(mode: FileMode.append);
      _activeHandleCount++;

      if (reset) {
        await raf.truncate(0);
      }

      final currentLength = await raf.length();
      if (currentLength < expectedFileSize) {
        await raf.truncate(expectedFileSize);
      } else if (currentLength > expectedFileSize) {
        await raf.truncate(expectedFileSize);
      }

      _transferId = transferId;
      _stagingPath = resolvedPath;
      _expectedFileSize = expectedFileSize;
      _raf = raf;
    } catch (e) {
      if (raf != null) {
        _activeHandleCount--;
        try {
          await raf.close();
        } catch (_) {}
      }
      if (e is FileDiskWriterException ||
          e is SecurityException ||
          e is ArgumentError) {
        rethrow;
      }
      throw FileWriteException(
        'Failed to open/create staging file "$resolvedPath": $e',
        e,
      );
    }
  }

  /// Alias for [createOrOpen].
  Future<void> open({
    required String transferId,
    required int expectedFileSize,
    String? stagingPath,
    bool reset = false,
  }) =>
      createOrOpen(
        transferId: transferId,
        expectedFileSize: expectedFileSize,
        stagingPath: stagingPath,
        reset: reset,
      );

  /// Convenience factory opening a writer for [transferId] using [filePathService].
  static Future<FileDiskWriter> openForTransfer({
    required String transferId,
    required int expectedFileSize,
    required FilePathService filePathService,
    bool reset = false,
  }) async {
    final writer = FileDiskWriter(filePathService: filePathService);
    await writer.createOrOpen(
      transferId: transferId,
      expectedFileSize: expectedFileSize,
      reset: reset,
    );
    return writer;
  }

  /// Writes [data] at the specified [offset] in the staging file.
  ///
  /// Guarantees:
  /// - Only [data] is held in memory during the write; no whole-file memory accumulation.
  /// - Safe out-of-order writes at arbitrary valid offsets.
  /// - Concurrent calls to [writeAt] are serialized sequentially without file corruption.
  ///
  /// Validations:
  /// - [offset] >= 0
  /// - [data.length] >= 0
  /// - [offset] <= [expectedFileSize]
  /// - [offset] + [data.length] <= [expectedFileSize]
  /// - Rejects 64-bit integer overflow
  ///
  /// A zero-length write ([data.isEmpty]) is treated as a safe no-op if [offset] <= [expectedFileSize].
  Future<void> writeAt({
    required int offset,
    required Uint8List data,
  }) {
    return _synchronized(() async {
      _ensureOpen();
      _validateWriteRange(offset, data.length);
      if (data.isEmpty) return;

      try {
        await _raf!.setPosition(offset);
        await _raf!.writeFrom(data);
      } catch (e) {
        throw FileWriteException(
          'Failed to write ${data.length} bytes at offset $offset in "$_stagingPath": $e',
          e,
        );
      }
    });
  }

  /// Flushes any buffered written data to the underlying filesystem.
  ///
  /// Note: Durability guarantees depend on the host operating system and filesystem.
  Future<void> flush() {
    return _synchronized(() async {
      _ensureOpen();
      try {
        await _raf!.flush();
      } catch (e) {
        throw FileWriteException(
          'Failed to flush staging file "$_stagingPath": $e',
          e,
        );
      }
    });
  }

  /// Truncates the staging file to [length], or to [expectedFileSize] if omitted.
  ///
  /// Throws [InvalidLengthException] if [length] < 0 or > [expectedFileSize].
  Future<void> truncate([int? length]) {
    return _synchronized(() async {
      _ensureOpen();
      final target = length ?? _expectedFileSize!;
      if (target < 0) {
        throw InvalidLengthException('truncate length cannot be negative ($target).');
      }
      if (target > _expectedFileSize!) {
        throw InvalidLengthException(
          'truncate length ($target) exceeds expected file size ($_expectedFileSize).',
        );
      }
      try {
        await _raf!.truncate(target);
      } catch (e) {
        throw FileWriteException(
          'Failed to truncate staging file "$_stagingPath" to $target: $e',
          e,
        );
      }
    });
  }

  /// Returns the current physical length of the staging file on disk in bytes.
  Future<int> getCurrentFileLength() {
    return _synchronized(() async {
      _ensureOpen();
      try {
        return await _raf!.length();
      } catch (e) {
        throw FileWriteException(
          'Failed to determine current staging file length: $e',
          e,
        );
      }
    });
  }

  /// Closes the underlying file descriptor and releases all resources.
  ///
  /// This operation is idempotent; multiple calls to [close] will succeed safely.
  Future<void> close() {
    return _synchronized(() async {
      if (_isClosed && _raf == null) return;
      _isClosed = true;
      final raf = _raf;
      _raf = null;
      if (raf != null) {
        _activeHandleCount--;
        try {
          await raf.close();
        } catch (_) {}
      }
    });
  }

  // --- Internal Serialization & Validation Helpers ---

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }, onError: (_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _ensureOpen() {
    if (!isOpen) {
      throw const FileDiskWriterClosedException(
        'FileDiskWriter is closed or not opened.',
      );
    }
  }

  void _validateWriteRange(int offset, int length) {
    if (offset < 0) {
      throw InvalidOffsetException('offset cannot be negative ($offset).');
    }
    if (length < 0) {
      throw InvalidLengthException('data length cannot be negative ($length).');
    }
    // Prevent 64-bit integer overflow
    if (offset > 0x7FFFFFFFFFFFFFFF - length || offset + length < 0) {
      throw InvalidOffsetException(
        'offset ($offset) + length ($length) causes integer overflow.',
      );
    }
    if (offset > _expectedFileSize!) {
      throw InvalidOffsetException(
        'offset ($offset) exceeds expected file size ($_expectedFileSize).',
      );
    }
    if (offset + length > _expectedFileSize!) {
      throw InvalidLengthException(
        'Requested write range [$offset, ${offset + length}) exceeds expected file size ($_expectedFileSize).',
      );
    }
  }
}
