import 'package:flutter/material.dart';

import 'package:meshlink/app/theme/app_theme.dart';
import 'package:meshlink/features/home/presentation/home_screen.dart';
import 'package:meshlink/features/devices/presentation/devices_screen.dart';
import 'package:meshlink/features/messages/presentation/messages_screen.dart';
import 'package:meshlink/features/settings/presentation/settings_screen.dart';
import 'package:meshlink/features/devices/data/services/android_ble_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';

void main() {
  runApp(const MeshLinkApp());
}

/// Root widget that sets up theme and navigation.
class MeshLinkApp extends StatelessWidget {
  const MeshLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainScaffold(),
    );
  }
}

/// Scaffold containing bottom navigation and the selected feature screen.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late final DeviceDiscoveryController _discoveryController;

  @override
  void initState() {
    super.initState();
    _discoveryController = DeviceDiscoveryController(
      AndroidBleDiscoveryService(),
    );
  }

  @override
  void dispose() {
    _discoveryController.dispose();
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
        HomeScreen(controller: _discoveryController),
        DevicesScreen(controller: _discoveryController),
        const MessagesScreen(),
        const SettingsScreen(),
      ][_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
// Minimal wrapper required by widget test.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MeshLinkApp();
}
