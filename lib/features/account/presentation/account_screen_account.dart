part of 'account_screen.dart';

extension _AccountScreenAccount on _AccountScreenState {
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

  Future<void> _closeIfSessionEnded() async {
    if (!mounted || widget.authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildPersonalInformationSection(BuildContext context) {
    final controller = widget.accountController;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildAccountDetailsSection(
    BuildContext context,
    CourierAccount account,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}
