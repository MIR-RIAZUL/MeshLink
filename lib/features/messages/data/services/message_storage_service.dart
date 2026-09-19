import 'dart:async';

import 'package:meshlink/features/messages/data/models/mesh_message.dart';

abstract class MessageStorageService {
  Future<List<MeshMessage>> getMessages(String peerId);
  Future<void> saveMessage(MeshMessage message);
  Future<void> updateMessageStatus(String messageId, MessageStatus status);
  Future<bool> hasMessage(String messageId);
  Future<List<String>> getActivePeerIds();
  Future<MeshMessage?> getLastMessage(String peerId);
}

class InMemoryMessageStorageService implements MessageStorageService {
  final Map<String, List<MeshMessage>> _messagesByPeer = {};
  final Set<String> _knownMessageIds = {};

  @override
  Future<List<MeshMessage>> getMessages(String peerId) async {
    final list = _messagesByPeer[peerId] ?? [];
    return List<MeshMessage>.from(list);
  }

  @override
  Future<void> saveMessage(MeshMessage message) async {
    _knownMessageIds.add(message.id);
    // Store under both sender and receiver peer ID mapping
    final targetPeer = message.receiverId;
    final otherPeer = message.senderId;

    _addForPeer(targetPeer, message);
    if (otherPeer != targetPeer) {
      _addForPeer(otherPeer, message);
    }
  }

  void _addForPeer(String peerId, MeshMessage message) {
    final list = _messagesByPeer.putIfAbsent(peerId, () => []);
    final existingIndex = list.indexWhere((m) => m.id == message.id);
    if (existingIndex >= 0) {
      list[existingIndex] = message;
    } else {
      list.add(message);
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    for (final list in _messagesByPeer.values) {
      final index = list.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        list[index] = list[index].copyWith(status: status);
      }
    }
  }

  @override
  Future<bool> hasMessage(String messageId) async {
    return _knownMessageIds.contains(messageId);
  }

  @override
  Future<List<String>> getActivePeerIds() async {
    return _messagesByPeer.keys.toList();
  }

  @override
  Future<MeshMessage?> getLastMessage(String peerId) async {
    final list = _messagesByPeer[peerId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }
}
