import 'dart:async';

import 'package:flutter/material.dart';

import '../../account/domain/account_models.dart';
import '../../account/presentation/controllers/account_controller.dart';
import '../../account/presentation/account_screen.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../delivery/presentation/delivery_controller.dart';
import '../../delivery/presentation/delivery_screen.dart';
import '../../history/presentation/history_controller.dart';
import '../../history/presentation/history_screen.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../pickup/presentation/pickup_controller.dart';
import '../../pickup/presentation/pickup_screen.dart';
import '../../vehicle/presentation/vehicle_controller.dart';
import '../domain/dashboard_models.dart';

part 'components/dashboard_body.dart';
part 'components/dashboard_cards.dart';
part 'components/dashboard_status.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.authController,
    this.accountController,
    this.policyController,
    this.pickupController,
    this.deliveryController,
    this.historyController,
    this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final AccountController? accountController;
  final PolicyController? policyController;
  final PickupController? pickupController;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;
  final VehicleController? vehicleController;

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
