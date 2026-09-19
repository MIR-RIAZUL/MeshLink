import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meshlink/features/devices/data/models/nearby_device.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';

class DeviceDiscoveryController extends ChangeNotifier {
  DeviceDiscoveryController(this._service) {
    _subscription = _service.events.listen(_onEvent);
    _pruneTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pruneStaleDevices(),
    );
  }

  final DeviceDiscoveryService _service;
  final Map<String, NearbyDevice> _devicesById = {};
  StreamSubscription<DeviceDiscoveryEvent>? _subscription;
  Timer? _pruneTimer;

  BluetoothState bluetoothState = BluetoothState.disabled;
  bool isDiscovering = false;
  bool isInitializing = true;
  String? errorMessage;
  LocalIdentity localIdentity = const LocalIdentity(
    id: 'ML-000000',
    name: 'MeshLink User',
  );

  List<NearbyDevice> get devices => _devicesById.values.toList(growable: false);
  bool get isBluetoothEnabled => bluetoothState == BluetoothState.enabled;

  Future<void> initialize() async {
    isInitializing = true;
    errorMessage = null;
    notifyListeners();

    try {
      localIdentity = await _service.getLocalIdentity();
      final stateInfo = await _service.getBluetoothState();
      bluetoothState = stateInfo.state;
      errorMessage = stateInfo.message;

      if (bluetoothState == BluetoothState.enabled) {
        await startDiscovery();
      }
    } catch (_) {
      bluetoothState = BluetoothState.unavailable;
      errorMessage = 'Could not initialize Bluetooth.';
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> startDiscovery() async {
    errorMessage = null;
    try {
      final stateInfo = await _service.getBluetoothState();
      bluetoothState = stateInfo.state;
      if (bluetoothState != BluetoothState.enabled &&
          bluetoothState != BluetoothState.permissionRequired) {
        errorMessage = stateInfo.message;
        notifyListeners();
        return;
      }

      final result = await _service.startDiscovery();
      if (result.started) {
        bluetoothState = BluetoothState.enabled;
        isDiscovering = true;
        errorMessage = null;
      } else {
        if (result.permanentlyDenied) {
          bluetoothState = BluetoothState.permissionPermanentlyDenied;
        } else if (result.message?.toLowerCase().contains('permission') ==
            true) {
          bluetoothState = BluetoothState.permissionRequired;
        }
        isDiscovering = false;
        errorMessage = result.message;
      }
    } catch (_) {
      isDiscovering = false;
      errorMessage = 'Unable to start MeshLink discovery.';
    }
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    await _service.stopDiscovery();
    isDiscovering = false;
    notifyListeners();
  }

  Future<void> enableBluetooth() async {
    final enabled = await _service.requestEnableBluetooth();
    if (enabled) {
      bluetoothState = BluetoothState.enabled;
      await startDiscovery();
    } else {
      final stateInfo = await _service.getBluetoothState();
      bluetoothState = stateInfo.state;
      if (bluetoothState == BluetoothState.enabled) {
        await startDiscovery();
      }
    }
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    if (bluetoothState == BluetoothState.permissionPermanentlyDenied) {
      await _service.openAppSettings();
    } else {
      await startDiscovery();
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _service.setDisplayName(name);
    localIdentity = await _service.getLocalIdentity();
    notifyListeners();
  }

  void _onEvent(DeviceDiscoveryEvent event) {
    switch (event) {
      case DeviceFound(:final device):
        // Filter out own device
        if (device.id.toLowerCase() == localIdentity.id.toLowerCase()) return;
        _devicesById[device.id] = device;
        notifyListeners();
      case BluetoothStateChanged(:final state):
        bluetoothState = state;
        if (state == BluetoothState.enabled) {
          if (!isDiscovering) {
            startDiscovery();
          }
        } else {
          isDiscovering = false;
          _devicesById.clear();
        }
        notifyListeners();
      case DiscoveryCompleted():
        // On BLE, we continue scanning while app is active
        if (bluetoothState == BluetoothState.enabled && isDiscovering) {
          _service.startDiscovery();
        }
      case DiscoveryFailed(:final message):
        isDiscovering = false;
        errorMessage = message;
        notifyListeners();
      case ConnectionEvent():
      case MessageReceivedEvent():
        break;
    }
  }

  void _pruneStaleDevices() {
    if (_devicesById.isEmpty) return;
    final now = DateTime.now();
    final initialCount = _devicesById.length;
    _devicesById.removeWhere((id, device) {
      // If not seen in 12 seconds, remove from active nearby list
      return now.difference(device.lastSeen) > const Duration(seconds: 12);
    });
    if (_devicesById.length != initialCount) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    _subscription?.cancel();
    unawaited(_service.dispose());
    super.dispose();
  }
}
