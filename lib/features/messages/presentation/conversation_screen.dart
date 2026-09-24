import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:meshlink/features/devices/providers/device_connection_controller.dart';
import 'package:meshlink/features/messages/data/models/mesh_message.dart';
import 'package:meshlink/features/messages/providers/messaging_controller.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.messagingController,
    required this.connectionController,
  });

  final String peerId;
  final String peerName;
  final MessagingController messagingController;
  final DeviceConnectionController connectionController;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.messagingController.loadMessages(widget.peerId);
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final isNotEmpty = _textController.text.trim().isNotEmpty;
    if (isNotEmpty != _canSend) {
      setState(() {
        _canSend = isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (text.length > MeshMessage.maxMessageLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message is too long (${text.length} chars). Maximum allowed length is ${MeshMessage.maxMessageLength} characters.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _textController.clear();
    await widget.messagingController.sendMessage(widget.peerId, text);
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) return;
      await widget.messagingController.sendFile(widget.peerId, File(path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to send the selected file.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.messagingController,
        widget.connectionController,
      ]),
      builder: (context, _) {
        final isDirectConnected = widget.connectionController.isConnected(
          widget.peerId,
        );
        final hasRelayConnection = !isDirectConnected &&
            widget.connectionController.hasAnyConnection;
        final messages = widget.messagingController.getMessages(widget.peerId);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Text(
                    widget.peerName.isNotEmpty
                        ? widget.peerName[0].toUpperCase()
                        : 'M',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.peerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDirectConnected
                                  ? Colors.green
                                  : (hasRelayConnection
                                      ? Colors.teal
                                      : Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isDirectConnected
                                ? '● Direct Link'
                                : (hasRelayConnection
                                    ? '● Mesh Relay Active'
                                    : '○ Disconnected'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDirectConnected
                                  ? Colors.green
                                  : (hasRelayConnection
                                      ? Colors.teal
                                      : Colors.grey[600]),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${widget.peerId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Connection Status / Multi-Hop Relay Banner
              if (!isDirectConnected && hasRelayConnection)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.teal.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: Colors.teal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Direct link unavailable. Messages will be routed via connected MeshLink relay peers.',
                          style: TextStyle(
                            color: Colors.teal[900],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (!isDirectConnected && !hasRelayConnection)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.amber.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Peer disconnected. Messages will be saved locally and sent when reconnected.',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages List
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No messages yet',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Start an offline conversation with ${widget.peerName}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId != widget.peerId;
                          return _MessageBubble(
                            message: msg,
                            isOutgoing: isMe,
                            onRetry: isMe &&
                                    (msg.status == MessageStatus.failed ||
                                        msg.status == MessageStatus.pending)
                                ? () => widget.messagingController.retryMessage(
                                      msg,
                                    )
                                : null,
                          );
                        },
                      ),
              ),

              // Bottom Input Bar
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _textController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 4,
                            minLines: 1,
                            enabled: true, // Always allowed to compose offline messages!
                            decoration: InputDecoration(
                              hintText: isDirectConnected
                                  ? 'Type an offline message...'
                                  : (hasRelayConnection
                                      ? 'Type message (via mesh relay)...'
                                      : 'Type message (will queue offline)...'),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) {
                              if (_canSend) _sendMessage();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _pickAndSendFile,
                        icon: const Icon(Icons.attach_file),
                        tooltip: 'Send a file',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _canSend ? _sendMessage : null,
                        icon: const Icon(Icons.send, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOutgoing,
    this.onRetry,
  });

  final MeshMessage message;
  final bool isOutgoing;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = TimeOfDay.fromDateTime(message.timestamp).format(context);

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOutgoing
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
            bottomRight: Radius.circular(isOutgoing ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isOutgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isOutgoing
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hopCount > 0) ...[
                  Text(
                    'via ${message.hopCount} hop${message.hopCount > 1 ? 's' : ''} • ',
                    style: TextStyle(
                      fontSize: 10,
                      color: isOutgoing
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.65)
                          : Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isOutgoing
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.75)
                        : Colors.grey[600],
                  ),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 5),
                  _buildStatusIcon(context),
                ],
              ],
            ),
            if (message.status == MessageStatus.failed && onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: onRetry,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Colors.amberAccent),
                      SizedBox(width: 4),
                      Text(
                        'Tap to retry',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (message.status) {
      case MessageStatus.pending:
        return const Icon(
          Icons.access_time_rounded,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.sending:
        return const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white70,
          ),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.amberAccent,
        );
    }
  }
}
