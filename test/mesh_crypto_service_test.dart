import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';

void main() {
  late MeshCryptoService alice;
  late MeshCryptoService bob;

  setUp(() async {
    alice = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
    bob = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
    alice.rememberPeerKey('bob', await bob.localPublicKey());
    bob.rememberPeerKey('alice', await alice.localPublicKey());
  });

  test('encrypts and decrypts an authenticated message', () async {
    final encrypted = await alice.encrypt(
      messageId: 'message-1', originId: 'alice', destinationId: 'bob', text: 'This is a secret',
    );
    expect(encrypted.ciphertext, isNot(contains('This is a secret')));
    expect(await bob.decrypt(
      messageId: 'message-1', originId: 'alice', destinationId: 'bob',
      nonce: encrypted.nonce, ciphertext: encrypted.ciphertext, mac: encrypted.mac,
    ), 'This is a secret');
  });

  test('rejects a wrong recipient key', () async {
    final encrypted = await alice.encrypt(
      messageId: 'message-2', originId: 'alice', destinationId: 'bob', text: 'secret',
    );
    final mallory = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
    mallory.rememberPeerKey('alice', await alice.localPublicKey());
    await expectLater(
      mallory.decrypt(messageId: 'message-2', originId: 'alice', destinationId: 'bob', nonce: encrypted.nonce, ciphertext: encrypted.ciphertext, mac: encrypted.mac),
      throwsA(isA<MeshCryptoException>()),
    );
  });

  test('rejects tampered ciphertext and generates unique nonces', () async {
    final first = await alice.encrypt(messageId: 'message-3', originId: 'alice', destinationId: 'bob', text: 'secret');
    final second = await alice.encrypt(messageId: 'message-4', originId: 'alice', destinationId: 'bob', text: 'secret');
    expect(first.nonce, isNot(second.nonce));
    final tampered = '${first.ciphertext.substring(0, first.ciphertext.length - 1)}A';
    await expectLater(
      bob.decrypt(messageId: 'message-3', originId: 'alice', destinationId: 'bob', nonce: first.nonce, ciphertext: tampered, mac: first.mac),
      throwsA(isA<MeshCryptoException>()),
    );
  });
}
