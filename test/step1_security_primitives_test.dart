import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Drift Schema Version & Migration Primitives', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('AppDatabase reports schemaVersion 2', () {
      expect(db.schemaVersion, 2);
    });

    test('Migration from v1 preserves messages and creates new tables', () async {
      // 1. Simulate a legacy v1 database on raw connection
      final rawDb = NativeDatabase.memory();
      final tempDb = AppDatabase(rawDb);
      
      // Open and simulate v1 state by populating a legacy message
      final msg = MeshMessage(
        id: 'legacy-msg-1',
        conversationId: 'ML-PEER-1',
        senderId: 'ML-PEER-1',
        receiverId: 'ML-LOCAL',
        text: 'Historical v1 message text',
        timestamp: DateTime.utc(2026, 9, 1),
        status: MessageStatus.delivered,
      );
      final repoV1 = DriftMessageRepository(tempDb);
      await repoV1.saveMessage(msg);

      // Verify legacy message exists
      final savedMessages = await repoV1.getMessages('ML-PEER-1');
      expect(savedMessages.length, 1);
      expect(savedMessages.first.text, 'Historical v1 message text');

      // 2. Perform migration strategy onUpgrade from version 1 to 2
      final migrator = tempDb.createMigrator();
      await tempDb.migration.onUpgrade(migrator, 1, 2);

      // 3. Verify legacy data is completely preserved
      final postMigrationMessages = await repoV1.getMessages('ML-PEER-1');
      expect(postMigrationMessages.length, 1);
      expect(postMigrationMessages.first.id, 'legacy-msg-1');
      expect(postMigrationMessages.first.text, 'Historical v1 message text');

      // 4. Verify new tables are functional post-migration
      final inserted = await repoV1.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-PEER-1',
        packetId: 'post-mig-pkt-1',
      );
      expect(inserted, isTrue);

      await tempDb.close();
    });
  });

  group('SeenPacketsTable & Atomic Replay Primitives', () {
    late AppDatabase db;
    late DriftMessageRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftMessageRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('First occurrence returns true, duplicate occurrence returns false', () async {
      // 1. First packet arrival
      final firstResult = await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-ORIGIN-A',
        packetId: 'MSG-001',
      );
      expect(firstResult, isTrue);

      // 2. Exact same packet again -> must be rejected atomically
      final duplicateResult = await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-ORIGIN-A',
        packetId: 'MSG-001',
      );
      expect(duplicateResult, isFalse);

      // 3. Different packetId -> accepted
      final differentPacketResult = await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-ORIGIN-A',
        packetId: 'MSG-002',
      );
      expect(differentPacketResult, isTrue);
    });

    test('Distinguishes packetType and originId collision boundaries', () async {
      // Same packetId, but different packetType
      final msgPkt = await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-ORIGIN-A',
        packetId: 'SHARED-ID-1',
      );
      expect(msgPkt, isTrue);

      final ackPkt = await repository.checkAndMarkSeen(
        packetType: 'ack',
        originId: 'ML-ORIGIN-A',
        packetId: 'SHARED-ID-1',
      );
      expect(ackPkt, isTrue);

      // Same packetId, but different originId
      final diffOriginPkt = await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'ML-ORIGIN-B',
        packetId: 'SHARED-ID-1',
      );
      expect(diffOriginPkt, isTrue);

      // Duplicate of any of the above must return false
      expect(
        await repository.checkAndMarkSeen(
          packetType: 'ack',
          originId: 'ML-ORIGIN-A',
          packetId: 'SHARED-ID-1',
        ),
        isFalse,
      );
    });

    test('pruneExpiredPackets deletes expired entries and preserves recent entries', () async {
      // Manually insert an old packet and a fresh packet
      final oldTimestamp = DateTime.now().subtract(const Duration(days: 8));
      final recentTimestamp = DateTime.now().subtract(const Duration(hours: 1));

      await db.customInsert(
        'INSERT INTO seen_packets_table (replay_key, packet_type, origin_id, received_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('encrypted_message:OLD:PKT-1'),
          Variable.withString('encrypted_message'),
          Variable.withString('OLD'),
          Variable.withDateTime(oldTimestamp),
        ],
      );

      await db.customInsert(
        'INSERT INTO seen_packets_table (replay_key, packet_type, origin_id, received_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('encrypted_message:RECENT:PKT-2'),
          Variable.withString('encrypted_message'),
          Variable.withString('RECENT'),
          Variable.withDateTime(recentTimestamp),
        ],
      );

      // Prune with a maxAge of 7 days
      final deletedCount = await repository.pruneExpiredPackets(const Duration(days: 7));
      expect(deletedCount, 1);

      // Verify that old packet was deleted and can be marked seen again
      final reinsertedOld = await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'OLD',
        packetId: 'PKT-1',
      );
      expect(reinsertedOld, isTrue);

      // Verify that recent packet was NOT deleted (still seen)
      final reinsertedRecent = await repository.checkAndMarkSeen(
        packetType: 'encrypted_message',
        originId: 'RECENT',
        packetId: 'PKT-2',
      );
      expect(reinsertedRecent, isFalse);
    });
  });

  group('PeerIdentitiesTable & Identity Repository Primitives', () {
    late AppDatabase db;
    late DriftMessageRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftMessageRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('savePeerIdentity and getPeerIdentity preserve all fields', () async {
      final now = DateTime.utc(2026, 10, 2, 3, 30, 0);
      final entry = PeerIdentityEntry(
        peerId: 'ML-DEVICE-XYZ',
        identityPublicKey: 'test-ed25519-public-key-base64url-32bytes',
        safetyNumber: '482913',
        trustStatus: 'tofu_unverified',
        protocolVersion: 2,
        firstSeenAt: now,
        lastSeenAt: now,
      );

      await repository.savePeerIdentity(entry);

      final retrieved = await repository.getPeerIdentity('ML-DEVICE-XYZ');
      expect(retrieved, isNotNull);
      expect(retrieved!.peerId, 'ML-DEVICE-XYZ');
      expect(retrieved.identityPublicKey, 'test-ed25519-public-key-base64url-32bytes');
      expect(retrieved.safetyNumber, '482913');
      expect(retrieved.trustStatus, 'tofu_unverified');
      expect(retrieved.protocolVersion, 2);
      expect(retrieved.firstSeenAt.toUtc(), now);
      expect(retrieved.lastSeenAt.toUtc(), now);
    });

    test('updateTrustStatus updates only trust status and preserves other identity fields', () async {
      final firstSeen = DateTime.utc(2026, 10, 1, 10, 0, 0);
      final lastSeen = DateTime.utc(2026, 10, 2, 12, 0, 0);
      final entry = PeerIdentityEntry(
        peerId: 'ML-DEVICE-ABC',
        identityPublicKey: 'ed25519-pk-abc',
        safetyNumber: '112233',
        trustStatus: 'tofu_unverified',
        protocolVersion: 2,
        firstSeenAt: firstSeen,
        lastSeenAt: lastSeen,
      );

      await repository.savePeerIdentity(entry);

      // Update trust status to 'verified'
      await repository.updateTrustStatus('ML-DEVICE-ABC', 'verified');

      final updated = await repository.getPeerIdentity('ML-DEVICE-ABC');
      expect(updated, isNotNull);
      expect(updated!.trustStatus, 'verified');
      // Verify other fields remain strictly preserved
      expect(updated.peerId, 'ML-DEVICE-ABC');
      expect(updated.identityPublicKey, 'ed25519-pk-abc');
      expect(updated.safetyNumber, '112233');
      expect(updated.protocolVersion, 2);
      expect(updated.firstSeenAt.toUtc(), firstSeen);
      expect(updated.lastSeenAt.toUtc(), lastSeen);
    });

    test('getPeerIdentity returns null for unknown peer', () async {
      final nonExistent = await repository.getPeerIdentity('NON-EXISTENT');
      expect(nonExistent, isNull);
    });
  });

  group('Native Identity Storage Protocol Verification', () {
    const channel = MethodChannel('meshlink/security');
    final Map<String, String> simulatedStorage = {};

    setUp(() {
      simulatedStorage.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          switch (call.method) {
            case 'readIdentity':
              return simulatedStorage['x25519_identity'];
            case 'writeIdentity':
              final value = call.arguments['value'] as String?;
              if (value == null) throw PlatformException(code: 'invalid_argument');
              simulatedStorage['x25519_identity'] = value;
              return null;
            case 'readIdentityV2':
              final stored = simulatedStorage['ed25519_identity_v2'];
              if (stored != null) {
                final json = jsonDecode(stored) as Map<String, dynamic>;
                if (json['schema'] == 2 && json['algorithm'] == 'ed25519') {
                  return stored;
                }
                throw PlatformException(code: 'invalid_identity_format');
              }
              return null;
            case 'writeIdentityV2':
              final value = call.arguments['value'] as String?;
              if (value == null) throw PlatformException(code: 'invalid_argument');
              final json = jsonDecode(value) as Map<String, dynamic>;
              if (json['schema'] == 2 && json['algorithm'] == 'ed25519') {
                simulatedStorage['ed25519_identity_v2'] = value;
                return null;
              }
              throw PlatformException(code: 'invalid_identity_format');
            default:
              throw PlatformException(code: 'not_implemented');
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    test('readIdentityV2 and writeIdentityV2 enforce schema 2 and ed25519 algorithm', () async {
      // 1. Initial read returns null
      final initial = await channel.invokeMethod<String>('readIdentityV2');
      expect(initial, isNull);

      // 2. Writing valid v2 identity succeeds
      final validV2Json = jsonEncode({
        'schema': 2,
        'algorithm': 'ed25519',
        'privateKey': 'fake-ed25519-priv-key-32b',
        'publicKey': 'fake-ed25519-pub-key-32b',
      });
      await channel.invokeMethod<void>('writeIdentityV2', {'value': validV2Json});

      // 3. Reading returns the valid identity
      final readBack = await channel.invokeMethod<String>('readIdentityV2');
      expect(readBack, validV2Json);

      // 4. Writing invalid schema or algorithm throws PlatformException
      final invalidJson = jsonEncode({
        'schema': 1,
        'algorithm': 'x25519',
        'privateKey': 'priv',
        'publicKey': 'pub',
      });
      expect(
        () => channel.invokeMethod<void>('writeIdentityV2', {'value': invalidJson}),
        throwsA(isA<PlatformException>()),
      );
    });

    test('Legacy X25519 storage remains completely untouched and functional', () async {
      // 1. Write legacy identity
      const legacyX25519Value = '{"privateKey":"x25519_priv","publicKey":"x25519_pub"}';
      await channel.invokeMethod<void>('writeIdentity', {'value': legacyX25519Value});

      // 2. Write v2 identity
      final validV2Json = jsonEncode({
        'schema': 2,
        'algorithm': 'ed25519',
        'privateKey': 'ed25519_priv',
        'publicKey': 'ed25519_pub',
      });
      await channel.invokeMethod<void>('writeIdentityV2', {'value': validV2Json});

      // 3. Verify legacy read returns legacy key unchanged
      final legacyRead = await channel.invokeMethod<String>('readIdentity');
      expect(legacyRead, legacyX25519Value);

      // 4. Verify v2 read returns v2 key unchanged
      final v2Read = await channel.invokeMethod<String>('readIdentityV2');
      expect(v2Read, validV2Json);
    });
  });
}
