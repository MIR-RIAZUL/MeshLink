/// Direction of a file transfer relative to the local node.
enum FileTransferDirection {
  outgoing,
  incoming;

  /// Serializes direction to a string for database/wire storage.
  String toDbValue() => name;

  /// Serializes direction to wire/JSON string.
  String toJson() => name;

  /// Parses direction from database or wire string.
  /// Throws [ArgumentError] if the value is unrecognized.
  static FileTransferDirection fromString(String value) {
    switch (value) {
      case 'outgoing':
        return FileTransferDirection.outgoing;
      case 'incoming':
        return FileTransferDirection.incoming;
      default:
        throw ArgumentError('Invalid file transfer direction: $value');
    }
  }

  /// Parses direction, or returns null if invalid.
  static FileTransferDirection? tryFromString(String? value) {
    if (value == null) return null;
    for (final dir in FileTransferDirection.values) {
      if (dir.name == value) return dir;
    }
    return null;
  }
}
