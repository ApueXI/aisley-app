import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/policy_models.dart';
import 'policy_controller.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({
    required this.authController,
    required this.policyController,
    super.key,
  });

  final AuthController authController;
  final PolicyController policyController;

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen>
    with WidgetsBindingObserver {
  final Map<PolicyType, int> _confirmedVersions = <PolicyType, int>{};

  PolicyController get controller => widget.policyController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(controller.refreshIfStale());
    }
  }

  Future<void> _load() async {
    await controller.load();
    if (!mounted) {
      return;
    }
    _clearOutdatedConfirmations();
    await _closeIfSessionEnded();
  }

  void _clearOutdatedConfirmations() {
    _confirmedVersions.removeWhere((type, version) {
      return controller.consentFor(type)?.currentVersion != version;
    });
  }

  Future<void> _accept(PolicyType type) async {
    await controller.accept(type);
    if (!mounted) {
      return;
    }
    _clearOutdatedConfirmations();
    await _closeIfSessionEnded();
  }

  Future<void> _openHistory(PolicyType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyHistoryScreen(
          authController: widget.authController,
          policyController: controller,
          type: type,
        ),
      ),
    );
  }

  Future<void> _closeIfSessionEnded() async {
    if (!mounted || widget.authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Policy & consent')),
          body: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = controller.state;
    if (state == PolicyViewState.signedOut ||
        state == PolicyViewState.unauthorized) {
      return _PolicyStateView(
        icon: Icons.lock_outline,
        title: 'Sign in required',
        message: 'Sign in again to view and manage your policy consent.',
        onRetry: null,
      );
    }
    if (state == PolicyViewState.forbidden) {
      return _PolicyStateView(
        icon: Icons.support_agent_outlined,
        title: 'Policy consent is unavailable',
        message: controller.errorMessage ?? 'Your Courier account or Logistics affiliation is not currently eligible. Contact your Logistics organization for help.',
        onRetry: null,
      );
    }
    if (controller.consentStatus == null &&
        (state == PolicyViewState.loadingStatus ||
            state == PolicyViewState.loadingDocument)) {
      return const _PolicyLoadingView();
    }
    if (controller.consentStatus == null) {
      return _PolicyStateView(
        icon: Icons.policy_outlined,
        title: 'Policy information unavailable',
        message:
            controller.errorMessage ??
            'We could not load the current policies.',
        onRetry:
            controller.isBusy ||
                (state == PolicyViewState.rateLimited &&
                    !controller.canRetryRateLimit)
            ? null
            : () => controller.retry(),
      );
    }

    return _buildPolicyList(context);
  }

  Widget _buildPolicyList(BuildContext context) {
    final status = controller.consentStatus!;
    final items = status.supportedPolicies.toList(growable: false);
    final state = controller.state;
    final showRetry =
        state == PolicyViewState.timeout ||
        state == PolicyViewState.offline ||
        state == PolicyViewState.retryableError ||
        state == PolicyViewState.rateLimited ||
        state == PolicyViewState.validationError ||
        state == PolicyViewState.staleVersion;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Platform policies',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review the current Terms of Service and Privacy Policy. Acceptance is recorded only after the server confirms it.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (state == PolicyViewState.loadingStatus ||
            state == PolicyViewState.loadingDocument) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (controller.successMessage != null) ...[
          const SizedBox(height: 16),
          _PolicyBanner(message: controller.successMessage!, isError: false),
        ],
        if (controller.errorMessage != null && showRetry) ...[
          const SizedBox(height: 16),
          _PolicyBanner(message: controller.errorMessage!, isError: true),
        ],
        if (controller.hasUnsupportedRequiredPolicy) ...[
          const SizedBox(height: 16),
          const _PolicyBanner(
            message: 'A required policy type is not supported by this app version. Please update the app or contact support.',
            isError: true,
          ),
        ],
        const SizedBox(height: 20),
        if (items.isEmpty)
          const _NoPublishedPolicyView()
        else
          ...items.map((item) => _buildPolicyCard(context, item)),
        if (showRetry) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                controller.isBusy ||
                    (state == PolicyViewState.rateLimited &&
                        !controller.canRetryRateLimit)
                ? null
                : () => controller.retry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh policies'),
          ),
        ],
      ],
    );
  }

  Widget _buildPolicyCard(BuildContext context, PolicyConsentItem item) {
    final type = item.type!;
    final document = controller.documentFor(type);
    final version = item.currentVersion;
    final documentIsStale =
        document != null &&
        (controller.isDocumentStale(type) ||
            document.version.version != version);
    final isConfirmed = version != null && _confirmedVersions[type] == version;
    final isAccepted = item.accepted && item.acceptedVersion == version;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.policy_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (version == null)
              Text(
                'No published version is currently available.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else if (document == null)
              Text(
                'The current version could not be loaded. Refresh to try again.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else ...[
              if (documentIsStale) ...[
                _PolicyBanner(
                  message: 'This displayed policy may be stale. Refresh before accepting it.',
                  isError: true,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Version ${document.version.version} • ${_formatDate(context, document.version.publishedAt)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (document.version.changeSummary != null) ...[
                const SizedBox(height: 10),
                Text(
                  document.version.changeSummary!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 14),
              SelectableText(
                document.version.content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              if (isAccepted)
                _AcceptedPolicyLabel(item: item, version: version)
              else if (item.required && !documentIsStale) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isConfirmed,
                  onChanged: controller.state == PolicyViewState.accepting
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              _confirmedVersions[type] = version;
                            } else {
                              _confirmedVersions.remove(type);
                            }
                          });
                        },
                  title: Text(
                    'I have read and agree to the current ${item.label}, version $version.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: !isConfirmed || controller.isBusy
                      ? null
                      : () => _accept(type),
                  child: Text(
                    controller.state == PolicyViewState.accepting
                        ? 'Saving…'
                        : 'Accept ${item.label}',
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openHistory(type),
                icon: const Icon(Icons.history),
                label: const Text('View published history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class PolicyVersionScreen extends StatelessWidget {
  const PolicyVersionScreen({required this.document, super.key});

  final PolicyDocument document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${document.label} v${document.version.version}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Historical version',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${document.version.version} • ${_formatDate(context, document.version.publishedAt)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (document.version.changeSummary != null) ...[
            const SizedBox(height: 14),
            Text(document.version.changeSummary!),
          ],
          const SizedBox(height: 20),
          SelectableText(
            document.version.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PolicyLoadingView extends StatelessWidget {
  const _PolicyLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Loading policy and consent information',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _PolicyStateView extends StatelessWidget {
  const _PolicyStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPublishedPolicyView extends StatelessWidget {
  const _NoPublishedPolicyView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'No published policy version is available',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'There is no published policy version to display right now.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _AcceptedPolicyLabel extends StatelessWidget {
  const _AcceptedPolicyLabel({required this.item, required this.version});

  final PolicyConsentItem item;
  final int? version;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${item.label} version $version is accepted',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Accepted version $version${item.acceptedAt == null ? '' : ' on ${_formatDate(context, item.acceptedAt)}'}.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyBanner extends StatelessWidget {
  const _PolicyBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError
                ? scheme.onErrorContainer
                : scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return 'time unavailable';
  }
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date, $time';
}

String _statusLabel(String status) {
  return switch (status) {
    'published' => 'Published',
    'superseded' => 'Superseded',
    _ => 'Unavailable',
  };
}
