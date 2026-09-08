import 'package:flutter/material.dart';

import 'auth_controller.dart';

class BlockedAccessScreen extends StatelessWidget {
  const BlockedAccessScreen({
    required this.authController,
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  const BlockedAccessScreen.pending({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Application pending',
         message: 'The selected Logistics organization still needs to review your Courier application.',
         icon: Icons.hourglass_top_rounded,
         key: key,
       );

  const BlockedAccessScreen.rejected({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Application not approved',
         message: 'Courier access is unavailable for this application. Review details are not shown here.',
         icon: Icons.info_outline_rounded,
         key: key,
       );

  const BlockedAccessScreen.suspended({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Access unavailable',
         message: 'Your Courier account is suspended or inactive. Contact your Logistics organization for help.',
         icon: Icons.lock_outline_rounded,
         key: key,
       );

  const BlockedAccessScreen.affiliation({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Logistics affiliation unavailable',
         message: 'Your Courier affiliation is not currently valid, so operational access is blocked.',
         icon: Icons.domain_disabled_outlined,
         key: key,
       );

  final AuthController authController;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _StatusMessageScreen(
      icon: icon,
      title: title,
      message: message,
      actionLabel: 'Return to sign in',
      onAction: authController.returnToSignIn,
    );
  }
}

class RetrySessionScreen extends StatelessWidget {
  const RetrySessionScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return _StatusMessageScreen(
      icon: Icons.cloud_off_outlined,
      title: 'Connection unavailable',
      message: authController.errorMessage ?? 'We could not check your Courier session. Your access was not changed.',
      actionLabel: 'Retry',
      onAction: authController.retry,
    );
  }
}

class SecureStorageFailureScreen extends StatelessWidget {
  const SecureStorageFailureScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final platformHint = Theme.of(context).platform == TargetPlatform.linux
        ? ' On Linux, unlock the default Secret Service keyring and try again.'
        : '';
    return _StatusMessageScreen(
      icon: Icons.security_outlined,
      title: 'Secure session storage unavailable',
      message:
          '${authController.errorMessage ?? 'The app cannot safely read or update your session on this device.'}$platformHint',
      actionLabel: 'Try again',
      onAction: authController.retry,
    );
  }
}

class _StatusMessageScreen extends StatelessWidget {
  const _StatusMessageScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
