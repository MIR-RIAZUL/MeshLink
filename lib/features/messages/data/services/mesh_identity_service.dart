import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

/// Secure store interface for the long-term Ed25519 identity (Phase 7 v2).
abstract class SecureIdentityStoreV2 {
  Future<String?> read();
  Future<void> write(String value);
}

/// Android Keystore / EncryptedSharedPreferences implementation using
/// MethodChannel `meshlink/security` (`readIdentityV2` / `writeIdentityV2`).
class AndroidSecureIdentityStoreV2 implements SecureIdentityStoreV2 {
  const AndroidSecureIdentityStoreV2();
  static const _channel = MethodChannel('meshlink/security');

  @override
  Future<String?> read() => _channel.invokeMethod<String>('readIdentityV2');

  @override
  Future<void> write(String value) =>
      _channel.invokeMethod<void>('writeIdentityV2', {'value': value});
}

/// In-memory implementation of [SecureIdentityStoreV2] for isolated unit testing.
class InMemorySecureIdentityStoreV2 implements SecureIdentityStoreV2 {
  InMemorySecureIdentityStoreV2([this._value]);
  String? _value;
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<String?> read() async {
    readCount++;
    return _value;
  }

  @override
  Future<void> write(String value) async {
    writeCount++;
    _value = value;
  }
}

/// Exception thrown when identity loading, generation, or validation fails.
class MeshIdentityException implements Exception {
  const MeshIdentityException(this.message);
  final String message;

  @override
  String toString() => 'MeshIdentityException: $message';
}

/// Manages the local device's long-term Ed25519 identity (Phase 7 Security Hardening v2).
///
/// Features:
/// - Idempotent lazy loading and initialization.
/// - Generates a new 32-byte Ed25519 key pair on first launch.
/// - Persists key material via [SecureIdentityStoreV2] using schema v2 and algorithm "ed25519".
/// - Strictly validates stored key material (schema, algorithm, key lengths, mathematical seed-pub consistency).
/// - Exposes the canonical Base64URL-encoded public key compatible with `PeerIdentitiesTable`.
/// - Exposes [SimpleKeyPair] for cryptographic operations (such as handshake signing in Step 3).
/// - Keeps the private key in memory only, isolated from Dart persistence, logs, and SQLite.
class MeshIdentityService {
  MeshIdentityService({
    SecureIdentityStoreV2? store,
    Ed25519? ed25519,
  })  : _store = store ?? const AndroidSecureIdentityStoreV2(),
        _ed25519 = ed25519 ?? Ed25519();

  static const int schemaVersion = 2;
  static const String algorithm = 'ed25519';

  final SecureIdentityStoreV2 _store;
  final Ed25519 _ed25519;
  SimpleKeyPairData? _cachedIdentity;
  Future<SimpleKeyPairData>? _initializationFuture;

  /// Returns true if the identity has been loaded into memory.
  bool get isLoaded => _cachedIdentity != null;

  /// Explicitly loads or generates the device Ed25519 identity idempotently.
  Future<void> initialize() async {
    await _loadIdentity();
  }

  /// Returns the canonical Base64URL-encoded 32-byte Ed25519 public key string.
  ///
  /// This representation matches the `identityPublicKey` column in
  /// `PeerIdentitiesTable`.
  Future<String> getIdentityPublicKey() async {
    final identity = await _loadIdentity();
    return base64UrlEncode(identity.publicKey.bytes);
  }

  /// Returns the raw 32-byte Ed25519 public key bytes.
  Future<Uint8List> getIdentityPublicKeyBytes() async {
    final identity = await _loadIdentity();
    return Uint8List.fromList(identity.publicKey.bytes);
  }

  /// Returns the `SimplePublicKey` object representing the device's public identity.
  Future<SimplePublicKey> getIdentityPublicKeyObject() async {
    final identity = await _loadIdentity();
    return identity.publicKey;
  }

  /// Returns the underlying `SimpleKeyPair` for cryptographic operations
  /// (e.g. handshake transcript signing).
  ///
  /// Does NOT expose raw private key strings.
  Future<SimpleKeyPair> getKeyPair() async {
    return _loadIdentity();
  }

  /// Validates and decodes a canonical Base64URL-encoded Ed25519 public key string.
  ///
  /// Returns 32-byte public key bytes, or throws [FormatException] if invalid.
  static Uint8List decodePublicKey(String encodedKey) {
    final bytes = base64Url.decode(encodedKey);
    if (bytes.length != 32) {
      throw const FormatException('Invalid Ed25519 public key length (expected 32 bytes)');
    }
    return Uint8List.fromList(bytes);
  }

