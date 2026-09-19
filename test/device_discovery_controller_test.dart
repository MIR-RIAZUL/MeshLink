import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/models/nearby_device.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';

class FakeDeviceDiscoveryService implements DeviceDiscoveryService {
  final StreamController<DeviceDiscoveryEvent> _eventsController =
      StreamController<DeviceDiscoveryEvent>.broadcast();

  BluetoothState simulatedState = BluetoothState.disabled;
  LocalIdentity identity = const LocalIdentity(id: 'ML-A1B2C3', name: 'Tester');
  bool discoveryStarted = false;

  @override
  Stream<DeviceDiscoveryEvent> get events => _eventsController.stream;

  void emitEvent(DeviceDiscoveryEvent event) {
    _eventsController.add(event);
  }

  @override
  Future<BluetoothStateInfo> getBluetoothState() async =>
      BluetoothStateInfo(state: simulatedState);

  @override
  Future<bool> requestEnableBluetooth() async {
    simulatedState = BluetoothState.enabled;
    emitEvent(const BluetoothStateChanged(BluetoothState.enabled));
    return true;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<LocalIdentity> getLocalIdentity() async => identity;

  @override
  Future<void> setDisplayName(String name) async {
    identity = LocalIdentity(id: identity.id, name: name);
  }

  @override
  Future<DiscoveryAvailability> checkAvailability() async =>
      DiscoveryAvailability(
        available: simulatedState == BluetoothState.enabled,
      );

  @override
  Future<DiscoveryStartResult> startDiscovery() async {
    if (simulatedState != BluetoothState.enabled) {
      return const DiscoveryStartResult(
        started: false,
        message: 'Bluetooth is disabled',
      );
    }
    discoveryStarted = true;
    return const DiscoveryStartResult(started: true);
  }

  @override
  Future<void> stopDiscovery() async {
    discoveryStarted = false;
  }

  @override
  Future<ConnectionStartResult> connect(String deviceId) async =>
      const ConnectionStartResult(started: true);

  @override
  Future<bool> acceptConnection(String deviceId) async => true;

  @override
  Future<bool> rejectConnection(String deviceId) async => true;

  @override
  Future<bool> sendMessage(String deviceId, String payload) async => true;

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {
    await _eventsController.close();
  }
}

void main() {
  group('DeviceDiscoveryController', () {
    late FakeDeviceDiscoveryService fakeService;
    late DeviceDiscoveryController controller;

    setUp(() {
      fakeService = FakeDeviceDiscoveryService();
      controller = DeviceDiscoveryController(fakeService);
    });

    tearDown(() {
      controller.dispose();
    });

    test(
      'Initializes with Bluetooth disabled and shows proper state',
      () async {
        fakeService.simulatedState = BluetoothState.disabled;
        await controller.initialize();

        expect(controller.bluetoothState, BluetoothState.disabled);
        expect(controller.isDiscovering, isFalse);
        expect(controller.localIdentity.id, 'ML-A1B2C3');
        expect(controller.localIdentity.name, 'Tester');
      },
    );

    test(
      'Initializes with Bluetooth enabled and starts discovery automatically',
      () async {
        fakeService.simulatedState = BluetoothState.enabled;
        await controller.initialize();

        expect(controller.bluetoothState, BluetoothState.enabled);
        expect(controller.isDiscovering, isTrue);
        expect(fakeService.discoveryStarted, isTrue);
      },
    );

    test('Enabling Bluetooth triggers discovery automatically', () async {
      fakeService.simulatedState = BluetoothState.disabled;
      await controller.initialize();
      expect(controller.isDiscovering, isFalse);

      await controller.enableBluetooth();
      expect(controller.bluetoothState, BluetoothState.enabled);
      expect(controller.isDiscovering, isTrue);
    });

    test('Filters out own device from discovery list', () async {
      fakeService.simulatedState = BluetoothState.enabled;
      await controller.initialize();

      // Emit own device
      fakeService.emitEvent(
        DeviceFound(
          NearbyDevice(
            id: 'ML-A1B2C3',
            name: 'My Own Phone',
            isConnectable: true,
            lastSeen: DateTime.now(),
          ),
        ),
      );

      // Emit another phone
      fakeService.emitEvent(
        DeviceFound(
          NearbyDevice(
            id: 'ML-998877',
            name: 'Riaz',
            isConnectable: true,
            lastSeen: DateTime.now(),
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.devices.length, 1);
      expect(controller.devices.first.id, 'ML-998877');
      expect(controller.devices.first.name, 'Riaz');
    });

    test(
      'Bluetooth state change event automatically updates controller state',
      () async {
        fakeService.simulatedState = BluetoothState.enabled;
        await controller.initialize();
        expect(controller.isDiscovering, isTrue);

        fakeService.emitEvent(
          const BluetoothStateChanged(BluetoothState.disabled),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(controller.bluetoothState, BluetoothState.disabled);
        expect(controller.isDiscovering, isFalse);
        expect(controller.devices, isEmpty);
      },
    );
  });
}
