import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_router.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';

class MockDiscoveryService implements DeviceDiscoveryService {
  MockDiscoveryService({this.localIdentity = const LocalIdentity(id: 'ML-DEFAULT', name: 'Default')});

  final StreamController<DeviceDiscoveryEvent> _controller =
      StreamController<DeviceDiscoveryEvent>.broadcast();

  final List<Map<String, String>> sentTransmissions = [];
  final List<String> sentPayloads = [];
  bool shouldSendSucceed = true;
  final LocalIdentity localIdentity;

  @override
  Stream<DeviceDiscoveryEvent> get events => _controller.stream;

  void emit(DeviceDiscoveryEvent event) => _controller.add(event);

  @override
  Future<bool> sendMessage(String deviceId, String payload) async {
    if (!shouldSendSucceed) return false;
    sentTransmissions.add({'deviceId': deviceId, 'payload': payload});
    sentPayloads.add(payload);
    return true;
  }

  @override
  Future<BluetoothStateInfo> getBluetoothState() async =>
      const BluetoothStateInfo(state: BluetoothState.enabled);

  @override
  Future<bool> requestEnableBluetooth() async => true;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<LocalIdentity> getLocalIdentity() async => localIdentity;

  @override
  Future<void> setDisplayName(String name) async {}

  @override
  Future<DiscoveryAvailability> checkAvailability() async =>
      const DiscoveryAvailability(available: true);

  @override
  Future<DiscoveryStartResult> startDiscovery() async =>
      const DiscoveryStartResult(started: true);

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<ConnectionStartResult> connect(String deviceId) async =>
      const ConnectionStartResult(started: true);

  @override
  Future<bool> acceptConnection(String deviceId) async => true;

  @override
  Future<bool> rejectConnection(String deviceId) async => true;

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Helper node representing a complete MeshLink node in an in-memory mesh simulation.
class MeshNode {
  MeshNode({required this.id, required this.name}) {
    discovery = MockDiscoveryService(localIdentity: LocalIdentity(id: id, name: name));
    storage = InMemoryMessageStorageService();
    connectionController = DeviceConnectionController(discovery);
    router = MeshRouter(
      discoveryService: discovery,
      localId: id,
      getConnectedPeers: () => connectionController.connectedDevices,
    );
    crypto = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
    messagingService = BleMeshMessagingService(
      discoveryService: discovery,
      storageService: storage,
      localId: id,
      router: router,
      cryptoService: crypto,
    );
    controller = MessagingController(
      messagingService: messagingService,
      localId: id,
      connectionController: connectionController,
    );
  }

  final String id;
  final String name;
  late final MockDiscoveryService discovery;
  late final InMemoryMessageStorageService storage;
  late final DeviceConnectionController connectionController;
  late final MeshRouter router;
  late final MeshCryptoService crypto;
  late final BleMeshMessagingService messagingService;
  late final MessagingController controller;

