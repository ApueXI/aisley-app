import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/chat_models.dart';
import 'controllers/chat_controller.dart';
import 'chat_thread_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({
    required this.controller,
    required this.authController,
    super.key,
  });

  final ChatController controller;
  final AuthController authController;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_leaveOnSessionChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.loadInbox());
      widget.controller.startPollingInbox();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.loadInbox());
      widget.controller.startPollingInbox();
    } else {
      widget.controller.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_leaveOnSessionChange);
    widget.controller.stopPolling();
    super.dispose();
  }

  void _leaveOnSessionChange() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _open(ChatThread thread) async {
    widget.controller.stopPolling();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          controller: widget.controller,
          authController: widget.authController,
          thread: thread,
        ),
      ),
    );
    if (!mounted || widget.authController.status != AuthStatus.authenticated) {
      return;
    }
    unawaited(widget.controller.loadInbox());
    widget.controller.startPollingInbox();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.authController]),
      builder: (context, child) {
        final controller = widget.controller;
        if (widget.authController.status != AuthStatus.authenticated) {
          return const Scaffold(body: Center(child: Text('Session ended.')));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Task messages')),
          body: RefreshIndicator(
            onRefresh: controller.loadInbox,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.inboxStatus == ChatLoadStatus.loading &&
                    controller.threads.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                if (controller.inboxError case final error?)
                  _ChatInboxNotice(
                    message: error,
                    onRetry: controller.canRetry ? controller.loadInbox : null,
                  ),
                if (controller.inboxStatus == ChatLoadStatus.empty)
                  const _ChatInboxNotice(
                    message: 'No task conversations yet. Open an eligible task to message Logistics.',
                  ),
                for (final thread in controller.threads)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    title: Text(
                      '${thread.counterpartyLabel ?? _label(thread.counterpartyRole)} · ${thread.taskReference ?? thread.orderReference ?? 'Task'}',
                    ),
                    subtitle: Text(
                      '${thread.leg == 'first_mile' ? 'First mile' : 'Final mile'} · ${thread.lastMessagePreview ?? 'Open conversation'}${thread.sendAllowed == false ? ' · Read-only' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: thread.unreadCount > 0
                        ? Text(
                            '${thread.unreadCount} unread',
                            style: Theme.of(context).textTheme.labelMedium,
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _open(thread),
                  ),
                if (controller.canLoadMoreInbox)
                  OutlinedButton(
                    onPressed: controller.loadingMoreInbox
                        ? null
                        : controller.loadMoreInbox,
                    child: Text(
                      controller.loadingMoreInbox
                          ? 'Loading…'
                          : 'Load older conversations',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _label(String role) => switch (role) {
  'customer' => 'Buyer',
  'seller' => 'Seller',
  _ => 'Logistics',
};

class _ChatInboxNotice extends StatelessWidget {
  const _ChatInboxNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
