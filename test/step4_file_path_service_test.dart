import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Phase 8 Step 4 — Filename Security & Validation Tests', () {
    test('valid filenames are accepted', () {
      final validNames = [
        'photo.jpg',
        'document.pdf',
        'my file.txt',
        'বাংলা.txt',
        'archive-2026_01.tar.gz',
        'music 123.mp3',
      ];

      for (final name in validNames) {
        expect(
          FilePathService.isValidFileName(name),
          isTrue,
          reason: 'Filename "$name" should be valid',
        );
        expect(
          () => FilePathService.validateFileName(name),
          returnsNormally,
          reason: 'Filename "$name" should not throw',
        );
      }
    });

    test('unsafe and path-traversal filenames are rejected', () {
      final invalidNames = [
        '../secret.txt',
        r'..\secret.txt',
        '../../secret.txt',
        r'..\..\secret.txt',
        r'C:\secret.txt',
        'C:/secret.txt',
        '/secret.txt',
        r'\secret.txt',
        r'\\server\share\secret.txt',
        '//server/share/secret.txt',
        '.',
        '..',
        '',
        '   ',
        'file\x00.txt',
        'file\n.txt',
        'file\r.txt',
        'file\t.txt',
        'CON',
        'con.txt',
        'prn.pdf',
        'aux',
        'nul',
        'com1.dat',
        'lpt1.txt',
        'a' * 256, // exceeds 255 chars
      ];

      for (final name in invalidNames) {
        expect(
          FilePathService.isValidFileName(name),
          isFalse,
          reason: 'Filename "$name" should be detected as invalid',
        );
        expect(
          () => FilePathService.validateFileName(name),
          throwsArgumentError,
          reason: 'Filename "$name" should throw ArgumentError',
        );
      }
    });

    test('filename extension does not bypass path structure checks', () {
      // Must be rejected regardless of safe-looking extension
      expect(() => FilePathService.validateFileName('../../evil.png'), throwsArgumentError);
      expect(() => FilePathService.validateFileName(r'..\safe.txt'), throwsArgumentError);
      expect(() => FilePathService.validateFileName('C:/innocent.pdf'), throwsArgumentError);
    });

    test('sanitizeFileName removes traversal, illegal characters, and prefixes', () {
      expect(FilePathService.sanitizeFileName('../secret.txt'), 'secret.txt');
      expect(FilePathService.sanitizeFileName(r'..\..\doc.pdf'), 'doc.pdf');
      expect(FilePathService.sanitizeFileName('/var/tmp/data.bin'), 'data.bin');
      expect(FilePathService.sanitizeFileName(r'C:\Windows\calc.exe'), 'calc.exe');
      expect(FilePathService.sanitizeFileName('hello:world?.txt'), 'hello_world_.txt');
      expect(FilePathService.sanitizeFileName('file\x00\x1F.txt'), 'file__.txt');
      expect(FilePathService.sanitizeFileName('   spaced.txt   '), 'spaced.txt');
      expect(FilePathService.sanitizeFileName('CON.txt'), 'file_CON.txt');
      expect(FilePathService.sanitizeFileName(''), 'meshlink_transfer.bin');
      expect(FilePathService.sanitizeFileName('...'), 'meshlink_transfer.bin');
    });
  });

  group('Phase 8 Step 4 — Transfer ID Validation Tests', () {
    test('valid transfer IDs are accepted', () {
      final validIds = [
        'FT-1727220000000-A1B2C3',
        'FT-1001',
        'FT-test_file_transfer-99',
        'abc123XYZ',
      ];

      for (final id in validIds) {
        expect(FilePathService.isValidTransferId(id), isTrue);
        expect(() => FilePathService.validateTransferId(id), returnsNormally);
      }
    });

    test('unsafe transfer IDs are rejected', () {
      final invalidIds = [
        '',
        '   ',
        '../traversal',
        r'..\traversal',
        'FT/123',
        r'FT\123',
        'FT:123',
        'FT 123',
        'FT\x00123',
        'FT\n123',
        'a' * 129, // exceeds 128 chars
      ];

      for (final id in invalidIds) {
        expect(FilePathService.isValidTransferId(id), isFalse);
        expect(
          () => FilePathService.validateTransferId(id),
          throwsArgumentError,
          reason: 'Transfer ID "$id" should throw ArgumentError',
        );
      }
    });
  });

  group('Phase 8 Step 4 — Path Containment Tests', () {
    test('descendant paths are identified as inside directory', () {
      final tempDir = Directory.systemTemp.createTempSync('meshlink_containment_test_');
      try {
        final root = tempDir.path;
        final child = p.join(root, 'files', 'sample.txt');
        final directChild = p.join(root, 'sample.txt');

        expect(FilePathService.isPathInsideDirectory(child, root), isTrue);
        expect(FilePathService.isPathInsideDirectory(directChild, root), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('prefix collision paths are NOT inside directory', () {
      final tempDir = Directory.systemTemp.createTempSync('meshlink_containment_prefix_');
      try {
        final root = p.join(tempDir.path, 'files');
        final evilSibling = p.join(tempDir.path, 'files_evil', 'sample.txt');

        expect(FilePathService.isPathInsideDirectory(evilSibling, root), isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('path traversal attempts are detected as NOT inside directory', () {
      final tempDir = Directory.systemTemp.createTempSync('meshlink_containment_traversal_');
      try {
        final root = p.join(tempDir.path, 'safe_dir');
        final traversal = p.join(root, '..', 'evil.txt');
        final deepTraversal = p.join(root, 'sub', '..', '..', 'evil.txt');

        expect(FilePathService.isPathInsideDirectory(traversal, root), isFalse);
        expect(FilePathService.isPathInsideDirectory(deepTraversal, root), isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('root path itself is not strictly inside itself', () {
      final tempDir = Directory.systemTemp.createTempSync('meshlink_containment_self_');
      try {
        expect(FilePathService.isPathInsideDirectory(tempDir.path, tempDir.path), isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('empty paths return false safely', () {
      expect(FilePathService.isPathInsideDirectory('', '/root'), isFalse);
      expect(FilePathService.isPathInsideDirectory('/root/file', ''), isFalse);
      expect(FilePathService.isPathInsideDirectory('', ''), isFalse);
    });
  });

  group('Phase 8 Step 4 — Staging and Completed Directory Operations', () {
    late Directory testBaseDir;
    late FilePathService pathService;

    setUp(() {
      testBaseDir = Directory.systemTemp.createTempSync('meshlink_filepath_test_');
      pathService = FilePathService(baseDirectory: testBaseDir);
    });

    tearDown(() {
      if (testBaseDir.existsSync()) {
        testBaseDir.deleteSync(recursive: true);
      }
    });

    test('directory hierarchy resolution and lazy creation', () async {
      final stagingDir = await pathService.getStagingDirectory();
      final completedDir = await pathService.getCompletedDirectory();

      expect(p.isWithin(testBaseDir.path, stagingDir.path), isTrue);
      expect(p.isWithin(testBaseDir.path, completedDir.path), isTrue);

      // Lazily not created yet until requested
      expect(stagingDir.existsSync(), isFalse);
      expect(completedDir.existsSync(), isFalse);

      // Explicitly ensure directories exist
      await pathService.ensureDirectoriesExist();

      expect(stagingDir.existsSync(), isTrue);
      expect(completedDir.existsSync(), isTrue);
    });

    test('getStagingPath generates contained, deterministic path', () async {
      await pathService.ensureDirectoriesExist();
      final stagingPath = await pathService.getStagingPath('FT-12345');

      expect(stagingPath.endsWith('FT-12345.part'), isTrue);
      final stagingDir = await pathService.getStagingDirectory();
      expect(FilePathService.isPathInsideDirectory(stagingPath, stagingDir.path), isTrue);
    });

    test('getStagingPath rejects malicious transfer IDs', () async {
      expect(
        () => pathService.getStagingPath('../../escape'),
        throwsArgumentError,
      );
      expect(
        () => pathService.getStagingPath('FT/traversal'),
        throwsArgumentError,
      );
    });

    test('getSafeCompletedPath generates contained completed path', () async {
      await pathService.ensureDirectoriesExist();
      final completedPath = await pathService.getSafeCompletedPath(
        transferId: 'FT-555',
        fileName: 'document.pdf',
      );

      final completedDir = await pathService.getCompletedDirectory();
      expect(FilePathService.isPathInsideDirectory(completedPath, completedDir.path), isTrue);
      expect(completedPath.endsWith('document.pdf'), isTrue);
    });

    test('getSafeCompletedPath rejects traversal filenames', () async {
      expect(
        () => pathService.getSafeCompletedPath(
          transferId: 'FT-555',
          fileName: '../escape.pdf',
        ),
        throwsArgumentError,
      );
      expect(
        () => pathService.getSafeCompletedPath(
          transferId: 'FT-555',
          fileName: r'C:\Windows\escape.exe',
        ),
        throwsArgumentError,
      );
    });

    test('getSafeCompletedPath resolves name collisions safely without overwriting', () async {
      final completedDir = await pathService.getCompletedDirectory(create: true);

      // Create an existing file
      final initialFile = File(p.join(completedDir.path, 'report.pdf'));
      initialFile.writeAsStringSync('Original content 1');

      final firstCollisionPath = await pathService.getSafeCompletedPath(
        transferId: 'FT-COL-1',
        fileName: 'report.pdf',
      );
      expect(firstCollisionPath.endsWith('report (1).pdf'), isTrue);

      // Create the collision candidate
      final secondFile = File(firstCollisionPath);
      secondFile.writeAsStringSync('Original content 2');

      final secondCollisionPath = await pathService.getSafeCompletedPath(
        transferId: 'FT-COL-2',
        fileName: 'report.pdf',
      );
      expect(secondCollisionPath.endsWith('report (2).pdf'), isTrue);

      // Confirm original file was never overwritten
      expect(initialFile.readAsStringSync(), 'Original content 1');
      expect(secondFile.readAsStringSync(), 'Original content 2');
    });

    test('getSafeCompletedPath handles filenames without extension during collision', () async {
      final completedDir = await pathService.getCompletedDirectory(create: true);

      final initialFile = File(p.join(completedDir.path, 'README'));
      initialFile.writeAsStringSync('Original readme');

      final collisionPath = await pathService.getSafeCompletedPath(
        transferId: 'FT-NOEXT',
        fileName: 'README',
      );
      expect(collisionPath.endsWith('README (1)'), isTrue);
      expect(FilePathService.isPathInsideDirectory(collisionPath, completedDir.path), isTrue);
    });
  });
}
