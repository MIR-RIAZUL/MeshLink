import 'package:flutter/material.dart';
import 'package:meshlink/core/constants/strings.dart';
import 'package:meshlink/core/widgets/primary_button.dart';
import 'package:meshlink/core/widgets/status_card.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller, required this.connectionController});

  final DeviceDiscoveryController controller;
  final DeviceConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, connectionController]),
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.appTagline,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            // Offline status indicator
            Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(AppStrings.offlineStatus),
              ],
            ),
            const SizedBox(height: 24),
            // Network Status Card
            StatusCard(
              title: AppStrings.networkStatusTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _KeyValueRow(keyLabel: AppStrings.internetLabel, value: AppStrings.internetValue),
                  _KeyValueRow(keyLabel: AppStrings.nearbyDevicesLabel, value: '${controller.devices.length}'),
                  _KeyValueRow(keyLabel: 'Direct Link', value: connectionController.status == ConnectionStatus.connected ? 'Connected' : 'Not Connected'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Discover Devices Button
            Center(
              child: PrimaryButton(
                label: controller.isDiscovering ? 'Stop Discovery' : AppStrings.discoverButton,
                onPressed: controller.isDiscovering
                    ? controller.stopDiscovery
                    : controller.startDiscovery,
              ),
            ),
            ],
          ),
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
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
