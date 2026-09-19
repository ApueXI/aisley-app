import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/account_models.dart';
import '../../vehicle/presentation/vehicle_controller.dart';
import '../../vehicle/presentation/vehicle_screen.dart';
import 'account_controller.dart';

part 'components/account_screen_account.dart';
part 'components/account_screen_content.dart';
part 'components/account_screen_profile_photo.dart';
part 'components/account_screen_profile_photo_view.dart';
part 'components/account_screen_security.dart';
part 'components/account_screen_widgets.dart';

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
    this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final AccountController accountController;
  final PolicyController? policyController;
  final VehicleController? vehicleController;

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

  void _updateState(VoidCallback callback) {
    setState(callback);
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

  Future<void> _openVehicle() async {
    final vehicleController = widget.vehicleController;
    if (vehicleController == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleScreen(
          authController: widget.authController,
          vehicleController: vehicleController,
        ),
      ),
    );
  }
}
