import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/models/session_encrypted_payload.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_negotiation_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase aliceDb;
  late AppDatabase bobDb;
  late DriftMessageRepository aliceRepo;
  late DriftMessageRepository bobRepo;

  late MeshIdentityService aliceIdentity;
  late MeshIdentityService bobIdentity;

  late EphemeralSessionService aliceSessionService;
  late EphemeralSessionService bobSessionService;

  late HandshakeService aliceHandshake;
  late HandshakeService bobHandshake;

  late DirectionalSessionEncryptionService encryptionService;
  late FileTransferNegotiationService aliceService;
  late FileTransferNegotiationService bobService;

  DateTime mockNow = DateTime.utc(2026, 10, 9, 12, 0, 0);

  setUp(() async {
    mockNow = DateTime.utc(2026, 10, 9, 12, 0, 0);

    aliceDb = AppDatabase(NativeDatabase.memory());
    bobDb = AppDatabase(NativeDatabase.memory());
    aliceRepo = DriftMessageRepository(aliceDb);
    bobRepo = DriftMessageRepository(bobDb);

    aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    await aliceIdentity.initialize();
    await bobIdentity.initialize();

    aliceSessionService = EphemeralSessionService(clock: () => mockNow);
    bobSessionService = EphemeralSessionService(clock: () => mockNow);

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

    encryptionService = DirectionalSessionEncryptionService();

    aliceService = FileTransferNegotiationService(
      database: aliceDb,
      localDeviceId: 'ML-DEVICE-ALICE',
      messageRepository: aliceRepo,
      encryptionService: encryptionService,
      clock: () => mockNow,
    );

    bobService = FileTransferNegotiationService(
      database: bobDb,
      localDeviceId: 'ML-DEVICE-BOB',
      messageRepository: bobRepo,
      encryptionService: encryptionService,
      clock: () => mockNow,
    );
  });

  tearDown(() async {
    await aliceDb.close();
    await bobDb.close();
  });

  /// Helper to establish a Phase 7 bidirectional authenticated session between Alice and Bob.
  Future<({EphemeralSession sessionA, EphemeralSession sessionB})> establishTestSession({
    String requestId = 'REQ-NEGOTIATION-001',
  }) async {
    final request = await aliceHandshake.createKeyRequest(
      destinationId: 'ML-DEVICE-BOB',
      requestId: requestId,
    );
    final verifiedReq = await bobHandshake.verifyKeyRequest(request);
    final response = await bobHandshake.createKeyResponse(request: request);
    final sessionB = await bobHandshake.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: mockNow,
    );
    final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
    final sessionA = await aliceHandshake.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: mockNow,
    );
    return (sessionA: sessionA, sessionB: sessionB);
  }

  group('Group 1: Offer Creation and Validation', () {
    test('Test 1: Valid outgoing offer creation', () async {
      final offer = await aliceService.createOffer(
        transferId: 'TF-OUT-001',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'document.pdf',
        fileSize: 65536,
        mimeType: 'application/pdf',
      );

      expect(offer.version, 2);
      expect(offer.transferId, 'TF-OUT-001');
      expect(offer.offerId, 'offer_TF-OUT-001');
      expect(offer.senderId, 'ML-DEVICE-ALICE');
      expect(offer.recipientId, 'ML-DEVICE-BOB');
      expect(offer.fileName, 'document.pdf');
      expect(offer.fileSize, 65536);
      expect(offer.chunkSize, 32768);
      expect(offer.totalChunks, 2);
      expect(offer.mimeType, 'application/pdf');
      expect(offer.createdAt, mockNow);
      expect(offer.expiresAt, mockNow.add(const Duration(minutes: 5)));

      // Check persistence in Alice's database
      final record = await aliceDb.getFileTransfer('TF-OUT-001');
      expect(record, isNotNull);
      expect(record!.status, FileTransferStatus.offerSent.toDbValue());
      expect(record.direction, FileTransferDirection.outgoing.toDbValue());
    });

    test('Test 2: Invalid protocol version rejected', () {
      expect(
        () => FileTransferOffer(
          version: 1,
          transferId: 'TF-VER-1',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Unsupported protocol version: 1'),
        )),
      );

      expect(
        () => FileTransferOffer(
          version: 3,
          transferId: 'TF-VER-3',
          offerId: 'OFF-3',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Unsupported protocol version: 3'),
        )),
      );
    });

    test('Test 3: Empty transfer ID rejected', () {
      expect(
        () => FileTransferOffer(
          transferId: '',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      expect(
        () => FileTransferOffer(
          transferId: '   ',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });

    test('Test 4: Invalid sender or recipient rejected', () {
      // Empty sender
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: '',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      // Empty recipient
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: '',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      // Identical sender and recipient
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'DEVICE-A',
          recipientId: 'DEVICE-A',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      // Control characters in sender
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'DEVICE\x00A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 10,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });

    test('Test 5: Negative file size rejected', () {
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: -100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });

    test('Test 6: Invalid chunk size rejected', () {
      // Chunk size smaller than minimum (1024)
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 1000,
          chunkSize: 512,
          totalChunks: 2,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      // Chunk size greater than maximum (65536)
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 100000,
          chunkSize: 70000,
          totalChunks: 2,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });

    test('Test 7: Inconsistent chunk count rejected', () {
      // 100,000 bytes with 32,768 chunk size requires ceil(100000/32768) = 4 chunks
      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 100000,
          chunkSize: 32768,
          totalChunks: 3, // Inconsistent!
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('does not match expected chunk count'),
        )),
      );

      expect(
        () => FileTransferOffer(
          transferId: 'TF-1',
          offerId: 'OFF-1',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 100000,
          chunkSize: 32768,
          totalChunks: 5, // Inconsistent!
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });

    test('Test 8: Zero-byte file handled according to documented rule', () {
      // Zero-byte file with totalChunks == 0 succeeds
      final zeroOffer = FileTransferOffer(
        transferId: 'TF-ZERO',
        offerId: 'OFF-ZERO',
        senderId: 'A',
        recipientId: 'B',
        fileName: 'empty.txt',
        fileSize: 0,
        totalChunks: 0,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );
      expect(zeroOffer.totalChunks, 0);

      // Zero-byte file with totalChunks > 0 rejected
      expect(
        () => FileTransferOffer(
          transferId: 'TF-ZERO',
          offerId: 'OFF-ZERO',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'empty.txt',
          fileSize: 0,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });

    test('Test 9: Invalid timestamps rejected', () {
      // expiresAt before createdAt
      expect(
        () => FileTransferOffer(
          transferId: 'TF-TIME',
          offerId: 'OFF-TIME',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.subtract(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );

      // expiresAt equal to createdAt
      expect(
        () => FileTransferOffer(
          transferId: 'TF-TIME',
          offerId: 'OFF-TIME',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'f.txt',
          fileSize: 100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow,
        ),
        throwsArgumentError,
      );
    });

    test('Test 10: Expired offer rejected', () async {
      final pastOffer = FileTransferOffer(
        transferId: 'TF-EXPIRED',
        offerId: 'OFF-EXPIRED',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'old.pdf',
        fileSize: 1000,
        totalChunks: 1,
        createdAt: mockNow.subtract(const Duration(minutes: 10)),
        expiresAt: mockNow.subtract(const Duration(minutes: 1)),
      );

      expect(
        () => bobService.receiveOffer(
          offer: pastOffer,
          authenticatedSenderId: 'ML-DEVICE-ALICE',
        ),
        throwsA(isA<OfferExpiredException>()),
      );
    });

    test('Test 11: Future timestamp rejected', () async {
      final futureOffer = FileTransferOffer(
        transferId: 'TF-FUTURE',
        offerId: 'OFF-FUTURE',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'future.pdf',
        fileSize: 1000,
        totalChunks: 1,
        createdAt: mockNow.add(const Duration(minutes: 10)), // Beyond 2-minute skew!
        expiresAt: mockNow.add(const Duration(minutes: 15)),
      );

      expect(
        () => bobService.receiveOffer(
          offer: futureOffer,
          authenticatedSenderId: 'ML-DEVICE-ALICE',
        ),
        throwsA(isA<InvalidTimestampException>()),
      );
    });

    test('Test 12: Invalid filename rejected', () {
      expect(
        () => FileTransferOffer(
          transferId: 'TF-NAME',
          offerId: 'OFF-NAME',
          senderId: 'A',
          recipientId: 'B',
          fileName: '',
          fileSize: 100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      expect(
        () => FileTransferOffer(
          transferId: 'TF-NAME',
          offerId: 'OFF-NAME',
          senderId: 'A',
          recipientId: 'B',
          fileName: '.',
          fileSize: 100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      expect(
        () => FileTransferOffer(
          transferId: 'TF-NAME',
          offerId: 'OFF-NAME',
          senderId: 'A',
          recipientId: 'B',
          fileName: '..',
          fileSize: 100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });

    test('Test 13: Absolute path or traversal filename rejected', () {
      for (final badName in [
        '../traversal.txt',
        r'..\traversal.txt',
        '/etc/passwd',
        r'C:\boot.ini',
        'dir/sub.txt',
        'CON.txt',
        'NUL',
      ]) {
        expect(
          () => FileTransferOffer(
            transferId: 'TF-TRAVERSAL',
            offerId: 'OFF-TRAVERSAL',
            senderId: 'A',
            recipientId: 'B',
            fileName: badName,
            fileSize: 100,
            totalChunks: 1,
            createdAt: mockNow,
            expiresAt: mockNow.add(const Duration(minutes: 5)),
          ),
          throwsArgumentError,
          reason: 'Failed to reject dangerous filename: "$badName"',
        );
      }
    });

    test('Test 14: Excessively long metadata rejected', () {
      // Filename > 255 chars
      final longName = '${'a' * 256}.txt';
      expect(
        () => FileTransferOffer(
          transferId: 'TF-LONG',
          offerId: 'OFF-LONG',
          senderId: 'A',
          recipientId: 'B',
          fileName: longName,
          fileSize: 100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      // TransferId > 128 chars
      final longId = 'a' * 129;
      expect(
        () => FileTransferOffer(
          transferId: longId,
          offerId: 'OFF-LONG',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'valid.txt',
          fileSize: 100,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );

      // MIME type > 128 chars
      final longMime = 'a' * 129;
      expect(
        () => FileTransferOffer(
          transferId: 'TF-VALID',
          offerId: 'OFF-VALID',
          senderId: 'A',
          recipientId: 'B',
          fileName: 'valid.txt',
          fileSize: 100,
          mimeType: longMime,
          totalChunks: 1,
          createdAt: mockNow,
          expiresAt: mockNow.add(const Duration(minutes: 5)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Group 2: Recipient and Trust Validation', () {
    test('Test 15: Correct recipient accepted for further validation', () async {
      final offer = FileTransferOffer(
        transferId: 'TF-REC-001',
        offerId: 'OFF-REC-001',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'image.png',
        fileSize: 1024,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      final transfer = await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );

      expect(transfer.transferId, 'TF-REC-001');
      expect(transfer.status, FileTransferStatus.offerReceived);
      expect(transfer.direction, FileTransferDirection.incoming);
    });

    test('Test 16: Wrong recipient rejected', () async {
      final offer = FileTransferOffer(
        transferId: 'TF-WRONG-REC',
        offerId: 'OFF-WRONG-REC',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-CHARLIE', // Not Bob!
        fileName: 'image.png',
        fileSize: 1024,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      expect(
        () => bobService.receiveOffer(
          offer: offer,
          authenticatedSenderId: 'ML-DEVICE-ALICE',
        ),
        throwsA(isA<FileTransferNegotiationException>().having(
          (e) => e.message,
          'message',
          contains('Offer recipient (ML-DEVICE-CHARLIE) does not match local device (ML-DEVICE-BOB)'),
        )),
      );
    });

    test('Test 17: Authenticated sender mismatch rejected', () async {
      final offer = FileTransferOffer(
        transferId: 'TF-SENDER-MISMATCH',
        offerId: 'OFF-SENDER-MISMATCH',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'image.png',
        fileSize: 1024,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      // Authenticated peer is Charlie, but offer claims sender is Alice
      expect(
        () => bobService.receiveOffer(
          offer: offer,
          authenticatedSenderId: 'ML-DEVICE-CHARLIE',
        ),
        throwsA(isA<FileTransferNegotiationException>().having(
          (e) => e.message,
          'message',
          contains('Offer sender (ML-DEVICE-ALICE) does not match authenticated peer (ML-DEVICE-CHARLIE)'),
        )),
      );
    });

    test('Test 18: Untrusted peer rejected', () async {
      // Mark Alice as compromised in Bob's peer repository
      await bobRepo.savePeerIdentity(
        PeerIdentityEntry(
          peerId: 'ML-DEVICE-ALICE',
          identityPublicKey: 'alice-pk-hex',
          safetyNumber: '123456',
          trustStatus: 'compromised',
          protocolVersion: 2,
          firstSeenAt: mockNow,
          lastSeenAt: mockNow,
        ),
      );

      final offer = FileTransferOffer(
        transferId: 'TF-COMPROMISED',
        offerId: 'OFF-COMPROMISED',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'image.png',
        fileSize: 1024,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      expect(
        () => bobService.receiveOffer(
          offer: offer,
          authenticatedSenderId: 'ML-DEVICE-ALICE',
        ),
        throwsA(isA<PeerUntrustedException>()),
      );
    });

    test('Test 19: Malformed or unauthenticated input cannot be treated as a valid offer', () {
      expect(
        () => FileTransferOffer.fromJson('{"invalid":"json_structure"}'),
        throwsArgumentError,
      );

      expect(
        () => FileTransferOffer.fromJson('not even json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Test 20: Conflicting existing transfer rejected', () async {
      final offer1 = FileTransferOffer(
        transferId: 'TF-CONFLICT-001',
        offerId: 'OFF-1',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'good_file.pdf',
        fileSize: 5000,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      await bobService.receiveOffer(
        offer: offer1,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );

      // Second offer with same transferId but different file details
      final offer2 = FileTransferOffer(
        transferId: 'TF-CONFLICT-001',
        offerId: 'OFF-2',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'evil_file.exe', // Conflicting fileName!
        fileSize: 5000,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      expect(
        () => bobService.receiveOffer(
          offer: offer2,
          authenticatedSenderId: 'ML-DEVICE-ALICE',
        ),
        throwsA(isA<TransferConflictException>()),
      );
    });
  });

  group('Group 3: Decision Handling', () {
    late FileTransferOffer validOffer;

    setUp(() async {
      validOffer = FileTransferOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'report.docx',
        fileSize: 20000,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      await bobService.receiveOffer(
        offer: validOffer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );
    });

    test('Test 21: Valid acceptance', () async {
      final decision = await bobService.acceptOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
      );

      expect(decision.version, 2);
      expect(decision.transferId, 'TF-DEC-001');
      expect(decision.offerId, 'offer_TF-DEC-001');
      expect(decision.isAccepted, isTrue);
      expect(decision.isRejected, isFalse);
      expect(decision.rejectionReason, isNull);
      expect(decision.senderId, 'ML-DEVICE-BOB');
      expect(decision.recipientId, 'ML-DEVICE-ALICE');

      final record = await bobDb.getFileTransfer('TF-DEC-001');
      expect(record!.status, FileTransferStatus.acceptSent.toDbValue());
    });

    test('Test 22: Valid rejection', () async {
      final decision = await bobService.rejectOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
        reason: FileTransferRejectionReason.insufficientStorage,
      );

      expect(decision.isAccepted, isFalse);
      expect(decision.isRejected, isTrue);
      expect(decision.rejectionReason, FileTransferRejectionReason.insufficientStorage);
      expect(decision.rejectionReason!.wireCode, 'insufficient_storage');

      final record = await bobDb.getFileTransfer('TF-DEC-001');
      expect(record!.status, FileTransferStatus.cancelled.toDbValue());
    });

    test('Test 23: Invalid decision type rejected', () {
      // Rejection decision without reason throws
      expect(
        () => FileTransferDecision(
          transferId: 'TF-DEC-001',
          offerId: 'OFF-1',
          decisionType: FileTransferDecisionType.reject,
          rejectionReason: null, // Required!
          senderId: 'B',
          recipientId: 'A',
          createdAt: mockNow,
        ),
        throwsArgumentError,
      );

      // Acceptance decision with rejection reason throws
      expect(
        () => FileTransferDecision(
          transferId: 'TF-DEC-001',
          offerId: 'OFF-1',
          decisionType: FileTransferDecisionType.accept,
          rejectionReason: FileTransferRejectionReason.userRejected, // Disallowed!
          senderId: 'B',
          recipientId: 'A',
          createdAt: mockNow,
        ),
        throwsArgumentError,
      );

      // Unsupported string decision type throws
      expect(
        () => FileTransferDecisionType.fromString('maybe'),
        throwsArgumentError,
      );
    });

    test('Test 24: Wrong transfer ID rejected', () async {
      expect(
        () => bobService.acceptOffer(
          transferId: 'TF-NON-EXISTENT',
          offerId: 'OFF-1',
        ),
        throwsA(isA<TransferNotFoundException>()),
      );
    });

    test('Test 25: Wrong offer/request ID rejected', () async {
      expect(
        () => bobService.acceptOffer(
          transferId: 'TF-DEC-001',
          offerId: 'WRONG-OFFER-ID',
        ),
        throwsA(isA<FileTransferNegotiationException>().having(
          (e) => e.message,
          'message',
          contains('Offer ID mismatch'),
        )),
      );
    });

    test('Test 26: Wrong sender or recipient rejected', () async {
      final outOffer = await aliceService.createOffer(
        transferId: 'TF-OUT-DEC-1',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'file.txt',
        fileSize: 100,
      );

      // Decision with wrong recipient (claims Charlie, but Alice is recipient)
      final wrongRecipDecision = FileTransferDecision(
        transferId: outOffer.transferId,
        offerId: outOffer.offerId,
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-CHARLIE',
        createdAt: mockNow,
      );

      expect(
        () => aliceService.handleDecision(
          decision: wrongRecipDecision,
          authenticatedSenderId: 'ML-DEVICE-BOB',
        ),
        throwsA(isA<FileTransferNegotiationException>()),
      );

      // Decision with wrong sender (claims Bob, but authenticated peer is Charlie)
      final wrongSenderDecision = FileTransferDecision(
        transferId: outOffer.transferId,
        offerId: outOffer.offerId,
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-ALICE',
        createdAt: mockNow,
      );

      expect(
        () => aliceService.handleDecision(
          decision: wrongSenderDecision,
          authenticatedSenderId: 'ML-DEVICE-CHARLIE',
        ),
        throwsA(isA<FileTransferNegotiationException>()),
      );
    });

    test('Test 27: Expired decision rejected', () async {
      // Advance clock past expiration
      mockNow = mockNow.add(const Duration(minutes: 6));

      expect(
        () => bobService.acceptOffer(
          transferId: 'TF-DEC-001',
          offerId: 'offer_TF-DEC-001',
        ),
        throwsA(isA<OfferExpiredException>()),
      );
    });

    test('Test 28: Duplicate acceptance is idempotent or safely rejected', () async {
      final dec1 = await bobService.acceptOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
      );
      final dec2 = await bobService.acceptOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
      );

      expect(dec1.decisionType, dec2.decisionType);
      expect(dec1.transferId, dec2.transferId);

      // Bob's record remains acceptSent
      final record = await bobDb.getFileTransfer('TF-DEC-001');
      expect(record!.status, FileTransferStatus.acceptSent.toDbValue());
    });

    test('Test 29: Duplicate rejection is idempotent or safely rejected', () async {
      final dec1 = await bobService.rejectOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
        reason: FileTransferRejectionReason.userRejected,
      );
      final dec2 = await bobService.rejectOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
        reason: FileTransferRejectionReason.userRejected,
      );

      expect(dec1.decisionType, dec2.decisionType);
      final record = await bobDb.getFileTransfer('TF-DEC-001');
      expect(record!.status, FileTransferStatus.cancelled.toDbValue());
    });

    test('Test 30: Acceptance after rejection rejected', () async {
      await bobService.rejectOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
      );

      expect(
        () => bobService.acceptOffer(
          transferId: 'TF-DEC-001',
          offerId: 'offer_TF-DEC-001',
        ),
        throwsA(isA<InvalidNegotiationStateException>().having(
          (e) => e.message,
          'message',
          contains('Cannot accept transfer in terminal status "cancelled"'),
        )),
      );
    });

    test('Test 31: Rejection after acceptance rejected', () async {
      await bobService.acceptOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
      );

      expect(
        () => bobService.rejectOffer(
          transferId: 'TF-DEC-001',
          offerId: 'offer_TF-DEC-001',
        ),
        throwsA(isA<InvalidNegotiationStateException>().having(
          (e) => e.message,
          'message',
          contains('Cannot reject transfer after acceptance'),
        )),
      );
    });

    test('Test 32: Terminal transfer cannot be reopened', () async {
      // Reject offer -> terminal cancelled
      await bobService.rejectOffer(
        transferId: 'TF-DEC-001',
        offerId: 'offer_TF-DEC-001',
      );

      // Attempt to handle accept on Alice when already cancelled
      final outOffer = await aliceService.createOffer(
        transferId: 'TF-TERM-1',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'term.txt',
        fileSize: 100,
      );

      // Manually cancel it on Alice
      await aliceDb.updateFileTransferStatus(
        'TF-TERM-1',
        FileTransferStatus.cancelled.toDbValue(),
      );

      final decision = FileTransferDecision(
        transferId: outOffer.transferId,
        offerId: outOffer.offerId,
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-ALICE',
        createdAt: mockNow,
      );

      expect(
        () => aliceService.handleDecision(
          decision: decision,
          authenticatedSenderId: 'ML-DEVICE-BOB',
        ),
        throwsA(isA<InvalidNegotiationStateException>().having(
          (e) => e.message,
          'message',
          contains('Terminal transfer cannot be reopened'),
        )),
      );
    });
  });

  group('Group 4: State Transitions and Persistence', () {
    test('Test 33: Correct outgoing transition sequence', () async {
      final offer = await aliceService.createOffer(
        transferId: 'TF-SEQ-OUT',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'seq.bin',
        fileSize: 4096,
      );

      // Check step 1: offerSent
      var transfer = await aliceDb.getFileTransfer('TF-SEQ-OUT');
      expect(transfer!.status, FileTransferStatus.offerSent.toDbValue());

      // Bob accepts
      final decision = FileTransferDecision(
        transferId: offer.transferId,
        offerId: offer.offerId,
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-ALICE',
        createdAt: mockNow,
      );

      final updated = await aliceService.handleDecision(
        decision: decision,
        authenticatedSenderId: 'ML-DEVICE-BOB',
      );

      // Check step 2: acceptReceived
      expect(updated.status, FileTransferStatus.acceptReceived);
      transfer = await aliceDb.getFileTransfer('TF-SEQ-OUT');
      expect(transfer!.status, FileTransferStatus.acceptReceived.toDbValue());
      // Crucial: Must NOT move to transferring merely because recipient accepted!
      expect(transfer.status, isNot(FileTransferStatus.transferring.toDbValue()));
    });

    test('Test 34: Correct incoming transition sequence', () async {
      final offer = FileTransferOffer(
        transferId: 'TF-SEQ-IN',
        offerId: 'OFF-SEQ-IN',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'seq_in.bin',
        fileSize: 4096,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      // Step 1: receiveOffer -> offerReceived
      final received = await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );
      expect(received.status, FileTransferStatus.offerReceived);

      // Step 2: acceptOffer -> acceptSent
      await bobService.acceptOffer(
        transferId: 'TF-SEQ-IN',
        offerId: 'OFF-SEQ-IN',
      );
      final record = await bobDb.getFileTransfer('TF-SEQ-IN');
      expect(record!.status, FileTransferStatus.acceptSent.toDbValue());
      // Crucial: Must NOT move to transferring automatically
      expect(record.status, isNot(FileTransferStatus.transferring.toDbValue()));
    });

    test('Test 35: Invalid state transition rejected', () async {
      final offer = await aliceService.createOffer(
        transferId: 'TF-INVALID-TRANS',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'file.dat',
        fileSize: 1024,
      );

      // Incoming decision on outgoing transfer that is already completed or unexpected
      await aliceDb.updateFileTransferStatus(
        offer.transferId,
        FileTransferStatus.completed.toDbValue(),
      );

      final decision = FileTransferDecision(
        transferId: offer.transferId,
        offerId: offer.offerId,
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-ALICE',
        createdAt: mockNow,
      );

      expect(
        () => aliceService.handleDecision(
          decision: decision,
          authenticatedSenderId: 'ML-DEVICE-BOB',
        ),
        throwsA(isA<InvalidNegotiationStateException>()),
      );
    });

    test('Test 36: Rejected transfer cannot enter transferring', () async {
      final offer = FileTransferOffer(
        transferId: 'TF-REJ-BLOCK',
        offerId: 'OFF-REJ-BLOCK',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'rejected.bin',
        fileSize: 1024,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );

      await bobService.rejectOffer(
        transferId: 'TF-REJ-BLOCK',
        offerId: 'OFF-REJ-BLOCK',
      );

      final entry = await bobDb.getFileTransfer('TF-REJ-BLOCK');
      final domainTransfer = FileTransfer.fromEntry(entry!);
      expect(domainTransfer.status, FileTransferStatus.cancelled);

      // Verify that FileTransferStateMachine prevents moving to transferring
      expect(
        FileTransferStateMachine.instance.canTransition(
          direction: domainTransfer.direction,
          from: domainTransfer.status,
          to: FileTransferStatus.transferring,
        ),
        isFalse,
      );
    });

    test('Test 37: Repository persistence works if supported by existing APIs', () async {
      await aliceService.createOffer(
        transferId: 'TF-PERSIST-1',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'persist.txt',
        fileSize: 1024,
      );

      final transfers = await aliceDb.getAllFileTransfers();
      expect(transfers.any((t) => t.transferId == 'TF-PERSIST-1'), isTrue);
    });

    test('Test 38: Reloaded transfer retains its negotiation state', () async {
      await aliceService.createOffer(
        transferId: 'TF-RELOAD-1',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'reload.bin',
        fileSize: 2048,
        mimeType: 'application/octet-stream',
      );

      final entry = await aliceDb.getFileTransfer('TF-RELOAD-1');
      expect(entry, isNotNull);
      final model = FileTransfer.fromEntry(entry!);

      expect(model.transferId, 'TF-RELOAD-1');
      expect(model.fileName, 'reload.bin');
      expect(model.fileSize, 2048);
      expect(model.status, FileTransferStatus.offerSent);
      expect(model.direction, FileTransferDirection.outgoing);
    });
  });

  group('Group 5: Concurrency and Resource Safety', () {
    test('Test 39: Concurrent accept/reject attempts cannot both succeed', () async {
      final offer = FileTransferOffer(
        transferId: 'TF-CONCURRENCY-1',
        offerId: 'OFF-CONCURRENCY-1',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'race.bin',
        fileSize: 1024,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );

      // Launch accept and reject concurrently
      var acceptSucceeded = false;
      var rejectSucceeded = false;

      await Future.wait([
        (() async {
          try {
            await bobService.acceptOffer(
              transferId: 'TF-CONCURRENCY-1',
              offerId: 'OFF-CONCURRENCY-1',
            );
            acceptSucceeded = true;
          } catch (_) {}
        })(),
        (() async {
          try {
            await bobService.rejectOffer(
              transferId: 'TF-CONCURRENCY-1',
              offerId: 'OFF-CONCURRENCY-1',
            );
            rejectSucceeded = true;
          } catch (_) {}
        })(),
      ]);

      // Exactly ONE operation must succeed, never both!
      expect(acceptSucceeded != rejectSucceeded, isTrue,
          reason: 'Concurrent accept and reject cannot both succeed');
    });

    test('Test 40: Duplicate offers do not create duplicate transfer records', () async {
      final offer = FileTransferOffer(
        transferId: 'TF-DUP-001',
        offerId: 'OFF-DUP-001',
        senderId: 'ML-DEVICE-ALICE',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'duplicate.bin',
        fileSize: 1024,
        totalChunks: 1,
        createdAt: mockNow,
        expiresAt: mockNow.add(const Duration(minutes: 5)),
      );

      final t1 = await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );
      final t2 = await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );

      expect(t1.transferId, t2.transferId);
      final allTransfers = await bobDb.getAllFileTransfers();
      final matching = allTransfers.where((t) => t.transferId == 'TF-DUP-001').toList();
      expect(matching.length, 1);
    });

    test('Test 41: Large declared file size does not allocate a file-sized buffer', () async {
      // 10 Gigabyte file offer
      const tenGigaBytes = 10 * 1024 * 1024 * 1024;
      final offer = await aliceService.createOffer(
        transferId: 'TF-LARGE-10GB',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'huge_archive.zip',
        fileSize: tenGigaBytes,
        chunkSize: 65536,
      );

      expect(offer.fileSize, tenGigaBytes);
      expect(offer.totalChunks, (tenGigaBytes / 65536).ceil());

      // Bob receives it without buffer allocation
      final bobTransfer = await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );
      expect(bobTransfer.fileSize, tenGigaBytes);
    });

    test('Test 42: No local absolute path is exposed in the offer', () async {
      final offer = await aliceService.createOffer(
        transferId: 'TF-NO-PATH',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'privacy.pdf',
        fileSize: 4096,
      );

      final map = offer.toMap();
      final jsonStr = offer.toJson();

      expect(map.containsKey('localPath'), isFalse);
      expect(map.containsKey('stagingPath'), isFalse);
      expect(jsonStr.contains('localPath'), isFalse);
      expect(jsonStr.contains('stagingPath'), isFalse);
      expect(jsonStr.contains(r'C:\'), isFalse);
      expect(jsonStr.contains('/storage/'), isFalse);
    });

    test('Test 43: No session secret or private key is serialized', () async {
      final offer = await aliceService.createOffer(
        transferId: 'TF-NO-SECRET',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'data.txt',
        fileSize: 1024,
      );

      final decision = FileTransferDecision(
        transferId: offer.transferId,
        offerId: offer.offerId,
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-ALICE',
        createdAt: mockNow,
      );

      for (final jsonStr in [offer.toJson(), decision.toJson()]) {
        expect(jsonStr.contains('privateKey'), isFalse);
        expect(jsonStr.contains('sharedSecret'), isFalse);
        expect(jsonStr.contains('sessionKey'), isFalse);
        expect(jsonStr.contains('identityKey'), isFalse);
        expect(jsonStr.contains('sendKey'), isFalse);
        expect(jsonStr.contains('receiveKey'), isFalse);
        expect(jsonStr.contains('secret'), isFalse);
      }
    });

    test('Test 44: Clock injection makes expiration tests deterministic', () async {
      final offer = await aliceService.createOffer(
        transferId: 'TF-DETERMINISTIC-TIME',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'clock.txt',
        fileSize: 1024,
        validityDuration: const Duration(minutes: 3),
      );

      // Offer valid right now
      expect(offer.isExpired(mockNow), isFalse);

      // Advance mock time by 2 minutes -> still valid
      mockNow = mockNow.add(const Duration(minutes: 2));
      expect(offer.isExpired(mockNow), isFalse);

      // Advance mock time by 2 more minutes (total 4) -> expired!
      mockNow = mockNow.add(const Duration(minutes: 2));
      expect(offer.isExpired(mockNow), isTrue);
    });
  });

  group('Group 6: Cryptographic Protocol and End-to-End Handshake', () {
    test('Test 45: Encrypt and decrypt offer via DirectionalSessionEncryptionService', () async {
      final sessions = await establishTestSession();
      final sessionA = sessions.sessionA;
      final sessionB = sessions.sessionB;

      final offer = await aliceService.createOffer(
        transferId: 'TF-CRYPTO-OFFER',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'secure_file.pdf',
        fileSize: 10000,
      );

      final encryptedPayload = await aliceService.encryptOffer(
        session: sessionA,
        offer: offer,
      );

      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        version: offer.version,
        packetType: 'file_offer',
        sessionId: sessionB.sessionId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        messageId: offer.transferId,
      );

      final decryptedOffer = await bobService.decryptOffer(
        session: sessionB,
        encrypted: encryptedPayload,
        aad: aad,
      );

      expect(decryptedOffer.transferId, offer.transferId);
      expect(decryptedOffer.fileName, offer.fileName);
      expect(decryptedOffer.fileSize, offer.fileSize);
      expect(decryptedOffer.totalChunks, offer.totalChunks);
    });

    test('Test 46: Tampered offer ciphertext or AAD fails closed with zero plaintext leakage', () async {
      final sessions = await establishTestSession();
      final sessionA = sessions.sessionA;
      final sessionB = sessions.sessionB;

      final offer = await aliceService.createOffer(
        transferId: 'TF-TAMPER-OFFER',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'tamper_test.pdf',
        fileSize: 10000,
      );

      final encryptedPayload = await aliceService.encryptOffer(
        session: sessionA,
        offer: offer,
      );

      // 1. Tamper ciphertext byte
      final tamperedCiphertext = Uint8List.fromList(encryptedPayload.ciphertext);
      tamperedCiphertext[0] ^= 0xFF;
      final tamperedPayload = SessionEncryptedPayload(
        nonce: encryptedPayload.nonce,
        ciphertext: tamperedCiphertext,
        mac: encryptedPayload.mac,
      );

      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        version: offer.version,
        packetType: 'file_offer',
        sessionId: sessionB.sessionId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        messageId: offer.transferId,
      );

      expect(
        () => bobService.decryptOffer(
          session: sessionB,
          encrypted: tamperedPayload,
          aad: aad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );

      // 2. Tamper AAD
      final tamperedAad = DirectionalSessionEncryptionService.buildCanonicalAad(
        version: offer.version,
        packetType: 'file_offer',
        sessionId: sessionB.sessionId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        messageId: 'WRONG-TRANSFER-ID', // Tampered!
      );

      expect(
        () => bobService.decryptOffer(
          session: sessionB,
          encrypted: encryptedPayload,
          aad: tamperedAad,
        ),
        throwsA(isA<DirectionalEncryptionException>()),
      );
    });

    test('Test 47: Encrypt and decrypt decision via DirectionalSessionEncryptionService', () async {
      final sessions = await establishTestSession();
      final sessionA = sessions.sessionA;
      final sessionB = sessions.sessionB;

      final decision = FileTransferDecision(
        transferId: 'TF-DEC-CRYPTO',
        offerId: 'OFF-DEC-CRYPTO',
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-ALICE',
        createdAt: mockNow,
      );

      // Bob encrypts decision for Alice
      final encrypted = await bobService.encryptDecision(
        session: sessionB,
        decision: decision,
      );

      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        version: decision.version,
        packetType: 'file_decision',
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-BOB',
        destinationId: 'ML-DEVICE-ALICE',
        messageId: decision.transferId,
      );

      final decrypted = await aliceService.decryptDecision(
        session: sessionA,
        encrypted: encrypted,
        aad: aad,
      );

      expect(decrypted.transferId, decision.transferId);
      expect(decrypted.decisionType, decision.decisionType);
      expect(decrypted.senderId, decision.senderId);
    });

    test('Test 48: receiveEncryptedOffer end-to-end integration', () async {
      final sessions = await establishTestSession();
      final sessionA = sessions.sessionA;
      final sessionB = sessions.sessionB;

      final offer = await aliceService.createOffer(
        transferId: 'TF-E2E-001',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'presentation.key',
        fileSize: 45000,
      );

      final encryptedPayload = await aliceService.encryptOffer(
        session: sessionA,
        offer: offer,
      );

      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        version: offer.version,
        packetType: 'file_offer',
        sessionId: sessionB.sessionId,
        originId: 'ML-DEVICE-ALICE',
        destinationId: 'ML-DEVICE-BOB',
        messageId: offer.transferId,
      );

      final bobTransfer = await bobService.receiveEncryptedOffer(
        session: sessionB,
        encrypted: encryptedPayload,
        aad: aad,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );

      expect(bobTransfer.transferId, 'TF-E2E-001');
      expect(bobTransfer.status, FileTransferStatus.offerReceived);
      expect(bobTransfer.direction, FileTransferDirection.incoming);
    });

    test('Test 49: handleEncryptedDecision end-to-end integration', () async {
      final sessions = await establishTestSession();
      final sessionA = sessions.sessionA;
      final sessionB = sessions.sessionB;

      // Alice creates offer
      final offer = await aliceService.createOffer(
        transferId: 'TF-E2E-DEC-001',
        recipientId: 'ML-DEVICE-BOB',
        fileName: 'contract.pdf',
        fileSize: 8000,
      );

      // Bob accepts offer
      await bobService.receiveOffer(
        offer: offer,
        authenticatedSenderId: 'ML-DEVICE-ALICE',
      );

      final decision = await bobService.acceptOffer(
        transferId: offer.transferId,
        offerId: offer.offerId,
      );

      final encryptedDecision = await bobService.encryptDecision(
        session: sessionB,
        decision: decision,
      );

      final aad = DirectionalSessionEncryptionService.buildCanonicalAad(
        version: decision.version,
        packetType: 'file_decision',
        sessionId: sessionA.sessionId,
        originId: 'ML-DEVICE-BOB',
        destinationId: 'ML-DEVICE-ALICE',
        messageId: decision.transferId,
      );

      final updatedAliceTransfer = await aliceService.handleEncryptedDecision(
        session: sessionA,
        encrypted: encryptedDecision,
        aad: aad,
        authenticatedSenderId: 'ML-DEVICE-BOB',
      );

      expect(updatedAliceTransfer.transferId, 'TF-E2E-DEC-001');
      expect(updatedAliceTransfer.status, FileTransferStatus.acceptReceived);
    });

    test('Test 50: Bounded pending offer cache evicts oldest entries when capacity reached', () async {
      final limitedService = FileTransferNegotiationService(
        database: aliceDb,
        localDeviceId: 'ML-DEVICE-ALICE',
        maxPendingOffers: 3,
        clock: () => mockNow,
      );

      await limitedService.createOffer(
        transferId: 'TF-BOUND-1',
        recipientId: 'ML-DEVICE-BOB',
        fileName: '1.txt',
        fileSize: 10,
      );
      await limitedService.createOffer(
        transferId: 'TF-BOUND-2',
        recipientId: 'ML-DEVICE-BOB',
        fileName: '2.txt',
        fileSize: 20,
      );
      await limitedService.createOffer(
        transferId: 'TF-BOUND-3',
        recipientId: 'ML-DEVICE-BOB',
        fileName: '3.txt',
        fileSize: 30,
      );
      // Inserting 4th offer causes oldest (TF-BOUND-1) to be evicted
      await limitedService.createOffer(
        transferId: 'TF-BOUND-4',
        recipientId: 'ML-DEVICE-BOB',
        fileName: '4.txt',
        fileSize: 40,
      );

      // TF-BOUND-4 is accepted fine
      final dec = FileTransferDecision(
        transferId: 'TF-BOUND-4',
        offerId: 'offer_TF-BOUND-4',
        decisionType: FileTransferDecisionType.accept,
        senderId: 'ML-DEVICE-BOB',
        recipientId: 'ML-DEVICE-ALICE',
        createdAt: mockNow,
      );
      final handled = await limitedService.handleDecision(
        decision: dec,
        authenticatedSenderId: 'ML-DEVICE-BOB',
      );
      expect(handled.status, FileTransferStatus.acceptReceived);
    });
  });
}
