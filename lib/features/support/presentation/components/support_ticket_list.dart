part of '../support_ticket_screen.dart';

class _SupportTicketList extends StatelessWidget {
  const _SupportTicketList({
    required this.controller,
    required this.onCreate,
    required this.onOpen,
  });

  final SupportTicketController controller;
  final VoidCallback onCreate;
  final ValueChanged<SupportTicketSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final hasBlockingError =
        controller.tickets.isEmpty &&
        !const <SupportTicketLoadStatus>{
          SupportTicketLoadStatus.idle,
          SupportTicketLoadStatus.loading,
          SupportTicketLoadStatus.loaded,
          SupportTicketLoadStatus.empty,
        }.contains(controller.listStatus);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Ask Admin support for help',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Support tickets are private and separate from task messages. They cannot change an Order or delivery state.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Create support ticket'),
        ),
        const SizedBox(height: 20),
        _SupportTicketFilters(controller: controller),
        const SizedBox(height: 16),
        if (controller.tickets.isNotEmpty && controller.listError != null)
          _SupportTicketNotice(
            message: 'Showing saved results. ${controller.listError}',
            icon: Icons.sync_problem_outlined,
            liveRegion: true,
          ),
        if ((controller.listStatus == SupportTicketLoadStatus.idle ||
                controller.listStatus == SupportTicketLoadStatus.loading) &&
            controller.tickets.isEmpty)
          const _SupportTicketLoading(label: 'Loading support tickets')
        else if (hasBlockingError)
          _SupportTicketErrorCard(
            message: controller.listError ?? 'Support tickets are unavailable.',
            onRetry: controller.canRetry ? controller.refreshList : null,
          )
        else if (controller.listStatus == SupportTicketLoadStatus.empty ||
            controller.tickets.isEmpty)
          const _SupportTicketEmpty()
        else ...[
          for (final ticket in controller.tickets) ...[
            _SupportTicketCard(ticket: ticket, onTap: () => onOpen(ticket)),
            const SizedBox(height: 10),
          ],
          if (controller.loadMoreError != null)
            _SupportTicketNotice(
              message: controller.loadMoreError!,
              icon: Icons.cloud_off_outlined,
            ),
          if (controller.canLoadMoreTickets)
            OutlinedButton.icon(
              onPressed: controller.loadingMoreTickets
                  ? null
                  : controller.loadMoreTicketsPage,
              icon: controller.loadingMoreTickets
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Load older tickets'),
            ),
        ],
      ],
    );
  }
}

class _SupportTicketFilters extends StatelessWidget {
  const _SupportTicketFilters({required this.controller});

  final SupportTicketController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Support ticket filters',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<SupportTicketStatusFilter>(
                initialValue: controller.statusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final value in SupportTicketStatusFilter.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    unawaited(controller.setFilters(status: value));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SupportTicketCategoryFilter>(
                initialValue: controller.categoryFilter,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final value in SupportTicketCategoryFilter.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    unawaited(controller.setFilters(category: value));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({required this.ticket, required this.onTap});

  final SupportTicketSummary ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = ticket.unreadCount;
    return Semantics(
      button: true,
      label:
          '${ticket.reference}. ${ticket.subject}. ${ticket.statusLabel}. $unread unread update${unread == 1 ? '' : 's'}.',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.support_agent_outlined, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.subject,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ticket.reference} • ${ticket.categoryLabel} • ${ticket.statusLabel}',
                      ),
                      if (unread > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$unread unread update${unread == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
