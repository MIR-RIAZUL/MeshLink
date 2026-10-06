import 'dart:convert';
import 'file_transfer_status.dart';

/// Immutable model representing progress and status of a file transfer.
class FileTransferProgress {
  FileTransferProgress({
    required this.transferId,
    required this.status,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.chunksCompleted,
    required this.totalChunks,
    this.fileName = '',
  }) {
    if (transferId.trim().isEmpty) {
      throw ArgumentError('transferId must not be empty.');
    }
    if (bytesTransferred < 0) {
      throw ArgumentError('bytesTransferred cannot be negative ($bytesTransferred).');
    }
    if (totalBytes < 0) {
      throw ArgumentError('totalBytes cannot be negative ($totalBytes).');
    }
    if (bytesTransferred > totalBytes) {
      throw ArgumentError(
        'bytesTransferred ($bytesTransferred) cannot exceed totalBytes ($totalBytes).',
      );
    }
    if (chunksCompleted < 0) {
      throw ArgumentError('chunksCompleted cannot be negative ($chunksCompleted).');
    }
    if (totalChunks < 0) {
      throw ArgumentError('totalChunks cannot be negative ($totalChunks).');
    }
    if (chunksCompleted > totalChunks) {
      throw ArgumentError(
        'chunksCompleted ($chunksCompleted) cannot exceed totalChunks ($totalChunks).',
      );
    }
  }

  final String transferId;
  final FileTransferStatus status;
  final int bytesTransferred;
  final int totalBytes;
  final int chunksCompleted;
  final int totalChunks;
  final String fileName;

  /// Progress ratio from 0.0 to 1.0.
  double get progressFraction =>
      totalBytes == 0 ? 0.0 : (bytesTransferred / totalBytes).clamp(0.0, 1.0);

  bool get isCompleted =>
      status == FileTransferStatus.completed ||
      (totalBytes > 0 && bytesTransferred == totalBytes);

  bool get isFailed => status == FileTransferStatus.failed;
  bool get isCancelled => status == FileTransferStatus.cancelled;
  bool get isPaused => status == FileTransferStatus.paused;

  FileTransferProgress copyWith({
    String? transferId,
    FileTransferStatus? status,
    int? bytesTransferred,
    int? totalBytes,
    int? chunksCompleted,
    int? totalChunks,
    String? fileName,
  }) {
    return FileTransferProgress(
      transferId: transferId ?? this.transferId,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      chunksCompleted: chunksCompleted ?? this.chunksCompleted,
      totalChunks: totalChunks ?? this.totalChunks,
      fileName: fileName ?? this.fileName,
    );
  }

  Map<String, dynamic> toMap() => {
    'transferId': transferId,
    'status': status.toJson(),
    'bytesTransferred': bytesTransferred,
    'totalBytes': totalBytes,
    'chunksCompleted': chunksCompleted,
    'totalChunks': totalChunks,
    'fileName': fileName,
    'progressFraction': progressFraction,
  };

  factory FileTransferProgress.fromMap(Map<String, dynamic> map) {
    return FileTransferProgress(
      transferId: map['transferId'] as String? ?? '',
      status: FileTransferStatus.fromString(map['status'] as String? ?? 'initiated'),
      bytesTransferred: (map['bytesTransferred'] as num?)?.toInt() ?? -1,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? -1,
      chunksCompleted: (map['chunksCompleted'] as num?)?.toInt() ?? -1,
      totalChunks: (map['totalChunks'] as num?)?.toInt() ?? -1,
      fileName: map['fileName'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FileTransferProgress.fromJson(String source) =>
      FileTransferProgress.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTransferProgress &&
          runtimeType == other.runtimeType &&
          transferId == other.transferId &&
          status == other.status &&
          bytesTransferred == other.bytesTransferred &&
          totalBytes == other.totalBytes &&
          chunksCompleted == other.chunksCompleted &&
          totalChunks == other.totalChunks &&
          fileName == other.fileName;

  @override
  int get hashCode => Object.hash(
    transferId,
    status,
    bytesTransferred,
    totalBytes,
    chunksCompleted,
    totalChunks,
    fileName,
  );

  @override
  String toString() =>
      'FileTransferProgress(transferId: $transferId, status: $status, '
      '$bytesTransferred/$totalBytes bytes, $chunksCompleted/$totalChunks chunks)';
}
