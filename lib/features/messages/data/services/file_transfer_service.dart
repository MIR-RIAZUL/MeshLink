import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/chunk_ack_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_stream_reader.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_negotiation_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_resumption_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';
import 'package:meshlink/features/messages/domain/models/models.dart';
import 'package:meshlink/features/messages/domain/services/file_transfer_state_machine.dart';
import 'package:path/path.dart' as p;

/// Base exception for file transfer service operations.
class FileTransferServiceException implements Exception {
  const FileTransferServiceException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? 'FileTransferServiceException: $message (cause: $cause)'
      : 'FileTransferServiceException: $message';
}

/// Thrown when no active session exists with the destination peer.
class NoActiveSessionException extends FileTransferServiceException {
  const NoActiveSessionException(super.message, [super.cause]);
}

/// Authoritative application service coordinating sending, receiving, acknowledgment,
/// assembly, and routing for MeshLink file transfers.
///
/// Phase 8 Step 17: Service Integration & Legacy Deprecation.
class FileTransferService {
  FileTransferService({
    required this.localDeviceId,
    required this.database,
    required this.messageRepository,
    required this.router,
    required this.sessionService,
    ChunkSendingPipeline? sendingPipeline,
    ChunkReceivingPipeline? receivingPipeline,
    ChunkAckService? ackService,
    FileAssemblyService? assemblyService,
    FilePathService? pathService,
    FileTransferCryptoService? cryptoService,
    ReplayProtectionService? replayProtectionService,
    FileTransferNegotiationService? negotiationService,
    FileTransferResumptionService? resumptionService,
    DirectionalSessionEncryptionService? encryptionService,
    FileTransferStateMachine? stateMachine,
    bool autoListenToRouter = true,
  })  : _directionalEncryption = encryptionService ??
            DirectionalSessionEncryptionService(),
        _stateMachine = stateMachine ?? FileTransferStateMachine.instance,
        _replayProtection = replayProtectionService ??
            ReplayProtectionService(repository: messageRepository),
        _pathService = pathService ?? FilePathService(),
        isListeningToRouter = autoListenToRouter {
    _cryptoService = cryptoService ??
        FileTransferCryptoService(encryptionService: _directionalEncryption);

    _assemblyService = assemblyService ??
        FileAssemblyService(
          database: database,
          pathService: _pathService,
          stateMachine: _stateMachine,
        );

    _ackService = ackService ??
        ChunkAckService(
          localDeviceId: localDeviceId,
          database: database,
          messageRepository: messageRepository,
          replayProtectionService: _replayProtection,
          encryptionService: _directionalEncryption,
          stateMachine: _stateMachine,
        );

    _receivingPipeline = receivingPipeline ??
        ChunkReceivingPipeline(
          localDeviceId: localDeviceId,
          database: database,
          messageRepository: messageRepository,
          replayProtectionService: _replayProtection,
          cryptoService: _cryptoService,
          pathService: _pathService,
          assemblyService: _assemblyService,
          ackService: _ackService,
          stateMachine: _stateMachine,
        );

    _sendingPipeline = sendingPipeline ??
        ChunkSendingPipeline(
          localDeviceId: localDeviceId,
          database: database,
          messageRepository: messageRepository,
          cryptoService: _cryptoService,
          stateMachine: _stateMachine,
        );

    _negotiationService = negotiationService ??
        FileTransferNegotiationService(
          database: database,
          localDeviceId: localDeviceId,
          messageRepository: messageRepository,
          encryptionService: _directionalEncryption,
          stateMachine: _stateMachine,
        );

    _resumptionService = resumptionService ??
        FileTransferResumptionService(
          database: database,
          localDeviceId: localDeviceId,
          messageRepository: messageRepository,
          replayProtectionService: _replayProtection,
          receivingPipeline: _receivingPipeline,
          sendingPipeline: _sendingPipeline,
          pathService: _pathService,
          assemblyService: _assemblyService,
          stateMachine: _stateMachine,
        );

    _routerChunkTransportSender = RouterChunkTransportSender(router: router);
    _routerAckTransportSender = RouterChunkAckTransportSender(router: router);

    if (autoListenToRouter) {
      _chunkSub = router.onFileChunkDelivery.listen(
        _onRouterChunkDelivery,
        onError: (_) {},
      );
      _ackSub = router.onFileAckDelivery.listen(
        _onRouterAckDelivery,
        onError: (_) {},
      );
    }
  }

  final String localDeviceId;
  final AppDatabase database;
  final MessageRepository messageRepository;
  final MeshRouter router;
  final EphemeralSessionService sessionService;
  final bool isListeningToRouter;

  final DirectionalSessionEncryptionService _directionalEncryption;
  final FileTransferStateMachine _stateMachine;
  final ReplayProtectionService _replayProtection;
  final FilePathService _pathService;

