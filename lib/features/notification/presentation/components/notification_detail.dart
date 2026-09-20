part of '../notification_screen.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    required this.controller,
    required this.notification,
    this.onOpenTarget,
    super.key,
  });

  final NotificationController controller;
  final CourierNotification notification;
  final NotificationTargetOpener? onOpenTarget;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.controller.loadDetail(widget.notification.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final notification =
            widget.controller.detailFor(widget.notification.id) ??
            widget.notification;
        final detailStatus = widget.controller.detailStatusFor(notification.id);
        final detailError = widget.controller.detailErrorFor(notification.id);
        final readStatus = widget.controller.readStatusFor(notification.id);
        final readError = widget.controller.readErrorFor(notification.id);
        final canOpenTarget =
            detailStatus != NotificationLoadStatus.unavailable &&
            notification.hasDestination &&
            widget.onOpenTarget != null;

        return Scaffold(
          appBar: AppBar(title: const Text('Notification details')),
          body: RefreshIndicator(
            onRefresh: () async {
              await widget.controller.loadDetail(notification.id);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                if (detailStatus == NotificationLoadStatus.loading &&
                    widget.controller.detailFor(notification.id) == null)
                  const _NotificationLoadingCard()
                else
                  _NotificationDetailCard(
                    notification: notification,
                    detailStatus: detailStatus,
                    detailError: detailError,
                    readStatus: readStatus,
                    readError: readError,
                    onMarkRead:
                        notification.isRead ||
                            readStatus == NotificationReadStatus.reading
                        ? null
                        : () => widget.controller.markRead(notification.id),
                    onOpenTarget: canOpenTarget
                        ? () => widget.onOpenTarget!(notification)
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationDetailCard extends StatelessWidget {
  const _NotificationDetailCard({
    required this.notification,
    required this.detailStatus,
    required this.detailError,
    required this.readStatus,
    required this.readError,
    this.onMarkRead,
    this.onOpenTarget,
  });

  final CourierNotification notification;
  final NotificationLoadStatus detailStatus;
  final String? detailError;
  final NotificationReadStatus readStatus;
  final String? readError;
  final VoidCallback? onMarkRead;
  final VoidCallback? onOpenTarget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUnavailable = detailStatus == NotificationLoadStatus.unavailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.typeLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(notification.summary),
                const SizedBox(height: 16),
                Text(
                  _formatNotificationDate(context, notification.createdAt),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: notification.isRead ? 'Read' : 'Unread',
                  child: Text(
                    notification.isRead ? 'Read' : 'Unread',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (detailError != null) ...[
          const SizedBox(height: 12),
          _NotificationInlineMessage(
            message: detailError!,
            icon: isUnavailable ? Icons.link_off_outlined : Icons.info_outline,
          ),
        ],
        if (readError != null) ...[
          const SizedBox(height: 12),
          _NotificationInlineMessage(
            message: readError!,
            icon: Icons.mark_email_unread_outlined,
          ),
        ],
        const SizedBox(height: 16),
        if (onOpenTarget != null) ...[
          OutlinedButton.icon(
            onPressed: onOpenTarget,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open related work'),
          ),
          const SizedBox(height: 12),
        ] else if (notification.hasDestination || isUnavailable) ...[
          _NotificationInlineMessage(
            message: isUnavailable
                ? 'The related work is no longer available. The notification remains read-only.'
                : 'The related work is not currently available to this Courier.',
            icon: Icons.link_off_outlined,
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: onMarkRead,
          icon: readStatus == NotificationReadStatus.reading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mark_email_read_outlined),
          label: Text(notification.isRead ? 'Already read' : 'Mark as read'),
        ),
      ],
    );
  }
}
