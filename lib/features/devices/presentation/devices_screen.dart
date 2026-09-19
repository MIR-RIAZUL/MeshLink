import 'package:flutter/material.dart';
import 'package:meshlink/core/widgets/primary_button.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key, required this.controller});

  final DeviceDiscoveryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Devices')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
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
              ...controller.devices.map((device) => Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: Text(device.name),
                  subtitle: const Text('Nearby'),
                  trailing: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connections will be available in Phase 3.')),
                    ),
                    child: const Text('Connect'),
                  ),
                ),
              )),
            ],
            const SizedBox(height: 20),
            Center(child: PrimaryButton(
              label: controller.isDiscovering ? 'Stop Discovery' : 'Discover Devices',
              onPressed: controller.isDiscovering ? controller.stopDiscovery : controller.startDiscovery,
            )),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryMessage extends StatelessWidget {
  const _DiscoveryMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );
}
