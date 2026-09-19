import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';

class MockDiscoveryService implements DeviceDiscoveryService {
  final StreamController<DeviceDiscoveryEvent> _controller =
      StreamController<DeviceDiscoveryEvent>.broadcast();

  final List<String> sentPayloads = [];
  bool shouldSendSucceed = true;

  @override
  Stream<DeviceDiscoveryEvent> get events => _controller.stream;

  void emit(DeviceDiscoveryEvent event) => _controller.add(event);

  @override
  Future<bool> sendMessage(String deviceId, String payload) async {
    if (!shouldSendSucceed) return false;
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
  Future<LocalIdentity> getLocalIdentity() async =>
      const LocalIdentity(id: 'ML-LOCAL', name: 'Local User');

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

void main() {
  group('MeshMessage Model & Wire Protocol', () {
    test('Serializes to and from wire protocol JSON correctly', () {
      final now = DateTime.utc(2026, 9, 20, 12, 0, 0);
      final msg = MeshMessage(
        id: 'msg-12345',
        senderId: 'ML-000001',
        receiverId: 'ML-000002',
        text: 'Hello MeshLink peer!',
        timestamp: now,
        status: MessageStatus.sent,
      );

      final wireStr = msg.toWireProtocol();
      expect(wireStr.contains('"type":"message"'), isTrue);
      expect(wireStr.contains('"messageId":"msg-12345"'), isTrue);
      expect(wireStr.contains('"text":"Hello MeshLink peer!"'), isTrue);

      final decoded = MeshMessage.fromWireProtocol(wireStr);
      expect(decoded, isNotNull);
      expect(decoded!.id, 'msg-12345');
      expect(decoded.senderId, 'ML-000001');
      expect(decoded.receiverId, 'ML-000002');
      expect(decoded.text, 'Hello MeshLink peer!');
      expect(decoded.timestamp, now);
      expect(decoded.status, MessageStatus.delivered);
    });

    test('Creates valid ACK payload frame', () {
      final ackStr = MeshMessage.createAckPayload(
        messageId: 'msg-12345',
        senderId: 'ML-000002',
        receiverId: 'ML-000001',
      );

      expect(ackStr.contains('"type":"ack"'), isTrue);
      expect(ackStr.contains('"messageId":"msg-12345"'), isTrue);
      expect(ackStr.contains('"senderId":"ML-000002"'), isTrue);
    });
  });

  group('InMemoryMessageStorageService', () {
    late InMemoryMessageStorageService storage;

    setUp(() {
      storage = InMemoryMessageStorageService();
    });

    test('Saves, retrieves, and checks existence of messages', () async {
      final msg = MeshMessage(
        id: 'msg-1',
        senderId: 'ML-A',
        receiverId: 'ML-B',
        text: 'Testing storage',
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      expect(await storage.hasMessage('msg-1'), isFalse);
      await storage.saveMessage(msg);
      expect(await storage.hasMessage('msg-1'), isTrue);

      final listA = await storage.getMessages('ML-A');
      expect(listA.length, 1);
      expect(listA.first.text, 'Testing storage');

      final listB = await storage.getMessages('ML-B');
      expect(listB.length, 1);
      expect(listB.first.text, 'Testing storage');

      final last = await storage.getLastMessage('ML-B');
      expect(last?.id, 'msg-1');
    });

    test('Updates message status properly', () async {
      final msg = MeshMessage(
        id: 'msg-2',
        senderId: 'ML-A',
        receiverId: 'ML-B',
        text: 'Status test',
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );

      await storage.saveMessage(msg);
      await storage.updateMessageStatus('msg-2', MessageStatus.delivered);

      final list = await storage.getMessages('ML-B');
      expect(list.first.status, MessageStatus.delivered);
    });
  });

  group('BleMeshMessagingService & MessagingController Flow', () {
    late MockDiscoveryService mockDiscovery;
    late InMemoryMessageStorageService storage;
    late BleMeshMessagingService messagingService;
    late MessagingController controller;

    setUp(() {
      mockDiscovery = MockDiscoveryService();
      storage = InMemoryMessageStorageService();
      messagingService = BleMeshMessagingService(
        discoveryService: mockDiscovery,
        storageService: storage,
        localId: 'ML-LOCAL',
      );
      controller = MessagingController(
        messagingService: messagingService,
        localId: 'ML-LOCAL',
      );
    });

    tearDown(() async {
      controller.dispose();
      await messagingService.dispose();
      await mockDiscovery.dispose();
    });

    test('Sending a message sends wire payload over BLE and updates status to sent', () async {
      await controller.sendMessage('ML-REMOTE', 'Hello over BLE!');

      final messages = controller.getMessages('ML-REMOTE');
      expect(messages.length, 1);
      expect(messages.first.text, 'Hello over BLE!');
      expect(messages.first.status, MessageStatus.sent);
      expect(mockDiscovery.sentPayloads.length, 1);
      expect(
        mockDiscovery.sentPayloads.first.contains('Hello over BLE!'),
        isTrue,
      );
    });

    test('Failed BLE transport marks message as failed', () async {
      mockDiscovery.shouldSendSucceed = false;
      await controller.sendMessage('ML-REMOTE', 'Will fail');

      final messages = controller.getMessages('ML-REMOTE');
      expect(messages.length, 1);
      expect(messages.first.status, MessageStatus.failed);
    });

    test('Receiving ACK frame updates message status to delivered', () async {
      await controller.sendMessage('ML-REMOTE', 'Check delivery');
      final msg = controller.getMessages('ML-REMOTE').first;
      expect(msg.status, MessageStatus.sent);

      // Peer returns ACK
      final ackPayload = MeshMessage.createAckPayload(
        messageId: msg.id,
        senderId: 'ML-REMOTE',
        receiverId: 'ML-LOCAL',
      );
      mockDiscovery.emit(MessageReceivedEvent(ackPayload));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final updatedMessages = controller.getMessages('ML-REMOTE');
      expect(updatedMessages.first.status, MessageStatus.delivered);
    });

    test('Receiving incoming message automatically stores message and replies with ACK', () async {
      final incoming = MeshMessage(
        id: 'msg-incoming-99',
        senderId: 'ML-REMOTE',
        receiverId: 'ML-LOCAL',
        text: 'Hey from remote phone!',
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      );

      mockDiscovery.emit(MessageReceivedEvent(incoming.toWireProtocol()));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final list = controller.getMessages('ML-REMOTE');
      expect(list.length, 1);
      expect(list.first.text, 'Hey from remote phone!');
      expect(list.first.status, MessageStatus.delivered);

      // Verify that ACK was sent back to sender
      expect(
        mockDiscovery.sentPayloads.any(
          (p) => p.contains('"type":"ack"') && p.contains('msg-incoming-99'),
        ),
        isTrue,
      );
    });

    test(
      'Duplicate incoming messages are suppressed and do not duplicate in list',
      () async {
        final incoming = MeshMessage(
          id: 'dup-100',
          senderId: 'ML-REMOTE',
          receiverId: 'ML-LOCAL',
          text: 'Unique text',
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
        );

        // Emit first time
        mockDiscovery.emit(MessageReceivedEvent(incoming.toWireProtocol()));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Emit second time (duplicate delivery)
        mockDiscovery.emit(MessageReceivedEvent(incoming.toWireProtocol()));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final list = controller.getMessages('ML-REMOTE');
        expect(list.length, 1);
      },
    );

    test('Retrying a failed message triggers re-transmission', () async {
      mockDiscovery.shouldSendSucceed = false;
      await controller.sendMessage('ML-REMOTE', 'Try once');
      final msg = controller.getMessages('ML-REMOTE').first;
      expect(msg.status, MessageStatus.failed);

      // Enable send success and retry
      mockDiscovery.shouldSendSucceed = true;
      await controller.retryMessage(msg);

      final retryList = controller.getMessages('ML-REMOTE');
      expect(retryList.first.status, MessageStatus.sent);
    });
  });
}
