import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';

const _maxEvidenceBytes = 10 * 1024 * 1024;
const _evidenceTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
);

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    required this.authController,
    required this.onSignIn,
    super.key,
  });

  final AuthController authController;
  final VoidCallback onSignIn;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityMunicipalityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _regionController = TextEditingController();
  final _postalCodeController = TextEditingController();

  List<LogisticsOption> _organizations = const <LogisticsOption>[];
  LogisticsOption? _organization;
  String? _sex;
  String? _vehicleType;
  DateTime? _birthDate;
  RegistrationUpload? _governmentId;
  RegistrationUpload? _vehicleRegistration;
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};
  String? _optionsError;
  String? _submissionError;
  RegistrationResult? _result;
  bool _isLoadingOrganizations = true;
  bool _isSubmitting = false;
  int _submissionSerial = 0;
  VoidCallback? _cancelUpload;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOrganizations());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _birthDateController.dispose();
    _plateNumberController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _barangayController.dispose();
    _cityMunicipalityController.dispose();
    _provinceController.dispose();
    _regionController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    if (mounted) {
      setState(() {
        _isLoadingOrganizations = true;
        _optionsError = null;
      });
    }

    try {
      final organizations = await widget.authController.fetchLogisticsOptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _organizations = organizations;
        _isLoadingOrganizations = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingOrganizations = false;
        _optionsError = _messageForOptionsError(error);
      });
    } on ApiContractException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingOrganizations = false;
        _optionsError =
            'The service returned an unexpected Logistics list. Please retry.';
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select your birth date',
    );
    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _birthDate = selectedDate;
      _birthDateController.text = _formatDisplayDate(selectedDate);
    });
  }

  Future<void> _pickEvidence({required bool governmentId}) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_evidenceTypeGroup],
      );
      if (file == null) {
        return;
      }

      final validationError = await _validateEvidence(file);
      if (!mounted) {
        return;
      }
      if (validationError != null) {
        setState(() {
          _submissionError = validationError;
        });
        return;
      }

      final upload = RegistrationUpload(
        path: file.path,
        fileName: _fileName(file),
        sizeInBytes: await file.length(),
      );
      setState(() {
        if (governmentId) {
          _governmentId = upload;
        } else {
          _vehicleRegistration = upload;
        }
        _submissionError = null;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _submissionError =
            'The selected document could not be read. Choose it again.';
      });
    }
  }

  Future<String?> _validateEvidence(XFile file) async {
    if (file.path.trim().isEmpty) {
      return 'The selected document could not be read. Choose it again.';
    }

    final name = _fileName(file);
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    if (!const <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      return 'Use a JPEG, JPG, PNG, or WebP image.';
    }

    final size = await file.length();
    if (size >= _maxEvidenceBytes) {
      return 'Each image must be smaller than 10 MiB.';
    }

    final bytes = await file.readAsBytes();
    if (!_hasSupportedImageSignature(bytes)) {
      return 'The selected file does not appear to be a valid image.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _fieldErrors = const <String, List<String>>{};
      _submissionError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_organization == null) {
      setState(() {
        _submissionError = 'Select a Logistics organization.';
      });
      return;
    }
    if (_governmentId == null || _vehicleRegistration == null) {
      setState(() {
        _submissionError =
            'Select both a government ID and a vehicle registration image.';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final serial = ++_submissionSerial;
    setState(() {
      _isSubmitting = true;
      _cancelUpload = null;
    });

    final request = CourierRegistrationRequest(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      middleName: _middleNameController.text,
      contactNumber: _contactNumberController.text,
      sex: _sex!,
      birthDate: _birthDate!,
      email: _emailController.text,
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmationController.text,
      logisticsOrganizationId: _organization!.id,
      vehicleType: _vehicleType!,
      plateNumber: _plateNumberController.text,
      addressLine1: _addressLine1Controller.text,
      addressLine2: _addressLine2Controller.text,
      barangay: _barangayController.text,
      cityMunicipality: _cityMunicipalityController.text,
      province: _provinceController.text,
      region: _regionController.text,
      postalCode: _postalCodeController.text,
      governmentId: _governmentId!,
      vehicleRegistration: _vehicleRegistration!,
    );

    try {
      final result = await widget.authController.register(
        request,
        onCancel: (cancel) {
          if (serial != _submissionSerial) {
            cancel();
            return;
          }
          if (mounted) {
            setState(() {
              _cancelUpload = cancel;
            });
          }
        },
      );
      if (!mounted || serial != _submissionSerial) {
        return;
      }
      _passwordController.clear();
      _passwordConfirmationController.clear();
      setState(() {
        _result = result;
        _isSubmitting = false;
        _cancelUpload = null;
        _governmentId = null;
        _vehicleRegistration = null;
      });
    } on ApiException catch (error) {
      if (!mounted || serial != _submissionSerial) {
        return;
      }
      setState(() {
        _fieldErrors = error.fieldErrors;
        _submissionError = _messageForRegistrationError(error);
        _isSubmitting = false;
        _cancelUpload = null;
        _passwordController.clear();
        _passwordConfirmationController.clear();
      });
    } on ApiContractException {
      if (!mounted || serial != _submissionSerial) {
        return;
      }
      setState(() {
        _submissionError = 'The service returned an unexpected registration response. Please retry.';
        _isSubmitting = false;
        _cancelUpload = null;
        _passwordController.clear();
        _passwordConfirmationController.clear();
      });
    } on Exception {
      if (!mounted || serial != _submissionSerial) {
        return;
      }
      setState(() {
        _submissionError = 'A selected document could not be read. Choose the files again and retry.';
        _isSubmitting = false;
        _cancelUpload = null;
        _passwordController.clear();
        _passwordConfirmationController.clear();
      });
    } finally {
      if (mounted && serial == _submissionSerial && _isSubmitting) {
        setState(() {
          _isSubmitting = false;
          _cancelUpload = null;
        });
      }
    }
  }

  void _cancelSubmission() {
    if (!_isSubmitting) {
      return;
    }
    _submissionSerial++;
    _cancelUpload?.call();
    setState(() {
      _isSubmitting = false;
      _cancelUpload = null;
      _submissionError = 'Registration upload cancelled. Review the form before submitting again.';
    });
  }

  @override
  Widget build(BuildContext context) {
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
                            : (value) => setState(() => _sex = value),
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
                      'Use PSGC spelling when known. These fields are the manual fallback and are submitted as labels; no map pin is required.',
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
                    _twoColumn(
                      _textField(
                        controller: _regionController,
                        label: 'Region',
                        validator: (value) =>
                            _required(value, 'Enter your region.'),
                        serverKey: 'address.region',
                      ),
                      _textField(
                        controller: _provinceController,
                        label: 'Province',
                        validator: (value) =>
                            _required(value, 'Enter your province.'),
                        serverKey: 'address.province',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _twoColumn(
                      _textField(
                        controller: _cityMunicipalityController,
                        label: 'City / municipality',
                        validator: (value) => _required(
                          value,
                          'Enter your city or municipality.',
                        ),
                        serverKey: 'address.city_municipality',
                      ),
                      _textField(
                        controller: _barangayController,
                        label: 'Barangay',
                        validator: (value) =>
                            _required(value, 'Enter your barangay.'),
                        serverKey: 'address.barangay',
                      ),
                    ),
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
                            : (value) => setState(() => _vehicleType = value),
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
                      onRemove: () => setState(() => _governmentId = null),
                    ),
                    const SizedBox(height: 14),
                    _evidencePicker(
                      context,
                      label: 'Vehicle registration (OR/CR)',
                      fieldKey: 'vehicle_registration',
                      upload: _vehicleRegistration,
                      onPick: () => _pickEvidence(governmentId: false),
                      onRemove: () =>
                          setState(() => _vehicleRegistration = null),
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

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[scheme.primary, scheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.two_wheeler_outlined, color: scheme.onPrimary),
        ),
        const SizedBox(height: 20),
        Text(
          'Create your Courier account',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Submit your details for Logistics approval. Fields marked by the server remain authoritative.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 26),
      ],
    );
  }

  Widget _buildOrganizationField(BuildContext context) {
    if (_isLoadingOrganizations) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Text('Loading active Logistics organizations…'),
          ],
        ),
      );
    }

    if (_optionsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _optionsError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadOrganizations,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry organizations'),
          ),
        ],
      );
    }

    if (_organizations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No active Logistics organizations are available right now.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadOrganizations,
            icon: const Icon(Icons.refresh),
            label: const Text('Check again'),
          ),
        ],
      );
    }

    return DropdownButtonFormField<LogisticsOption>(
      key: ValueKey<String?>('organization-${_organization?.id}'),
      initialValue: _organization,
      isExpanded: true,
      decoration: _decoration(
        'Logistics organization',
        icon: Icons.business_outlined,
        errorText: _serverError('logistics_organization_id'),
      ),
      items: _organizations
          .map(
            (organization) => DropdownMenuItem<LogisticsOption>(
              value: organization,
              child: Text(organization.businessName),
            ),
          )
          .toList(growable: false),
      onChanged: _isSubmitting
          ? null
          : (value) => setState(() => _organization = value),
      validator: (value) =>
          value == null ? 'Select a Logistics organization.' : null,
    );
  }

  Widget _evidencePicker(
    BuildContext context, {
    required String label,
    required String fieldKey,
    required RegistrationUpload? upload,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: _decoration(label, errorText: _serverError(fieldKey)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                upload == null
                    ? Icons.upload_file_outlined
                    : Icons.check_circle,
                color: upload == null
                    ? scheme.onSurfaceVariant
                    : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: upload == null
                    ? Text(
                        'No image selected',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            upload.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(upload.sizeInBytes),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (upload != null)
                IconButton(
                  tooltip: 'Remove $label',
                  onPressed: _isSubmitting ? null : onRemove,
                  icon: const Icon(Icons.close),
                ),
              OutlinedButton(
                onPressed: _isSubmitting ? null : onPick,
                child: Text(upload == null ? 'Choose' : 'Replace'),
              ),
            ],
          );

          if (constraints.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    );
  }

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
  if (error.statusCode == 429) {
    return 'Too many registration attempts. Please wait before trying again.';
  }
  if (error.isNetworkError) {
    return 'Could not reach the service. Your form is preserved; retry only when you are ready.';
  }
  if (error.statusCode == 422) {
    return error.message.isEmpty
        ? 'Check the highlighted fields and try again.'
        : error.message;
  }
  return 'Registration could not be submitted. Please review the form and retry.';
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
