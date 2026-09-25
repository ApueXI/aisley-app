part of '../dashboard_screen.dart';

mixin _DashboardNavigation on State<DashboardScreen> {
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
          vehicleController: widget.vehicleController,
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
          chatController: widget.chatController,
        ),
      ),
    );
    if (mounted && widget.authController.status == AuthStatus.authenticated) {
      unawaited(
        widget.dashboardPreviewController?.refreshFirstMile() ??
            Future<void>.value(),
      );
    }
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
          chatController: widget.chatController,
        ),
      ),
    );
    if (mounted && widget.authController.status == AuthStatus.authenticated) {
      unawaited(
        widget.dashboardPreviewController?.refreshFinalMile() ??
            Future<void>.value(),
      );
    }
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

  Future<void> _openNotifications() async {
    final notificationController = widget.notificationController;
    if (notificationController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationScreen(
          controller: notificationController,
          managePolling: false,
          onOpenTarget: _openNotificationTarget,
        ),
      ),
    );
    if (mounted) {
      notificationController.startPolling();
    }
  }

  Future<void> _openNotificationTarget(CourierNotification notification) async {
    switch (notification.resourceType) {
      case 'pickup_schedule':
        await _openPickups();
      case 'delivery_task':
      case 'final_mile_task':
        await _openDeliveries();
      default:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The related work type is not available in this app yet.',
              ),
            ),
          );
        }
    }
  }

  Future<void> _openMessages() async {
    final chatController = widget.chatController;
    if (chatController == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatInboxScreen(
          controller: chatController,
          authController: widget.authController,
        ),
      ),
    );
  }
}
