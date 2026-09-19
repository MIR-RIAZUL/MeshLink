import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meshlink/features/devices/data/models/nearby_device.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';

/// Android platform bridge. BLE implementation details stay out of widgets.
class AndroidBleDiscoveryService implements DeviceDiscoveryService {
  static const _methods = MethodChannel('meshlink/device_discovery');
  static const _events = EventChannel('meshlink/device_discovery_events');
  final StreamController<DeviceDiscoveryEvent> _controller =
      StreamController<DeviceDiscoveryEvent>.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;

  AndroidBleDiscoveryService() {
    _eventSubscription = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error) =>
          _controller.add(DiscoveryFailed('Nearby discovery failed: $error')),
    );
  }

  @override
  Stream<DeviceDiscoveryEvent> get events => _controller.stream;

  @override
  Future<BluetoothStateInfo> getBluetoothState() async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>(
        'getBluetoothState',
      );
      final stateStr = result?['state'] as String? ?? 'unavailable';
      final message = result?['message'] as String?;
      final state = switch (stateStr) {
        'enabled' => BluetoothState.enabled,
        'disabled' => BluetoothState.disabled,
        'permissionRequired' => BluetoothState.permissionRequired,
        'permissionPermanentlyDenied' =>
          BluetoothState.permissionPermanentlyDenied,
        _ => BluetoothState.unavailable,
      };
      return BluetoothStateInfo(state: state, message: message);
    } catch (e) {
      return const BluetoothStateInfo(
        state: BluetoothState.unavailable,
        message: 'Could not query Bluetooth state.',
      );
    }
  }

  @override
  Future<bool> requestEnableBluetooth() async {
    try {
      final result = await _methods.invokeMethod<bool>(
        'requestEnableBluetooth',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _methods.invokeMethod<void>('openAppSettings');
    } catch (_) {}
  }

  @override
  Future<LocalIdentity> getLocalIdentity() async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>(
        'getLocalIdentity',
      );
      return LocalIdentity(
        id: result?['id'] as String? ?? 'ML-000000',
        name: result?['name'] as String? ?? 'MeshLink User',
      );
    } catch (_) {
      return const LocalIdentity(id: 'ML-000000', name: 'MeshLink User');
    }
  }

  @override
  Future<void> setDisplayName(String name) async {
    try {
      await _methods.invokeMethod<void>('setDisplayName', {'name': name});
    } catch (_) {}
  }

  @override
  Future<DiscoveryAvailability> checkAvailability() async {
    final result = await _methods.invokeMapMethod<String, dynamic>(
      'checkAvailability',
    );
    return DiscoveryAvailability(
      available: result?['available'] as bool? ?? false,
      message: result?['message'] as String?,
    );
  }

  @override
  Future<DiscoveryStartResult> startDiscovery() async {
    final result = await _methods.invokeMapMethod<String, dynamic>(
      'startDiscovery',
    );
    return DiscoveryStartResult(
      started: result?['started'] as bool? ?? false,
      message: result?['message'] as String?,
      permanentlyDenied: result?['permanentlyDenied'] as bool? ?? false,
    );
  }

  @override
  Future<void> stopDiscovery() => _methods.invokeMethod<void>('stopDiscovery');

  @override
  Future<ConnectionStartResult> connect(String deviceId) async {
    final result = await _methods.invokeMapMethod<String, dynamic>('connect', {
      'deviceId': deviceId,
    });
    return ConnectionStartResult(
      started: result?['started'] as bool? ?? false,
      message: result?['message'] as String?,
    );
  }

  @override
  Future<bool> acceptConnection(String deviceId) async =>
      await _methods.invokeMethod<bool>('acceptConnection', {
        'deviceId': deviceId,
      }) ??
      false;

  @override
  Future<bool> rejectConnection(String deviceId) async =>
      await _methods.invokeMethod<bool>('rejectConnection', {
        'deviceId': deviceId,
      }) ??
      false;

  @override
  Future<bool> sendMessage(String deviceId, String payload) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>(
        'sendMessage',
        {'deviceId': deviceId, 'payload': payload},
      );
      return result?['sent'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect(String deviceId) async =>
      _methods.invokeMethod<void>('disconnect', {'deviceId': deviceId});

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'];
    if (type == 'device') {
      _controller.add(
        DeviceFound(NearbyDevice.fromMap(event.cast<Object?, Object?>())),
      );
    } else if (type == 'bluetoothStateChanged') {
      final stateStr = event['state'] as String?;
      final state = stateStr == 'enabled'
          ? BluetoothState.enabled
          : BluetoothState.disabled;
      _controller.add(BluetoothStateChanged(state));
    } else if (type == 'messageReceived') {
      final payload = event['payload'] as String?;
      if (payload != null) {
        _controller.add(MessageReceivedEvent(payload));
      }
    } else if (type == 'completed') {
      _controller.add(const DiscoveryCompleted());
    } else if (type == 'error') {
      _controller.add(
        DiscoveryFailed(
          event['message'] as String? ?? 'Nearby discovery failed.',
        ),
      );
    } else if (event['deviceId'] is String) {
      _controller.add(
        ConnectionEvent(
          type as String,
          event['deviceId'] as String,
          message: event['message'] as String?,
          name: event['name'] as String?,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    await _eventSubscription?.cancel();
    await _controller.close();
  }
}
