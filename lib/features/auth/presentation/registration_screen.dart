import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../data/psgc_address_data_source.dart';
import '../domain/auth_models.dart';
import '../domain/psgc_address_models.dart';
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
  final _psgcDataSource = PsgcAddressDataSource();
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
  List<PsgcRegion> _psgcRegions = const <PsgcRegion>[];
  LogisticsOption? _organization;
  PsgcRegion? _psgcRegion;
  PsgcAddressNode? _psgcRegionTree;
  PsgcAddressNode? _psgcProvince;
  PsgcAddressNode? _psgcCity;
  PsgcAddressNode? _psgcBarangay;
  String? _sex;
  String? _vehicleType;
  DateTime? _birthDate;
  RegistrationUpload? _governmentId;
  RegistrationUpload? _vehicleRegistration;
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};
  String? _optionsError;
  String? _psgcError;
  String? _submissionError;
  RegistrationResult? _result;
  bool _isLoadingOrganizations = true;
  bool _isLoadingPsgc = true;
  bool _isLoadingPsgcRegion = false;
  bool _useManualAddress = false;
  bool _isSubmitting = false;
  int _submissionSerial = 0;
  VoidCallback? _cancelUpload;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOrganizations());
    unawaited(_loadPsgcRegions());
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

  Future<void> _loadPsgcRegions() async {
    try {
      final regions = await _psgcDataSource.loadRegions();
      if (!mounted) {
        return;
      }
      setState(() {
        _psgcRegions = regions;
        _isLoadingPsgc = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPsgc = false;
        _useManualAddress = true;
        _psgcError = 'The bundled address directory is unavailable. Manual address entry is available.';
      });
    }
  }

  Future<void> _selectPsgcRegion(PsgcRegion? region) async {
    setState(() {
      _psgcRegion = region;
      _psgcRegionTree = null;
      _psgcProvince = null;
      _psgcCity = null;
      _psgcBarangay = null;
      _psgcError = null;
      _isLoadingPsgcRegion = region != null;
      _regionController.text = region?.name ?? '';
      _provinceController.clear();
      _cityMunicipalityController.clear();
      _barangayController.clear();
    });

    if (region == null) {
      return;
    }

    try {
      final tree = await _psgcDataSource.loadRegion(region);
      if (!mounted || _psgcRegion?.code != region.code) {
        return;
      }
      setState(() {
        _psgcRegionTree = tree;
        _isLoadingPsgcRegion = false;
      });
    } catch (_) {
      if (!mounted || _psgcRegion?.code != region.code) {
        return;
      }
      setState(() {
        _isLoadingPsgcRegion = false;
        _useManualAddress = true;
        _psgcError = 'This region could not be opened from the bundled directory. Manual address entry is available.';
      });
    }
  }

  void _selectPsgcProvince(PsgcAddressNode? province) {
    setState(() {
      _psgcProvince = province;
      _psgcCity = null;
      _psgcBarangay = null;
      _provinceController.text = province?.name ?? '';
      _cityMunicipalityController.clear();
      _barangayController.clear();
    });
  }

  void _selectPsgcCity(PsgcAddressNode? city) {
    setState(() {
      _psgcCity = city;
      _psgcBarangay = null;
      _cityMunicipalityController.text = city?.name ?? '';
      _barangayController.clear();
    });
  }

  void _selectPsgcBarangay(PsgcAddressNode? barangay) {
    setState(() {
      _psgcBarangay = barangay;
      _barangayController.text = barangay?.name ?? '';
    });
  }

  List<PsgcAddressNode> get _psgcProvinceOptions {
    return _psgcRegionTree?.children
            .where((node) => node.geographicLevel == 'province')
            .toList(growable: false) ??
        const <PsgcAddressNode>[];
  }

  List<PsgcAddressNode> get _psgcCityOptions {
    final parent = _psgcProvince ?? _psgcRegionTree;
    return parent?.children
            .where(
              (node) =>
                  node.geographicLevel == 'city' ||
                  node.geographicLevel == 'municipality',
            )
            .toList(growable: false) ??
        const <PsgcAddressNode>[];
  }

  List<PsgcAddressNode> get _psgcBarangayOptions {
    final city = _psgcCity;
    if (city == null) {
      return const <PsgcAddressNode>[];
    }
    return _findBarangays(city);
  }

  List<PsgcAddressNode> _findBarangays(PsgcAddressNode node) {
    if (node.geographicLevel == 'barangay') {
      return <PsgcAddressNode>[node];
    }
    final barangays = <PsgcAddressNode>[];
    for (final child in node.children) {
      barangays.addAll(_findBarangays(child));
    }
    return barangays;
  }

  bool _validatePsgcAddress() {
    if (_useManualAddress) {
      return true;
    }
    if (_isLoadingPsgc || _isLoadingPsgcRegion) {
      setState(() {
        _submissionError = 'Wait for the address directory to finish loading, or choose manual address entry.';
      });
      return false;
    }
    if (_psgcRegion == null || _psgcRegionTree == null) {
      setState(() {
        _submissionError = 'Select a region from the address directory.';
      });
      return false;
    }
    if (_psgcProvinceOptions.isNotEmpty && _psgcProvince == null) {
      setState(() {
        _submissionError = 'Select a province from the address directory.';
      });
      return false;
    }
    if (_provinceController.text.trim().isEmpty) {
      setState(() {
        _submissionError = 'Enter the province for this address.';
      });
      return false;
    }
    if (_psgcCity == null) {
      setState(() {
        _submissionError =
            'Select a city or municipality from the address directory.';
      });
      return false;
    }
    if (_psgcBarangay == null) {
      setState(() {
        _submissionError = 'Select a barangay from the address directory.';
      });
      return false;
    }
    return true;
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
      setState(() {
        _submissionError = 'Some required information is missing or invalid. Review the highlighted fields below before submitting.';
      });
      return;
    }

    if (!_validatePsgcAddress()) {
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
            Expanded(child: Text('Loading active Logistics organizations…')),
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

  Widget _buildAddressDirectory(BuildContext context) {
    if (_useManualAddress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_psgcError != null) _addressNotice(context, _psgcError!),
          _manualAddressFields(),
          if (_psgcRegions.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() {
                        _useManualAddress = false;
                        _psgcError = null;
                      }),
                icon: const Icon(Icons.search),
                label: const Text('Use searchable PSGC directory'),
              ),
            ),
        ],
      );
    }

    if (_isLoadingPsgc) {
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
            Expanded(
              child: Text('Loading the bundled PSGC address directory…'),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[
      _psgcDropdown<PsgcRegion>(
        fieldKey: 'address.region',
        label: 'Region',
        icon: Icons.map_outlined,
        options: _psgcRegions,
        selected: _psgcRegion,
        labelFor: (region) => region.name,
        onSelected: _selectPsgcRegion,
      ),
    ];

    if (_isLoadingPsgcRegion) {
      children.addAll(const <Widget>[
        SizedBox(height: 14),
        LinearProgressIndicator(),
      ]);
    } else if (_psgcRegionTree != null) {
      final provinceOptions = _psgcProvinceOptions;
      if (provinceOptions.isNotEmpty) {
        children.addAll(<Widget>[
          const SizedBox(height: 14),
          _psgcDropdown<PsgcAddressNode>(
            fieldKey: 'address.province',
            label: 'Province',
            options: provinceOptions,
            selected: _psgcProvince,
            labelFor: (province) => province.name,
            onSelected: _selectPsgcProvince,
          ),
        ]);
      } else {
        children.addAll(<Widget>[
          const SizedBox(height: 14),
          _textField(
            controller: _provinceController,
            label: 'Province / administrative area',
            hint: 'Enter the province label used for this region',
            validator: (value) =>
                _required(value, 'Enter the province for this address.'),
            serverKey: 'address.province',
          ),
        ]);
      }

      final cityOptions = _psgcCityOptions;
      if (cityOptions.isNotEmpty) {
        children.addAll(<Widget>[
          const SizedBox(height: 14),
          _psgcDropdown<PsgcAddressNode>(
            fieldKey: 'address.city_municipality',
            label: 'City / municipality',
            options: cityOptions,
            selected: _psgcCity,
            labelFor: (city) => city.name,
            onSelected: _selectPsgcCity,
          ),
        ]);
      } else {
        children.addAll(<Widget>[
          const SizedBox(height: 14),
          _textField(
            controller: _cityMunicipalityController,
            label: 'City / municipality',
            validator: (value) =>
                _required(value, 'Enter your city or municipality.'),
            serverKey: 'address.city_municipality',
          ),
        ]);
      }

      if (_psgcCity != null && _psgcBarangayOptions.isNotEmpty) {
        children.addAll(<Widget>[
          const SizedBox(height: 14),
          _psgcDropdown<PsgcAddressNode>(
            fieldKey: 'address.barangay',
            label: 'Barangay',
            options: _psgcBarangayOptions,
            selected: _psgcBarangay,
            labelFor: (barangay) => barangay.name,
            onSelected: _selectPsgcBarangay,
          ),
        ]);
      } else if (_psgcCity != null) {
        children.addAll(<Widget>[
          const SizedBox(height: 14),
          _textField(
            controller: _barangayController,
            label: 'Barangay',
            validator: (value) => _required(value, 'Enter your barangay.'),
            serverKey: 'address.barangay',
          ),
        ]);
      } else {
        children.add(
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Select a city or municipality to search barangays.'),
          ),
        );
      }
    }

    children.addAll(<Widget>[
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _isSubmitting
              ? null
              : () => setState(() => _useManualAddress = true),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Use manual address entry instead'),
        ),
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _manualAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _twoColumn(
          _textField(
            controller: _regionController,
            label: 'Region',
            validator: (value) => _required(value, 'Enter your region.'),
            serverKey: 'address.region',
          ),
          _textField(
            controller: _provinceController,
            label: 'Province',
            validator: (value) => _required(value, 'Enter your province.'),
            serverKey: 'address.province',
          ),
        ),
        const SizedBox(height: 14),
        _twoColumn(
          _textField(
            controller: _cityMunicipalityController,
            label: 'City / municipality',
            validator: (value) =>
                _required(value, 'Enter your city or municipality.'),
            serverKey: 'address.city_municipality',
          ),
          _textField(
            controller: _barangayController,
            label: 'Barangay',
            validator: (value) => _required(value, 'Enter your barangay.'),
            serverKey: 'address.barangay',
          ),
        ),
      ],
    );
  }

  Widget _psgcDropdown<T>({
    required String fieldKey,
    required String label,
    required List<T> options,
    required T? selected,
    required String Function(T) labelFor,
    required ValueChanged<T?> onSelected,
    IconData? icon,
  }) {
    return DropdownMenu<T>(
      key: ValueKey<String>(
        '$fieldKey-${selected == null ? '' : labelFor(selected)}',
      ),
      enabled: !_isSubmitting && options.isNotEmpty,
      width: double.infinity,
      menuHeight: 360,
      label: Text(label),
      hintText: options.isEmpty ? 'No options available' : 'Type to search',
      errorText: _serverError(fieldKey),
      enableFilter: true,
      enableSearch: true,
      initialSelection: selected,
      leadingIcon: icon == null ? null : Icon(icon),
      dropdownMenuEntries: options
          .map(
            (option) =>
                DropdownMenuEntry<T>(value: option, label: labelFor(option)),
          )
          .toList(growable: false),
      onSelected: onSelected,
    );
  }

  Widget _addressNotice(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
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
