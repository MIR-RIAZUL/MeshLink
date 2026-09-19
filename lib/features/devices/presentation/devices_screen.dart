import 'package:flutter/material.dart';
import 'package:meshlink/core/widgets/primary_button.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key, required this.controller, required this.connectionController});

  final DeviceDiscoveryController controller;
  final DeviceConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Devices')),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, connectionController]),
        builder: (context, _) {
          final incoming = connectionController.incomingDevice;
          return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (controller.isDiscovering) ...[
              const Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Searching for nearby devices...'),
              ]),
              const SizedBox(height: 8),
              const Text('Looking for nearby MeshLink devices.'),
            ] else if (controller.errorMessage != null) ...[
              _DiscoveryMessage(message: controller.errorMessage!),
            ] else if (controller.hasCompleted && controller.devices.isEmpty) ...[
              const _DiscoveryMessage(
                message: 'No nearby devices found.\n\nMake sure another compatible MeshLink device is nearby and searching.',
              ),
            ] else if (controller.devices.isEmpty) ...[
              const _DiscoveryMessage(message: 'No devices discovered\n\nTap "Discover Devices" to search nearby.'),
            ],
            if (controller.devices.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${controller.devices.length} devices found', style: Theme.of(context).textTheme.titleMedium),
              ),
              ...controller.devices.map((device) {
                final connected = connectionController.isConnected(device.id);
                final active = connectionController.deviceId == device.id;
                final retryable = active && (connectionController.status == ConnectionStatus.failed || connectionController.status == ConnectionStatus.lost);
                final label = connected ? 'Disconnect' : retryable ? 'Reconnect' : active ? _connectionLabel(connectionController.status) : 'Connect';
                return Card(
                child: ListTile(
                  leading: Icon(Icons.phone_android, color: connected ? Colors.green : null),
                  title: Text(device.name),
                  subtitle: Text(connected ? 'Connected' : active ? _connectionLabel(connectionController.status) : 'Nearby'),
                  onTap: connected ? () => showModalBottomSheet<void>(context: context, builder: (context) => Padding(
                    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Device', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
                      Text('Name: ${device.name}'), const Text('Status: Connected'), const Text('Connection: Peer-to-Peer'),
                      if (connectionController.connectedSince != null) Text('Connected Since: ${TimeOfDay.fromDateTime(connectionController.connectedSince!).format(context)}'),
                    ]),
                  )) : null,
                  trailing: TextButton(
                    onPressed: active && !connected && !retryable ? null : () => connected ? connectionController.disconnect(device.id) : connectionController.connect(device),
                    child: Text(label),
                  ),
                ),
              ); }),
            ],
            if (incoming != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              Text('Connection Request', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
              Text('${incoming.name} wants to connect with you.'), Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: connectionController.reject, child: const Text('Reject')),
                ElevatedButton(onPressed: connectionController.accept, child: const Text('Accept')),
              ])
            ]))),
            const SizedBox(height: 20),
            Center(child: PrimaryButton(
              label: controller.isDiscovering ? 'Stop Discovery' : 'Discover Devices',
              onPressed: controller.isDiscovering ? controller.stopDiscovery : controller.startDiscovery,
            )),
          ],
        );
        },
      ),
    );
  }
}

String _connectionLabel(ConnectionStatus status) => switch (status) {
  ConnectionStatus.connecting => 'Connecting...',
  ConnectionStatus.waitingForAcceptance => 'Waiting for acceptance...',
  ConnectionStatus.connected => 'Connected',
  ConnectionStatus.disconnecting => 'Disconnecting...',
  ConnectionStatus.failed => 'Connection failed',
  ConnectionStatus.lost => 'Connection lost',
  ConnectionStatus.disconnected => 'Connect',
};

class _DiscoveryMessage extends StatelessWidget {
  const _DiscoveryMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );
}
