import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/chat_models.dart';
import 'controllers/chat_controller.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    required this.controller,
    required this.authController,
    this.thread,
    this.task,
    super.key,
  }) : assert(thread != null || task != null);

  final ChatController controller;
  final AuthController authController;
  final ChatThread? thread;
  final ChatTaskContext? task;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_clearDraftOnSessionChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.thread case final thread?) {
        await widget.controller.openThread(thread);
      } else if (widget.task case final task?) {
        await widget.controller.openTask(task);
      }
      if (!mounted) return;
      final attempt = widget.controller.pendingAttempt;
      if (attempt != null &&
          attempt.taskId == widget.controller.activeTask?.taskId &&
          attempt.counterpartyRole ==
              widget.controller.activeTask?.counterpartyRole) {
        _text.text = attempt.body;
      }
      widget.controller.startPollingThread();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refreshActive());
      widget.controller.startPollingThread();
    } else {
      widget.controller.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_clearDraftOnSessionChange);
    widget.controller.stopPolling();
    _text.dispose();
    super.dispose();
  }

  void _clearDraftOnSessionChange() {
    if (widget.authController.status != AuthStatus.authenticated) {
      _text.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> _send() async {
    final sent = await widget.controller.sendMessage(_text.text);
    if (sent && mounted) _text.clear();
  }

  Future<void> _discardPending() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard pending retry?'),
        content: const Text(
          'The previous message may have been saved. Refresh the conversation before sending different text.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard retry'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.controller.discardPendingAttempt();
      await widget.controller.refreshActive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.authController]),
      builder: (context, child) {
        if (widget.authController.status != AuthStatus.authenticated) {
          return const Scaffold(body: Center(child: Text('Session ended.')));
        }
        final controller = widget.controller;
        final thread = controller.activeThread;
        final task = controller.activeTask;
        final role =
            thread?.counterpartyRole ?? task?.counterpartyRole ?? 'logistics';
        final title = switch (role) {
          'seller' => 'Seller',
          'customer' => 'Buyer',
          _ => 'Logistics',
        };
        final sendable =
            task?.canCompose == true &&
            (controller.threadStatus == ChatLoadStatus.loaded ||
                controller.threadStatus == ChatLoadStatus.empty) &&
            controller.sendStatus != ChatSendStatus.conflict &&
            (thread == null
                ? task != null &&
                      controller.threadStatus == ChatLoadStatus.empty
                : thread.sendAllowed == true);
        return Scaffold(
          appBar: AppBar(title: Text('Message $title')),
          body: Column(
            children: [
              ListTile(
                title: Text(thread?.counterpartyLabel ?? title),
                subtitle: Text(
                  '${task?.leg == 'first_mile' ? 'First mile' : 'Final mile'} · ${thread?.taskReference ?? task?.reference ?? thread?.orderReference ?? 'Task'}',
                ),
              ),
              if (thread?.sendAllowed == false || task?.canCompose == false)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Read-only conversation. Replies are unavailable here.',
                  ),
                ),
              if (controller.threadError case final error?)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(error),
                      if (controller.canRetry)
                        TextButton(
                          onPressed: controller.refreshActive,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refreshActive,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (controller.threadStatus == ChatLoadStatus.loading &&
                          controller.messages.isEmpty)
                        const Center(child: CircularProgressIndicator()),
                      if (controller.threadStatus == ChatLoadStatus.empty)
                        const Text(
                          'No task conversation found in the current inbox. Your first message will open or resume the server-authorized thread.',
                        ),
                      if (controller.canLoadOlder)
                        TextButton(
                          onPressed: controller.loadOlder,
                          child: const Text('Load older messages'),
                        ),
                      for (final message in controller.messages)
                        _MessageRow(message: message),
                    ],
                  ),
                ),
              ),
              if (controller.sendError case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(liveRegion: true, child: Text(error)),
                ),
              if (controller.pendingAttempt != null &&
                  controller.sendStatus != ChatSendStatus.sending)
                TextButton(
                  onPressed: _discardPending,
                  child: const Text('Discard pending retry'),
                ),
              if (sendable)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            maxLength: 2000,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Message',
                              hintText: 'Type a message',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: controller.pendingAttempt == null
                              ? 'Send message'
                              : 'Retry same message',
                          onPressed:
                              controller.sendStatus == ChatSendStatus.sending ||
                                  !controller.canRetry
                              ? null
                              : _send,
                          icon: const Icon(Icons.send),
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

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '${message.mine ? 'You' : message.senderRole}: ${message.body}',
      child: Align(
        alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: message.mine
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(message.body),
        ),
      ),
    );
  }
}
