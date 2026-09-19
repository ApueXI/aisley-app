part of '../account_screen.dart';

extension _AccountScreenContent on _AccountScreenState {
  Widget _buildAccountForm(BuildContext context, CourierAccount account) {
    final controller = widget.accountController;
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
        if (widget.vehicleController != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: const Icon(Icons.two_wheeler_outlined),
              title: const Text('Vehicle management'),
              subtitle: const Text(
                'Update vehicle details and replace your private OR or CR.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openVehicle,
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
        _buildPersonalInformationSection(context),
        const SizedBox(height: 24),
        _buildAccountDetailsSection(context, account),
        const SizedBox(height: 24),
        _buildSecuritySection(context),
      ],
    );
  }
}
