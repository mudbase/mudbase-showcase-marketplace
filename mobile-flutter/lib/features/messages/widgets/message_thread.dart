import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../models/message.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/initials_avatar.dart';
import '../message_thread_controller.dart';

/// A listing's message thread - visible to the client and the accepted
/// freelancer only (gated by the caller, see `ListingDetailScreen
/// .canMessage`). Mirrors the web app's `MessageThread.tsx`.
class MessageThread extends ConsumerStatefulWidget {
  const MessageThread({
    required this.listingId,
    required this.currentUserId,
    required this.currentUserName,
    super.key,
  });

  final String listingId;
  final String currentUserId;
  final String currentUserName;

  @override
  ConsumerState<MessageThread> createState() => _MessageThreadState();
}

class _MessageThreadState extends ConsumerState<MessageThread> {
  final _draftController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _draftController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messageThreadControllerProvider(widget.listingId).notifier)
          .send(
            senderId: widget.currentUserId,
            senderName: widget.currentUserName,
            content: content,
          );
      _draftController.clear();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      messageThreadControllerProvider(widget.listingId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 320,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: AsyncValueView<List<Message>>(
              value: messagesAsync,
              onRetry: () => ref.invalidate(
                messageThreadControllerProvider(widget.listingId),
              ),
              data: (context, messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet — say hello.'),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwn = message.senderId == widget.currentUserId;
                    return _MessageBubble(message: message, isOwn: isOwn);
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _draftController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Write a message…'),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isOwn});

  final Message message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isOwn ? colorScheme.primary : colorScheme.surface;
    final textColor = isOwn ? colorScheme.onPrimary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            InitialsAvatar(name: message.senderName, radius: 12),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message.content, style: TextStyle(color: textColor)),
                  const SizedBox(height: 2),
                  Text(
                    '${message.senderName} · ${formatDateTime(message.createdAt)}',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwn) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
