import 'dart:async';

import 'package:flutter/material.dart';

import '../../account/domain/account_models.dart';
import '../../account/presentation/account_controller.dart';
import '../../account/presentation/account_screen.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../delivery/presentation/delivery_controller.dart';
import '../../delivery/presentation/delivery_screen.dart';
import '../../history/presentation/history_controller.dart';
import '../../history/presentation/history_screen.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../pickup/presentation/pickup_controller.dart';
import '../../pickup/presentation/pickup_screen.dart';
import '../domain/dashboard_models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.authController,
    this.accountController,
    this.policyController,
    this.pickupController,
    this.deliveryController,
    this.historyController,
    super.key,
  });

  final AuthController authController;
  final AccountController? accountController;
  final PolicyController? policyController;
  final PickupController? pickupController;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.authController.loadDashboard();
        final accountController = widget.accountController;
        if (accountController != null && accountController.account == null) {
          unawaited(accountController.loadAccount());
        }
      }
    });
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to view your Courier dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !mounted) {
      return;
    }

    final didSignOut = await widget.authController.signOut();
    if (!mounted || didSignOut) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign out could not be completed. Your session remains active.',
        ),
      ),
    );
  }

  Future<void> _openAccount() async {
    final accountController = widget.accountController;
    if (accountController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountScreen(
          authController: widget.authController,
          accountController: accountController,
          policyController: widget.policyController,
        ),
      ),
    );
  }

  Future<void> _openPickups() async {
    final pickupController = widget.pickupController;
    if (pickupController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PickupScreen(
          authController: widget.authController,
          pickupController: pickupController,
          policyController: widget.policyController,
          onOpenDelivery: _openDeliveries,
        ),
      ),
    );
  }

  Future<void> _openDeliveries() async {
    final deliveryController = widget.deliveryController;
    if (deliveryController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryScreen(
          authController: widget.authController,
          deliveryController: deliveryController,
          policyController: widget.policyController,
          onOpenPickup: _openPickups,
        ),
      ),
    );
  }

  Future<void> _openHistory() async {
    final historyController = widget.historyController;
    if (historyController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          authController: widget.authController,
          historyController: historyController,
          policyController: widget.policyController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, child) {
        final courier = widget.authController.courier;
        if (courier == null) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Courier dashboard'),
            actions: [
              if (widget.pickupController != null ||
                  widget.deliveryController != null ||
                  widget.historyController != null)
                PopupMenuButton<String>(
                  tooltip: 'Courier work',
                  icon: const Icon(Icons.local_shipping_outlined),
                  onSelected: (value) {
                    switch (value) {
                      case 'pickup':
                        _openPickups();
                      case 'delivery':
                        _openDeliveries();
                      case 'history':
                        _openHistory();
                    }
                  },
                  itemBuilder: (context) => [
                    if (widget.pickupController != null)
                      const PopupMenuItem<String>(
                        value: 'pickup',
                        child: Text('Pickup orders'),
                      ),
                    if (widget.deliveryController != null)
                      const PopupMenuItem<String>(
                        value: 'delivery',
                        child: Text('Delivery work'),
                      ),
                    if (widget.historyController != null)
                      const PopupMenuItem<String>(
                        value: 'history',
                        child: Text('Delivery history'),
                      ),
                  ],
                ),
              if (widget.accountController != null)
                IconButton(
                  onPressed: _openAccount,
                  tooltip: 'Account settings',
                  icon: const Icon(Icons.manage_accounts_outlined),
                ),
              IconButton(
                onPressed: widget.authController.isSigningOut
                    ? null
                    : _confirmSignOut,
                tooltip: 'Sign out',
                icon: widget.authController.isSigningOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: widget.authController.loadDashboard,
            child: widget.accountController == null
                ? _DashboardBody(
                    authController: widget.authController,
                    onSignOut: _confirmSignOut,
                    pickupController: widget.pickupController,
                    onOpenPickups: _openPickups,
                    deliveryController: widget.deliveryController,
                    historyController: widget.historyController,
                    onOpenDeliveries: _openDeliveries,
                    onOpenHistory: _openHistory,
                  )
                : AnimatedBuilder(
                    animation: widget.accountController!,
                    builder: (context, child) => _DashboardBody(
                      authController: widget.authController,
                      onSignOut: _confirmSignOut,
                      pickupController: widget.pickupController,
                      onOpenPickups: _openPickups,
                      deliveryController: widget.deliveryController,
                      historyController: widget.historyController,
                      onOpenDeliveries: _openDeliveries,
                      onOpenHistory: _openHistory,
                      profilePhoto: widget.accountController!.profilePhoto,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.authController,
    required this.onSignOut,
    this.pickupController,
    required this.onOpenPickups,
    this.deliveryController,
    this.historyController,
    required this.onOpenDeliveries,
    required this.onOpenHistory,
    this.profilePhoto,
  });

  final AuthController authController;
  final VoidCallback onSignOut;
  final PickupController? pickupController;
  final VoidCallback onOpenPickups;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;
  final VoidCallback onOpenDeliveries;
  final VoidCallback onOpenHistory;
  final ProfilePhotoData? profilePhoto;

  @override
  Widget build(BuildContext context) {
    final courier = authController.courier!;
    final isLoading =
        authController.dashboardStatus == DashboardLoadStatus.loading;
    final snapshot = authController.dashboard;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _WelcomeCard(courier: courier, profilePhoto: profilePhoto),
        const SizedBox(height: 24),
        Text(
          'Your work',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Operational delivery data will appear here when it is available.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (authController.dashboardErrorMessage != null)
          _DashboardErrorBanner(
            message: authController.dashboardErrorMessage!,
            onRetry: authController.loadDashboard,
          ),
        if (authController.dashboardErrorMessage != null)
          const SizedBox(height: 16),
        if (isLoading && snapshot == null) ...[
          const _SkeletonSectionCard(),
          const SizedBox(height: 12),
          const _SkeletonSectionCard(),
          const SizedBox(height: 12),
          const _SkeletonSectionCard(),
        ] else ...[
          _DashboardSectionCard(
            title: 'Notifications',
            subtitle: 'Updates about your Courier work',
            icon: Icons.notifications_none_rounded,
            section: snapshot?.section('notifications'),
          ),
          const SizedBox(height: 12),
          _DashboardSectionCard(
            title: 'Available work',
            subtitle: 'Pickup and delivery requests offered to you',
            icon: Icons.assignment_outlined,
            section: snapshot?.section('available_tasks'),
          ),
          const SizedBox(height: 12),
          _DashboardSectionCard(
            title: 'Active work',
            subtitle: 'Accepted Courier work in progress',
            icon: Icons.local_shipping_outlined,
            section: snapshot?.section('active_tasks'),
          ),
        ],
        const SizedBox(height: 20),
        _UnavailableNotice(
          freshness: snapshot?.freshness,
          isLoading: isLoading,
        ),
        const SizedBox(height: 20),
        if (pickupController != null) ...[
          OutlinedButton.icon(
            onPressed: onOpenPickups,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Open pickup orders'),
          ),
          const SizedBox(height: 12),
        ],
        if (deliveryController != null) ...[
          OutlinedButton.icon(
            onPressed: onOpenDeliveries,
            icon: const Icon(Icons.route_outlined),
            label: const Text('Open delivery work'),
          ),
          const SizedBox(height: 12),
        ],
        if (historyController != null) ...[
          OutlinedButton.icon(
            onPressed: onOpenHistory,
            icon: const Icon(Icons.history_outlined),
            label: const Text('View delivery history'),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: isLoading ? null : authController.loadDashboard,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh dashboard'),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onSignOut, child: const Text('Sign out')),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.courier, this.profilePhoto});

  final CourierIdentity courier;
  final ProfilePhotoData? profilePhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final organization = courier.organizationName;
    final hub = courier.hubName;
    final affiliation = [?organization, ?hub].join(' • ');
    final photoBytes = profilePhoto?.bytes;

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
              child: photoBytes == null || photoBytes.isEmpty
                  ? Text(
                      _initials(courier.displayName),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : ClipOval(
                      child: Image.memory(
                        photoBytes,
                        key: const ValueKey<String>('dashboard-profile-photo'),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        semanticLabel: '${courier.displayName} profile photo',
                        errorBuilder: (context, error, stackTrace) => Text(
                          _initials(courier.displayName),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good to see you,',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    courier.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (affiliation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      affiliation,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSectionCard extends StatelessWidget {
  const _DashboardSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.section,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final DashboardSection? section;

  @override
  Widget build(BuildContext context) {
    final resolvedSection =
        section ?? const DashboardSection(state: DashboardSectionState.unknown);
    final stateLabel = _stateLabel(resolvedSection);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '$title. $stateLabel',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _StatusPill(label: stateLabel),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.freshness, required this.isLoading});

  final DashboardFreshness? freshness;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isScaffold = freshness?.state == DashboardFreshnessState.scaffold;
    final text = isLoading
        ? 'Refreshing from the server…'
        : isScaffold
        ? 'Operational delivery data is not available yet. This dashboard is ready for the approved Courier task contract.'
        : 'This dashboard only shows data confirmed by the server.';

    return Semantics(
      liveRegion: true,
      container: true,
      label: text,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardErrorBanner extends StatelessWidget {
  const _DashboardErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: scheme.onErrorContainer)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onRetry,
                    child: Text(
                      'Retry',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonSectionCard extends StatelessWidget {
  const _SkeletonSectionCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 130,
                    height: 16,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(DashboardSection section) {
  return switch (section.state) {
    DashboardSectionState.available =>
      section.items.isEmpty ? 'No items available' : 'Available',
    DashboardSectionState.empty => 'Nothing to show',
    DashboardSectionState.unavailable => 'Unavailable in this build',
    DashboardSectionState.stale => 'Needs refresh',
    DashboardSectionState.failed => 'Could not load',
    DashboardSectionState.unknown => 'Unavailable',
  };
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
