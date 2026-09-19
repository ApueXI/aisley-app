part of '../registration_screen.dart';

extension _RegistrationSubmission on _RegistrationScreenState {
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

    _updateState(() {
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
        _updateState(() {
          _submissionError = validationError;
        });
        return;
      }

      final upload = RegistrationUpload(
        path: file.path,
        fileName: _fileName(file),
        sizeInBytes: await file.length(),
      );
      _updateState(() {
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
      _updateState(() {
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

    _updateState(() {
      _fieldErrors = const <String, List<String>>{};
      _submissionError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      _updateState(() {
        _submissionError = 'Some required information is missing or invalid. Review the highlighted fields below before submitting.';
      });
      return;
    }

    if (!_validatePsgcAddress()) {
      return;
    }

    if (_organization == null) {
      _updateState(() {
        _submissionError = 'Select a Logistics organization.';
      });
      return;
    }
    if (_governmentId == null || _vehicleRegistration == null) {
      _updateState(() {
        _submissionError =
            'Select both a government ID and a vehicle registration image.';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final serial = ++_submissionSerial;
    _updateState(() {
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
            _updateState(() {
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
      _updateState(() {
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
      _updateState(() {
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
      _updateState(() {
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
      _updateState(() {
        _submissionError = 'A selected document could not be read. Choose the files again and retry.';
        _isSubmitting = false;
        _cancelUpload = null;
        _passwordController.clear();
        _passwordConfirmationController.clear();
      });
    } finally {
      if (mounted && serial == _submissionSerial && _isSubmitting) {
        _updateState(() {
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
    _updateState(() {
      _isSubmitting = false;
      _cancelUpload = null;
      _submissionError = 'Registration upload cancelled. Review the form before submitting again.';
    });
  }
}
