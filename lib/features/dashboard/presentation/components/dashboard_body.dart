part of '../dashboard_screen.dart';

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
