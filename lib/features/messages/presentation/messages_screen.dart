import 'package:flutter/material.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';
import 'package:meshlink/features/devices/providers/device_discovery_controller.dart';
import 'package:meshlink/features/messages/presentation/conversation_screen.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({
    super.key,
    required this.messagingController,
    required this.connectionController,
    required this.discoveryController,
  });

  final MessagingController messagingController;
  final DeviceConnectionController connectionController;
  final DeviceDiscoveryController discoveryController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Messages')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          messagingController,
          connectionController,
          discoveryController,
        ]),
        builder: (context, _) {
          final peerIds = messagingController.conversationPeerIds.toSet();

          // Also include the currently connected device if connected
          final activePeerId = connectionController.deviceId;
          if (connectionController.status == ConnectionStatus.connected &&
              activePeerId != null) {
            peerIds.add(activePeerId);
          }

          if (peerIds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_outlined,
                      size: 64,
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect to a nearby device in the Devices tab\nto start communicating offline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: peerIds.length,
            separatorBuilder: (context, _) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final peerId = peerIds.elementAt(index);
              final isConnected = connectionController.isConnected(peerId);
              final lastMsg = messagingController.getLastMessage(peerId);

              // Find peer display name from discovered devices or fallback
              final matchedDevice = discoveryController.devices
                  .where((d) => d.id == peerId)
                  .firstOrNull;
              final peerName = matchedDevice?.name ?? 'MeshLink User';

              return ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Text(
                        peerName.isNotEmpty ? peerName[0].toUpperCase() : 'M',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  peerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lastMsg != null
                      ? lastMsg.text
                      : (isConnected
                            ? 'Direct link active — tap to chat'
                            : 'No messages yet'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: lastMsg != null ? Colors.grey[700] : Colors.grey,
                    fontStyle: lastMsg == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastMsg != null)
                      Text(
                        TimeOfDay.fromDateTime(lastMsg.timestamp)
                            .format(context),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      peerId,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => ConversationScreen(
                        peerId: peerId,
                        peerName: peerName,
                        messagingController: messagingController,
                        connectionController: connectionController,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
