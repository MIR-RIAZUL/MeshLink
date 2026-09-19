import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/models/nearby_device.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/presentation/conversation_screen.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';
import 'package:meshlink/main.dart';

import 'device_discovery_controller_test.dart';

void main() {
  testWidgets('shows the MeshLink home screen with Bluetooth state', (
    tester,
  ) async {
    final fakeService = FakeDeviceDiscoveryService();
    await tester.pumpWidget(MeshLinkApp(service: fakeService));
    await tester.pumpAndSettle();

    expect(find.text('MeshLink'), findsWidgets);
    expect(find.text('Bluetooth Required'), findsOneWidget);
    expect(find.text('Turn On Bluetooth'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('navigates to Messages tab and renders empty state', (
    tester,
  ) async {
    final fakeService = FakeDeviceDiscoveryService();
    await tester.pumpWidget(MeshLinkApp(service: fakeService));
    await tester.pumpAndSettle();

    // Tap on Messages tab icon
    await tester.tap(find.byIcon(Icons.message));
    await tester.pumpAndSettle();

    expect(find.text('Offline Messages'), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('ConversationScreen renders peer name and empty state', (
    tester,
  ) async {
    final fakeService = FakeDeviceDiscoveryService();
    final storage = InMemoryMessageStorageService();
    final messagingService = BleMeshMessagingService(
      discoveryService: fakeService,
      storageService: storage,
      localId: 'ML-LOCAL',
    );
    final messagingController = MessagingController(
      messagingService: messagingService,
      localId: 'ML-LOCAL',
    );
    final connectionController = DeviceConnectionController(fakeService);

    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          peerId: 'ML-PEER',
          peerName: 'Peer Phone',
          messagingController: messagingController,
          connectionController: connectionController,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Peer Phone'), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('ConversationScreen allows entering and sending message', (
    tester,
  ) async {
    final fakeService = FakeDeviceDiscoveryService();
    final storage = InMemoryMessageStorageService();
    final messagingService = BleMeshMessagingService(
      discoveryService: fakeService,
      storageService: storage,
      localId: 'ML-LOCAL',
    );
    final messagingController = MessagingController(
      messagingService: messagingService,
      localId: 'ML-LOCAL',
    );
    final connectionController = DeviceConnectionController(fakeService);

    await connectionController.connect(
      NearbyDevice(
        id: 'ML-PEER',
        name: 'Peer Phone',
        isConnectable: true,
        lastSeen: DateTime.now(),
      ),
    );
    fakeService.emitEvent(
      const ConnectionEvent('connected', 'ML-PEER', name: 'Peer Phone'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          peerId: 'ML-PEER',
          peerName: 'Peer Phone',
          messagingController: messagingController,
          connectionController: connectionController,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello peer offline!');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Hello peer offline!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
