import 'dart:typed_data';

/// Holds the in-memory directional 32-byte encryption keys derived for an ephemeral session.
///
/// Phase 7 Step 5: Directional Session Encryption
/// - [sendKey]: Exactly 32-byte symmetric key for outbound ChaCha20-Poly1305 encryption.
/// - [receiveKey]: Exactly 32-byte symmetric key for inbound ChaCha20-Poly1305 decryption.
///
/// Security constraints:
/// - In-memory only: MUST NEVER be persisted to disk, database, or SharedPreferences.
/// - Redacted string representation: raw keys are never exposed in logs or [toString].
/// - [destroy] releases references and zeroes memory.
class DirectionalSessionKeys {
  DirectionalSessionKeys({
    required Uint8List sendKey,
    required Uint8List receiveKey,
  })  : _sendKey = Uint8List.fromList(sendKey),
        _receiveKey = Uint8List.fromList(receiveKey) {
    if (_sendKey!.length != 32) {
      throw ArgumentError.value(
        _sendKey!.length,
        'sendKey',
        'Directional sendKey must be exactly 32 bytes (got ${_sendKey!.length})',
      );
    }
    if (_receiveKey!.length != 32) {
      throw ArgumentError.value(
        _receiveKey!.length,
        'receiveKey',
        'Directional receiveKey must be exactly 32 bytes (got ${_receiveKey!.length})',
      );
    }
  }

  Uint8List? _sendKey;
  Uint8List? _receiveKey;
  bool _isDestroyed = false;

  /// Returns the 32-byte outbound encryption key.
  Uint8List get sendKey {
    if (_isDestroyed || _sendKey == null) {
      throw StateError('Cannot access sendKey: keys have been destroyed');
    }
    return _sendKey!;
  }

  /// Returns the 32-byte inbound decryption key.
  Uint8List get receiveKey {
    if (_isDestroyed || _receiveKey == null) {
      throw StateError('Cannot access receiveKey: keys have been destroyed');
    }
    return _receiveKey!;
  }

  /// Returns true if these keys have been destroyed.
  bool get isDestroyed => _isDestroyed;

  /// Destroys these keys and zeroes out secret key material from memory.
  void destroy() {
    _isDestroyed = true;
    if (_sendKey != null) {
      _sendKey!.fillRange(0, _sendKey!.length, 0);
      _sendKey = null;
    }
    if (_receiveKey != null) {
      _receiveKey!.fillRange(0, _receiveKey!.length, 0);
      _receiveKey = null;
    }
  }

  @override
  String toString() =>
      'DirectionalSessionKeys(sendKey: [REDACTED], receiveKey: [REDACTED], isDestroyed: $_isDestroyed)';
}
