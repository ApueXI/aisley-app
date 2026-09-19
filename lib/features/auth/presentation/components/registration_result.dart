part of '../registration_screen.dart';

extension _RegistrationResult on _RegistrationScreenState {
  Widget _buildSubmitted(BuildContext context, RegistrationResult result) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Semantics(
                liveRegion: true,
                label: 'Courier registration submitted for approval',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 64,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Application submitted',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(result.message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                      'Your application is pending approval from the selected Logistics organization. Registration did not create a session, so you can sign in after approval.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: widget.onSignIn,
                      child: const Text('Return to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _required(String? value, String message) {
  if (value == null || value.trim().isEmpty) {
    return message;
  }
  return null;
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Enter your email.';
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String _formatDisplayDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _fileName(XFile file) {
  final name = file.name.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final pieces = file.path.split(RegExp(r'[/\\]+'));
  return pieces.isEmpty ? 'selected image' : pieces.last;
}

bool _hasSupportedImageSignature(List<int> bytes) {
  final isJpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final isPng =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  final isWebp =
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
  return isJpeg || isPng || isWebp;
}

String _formatFileSize(int bytes) {
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';
}

String _messageForOptionsError(ApiException error) {
  if (error.statusCode == 429) {
    return 'Too many organization requests. Please wait and retry.';
  }
  if (error.isNetworkError) {
    return 'Could not load active Logistics organizations. Check your connection and retry.';
  }
  return 'Active Logistics organizations could not be loaded. Please retry.';
}

String _messageForRegistrationError(ApiException error) {
  if (error.code == 'EMAIL_ALREADY_REGISTERED') {
    return 'This email is already registered for a Courier account. Use a different email or sign in instead.';
  }
  if (error.statusCode == 429) {
    final retryAfter = error.retryAfter;
    if (retryAfter != null && retryAfter.inSeconds > 0) {
      return 'Too many registration attempts. Try again in ${retryAfter.inSeconds} seconds.';
    }
    return 'Too many registration attempts. Please wait before trying again.';
  }
  if (error.isNetworkError) {
    return 'Could not reach the service. Your form is preserved; retry only when you are ready.';
  }
  if (error.statusCode == 422) {
    final message = error.message.trim();
    final isGeneric =
        message.isEmpty ||
        message.toLowerCase() == 'the given data was invalid.' ||
        message.toLowerCase() == 'the submitted data is invalid.';
    return isGeneric
        ? error.fieldErrors.isEmpty
              ? 'The server rejected the registration without identifying a field. Verify the organization, address, vehicle details, and both documents, then retry. If this repeats, check the API response for the validation cause.'
              : 'The server rejected some registration details. Review the highlighted fields below and correct them before submitting again.'
        : message;
  }
  if (error.statusCode == 409) {
    return 'This registration conflicts with an existing application. Check the email and selected Logistics organization, then retry.';
  }
  if (error.statusCode == 404) {
    return 'The selected Logistics organization is no longer available. Return to the organization field, choose an available option, and retry.';
  }
  if (error.statusCode != null && error.statusCode! >= 500) {
    return 'The registration service returned a server error (HTTP ${error.statusCode}, ${error.code}). This is not a missing-field error. Retry once; if it continues, check the API log for this status and code.';
  }
  if (error.statusCode != null) {
    return 'The registration service rejected the request (HTTP ${error.statusCode}, ${error.code}). This does not confirm that the Logistics organization or documents are missing. Retry, then check the API response if it continues.';
  }
  return 'Registration could not be submitted. Your form is preserved; retry when the service is available.';
}

class _RegistrationErrorBanner extends StatelessWidget {
  const _RegistrationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Registration error: $message',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationFieldErrorSummary extends StatelessWidget {
  const _RegistrationFieldErrorSummary({required this.errors});

  final Map<String, List<String>> errors;

  @override
  Widget build(BuildContext context) {
    final visibleErrors = errors.entries
        .where(
          (entry) => entry.value.any((message) => message.trim().isNotEmpty),
        )
        .toList(growable: false);
    if (visibleErrors.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Registration fields with errors',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review these fields:',
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in visibleErrors)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${_registrationFieldLabel(entry.key)}: ${entry.value.where((message) => message.trim().isNotEmpty).join(' ')}',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _registrationFieldLabel(String key) {
  final normalized = key.replaceAll('[', '.').replaceAll(']', '');
  return switch (normalized) {
    'first_name' => 'First name',
    'last_name' => 'Last name',
    'middle_name' => 'Middle initial',
    'contact_number' => 'Contact number',
    'birth_date' => 'Birth date',
    'email' => 'Email',
    'password' => 'Password',
    'password_confirmation' => 'Confirm password',
    'sex' => 'Sex',
    'logistics_organization_id' => 'Logistics organization',
    'address.address_line_1' => 'Street / house detail',
    'address.address_line_2' => 'Address line 2',
    'address.barangay' => 'Barangay',
    'address.city_municipality' => 'City / municipality',
    'address.province' => 'Province',
    'address.region' => 'Region',
    'address.postal_code' => 'Postal code',
    'vehicle_type' => 'Vehicle type',
    'plate_number' => 'Plate number',
    'government_id' => 'Government ID / driver’s license',
    'vehicle_registration' => 'Vehicle registration (OR/CR)',
    _ =>
      key
          .replaceAll(RegExp(r'[._\[\]]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
  };
}
