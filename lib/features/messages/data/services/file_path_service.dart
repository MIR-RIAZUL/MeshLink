import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Exception thrown when a path safety or traversal check fails.
class SecurityException implements Exception {
  const SecurityException(this.message);
  final String message;

  @override
  String toString() => 'SecurityException: $message';
}

/// Service providing path sanitization, traversal defense, and safe filesystem
/// resolution for MeshLink file transfers.
class FilePathService {
  FilePathService({
    Future<Directory> Function()? baseDirectoryProvider,
    Directory? baseDirectory,
  }) : _baseDirectoryProvider = baseDirectory != null
            ? (() async => baseDirectory)
            : (baseDirectoryProvider ?? getApplicationSupportDirectory);

  final Future<Directory> Function() _baseDirectoryProvider;

  static final RegExp _unsafeTransferIdRegex = RegExp(r'^[a-zA-Z0-9_\-]+$');
  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _invalidFileNameCharsRegex = RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]');
  static final RegExp _windowsReservedNamesRegex = RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$',
    caseSensitive: false,
  );

  /// Validates a transfer ID.
  ///
  /// Throws [ArgumentError] if the transfer ID is empty, contains path traversal
  /// fragments, or violates allowed character patterns.
  static void validateTransferId(String transferId) {
    if (transferId.trim().isEmpty) {
      throw ArgumentError('transferId must not be empty.');
    }
    if (transferId.length > 128) {
      throw ArgumentError('transferId length (${transferId.length}) exceeds maximum limit of 128.');
    }
    if (transferId.contains('/') ||
        transferId.contains(r'\') ||
        transferId.contains('..') ||
        transferId.contains(':')) {
      throw ArgumentError('transferId contains illegal path characters: "$transferId"');
    }
    if (_controlCharRegex.hasMatch(transferId)) {
      throw ArgumentError('transferId contains control characters.');
    }
    if (!_unsafeTransferIdRegex.hasMatch(transferId)) {
      throw ArgumentError('transferId contains illegal characters: "$transferId"');
    }
  }

  /// Returns true if [transferId] is strictly valid.
  static bool isValidTransferId(String transferId) {
    try {
      validateTransferId(transferId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validates a filename strictly.
  ///
  /// Throws [ArgumentError] if the filename contains path traversal, directory
  /// separators, drive prefixes, control characters, or reserved names.
  static void validateFileName(String fileName) {
    if (fileName.trim().isEmpty) {
      throw ArgumentError('fileName must not be empty.');
    }
    if (fileName == '.' || fileName == '..') {
      throw ArgumentError('fileName cannot be "." or "..".');
    }
    if (fileName.length > 255) {
      throw ArgumentError('fileName length (${fileName.length}) exceeds maximum limit of 255.');
    }
    if (fileName.contains('/') || fileName.contains(r'\')) {
      throw ArgumentError('fileName must not contain path separators: "$fileName"');
    }
    if (fileName.contains('..')) {
      throw ArgumentError('fileName must not contain parent directory references: "$fileName"');
    }
    if (fileName.contains(':')) {
      throw ArgumentError('fileName must not contain drive or stream prefixes: "$fileName"');
    }
    if (fileName.startsWith(r'\\') || fileName.startsWith('//')) {
      throw ArgumentError('fileName must not contain network or UNC prefixes: "$fileName"');
    }
    if (_controlCharRegex.hasMatch(fileName)) {
      throw ArgumentError('fileName must not contain control characters.');
    }
    if (_windowsReservedNamesRegex.hasMatch(fileName.trim())) {
      throw ArgumentError('fileName uses a reserved operating system device name: "$fileName"');
    }
  }

  /// Returns true if [fileName] is strictly safe and valid.
  static bool isValidFileName(String fileName) {
    try {
      validateFileName(fileName);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sanitizes an arbitrary filename, stripping paths and replacing illegal characters.
  static String sanitizeFileName(String fileName, {String fallback = 'meshlink_transfer.bin'}) {
    var name = fileName.trim();
    if (name.isEmpty) return fallback;

    // Extract basename if path components were provided
    name = p.basename(name);

    // Replace illegal characters and separators with underscores
    name = name.replaceAll(_invalidFileNameCharsRegex, '_');

    // Replace directory traversal sequences
    while (name.contains('..')) {
      name = name.replaceAll('..', '_');
    }

    // Strip leading or trailing dots and spaces
    name = name.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');

    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.replaceAll('_', '').isEmpty) {
      return fallback;
    }

    // Prevent reserved OS device names
    if (_windowsReservedNamesRegex.hasMatch(name)) {
      name = 'file_$name';
    }

    // Truncate to maximum 255 characters while preserving extension if possible
    if (name.length > 255) {
      final ext = p.extension(name);
      final stem = p.basenameWithoutExtension(name);
      final maxStemLen = 255 - ext.length;
      if (maxStemLen > 0 && stem.length > maxStemLen) {
        name = '${stem.substring(0, maxStemLen)}$ext';
      } else {
        name = name.substring(0, 255);
      }
    }

    return name;
  }

  /// Verifies whether [candidatePath] resides strictly within [rootDirectoryPath].
  ///
  /// Prevents directory traversal attacks and prefix collision bugs
  /// (e.g. `/root/files_evil` is NOT inside `/root/files`).
  static bool isPathInsideDirectory(String candidatePath, String rootDirectoryPath) {
    if (candidatePath.trim().isEmpty || rootDirectoryPath.trim().isEmpty) {
      return false;
    }
    try {
      final canonicalRoot = p.canonicalize(rootDirectoryPath);
      final canonicalCandidate = p.canonicalize(candidatePath);

      // Candidate must be strictly within root (child or descendant)
      return p.isWithin(canonicalRoot, canonicalCandidate);
    } catch (_) {
      return false;
    }
  }

  /// Returns the base transfer directory: `<baseDir>/meshlink/file_transfers`
  Future<Directory> getBaseTransfersDirectory({bool create = false}) async {
    final base = await _baseDirectoryProvider();
    final dir = Directory(p.join(base.path, 'meshlink', 'file_transfers'));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the application-private staging directory:
  /// `<baseDir>/meshlink/file_transfers/staging`
  Future<Directory> getStagingDirectory({bool create = false}) async {
    final baseTransfers = await getBaseTransfersDirectory(create: create);
    final dir = Directory(p.join(baseTransfers.path, 'staging'));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the application-private completed files directory:
  /// `<baseDir>/meshlink/file_transfers/completed`
  Future<Directory> getCompletedDirectory({bool create = false}) async {
    final baseTransfers = await getBaseTransfersDirectory(create: create);
    final dir = Directory(p.join(baseTransfers.path, 'completed'));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ensures that all required private file transfer directories exist.
  Future<void> ensureDirectoriesExist() async {
    await getStagingDirectory(create: true);
    await getCompletedDirectory(create: true);
  }

  /// Generates a validated, contained staging path for a transfer:
  /// `<stagingDir>/<transferId>.part`
  Future<String> getStagingPath(String transferId) async {
    validateTransferId(transferId);
    final stagingDir = await getStagingDirectory();
    final stagingFileName = '$transferId.part';
    final candidatePath = p.join(stagingDir.path, stagingFileName);

    if (!isPathInsideDirectory(candidatePath, stagingDir.path)) {
      throw SecurityException(
        'Staging path escapes staging directory: "$candidatePath"',
      );
    }
    return candidatePath;
  }

  /// Generates a collision-safe, traversal-proof completed destination path:
  /// `<completedDir>/<sanitizedFileName>`
  ///
  /// If a file with the same name already exists in the completed directory,
  /// this method resolves collisions using the `fileName (N).ext` pattern.
  Future<String> getSafeCompletedPath({
    required String transferId,
    required String fileName,
  }) async {
    validateTransferId(transferId);
    validateFileName(fileName);

    final completedDir = await getCompletedDirectory();
    final safeName = sanitizeFileName(fileName);
    final baseCandidate = p.join(completedDir.path, safeName);

    if (!isPathInsideDirectory(baseCandidate, completedDir.path)) {
      throw SecurityException(
        'Completed path escapes completed directory: "$baseCandidate"',
      );
    }

    if (!await File(baseCandidate).exists()) {
      return baseCandidate;
    }

    // Collision handling: "file (1).ext", "file (2).ext" ...
    final ext = p.extension(safeName);
    final baseName = p.basenameWithoutExtension(safeName);

    var counter = 1;
    while (true) {
      final candidateName = '$baseName ($counter)$ext';
      final candidatePath = p.join(completedDir.path, candidateName);

      if (!isPathInsideDirectory(candidatePath, completedDir.path)) {
        throw SecurityException(
          'Collision path escapes completed directory: "$candidatePath"',
        );
      }

      if (!await File(candidatePath).exists()) {
        return candidatePath;
      }
      counter++;
      if (counter > 10000) {
        throw FileSystemException(
          'Excessive file collisions encountered for filename: "$safeName"',
        );
      }
    }
  }
}