  late final FileTransferCryptoService _cryptoService;
  late final FileAssemblyService _assemblyService;
  late final ChunkAckService _ackService;
  late final ChunkReceivingPipeline _receivingPipeline;
  late final ChunkSendingPipeline _sendingPipeline;
  late final FileTransferNegotiationService _negotiationService;
  late final FileTransferResumptionService _resumptionService;

  late final RouterChunkTransportSender _routerChunkTransportSender;
  late final RouterChunkAckTransportSender _routerAckTransportSender;

  /// Transport sender handing off chunks to the underlying [MeshRouter].
  RouterChunkTransportSender get routerChunkTransportSender =>
      _routerChunkTransportSender;

  /// Transport sender handing off ACKs to the underlying [MeshRouter].
  RouterChunkAckTransportSender get routerAckTransportSender =>
      _routerAckTransportSender;

  StreamSubscription<LocalFileChunkDelivery>? _chunkSub;
  StreamSubscription<LocalFileChunkAckDelivery>? _ackSub;

  final Map<String, ChunkAckTracker> _activeTrackers = {};
  final Map<String, FileTransferCancellationToken> _activeTokens = {};

  final StreamController<FileTransferProgress> _progressController =
      StreamController<FileTransferProgress>.broadcast();

  // Getters for shared services
  ChunkSendingPipeline get sendingPipeline => _sendingPipeline;
  ChunkReceivingPipeline get receivingPipeline => _receivingPipeline;
  ChunkAckService get ackService => _ackService;
  FileAssemblyService get assemblyService => _assemblyService;
  FilePathService get pathService => _pathService;
  FileTransferCryptoService get cryptoService => _cryptoService;
  FileTransferNegotiationService get negotiationService => _negotiationService;
  FileTransferResumptionService get resumptionService => _resumptionService;
  ReplayProtectionService get replayProtectionService => _replayProtection;
  FileTransferStateMachine get stateMachine => _stateMachine;
  RouterChunkTransportSender get chunkTransportSender =>
      _routerChunkTransportSender;
  RouterChunkAckTransportSender get ackTransportSender =>
      _routerAckTransportSender;

  /// Broadcast stream of domain-level [FileTransferProgress] updates.
  Stream<FileTransferProgress> get progressStream => _progressController.stream;

  /// Registers a pre-negotiated or manual incoming file transfer record in persistence.
  Future<FileTransfer> registerIncomingTransfer({
    required String transferId,
    required String peerId,
    required String fileName,
    required int fileSize,
    required String fileHash,
    int chunkSize = FileStreamReader.defaultChunkSize,
    int? totalChunks,
    String? stagingPath,
  }) async {
    FilePathService.validateTransferId(transferId);
    final staging = stagingPath ?? await _pathService.getStagingPath(transferId);
    final calculatedChunks = totalChunks ??
        FileStreamReader.calculateTotalChunks(
          fileSize: fileSize,
          chunkSize: chunkSize,
        );

    final rawName = p.basename(fileName);
    final safeFileName =
        rawName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]'), '_');

    final now = DateTime.now().toUtc();
    final transfer = FileTransfer(
      transferId: transferId,
      conversationId: peerId,
      peerId: peerId,
      direction: FileTransferDirection.incoming,
      fileName: safeFileName,
      fileSize: fileSize,
      mimeType: 'application/octet-stream',
      fileHash: fileHash,
      localPath: '',
      stagingPath: staging,
      totalChunks: calculatedChunks,
      chunkSize: chunkSize,
      status: FileTransferStatus.acceptSent,
      createdAt: now,
      updatedAt: now,
    );

