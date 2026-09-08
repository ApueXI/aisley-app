import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/courier_app.dart';
import 'core/config/app_config.dart';
import 'core/networking/api_client.dart';
import 'core/security/token_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/dashboard/data/dashboard_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = SecureTokenStorage();
  final apiClient = ApiClient(
    config: AppConfig.fromEnvironment,
    tokenStorage: tokenStorage,
  );
  final authController = AuthController(
    authRepository: ApiAuthRepository(
      client: apiClient,
      tokenStorage: tokenStorage,
    ),
    dashboardRepository: ApiDashboardRepository(client: apiClient),
  );

  runApp(CourierApp(authController: authController));
  unawaited(authController.initialize());
}