  /// Returns true if [encodedKey] is a valid Base64URL-encoded 32-byte Ed25519 public key.
  static bool isValidPublicKey(String encodedKey) {
    try {
      decodePublicKey(encodedKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Internal idempotent loader with race condition guard.
  Future<SimpleKeyPairData> _loadIdentity() async {
    final cached = _cachedIdentity;
    if (cached != null) return cached;

    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    final future = _doLoadIdentity();
    _initializationFuture = future;
    try {
      final result = await future;
      _cachedIdentity = result;
      return result;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<SimpleKeyPairData> _doLoadIdentity() async {
    String? saved;
    try {
      saved = await _store.read();
    } on PlatformException catch (e) {
      throw MeshIdentityException(
        'Failed to read identity from secure store: ${e.message} (${e.code})',
      );
    } catch (e) {
      if (e is MeshIdentityException) rethrow;
      throw MeshIdentityException('Unexpected error reading secure store: $e');
    }

    if (saved == null) {
      // First launch: generate new Ed25519 identity
      final generated = await _ed25519.newKeyPair();
      final extracted = await generated.extract();
      final privEncoded = base64UrlEncode(extracted.bytes);
      final pubEncoded = base64UrlEncode(extracted.publicKey.bytes);

      final payload = jsonEncode({
        'schema': schemaVersion,
        'algorithm': algorithm,
        'privateKey': privEncoded,
        'publicKey': pubEncoded,
      });

      try {
        await _store.write(payload);
      } on PlatformException catch (e) {
        throw MeshIdentityException(
          'Failed to write identity to secure store: ${e.message} (${e.code})',
        );
      } catch (e) {
        if (e is MeshIdentityException) rethrow;
        throw MeshIdentityException('Unexpected error writing secure store: $e');
      }

      return extracted;
    }

    // Subsequent launches: validate stored identity
    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const MeshIdentityException('Stored identity is not a JSON object');
      }
      data = decoded;
    } catch (e) {
      if (e is MeshIdentityException) rethrow;
      throw MeshIdentityException('Malformed identity JSON in secure storage: $e');
    }

    // Validate schema
    final schema = data['schema'];
    if (schema != schemaVersion) {
      throw MeshIdentityException(
        'Invalid identity schema: $schema (expected $schemaVersion)',
      );
    }

    // Validate algorithm
    final algo = data['algorithm'];
    if (algo != algorithm) {
      throw MeshIdentityException(
        'Invalid identity algorithm: $algo (expected $algorithm)',
      );
    }

    // Validate key fields
    final privStr = data['privateKey'];
    final pubStr = data['publicKey'];
    if (privStr is! String || privStr.isEmpty) {
      throw const MeshIdentityException('Missing or empty privateKey in stored identity');
    }
    if (pubStr is! String || pubStr.isEmpty) {
      throw const MeshIdentityException('Missing or empty publicKey in stored identity');
    }

    // Validate Base64URL encoding and length
    final Uint8List privBytes;
    final Uint8List pubBytes;
    try {
      privBytes = Uint8List.fromList(base64Url.decode(privStr));
    } catch (e) {
      throw MeshIdentityException('Invalid Base64URL encoding for privateKey: $e');
    }
    try {
      pubBytes = Uint8List.fromList(base64Url.decode(pubStr));
    } catch (e) {
      throw MeshIdentityException('Invalid Base64URL encoding for publicKey: $e');
    }

    if (privBytes.length != 32) {
      throw MeshIdentityException(
        'Invalid private key length: ${privBytes.length} bytes (expected 32)',
      );
    }
    if (pubBytes.length != 32) {
      throw MeshIdentityException(
        'Invalid public key length: ${pubBytes.length} bytes (expected 32)',
      );
    }

    // Mathematically verify that the public key corresponds to the private key seed
    try {
      final derivedKeyPair = await _ed25519.newKeyPairFromSeed(privBytes);
      final derivedExtracted = await derivedKeyPair.extract();
      if (!_bytesEqual(derivedExtracted.publicKey.bytes, pubBytes)) {
        throw const MeshIdentityException(
          'Stored public key does not match private key seed',
        );
      }
    } catch (e) {
      if (e is MeshIdentityException) rethrow;
      throw MeshIdentityException('Invalid Ed25519 key material: $e');
    }

    return SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
  }

  /// Constant-time byte comparison to prevent timing side channels.
  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
