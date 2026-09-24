import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshlink/features/devices/data/services/android_ble_discovery_service.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftMessageRepository(db);
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
      ref.onDispose(() => controller.dispose());
      return controller;
    });

final deviceConnectionControllerProvider =
    ChangeNotifierProvider<DeviceConnectionController>((ref) {
      final service = ref.watch(deviceDiscoveryServiceProvider);
      final controller = DeviceConnectionController(service);
      ref.onDispose(() => controller.dispose());
      return controller;
    });

final meshMessagingServiceProvider = Provider<MeshMessagingService>((ref) {
  final discoveryService = ref.watch(deviceDiscoveryServiceProvider);
  final repository = ref.watch(messageRepositoryProvider);
  final discoveryController = ref.watch(
    deviceDiscoveryControllerProvider.notifier,
  );
  final connectionController = ref.watch(
    deviceConnectionControllerProvider.notifier,
  );

  final router = MeshRouter(
    discoveryService: discoveryService,
    localId: discoveryController.localIdentity.id,
    getConnectedPeers: () => connectionController.connectedDevices,
  );

  final service = BleMeshMessagingService(
    discoveryService: discoveryService,
    storageService: repository,
    localId: discoveryController.localIdentity.id,
    router: router,
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
