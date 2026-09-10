import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/account_models.dart';
import 'account_controller.dart';

const _maxProfilePhotoBytes = 10 * 1024 * 1024;
const _profilePhotoTypeGroup = XTypeGroup(
  label: 'Profile photos',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
);

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.authController,
    required this.accountController,
    this.policyController,
    super.key,
  });

  final AuthController authController;
  final AccountController accountController;
  final PolicyController? policyController;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _hasPopulatedProfile = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscurePasswordConfirmation = true;
  ProfilePhotoSelection? _pendingProfilePhoto;
  String? _profilePhotoSelectionError;
  bool _isPickingProfilePhoto = false;
  VoidCallback? _cancelProfilePhotoUpload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAccount();
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _contactNumberController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    await widget.accountController.loadAccount();
    if (!mounted) {
      return;
    }
    final account = widget.accountController.account;
    if (account != null && !_hasPopulatedProfile) {
      _populateProfile(account);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _refreshAccount() async {
    final hadLocalEdits = _profileHasLocalEdits();
    await widget.accountController.loadAccount();
    if (!mounted) {
      return;
    }
    final account = widget.accountController.account;
    if (account != null && !hadLocalEdits) {
      _populateProfile(account);
    }
    await _closeIfSessionEnded();
  }

  void _populateProfile(CourierAccount account) {
    final profile = account.profile;
    _firstNameController.text = profile.firstName;
    _middleNameController.text = profile.middleName ?? '';
    _lastNameController.text = profile.lastName;
    _contactNumberController.text = profile.contactNumber;
    _hasPopulatedProfile = true;
  }

  bool _profileHasLocalEdits() {
    final account = widget.accountController.account;
    if (account == null || !_hasPopulatedProfile) {
      return false;
    }

    final profile = account.profile;
    return _firstNameController.text.trim() != profile.firstName ||
        _middleNameController.text.trim() != (profile.middleName ?? '') ||
        _lastNameController.text.trim() != profile.lastName ||
        _contactNumberController.text.trim() != profile.contactNumber;
  }

  Future<void> _saveProfile() async {
    if (widget.accountController.isBusy ||
        !_profileFormKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await widget.accountController.updateProfile(
      firstName: _firstNameController.text,
      middleName: _middleNameController.text,
      lastName: _lastNameController.text,
      contactNumber: _contactNumberController.text,
    );

    if (!mounted) {
      return;
    }
    final account = widget.accountController.account;
    if (account != null &&
        widget.accountController.status == AccountStatus.loaded) {
      _populateProfile(account);
    }
    await _closeIfSessionEnded();
  }

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

  Future<void> _closeIfSessionEnded() async {
    if (!mounted || widget.authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.accountController,
      builder: (context, child) {
        final account = widget.accountController.account;
        return Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: account == null
              ? _buildAccountState(context)
              : RefreshIndicator(
                  onRefresh: _refreshAccount,
                  child: _buildAccountForm(context, account),
                ),
        );
      },
    );
  }

  Widget _buildAccountState(BuildContext context) {
    final controller = widget.accountController;
    if (controller.status == AccountStatus.loading) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Loading your account',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final message =
        controller.errorMessage ??
        'Your account details are not available right now.';
    final canRetry =
        controller.status != AccountStatus.signedOut &&
        controller.status != AccountStatus.forbidden;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                controller.status == AccountStatus.forbidden
                    ? Icons.lock_outline
                    : Icons.account_circle_outlined,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (canRetry) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: controller.isBusy ? null : _loadAccount,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection(
    BuildContext context,
    CourierAccount account,
  ) {
    final controller = widget.accountController;
    final scheme = Theme.of(context).colorScheme;
    final pendingPhoto = _pendingProfilePhoto;
    final displayedBytes =
        pendingPhoto?.bytes ?? controller.profilePhoto?.bytes;
    final isPhotoBusy = controller.isProfilePhotoBusy;
    final photoError =
        controller.profilePhotoFieldError('photo') ??
        controller.profilePhotoErrorMessage ??
        _profilePhotoSelectionError;
    final canEdit = account.security.profilePhotoEditable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.photo_camera_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile photo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPEG, JPG, PNG, or WebP under 10 MB.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (displayedBytes != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfilePhotoPreview(bytes: displayedBytes),
                  const SizedBox(width: 14),
                  Expanded(
                    child: pendingPhoto == null
                        ? Text(
                            'Current private profile photo',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local preview — upload to save it to your account.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                pendingPhoto.fileName,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                _formatFileSize(pendingPhoto.sizeInBytes),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                  ),
                ],
              )
            else if (controller.profilePhotoStatus ==
                ProfilePhotoStatus.loading)
              Semantics(
                liveRegion: true,
                label: 'Loading your private profile photo',
                child: const LinearProgressIndicator(),
              )
            else
              Text(
                'No profile photo is set.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (controller.profilePhotoStatus ==
                ProfilePhotoStatus.uploading) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label: 'Uploading your profile photo',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 8),
              Text('Uploading…', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (controller.profilePhotoStatus ==
                ProfilePhotoStatus.deleting) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label: 'Removing your profile photo',
                child: const LinearProgressIndicator(),
              ),
            ],
            if (photoError != null) ...[
              const SizedBox(height: 14),
              _AccountBanner(message: photoError, isError: true),
            ],
            if (controller.profilePhotoSuccessMessage != null) ...[
              const SizedBox(height: 14),
              _AccountBanner(
                message: controller.profilePhotoSuccessMessage!,
                isError: false,
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (pendingPhoto != null)
                    FilledButton.icon(
                      onPressed: isPhotoBusy ? null : _uploadProfilePhoto,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Upload photo'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: isPhotoBusy || _isPickingProfilePhoto
                          ? null
                          : _pickProfilePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        displayedBytes == null
                            ? 'Choose photo'
                            : 'Replace photo',
                      ),
                    ),
                  if (pendingPhoto != null)
                    TextButton(
                      onPressed: isPhotoBusy ? null : _discardPendingPhoto,
                      child: const Text('Discard'),
                    ),
                  if (pendingPhoto == null && displayedBytes != null)
                    TextButton.icon(
                      onPressed: isPhotoBusy ? null : _removeProfilePhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  if (pendingPhoto == null &&
                      controller.profilePhotoStatus ==
                          ProfilePhotoStatus.retryableFailure)
                    TextButton.icon(
                      onPressed: isPhotoBusy ? null : _retryProfilePhoto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry photo'),
                    ),
                  if (controller.profilePhotoStatus ==
                          ProfilePhotoStatus.uploading &&
                      _cancelProfilePhotoUpload != null)
                    TextButton.icon(
                      onPressed: _cancelProfilePhotoUploadRequest,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel upload'),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Profile photo changes are not available for this account.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    if (_isPickingProfilePhoto ||
        widget.accountController.isBusy ||
        widget.accountController.account?.security.profilePhotoEditable !=
            true) {
      return;
    }

    setState(() {
      _isPickingProfilePhoto = true;
      _profilePhotoSelectionError = null;
    });

    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_profilePhotoTypeGroup],
      );
      if (file == null) {
        return;
      }

      final fileName = file.name.trim().isEmpty
          ? _fileNameFromPath(file.path)
          : file.name.trim();
      if (!_isAllowedProfilePhotoName(fileName)) {
        _setProfilePhotoSelectionError(
          'Choose a JPEG, JPG, PNG, or WebP image.',
        );
        return;
      }
      if (file.path.trim().isEmpty) {
        _setProfilePhotoSelectionError(
          'The selected photo could not be opened. Choose it again.',
        );
        return;
      }

      final fileSize = await file.length();
      if (fileSize >= _maxProfilePhotoBytes) {
        _setProfilePhotoSelectionError(
          'The photo must be under 10 MB (10,485,760 bytes).',
        );
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length >= _maxProfilePhotoBytes) {
        _setProfilePhotoSelectionError(
          'The photo must be under 10 MB (10,485,760 bytes).',
        );
        return;
      }
      if (!_hasSupportedImageSignature(bytes)) {
        _setProfilePhotoSelectionError(
          'The selected file does not look like a supported image.',
        );
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _pendingProfilePhoto = ProfilePhotoSelection(
          path: file.path,
          fileName: fileName,
          bytes: Uint8List.fromList(bytes),
        );
        _profilePhotoSelectionError = null;
      });
    } catch (_) {
      _setProfilePhotoSelectionError(
        'The photo could not be opened. Choose a supported image and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingProfilePhoto = false;
        });
      }
    }
  }

  void _setProfilePhotoSelectionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _profilePhotoSelectionError = message;
    });
  }

  Future<void> _uploadProfilePhoto() async {
    final selection = _pendingProfilePhoto;
    if (selection == null || widget.accountController.isBusy) {
      return;
    }

    setState(() {
      _cancelProfilePhotoUpload = null;
      _profilePhotoSelectionError = null;
    });

    final uploaded = await widget.accountController.uploadProfilePhoto(
      selection,
      onCancel: (cancel) {
        if (mounted) {
          setState(() {
            _cancelProfilePhotoUpload = cancel;
          });
        }
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _cancelProfilePhotoUpload = null;
      if (uploaded) {
        _pendingProfilePhoto = null;
      }
    });
    await _closeIfSessionEnded();
  }

  void _cancelProfilePhotoUploadRequest() {
    final cancel = _cancelProfilePhotoUpload;
    if (cancel == null) {
      return;
    }
    setState(() {
      _cancelProfilePhotoUpload = null;
    });
    cancel();
  }

  Future<void> _discardPendingPhoto() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard selected photo?'),
          content: const Text('The local preview will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    if (shouldDiscard == true && mounted) {
      setState(() {
        _pendingProfilePhoto = null;
        _profilePhotoSelectionError = null;
      });
    }
  }

  Future<void> _removeProfilePhoto() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove profile photo?'),
          content: const Text(
            'This removes the private photo from your Courier account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove photo'),
            ),
          ],
        );
      },
    );
    if (shouldRemove != true || !mounted) {
      return;
    }

    await widget.accountController.deleteProfilePhoto();
    if (mounted) {
      await _closeIfSessionEnded();
    }
  }

  Future<void> _retryProfilePhoto() async {
    await widget.accountController.loadProfilePhoto();
    if (mounted) {
      await _closeIfSessionEnded();
    }
  }

  Future<void> _openPolicy() async {
    final policyController = widget.policyController;
    if (policyController == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: widget.authController,
          policyController: policyController,
        ),
      ),
    );
  }

  Widget _buildAccountForm(BuildContext context, CourierAccount account) {
    final controller = widget.accountController;
    final scheme = Theme.of(context).colorScheme;
    final isLoading = controller.status == AccountStatus.loading;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        _AccountHeader(
          account: account,
          profilePhotoBytes:
              _pendingProfilePhoto?.bytes ?? controller.profilePhoto?.bytes,
        ),
        if (widget.policyController != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Policy & consent'),
              subtitle: const Text(
                'Read the current Terms of Service and Privacy Policy.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openPolicy,
            ),
          ),
        ],
        if (isLoading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 16),
          _AccountBanner(message: controller.errorMessage!, isError: true),
        ],
        if (controller.successMessage != null) ...[
          const SizedBox(height: 16),
          _AccountBanner(message: controller.successMessage!, isError: false),
        ],
        const SizedBox(height: 20),
        _buildProfilePhotoSection(context, account),
        const SizedBox(height: 24),
        Text(
          'Personal information',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Update only the contact details you are allowed to maintain yourself.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Form(
          key: _profileFormKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    enabled: !controller.isBusy,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'First name',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: controller.fieldError('first_name'),
                    ),
                    validator: (value) => _required(value, 'first name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _middleNameController,
                    enabled: !controller.isBusy,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Middle name',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: controller.fieldError('middle_name'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lastNameController,
                    enabled: !controller.isBusy,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Last name',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: controller.fieldError('last_name'),
                    ),
                    validator: (value) => _required(value, 'last name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contactNumberController,
                    enabled: !controller.isBusy,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Contact number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      errorText: controller.fieldError('contact_number'),
                    ),
                    validator: (value) => _required(value, 'contact number'),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    button: true,
                    label: controller.status == AccountStatus.savingProfile
                        ? 'Saving profile'
                        : 'Save profile',
                    child: FilledButton.icon(
                      onPressed: controller.isBusy ? null : _saveProfile,
                      icon: controller.status == AccountStatus.savingProfile
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        controller.status == AccountStatus.savingProfile
                            ? 'Saving…'
                            : 'Save profile',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Account details',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'These values are supplied by the server and cannot be changed here.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _ReadOnlyRow(label: 'Email', value: account.email),
                _ReadOnlyRow(
                  label: 'Account status',
                  value: _accountStatusLabel(account.status),
                ),
                _ReadOnlyRow(label: 'Sex', value: account.profile.sex),
                _ReadOnlyRow(
                  label: 'Birth date',
                  value: account.profile.birthDate,
                ),
                _ReadOnlyRow(
                  label: 'Age',
                  value: account.profile.age.toString(),
                ),
                _ReadOnlyRow(
                  label: 'Logistics organization',
                  value: account.affiliation.organizationName ?? 'Not provided',
                ),
                _ReadOnlyRow(
                  label: 'Operational hub',
                  value: account.affiliation.hubName ?? 'Not provided',
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
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
                      setState(() {
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
                      setState(() {
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
                      setState(() {
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

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account, this.profilePhotoBytes});

  final CourierAccount account;
  final Uint8List? profilePhotoBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName =
        '${account.profile.firstName} ${account.profile.lastName}'.trim();
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
              child: profilePhotoBytes == null
                  ? Text(
                      _initials(displayName),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : ClipOval(
                      child: Image.memory(
                        profilePhotoBytes!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          _initials(displayName),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Courier account',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _accountStatusLabel(account.status),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoPreview extends StatelessWidget {
  const _ProfilePhotoPreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Profile photo preview',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 92,
            height: 92,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _AccountBanner extends StatelessWidget {
  const _AccountBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      label: '${isError ? 'Account error' : 'Account update'}: $message',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.obscureText,
    required this.onToggle,
    this.serverError,
    this.validator,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? serverError;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      autofillHints: const <String>[AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        errorText: serverError,
        suffixIcon: IconButton(
          onPressed: onToggle,
          tooltip: obscureText ? 'Show password' : 'Hide password',
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator ?? (value) => _required(value, label.toLowerCase()),
    );
  }
}

String? _required(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return 'Enter your $label.';
  }
  return null;
}

String _accountStatusLabel(CourierAccountStatus status) {
  return switch (status) {
    CourierAccountStatus.pending => 'Pending approval',
    CourierAccountStatus.active => 'Active',
    CourierAccountStatus.rejected => 'Rejected',
    CourierAccountStatus.suspended => 'Suspended',
    CourierAccountStatus.deactivated => 'Deactivated',
  };
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final separator = normalized.lastIndexOf('/');
  return separator < 0 ? normalized : normalized.substring(separator + 1);
}

String _formatFileSize(int bytes) {
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

bool _isAllowedProfilePhotoName(String name) {
  final parts = name.toLowerCase().split('.');
  if (parts.length != 2 || parts.first.isEmpty) {
    return false;
  }
  return <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(parts.last);
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
