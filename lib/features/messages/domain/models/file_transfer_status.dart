/// Conceptual transfer lifecycle states for MeshLink Phase 8.
enum FileTransferStatus {
  initiated,
  offerSent,
  offerReceived,
  acceptSent,
  acceptReceived,
  transferring,
  paused,
  completed,
  cancelled,
  failed;

  /// Serializes status to a string for wire or JSON storage.
  String toJson() => name;

  /// Serializes status to a database-friendly string.
  String toDbValue() => name;

  /// Parses status from wire or database string representation.
  /// Throws [ArgumentError] if unrecognized.
  static FileTransferStatus fromString(String value) {
    switch (value) {
      case 'initiated':
      case 'pending':
        return FileTransferStatus.initiated;
      case 'offerSent':
      case 'offer_sent':
      case 'offered':
        return FileTransferStatus.offerSent;
      case 'offerReceived':
      case 'offer_received':
        return FileTransferStatus.offerReceived;
      case 'acceptSent':
      case 'accept_sent':
      case 'accepted':
        return FileTransferStatus.acceptSent;
      case 'acceptReceived':
      case 'accept_received':
        return FileTransferStatus.acceptReceived;
      case 'transferring':
        return FileTransferStatus.transferring;
      case 'paused':
        return FileTransferStatus.paused;
      case 'completed':
        return FileTransferStatus.completed;
      case 'cancelled':
      case 'canceled':
        return FileTransferStatus.cancelled;
      case 'failed':
        return FileTransferStatus.failed;
      default:
        throw ArgumentError('Invalid file transfer status: $value');
    }
  }

  /// Parses status safely, returning null if unrecognized.
  static FileTransferStatus? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }
}
