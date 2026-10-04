import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Represents an authenticated encrypted payload produced by ChaCha20-Poly1305.
///
/// Phase 7 Step 5: Directional Session Encryption
/// - [nonce]: Exactly 12-byte (96-bit) unique nonce.
/// - [ciphertext]: Raw ciphertext bytes produced by ChaCha20.
/// - [mac]: Exactly 16-byte (128-bit) Poly1305 authentication tag.
class SessionEncryptedPayload {
  SessionEncryptedPayload({
    required Uint8List nonce,
    required Uint8List ciphertext,
    required Uint8List mac,
  })  : nonce = Uint8List.fromList(nonce),
        ciphertext = Uint8List.fromList(ciphertext),
        mac = Uint8List.fromList(mac) {
    if (this.nonce.length != 12) {
      throw ArgumentError.value(
        this.nonce.length,
        'nonce',
        'ChaCha20-Poly1305 nonce must be exactly 12 bytes (got ${this.nonce.length})',
      );
    }
    if (this.mac.length != 16) {
      throw ArgumentError.value(
        this.mac.length,
        'mac',
        'Poly1305 MAC tag must be exactly 16 bytes (got ${this.mac.length})',
      );
    }
  }

  /// 12-byte unique nonce.
  final Uint8List nonce;

  /// Raw ciphertext bytes.
  final Uint8List ciphertext;

  /// 16-byte Poly1305 authentication tag.
  final Uint8List mac;

  /// Creates a payload from cryptography package's [SecretBox].
  factory SessionEncryptedPayload.fromSecretBox(SecretBox secretBox) {
    return SessionEncryptedPayload(
      nonce: Uint8List.fromList(secretBox.nonce),
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  /// Converts this payload to a cryptography package [SecretBox].
  SecretBox toSecretBox() {
    return SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );
  }

  /// Serializes into canonical binary format:
  /// `[12-byte nonce][16-byte mac][ciphertext bytes...]`
  Uint8List toBytes() {
    final builder = BytesBuilder(copy: false);
    builder.add(nonce);
    builder.add(mac);
    builder.add(ciphertext);
    return builder.toBytes();
  }

  /// Deserializes from canonical binary format:
  /// `[12-byte nonce][16-byte mac][ciphertext bytes...]`
  factory SessionEncryptedPayload.fromBytes(List<int> bytes) {
    if (bytes.length < 28) {
      throw const FormatException(
        'Invalid encrypted payload bytes: must be at least 28 bytes (12 nonce + 16 mac)',
      );
    }
    final nonce = Uint8List.fromList(bytes.sublist(0, 12));
    final mac = Uint8List.fromList(bytes.sublist(12, 28));
    final ciphertext = Uint8List.fromList(bytes.sublist(28));
    return SessionEncryptedPayload(
      nonce: nonce,
      ciphertext: ciphertext,
      mac: mac,
    );
  }

  /// Map serialization using Base64URL encoding (for wire packets).
  Map<String, dynamic> toMap() => {
        'nonce': base64UrlEncode(nonce),
        'ciphertext': base64UrlEncode(ciphertext),
        'mac': base64UrlEncode(mac),
      };

  factory SessionEncryptedPayload.fromMap(Map<String, dynamic> map) {
    final nonceStr = map['nonce'] as String?;
    final ciphertextStr = map['ciphertext'] as String?;
    final macStr = map['mac'] as String?;

    if (nonceStr == null || ciphertextStr == null || macStr == null) {
      throw const FormatException('Missing required fields in encrypted payload map');
    }

    final nonceBytes = base64Url.decode(nonceStr);
    final ciphertextBytes = base64Url.decode(ciphertextStr);
    final macBytes = base64Url.decode(macStr);

    return SessionEncryptedPayload(
      nonce: Uint8List.fromList(nonceBytes),
      ciphertext: Uint8List.fromList(ciphertextBytes),
      mac: Uint8List.fromList(macBytes),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SessionEncryptedPayload.fromJson(String source) =>
      SessionEncryptedPayload.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionEncryptedPayload) return false;
    return _listEquals(nonce, other.nonce) &&
        _listEquals(mac, other.mac) &&
        _listEquals(ciphertext, other.ciphertext);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(nonce),
        Object.hashAll(mac),
        Object.hashAll(ciphertext),
      );

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
