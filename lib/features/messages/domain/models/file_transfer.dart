import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'file_transfer_direction.dart';
import 'file_transfer_status.dart';

/// Immutable domain model representing a persistent file transfer.
class FileTransfer {
  FileTransfer({
    required this.transferId,
    required this.conversationId,
    required this.peerId,
    required this.direction,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.fileHash,
    required this.localPath,
    required this.stagingPath,
    required this.totalChunks,
    required this.chunkSize,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (transferId.trim().isEmpty) {
      throw ArgumentError('transferId must not be empty.');
    }
    if (conversationId.trim().isEmpty) {
      throw ArgumentError('conversationId must not be empty.');
    }
    if (peerId.trim().isEmpty) {
      throw ArgumentError('peerId must not be empty.');
    }
    if (fileName.trim().isEmpty) {
      throw ArgumentError('fileName must not be empty.');
    }
    if (fileName.contains('/') || fileName.contains(r'\') || fileName.contains('..')) {
      throw ArgumentError('fileName must not contain path traversal: $fileName');
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
  final String conversationId;
  final String peerId;
  final FileTransferDirection direction;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String fileHash;
  final String localPath;
  final String stagingPath;
  final int totalChunks;
  final int chunkSize;
  final FileTransferStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a domain model from a Drift generated [FileTransferEntry].
  factory FileTransfer.fromEntry(FileTransferEntry entry) {
    return FileTransfer(
      transferId: entry.transferId,
      conversationId: entry.conversationId,
      peerId: entry.peerId,
      direction: FileTransferDirection.fromString(entry.direction),
      fileName: entry.fileName,
      fileSize: entry.fileSize.toInt(),
      mimeType: entry.mimeType,
      fileHash: entry.fileHash,
      localPath: entry.localPath,
      stagingPath: entry.stagingPath,
      totalChunks: entry.totalChunks,
      chunkSize: entry.chunkSize,
      status: FileTransferStatus.fromString(entry.status),
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// Converts this domain model into a Drift companion for persistence.
  FileTransfersTableCompanion toCompanion() {
    return FileTransfersTableCompanion(
      transferId: Value(transferId),
      conversationId: Value(conversationId),
      peerId: Value(peerId),
      direction: Value(direction.toDbValue()),
      fileName: Value(fileName),
      fileSize: Value(BigInt.from(fileSize)),
      mimeType: Value(mimeType),
      fileHash: Value(fileHash),
      localPath: Value(localPath),
      stagingPath: Value(stagingPath),
      totalChunks: Value(totalChunks),
      chunkSize: Value(chunkSize),
      status: Value(status.toDbValue()),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  FileTransfer copyWith({
    String? transferId,
    String? conversationId,
    String? peerId,
    FileTransferDirection? direction,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? fileHash,
    String? localPath,
    String? stagingPath,
    int? totalChunks,
    int? chunkSize,
    FileTransferStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FileTransfer(
      transferId: transferId ?? this.transferId,
      conversationId: conversationId ?? this.conversationId,
      peerId: peerId ?? this.peerId,
      direction: direction ?? this.direction,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      fileHash: fileHash ?? this.fileHash,
      localPath: localPath ?? this.localPath,
      stagingPath: stagingPath ?? this.stagingPath,
      totalChunks: totalChunks ?? this.totalChunks,
      chunkSize: chunkSize ?? this.chunkSize,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'transferId': transferId,
    'conversationId': conversationId,
    'peerId': peerId,
    'direction': direction.toJson(),
    'fileName': fileName,
    'fileSize': fileSize,
    'mimeType': mimeType,
    'fileHash': fileHash,
    'localPath': localPath,
    'stagingPath': stagingPath,
    'totalChunks': totalChunks,
    'chunkSize': chunkSize,
    'status': status.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FileTransfer.fromMap(Map<String, dynamic> map) {
    return FileTransfer(
      transferId: map['transferId'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      peerId: map['peerId'] as String? ?? '',
      direction: FileTransferDirection.fromString(map['direction'] as String? ?? ''),
      fileName: map['fileName'] as String? ?? '',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? -1,
      mimeType: map['mimeType'] as String? ?? '',
      fileHash: map['fileHash'] as String? ?? '',
      localPath: map['localPath'] as String? ?? '',
      stagingPath: map['stagingPath'] as String? ?? '',
      totalChunks: (map['totalChunks'] as num?)?.toInt() ?? -1,
      chunkSize: (map['chunkSize'] as num?)?.toInt() ?? 0,
      status: FileTransferStatus.fromString(map['status'] as String? ?? ''),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FileTransfer.fromJson(String source) =>
      FileTransfer.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileTransfer &&
          runtimeType == other.runtimeType &&
          transferId == other.transferId &&
          conversationId == other.conversationId &&
          peerId == other.peerId &&
          direction == other.direction &&
          fileName == other.fileName &&
          fileSize == other.fileSize &&
          mimeType == other.mimeType &&
          fileHash == other.fileHash &&
          localPath == other.localPath &&
          stagingPath == other.stagingPath &&
          totalChunks == other.totalChunks &&
          chunkSize == other.chunkSize &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    transferId,
    conversationId,
    peerId,
    direction,
    fileName,
    fileSize,
    mimeType,
    fileHash,
    localPath,
    stagingPath,
    totalChunks,
    chunkSize,
    status,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'FileTransfer(id: $transferId, file: $fileName ($fileSize B), '
      'status: $status, dir: $direction, chunks: $totalChunks)';
}
