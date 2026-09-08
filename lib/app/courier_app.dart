import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/blocked_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/registration_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

class CourierApp extends StatelessWidget {
  const CourierApp({required this.authController, super.key});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aisley Courier',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: AuthGate(authController: authController),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({required this.authController, super.key});

  final AuthController authController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showRegistration = false;

  @override
  Widget build(BuildContext context) {
    final authController = widget.authController;
    return AnimatedBuilder(
      animation: authController,
      builder: (context, child) {
        return switch (authController.status) {
          AuthStatus.checkingSession => const CheckingSessionScreen(
            key: ValueKey('checking-session'),
          ),
          AuthStatus.signedOut || AuthStatus.authenticating =>
            _showRegistration
                ? RegistrationScreen(
                    key: const ValueKey('registration'),
                    authController: authController,
                    onSignIn: _showSignIn,
                  )
                : LoginScreen(
                    key: const ValueKey('login'),
                    authController: authController,
                    onRegister: _showRegistrationScreen,
                  ),
          AuthStatus.authenticated => DashboardScreen(
            key: const ValueKey('dashboard'),
            authController: authController,
          ),
          AuthStatus.pendingApproval => BlockedAccessScreen.pending(
            key: const ValueKey('pending-approval'),
            authController: authController,
          ),
          AuthStatus.rejected => BlockedAccessScreen.rejected(
            key: const ValueKey('rejected'),
            authController: authController,
          ),
          AuthStatus.suspendedOrDeactivated => BlockedAccessScreen.suspended(
            key: const ValueKey('suspended'),
            authController: authController,
          ),
          AuthStatus.invalidAffiliation => BlockedAccessScreen.affiliation(
            key: const ValueKey('invalid-affiliation'),
            authController: authController,
          ),
          AuthStatus.recoverableNetworkFailure => RetrySessionScreen(
            key: const ValueKey('network-retry'),
            authController: authController,
          ),
          AuthStatus.secureStorageFailure => SecureStorageFailureScreen(
            key: const ValueKey('secure-storage-failure'),
            authController: authController,
          ),
        };
      },
    );
  }

  void _showRegistrationScreen() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showRegistration = true;
    });
  }

  void _showSignIn() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showRegistration = false;
    });
  }
}

class CheckingSessionScreen extends StatelessWidget {
  const CheckingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Checking your Courier session',
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
                  'Checking your Courier session…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const primary = Color(0xFFE6007A);
  const deepPurple = Color(0xFF4C1268);
  const error = Color(0xFFFF3B30);
  const warning = Color(0xFFFF8800);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(primary: primary, secondary: deepPurple, error: error);

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF9F7FA)
        : const Color(0xFF151117),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF211B23),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: deepPurple,
      contentTextStyle: TextStyle(color: scheme.onPrimary),
    ),
    extensions: <ThemeExtension<dynamic>>[
      const _CourierTheme(warning: warning),
    ],
  );
}

class _CourierTheme extends ThemeExtension<_CourierTheme> {
  const _CourierTheme({required this.warning});

  final Color warning;

  @override
  _CourierTheme copyWith({Color? warning}) {
    return _CourierTheme(warning: warning ?? this.warning);
  }

  @override
  _CourierTheme lerp(ThemeExtension<_CourierTheme>? other, double t) {
    if (other is! _CourierTheme) {
      return this;
    }
    return _CourierTheme(
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}
