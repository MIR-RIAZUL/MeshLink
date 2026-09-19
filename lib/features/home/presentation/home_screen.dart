import 'package:flutter/material.dart';
import 'package:meshlink/core/constants/strings.dart';
import 'package:meshlink/core/widgets/primary_button.dart';
import 'package:meshlink/core/widgets/status_card.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.connectionController,
  });

  final DeviceDiscoveryController controller;
  final DeviceConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, connectionController]),
      builder: (context, _) {
        final btState = controller.bluetoothState;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.appTagline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // Bluetooth State Prompt / Banner if not enabled
                if (btState == BluetoothState.disabled) ...[
                  _BluetoothRequiredCard(
                    title: 'Bluetooth Required',
                    description: 'MeshLink uses Bluetooth LE to automatically find and connect to nearby MeshLink users without internet.',
                    buttonLabel: 'Turn On Bluetooth',
                    onAction: controller.enableBluetooth,
                  ),
                  const SizedBox(height: 16),
                ] else if (btState == BluetoothState.permissionRequired ||
                    btState == BluetoothState.permissionPermanentlyDenied) ...[
                  _BluetoothRequiredCard(
                    title: 'Bluetooth Permission Required',
                    description:
                        btState == BluetoothState.permissionPermanentlyDenied
                        ? 'Bluetooth permissions were permanently denied. Please enable them in Android Settings.'
                        : 'Nearby-device permissions are needed to scan and advertise for MeshLink users.',
                    buttonLabel:
                        btState == BluetoothState.permissionPermanentlyDenied
                        ? 'Open Settings'
                        : 'Grant Permission',
                    onAction: controller.requestPermissions,
                  ),
                  const SizedBox(height: 16),
                ] else if (btState == BluetoothState.unavailable) ...[
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.errorMessage ??
                                  'Bluetooth LE is unavailable on this device.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Live Bluetooth & Discovery Indicator Card
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              btState == BluetoothState.enabled
                                  ? Icons.bluetooth
                                  : Icons.bluetooth_disabled,
                              color: btState == BluetoothState.enabled
                                  ? Colors.green
                                  : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bluetooth',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    _bluetoothStateLabel(btState),
                                    style: TextStyle(
                                      color: btState == BluetoothState.enabled
                                          ? Colors.green
                                          : Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.radar,
                              color: controller.isDiscovering
                                  ? Colors.blue
                                  : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MeshLink Discovery',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    controller.isDiscovering
                                        ? 'Active (Scanning & Advertising)'
                                        : 'Inactive',
                                    style: TextStyle(
                                      color: controller.isDiscovering
                                          ? Colors.blue
                                          : Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (controller.isDiscovering)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Network & Identity Status Card
                StatusCard(
                  title: AppStrings.networkStatusTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _KeyValueRow(
                        keyLabel: AppStrings.internetLabel,
                        value: AppStrings.internetValue,
                      ),
                      _KeyValueRow(
                        keyLabel: 'My MeshLink ID',
                        value: controller.localIdentity.id,
                      ),
                      _KeyValueRow(
                        keyLabel: 'My Display Name',
                        value: controller.localIdentity.name,
                      ),
                      _KeyValueRow(
                        keyLabel: AppStrings.nearbyDevicesLabel,
                        value: '${controller.devices.length} nearby',
                      ),
                      _KeyValueRow(
                        keyLabel: 'Direct Link',
                        value:
                            connectionController.status ==
                                ConnectionStatus.connected
                            ? 'Connected'
                            : 'Not Connected',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Manual Toggle button if needed (auto-starts by default)
                if (btState == BluetoothState.enabled)
                  Center(
                    child: PrimaryButton(
                      label: controller.isDiscovering
                          ? 'Pause Discovery'
                          : 'Resume Discovery',
                      onPressed: controller.isDiscovering
                          ? controller.stopDiscovery
                          : controller.startDiscovery,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _bluetoothStateLabel(BluetoothState state) => switch (state) {
    BluetoothState.enabled => 'Enabled',
    BluetoothState.disabled => 'Disabled',
    BluetoothState.permissionRequired => 'Permission Required',
    BluetoothState.permissionPermanentlyDenied =>
      'Permission Permanently Denied',
    BluetoothState.unavailable => 'Unavailable',
  };
}

class _BluetoothRequiredCard extends StatelessWidget {
  const _BluetoothRequiredCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onAction,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bluetooth_searching,
                  color: Colors.indigo,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onAction,
                icon: const Icon(Icons.power_settings_new),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.keyLabel, required this.value});
  final String keyLabel;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(keyLabel, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