    await database.insertFileTransfer(transfer.toCompanion());
    return transfer;
  }

  /// Sends a local [file] to [peerId] using the authoritative Phase 8 transfer pipeline.
  Future<ChunkSendingResult> sendFile({
    required String peerId,
    required File file,
    String? transferId,
    Duration? timeout,
    ChunkSendingPolicy? policy,
    FileTransferCancellationToken? cancellationToken,
    ChunkProgressCallback? onProgress,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('Source file does not exist', file.path);
    }
    final fileSize = await file.length();
    if (fileSize == 0) {
      throw ArgumentError('Cannot transfer an empty file');
    }

    final session = sessionService.getSession(peerId);
    if (session == null) {
      throw NoActiveSessionException(
        'No active ephemeral session with peer "$peerId". Establish a handshake first.',
      );
    }

    final id = transferId ?? 'FT-${DateTime.now().millisecondsSinceEpoch}';
    FilePathService.validateTransferId(id);

    // Compute whole-file SHA-256 digest
    final fileBytes = await file.readAsBytes();
    final digest = await Sha256().hash(fileBytes);
    final fileHash =
        digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final chunkSize = FileStreamReader.defaultChunkSize;
    final totalChunks = FileStreamReader.calculateTotalChunks(
      fileSize: fileSize,
      chunkSize: chunkSize,
    );

    final rawName = p.basename(file.path);
    final safeFileName =
        rawName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]'), '_');

    final now = DateTime.now().toUtc();
    final transfer = FileTransfer(
      transferId: id,
      conversationId: peerId,
      peerId: peerId,
      direction: FileTransferDirection.outgoing,
      fileName: safeFileName,
      fileSize: fileSize,
      mimeType: 'application/octet-stream',
      fileHash: fileHash,
      localPath: file.path,
      stagingPath: '',
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      status: FileTransferStatus.acceptReceived,
      createdAt: now,
      updatedAt: now,
    );

    await database.insertFileTransfer(transfer.toCompanion());

    final tracker = ChunkAckTracker();
    _activeTrackers[id] = tracker;
    final token = cancellationToken ?? FileTransferCancellationToken();
    _activeTokens[id] = token;

    try {
      final result = await _sendingPipeline.sendTransfer(
        transfer: transfer,
        session: session,
        transportSender: _routerChunkTransportSender,
        ackTracker: tracker,
        policy: policy ??
            ChunkSendingPolicy(
              waitForAcks: true,
              ackTimeout: timeout ?? const Duration(seconds: 5),
            ),
        cancellationToken: token,
        throwOnError: false,
        onProgress: (progress) {
          _progressController.add(FileTransferProgress(
            transferId: id,
            status: FileTransferStatus.transferring,
            bytesTransferred: progress.bytesSent,
            totalBytes: progress.totalBytes,
            chunksCompleted: progress.chunkIndex,
            totalChunks: progress.totalChunks,
            fileName: safeFileName,
          ));
          onProgress?.call(progress);
        },
      );

      if (result.isSuccess) {
        await database.updateFileTransferStatus(
          id,
          FileTransferStatus.completed.toDbValue(),
          updatedAt: DateTime.now().toUtc(),
        );

        _progressController.add(FileTransferProgress(
          transferId: id,
          status: FileTransferStatus.completed,
          bytesTransferred: fileSize,
          totalBytes: fileSize,
          chunksCompleted: totalChunks,
          totalChunks: totalChunks,
          fileName: safeFileName,
        ));

        return ChunkSendingResult(
          transferId: result.transferId,
          chunksSent: result.chunksSent,
          totalChunks: result.totalChunks,
          bytesSent: result.bytesSent,
          totalBytes: result.totalBytes,
          status: FileTransferStatus.completed,
          isCancelled: false,
          error: null,
        );
      } else if (token.isCancelled || result.isCancelled) {
        _progressController.add(FileTransferProgress(
          transferId: id,
          status: FileTransferStatus.cancelled,
          bytesTransferred: result.bytesSent,
          totalBytes: fileSize,
          chunksCompleted: result.chunksSent,
          totalChunks: totalChunks,
          fileName: safeFileName,
        ));
      } else {
        _progressController.add(FileTransferProgress(
          transferId: id,
          status: FileTransferStatus.failed,
          bytesTransferred: result.bytesSent,
          totalBytes: fileSize,
          chunksCompleted: result.chunksSent,
          totalChunks: totalChunks,
          fileName: safeFileName,
        ));
      }

      return result;
    } catch (e) {
      if (token.isCancelled) {
        _progressController.add(FileTransferProgress(
          transferId: id,
          status: FileTransferStatus.cancelled,
          bytesTransferred: 0,
          totalBytes: fileSize,
          chunksCompleted: 0,
          totalChunks: totalChunks,
          fileName: safeFileName,
        ));
        return ChunkSendingResult(
          transferId: id,
          chunksSent: 0,
          totalChunks: totalChunks,
          bytesSent: 0,
          totalBytes: fileSize,
          status: FileTransferStatus.cancelled,
          isCancelled: true,
          error: e,
        );
      }
      try {
        await database.updateFileTransferStatus(
          id,
          FileTransferStatus.failed.toDbValue(),
          updatedAt: DateTime.now().toUtc(),
        );
      } catch (_) {}
      _progressController.add(FileTransferProgress(
        transferId: id,
        status: FileTransferStatus.failed,
        bytesTransferred: 0,
        totalBytes: fileSize,
        chunksCompleted: 0,
        totalChunks: totalChunks,
        fileName: safeFileName,
      ));
      return ChunkSendingResult(
        transferId: id,
        chunksSent: 0,
        totalChunks: totalChunks,
        bytesSent: 0,
        totalBytes: fileSize,
        status: FileTransferStatus.failed,
        isCancelled: false,
        error: e,
      );
    } finally {
      _activeTrackers.remove(id);
      _activeTokens.remove(id);
    }
  }

  void _onRouterChunkDelivery(LocalFileChunkDelivery delivery) async {
    await handleIncomingFileChunk(delivery.envelope);
  }

  void _onRouterAckDelivery(LocalFileChunkAckDelivery delivery) async {
    await handleIncomingFileAck(delivery.envelope);
  }

  /// Processes an incoming [EncryptedFileChunkEnvelope] addressed to this node.
  Future<ChunkReceivingResult?> handleIncomingFileChunk(
    EncryptedFileChunkEnvelope envelope,
  ) async {
    final session = sessionService.getSession(envelope.originId);
    if (session == null) {
      return null;
    }

    try {
      final result = await _receivingPipeline.receiveChunk(
        envelope: envelope,
        session: session,
        ackTransportSender: _routerAckTransportSender,
        autoAssemble: true,
      );

      final entry = await database.getFileTransfer(envelope.transferId);
      if (entry != null) {
        final chunks = await database.getFileChunks(envelope.transferId);
        final isCompleted =
            FileTransferStatus.fromString(entry.status) == FileTransferStatus.completed;
        final chunksCompleted =
            isCompleted ? entry.totalChunks : chunks.length;
        final bytesTransferred = isCompleted
            ? entry.fileSize.toInt()
            : (chunksCompleted * entry.chunkSize).clamp(0, entry.fileSize.toInt());

        _progressController.add(FileTransferProgress(
          transferId: envelope.transferId,
          status: FileTransferStatus.fromString(entry.status),
          bytesTransferred: bytesTransferred,
          totalBytes: entry.fileSize.toInt(),
          chunksCompleted: chunksCompleted,
          totalChunks: entry.totalChunks,
          fileName: entry.fileName,
        ));
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  /// Processes an incoming [EncryptedChunkAckEnvelope] addressed to this node.
  Future<bool> handleIncomingFileAck(
    EncryptedChunkAckEnvelope envelope,
  ) async {
    final session = sessionService.getSession(envelope.originId);
    if (session == null) {
      return false;
    }

    try {
      final decryptedAck = await _ackService.decryptAck(
        envelope: envelope,
        session: session,
      );

      // Satisfy any pending active tracker wait
      final tracker = _activeTrackers[decryptedAck.transferId];
      if (tracker != null) {
        tracker.onAckReceived(decryptedAck);
      }

      // Record ACK persistently
      await _ackService.processReceivedAck(
        ack: decryptedAck,
        session: session,
        throwOnError: false,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancels an active or pending transfer, transitioning to [FileTransferStatus.cancelled].
  Future<bool> cancelTransfer(String transferId, [String? reason]) async {
    final token = _activeTokens[transferId];
    token?.cancel(reason ?? 'User cancelled transfer');

    final tracker = _activeTrackers[transferId];
    tracker?.cancelTransfer(transferId, reason);

    var cancelled = false;
    try {
      final sendCancelled =
          await _sendingPipeline.cancelTransfer(transferId, reason);
      if (sendCancelled) cancelled = true;
    } catch (_) {}

    try {
      final recvCancelled =
          await _receivingPipeline.cancelTransfer(transferId, reason);
      if (recvCancelled) cancelled = true;
    } catch (_) {}

    final entry = await database.getFileTransfer(transferId);
    if (entry != null) {
      final chunks = await database.getFileChunks(transferId);
      final chunksCompleted = chunks.length;
      final bytesTransferred =
          (chunksCompleted * entry.chunkSize).clamp(0, entry.fileSize.toInt());

      _progressController.add(FileTransferProgress(
        transferId: transferId,
        status: FileTransferStatus.cancelled,
        bytesTransferred: bytesTransferred,
        totalBytes: entry.fileSize.toInt(),
        chunksCompleted: chunksCompleted,
        totalChunks: entry.totalChunks,
        fileName: entry.fileName,
      ));
    }

    return cancelled;
  }

  /// Retrieves an existing [FileTransfer] record from database.
  Future<FileTransfer?> getTransfer(String transferId) async {
    final entry = await database.getFileTransfer(transferId);
    if (entry == null) return null;
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

  /// Disposes active resources, cancels listeners, and closes staging writers.
  Future<void> dispose() async {
    await _chunkSub?.cancel();
    await _ackSub?.cancel();

    for (final token in _activeTokens.values) {
      if (!token.isCancelled) {
        token.cancel('Service disposed');
      }
    }
    _activeTokens.clear();

    for (final tracker in _activeTrackers.values) {
      tracker.cancelAll('Service disposed');
    }
    _activeTrackers.clear();

    await _receivingPipeline.closeAll();
    await _progressController.close();
  }
}
