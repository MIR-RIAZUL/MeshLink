import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

/// Holds the installation X25519 identity outside of the message database.
class MeshCryptoService {
  MeshCryptoService({KeyMaterialStore? keyStore})
      : _keyStore = keyStore ?? const AndroidKeyMaterialStore();

  static const protocolVersion = 1;
  static final _x25519 = X25519();
  static final _aead = Chacha20.poly1305Aead();

  final KeyMaterialStore _keyStore;
  final Map<String, SimplePublicKey> _peerKeys = {};
  SimpleKeyPairData? _identity;

  Future<String> localPublicKey() async {
    final identity = await _loadIdentity();
    return base64UrlEncode(identity.publicKey.bytes);
  }

  void rememberPeerKey(String deviceId, String encodedKey) {
    final bytes = base64Url.decode(encodedKey);
    if (bytes.length != 32) throw const FormatException('Invalid public key');
    _peerKeys[deviceId] = SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  bool hasPeerKey(String deviceId) => _peerKeys.containsKey(deviceId);

  Future<EncryptedMessagePayload> encrypt({
    required String messageId,
    required String originId,
    required String destinationId,
    required String text,
  }) async {
    final peerKey = _peerKeys[destinationId];
    if (peerKey == null) throw const MeshCryptoException('Missing destination key');
    final secret = await _sharedSecret(peerKey);
    final aad = _associatedData(messageId, originId, destinationId);
    final box = await _aead.encrypt(
      utf8.encode(text),
      secretKey: secret,
      aad: aad,
    );
    return EncryptedMessagePayload(
      nonce: base64UrlEncode(box.nonce),
      ciphertext: base64UrlEncode(box.cipherText),
      mac: base64UrlEncode(box.mac.bytes),
    );
  }

  Future<String> decrypt({
    required String messageId,
    required String originId,
    required String destinationId,
    required String nonce,
    required String ciphertext,
    required String mac,
  }) async {
    final peerKey = _peerKeys[originId];
    if (peerKey == null) throw const MeshCryptoException('Missing sender key');
    try {
      final clear = await _aead.decrypt(
        SecretBox(
          base64Url.decode(ciphertext),
          nonce: base64Url.decode(nonce),
          mac: Mac(base64Url.decode(mac)),
        ),
        secretKey: await _sharedSecret(peerKey),
        aad: _associatedData(messageId, originId, destinationId),
      );
      return utf8.decode(clear, allowMalformed: false);
    } catch (_) {
      throw const MeshCryptoException('Decryption failed');
    }
  }

  Future<SecretKey> _sharedSecret(SimplePublicKey peerKey) async =>
      _x25519.sharedSecretKey(keyPair: await _loadIdentity(), remotePublicKey: peerKey);

  Future<SimpleKeyPairData> _loadIdentity() async {
    final cached = _identity;
    if (cached != null) return cached;
    final saved = await _keyStore.read();
    if (saved != null) {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      final privateBytes = base64Url.decode(data['privateKey'] as String);
      final publicBytes = base64Url.decode(data['publicKey'] as String);
      if (privateBytes.length == 32 && publicBytes.length == 32) {
        return _identity = SimpleKeyPairData(
          privateBytes,
          publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
      }
    }
    final generated = await _x25519.newKeyPair();
    final extracted = await generated.extract();
    await _keyStore.write(jsonEncode({
      'privateKey': base64UrlEncode(extracted.bytes),
      'publicKey': base64UrlEncode(extracted.publicKey.bytes),
    }));
    return _identity = extracted;
  }

  List<int> _associatedData(String id, String origin, String destination) =>
      Uint8List.fromList(utf8.encode('$protocolVersion|$id|$origin|$destination'));
}

class EncryptedMessagePayload {
  const EncryptedMessagePayload({required this.nonce, required this.ciphertext, required this.mac});
  final String nonce;
  final String ciphertext;
  final String mac;
}

class MeshCryptoException implements Exception {
  const MeshCryptoException(this.message);
  final String message;
}

abstract class KeyMaterialStore {
  Future<String?> read();
  Future<void> write(String value);
}

/// Android implementation uses EncryptedSharedPreferences with an Android
/// Keystore master key. It deliberately has no delete/export API.
class AndroidKeyMaterialStore implements KeyMaterialStore {
  const AndroidKeyMaterialStore();
  static const _channel = MethodChannel('meshlink/security');

  @override
  Future<String?> read() => _channel.invokeMethod<String>('readIdentity');

  @override
  Future<void> write(String value) =>
      _channel.invokeMethod<void>('writeIdentity', {'value': value});
}

class InMemoryKeyMaterialStore implements KeyMaterialStore {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async => _value = value;
}
