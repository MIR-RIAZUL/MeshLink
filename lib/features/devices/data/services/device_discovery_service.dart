import 'package:meshlink/features/devices/data/models/nearby_device.dart';

enum BluetoothState {
  enabled,
  disabled,
  unavailable,
  permissionRequired,
  permissionPermanentlyDenied,
}

class LocalIdentity {
  const LocalIdentity({required this.id, required this.name});
  final String id;
  final String name;
}

abstract class DeviceDiscoveryService {
  Stream<DeviceDiscoveryEvent> get events;

  Future<BluetoothStateInfo> getBluetoothState();
  Future<bool> requestEnableBluetooth();
  Future<void> openAppSettings();
  Future<LocalIdentity> getLocalIdentity();
  Future<void> setDisplayName(String name);

  Future<DiscoveryAvailability> checkAvailability();
  Future<DiscoveryStartResult> startDiscovery();
  Future<void> stopDiscovery();
  Future<ConnectionStartResult> connect(String deviceId);
  Future<bool> acceptConnection(String deviceId);
  Future<bool> rejectConnection(String deviceId);
  Future<bool> sendMessage(String deviceId, String payload);
  Future<void> disconnect(String deviceId);
  Future<void> dispose();
}

class BluetoothStateInfo {
  const BluetoothStateInfo({required this.state, this.message});
  final BluetoothState state;
  final String? message;
}

class ConnectionStartResult {
  const ConnectionStartResult({required this.started, this.message});
  final bool started;
  final String? message;
}

class DiscoveryAvailability {
  const DiscoveryAvailability({required this.available, this.message});
  final bool available;
  final String? message;
}

class DiscoveryStartResult {
  const DiscoveryStartResult({
    required this.started,
    this.message,
    this.permanentlyDenied = false,
  });
  final bool started;
  final String? message;
  final bool permanentlyDenied;
}

sealed class DeviceDiscoveryEvent {
  const DeviceDiscoveryEvent();
}

class DeviceFound extends DeviceDiscoveryEvent {
  const DeviceFound(this.device);
  final NearbyDevice device;
}

class BluetoothStateChanged extends DeviceDiscoveryEvent {
  const BluetoothStateChanged(this.state);
  final BluetoothState state;
}

class MessageReceivedEvent extends DeviceDiscoveryEvent {
  const MessageReceivedEvent(this.payload);
  final String payload;
}

class DiscoveryCompleted extends DeviceDiscoveryEvent {
  const DiscoveryCompleted();
}

class DiscoveryFailed extends DeviceDiscoveryEvent {
  const DiscoveryFailed(this.message);
  final String message;
}

class ConnectionEvent extends DeviceDiscoveryEvent {
  const ConnectionEvent(this.type, this.deviceId, {this.message, this.name});
  final String type;
  final String deviceId;
  final String? message;
  final String? name;
}
