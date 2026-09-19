import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../data/psgc_address_data_source.dart';
import '../domain/auth_models.dart';
import '../domain/psgc_address_models.dart';
import 'controllers/auth_controller.dart';

part 'components/registration_data.dart';
part 'components/registration_submission.dart';
part 'components/registration_form.dart';
part 'components/registration_sections.dart';
part 'components/registration_address.dart';
part 'components/registration_fields.dart';
part 'components/registration_result.dart';

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

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  @override
  Widget build(BuildContext context) {
    return _buildRegistrationForm(context);
  }
}
