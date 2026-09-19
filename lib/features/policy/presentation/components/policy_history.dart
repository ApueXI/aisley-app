part of '../policy_screen.dart';

class PolicyHistoryScreen extends StatefulWidget {
  const PolicyHistoryScreen({
    required this.authController,
    required this.policyController,
    required this.type,
    super.key,
  });

  final AuthController authController;
  final PolicyController policyController;
  final PolicyType type;

  @override
  State<PolicyHistoryScreen> createState() => _PolicyHistoryScreenState();
}

class _PolicyHistoryScreenState extends State<PolicyHistoryScreen> {
  PolicyController get controller => widget.policyController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(controller.loadHistory(widget.type));
      }
    });
  }

  Future<void> _openVersion(PolicyHistoryEntry entry) async {
    final document = await controller.loadHistoryVersion(
      widget.type,
      entry.version,
    );
    if (!mounted || document == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyVersionScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final history = controller.historyFor(widget.type);
        final error = controller.historyErrors[widget.type];
        final isLoading = controller.isHistoryLoading(widget.type);
        return Scaffold(
          appBar: AppBar(title: Text('${widget.type.fallbackLabel} history')),
          body: history == null && isLoading
              ? const _PolicyLoadingView()
              : history == null
              ? _PolicyStateView(
                  icon: Icons.history,
                  title: 'History unavailable',
                  message: error ?? 'We could not load the policy history.',
                  onRetry: isLoading
                      ? null
                      : () => controller.loadHistory(
                          widget.type,
                          forceRefresh: true,
                        ),
                )
              : _buildHistory(context, history, error),
        );
      },
    );
  }

  Widget _buildHistory(
    BuildContext context,
    PolicyHistory history,
    String? error,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        Text(
          'Published history',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'History is read-only. Opening an older version does not change your consent.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _PolicyBanner(message: error, isError: true),
        ],
        const SizedBox(height: 18),
        if (history.versions.isEmpty)
          const _NoPublishedPolicyView()
        else
          ...history.versions.map(
            (entry) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                minVerticalPadding: 14,
                leading: const Icon(Icons.description_outlined),
                title: Text('Version ${entry.version}: ${entry.title}'),
                subtitle: Text(
                  '${_statusLabel(entry.status)} • ${_formatDate(context, entry.publishedAt)}${entry.changeSummary == null ? '' : '\n${entry.changeSummary}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openVersion(entry),
              ),
            ),
          ),
      ],
    );
  }
}
