part of '../registration_screen.dart';

extension _RegistrationForm on _RegistrationScreenState {
  Widget _buildRegistrationForm(BuildContext context) {
    final result = _result;
    if (result != null) {
      return _buildSubmitted(context, result);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Return to sign in',
          onPressed: _isSubmitting ? null : widget.onSignIn,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Courier registration'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    if (_submissionError != null) ...[
                      _RegistrationErrorBanner(message: _submissionError!),
                      const SizedBox(height: 18),
                    ],
                    if (_fieldErrors.isNotEmpty) ...[
                      _RegistrationFieldErrorSummary(errors: _fieldErrors),
                      const SizedBox(height: 18),
                    ],
                    _sectionHeading(
                      context,
                      'Personal details',
                      'Use the same legal details shown on your identity document.',
                    ),
                    _twoColumn(
                      _textField(
                        controller: _firstNameController,
                        label: 'First name',
                        icon: Icons.person_outline,
                        validator: (value) =>
                            _required(value, 'Enter your first name.'),
                        serverKey: 'first_name',
                      ),
                      _textField(
                        controller: _lastNameController,
                        label: 'Last name',
                        icon: Icons.person_outline,
                        validator: (value) =>
                            _required(value, 'Enter your last name.'),
                        serverKey: 'last_name',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _textField(
                      controller: _middleNameController,
                      label: 'Middle initial (optional)',
                      icon: Icons.person_outline,
                      maxLength: 1,
                      inputFormatters: <TextInputFormatter>[
                        LengthLimitingTextInputFormatter(1),
                      ],
                      serverKey: 'middle_name',
                    ),
                    const SizedBox(height: 14),
                    _twoColumn(
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>('sex-$_sex'),
                        initialValue: _sex,
                        isExpanded: true,
                        decoration: _decoration(
                          'Sex',
                          icon: Icons.wc_outlined,
                          errorText: _serverError('sex'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'non_binary',
                            child: Text('Non-binary'),
                          ),
                          DropdownMenuItem(
                            value: 'prefer_not_to_say',
                            child: Text('Prefer not to say'),
                          ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => _updateState(() => _sex = value),
                        validator: (value) =>
                            value == null ? 'Select your sex.' : null,
                      ),
                      TextFormField(
                        controller: _contactNumberController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.phone,
                        maxLength: 32,
                        decoration: _decoration(
                          'Contact number',
                          hint: '09XX XXX XXXX',
                          icon: Icons.phone_outlined,
                          errorText: _serverError('contact_number'),
                        ),
                        validator: (value) =>
                            _required(value, 'Enter your contact number.'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _birthDateController,
                      enabled: !_isSubmitting,
                      readOnly: true,
                      onTap: _isSubmitting ? null : _pickBirthDate,
                      decoration: _decoration(
                        'Birth date',
                        hint: 'YYYY-MM-DD',
                        icon: Icons.calendar_today_outlined,
                        errorText: _serverError('birth_date'),
                      ),
                      validator: (_) =>
                          _birthDate == null ? 'Select your birth date.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: _decoration(
                        'Email',
                        hint: 'you@example.com',
                        icon: Icons.mail_outline,
                        errorText: _serverError('email'),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    _twoColumn(
                      _passwordField(
                        controller: _passwordController,
                        label: 'Password',
                        serverKey: 'password',
                      ),
                      _passwordField(
                        controller: _passwordConfirmationController,
                        label: 'Confirm password',
                        serverKey: 'password_confirmation',
                        confirmation: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _sectionHeading(
                      context,
                      'Logistics affiliation',
                      'Choose the active Logistics organization you want to apply under. Its hub is assigned by the server.',
                    ),
                    _buildOrganizationField(context),
                    const SizedBox(height: 28),
                    _sectionHeading(
                      context,
                      'Address',
                      'Search the bundled PSGC directory from Region through Barangay, or switch to manual labels when needed. No map pin is required.',
                    ),
                    _textField(
                      controller: _addressLine1Controller,
                      label: 'Street / house detail',
                      icon: Icons.home_outlined,
                      validator: (value) => _required(
                        value,
                        'Enter your street or house detail.',
                      ),
                      serverKey: 'address.address_line_1',
                    ),
                    const SizedBox(height: 14),
                    _textField(
                      controller: _addressLine2Controller,
                      label: 'Address line 2 (optional)',
                      icon: Icons.add_home_outlined,
                      serverKey: 'address.address_line_2',
                    ),
                    const SizedBox(height: 14),
                    _buildAddressDirectory(context),
                    const SizedBox(height: 14),
                    _textField(
                      controller: _postalCodeController,
                      label: 'Postal code',
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      validator: (value) =>
                          _required(value, 'Enter your postal code.'),
                      serverKey: 'address.postal_code',
                    ),
                    const SizedBox(height: 28),
                    _sectionHeading(
                      context,
                      'Vehicle',
                      'Registration creates one initial active vehicle for your Courier application.',
                    ),
                    _twoColumn(
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>('vehicle-$_vehicleType'),
                        initialValue: _vehicleType,
                        isExpanded: true,
                        decoration: _decoration(
                          'Vehicle type',
                          icon: Icons.two_wheeler_outlined,
                          errorText: _serverError('vehicle_type'),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'motorcycle',
                            child: Text('Motorcycle'),
                          ),
                          DropdownMenuItem(value: 'car', child: Text('Car')),
                          DropdownMenuItem(value: 'van', child: Text('Van')),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) =>
                                  _updateState(() => _vehicleType = value),
                        validator: (value) =>
                            value == null ? 'Select a vehicle type.' : null,
                      ),
                      _textField(
                        controller: _plateNumberController,
                        label: 'Plate number',
                        icon: Icons.confirmation_number_outlined,
                        maxLength: 64,
                        validator: (value) =>
                            _required(value, 'Enter your plate number.'),
                        serverKey: 'plate_number',
                      ),
                    ),
                    const SizedBox(height: 28),
                    _sectionHeading(
                      context,
                      'Required evidence',
                      'The server performs the final validation and keeps these documents private.',
                    ),
                    _evidencePicker(
                      context,
                      label: 'Government ID / driver’s license',
                      fieldKey: 'government_id',
                      upload: _governmentId,
                      onPick: () => _pickEvidence(governmentId: true),
                      onRemove: () => _updateState(() => _governmentId = null),
                    ),
                    const SizedBox(height: 14),
                    _evidencePicker(
                      context,
                      label: 'Vehicle registration (OR/CR)',
                      fieldKey: 'vehicle_registration',
                      upload: _vehicleRegistration,
                      onPick: () => _pickEvidence(governmentId: false),
                      onRemove: () =>
                          _updateState(() => _vehicleRegistration = null),
                    ),
                    const SizedBox(height: 26),
                    if (_isSubmitting) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                      Semantics(
                        liveRegion: true,
                        label: 'Submitting registration',
                        child: Text(
                          'Submitting your application…',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _cancelSubmission,
                        child: const Text('Cancel upload'),
                      ),
                    ] else ...[
                      Semantics(
                        button: true,
                        label: 'Submit Courier registration',
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Submit registration'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _isSubmitting ? null : widget.onSignIn,
                      child: const Text('Already registered? Sign in'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your application remains pending until the selected Logistics organization approves it. No session is created during registration.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
