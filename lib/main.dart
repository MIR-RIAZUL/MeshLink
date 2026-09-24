import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meshlink/app/theme/app_theme.dart';
import 'package:meshlink/features/home/presentation/home_screen.dart';
import 'package:meshlink/features/devices/presentation/devices_screen.dart';
import 'package:meshlink/features/messages/presentation/messages_screen.dart';
import 'package:meshlink/features/settings/presentation/settings_screen.dart';
import 'package:meshlink/features/devices/data/services/android_ble_discovery_service.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';

import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MeshLinkApp()));
}

/// Root widget that sets up theme and navigation.
class MeshLinkApp extends StatelessWidget {
  const MeshLinkApp({
    super.key,
    this.service,
    this.storageService,
    this.messagingService,
    this.messagingController,
  });

  final DeviceDiscoveryService? service;
  final MessageStorageService? storageService;
  final MeshMessagingService? messagingService;
  final MessagingController? messagingController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: MainScaffold(
        service: service,
        storageService: storageService,
        messagingService: messagingService,
        messagingController: messagingController,
      ),
    );
  }
}

/// Scaffold containing bottom navigation and the selected feature screen.
class MainScaffold extends StatefulWidget {
  const MainScaffold({
    super.key,
    this.service,
    this.storageService,
    this.messagingService,
    this.messagingController,
  });

  final DeviceDiscoveryService? service;
  final MessageStorageService? storageService;
  final MeshMessagingService? messagingService;
  final MessagingController? messagingController;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late final DeviceDiscoveryService _service;
  late final DeviceDiscoveryController _discoveryController;
  late final DeviceConnectionController _connectionController;
  AppDatabase? _db;
  late final MessageStorageService _storageService;
  late final MeshMessagingService _messagingService;
  late final MessagingController _messagingController;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AndroidBleDiscoveryService();
    _discoveryController = DeviceDiscoveryController(_service);
    _connectionController = DeviceConnectionController(_service);

    if (widget.storageService != null) {
      _storageService = widget.storageService!;
    } else {
      _db = AppDatabase();
      _storageService = DriftMessageRepository(_db!);
    }

    final router = MeshRouter(
      discoveryService: _service,
      localId: _discoveryController.localIdentity.id,
      getConnectedPeers: () => _connectionController.connectedDevices,
    );

    _messagingService =
        widget.messagingService ??
        BleMeshMessagingService(
          discoveryService: _service,
          storageService: _storageService,
          localId: _discoveryController.localIdentity.id,
          router: router,
        );

    _messagingController =
        widget.messagingController ??
        MessagingController(
          messagingService: _messagingService,
          localId: _discoveryController.localIdentity.id,
          connectionController: _connectionController,
        );

    _initControllers();
  }

  Future<void> _initControllers() async {
    await _discoveryController.initialize();
    _messagingController.setLocalId(_discoveryController.localIdentity.id);
  }

  @override
  void dispose() {
    _discoveryController.dispose();
    _connectionController.dispose();
    _messagingController.dispose();
    _messagingService.dispose();
    _db?.close();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: <Widget>[
        HomeScreen(
          controller: _discoveryController,
          connectionController: _connectionController,
        ),
        DevicesScreen(
          controller: _discoveryController,
          connectionController: _connectionController,
          messagingController: _messagingController,
        ),
        MessagesScreen(
          messagingController: _messagingController,
          connectionController: _connectionController,
          discoveryController: _discoveryController,
        ),
        SettingsScreen(controller: _discoveryController),
      ][_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Minimal wrapper required by widget test.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const ProviderScope(child: MeshLinkApp());
}
