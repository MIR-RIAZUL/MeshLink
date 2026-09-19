import 'package:flutter/material.dart';
import 'package:meshlink/features/devices/data/models/nearby_device.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key, required this.controller, required this.connectionController});

  final DeviceDiscoveryController controller;
  final DeviceConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby MeshLink Users'),
        actions: [
          if (controller.isDiscovering)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, connectionController]),
        builder: (context, _) {
          final btState = controller.bluetoothState;
          final incoming = connectionController.incomingDevice;
          final devices = controller.devices;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Bluetooth State Alerts
              if (btState == BluetoothState.disabled) ...[
                _ActionBanner(
                  icon: Icons.bluetooth_disabled,
                  iconColor: Colors.red,
                  title: 'Bluetooth is OFF',
                  message: 'Turn on Bluetooth to find and advertise to nearby MeshLink users.',
                  buttonLabel: 'Turn On Bluetooth',
                  onPressed: controller.enableBluetooth,
                ),
                const SizedBox(height: 16),
              ] else if (btState == BluetoothState.permissionRequired || btState == BluetoothState.permissionPermanentlyDenied) ...[
                _ActionBanner(
                  icon: Icons.security,
                  iconColor: Colors.orange,
                  title: 'Bluetooth Permission Required',
                  message: btState == BluetoothState.permissionPermanentlyDenied
                      ? 'Permission permanently denied. Open Android Settings to grant access.'
                      : 'MeshLink needs nearby device permissions to discover other phones.',
                  buttonLabel: btState == BluetoothState.permissionPermanentlyDenied ? 'Open Settings' : 'Grant Permission',
                  onPressed: controller.requestPermissions,
                ),
                const SizedBox(height: 16),
              ] else if (controller.isDiscovering) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'MeshLink active — scanning for nearby devices',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Incoming Connection Request
              if (incoming != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incoming Connection Request',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('${incoming.name} (${incoming.id}) wants to connect directly with your device.'),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: connectionController.reject,
                              child: const Text('Decline'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: connectionController.accept,
                              child: const Text('Accept Link'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Nearby MeshLink Users List
              if (devices.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4),
                  child: Text(
                    'Nearby MeshLink Users (${devices.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                ...devices.map((device) => _DeviceCard(
                      device: device,
                      connectionController: connectionController,
                    )),
              ] else if (btState == BluetoothState.enabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar, size: 56, color: Colors.grey.withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        Text(
                          'No nearby MeshLink users found.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Make sure another device has MeshLink open\nand Bluetooth enabled.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.connectionController,
  });

  final NearbyDevice device;
  final DeviceConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    final connected = connectionController.isConnected(device.id);
    final active = connectionController.deviceId == device.id;
    final retryable = active &&
        (connectionController.status == ConnectionStatus.failed ||
            connectionController.status == ConnectionStatus.lost);
    final label = connected
        ? 'Disconnect'
        : retryable
            ? 'Reconnect'
            : active
                ? _connectionLabel(connectionController.status)
                : 'Connect';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: connected
              ? Colors.green.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.smartphone,
            color: connected ? Colors.green : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                device.id,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? Colors.green : Colors.teal,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected
                    ? 'Connected'
                    : active
                        ? _connectionLabel(connectionController.status)
                        : 'Nearby',
                style: TextStyle(
                  fontSize: 12,
                  color: connected ? Colors.green : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: connected
                ? Colors.red.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.primary,
            foregroundColor: connected
                ? Colors.red
                : Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: active && !connected && !retryable
              ? null
              : () => connected
                  ? connectionController.disconnect(device.id)
                  : connectionController.connect(device),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _connectionLabel(ConnectionStatus status) => switch (status) {
  ConnectionStatus.connecting => 'Connecting...',
  ConnectionStatus.waitingForAcceptance => 'Waiting...',
  ConnectionStatus.connected => 'Connected',
  ConnectionStatus.disconnecting => 'Disconnecting...',
  ConnectionStatus.failed => 'Failed',
  ConnectionStatus.lost => 'Lost',
  ConnectionStatus.disconnected => 'Connect',
};

