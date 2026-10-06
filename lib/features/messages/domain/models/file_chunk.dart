import 'dart:convert';

/// Immutable DTO representing a single file chunk's metadata without binary payload.
class FileChunk {
  FileChunk({
    required this.transferId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.offset,
    required this.chunkLength,
    this.chunkHash,
  }) {
    if (transferId.trim().isEmpty) {
      throw ArgumentError('transferId must not be empty.');
    }
    if (chunkIndex < 0) {
      throw ArgumentError('chunkIndex cannot be negative ($chunkIndex).');
    }
    if (totalChunks < 0) {
      throw ArgumentError('totalChunks cannot be negative ($totalChunks).');
    }
    if (totalChunks > 0 && chunkIndex >= totalChunks) {
      throw ArgumentError(
        'chunkIndex ($chunkIndex) must be less than totalChunks ($totalChunks).',
      );
    }
    if (offset < 0) {
      throw ArgumentError('offset cannot be negative ($offset).');
    }
    if (chunkLength < 0) {
      throw ArgumentError('chunkLength cannot be negative ($chunkLength).');
    }
  }

  final String transferId;
  final int chunkIndex;
  final int totalChunks;
  final int offset;
  final int chunkLength;
  final String? chunkHash;

  FileChunk copyWith({
    String? transferId,
    int? chunkIndex,
    int? totalChunks,
    int? offset,
    int? chunkLength,
    String? chunkHash,
  }) {
    return FileChunk(
      transferId: transferId ?? this.transferId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      offset: offset ?? this.offset,
      chunkLength: chunkLength ?? this.chunkLength,
      chunkHash: chunkHash ?? this.chunkHash,
    );
  }

  Map<String, dynamic> toMap() => {
    'transferId': transferId,
    'chunkIndex': chunkIndex,
    'totalChunks': totalChunks,
    'offset': offset,
    'chunkLength': chunkLength,
    if (chunkHash != null) 'chunkHash': chunkHash,
  };

  factory FileChunk.fromMap(Map<String, dynamic> map) {
    return FileChunk(
      transferId: map['transferId'] as String? ?? '',
      chunkIndex: (map['chunkIndex'] as num?)?.toInt() ?? -1,
      totalChunks: (map['totalChunks'] as num?)?.toInt() ?? -1,
      offset: (map['offset'] as num?)?.toInt() ?? -1,
      chunkLength: (map['chunkLength'] as num?)?.toInt() ?? -1,
      chunkHash: map['chunkHash'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FileChunk.fromJson(String source) =>
      FileChunk.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileChunk &&
          runtimeType == other.runtimeType &&
          transferId == other.transferId &&
          chunkIndex == other.chunkIndex &&
          totalChunks == other.totalChunks &&
          offset == other.offset &&
          chunkLength == other.chunkLength &&
          chunkHash == other.chunkHash;

  @override
  int get hashCode => Object.hash(
    transferId,
    chunkIndex,
    totalChunks,
    offset,
    chunkLength,
    chunkHash,
  );

  @override
  String toString() =>
      'FileChunk(transferId: $transferId, chunkIndex: $chunkIndex/$totalChunks, '
      'offset: $offset, chunkLength: $chunkLength, hash: $chunkHash)';
}
