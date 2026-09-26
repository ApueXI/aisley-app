part of '../support_ticket_screen.dart';

class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({
    required this.controller,
    required this.authController,
    required this.ticket,
    super.key,
  });

  final SupportTicketController controller;
  final AuthController authController;
  final SupportTicketSummary ticket;

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _reply;
  bool _returningFromUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_leaveOnSessionChange);
    _reply = TextEditingController(
      text: widget.controller.replyDraftFor(widget.ticket.id),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.controller.openDetail(widget.ticket);
      if (mounted) widget.controller.startDetailPolling(widget.ticket.id);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.startDetailPolling(
        widget.ticket.id,
        refreshImmediately: true,
      );
    } else {
      widget.controller.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_leaveOnSessionChange);
    widget.controller.stopPolling();
    _reply.dispose();
    super.dispose();
  }

  void _leaveOnSessionChange() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    _reply.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _sendReply() async {
    final saved = await widget.controller.reply(widget.ticket.id, _reply.text);
    if (saved && mounted) _reply.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.authController]),
      builder: (context, child) {
        final controller = widget.controller;
        final ticket = controller.activeTicket ?? widget.ticket;
        final replyStatus = controller.replyStatusFor(widget.ticket.id);
        final readStatus = controller.readStatusFor(widget.ticket.id);
        final unavailable =
            controller.detailStatus == SupportTicketLoadStatus.unavailable;
        if (unavailable && !_returningFromUnavailable) {
          _returningFromUnavailable = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pop(
              controller.detailError ??
                  'This support ticket is no longer available.',
            );
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(ticket.reference),
            actions: [
              IconButton(
                onPressed:
                    controller.detailStatus ==
                            SupportTicketLoadStatus.loading ||
                        !controller.canRetry
                    ? null
                    : controller.refreshDetail,
                tooltip: 'Refresh ticket',
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.refreshDetail,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                if (!unavailable) ...[
                  _SupportTicketSummaryCard(ticket: ticket),
                  const SizedBox(height: 16),
                ],
                if (controller.detailStatus ==
                        SupportTicketLoadStatus.loading &&
                    controller.events.isEmpty)
                  const _SupportTicketLoading(label: 'Loading ticket history')
                else if (unavailable)
                  _SupportTicketErrorCard(
                    message:
                        controller.detailError ??
                        'This support ticket is no longer available.',
                    onRetry: null,
                  )
                else ...[
                  if (controller.detailError != null)
                    _SupportTicketNotice(
                      message: controller.detailError!,
                      icon: Icons.sync_problem_outlined,
                      liveRegion: true,
                    ),
                  if (controller.canLoadMoreEvents)
                    OutlinedButton.icon(
                      onPressed: controller.loadingMoreEvents
                          ? null
                          : controller.loadOlderEvents,
                      icon: const Icon(Icons.history),
                      label: const Text('Load older updates'),
                    ),
                  if (controller.events.isEmpty)
                    const _SupportTicketNotice(
                      message: 'No ticket updates are available.',
                      icon: Icons.inbox_outlined,
                    )
                  else
                    for (final event in controller.events)
                      _SupportTicketEventCard(event: event),
                  const SizedBox(height: 12),
                  if (controller.readErrorFor(widget.ticket.id)
                      case final error?)
                    _SupportTicketNotice(
                      message: error,
                      icon: Icons.mark_email_unread_outlined,
                      liveRegion: true,
                    ),
                  OutlinedButton.icon(
                    onPressed:
                        ticket.unreadCount == 0 ||
                            readStatus == SupportTicketReadStatus.submitting ||
                            controller.latestVisibleSequence == null
                        ? null
                        : () => controller.markRead(widget.ticket.id),
                    icon: readStatus == SupportTicketReadStatus.submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mark_email_read_outlined),
                    label: Text(
                      ticket.unreadCount == 0 ? 'Already read' : 'Mark as read',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reply,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 7,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Reply',
                      hintText: 'Add information for Admin support',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) =>
                        controller.updateReplyDraft(widget.ticket.id, value),
                  ),
                  if (controller.replyErrorFor(widget.ticket.id)
                      case final error?)
                    _SupportTicketNotice(
                      message: error,
                      icon: Icons.info_outline,
                      liveRegion: true,
                    ),
                  if (controller.pendingReplyFor(widget.ticket.id) != null &&
                      replyStatus != SupportTicketMutationStatus.submitting)
                    TextButton(
                      onPressed: () =>
                          controller.discardPendingReply(widget.ticket.id),
                      child: const Text('Discard pending retry'),
                    ),
                  FilledButton.icon(
                    onPressed:
                        replyStatus == SupportTicketMutationStatus.submitting ||
                            !controller.canRetry
                        ? null
                        : _sendReply,
                    icon: replyStatus == SupportTicketMutationStatus.submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      controller.pendingReplyFor(widget.ticket.id) == null
                          ? 'Send reply'
                          : 'Retry same reply',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SupportTicketSummaryCard extends StatelessWidget {
  const _SupportTicketSummaryCard({required this.ticket});

  final SupportTicketSummary ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket.subject,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('${ticket.categoryLabel} • ${ticket.statusLabel}'),
            const SizedBox(height: 6),
            Text('Revision ${ticket.revision}'),
            if (ticket.assigneeName case final assignee?) ...[
              const SizedBox(height: 6),
              Text('Assigned to $assignee'),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupportTicketEventCard extends StatelessWidget {
  const _SupportTicketEventCard({required this.event});

  final SupportTicketEvent event;

  @override
  Widget build(BuildContext context) {
    final actor = event.isMine ? 'You' : 'Admin support';
    final description =
        event.body ??
        (event.toStatus == null
            ? event.typeLabel
            : '${event.typeLabel}: ${supportTicketStatusLabel(event.toStatus!)}');
    return Semantics(
      container: true,
      label: '$actor. ${event.typeLabel}. $description',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$actor • ${event.typeLabel}',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(description),
              if (event.createdAt case final created?) ...[
                const SizedBox(height: 8),
                Text(
                  _formatSupportDate(context, created),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
