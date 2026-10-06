import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';

void main() {
  group('Phase 8 Step 3 — FileTransferDirection Tests', () {
    test('outgoing serialization and parsing', () {
      expect(FileTransferDirection.outgoing.toDbValue(), 'outgoing');
      expect(FileTransferDirection.outgoing.toJson(), 'outgoing');
      expect(
        FileTransferDirection.fromString('outgoing'),
        FileTransferDirection.outgoing,
      );
      expect(
        FileTransferDirection.tryFromString('outgoing'),
        FileTransferDirection.outgoing,
      );
    });

    test('incoming serialization and parsing', () {
      expect(FileTransferDirection.incoming.toDbValue(), 'incoming');
      expect(FileTransferDirection.incoming.toJson(), 'incoming');
      expect(
        FileTransferDirection.fromString('incoming'),
        FileTransferDirection.incoming,
      );
      expect(
        FileTransferDirection.tryFromString('incoming'),
        FileTransferDirection.incoming,
      );
    });

    test('invalid direction value rejected', () {
      expect(
        () => FileTransferDirection.fromString('sideways'),
        throwsArgumentError,
      );
      expect(FileTransferDirection.tryFromString('unknown'), isNull);
      expect(FileTransferDirection.tryFromString(null), isNull);
    });
  });

  group('Phase 8 Step 3 — FileTransferStatus Tests', () {
    test('all supported statuses serialize and deserialize correctly', () {
      for (final status in FileTransferStatus.values) {
        final serialized = status.toJson();
        expect(serialized, status.name);
        expect(FileTransferStatus.fromString(serialized), status);
        expect(FileTransferStatus.tryFromString(serialized), status);
        expect(status.toDbValue(), status.name);
      }
    });

    test('legacy database status aliases parse correctly', () {
      expect(FileTransferStatus.fromString('pending'), FileTransferStatus.initiated);
      expect(FileTransferStatus.fromString('offered'), FileTransferStatus.offerSent);
      expect(FileTransferStatus.fromString('accepted'), FileTransferStatus.acceptSent);
      expect(FileTransferStatus.fromString('offer_sent'), FileTransferStatus.offerSent);
      expect(FileTransferStatus.fromString('offer_received'), FileTransferStatus.offerReceived);
      expect(FileTransferStatus.fromString('accept_sent'), FileTransferStatus.acceptSent);
      expect(FileTransferStatus.fromString('accept_received'), FileTransferStatus.acceptReceived);
      expect(FileTransferStatus.fromString('canceled'), FileTransferStatus.cancelled);
    });

    test('invalid status rejected', () {
      expect(() => FileTransferStatus.fromString('corrupted_state'), throwsArgumentError);
      expect(FileTransferStatus.tryFromString('unknown_state'), isNull);
      expect(FileTransferStatus.tryFromString(null), isNull);
    });
  });

  group('Phase 8 Step 3 — FileMetadata Tests', () {
    test('valid creation succeeds', () {
      final metadata = FileMetadata(
        transferId: 'FT-100',
        fileName: 'report.pdf',
        fileSize: 1048576,
        mimeType: 'application/pdf',
        fileHash: 'sha256-hash-value',
        totalChunks: 64,
        chunkSize: 16384,
      );

      expect(metadata.transferId, 'FT-100');
      expect(metadata.fileName, 'report.pdf');
      expect(metadata.fileSize, 1048576);
      expect(metadata.mimeType, 'application/pdf');
      expect(metadata.fileHash, 'sha256-hash-value');
      expect(metadata.totalChunks, 64);
      expect(metadata.chunkSize, 16384);
    });

    test('empty transferId rejected', () {
      expect(
        () => FileMetadata(
          transferId: '   ',
          fileName: 'report.pdf',
          fileSize: 1024,
          mimeType: 'application/pdf',
          fileHash: 'hash',
          totalChunks: 1,
          chunkSize: 1024,
        ),
        throwsArgumentError,
      );
    });

    test('empty filename rejected', () {
      expect(
        () => FileMetadata(
          transferId: 'FT-100',
          fileName: '',
          fileSize: 1024,
          mimeType: 'application/pdf',
          fileHash: 'hash',
          totalChunks: 1,
          chunkSize: 1024,
        ),
        throwsArgumentError,
      );
    });

    test('path traversal in filename rejected', () {
      final maliciousNames = [
        '../secret.txt',
        r'..\secret.txt',
        '/etc/passwd',
        r'C:\Windows\System32\cmd.exe',
        'sub/dir/file.bin',
        r'sub\dir\file.bin',
      ];

      for (final name in maliciousNames) {
        expect(
          () => FileMetadata(
            transferId: 'FT-100',
            fileName: name,
            fileSize: 1024,
            mimeType: 'application/octet-stream',
            fileHash: 'hash',
            totalChunks: 1,
            chunkSize: 1024,
          ),
          throwsArgumentError,
          reason: 'Filename "$name" should be rejected for path traversal',
        );
      }
    });

    test('negative file size rejected', () {
      expect(
        () => FileMetadata(
          transferId: 'FT-100',
          fileName: 'valid.bin',
          fileSize: -1,
          mimeType: 'application/octet-stream',
          fileHash: 'hash',
          totalChunks: 1,
          chunkSize: 1024,
        ),
        throwsArgumentError,
      );
    });

    test('invalid chunk size rejected', () {
      expect(
        () => FileMetadata(
          transferId: 'FT-100',
          fileName: 'valid.bin',
          fileSize: 1024,
          mimeType: 'application/octet-stream',
          fileHash: 'hash',
          totalChunks: 1,
          chunkSize: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => FileMetadata(
          transferId: 'FT-100',
          fileName: 'valid.bin',
          fileSize: 1024,
          mimeType: 'application/octet-stream',
          fileHash: 'hash',
          totalChunks: 1,
          chunkSize: -16,
        ),
        throwsArgumentError,
      );
    });

    test('invalid totalChunks rejected', () {
      expect(
        () => FileMetadata(
          transferId: 'FT-100',
          fileName: 'valid.bin',
          fileSize: 1024,
          mimeType: 'application/octet-stream',
          fileHash: 'hash',
          totalChunks: -1,
          chunkSize: 1024,
        ),
        throwsArgumentError,
      );
    });

    test('serialize -> deserialize produces equivalent model and deterministic JSON', () {
      final original = FileMetadata(
        transferId: 'FT-TEST-METADATA',
        fileName: 'archive.tar.gz',
        fileSize: 204800,
        mimeType: 'application/gzip',
        fileHash: 'hash-abc-123',
        totalChunks: 13,
        chunkSize: 16384,
      );

      final jsonString = original.toJson();
      final reconstructed = FileMetadata.fromJson(jsonString);

      expect(reconstructed, equals(original));
      expect(reconstructed.hashCode, equals(original.hashCode));
      expect(reconstructed.toJson(), equals(jsonString));
    });

    test('copyWith updates specified fields', () {
      final original = FileMetadata(
        transferId: 'FT-1',
        fileName: 'file.txt',
        fileSize: 100,
        mimeType: 'text/plain',
        fileHash: 'h1',
        totalChunks: 1,
        chunkSize: 100,
      );

      final modified = original.copyWith(fileName: 'new.txt', fileSize: 200);
      expect(modified.fileName, 'new.txt');
      expect(modified.fileSize, 200);
      expect(modified.transferId, original.transferId);
    });
  });

  group('Phase 8 Step 3 — FileTransferProgress Tests', () {
    test('valid progress creation and calculations', () {
      final progress = FileTransferProgress(
        transferId: 'FT-P1',
        status: FileTransferStatus.transferring,
        bytesTransferred: 500,
        totalBytes: 1000,
        chunksCompleted: 5,
        totalChunks: 10,
        fileName: 'movie.mp4',
      );

      expect(progress.transferId, 'FT-P1');
      expect(progress.status, FileTransferStatus.transferring);
      expect(progress.bytesTransferred, 500);
      expect(progress.totalBytes, 1000);
      expect(progress.chunksCompleted, 5);
      expect(progress.totalChunks, 10);
      expect(progress.progressFraction, 0.5);
      expect(progress.isCompleted, false);
      expect(progress.isFailed, false);
      expect(progress.isCancelled, false);
      expect(progress.isPaused, false);
    });

    test('zero totalBytes yields zero progressFraction safely', () {
      final progress = FileTransferProgress(
        transferId: 'FT-P0',
        status: FileTransferStatus.initiated,
        bytesTransferred: 0,
        totalBytes: 0,
        chunksCompleted: 0,
        totalChunks: 0,
      );
      expect(progress.progressFraction, 0.0);
    });

    test('completed state detection', () {
      final progress = FileTransferProgress(
        transferId: 'FT-PC',
        status: FileTransferStatus.completed,
        bytesTransferred: 1000,
        totalBytes: 1000,
        chunksCompleted: 10,
        totalChunks: 10,
      );
      expect(progress.isCompleted, true);
    });

    test('negative bytesTransferred rejected', () {
      expect(
        () => FileTransferProgress(
          transferId: 'FT-1',
          status: FileTransferStatus.transferring,
          bytesTransferred: -1,
          totalBytes: 100,
          chunksCompleted: 0,
          totalChunks: 1,
        ),
        throwsArgumentError,
      );
    });

    test('bytesTransferred > totalBytes rejected', () {
      expect(
        () => FileTransferProgress(
          transferId: 'FT-1',
          status: FileTransferStatus.transferring,
          bytesTransferred: 101,
          totalBytes: 100,
          chunksCompleted: 0,
          totalChunks: 1,
        ),
        throwsArgumentError,
      );
    });

    test('negative chunk counts rejected', () {
      expect(
        () => FileTransferProgress(
          transferId: 'FT-1',
          status: FileTransferStatus.transferring,
          bytesTransferred: 0,
          totalBytes: 100,
          chunksCompleted: -1,
          totalChunks: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => FileTransferProgress(
          transferId: 'FT-1',
          status: FileTransferStatus.transferring,
          bytesTransferred: 0,
          totalBytes: 100,
          chunksCompleted: 0,
          totalChunks: -1,
        ),
        throwsArgumentError,
      );
    });

    test('chunksCompleted > totalChunks rejected', () {
      expect(
        () => FileTransferProgress(
          transferId: 'FT-1',
          status: FileTransferStatus.transferring,
          bytesTransferred: 50,
          totalBytes: 100,
          chunksCompleted: 5,
          totalChunks: 4,
        ),
        throwsArgumentError,
      );
    });

    test('serialize -> deserialize produces equivalent progress', () {
      final original = FileTransferProgress(
        transferId: 'FT-PROGRESS-SERIALIZE',
        status: FileTransferStatus.transferring,
        bytesTransferred: 32768,
        totalBytes: 65536,
        chunksCompleted: 2,
        totalChunks: 4,
        fileName: 'data.bin',
      );

      final json = original.toJson();
      final parsed = FileTransferProgress.fromJson(json);

      expect(parsed, equals(original));
      expect(parsed.progressFraction, 0.5);
    });
  });

  group('Phase 8 Step 3 — FileChunk Tests', () {
    test('valid chunk creation succeeds', () {
      final chunk = FileChunk(
        transferId: 'FT-CHUNK-1',
        chunkIndex: 2,
        totalChunks: 5,
        offset: 32768,
        chunkLength: 16384,
        chunkHash: 'sha256-chunk-hash',
      );

      expect(chunk.transferId, 'FT-CHUNK-1');
      expect(chunk.chunkIndex, 2);
      expect(chunk.totalChunks, 5);
      expect(chunk.offset, 32768);
      expect(chunk.chunkLength, 16384);
      expect(chunk.chunkHash, 'sha256-chunk-hash');
    });

    test('empty transferId rejected', () {
      expect(
        () => FileChunk(
          transferId: '',
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 100,
        ),
        throwsArgumentError,
      );
    });

    test('negative chunkIndex rejected', () {
      expect(
        () => FileChunk(
          transferId: 'FT-1',
          chunkIndex: -1,
          totalChunks: 5,
          offset: 0,
          chunkLength: 100,
        ),
        throwsArgumentError,
      );
    });

    test('chunkIndex >= totalChunks rejected', () {
      expect(
        () => FileChunk(
          transferId: 'FT-1',
          chunkIndex: 5,
          totalChunks: 5,
          offset: 0,
          chunkLength: 100,
        ),
        throwsArgumentError,
      );
    });

    test('negative offset rejected', () {
      expect(
        () => FileChunk(
          transferId: 'FT-1',
          chunkIndex: 0,
          totalChunks: 1,
          offset: -1,
          chunkLength: 100,
        ),
        throwsArgumentError,
      );
    });

    test('negative chunkLength rejected', () {
      expect(
        () => FileChunk(
          transferId: 'FT-1',
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: -1,
        ),
        throwsArgumentError,
      );
    });

    test('serialize -> deserialize produces equivalent chunk and deterministic JSON', () {
      final original = FileChunk(
        transferId: 'FT-SERIALIZE-CHUNK',
        chunkIndex: 3,
        totalChunks: 10,
        offset: 49152,
        chunkLength: 16384,
        chunkHash: 'chunk-hash-1234',
      );

      final json = original.toJson();
      final parsed = FileChunk.fromJson(json);

      expect(parsed, equals(original));
      expect(parsed.hashCode, equals(original.hashCode));
      expect(parsed.toJson(), equals(json));
    });

    test('copyWith updates specified chunk fields', () {
      final original = FileChunk(
        transferId: 'FT-1',
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );

      final updated = original.copyWith(chunkIndex: 1, offset: 100);
      expect(updated.chunkIndex, 1);
      expect(updated.offset, 100);
      expect(updated.transferId, original.transferId);
    });
  });

  group('Phase 8 Step 3 — FileTransfer Domain Model Tests', () {
    final now = DateTime.utc(2026, 10, 6, 12, 0, 0);

    test('valid FileTransfer creation succeeds', () {
      final transfer = FileTransfer(
        transferId: 'FT-DOMAIN-1',
        conversationId: 'PEER-ALICE',
        peerId: 'PEER-ALICE',
        direction: FileTransferDirection.outgoing,
        fileName: 'contract.pdf',
        fileSize: 524288,
        mimeType: 'application/pdf',
        fileHash: 'sha256-hash-contract',
        localPath: '/data/user/0/meshlink/files/contract.pdf',
        stagingPath: '/data/user/0/meshlink/staging/contract.pdf.part',
        totalChunks: 32,
        chunkSize: 16384,
        status: FileTransferStatus.transferring,
        createdAt: now,
        updatedAt: now,
      );

      expect(transfer.transferId, 'FT-DOMAIN-1');
      expect(transfer.conversationId, 'PEER-ALICE');
      expect(transfer.peerId, 'PEER-ALICE');
      expect(transfer.direction, FileTransferDirection.outgoing);
      expect(transfer.fileName, 'contract.pdf');
      expect(transfer.fileSize, 524288);
      expect(transfer.totalChunks, 32);
      expect(transfer.status, FileTransferStatus.transferring);
    });

    test('empty IDs and filenames rejected', () {
      expect(
        () => FileTransfer(
          transferId: '',
          conversationId: 'PEER-1',
          peerId: 'PEER-1',
          direction: FileTransferDirection.incoming,
          fileName: 'f.txt',
          fileSize: 10,
          mimeType: 'text/plain',
          fileHash: 'h',
          localPath: '/p',
          stagingPath: '/s',
          totalChunks: 1,
          chunkSize: 10,
          status: FileTransferStatus.initiated,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => FileTransfer(
          transferId: 'FT-1',
          conversationId: '',
          peerId: 'PEER-1',
          direction: FileTransferDirection.incoming,
          fileName: 'f.txt',
          fileSize: 10,
          mimeType: 'text/plain',
          fileHash: 'h',
          localPath: '/p',
          stagingPath: '/s',
          totalChunks: 1,
          chunkSize: 10,
          status: FileTransferStatus.initiated,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => FileTransfer(
          transferId: 'FT-1',
          conversationId: 'PEER-1',
          peerId: '',
          direction: FileTransferDirection.incoming,
          fileName: 'f.txt',
          fileSize: 10,
          mimeType: 'text/plain',
          fileHash: 'h',
          localPath: '/p',
          stagingPath: '/s',
          totalChunks: 1,
          chunkSize: 10,
          status: FileTransferStatus.initiated,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => FileTransfer(
          transferId: 'FT-1',
          conversationId: 'PEER-1',
          peerId: 'PEER-1',
          direction: FileTransferDirection.incoming,
          fileName: '',
          fileSize: 10,
          mimeType: 'text/plain',
          fileHash: 'h',
          localPath: '/p',
          stagingPath: '/s',
          totalChunks: 1,
          chunkSize: 10,
          status: FileTransferStatus.initiated,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('path traversal in filename rejected', () {
      expect(
        () => FileTransfer(
          transferId: 'FT-1',
          conversationId: 'PEER-1',
          peerId: 'PEER-1',
          direction: FileTransferDirection.incoming,
          fileName: '../../escape.sh',
          fileSize: 10,
          mimeType: 'text/plain',
          fileHash: 'h',
          localPath: '/p',
          stagingPath: '/s',
          totalChunks: 1,
          chunkSize: 10,
          status: FileTransferStatus.initiated,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('mapping between Drift FileTransferEntry and domain FileTransfer', () {
      final entry = FileTransferEntry(
        transferId: 'FT-ENTRY-1',
        conversationId: 'CONV-123',
        peerId: 'PEER-BOB',
        direction: 'incoming',
        fileName: 'image.png',
        fileSize: BigInt.from(102400),
        mimeType: 'image/png',
        fileHash: 'sha256-img-hash',
        localPath: '/files/image.png',
        stagingPath: '/staging/image.png.part',
        totalChunks: 7,
        chunkSize: 16384,
        status: 'transferring',
        createdAt: now,
        updatedAt: now,
      );

      // Convert from entry
      final domain = FileTransfer.fromEntry(entry);
      expect(domain.transferId, 'FT-ENTRY-1');
      expect(domain.conversationId, 'CONV-123');
      expect(domain.peerId, 'PEER-BOB');
      expect(domain.direction, FileTransferDirection.incoming);
      expect(domain.fileName, 'image.png');
      expect(domain.fileSize, 102400);
      expect(domain.status, FileTransferStatus.transferring);

      // Convert to companion
      final companion = domain.toCompanion();
      expect(companion.transferId.value, 'FT-ENTRY-1');
      expect(companion.fileSize.value, BigInt.from(102400));
      expect(companion.direction.value, 'incoming');
      expect(companion.status.value, 'transferring');
    });

    test('serialize -> deserialize produces equivalent FileTransfer', () {
      final original = FileTransfer(
        transferId: 'FT-SERIALIZE-TRANSFER',
        conversationId: 'PEER-CHARLIE',
        peerId: 'PEER-CHARLIE',
        direction: FileTransferDirection.outgoing,
        fileName: 'backup.zip',
        fileSize: 819200,
        mimeType: 'application/zip',
        fileHash: 'sha256-backup',
        localPath: '/files/backup.zip',
        stagingPath: '/staging/backup.zip.part',
        totalChunks: 50,
        chunkSize: 16384,
        status: FileTransferStatus.offerSent,
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final parsed = FileTransfer.fromJson(json);

      expect(parsed, equals(original));
      expect(parsed.hashCode, equals(original.hashCode));
    });
  });
}
