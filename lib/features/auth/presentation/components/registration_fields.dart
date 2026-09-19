part of '../registration_screen.dart';

extension _RegistrationFields on _RegistrationScreenState {
  Widget _sectionHeading(
    BuildContext context,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _twoColumn(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 14), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
    String? serverKey,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSubmitting,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: _decoration(
        label,
        hint: hint,
        icon: icon,
        errorText: serverKey == null ? null : _serverError(serverKey),
      ),
      validator: validator,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String serverKey,
    bool confirmation = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSubmitting,
      obscureText: true,
      autofillHints: confirmation
          ? const <String>[AutofillHints.password]
          : const <String>[AutofillHints.newPassword],
      decoration: _decoration(
        label,
        icon: Icons.lock_outline,
        errorText: _serverError(serverKey),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return confirmation ? 'Confirm your password.' : 'Enter a password.';
        }
        if (!confirmation) {
          if (value.length < 8 ||
              !RegExp(r'[A-Z]').hasMatch(value) ||
              !RegExp(r'[a-z]').hasMatch(value) ||
              !RegExp(r'[0-9]').hasMatch(value)) {
            return 'Use 8+ characters with upper, lower, and a number.';
          }
        } else if (value != _passwordController.text) {
          return 'Passwords do not match.';
        }
        return null;
      },
    );
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    IconData? icon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      errorText: errorText,
    );
  }

  String? _serverError(String key) {
    final keys = <String>[key];
    if (key.startsWith('address.')) {
      final addressKey = key.substring('address.'.length);
      keys.add('address[$addressKey]');
      keys.add(addressKey);
    }
    for (final candidate in keys) {
      final messages = _fieldErrors[candidate];
      if (messages != null && messages.isNotEmpty) {
        return messages.first;
      }
    }
    return null;
  }
}
