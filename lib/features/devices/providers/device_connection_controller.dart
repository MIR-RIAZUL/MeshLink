import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meshlink/features/devices/data/models/nearby_device.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  waitingForAcceptance,
  connected,
  disconnecting,
  failed,
  lost,
}

class DeviceConnectionController extends ChangeNotifier {
  DeviceConnectionController(this._service) {
    _subscription = _service.events.listen(_onEvent);
  }
  final DeviceDiscoveryService _service;
  StreamSubscription<DeviceDiscoveryEvent>? _subscription;
  ConnectionStatus status = ConnectionStatus.disconnected;
  String? deviceId;
  String? errorMessage;
  NearbyDevice? incomingDevice;
  DateTime? connectedSince;
  final Set<String> _connectedDevices = {};

  Set<String> get connectedDevices => Set.unmodifiable(_connectedDevices);

  bool isConnected(String id) =>
      _connectedDevices.contains(id) ||
      (status == ConnectionStatus.connected && deviceId == id);

  bool get hasAnyConnection =>
      _connectedDevices.isNotEmpty || status == ConnectionStatus.connected;

  Future<void> connect(NearbyDevice device) async {
    deviceId = device.id;
    errorMessage = null;
    status = ConnectionStatus.connecting;
    notifyListeners();
    final result = await _service.connect(device.id);
    if (!result.started) {
      status = ConnectionStatus.failed;
      errorMessage = result.message;
      notifyListeners();
    }
  }

  Future<void> accept() async {
    final id = incomingDevice?.id;
    if (id != null) {
      deviceId = id;
      status = ConnectionStatus.waitingForAcceptance;
      await _service.acceptConnection(id);
    }
    incomingDevice = null;
    notifyListeners();
  }

  Future<void> reject() async {
    final id = incomingDevice?.id;
    if (id != null) await _service.rejectConnection(id);
    incomingDevice = null;
    notifyListeners();
  }

  Future<void> disconnect(String id) async {
    status = ConnectionStatus.disconnecting;
    notifyListeners();
    await _service.disconnect(id);
  }

  void _onEvent(DeviceDiscoveryEvent event) {
    if (event is! ConnectionEvent) return;
    if (event.type == 'incomingRequest') {
      incomingDevice = NearbyDevice(
        id: event.deviceId,
        name: event.name ?? 'MeshLink User',
        isConnectable: true,
        lastSeen: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    if (event.type == 'connected') {
      _connectedDevices.add(event.deviceId);
      deviceId = event.deviceId;
      status = ConnectionStatus.connected;
      connectedSince = DateTime.now();
      notifyListeners();
      return;
    }

    if (event.type == 'disconnected') {
      _connectedDevices.remove(event.deviceId);
      if (deviceId == event.deviceId) {
        if (_connectedDevices.isNotEmpty) {
          deviceId = _connectedDevices.last;
          status = ConnectionStatus.connected;
        } else {
          status = ConnectionStatus.lost;
        }
      }
      notifyListeners();
      return;
    }

    if (event.deviceId != deviceId) return;

    switch (event.type) {
      case 'waitingForAcceptance':
        status = ConnectionStatus.waitingForAcceptance;
      case 'connectionFailed':
        status = ConnectionStatus.failed;
        errorMessage = event.message;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
