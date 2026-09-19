import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/networking/api_client.dart';
import '../core/security/token_storage.dart';
import '../features/account/data/account_repository.dart';
import '../features/account/presentation/controllers/account_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/delivery/data/delivery_repository.dart';
import '../features/delivery/presentation/controllers/delivery_controller.dart';
import '../features/history/data/history_repository.dart';
import '../features/history/presentation/history_controller.dart';
import '../features/policy/data/policy_repository.dart';
import '../features/policy/presentation/policy_controller.dart';
import '../features/pickup/data/pickup_repository.dart';
import '../features/pickup/presentation/pickup_controller.dart';
import '../features/vehicle/data/vehicle_repository.dart';
import '../features/vehicle/presentation/vehicle_controller.dart';
import 'courier_app.dart';

class CourierBootstrapApp extends StatefulWidget {
  const CourierBootstrapApp({super.key});

  @override
  State<CourierBootstrapApp> createState() => _CourierBootstrapAppState();
}

class _CourierBootstrapAppState extends State<CourierBootstrapApp> {
  AuthController? _authController;
  AccountController? _accountController;
  PolicyController? _policyController;
  PickupController? _pickupController;
  DeliveryController? _deliveryController;
  HistoryController? _historyController;
  VehicleController? _vehicleController;
  bool _hasStartupError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _hasStartupError = false;
      });
    }

    try {
      final config = await AppConfig.load().timeout(
        const Duration(seconds: 5),
        onTimeout: () => AppConfig.fromEnvironment,
      );
      final tokenStorage = SecureTokenStorage();
      final apiClient = ApiClient(config: config, tokenStorage: tokenStorage);
      late final AccountController accountController;
      late final PolicyController policyController;
      late final PickupController pickupController;
      late final DeliveryController deliveryController;
      late final HistoryController historyController;
      late final VehicleController vehicleController;
      final authController = AuthController(
        authRepository: ApiAuthRepository(
          client: apiClient,
          tokenStorage: tokenStorage,
        ),
        dashboardRepository: ApiDashboardRepository(client: apiClient),
        onSessionEnded: () {
          accountController.clear();
          policyController.clear();
          pickupController.clear();
          deliveryController.clear();
          historyController.clear();
          vehicleController.clear();
        },
      );
      accountController = AccountController(
        accountRepository: ApiAccountRepository(client: apiClient),
        onAuthFailure: authController.handleAccountAuthFailure,
        onPasswordChanged: authController.handlePasswordChanged,
        onAccountUpdated: authController.updateIdentityFromAccount,
      );
      policyController = PolicyController(
        policyApi: ApiPolicyRepository(client: apiClient),
        onAuthFailure: authController.handlePolicyAuthFailure,
      );
      pickupController = PickupController(
        pickupRepository: ApiPickupRepository(client: apiClient),
        onAuthFailure: authController.handlePickupAuthFailure,
      );
      deliveryController = DeliveryController(
        deliveryRepository: ApiDeliveryRepository(client: apiClient),
        onAuthFailure: authController.handleDeliveryAuthFailure,
      );
      historyController = HistoryController(
        historyRepository: ApiHistoryRepository(client: apiClient),
        onAuthFailure: authController.handleHistoryAuthFailure,
      );
      vehicleController = VehicleController(
        vehicleRepository: ApiVehicleRepository(client: apiClient),
        onAuthFailure: authController.handleVehicleAuthFailure,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _authController = authController;
        _accountController = accountController;
        _policyController = policyController;
        _pickupController = pickupController;
        _deliveryController = deliveryController;
        _historyController = historyController;
        _vehicleController = vehicleController;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(authController.initialize());
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasStartupError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = _authController;
    if (authController != null) {
      return CourierApp(
        authController: authController,
        accountController: _accountController,
        policyController: _policyController,
        pickupController: _pickupController,
        deliveryController: _deliveryController,
        historyController: _historyController,
        vehicleController: _vehicleController,
      );
    }

    return MaterialApp(
      title: 'Aisley Courier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE6007A)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _hasStartupError
                  ? _StartupError(onRetry: _bootstrap)
                  : const _StartupLoading(),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Starting Aisley Courier',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Starting Aisley Courier…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 16),
        Text(
          'The app could not start safely.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
