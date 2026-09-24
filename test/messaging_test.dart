import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/features/devices/data/services/device_discovery_service.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';
import 'package:meshlink/features/messages/data/database/app_database.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/repositories/message_repository.dart';
import 'package:meshlink/features/messages/data/services/message_storage_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';
import 'package:meshlink/features/messages/data/services/mesh_crypto_service.dart';
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
        conversationId: 'ML-000002',
        senderId: 'ML-000001',
        receiverId: 'ML-000002',
        text: 'Hello MeshLink peer!',
        timestamp: now,
        status: MessageStatus.sent,
      );

      final wireStr = msg.toWireProtocol();
      expect(wireStr.contains('"type":"message"'), isTrue);
      expect(wireStr.contains('"version":1'), isTrue);
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
        conversationId: 'ML-000001',
        senderId: 'ML-000002',
        receiverId: 'ML-000001',
      );

      expect(ackStr.contains('"type":"ack"'), isTrue);
      expect(ackStr.contains('"version":1'), isTrue);
      expect(ackStr.contains('"messageId":"msg-12345"'), isTrue);
      expect(ackStr.contains('"senderId":"ML-000002"'), isTrue);
    });

    test('Rejects oversized message payload', () {
      final hugeText = 'A' * (MeshMessage.maxMessageLength + 50);
      expect(
        () => MeshMessage.validateLength(hugeText),
        throwsArgumentError,
      );

      final hugeWireJson = '{"type":"message","messageId":"m1","senderId":"S","receiverId":"R","text":"$hugeText"}';
      expect(MeshMessage.fromWireProtocol(hugeWireJson), isNull);
    });

    test('Unique message ID generation works', () {
      final id1 = MeshMessage.generateId();
      final id2 = MeshMessage.generateId();
      expect(id1, isNot(equals(id2)));
      expect(id1.startsWith('MSG-'), isTrue);
    });
  });

  group('Drift Database & MessageRepository Operations', () {
    late AppDatabase db;
    late DriftMessageRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftMessageRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Saves, retrieves, and checks existence of messages in SQLite', () async {
      final msg = MeshMessage(
        id: 'msg-sqlite-1',
        conversationId: 'ML-PEER-B',
        senderId: 'ML-PEER-A',
        receiverId: 'ML-PEER-B',
        text: 'Hello SQLite!',
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
      );

      expect(await repository.hasMessage('msg-sqlite-1'), isFalse);
      await repository.saveMessage(msg);
      expect(await repository.hasMessage('msg-sqlite-1'), isTrue);

      final peerBMessages = await repository.getMessages('ML-PEER-B');
      expect(peerBMessages.length, 1);
      expect(peerBMessages.first.text, 'Hello SQLite!');
      expect(peerBMessages.first.status, MessageStatus.pending);

      final activePeers = await repository.getActivePeerIds();
      expect(activePeers.contains('ML-PEER-B'), isTrue);

      final last = await repository.getLastMessage('ML-PEER-B');
      expect(last?.id, 'msg-sqlite-1');
    });

    test('Updates message status and retry count properly', () async {
      final msg = MeshMessage(
        id: 'msg-retry-1',
        conversationId: 'ML-PEER-B',
        senderId: 'ML-LOCAL',
        receiverId: 'ML-PEER-B',
        text: 'Will retry',
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
        retryCount: 0,
      );

      await repository.saveMessage(msg);
      await repository.incrementRetryCount('msg-retry-1');
      await repository.updateMessageStatus('msg-retry-1', MessageStatus.sending);

      final list = await repository.getMessages('ML-PEER-B');
      expect(list.first.retryCount, 1);
      expect(list.first.status, MessageStatus.sending);
    });

    test('Retrieves pending messages correctly', () async {
      final m1 = MeshMessage(
        id: 'p1',
        conversationId: 'ML-PEER-B',
        senderId: 'ML-LOCAL',
        receiverId: 'ML-PEER-B',
        text: 'Pending 1',
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
      );
      final m2 = MeshMessage(
        id: 'p2',
        conversationId: 'ML-PEER-B',
        senderId: 'ML-LOCAL',
        receiverId: 'ML-PEER-B',
        text: 'Sent 2',
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      await repository.saveMessage(m1);
      await repository.saveMessage(m2);

      final pending = await repository.getPendingMessages('ML-PEER-B');
      expect(pending.length, 1);
      expect(pending.first.id, 'p1');
    });

    test('Separates conversations cleanly by peer device ID', () async {
      final msgB = MeshMessage(
        id: 'b1',
        conversationId: 'ML-PEER-B',
        senderId: 'ML-LOCAL',
        receiverId: 'ML-PEER-B',
        text: 'Message to B',
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      final msgC = MeshMessage(
        id: 'c1',
        conversationId: 'ML-PEER-C',
        senderId: 'ML-LOCAL',
        receiverId: 'ML-PEER-C',
        text: 'Message to C',
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      await repository.saveMessage(msgB);
      await repository.saveMessage(msgC);

      final listB = await repository.getMessages('ML-PEER-B');
      final listC = await repository.getMessages('ML-PEER-C');

      expect(listB.length, 1);
      expect(listB.first.text, 'Message to B');
      expect(listC.length, 1);
      expect(listC.first.text, 'Message to C');
    });
  });

  group('BleMeshMessagingService & MessagingController Flow', () {
    late MockDiscoveryService mockDiscovery;
    late InMemoryMessageStorageService storage;
    late BleMeshMessagingService messagingService;
    late DeviceConnectionController connectionController;
    late MessagingController controller;
    late MeshCryptoService localCrypto;

    setUp(() async {
      mockDiscovery = MockDiscoveryService();
      storage = InMemoryMessageStorageService();
      localCrypto = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
      final remoteCrypto = MeshCryptoService(keyStore: InMemoryKeyMaterialStore());
      localCrypto.rememberPeerKey('ML-REMOTE', await remoteCrypto.localPublicKey());
      messagingService = BleMeshMessagingService(
        discoveryService: mockDiscovery,
        storageService: storage,
        localId: 'ML-LOCAL',
        cryptoService: localCrypto,
      );
      connectionController = DeviceConnectionController(mockDiscovery);
      controller = MessagingController(
        messagingService: messagingService,
        localId: 'ML-LOCAL',
        connectionController: connectionController,
      );
    });

    tearDown(() async {
      controller.dispose();
      connectionController.dispose();
      await messagingService.dispose();
      await mockDiscovery.dispose();
    });

    test('Sending message while connected transmits frame and sets status to sent', () async {
      // Simulate connected state
      mockDiscovery.emit(const ConnectionEvent('connected', 'ML-REMOTE'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await controller.sendMessage('ML-REMOTE', 'Hello connected peer!');

      final messages = controller.getMessages('ML-REMOTE');
      expect(messages.length, 1);
      expect(messages.first.text, 'Hello connected peer!');
      expect(messages.first.status, MessageStatus.sent);
      expect(mockDiscovery.sentPayloads.length, 1);
    });

    test('Sending message while disconnected saves as PENDING', () async {
      await controller.sendMessage('ML-REMOTE', 'Hello offline peer!');

      final messages = controller.getMessages('ML-REMOTE');
      expect(messages.length, 1);
      expect(messages.first.text, 'Hello offline peer!');
      expect(messages.first.status, MessageStatus.pending);
      expect(mockDiscovery.sentPayloads.length, 0);
    });

    test('Reconnecting peer automatically flushes pending messages', () async {
      // Send message while disconnected
      await controller.sendMessage('ML-REMOTE', 'Queued message');
      expect(controller.getMessages('ML-REMOTE').first.status, MessageStatus.pending);

      // Now peer connects
      mockDiscovery.emit(const ConnectionEvent('connected', 'ML-REMOTE'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final messages = controller.getMessages('ML-REMOTE');
      expect(messages.first.status, MessageStatus.sent);
      expect(mockDiscovery.sentPayloads.length, 1);
      expect(mockDiscovery.sentPayloads.first.contains('Queued message'), isFalse);
    });

    test('Receiving ACK frame updates status to delivered', () async {
      mockDiscovery.emit(const ConnectionEvent('connected', 'ML-REMOTE'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await controller.sendMessage('ML-REMOTE', 'Check delivery ACK');
      final msg = controller.getMessages('ML-REMOTE').first;

      final ackPayload = MeshMessage.createAckPayload(
        messageId: msg.id,
        conversationId: 'ML-LOCAL',
        senderId: 'ML-REMOTE',
        receiverId: 'ML-LOCAL',
      );
      mockDiscovery.emit(MessageReceivedEvent(ackPayload));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final updated = controller.getMessages('ML-REMOTE').first;
      expect(updated.status, MessageStatus.delivered);
    });

    test('Duplicate incoming message is not duplicated in DB/UI but triggers ACK re-send', () async {
      final incoming = MeshMessage(
        id: 'dup-msg-77',
        conversationId: 'ML-REMOTE',
        senderId: 'ML-REMOTE',
        receiverId: 'ML-LOCAL',
        text: 'Unique packet text',
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      );

      mockDiscovery.emit(MessageReceivedEvent(incoming.toWireProtocol()));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Emit exact same packet again
      mockDiscovery.emit(MessageReceivedEvent(incoming.toWireProtocol()));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final list = controller.getMessages('ML-REMOTE');
      expect(list.length, 1);

      // Verify two ACK frames were sent back for the duplicate messageId
      final ackPayloads = mockDiscovery.sentPayloads
          .where((p) => p.contains('"type":"ack"') && p.contains('dup-msg-77'))
          .toList();
      expect(ackPayloads.length, 2);
    });

    test('Retry message preserves original messageId', () async {
      mockDiscovery.shouldSendSucceed = false;
      mockDiscovery.emit(const ConnectionEvent('connected', 'ML-REMOTE'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await controller.sendMessage('ML-REMOTE', 'Try original ID');
      final msg = controller.getMessages('ML-REMOTE').first;
      final originalId = msg.id;

      // Re-enable send success
      mockDiscovery.shouldSendSucceed = true;
      await controller.retryMessage(msg);

      final retriedMsg = controller.getMessages('ML-REMOTE').first;
      expect(retriedMsg.id, originalId);
      expect(retriedMsg.status, MessageStatus.sent);
    });
  });
}
