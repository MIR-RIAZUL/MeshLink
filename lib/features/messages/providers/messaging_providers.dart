import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshlink/features/devices/data/services/android_ble_discovery_service.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/directional_session_encryption_service.dart';
import 'package:meshlink/features/messages/data/services/ephemeral_session_service.dart';
import 'package:meshlink/features/messages/data/services/handshake_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_ack_service.dart';
import 'package:meshlink/features/messages/data/services/chunk_receiving_pipeline.dart';
import 'package:meshlink/features/messages/data/services/chunk_sending_pipeline.dart';
import 'package:meshlink/features/messages/data/services/file_path_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_crypto_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_negotiation_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_resumption_service.dart';
import 'package:meshlink/features/messages/data/services/file_transfer_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_identity_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';

import 'package:meshlink/features/messages/data/services/replay_protection_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftMessageRepository(db);
});

final replayProtectionServiceProvider = Provider<ReplayProtectionService>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  final service = ReplayProtectionService(repository: repository);
  service.pruneOnStartup();
  return service;
});

final meshIdentityServiceProvider = Provider<MeshIdentityService>((ref) {
  return MeshIdentityService();
});

final ephemeralSessionServiceProvider = Provider<EphemeralSessionService>((ref) {
  return EphemeralSessionService();
});

final directionalSessionEncryptionServiceProvider =
    Provider<DirectionalSessionEncryptionService>((ref) {
  return DirectionalSessionEncryptionService();
});

final handshakeServiceProvider = Provider<HandshakeService>((ref) {
  final identityService = ref.watch(meshIdentityServiceProvider);
  final repository = ref.watch(messageRepositoryProvider);
  final sessionService = ref.watch(ephemeralSessionServiceProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );
  return HandshakeService(
    identityService: identityService,
    localId: discoveryController.localIdentity.id,
    peerRepository: repository,
    ephemeralKeyProvider: sessionService,
    sessionService: sessionService,
  );
});

final deviceDiscoveryServiceProvider = Provider<DeviceDiscoveryService>((ref) {
  final service = AndroidBleDiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

final deviceDiscoveryControllerProvider =
    ChangeNotifierProvider<DeviceDiscoveryController>((ref) {
      final service = ref.watch(deviceDiscoveryServiceProvider);
      final controller = DeviceDiscoveryController(service);
      controller.initialize();
      return controller;
    });

final deviceConnectionControllerProvider =
    ChangeNotifierProvider<DeviceConnectionController>((ref) {
      final service = ref.watch(deviceDiscoveryServiceProvider);
      final controller = DeviceConnectionController(service);
      return controller;
    });

final meshRouterProvider = Provider<MeshRouter>((ref) {
  final discoveryService = ref.watch(deviceDiscoveryServiceProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );
  final connectionController = ref.watch(
    deviceConnectionControllerProvider.notifier,
  );
  final replayProtectionService = ref.watch(replayProtectionServiceProvider);

  final router = MeshRouter(
    discoveryService: discoveryService,
    localId: discoveryController.localIdentity.id,
    getConnectedPeers: () => connectionController.connectedDevices,
    replayProtectionService: replayProtectionService,
  );
  ref.onDispose(() => router.dispose());
  return router;
});

final filePathServiceProvider = Provider<FilePathService>((ref) {
  return FilePathService();
});

final fileAssemblyServiceProvider = Provider<FileAssemblyService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final pathService = ref.watch(filePathServiceProvider);
  return FileAssemblyService(
    database: db,
    pathService: pathService,
  );
});

final fileTransferCryptoServiceProvider =
    Provider<FileTransferCryptoService>((ref) {
  final encryptionService =
      ref.watch(directionalSessionEncryptionServiceProvider);
  return FileTransferCryptoService(encryptionService: encryptionService);
});

final fileTransferServiceProvider = Provider<FileTransferService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(messageRepositoryProvider);
  final router = ref.watch(meshRouterProvider);
  final sessionService = ref.watch(ephemeralSessionServiceProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );
  final sendingPipeline = ref.watch(chunkSendingPipelineProvider);
  final receivingPipeline = ref.watch(chunkReceivingPipelineProvider);
  final ackService = ref.watch(chunkAckServiceProvider);
  final assemblyService = ref.watch(fileAssemblyServiceProvider);
  final pathService = ref.watch(filePathServiceProvider);
  final cryptoService = ref.watch(fileTransferCryptoServiceProvider);
  final replayService = ref.watch(replayProtectionServiceProvider);
  final negotiationService = ref.watch(
    fileTransferNegotiationServiceProvider(
      discoveryController.localIdentity.id,
    ),
  );
  final resumptionService = ref.watch(fileTransferResumptionServiceProvider);

  final service = FileTransferService(
    localDeviceId: discoveryController.localIdentity.id,
    database: db,
    messageRepository: repo,
    router: router,
    sessionService: sessionService,
    sendingPipeline: sendingPipeline,
    receivingPipeline: receivingPipeline,
    ackService: ackService,
    assemblyService: assemblyService,
    pathService: pathService,
    cryptoService: cryptoService,
    replayProtectionService: replayService,
    negotiationService: negotiationService,
    resumptionService: resumptionService,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final meshMessagingServiceProvider = Provider<MeshMessagingService>((ref) {
  final discoveryService = ref.watch(deviceDiscoveryServiceProvider);
  final repository = ref.watch(messageRepositoryProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );
  final replayProtectionService = ref.watch(replayProtectionServiceProvider);
  final router = ref.watch(meshRouterProvider);
  final fileTransferService = ref.watch(fileTransferServiceProvider);

  final service = BleMeshMessagingService(
    discoveryService: discoveryService,
    storageService: repository,
    localId: discoveryController.localIdentity.id,
    router: router,
    replayProtectionService: replayProtectionService,
    fileTransferService: fileTransferService,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final messagingControllerProvider =
    ChangeNotifierProvider<MessagingController>((ref) {
      final messagingService = ref.watch(meshMessagingServiceProvider);
      final discoveryController = ref.watch(
        deviceDiscoveryControllerProvider.notifier,
      );
      final connectionController = ref.watch(
        deviceConnectionControllerProvider.notifier,
      );

      final controller = MessagingController(
        messagingService: messagingService,
        localId: discoveryController.localIdentity.id,
        connectionController: connectionController,
      );
      ref.onDispose(() => controller.dispose());
      return controller;
    });
