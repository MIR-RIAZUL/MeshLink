import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Phase 8 Step 2 — Drift Database Foundation Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    // Test 1: Schema version is 3
    test('Test 1: Schema version is 3', () {
      expect(db.schemaVersion, 3);
    });

    // Test 2: File transfer can be inserted
    test('Test 2: File transfer can be inserted', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      final rowId = await db.insertFileTransfer(
        FileTransfersTableCompanion(
          transferId: const Value('FT-1001'),
          conversationId: const Value('PEER-ALICE'),
          peerId: const Value('PEER-ALICE'),
          direction: const Value('outgoing'),
          fileName: const Value('sample.pdf'),
          fileSize: Value(BigInt.from(204800)),
          mimeType: const Value('application/pdf'),
          fileHash: const Value('hash-sample-12345'),
          localPath: const Value('/storage/sample.pdf'),
          stagingPath: const Value('/storage/staging/sample.pdf.part'),
          totalChunks: const Value(13),
          chunkSize: const Value(16384),
          status: const Value('pending'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      expect(rowId, greaterThan(0));
    });

    // Test 3: File transfer can be retrieved
    test('Test 3: File transfer can be retrieved with all fields intact', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.insertFileTransfer(
        FileTransfersTableCompanion(
          transferId: const Value('FT-1002'),
          conversationId: const Value('PEER-BOB'),
          peerId: const Value('PEER-BOB'),
          direction: const Value('incoming'),
          fileName: const Value('photo.jpg'),
          fileSize: Value(BigInt.from(1048576)),
          mimeType: const Value('image/jpeg'),
          fileHash: const Value('sha256-photo-abc'),
          localPath: const Value('/downloads/photo.jpg'),
          stagingPath: const Value('/staging/photo.part'),
          totalChunks: const Value(64),
          chunkSize: const Value(16384),
          status: const Value('offered'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final entry = await db.getFileTransfer('FT-1002');
      expect(entry, isNotNull);
      expect(entry!.transferId, 'FT-1002');
      expect(entry.conversationId, 'PEER-BOB');
      expect(entry.peerId, 'PEER-BOB');
      expect(entry.direction, 'incoming');
      expect(entry.fileName, 'photo.jpg');
      expect(entry.fileSize, BigInt.from(1048576));
      expect(entry.mimeType, 'image/jpeg');
      expect(entry.fileHash, 'sha256-photo-abc');
      expect(entry.localPath, '/downloads/photo.jpg');
      expect(entry.stagingPath, '/staging/photo.part');
      expect(entry.totalChunks, 64);
      expect(entry.chunkSize, 16384);
      expect(entry.status, 'offered');
      expect(entry.createdAt.toUtc(), now);
      expect(entry.updatedAt.toUtc(), now);
    });

    // Test 4: File transfer status can be updated
    test('Test 4: File transfer status can be updated', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: 'FT-1003',
          conversationId: 'PEER-CAROL',
          peerId: 'PEER-CAROL',
          direction: 'outgoing',
          fileName: 'notes.txt',
          fileSize: BigInt.from(512),
          mimeType: 'text/plain',
          fileHash: 'sha256-notes',
          localPath: '/files/notes.txt',
          stagingPath: '/staging/notes.txt.part',
          totalChunks: 1,
          chunkSize: 16384,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final updatedTime = DateTime.utc(2026, 10, 5, 12, 5, 0);
      final rowsAffected = await db.updateFileTransferStatus(
        'FT-1003',
        'transferring',
        updatedAt: updatedTime,
      );
      expect(rowsAffected, 1);

      final updated = await db.getFileTransfer('FT-1003');
      expect(updated, isNotNull);
      expect(updated!.status, 'transferring');
      expect(updated.updatedAt.toUtc(), updatedTime);
      expect(updated.createdAt.toUtc(), now);
    });

    // Test 5: Multiple transfers can coexist
    test('Test 5: Multiple transfers can coexist and query by peer', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: 'FT-A1',
          conversationId: 'PEER-1',
          peerId: 'PEER-1',
          direction: 'outgoing',
          fileName: 'doc1.pdf',
          fileSize: BigInt.from(1000),
          mimeType: 'application/pdf',
          fileHash: 'hash-doc1',
          localPath: '/p/doc1.pdf',
          stagingPath: '/s/doc1.part',
          totalChunks: 1,
          chunkSize: 16384,
          status: 'completed',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: 'FT-A2',
          conversationId: 'PEER-1',
          peerId: 'PEER-1',
          direction: 'incoming',
          fileName: 'doc2.pdf',
          fileSize: BigInt.from(2000),
          mimeType: 'application/pdf',
          fileHash: 'hash-doc2',
          localPath: '/p/doc2.pdf',
          stagingPath: '/s/doc2.part',
          totalChunks: 2,
          chunkSize: 16384,
          status: 'transferring',
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: 'FT-B1',
          conversationId: 'PEER-2',
          peerId: 'PEER-2',
          direction: 'outgoing',
          fileName: 'doc3.pdf',
          fileSize: BigInt.from(3000),
          mimeType: 'application/pdf',
          fileHash: 'hash-doc3',
          localPath: '/p/doc3.pdf',
          stagingPath: '/s/doc3.part',
          totalChunks: 3,
          chunkSize: 16384,
          status: 'pending',
          createdAt: now.add(const Duration(minutes: 2)),
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
      );

      final peer1Transfers = await db.getFileTransfersForPeer('PEER-1');
      expect(peer1Transfers.length, 2);
      expect(peer1Transfers.map((t) => t.transferId), containsAll(['FT-A1', 'FT-A2']));

      final allTransfers = await db.getAllFileTransfers();
      expect(allTransfers.length, 3);
      expect(allTransfers.first.transferId, 'FT-B1'); // Ordered desc by createdAt
    });

    // Test 6: File chunk can be inserted
    test('Test 6: File chunk can be inserted and retrieved', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      final rowId = await db.insertFileChunk(
        FileChunksTableCompanion.insert(
          transferId: 'FT-1004',
          chunkIndex: 0,
          status: 'pending',
          receivedAt: now,
        ),
      );
      expect(rowId, greaterThan(0));

      final chunk = await db.getFileChunk('FT-1004', 0);
      expect(chunk, isNotNull);
      expect(chunk!.transferId, 'FT-1004');
      expect(chunk.chunkIndex, 0);
      expect(chunk.status, 'pending');
      expect(chunk.receivedAt.toUtc(), now);
    });

    // Test 7: Multiple chunks can belong to one transfer
    test('Test 7: Multiple chunks can belong to one transfer and are ordered', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.insertFileChunk(
        FileChunksTableCompanion.insert(
          transferId: 'FT-1005',
          chunkIndex: 2,
          status: 'received',
          receivedAt: now.add(const Duration(seconds: 2)),
        ),
      );
      await db.insertFileChunk(
        FileChunksTableCompanion.insert(
          transferId: 'FT-1005',
          chunkIndex: 0,
          status: 'received',
          receivedAt: now,
        ),
      );
      await db.insertFileChunk(
        FileChunksTableCompanion.insert(
          transferId: 'FT-1005',
          chunkIndex: 1,
          status: 'received',
          receivedAt: now.add(const Duration(seconds: 1)),
        ),
      );

      final chunks = await db.getFileChunks('FT-1005');
      expect(chunks.length, 3);
      expect(chunks[0].chunkIndex, 0);
      expect(chunks[1].chunkIndex, 1);
      expect(chunks[2].chunkIndex, 2);
    });

    // Test 8: The same (transferId + chunkIndex) cannot create duplicate chunk records
    test('Test 8: The same (transferId + chunkIndex) cannot create duplicate chunk records', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.markChunkReceived('FT-1006', 0, status: 'pending', receivedAt: now);

      final chunksBefore = await db.getFileChunks('FT-1006');
      expect(chunksBefore.length, 1);
      expect(chunksBefore.first.status, 'pending');

      // Update same chunk to received
      final later = now.add(const Duration(seconds: 5));
      await db.markChunkReceived('FT-1006', 0, status: 'received', receivedAt: later);

      final chunksAfter = await db.getFileChunks('FT-1006');
      expect(chunksAfter.length, 1); // No duplicate entry created
      expect(chunksAfter.first.status, 'received');
      expect(chunksAfter.first.receivedAt.toUtc(), later);
    });

    // Test 9: Chunks from different transfers remain isolated
    test('Test 9: Chunks from different transfers remain isolated and can be deleted cleanly', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.markChunkReceived('FT-T1', 0, receivedAt: now);
      await db.markChunkReceived('FT-T1', 1, receivedAt: now);
      await db.markChunkReceived('FT-T2', 0, receivedAt: now);

      expect((await db.getFileChunks('FT-T1')).length, 2);
      expect((await db.getFileChunks('FT-T2')).length, 1);

      // Delete only FT-T1 chunks
      final deletedCount = await db.deleteFileChunks('FT-T1');
      expect(deletedCount, 2);

      expect((await db.getFileChunks('FT-T1')).isEmpty, true);
      expect((await db.getFileChunks('FT-T2')).length, 1);
    });

    // Test 10: Existing MessagesTable data remains intact
    test('Test 10: Existing MessagesTable data remains intact alongside file transfers', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.insertMessage(
        MessagesTableCompanion.insert(
          messageId: 'MSG-TEST-100',
          conversationId: 'PEER-X',
          senderId: 'PEER-X',
          receiverId: 'LOCAL',
          textContent: 'Hello from Phase 7 text messaging',
          createdAt: now,
          status: 'delivered',
        ),
      );

      // Add a file transfer
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: 'FT-MSG-COEXIST',
          conversationId: 'PEER-X',
          peerId: 'PEER-X',
          direction: 'incoming',
          fileName: 'audio.m4a',
          fileSize: BigInt.from(50000),
          mimeType: 'audio/mp4',
          fileHash: 'sha256-audio',
          localPath: '/p/audio.m4a',
          stagingPath: '/s/audio.m4a.part',
          totalChunks: 4,
          chunkSize: 16384,
          status: 'completed',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final hasMsg = await db.hasMessage('MSG-TEST-100');
      expect(hasMsg, true);

      final messages = await db.getMessagesForConversation('PEER-X');
      expect(messages.length, 1);
      expect(messages.first.textContent, 'Hello from Phase 7 text messaging');
    });

    // Test 11: Existing PeerIdentitiesTable data remains intact
    test('Test 11: Existing PeerIdentitiesTable data remains intact alongside file transfers', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      await db.savePeerIdentity(
        PeerIdentitiesTableCompanion.insert(
          peerId: 'PEER-ALICE-SECURE',
          identityPublicKey: 'b64url_ed25519_alice_key',
          safetyNumber: '123456',
          trustStatus: 'verified',
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );

      // Insert file transfer for this peer
      await db.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: 'FT-ALICE-1',
          conversationId: 'PEER-ALICE-SECURE',
          peerId: 'PEER-ALICE-SECURE',
          direction: 'outgoing',
          fileName: 'vault.enc',
          fileSize: BigInt.from(1234),
          mimeType: 'application/octet-stream',
          fileHash: 'sha256-vault',
          localPath: '/p/vault.enc',
          stagingPath: '/s/vault.enc.part',
          totalChunks: 1,
          chunkSize: 16384,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final identity = await db.getPeerIdentity('PEER-ALICE-SECURE');
      expect(identity, isNotNull);
      expect(identity!.identityPublicKey, 'b64url_ed25519_alice_key');
      expect(identity.safetyNumber, '123456');
      expect(identity.trustStatus, 'verified');
    });

    // Test 12: Existing SeenPacketsTable data remains intact
    test('Test 12: Existing SeenPacketsTable data remains intact alongside file transfers', () async {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      final firstSeen = await db.checkAndMarkSeen(
        packetType: 'file_chunk',
        originId: 'PEER-ORIGIN-1',
        packetId: 'CHUNK-001',
        receivedAt: now,
      );
      expect(firstSeen, true);

      // Replay must be detected as already seen
      final replay = await db.checkAndMarkSeen(
        packetType: 'file_chunk',
        originId: 'PEER-ORIGIN-1',
        packetId: 'CHUNK-001',
        receivedAt: now,
      );
      expect(replay, false);

      final hasSeen = await db.hasSeenPacket('file_chunk:PEER-ORIGIN-1:CHUNK-001');
      expect(hasSeen, true);
    });

    // Test 13: Database can be closed and reopened while preserving file-transfer data
    test('Test 13: Database can be closed and reopened preserving file transfer data', () async {
      final tempDir = await Directory.systemTemp.createTemp('meshlink_db_step2_');
      final dbFile = File('${tempDir.path}/test_persist.db');

      try {
        final db1 = AppDatabase(NativeDatabase(dbFile));
        final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
        await db1.insertFileTransfer(
          FileTransfersTableCompanion.insert(
            transferId: 'FT-PERSIST-1',
            conversationId: 'PEER-PERSIST',
            peerId: 'PEER-PERSIST',
            direction: 'outgoing',
            fileName: 'persisted_doc.bin',
            fileSize: BigInt.from(65536),
            mimeType: 'application/octet-stream',
            fileHash: 'sha256-persisted',
            localPath: '/files/persisted_doc.bin',
            stagingPath: '/staging/persisted_doc.bin.part',
            totalChunks: 4,
            chunkSize: 16384,
            status: 'transferring',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await db1.markChunkReceived('FT-PERSIST-1', 0, status: 'received', receivedAt: now);
        await db1.markChunkReceived('FT-PERSIST-1', 1, status: 'received', receivedAt: now);

        await db1.close();

        // Reopen database from same file
        final db2 = AppDatabase(NativeDatabase(dbFile));
        final transfer = await db2.getFileTransfer('FT-PERSIST-1');
        expect(transfer, isNotNull);
        expect(transfer!.fileName, 'persisted_doc.bin');
        expect(transfer.status, 'transferring');
        expect(transfer.fileSize, BigInt.from(65536));

        final chunks = await db2.getFileChunks('FT-PERSIST-1');
        expect(chunks.length, 2);
        expect(chunks[0].chunkIndex, 0);
        expect(chunks[1].chunkIndex, 1);

        await db2.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    // Test 14: Migration from schema version 2 to 3 preserves existing data
    test('Test 14: Migration from schema version 2 to 3 preserves existing data and creates new tables', () async {
      final rawConnection = NativeDatabase.memory();
      final tempDb = AppDatabase(rawConnection);

      // Simulate existing schema v2 state
      final now = DateTime.utc(2026, 10, 1);
      await tempDb.insertMessage(
        MessagesTableCompanion.insert(
          messageId: 'MIG-MSG-1',
          conversationId: 'PEER-MIG',
          senderId: 'PEER-MIG',
          receiverId: 'LOCAL',
          textContent: 'Preserve me across v2 -> v3',
          createdAt: now,
          status: 'delivered',
        ),
      );

      await tempDb.savePeerIdentity(
        PeerIdentitiesTableCompanion.insert(
          peerId: 'PEER-MIG',
          identityPublicKey: 'b64url_mig_key',
          safetyNumber: '654321',
          trustStatus: 'verified',
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );

      await tempDb.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'PEER-MIG',
        packetId: 'PKT-MIG-1',
        receivedAt: now,
      );

      // Perform migration from v2 to v3
      final migrator = tempDb.createMigrator();
      await tempDb.migration.onUpgrade(migrator, 2, 3);

      // 1. Verify v2 data is intact
      final messages = await tempDb.getMessagesForConversation('PEER-MIG');
      expect(messages.length, 1);
      expect(messages.first.textContent, 'Preserve me across v2 -> v3');

      final identity = await tempDb.getPeerIdentity('PEER-MIG');
      expect(identity, isNotNull);
      expect(identity!.safetyNumber, '654321');

      final isSeen = await tempDb.hasSeenPacket('encrypted_message:PEER-MIG:PKT-MIG-1');
      expect(isSeen, true);

      // 2. Verify new tables are active and operational
      await tempDb.insertFileTransfer(
        FileTransfersTableCompanion.insert(
          transferId: 'FT-MIG-1',
          conversationId: 'PEER-MIG',
          peerId: 'PEER-MIG',
          direction: 'incoming',
          fileName: 'migrated.zip',
          fileSize: BigInt.from(10000),
          mimeType: 'application/zip',
          fileHash: 'sha256-migrated',
          localPath: '/files/migrated.zip',
          stagingPath: '/staging/migrated.zip.part',
          totalChunks: 1,
          chunkSize: 16384,
          status: 'completed',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final transfer = await tempDb.getFileTransfer('FT-MIG-1');
      expect(transfer, isNotNull);
      expect(transfer!.fileName, 'migrated.zip');

      await tempDb.close();
    });
  });
}
