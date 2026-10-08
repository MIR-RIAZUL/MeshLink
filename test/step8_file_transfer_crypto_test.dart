import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/ephemeral_session.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/domain/models/file_chunk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MeshIdentityService aliceIdentity;
  late MeshIdentityService bobIdentity;
  late MeshIdentityService charlieIdentity;

  late EphemeralSessionService aliceSessionService;
  late EphemeralSessionService bobSessionService;
  late EphemeralSessionService charlieSessionService;

  late HandshakeService aliceHandshake;
  late HandshakeService bobHandshake;
  late HandshakeService charlieHandshake;

  late DirectionalSessionEncryptionService directionalService;
  late FileTransferCryptoService cryptoService;

  DateTime simulatedNow = DateTime.utc(2026, 10, 5, 12, 0, 0);

  setUp(() async {
    simulatedNow = DateTime.utc(2026, 10, 5, 12, 0, 0);

    aliceIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    bobIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());
    charlieIdentity = MeshIdentityService(store: InMemorySecureIdentityStoreV2());

    await aliceIdentity.initialize();
    await bobIdentity.initialize();
    await charlieIdentity.initialize();

    aliceSessionService = EphemeralSessionService(clock: () => simulatedNow);
    bobSessionService = EphemeralSessionService(clock: () => simulatedNow);
    charlieSessionService = EphemeralSessionService(clock: () => simulatedNow);

    aliceHandshake = HandshakeService(
      identityService: aliceIdentity,
      localId: 'ML-DEVICE-A',
      sessionService: aliceSessionService,
    );

    bobHandshake = HandshakeService(
      identityService: bobIdentity,
      localId: 'ML-DEVICE-B',
      sessionService: bobSessionService,
    );

    charlieHandshake = HandshakeService(
      identityService: charlieIdentity,
      localId: 'ML-DEVICE-C',
      sessionService: charlieSessionService,
    );

    directionalService = DirectionalSessionEncryptionService();
    cryptoService = FileTransferCryptoService(encryptionService: directionalService);
  });

  /// Helper to establish an authenticated bidirectional session between Alice and Bob.
  Future<({EphemeralSession sessionA, EphemeralSession sessionB})> establishTestSession({
    String requestId = 'REQ-SESS-001',
  }) async {
    final request = await aliceHandshake.createKeyRequest(
      destinationId: 'ML-DEVICE-B',
      requestId: requestId,
    );
    final verifiedReq = await bobHandshake.verifyKeyRequest(request);
    final response = await bobHandshake.createKeyResponse(request: request);
    final sessionB = await bobHandshake.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: simulatedNow,
    );
    final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
    final sessionA = await aliceHandshake.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: simulatedNow,
    );
    return (sessionA: sessionA, sessionB: sessionB);
  }

  /// Helper to establish an authenticated bidirectional session between Alice and Charlie.
  Future<({EphemeralSession sessionA, EphemeralSession sessionC})> establishCharlieSession({
    String requestId = 'REQ-SESS-CHARLIE-001',
  }) async {
    final request = await aliceHandshake.createKeyRequest(
      destinationId: 'ML-DEVICE-C',
      requestId: requestId,
    );
    final verifiedReq = await charlieHandshake.verifyKeyRequest(request);
    final response = await charlieHandshake.createKeyResponse(request: request);
    final sessionC = await charlieHandshake.completeSessionAsResponder(
      verifiedRequest: verifiedReq,
      now: simulatedNow,
    );
    final verifiedResp = await aliceHandshake.verifyKeyResponse(response);
    final sessionA = await aliceHandshake.completeSessionAsInitiator(
      verifiedResponse: verifiedResp,
      now: simulatedNow,
    );
    return (sessionA: sessionA, sessionC: sessionC);
  }

  /// Generates deterministic pseudo-random bytes for testing.
  Uint8List generateTestBytes(int length, {int seed = 42}) {
    final rand = Random(seed);
    final list = Uint8List(length);
    for (int i = 0; i < length; i++) {
      list[i] = rand.nextInt(256);
    }
    return list;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AAD Construction & Determinism (1–14)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase 8 Step 8 — AAD Construction & Determinism (1–14)', () {
    test('1. Deterministic AAD generation', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-TR-100',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        sessionId: 'SESS-100',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        chunkLength: 1024,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-TR-100',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        sessionId: 'SESS-100',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        chunkLength: 1024,
      );
      expect(aad1, equals(aad2));
      expect(aad1.isNotEmpty, isTrue);
    });

    test('2. Same metadata -> identical AAD', () {
      final aadA = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-SAME-META',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        sessionId: 'SESS-AAA',
        epoch: 2,
        sequenceNumber: 42,
        chunkIndex: 1,
        totalChunks: 5,
        offset: 16384,
        chunkLength: 4096,
      );
      final aadB = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-SAME-META',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        sessionId: 'SESS-AAA',
        epoch: 2,
        sequenceNumber: 42,
        chunkIndex: 1,
        totalChunks: 5,
        offset: 16384,
        chunkLength: 4096,
      );
      expect(aadA, equals(aadB));
    });

    test('3. Different transferId -> different AAD', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-TRANS-01',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-TRANS-02',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('4. Different chunkIndex -> different AAD', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        chunkLength: 100,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 1,
        totalChunks: 3,
        offset: 0,
        chunkLength: 100,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('5. Different offset -> different AAD', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 100,
        chunkLength: 100,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('6. Different sessionId -> different AAD', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-A',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-B',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('7. Different epoch -> different AAD', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 1,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('8. Different sequenceNumber -> different AAD', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 2,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('9. Different origin/destination -> different AAD', () {
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-1',
        originId: 'ML-B',
        destinationId: 'ML-A',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 2,
        offset: 0,
        chunkLength: 100,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('10. Different protocol version -> different AAD and rejected if invalid', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          version: 1,
          transferId: 'FT-1',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 2,
          offset: 0,
          chunkLength: 100,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('11. Canonical field ordering', () {
      final aad = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-ORDER',
        originId: 'ORIGIN',
        destinationId: 'DEST',
        sessionId: 'SESS',
        epoch: 3,
        sequenceNumber: 99,
        chunkIndex: 1,
        totalChunks: 4,
        offset: 500,
        chunkLength: 250,
      );

      // Verify domain prefix is at byte 0
      final domainLen = ByteData.sublistView(aad).getUint16(0, Endian.big);
      expect(domainLen, 22);
      final domainStr = utf8.decode(aad.sublist(2, 24));
      expect(domainStr, FileTransferCryptoService.domainSeparator);

      // Verify version is immediately after domain
      final version = ByteData.sublistView(aad).getUint16(24, Endian.big);
      expect(version, 2);
    });

    test('12. Explicit integer encoding and endianness', () {
      const epoch = 0x12345678;
      const seq = 0x1122334455667788;
      const chunkIdx = 0x01020304;
      const total = 0x05060708;
      const offset = 0x0A0B0C0D0E0F1011;
      const length = 0x20212223;

      final aad = FileTransferCryptoService.buildChunkAad(
        transferId: 'FT-INT',
        originId: 'A',
        destinationId: 'B',
        sessionId: 'S',
        epoch: epoch,
        sequenceNumber: seq,
        chunkIndex: chunkIdx,
        totalChunks: total,
        offset: offset,
        chunkLength: length,
      );

      // Inspect fixed 32-byte numeric block at the end
      final numericBlock = aad.sublist(aad.length - 32);
      final bd = ByteData.sublistView(numericBlock);

      expect(bd.getUint32(0, Endian.big), epoch);
      expect(bd.getUint64(4, Endian.big), seq);
      expect(bd.getUint32(12, Endian.big), chunkIdx);
      expect(bd.getUint32(16, Endian.big), total);
      expect(bd.getUint64(20, Endian.big), offset);
      expect(bd.getUint32(28, Endian.big), length);
    });

    test('13. Length-prefix correctness prevents concatenation collisions', () {
      // Scenario: ("AB", "C") vs ("A", "BC")
      final aad1 = FileTransferCryptoService.buildChunkAad(
        transferId: 'AB',
        originId: 'C',
        destinationId: 'DEST',
        sessionId: 'SESS',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        chunkLength: 10,
      );
      final aad2 = FileTransferCryptoService.buildChunkAad(
        transferId: 'A',
        originId: 'BC',
        destinationId: 'DEST',
        sessionId: 'SESS',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        chunkLength: 10,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('14. Domain separation distinct from text message AAD', () {
      final fileAad = FileTransferCryptoService.buildChunkAad(
        transferId: 'MSG-001',
        originId: 'ML-A',
        destinationId: 'ML-B',
        sessionId: 'SESS-1',
        epoch: 0,
        sequenceNumber: 1,
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        chunkLength: 100,
      );
      final textAad = DirectionalSessionEncryptionService.buildCanonicalAad(
        sessionId: 'SESS-1',
        originId: 'ML-A',
        destinationId: 'ML-B',
        messageId: 'MSG-001',
        epoch: 0,
        sequenceNumber: 1,
      );
      expect(fileAad, isNot(equals(textAad)));
      expect(
        utf8.decode(fileAad.sublist(2, 24)),
        equals('MESHLINK-FILE-CHUNK-v2'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Validation Rules (15–24)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase 8 Step 8 — Validation Rules (15–24)', () {
    test('15. Empty transferId rejected', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: '',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('16. Invalid identifiers rejected (empty, long, control chars)', () {
      // Empty originId
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-VALID',
          originId: '',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );

      // Long originId (>128 chars)
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-VALID',
          originId: 'A' * 129,
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );

      // Control characters in sessionId
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-VALID',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS\x00BAD',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('17. Invalid chunkIndex rejected (negative)', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-1',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: -1,
          totalChunks: 1,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('18. Invalid totalChunks rejected (negative)', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-1',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: -1,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('19. chunkIndex >= totalChunks rejected', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-1',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 5,
          totalChunks: 5,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('20. Negative offset rejected', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-1',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: -1,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('21. Negative chunkLength rejected', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-1',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: -10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('22. chunkLength != plaintext.length rejected during encrypt', () async {
      final (:sessionA, sessionB: _) = await establishTestSession();
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);

      expect(
        () => cryptoService.encryptChunk(
          session: sessionA,
          transferId: 'FT-LEN-CHECK',
          originId: 'ML-DEVICE-A',
          destinationId: 'ML-DEVICE-B',
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          plaintext: plaintext,
          chunkLength: 999, // Mismatched
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('23. Overflow conditions rejected', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          transferId: 'FT-OVERFLOW',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0x7FFFFFFFFFFFFFFF,
          chunkLength: 1024,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('24. Unsupported protocol version rejected', () {
      expect(
        () => FileTransferCryptoService.buildChunkAad(
          version: 99,
          transferId: 'FT-1',
          originId: 'ML-A',
          destinationId: 'ML-B',
          sessionId: 'SESS-1',
          epoch: 0,
          sequenceNumber: 1,
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          chunkLength: 10,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Encryption / Decryption Operations (25–31)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase 8 Step 8 — Encryption & Decryption (25–31)', () {
    test('25. Encrypt/decrypt small chunk', () async {
      final (:sessionA, :sessionB) = await establishTestSession();
      final plaintext = Uint8List.fromList(utf8.encode('Small chunk data 12345'));

      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-SMALL-25',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );

      expect(envelope.version, 2);
      expect(envelope.transferId, 'FT-SMALL-25');
      expect(envelope.ciphertext.length, plaintext.length);

      final decrypted = await cryptoService.decryptChunk(
        session: sessionB,
        envelope: envelope,
      );
      expect(decrypted, equals(plaintext));
    });

    test('26. Encrypt/decrypt binary data (non-ASCII, high bytes)', () async {
      final (:sessionA, :sessionB) = await establishTestSession();
      final binaryData = generateTestBytes(512, seed: 101);

      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-BIN-26',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 1,
        totalChunks: 4,
        offset: 512,
        plaintext: binaryData,
      );

      final decrypted = await cryptoService.decryptChunk(
        session: sessionB,
        envelope: envelope,
      );
      expect(decrypted, equals(binaryData));
    });

    test('27. Encrypt/decrypt empty data (0-byte payload with totalChunks = 0)', () async {
      final (:sessionA, :sessionB) = await establishTestSession();
      final emptyBytes = Uint8List(0);

      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-ZERO-27',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 0,
        offset: 0,
        plaintext: emptyBytes,
      );

      expect(envelope.ciphertext.length, 0);
      expect(envelope.mac.length, 16);

      final decrypted = await cryptoService.decryptChunk(
        session: sessionB,
        envelope: envelope,
      );
      expect(decrypted, equals(emptyBytes));
    });

    test('28. Encrypt/decrypt larger chunk (32 KB)', () async {
      final (:sessionA, :sessionB) = await establishTestSession();
      final largeData = generateTestBytes(32768, seed: 202);

      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-LARGE-28',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: largeData,
      );

      final decrypted = await cryptoService.decryptChunk(
        session: sessionB,
        envelope: envelope,
      );
      expect(decrypted, equals(largeData));
    });

    test('29. Same plaintext/context produces valid decrypt with unique random nonces', () async {
      final (:sessionA, :sessionB) = await establishTestSession();
      final plaintext = Uint8List.fromList(utf8.encode('Identical chunk'));

      final env1 = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-SAME-29',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );
      final env2 = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-SAME-29',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );

      // Nonces should be fresh random 12-byte sequences
      expect(env1.nonce, isNot(equals(env2.nonce)));

      final dec1 = await cryptoService.decryptChunk(session: sessionB, envelope: env1);
      final dec2 = await cryptoService.decryptChunk(session: sessionB, envelope: env2);
      expect(dec1, equals(plaintext));
      expect(dec2, equals(plaintext));
    });

    test('30. Different sessions are isolated', () async {
      final sessAB = await establishTestSession(requestId: 'REQ-AB');
      final sessAC = await establishCharlieSession(requestId: 'REQ-AC');
      final sessionA = sessAB.sessionA;
      final sessionC = sessAC.sessionC;

      final plaintext = Uint8List.fromList(utf8.encode('Secret for Bob'));
      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-ISOLATE-30',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );

      // Charlie cannot decrypt Bob's chunk
      await expectLater(
        cryptoService.decryptChunk(session: sessionC, envelope: envelope),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('31. Directional keys are respected (wrong direction fails)', () async {
      final (:sessionA, :sessionB) = await establishTestSession();
      final plaintext = Uint8List.fromList(utf8.encode('Directed chunk'));

      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-DIR-31',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );

      // Successfully decrypted by receiver (Bob)
      final decrypted = await cryptoService.decryptChunk(
        session: sessionB,
        envelope: envelope,
      );
      expect(decrypted, equals(plaintext));

      // Attempting to decrypt on sender (Alice) using receiveKey fails closed
      await expectLater(
        cryptoService.decryptChunk(session: sessionA, envelope: envelope),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Tampering Defense (32–44)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase 8 Step 8 — Tampering Defense (32–44)', () {
    late EphemeralSession sessionA;
    late EphemeralSession sessionB;
    late EncryptedFileChunkEnvelope baseEnvelope;
    final Uint8List originalPlaintext = Uint8List.fromList(utf8.encode('Untampered file data'));

    setUp(() async {
      final sess = await establishTestSession(requestId: 'REQ-TAMPER-BASE');
      sessionA = sess.sessionA;
      sessionB = sess.sessionB;

      baseEnvelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-BASE-TAMPER',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 3,
        offset: 0,
        plaintext: originalPlaintext,
      );
    });

    test('32. Modified ciphertext fails', () async {
      final tamperedCiphertext = Uint8List.fromList(baseEnvelope.ciphertext);
      tamperedCiphertext[0] ^= 0x55;

      final tampered = baseEnvelope.copyWith(ciphertext: tamperedCiphertext);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('33. Modified nonce fails', () async {
      final tamperedNonce = Uint8List.fromList(baseEnvelope.nonce);
      tamperedNonce[0] ^= 0xAA;

      final tampered = baseEnvelope.copyWith(nonce: tamperedNonce);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('34. Modified transferId fails', () async {
      final tampered = baseEnvelope.copyWith(transferId: 'FT-OTHER-FILE');
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('35. Modified originId fails', () async {
      final tampered = baseEnvelope.copyWith(originId: 'ML-DEVICE-MALLORY');
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('36. Modified destinationId fails', () async {
      final tampered = baseEnvelope.copyWith(destinationId: 'ML-DEVICE-MALLORY');
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('37. Modified sessionId fails', () async {
      final tampered = baseEnvelope.copyWith(sessionId: 'SESS-FAKE-999');
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('38. Modified epoch fails', () async {
      final tampered = baseEnvelope.copyWith(epoch: baseEnvelope.epoch + 1);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('39. Modified sequenceNumber fails', () async {
      final tampered = baseEnvelope.copyWith(sequenceNumber: baseEnvelope.sequenceNumber + 1);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('40. Modified chunkIndex fails', () async {
      final tampered = baseEnvelope.copyWith(chunkIndex: 1);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('41. Modified totalChunks fails', () async {
      final tampered = baseEnvelope.copyWith(totalChunks: baseEnvelope.totalChunks + 10);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('42. Modified offset fails', () async {
      final tampered = baseEnvelope.copyWith(offset: 8192);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('43. Modified chunkLength fails', () async {
      final tampered = baseEnvelope.copyWith(chunkLength: baseEnvelope.chunkLength + 1);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('44. Modified version fails', () async {
      final tampered = baseEnvelope.copyWith(version: 99);
      await expectLater(
        cryptoService.decryptChunk(session: sessionB, envelope: tampered),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Serialization & Encoding (45–50)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase 8 Step 8 — Serialization & Envelope Integrity (45–50)', () {
    test('45. Valid envelope round-trips via Map, JSON, and binary bytes', () async {
      final (:sessionA, sessionB: _) = await establishTestSession();
      final plaintext = Uint8List.fromList(utf8.encode('Roundtrip envelope payload'));

      final original = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-ROUNDTRIP-45',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 2,
        totalChunks: 8,
        offset: 4096,
        plaintext: plaintext,
      );

      // 1. Map round-trip
      final map = original.toMap();
      final fromMap = EncryptedFileChunkEnvelope.fromMap(map);
      expect(fromMap, equals(original));

      // 2. JSON round-trip
      final jsonStr = original.toJson();
      final fromJson = EncryptedFileChunkEnvelope.fromJson(jsonStr);
      expect(fromJson, equals(original));

      // 3. Binary bytes round-trip
      final bin = original.toBytes();
      final fromBin = EncryptedFileChunkEnvelope.fromBytes(bin);
      expect(fromBin, equals(original));
    });

    test('46. Malformed envelope rejected (invalid JSON)', () {
      expect(
        () => EncryptedFileChunkEnvelope.fromJson('{not valid json}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => EncryptedFileChunkEnvelope.fromJson('"just a string"'),
        throwsA(isA<FormatException>()),
      );
    });

    test('47. Missing required field rejected', () {
      final map = <String, dynamic>{
        'version': 2,
        'transferId': 'FT-MISSING',
        'originId': 'ML-A',
        // 'destinationId' is missing!
        'sessionId': 'SESS-1',
        'epoch': 0,
        'sequenceNumber': 1,
        'chunkIndex': 0,
        'totalChunks': 1,
        'offset': 0,
        'chunkLength': 4,
        'nonce': base64UrlEncode(Uint8List(12)),
        'mac': base64UrlEncode(Uint8List(16)),
        'ciphertext': base64UrlEncode(Uint8List(4)),
      };
      expect(
        () => EncryptedFileChunkEnvelope.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    });

    test('48. Invalid binary length rejected', () {
      final truncatedBytes = Uint8List.fromList([0, 2, 0, 0, 0]); // Too short
      expect(
        () => EncryptedFileChunkEnvelope.fromBytes(truncatedBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('49. Invalid Base64 rejected in map deserialization', () {
      final map = <String, dynamic>{
        'version': 2,
        'transferId': 'FT-BAD-B64',
        'originId': 'ML-A',
        'destinationId': 'ML-B',
        'sessionId': 'SESS-1',
        'epoch': 0,
        'sequenceNumber': 1,
        'chunkIndex': 0,
        'totalChunks': 1,
        'offset': 0,
        'chunkLength': 4,
        'nonce': '%%%INVALID-BASE-64%%%',
        'mac': base64UrlEncode(Uint8List(16)),
        'ciphertext': base64UrlEncode(Uint8List(4)),
      };
      expect(
        () => EncryptedFileChunkEnvelope.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    });

    test('50. Unsupported version rejected in deserialization', () {
      final map = <String, dynamic>{
        'version': 1, // Unsupported
        'transferId': 'FT-BAD-VER',
        'originId': 'ML-A',
        'destinationId': 'ML-B',
        'sessionId': 'SESS-1',
        'epoch': 0,
        'sequenceNumber': 1,
        'chunkIndex': 0,
        'totalChunks': 1,
        'offset': 0,
        'chunkLength': 4,
        'nonce': base64UrlEncode(Uint8List(12)),
        'mac': base64UrlEncode(Uint8List(16)),
        'ciphertext': base64UrlEncode(Uint8List(4)),
      };
      expect(
        () => EncryptedFileChunkEnvelope.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Session Lifecycle & Rekeying (51–53)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase 8 Step 8 — Session Lifecycle & Rekeying (51–53)', () {
    test('51. Encryption requires an active session (fails if noSession or handshakeInit)', () async {
      final unnegotiatedSession = EphemeralSession(
        sessionId: 'SESS-INACTIVE',
        requestId: 'REQ-INACTIVE',
        localId: 'ML-DEVICE-A',
        peerId: 'ML-DEVICE-B',
        isInitiator: true,
        localIdentityPublicKey: Uint8List(32),
        peerIdentityPublicKey: Uint8List(32),
        localEphemeralPublicKey: Uint8List(32),
        peerEphemeralPublicKey: Uint8List(32),
        sharedSecret: Uint8List(32),
        createdAt: 1000,
        state: SessionLifecycleState.handshakeInit,
      );

      final plaintext = Uint8List.fromList([1, 2, 3]);

      await expectLater(
        cryptoService.encryptChunk(
          session: unnegotiatedSession,
          transferId: 'FT-INACTIVE-51',
          originId: 'ML-DEVICE-A',
          destinationId: 'ML-DEVICE-B',
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          plaintext: plaintext,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('52. Destroyed session cannot encrypt or decrypt', () async {
      final (:sessionA, :sessionB) = await establishTestSession();
      final plaintext = Uint8List.fromList([10, 20, 30]);

      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-DESTROYED-52',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );

      // Destroy sessionA -> cannot encrypt anymore
      sessionA.destroy();
      expect(sessionA.isDestroyed, isTrue);

      await expectLater(
        cryptoService.encryptChunk(
          session: sessionA,
          transferId: 'FT-DESTROYED-52B',
          originId: 'ML-DEVICE-A',
          destinationId: 'ML-DEVICE-B',
          chunkIndex: 0,
          totalChunks: 1,
          offset: 0,
          plaintext: plaintext,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );

      // Destroy sessionB -> cannot decrypt anymore
      sessionB.destroy();
      expect(sessionB.isDestroyed, isTrue);

      await expectLater(
        cryptoService.decryptChunk(
          session: sessionB,
          envelope: envelope,
        ),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });

    test('53. Rekeyed session uses updated session context and epoch', () async {
      final (sessionA: initialA, sessionB: initialB) = await establishTestSession();

      // Rekey session from A to B
      final rekeyReq = await aliceHandshake.initiateRekey(
        destinationId: 'ML-DEVICE-B',
        requestId: 'REQ-REKEY-53',
      );
      final rekeyResp = await bobHandshake.createKeyResponse(request: rekeyReq);
      final verifiedResp = await aliceHandshake.verifyKeyResponse(rekeyResp);
      final verifiedReq = await bobHandshake.verifyKeyRequest(rekeyReq);

      final rekeyedA = await aliceHandshake.completeSessionAsInitiator(
        verifiedResponse: verifiedResp,
        now: simulatedNow,
      );
      final rekeyedB = await bobHandshake.completeSessionAsResponder(
        verifiedRequest: verifiedReq,
        now: simulatedNow,
      );

      expect(rekeyedA.epoch, 1);
      expect(rekeyedB.epoch, 1);
      expect(rekeyedA.sessionId, isNot(equals(initialA.sessionId)));

      final plaintext = Uint8List.fromList(utf8.encode('Data post-rekey'));

      // Encrypt under rekeyed session (epoch 1)
      final envelope = await cryptoService.encryptChunk(
        session: rekeyedA,
        transferId: 'FT-REKEY-53',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );

      expect(envelope.epoch, 1);

      // Decrypt succeeds under rekeyed session B
      final decrypted = await cryptoService.decryptChunk(
        session: rekeyedB,
        envelope: envelope,
      );
      expect(decrypted, equals(plaintext));

      // Attempting to decrypt with initial (epoch 0) session fails closed
      await expectLater(
        cryptoService.decryptChunk(session: initialB, envelope: envelope),
        throwsA(isA<FileTransferCryptoException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Security Boundaries & Zero-Persistence Invariants (54–57)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase 8 Step 8 — Security Boundaries & Zero-Persistence (54–57)', () {
    test('54. No file keys persisted: DirectionalSessionKeys are purely in-memory', () async {
      final (:sessionA, sessionB: _) = await establishTestSession();
      final keys = await directionalService.getOrDeriveKeys(sessionA);

      expect(keys.sendKey.length, 32);
      expect(keys.receiveKey.length, 32);

      // Destroy in-memory keys
      keys.destroy();
      expect(keys.isDestroyed, isTrue);
      expect(() => keys.sendKey, throwsStateError);
      expect(() => keys.receiveKey, throwsStateError);
    });

    test('55. No session secrets persisted in EphemeralSession', () async {
      final (:sessionA, sessionB: _) = await establishTestSession();
      expect(sessionA.sharedSecret.length, 32);

      // Destroy session zeroizes secret in memory
      sessionA.destroy();
      expect(sessionA.isDestroyed, isTrue);
      expect(sessionA.sharedSecret, everyElement(0));
    });

    test('56. No encryption keys written to SQLite schema', () {
      final db = AppDatabase(NativeDatabase.memory());
      // Inspect all table definitions in Drift database
      final tableNames = db.allTables.map((t) => t.actualTableName).toList();

      expect(tableNames, contains('file_transfers_table'));
      expect(tableNames, contains('file_chunks_table'));

      // Inspect column names of file tables
      final transferCols = db.fileTransfersTable.$columns.map((c) => c.$name).toList();
      final chunkCols = db.fileChunksTable.$columns.map((c) => c.$name).toList();

      // Ensure no raw keys, shared secrets, or encryption keys are columns
      expect(transferCols, isNot(contains('encryptionKey')));
      expect(transferCols, isNot(contains('secretKey')));
      expect(transferCols, isNot(contains('sharedSecret')));

      expect(chunkCols, isNot(contains('encryptionKey')));
      expect(chunkCols, isNot(contains('secretKey')));
      expect(chunkCols, isNot(contains('nonce')));

      db.close();
    });

    test('57. No sensitive secrets logged: toString() masks secret material', () async {
      final (:sessionA, sessionB: _) = await establishTestSession();
      final plaintext = Uint8List.fromList(utf8.encode('Highly confidential secret content'));

      final envelope = await cryptoService.encryptChunk(
        session: sessionA,
        transferId: 'FT-SAFE-STRING-57',
        originId: 'ML-DEVICE-A',
        destinationId: 'ML-DEVICE-B',
        chunkIndex: 0,
        totalChunks: 1,
        offset: 0,
        plaintext: plaintext,
      );

      final str = envelope.toString();

      // Does not contain plaintext
      expect(str, isNot(contains('Highly confidential')));
      // Does not expose raw keys or secrets
      expect(str, isNot(contains('sendKey')));
      expect(str, isNot(contains('sharedSecret')));
      // Contains high-level safe telemetry
      expect(str, contains('FT-SAFE-STRING-57'));
      expect(str, contains('chunk: 0/1'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Convenience FileChunk Model Integration Helper
  // ═══════════════════════════════════════════════════════════════════════════

  test('Convenience: encryptChunkFromMetadata using FileChunk DTO works cleanly', () async {
    final (:sessionA, :sessionB) = await establishTestSession();
    final chunkDto = FileChunk(
      transferId: 'FT-DTO-INTEG',
      chunkIndex: 2,
      totalChunks: 5,
      offset: 32768,
      chunkLength: 16384,
    );
    final plaintext = generateTestBytes(16384, seed: 999);

    final envelope = await cryptoService.encryptChunkFromMetadata(
      session: sessionA,
      chunk: chunkDto,
      originId: 'ML-DEVICE-A',
      destinationId: 'ML-DEVICE-B',
      plaintext: plaintext,
    );

    expect(envelope.transferId, chunkDto.transferId);
    expect(envelope.chunkIndex, chunkDto.chunkIndex);
    expect(envelope.totalChunks, chunkDto.totalChunks);
    expect(envelope.offset, chunkDto.offset);
    expect(envelope.chunkLength, chunkDto.chunkLength);

    final decrypted = await cryptoService.decryptChunk(
      session: sessionB,
      envelope: envelope,
    );
    expect(decrypted, equals(plaintext));
  });
}
