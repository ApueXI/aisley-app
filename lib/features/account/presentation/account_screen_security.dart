part of 'account_screen.dart';

extension _AccountScreenSecurity on _AccountScreenState {
  Future<void> _changePassword() async {
    if (widget.accountController.isBusy ||
        !_passwordFormKey.currentState!.validate()) {
      return;
    }

    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change password?'),
          content: const Text(
            'Changing your password signs you out on every device. You will need to sign in again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Change password'),
            ),
          ],
        );
      },
    );

    if (shouldChange != true || !mounted) {
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;
    _clearPasswordFields();
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      await widget.accountController.changePassword(
        currentPassword: currentPassword,
        password: newPassword,
        passwordConfirmation: passwordConfirmation,
      );
    } finally {
      // Keep password values out of the form after every server attempt.
      _clearPasswordFields();
    }

    if (mounted) {
      await _closeIfSessionEnded();
    }
  }

  void _clearPasswordFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _passwordConfirmationController.clear();
  }

  Widget _buildSecuritySection(BuildContext context) {
    final controller = widget.accountController;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Changing your password revokes all current sessions.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Form(
          key: _passwordFormKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _PasswordField(
                    controller: _currentPasswordController,
                    enabled: !controller.isBusy,
                    label: 'Current password',
                    obscureText: _obscureCurrentPassword,
                    onToggle: () {
                      _updateState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                    serverError: controller.fieldError('current_password'),
                  ),
                  const SizedBox(height: 14),
                  _PasswordField(
                    controller: _newPasswordController,
                    enabled: !controller.isBusy,
                    label: 'New password',
                    obscureText: _obscureNewPassword,
                    onToggle: () {
                      _updateState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                    serverError: controller.fieldError('password'),
                  ),
                  const SizedBox(height: 14),
                  _PasswordField(
                    controller: _passwordConfirmationController,
                    enabled: !controller.isBusy,
                    label: 'Confirm new password',
                    obscureText: _obscurePasswordConfirmation,
                    onToggle: () {
                      _updateState(() {
                        _obscurePasswordConfirmation =
                            !_obscurePasswordConfirmation;
                      });
                    },
                    serverError: controller.fieldError('password_confirmation'),
                    validator: (value) {
                      final requiredError = _required(value, 'confirmation');
                      if (requiredError != null) {
                        return requiredError;
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    button: true,
                    label: controller.status == AccountStatus.changingPassword
                        ? 'Changing password'
                        : 'Change password',
                    child: OutlinedButton.icon(
                      onPressed: controller.isBusy ? null : _changePassword,
                      icon: controller.status == AccountStatus.changingPassword
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_outlined),
                      label: Text(
                        controller.status == AccountStatus.changingPassword
                            ? 'Changing…'
                            : 'Change password',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
