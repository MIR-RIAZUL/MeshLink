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

  bool isConnected(String id) =>
      status == ConnectionStatus.connected && deviceId == id;

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
    if (event.deviceId != deviceId) return;
    switch (event.type) {
      case 'waitingForAcceptance':
        status = ConnectionStatus.waitingForAcceptance;
      case 'connected':
        status = ConnectionStatus.connected;
        connectedSince = DateTime.now();
      case 'disconnected':
        status = ConnectionStatus.lost;
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