  Future<void> dispose() async {
    controller.dispose();
    connectionController.dispose();
    await messagingService.dispose();
    await router.dispose();
    await discovery.dispose();
  }
}

void main() {
  group('MeshRouter Unit Tests', () {
    late MockDiscoveryService mockDiscovery;
    late MeshRouter router;

    setUp(() {
      mockDiscovery = MockDiscoveryService(localIdentity: const LocalIdentity(id: 'NODE-B', name: 'Node B'));
      router = MeshRouter(
        discoveryService: mockDiscovery,
        localId: 'NODE-B',
      );
    });

    tearDown(() async {
      await router.dispose();
      await mockDiscovery.dispose();
    });

    test('Direct link priority: routes directly when destination is connected', () async {
      // Connect Node A and Node C to Node B
      mockDiscovery.emit(const ConnectionEvent('connected', 'NODE-A'));
      mockDiscovery.emit(const ConnectionEvent('connected', 'NODE-C'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final msg = MeshMessage(
        id: 'msg-1',
        conversationId: 'NODE-C',
        senderId: 'NODE-B',
        receiverId: 'NODE-C',
        originId: 'NODE-B',
        destinationId: 'NODE-C',
        text: 'Direct hello',
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
      );

      final forwarded = await router.routeMessage(msg);
      expect(forwarded, isTrue);
      expect(mockDiscovery.sentTransmissions.length, 1);
      expect(mockDiscovery.sentTransmissions.first['deviceId'], 'NODE-C');
    });

    test('Multi-hop relay: forwards message when destination is not directly connected', () async {
      // Node B is only connected to Node C (destination is Node D)
      mockDiscovery.emit(const ConnectionEvent('connected', 'NODE-C'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final msg = MeshMessage(
        id: 'msg-2',
        conversationId: 'NODE-D',
        senderId: 'NODE-B',
        receiverId: 'NODE-D',
        originId: 'NODE-B',
        destinationId: 'NODE-D',
        text: 'Routed hello to D',
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
      );

      final forwarded = await router.routeMessage(msg);
      expect(forwarded, isTrue);
      expect(mockDiscovery.sentTransmissions.length, 1);
      expect(mockDiscovery.sentTransmissions.first['deviceId'], 'NODE-C');
    });

    test('TTL decrement: intermediate relay decrements TTL by 1 and increments hopCount', () async {
      mockDiscovery.emit(const ConnectionEvent('connected', 'NODE-C'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final incomingPayload = jsonEncode({
        'type': 'message',
        'version': 1,
        'messageId': 'msg-ttl-1',
        'originId': 'NODE-A',
        'destinationId': 'NODE-C',
        'senderId': 'NODE-A',
        'receiverId': 'NODE-C',
        'text': 'TTL check',
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': 5,
        'hopCount': 0,
      });

      final result = await router.handleIncomingPayload(incomingPayload, fromPeerId: 'NODE-A');
      expect(result, isA<RelayedMessage>());
      final relayed = result as RelayedMessage;
      expect(relayed.newTtl, 4);
      expect(relayed.newHopCount, 1);
      expect(relayed.forwardedCount, 1);

      // Verify wire payload sent out has TTL=4 and hopCount=1
      final sentPayloadStr = mockDiscovery.sentTransmissions.first['payload']!;
      final sentJson = jsonDecode(sentPayloadStr) as Map<String, dynamic>;
      expect(sentJson['ttl'], 4);
      expect(sentJson['hopCount'], 1);
      expect(sentJson['messageId'], 'msg-ttl-1');
      expect(sentJson['originId'], 'NODE-A');
      expect(sentJson['destinationId'], 'NODE-C');
    });

    test('TTL expiration: drops message when TTL is <= 1 upon arrival (new TTL <= 0)', () async {
      mockDiscovery.emit(const ConnectionEvent('connected', 'NODE-C'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final incomingPayload = jsonEncode({
        'type': 'message',
        'version': 1,
        'messageId': 'msg-expired',
        'originId': 'NODE-A',
        'destinationId': 'NODE-Z',
        'senderId': 'NODE-A',
        'receiverId': 'NODE-Z',
        'text': 'Expired packet',
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': 1,
        'hopCount': 4,
      });

      final result = await router.handleIncomingPayload(incomingPayload, fromPeerId: 'NODE-A');
      expect(result, isA<DroppedPayload>());
      expect((result as DroppedPayload).reason.contains('TTL expired'), isTrue);
      expect(mockDiscovery.sentTransmissions.isEmpty, isTrue);
    });

    test('Duplicate protection: drops duplicate messageId at intermediate relay', () async {
      mockDiscovery.emit(const ConnectionEvent('connected', 'NODE-C'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final payload = jsonEncode({
        'type': 'message',
        'version': 1,
        'messageId': 'msg-dup-check',
        'originId': 'NODE-A',
        'destinationId': 'NODE-C',
        'senderId': 'NODE-A',
        'receiverId': 'NODE-C',
        'text': 'Dup check',
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': 5,
        'hopCount': 0,
      });

      // First arrival -> relays
      final result1 = await router.handleIncomingPayload(payload, fromPeerId: 'NODE-A');
      expect(result1, isA<RelayedMessage>());
      expect(mockDiscovery.sentTransmissions.length, 1);

      // Second arrival -> duplicate dropped
      final result2 = await router.handleIncomingPayload(payload, fromPeerId: 'NODE-A');
      expect(result2, isA<DroppedPayload>());
      expect((result2 as DroppedPayload).reason.contains('Duplicate message'), isTrue);
      expect(mockDiscovery.sentTransmissions.length, 1); // Still 1, no second forward
    });

    test('Loop prevention: does not send packet back to originId or sender peer', () async {
      // Node B is connected to Node A only. Incoming packet originates from Node A.
      mockDiscovery.emit(const ConnectionEvent('connected', 'NODE-A'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final payload = jsonEncode({
        'type': 'message',
        'version': 1,
        'messageId': 'msg-loop-check',
        'originId': 'NODE-A',
        'destinationId': 'NODE-C',
        'senderId': 'NODE-A',
        'receiverId': 'NODE-C',
        'text': 'Loop check',
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': 5,
        'hopCount': 0,
      });

      final result = await router.handleIncomingPayload(payload, fromPeerId: 'NODE-A');
      expect(result, isA<RelayedMessage>());
      // Target count should be 0 because the only connected peer is NODE-A (the sender & origin)
      expect((result as RelayedMessage).forwardedCount, 0);
      expect(mockDiscovery.sentTransmissions.isEmpty, isTrue);
    });

    test('Local destination detection: delivers locally if destinationId matches localId', () async {
      final payload = jsonEncode({
        'type': 'message',
        'version': 1,
        'messageId': 'msg-local-dest',
        'originId': 'NODE-A',
        'destinationId': 'NODE-B',
        'senderId': 'NODE-A',
        'receiverId': 'NODE-B',
        'text': 'Hello Node B',
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': 5,
        'hopCount': 0,
      });

      final result = await router.handleIncomingPayload(payload, fromPeerId: 'NODE-A');
      expect(result, isA<LocalMessageDelivery>());
      final delivered = (result as LocalMessageDelivery).message;
      expect(delivered.id, 'msg-local-dest');
      expect(delivered.text, 'Hello Node B');
      expect(delivered.originId, 'NODE-A');
      expect(delivered.destinationId, 'NODE-B');
      expect(mockDiscovery.sentTransmissions.length, 1);
      expect(mockDiscovery.sentTransmissions.first['payload']!.contains('"type":"ack"'), isTrue);
    });
  });

  group('Three-Node Multi-Hop Topology Simulation (A ↔ B ↔ C)', () {
    late MeshNode nodeA;
    late MeshNode nodeB;
    late MeshNode nodeC;

    setUp(() async {
      nodeA = MeshNode(id: 'NODE-A', name: 'Phone A');
      nodeB = MeshNode(id: 'NODE-B', name: 'Phone B');
      nodeC = MeshNode(id: 'NODE-C', name: 'Phone C');
      final aKey = await nodeA.crypto.localPublicKey();
      final bKey = await nodeB.crypto.localPublicKey();
      final cKey = await nodeC.crypto.localPublicKey();
      nodeA.crypto.rememberPeerKey('NODE-B', bKey);
      nodeA.crypto.rememberPeerKey('NODE-C', cKey);
      nodeB.crypto.rememberPeerKey('NODE-A', aKey);
      nodeB.crypto.rememberPeerKey('NODE-C', cKey);
      nodeC.crypto.rememberPeerKey('NODE-A', aKey);
      nodeC.crypto.rememberPeerKey('NODE-B', bKey);

      // Setup topology: A <-> B and B <-> C (A and C do NOT connect directly)
      nodeA.discovery.emit(const ConnectionEvent('connected', 'NODE-B'));
      nodeB.discovery.emit(const ConnectionEvent('connected', 'NODE-A'));
      nodeB.discovery.emit(const ConnectionEvent('connected', 'NODE-C'));
      nodeC.discovery.emit(const ConnectionEvent('connected', 'NODE-B'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() async {
      await nodeA.dispose();
      await nodeB.dispose();
      await nodeC.dispose();
    });

    test('Full Forward Path: A -> B -> C', () async {
      // 1. A sends message intended for C
      await nodeA.controller.sendMessage('NODE-C', 'Hello from Phone A to Phone C');

      final aMessages = nodeA.controller.getMessages('NODE-C');
      expect(aMessages.length, 1);
      expect(aMessages.first.status, MessageStatus.sent);
      expect(aMessages.first.originId, 'NODE-A');
      expect(aMessages.first.destinationId, 'NODE-C');

      // Verify A transmitted payload to B
      expect(nodeA.discovery.sentTransmissions.length, 1);
      final payloadToB = nodeA.discovery.sentTransmissions.first['payload']!;
      expect(nodeA.discovery.sentTransmissions.first['deviceId'], 'NODE-B');

      // 2. Relay Node B receives payload from A
      nodeB.discovery.emit(MessageReceivedEvent(payloadToB, peerId: 'NODE-A'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // B should NOT store message locally in its own conversation list
      final bMessages = nodeB.controller.getMessages('NODE-C');
      expect(bMessages.isEmpty, isTrue);

      // B should forward message to C
      expect(nodeB.discovery.sentTransmissions.length, 1);
      expect(nodeB.discovery.sentTransmissions.first['deviceId'], 'NODE-C');
      final payloadToC = nodeB.discovery.sentTransmissions.first['payload']!;

      // Verify TTL was decremented and hop count incremented
      final payloadJson = jsonDecode(payloadToC) as Map<String, dynamic>;
      expect(payloadJson['ttl'], 4);
      expect(payloadJson['hopCount'], 1);

      // 3. Destination Node C receives payload from B
      nodeC.discovery.emit(MessageReceivedEvent(payloadToC, peerId: 'NODE-B'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // C should receive and store message in conversation with A
      final cMessages = nodeC.controller.getMessages('NODE-A');
      expect(cMessages.length, 1);
      expect(cMessages.first.text, 'Hello from Phone A to Phone C');
      expect(cMessages.first.originId, 'NODE-A');
      expect(cMessages.first.destinationId, 'NODE-C');
      expect(cMessages.first.hopCount, 1);
      expect(cMessages.first.status, MessageStatus.delivered);
    });

    test('Full Reverse Path: C -> B -> A', () async {
      // 1. C sends message intended for A
      await nodeC.controller.sendMessage('NODE-A', 'Hello back from C to A');

      final cMessages = nodeC.controller.getMessages('NODE-A');
      expect(cMessages.length, 1);
      expect(cMessages.first.status, MessageStatus.sent);

      expect(nodeC.discovery.sentTransmissions.length, 1);
      final payloadToB = nodeC.discovery.sentTransmissions.first['payload']!;
      expect(nodeC.discovery.sentTransmissions.first['deviceId'], 'NODE-B');

      // 2. B receives and relays from C
      nodeB.discovery.emit(MessageReceivedEvent(payloadToB, peerId: 'NODE-C'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(nodeB.discovery.sentTransmissions.length, 1);
      expect(nodeB.discovery.sentTransmissions.first['deviceId'], 'NODE-A');
      final payloadToA = nodeB.discovery.sentTransmissions.first['payload']!;

      // 3. A receives from B
      nodeA.discovery.emit(MessageReceivedEvent(payloadToA, peerId: 'NODE-B'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final aMessages = nodeA.controller.getMessages('NODE-C');
      expect(aMessages.length, 1);
      expect(aMessages.first.text, 'Hello back from C to A');
      expect(aMessages.first.originId, 'NODE-C');
    });

    test('End-to-End ACK: C generates ACK which relays through B back to A, marking message delivered', () async {
      // A sends message to C
      await nodeA.controller.sendMessage('NODE-C', 'ACK check payload');
      final aMsgId = nodeA.controller.getMessages('NODE-C').first.id;

      // A -> B
      final payloadToB = nodeA.discovery.sentTransmissions.first['payload']!;
      nodeB.discovery.emit(MessageReceivedEvent(payloadToB, peerId: 'NODE-A'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // B -> C
      final payloadToC = nodeB.discovery.sentTransmissions.first['payload']!;
      nodeC.discovery.emit(MessageReceivedEvent(payloadToC, peerId: 'NODE-B'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // C delivers message and generates ACK for A
      expect(nodeC.discovery.sentTransmissions.length, 1);
      final ackToB = nodeC.discovery.sentTransmissions.first['payload']!;
      expect(ackToB.contains('"type":"ack"'), isTrue);

      // C -> B (ACK)
      nodeB.discovery.emit(MessageReceivedEvent(ackToB, peerId: 'NODE-C'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // B relays ACK toward A
      final ackPayloadsFromB = nodeB.discovery.sentTransmissions
          .where((t) => t['deviceId'] == 'NODE-A' && t['payload']!.contains('"type":"ack"'))
          .toList();
      expect(ackPayloadsFromB.length, 1);
      final ackToA = ackPayloadsFromB.first['payload']!;

      // B -> A (ACK)
      nodeA.discovery.emit(MessageReceivedEvent(ackToA, peerId: 'NODE-B'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // A updates original message status to DELIVERED
      final aFinalMessages = nodeA.controller.getMessages('NODE-C');
      expect(aFinalMessages.first.id, aMsgId);
      expect(aFinalMessages.first.status, MessageStatus.delivered);
    });

    test('Store-and-forward when relay peer reconnects', () async {
      // Disconnect B from A initially
      nodeA.discovery.emit(const ConnectionEvent('disconnected', 'NODE-B'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // A queues message for C while offline
      await nodeA.controller.sendMessage('NODE-C', 'Offline queued message');
      expect(nodeA.controller.getMessages('NODE-C').first.status, MessageStatus.pending);

      // Now B connects to A
      nodeA.discovery.emit(const ConnectionEvent('connected', 'NODE-B'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // A flushes pending message to B
      expect(nodeA.discovery.sentTransmissions.length, 1);
      expect(nodeA.discovery.sentTransmissions.first['deviceId'], 'NODE-B');
      expect(nodeA.controller.getMessages('NODE-C').first.status, MessageStatus.sent);
    });
  });
}
