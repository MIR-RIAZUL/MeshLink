import 'dart:convert';

/// Immutable domain model representing metadata of a file to be transferred.
class FileMetadata {
  FileMetadata({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.fileHash,
    required this.totalChunks,
    required this.chunkSize,
  }) {
    if (transferId.trim().isEmpty) {
      throw ArgumentError('transferId must not be empty.');
    }
    if (fileName.trim().isEmpty) {
      throw ArgumentError('fileName must not be empty.');
    }
    if (fileName.contains('/') || fileName.contains(r'\') || fileName.contains('..')) {
      throw ArgumentError(
        'fileName must not contain path separators or parent directory references: $fileName',
      );
    }
    if (fileSize < 0) {
      throw ArgumentError('fileSize cannot be negative ($fileSize).');
    }
    if (totalChunks < 0) {
      throw ArgumentError('totalChunks cannot be negative ($totalChunks).');
    }
    if (chunkSize <= 0) {
      throw ArgumentError('chunkSize must be greater than zero ($chunkSize).');
    }
  }

  final String transferId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String fileHash;
  final int totalChunks;
  final int chunkSize;

  FileMetadata copyWith({
    String? transferId,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? fileHash,
    int? totalChunks,
    int? chunkSize,
  }) {
    return FileMetadata(
      transferId: transferId ?? this.transferId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      fileHash: fileHash ?? this.fileHash,
      totalChunks: totalChunks ?? this.totalChunks,
      chunkSize: chunkSize ?? this.chunkSize,
    );
  }

  Map<String, dynamic> toMap() => {
    'transferId': transferId,
    'fileName': fileName,
    'fileSize': fileSize,
    'mimeType': mimeType,
    'fileHash': fileHash,
    'totalChunks': totalChunks,
    'chunkSize': chunkSize,
  };

  factory FileMetadata.fromMap(Map<String, dynamic> map) {
    return FileMetadata(
      transferId: map['transferId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? -1,
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      fileHash: map['fileHash'] as String? ?? '',
      totalChunks: (map['totalChunks'] as num?)?.toInt() ?? -1,
      chunkSize: (map['chunkSize'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FileMetadata.fromJson(String source) =>
      FileMetadata.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileMetadata &&
          runtimeType == other.runtimeType &&
          transferId == other.transferId &&
          fileName == other.fileName &&
          fileSize == other.fileSize &&
          mimeType == other.mimeType &&
          fileHash == other.fileHash &&
          totalChunks == other.totalChunks &&
          chunkSize == other.chunkSize;

  @override
  int get hashCode => Object.hash(
    transferId,
    fileName,
    fileSize,
    mimeType,
    fileHash,
    totalChunks,
    chunkSize,
  );

  @override
  String toString() =>
      'FileMetadata(transferId: $transferId, fileName: $fileName, fileSize: $fileSize, '
      'mimeType: $mimeType, totalChunks: $totalChunks, chunkSize: $chunkSize)';
}
