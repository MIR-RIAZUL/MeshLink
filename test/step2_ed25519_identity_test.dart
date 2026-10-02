import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 2: Ed25519 Local Device Identity Lifecycle', () {
    test('Test 1 — First initialization generates, stores, and exposes Ed25519 identity', () async {
      final store = InMemorySecureIdentityStoreV2();
      final service = MeshIdentityService(store: store);

      expect(service.isLoaded, isFalse);
      expect(store.readCount, 0);
      expect(store.writeCount, 0);

      // Perform first initialization
      final publicKey = await service.getIdentityPublicKey();

      expect(service.isLoaded, isTrue);
      expect(store.readCount, 1);
      expect(store.writeCount, 1);

      // Validate public key format (Base64URL of 32 bytes)
      final rawPubBytes = base64Url.decode(publicKey);
      expect(rawPubBytes.length, 32);
      expect(MeshIdentityService.isValidPublicKey(publicKey), isTrue);

      // Validate stored JSON
      final storedString = await store.read();
      expect(storedString, isNotNull);
      final storedJson = jsonDecode(storedString!) as Map<String, dynamic>;
      expect(storedJson['schema'], 2);
      expect(storedJson['algorithm'], 'ed25519');
      expect(storedJson['publicKey'], publicKey);

      final storedPrivBytes = base64Url.decode(storedJson['privateKey'] as String);
      expect(storedPrivBytes.length, 32);

      // Check key pair can sign/verify
      final keyPair = await service.getKeyPair();
      final ed25519 = Ed25519();
      final signature = await ed25519.sign(utf8.encode('MeshLink Phase 7'), keyPair: keyPair);
      final verified = await ed25519.verify(
        utf8.encode('MeshLink Phase 7'),
        signature: signature,
      );
      expect(verified, isTrue);
    });

    test('Test 2 — Persistence preserves same public key and identity across restarts without regenerating', () async {
      final sharedStore = InMemorySecureIdentityStoreV2();

      // Launch 1: Initial creation
      final service1 = MeshIdentityService(store: sharedStore);
      final initialPubKey = await service1.getIdentityPublicKey();
      expect(sharedStore.writeCount, 1);

      // Subsequent call on same instance uses memory cache
      final cachedPubKey = await service1.getIdentityPublicKey();
      expect(cachedPubKey, initialPubKey);
      expect(sharedStore.writeCount, 1); // No new writes
      expect(sharedStore.readCount, 1);  // No extra reads

      // Launch 2: Simulate application restart (new service instance with same store)
      final service2 = MeshIdentityService(store: sharedStore);
      expect(service2.isLoaded, isFalse);

      final restartedPubKey = await service2.getIdentityPublicKey();
      expect(restartedPubKey, initialPubKey);
      expect(sharedStore.writeCount, 1); // Still 1! No new identity was generated!
      expect(sharedStore.readCount, 2);  // Read from persistent store
    });

    test('Test 3 — Valid stored identity loads successfully and reconstructs key pair', () async {
      final ed25519 = Ed25519();
      final pregeneratedKeyPair = await ed25519.newKeyPair();
      final extracted = await pregeneratedKeyPair.extract();

      final validV2Json = jsonEncode({
        'schema': 2,
        'algorithm': 'ed25519',
        'privateKey': base64UrlEncode(extracted.bytes),
        'publicKey': base64UrlEncode(extracted.publicKey.bytes),
      });

      final store = InMemorySecureIdentityStoreV2(validV2Json);
      final service = MeshIdentityService(store: store);

      await service.initialize();
      expect(service.isLoaded, isTrue);
      expect(store.writeCount, 0); // No writes performed

      final pubKey = await service.getIdentityPublicKey();
      expect(pubKey, base64UrlEncode(extracted.publicKey.bytes));

      final keyPair = await service.getKeyPair();
      final keyPairExtracted = await keyPair.extract();
      expect(keyPairExtracted.bytes, extracted.bytes);
      expect(keyPairExtracted.publicKey.bytes, extracted.publicKey.bytes);
    });

    test('Test 4 — Invalid schema is rejected and does not overwrite storage', () async {
      final invalidSchemaJson = jsonEncode({
        'schema': 1, // Invalid: expected 2
        'algorithm': 'ed25519',
        'privateKey': base64UrlEncode(List.filled(32, 1)),
        'publicKey': base64UrlEncode(List.filled(32, 2)),
      });

      final store = InMemorySecureIdentityStoreV2(invalidSchemaJson);
      final service = MeshIdentityService(store: store);

      expect(
        () => service.getIdentityPublicKey(),
        throwsA(isA<MeshIdentityException>().having(
          (e) => e.message,
          'message',
          contains('Invalid identity schema: 1 (expected 2)'),
        )),
      );
      // Ensure storage was not overwritten
      expect(store.writeCount, 0);
      expect(await store.read(), invalidSchemaJson);
    });

    test('Test 5 — Invalid algorithm is rejected and does not overwrite storage', () async {
      final invalidAlgoJson = jsonEncode({
        'schema': 2,
        'algorithm': 'x25519', // Invalid: expected ed25519
        'privateKey': base64UrlEncode(List.filled(32, 1)),
        'publicKey': base64UrlEncode(List.filled(32, 2)),
      });

      final store = InMemorySecureIdentityStoreV2(invalidAlgoJson);
      final service = MeshIdentityService(store: store);

      expect(
        () => service.getIdentityPublicKey(),
        throwsA(isA<MeshIdentityException>().having(
          (e) => e.message,
          'message',
          contains('Invalid identity algorithm: x25519 (expected ed25519)'),
        )),
      );
      expect(store.writeCount, 0);
      expect(await store.read(), invalidAlgoJson);
    });

    test('Test 6 — Malformed key material is safely rejected', () async {
      // 6a: Malformed JSON
      final malformedJsonStore = InMemorySecureIdentityStoreV2('{not valid json}');
      final serviceA = MeshIdentityService(store: malformedJsonStore);
      expect(
        () => serviceA.getIdentityPublicKey(),
        throwsA(isA<MeshIdentityException>().having(
          (e) => e.message,
          'message',
          contains('Malformed identity JSON'),
        )),
      );

      // 6b: Invalid Base64URL in privateKey
      final badBase64Json = jsonEncode({
        'schema': 2,
        'algorithm': 'ed25519',
        'privateKey': '???not-base64???',
        'publicKey': base64UrlEncode(List.filled(32, 2)),
      });
      final badBase64Store = InMemorySecureIdentityStoreV2(badBase64Json);
      final serviceB = MeshIdentityService(store: badBase64Store);
      expect(
        () => serviceB.getIdentityPublicKey(),
        throwsA(isA<MeshIdentityException>().having(
          (e) => e.message,
          'message',
          contains('Invalid Base64URL encoding'),
        )),
      );

      // 6c: Wrong private key byte length (16 bytes instead of 32)
      final wrongLengthJson = jsonEncode({
        'schema': 2,
        'algorithm': 'ed25519',
        'privateKey': base64UrlEncode(List.filled(16, 1)),
        'publicKey': base64UrlEncode(List.filled(32, 2)),
      });
      final wrongLengthStore = InMemorySecureIdentityStoreV2(wrongLengthJson);
      final serviceC = MeshIdentityService(store: wrongLengthStore);
      expect(
        () => serviceC.getIdentityPublicKey(),
        throwsA(isA<MeshIdentityException>().having(
          (e) => e.message,
          'message',
          contains('Invalid private key length: 16 bytes (expected 32)'),
        )),
      );

      // 6d: Stored public key does not match mathematical private key derivation
      final ed25519 = Ed25519();
      final kp = await ed25519.newKeyPair();
      final ext = await kp.extract();
      final corruptedPubKey = Uint8List.fromList(List.filled(32, 99));

      final mismatchedKeyJson = jsonEncode({
        'schema': 2,
        'algorithm': 'ed25519',
        'privateKey': base64UrlEncode(ext.bytes),
        'publicKey': base64UrlEncode(corruptedPubKey),
      });
      final mismatchedStore = InMemorySecureIdentityStoreV2(mismatchedKeyJson);
      final serviceD = MeshIdentityService(store: mismatchedStore);
      expect(
        () => serviceD.getIdentityPublicKey(),
        throwsA(isA<MeshIdentityException>().having(
          (e) => e.message,
          'message',
          contains('Stored public key does not match private key seed'),
        )),
      );
    });

    test('Test 7 — Legacy X25519 preservation remains completely untouched and operational', () async {
      final legacyStore = InMemoryKeyMaterialStore();
      final cryptoService = MeshCryptoService(keyStore: legacyStore);

      // Generate legacy X25519 key
      final legacyPk = await cryptoService.localPublicKey();
      expect(legacyPk, isNotEmpty);
      expect(base64Url.decode(legacyPk).length, 32);

      // Verify legacy storage contains X25519 JSON format (without schema/algorithm)
      final storedLegacy = await legacyStore.read();
      expect(storedLegacy, isNotNull);
      final legacyJson = jsonDecode(storedLegacy!) as Map<String, dynamic>;
      expect(legacyJson.containsKey('schema'), isFalse);
      expect(legacyJson.containsKey('algorithm'), isFalse);
      expect(legacyJson.containsKey('privateKey'), isTrue);
      expect(legacyJson.containsKey('publicKey'), isTrue);

      // Encryption and decryption still function as expected
      final bobStore = InMemoryKeyMaterialStore();
      final bobCrypto = MeshCryptoService(keyStore: bobStore);
      final bobPk = await bobCrypto.localPublicKey();

      cryptoService.rememberPeerKey('bob', bobPk);
      bobCrypto.rememberPeerKey('alice', legacyPk);

      final encrypted = await cryptoService.encrypt(
        messageId: 'msg-legacy',
        originId: 'alice',
        destinationId: 'bob',
        text: 'hello legacy x25519',
      );
      final decrypted = await bobCrypto.decrypt(
        messageId: 'msg-legacy',
        originId: 'alice',
        destinationId: 'bob',
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
        mac: encrypted.mac,
      );
      expect(decrypted, 'hello legacy x25519');
    });

    test('Test 8 — Identity separation ensures Ed25519 is completely independent from X25519', () async {
      final legacyStore = InMemoryKeyMaterialStore();
      final v2Store = InMemorySecureIdentityStoreV2();

      final legacyCrypto = MeshCryptoService(keyStore: legacyStore);
      final v2Identity = MeshIdentityService(store: v2Store);

      final legacyPk = await legacyCrypto.localPublicKey();
      final v2Pk = await v2Identity.getIdentityPublicKey();

      // Ensure keys are distinct
      expect(v2Pk, isNot(equals(legacyPk)));

      // Inspect stores: legacy store has only legacy JSON, v2 has only v2 JSON
      final storedLegacy = await legacyStore.read();
      final storedV2 = await v2Store.read();

      expect(storedLegacy, isNot(equals(storedV2)));
      final legacyJson = jsonDecode(storedLegacy!) as Map<String, dynamic>;
      final v2Json = jsonDecode(storedV2!) as Map<String, dynamic>;

      expect(legacyJson.containsKey('schema'), isFalse);
      expect(v2Json['schema'], 2);
      expect(v2Json['algorithm'], 'ed25519');
      expect(v2Json['publicKey'], isNot(equals(legacyJson['publicKey'])));
      expect(v2Json['privateKey'], isNot(equals(legacyJson['privateKey'])));
    });

    test('Test 9 — Concurrent initialization calls do not duplicate key generation or storage writes', () async {
      final store = InMemorySecureIdentityStoreV2();
      final service = MeshIdentityService(store: store);

      // Trigger 10 concurrent requests to get public key
      final futures = List.generate(10, (_) => service.getIdentityPublicKey());
      final results = await Future.wait(futures);

      // All callers get the identical public key
      final firstKey = results.first;
      for (final key in results) {
        expect(key, firstKey);
      }

      // Exactly 1 write occurred
      expect(store.writeCount, 1);
    });

    test('Test 10 — Native MethodChannel security protocol integration (AndroidSecureIdentityStoreV2)', () async {
      const channel = MethodChannel('meshlink/security');
      final Map<String, String> simulatedNativeStorage = {};

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async {
          switch (call.method) {
            case 'readIdentity':
              return simulatedNativeStorage['x25519_identity'];
            case 'writeIdentity':
              simulatedNativeStorage['x25519_identity'] = call.arguments['value'] as String;
              return null;
            case 'readIdentityV2':
              final stored = simulatedNativeStorage['ed25519_identity_v2'];
              if (stored != null) {
                final json = jsonDecode(stored) as Map<String, dynamic>;
                if (json['schema'] == 2 && json['algorithm'] == 'ed25519') {
                  return stored;
                }
                throw PlatformException(code: 'invalid_identity_format', message: 'Schema mismatch');
              }
              return null;
            case 'writeIdentityV2':
              final val = call.arguments['value'] as String;
              final json = jsonDecode(val) as Map<String, dynamic>;
              if (json['schema'] == 2 && json['algorithm'] == 'ed25519') {
                simulatedNativeStorage['ed25519_identity_v2'] = val;
                return null;
              }
              throw PlatformException(code: 'invalid_identity_format', message: 'Validation failed');
            default:
              throw PlatformException(code: 'not_implemented');
          }
        },
      );

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });

      // 1. First run on default Android store
      final androidService1 = MeshIdentityService();
      final pubKey1 = await androidService1.getIdentityPublicKey();
      expect(pubKey1, isNotEmpty);
      expect(simulatedNativeStorage.containsKey('ed25519_identity_v2'), isTrue);

      // 2. Second run on default Android store (simulates app restart)
      final androidService2 = MeshIdentityService();
      final pubKey2 = await androidService2.getIdentityPublicKey();
      expect(pubKey2, pubKey1);

      // 3. Platform exception on malformed read is safely propagated as MeshIdentityException
      simulatedNativeStorage['ed25519_identity_v2'] = '{"schema": 1, "algorithm": "ed25519"}';
      final androidService3 = MeshIdentityService();
      expect(
        () => androidService3.getIdentityPublicKey(),
        throwsA(isA<MeshIdentityException>()),
      );
    });

    test('Test 11 — Compatibility with PeerIdentitiesTable from Step 1', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = DriftMessageRepository(db);
      addTearDown(() => db.close());

      final store = InMemorySecureIdentityStoreV2();
      final service = MeshIdentityService(store: store);

      final localEd25519PubKey = await service.getIdentityPublicKey();

      // Ensure that this public key string can be saved in PeerIdentitiesTable as expected
      final now = DateTime.utc(2026, 10, 3, 3, 30, 0);
      final peerEntry = PeerIdentityEntry(
        peerId: 'ML-REMOTE-PEER-1',
        identityPublicKey: localEd25519PubKey,
        safetyNumber: '654321',
        trustStatus: 'tofu_unverified',
        protocolVersion: 2,
        firstSeenAt: now,
        lastSeenAt: now,
      );

      await repository.savePeerIdentity(peerEntry);

      final retrieved = await repository.getPeerIdentity('ML-REMOTE-PEER-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.identityPublicKey, localEd25519PubKey);
      expect(MeshIdentityService.isValidPublicKey(retrieved.identityPublicKey), isTrue);
    });
  });
}
