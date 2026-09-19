import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/data/services/mesh_messaging_service.dart';

class MessagingController extends ChangeNotifier {
  MessagingController({
    required MeshMessagingService messagingService,
    required String localId,
  }) : _service = messagingService,
       _currentLocalId = localId {
    _incomingSub = _service.incomingMessages.listen(_onIncomingMessage);
    _ackSub = _service.ackReceived.listen(_onAckReceived);
  }

  final MeshMessagingService _service;
  String _currentLocalId;
  final Map<String, List<MeshMessage>> _messagesByPeer = {};
  final Set<String> _knownMessageIds = {};

  String get localId => _currentLocalId;

  void setLocalId(String id) {
    _currentLocalId = id;
    if (_service is BleMeshMessagingService) {
      _service.setLocalId(id);
    }
  }

  StreamSubscription<MeshMessage>? _incomingSub;
  StreamSubscription<String>? _ackSub;

  List<MeshMessage> getMessages(String peerId) {
    return _messagesByPeer[peerId] ?? [];
  }

  List<String> get conversationPeerIds => _messagesByPeer.keys.toList();

  MeshMessage? getLastMessage(String peerId) {
    final list = _messagesByPeer[peerId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  Future<void> loadMessages(String peerId) async {
    final list = await _service.getMessagesForPeer(peerId);
    _messagesByPeer[peerId] = list;
    for (final m in list) {
      _knownMessageIds.add(m.id);
    }
    if (hasListeners) notifyListeners();
  }

  Future<void> sendMessage(String peerId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final message = MeshMessage(
      id: MeshMessage.generateId(),
      senderId: _currentLocalId,
      receiverId: peerId,
      text: trimmed,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Optimistic addition to UI
    _addMessageLocally(peerId, message);
    if (hasListeners) notifyListeners();

    final success = await _service.sendMessage(message);
    _updateStatusLocally(
      peerId,
      message.id,
      success ? MessageStatus.sent : MessageStatus.failed,
    );
    if (hasListeners) notifyListeners();
  }

  Future<void> retryMessage(MeshMessage message) async {
    final peerId = message.receiverId;
    _updateStatusLocally(peerId, message.id, MessageStatus.sending);
    if (hasListeners) notifyListeners();

    final success = await _service.sendMessage(message);
    _updateStatusLocally(
      peerId,
      message.id,
      success ? MessageStatus.sent : MessageStatus.failed,
    );
    if (hasListeners) notifyListeners();
  }

  void _onIncomingMessage(MeshMessage message) {
    if (_knownMessageIds.contains(message.id)) return;
    _knownMessageIds.add(message.id);

    final peerId = message.senderId;
    _addMessageLocally(peerId, message);
    if (hasListeners) notifyListeners();
  }

  void _onAckReceived(String messageId) {
    for (final peerId in _messagesByPeer.keys) {
      _updateStatusLocally(peerId, messageId, MessageStatus.delivered);
    }
    if (hasListeners) notifyListeners();
  }

  void _addMessageLocally(String peerId, MeshMessage message) {
    _knownMessageIds.add(message.id);
    final list = _messagesByPeer.putIfAbsent(peerId, () => []);
    final existingIndex = list.indexWhere((m) => m.id == message.id);
    if (existingIndex >= 0) {
      list[existingIndex] = message;
    } else {
      list.add(message);
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _updateStatusLocally(
    String peerId,
    String messageId,
    MessageStatus status,
  ) {
    final list = _messagesByPeer[peerId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      list[index] = list[index].copyWith(status: status);
    }
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _ackSub?.cancel();
    super.dispose();
  }
}
