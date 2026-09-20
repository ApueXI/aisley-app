part of '../vehicle_screen.dart';

extension _VehicleScreenActions on _VehicleScreenState {
  Future<void> _loadVehicle() async {
    await _vehicleController.load();
    if (!_vehicleMounted) {
      return;
    }
    final vehicle = _vehicleController.vehicle;
    if (vehicle != null && !_hasPopulatedVehicle) {
      _populateVehicle(vehicle);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _refreshVehicle() async {
    final hadLocalEdits = _hasLocalVehicleEdits();
    await _vehicleController.load();
    if (!_vehicleMounted) {
      return;
    }
    final vehicle = _vehicleController.vehicle;
    if (vehicle != null && !hadLocalEdits) {
      _populateVehicle(vehicle);
    }
    await _closeIfSessionEnded();
  }

  void _populateVehicle(CourierVehicle vehicle) {
    _vehicleType = vehicle.vehicleType;
    _plateController.text = vehicle.plateNumber;
    _makeController.text = vehicle.make ?? '';
    _modelController.text = vehicle.model ?? '';
    _hasPopulatedVehicle = true;
  }

  bool _hasLocalVehicleEdits() {
    final vehicle = _vehicleController.vehicle;
    if (vehicle == null || !_hasPopulatedVehicle) {
      return false;
    }
    return _vehicleType != vehicle.vehicleType ||
        _plateController.text.trim() != vehicle.plateNumber ||
        _makeController.text.trim() != (vehicle.make ?? '') ||
        _modelController.text.trim() != (vehicle.model ?? '');
  }

  Future<void> _saveVehicle() async {
    if (_vehicleController.updateStatus == VehicleActionStatus.saving ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final vehicle = _vehicleController.vehicle;
    if (vehicle == null) {
      return;
    }

    final changes = <String, Object?>{};
    if (_vehicleType != vehicle.vehicleType) {
      changes['vehicle_type'] = _vehicleType;
    }
    if (_plateController.text.trim() != vehicle.plateNumber) {
      changes['plate_number'] = _plateController.text.trim();
    }
    if (_makeController.text.trim() != (vehicle.make ?? '')) {
      changes['make'] = _emptyAsNull(_makeController.text);
    }
    if (_modelController.text.trim() != (vehicle.model ?? '')) {
      changes['model'] = _emptyAsNull(_modelController.text);
    }
    if (changes.isEmpty) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await _vehicleController.updateVehicle(changes: changes);
    if (!_vehicleMounted) {
      return;
    }
    final updatedVehicle = _vehicleController.vehicle;
    if (saved && updatedVehicle != null) {
      _populateVehicle(updatedVehicle);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _pickDocument(VehicleDocumentKind kind) async {
    if (_isPicking[kind] == true ||
        _vehicleController.documentActionStatus(kind) ==
            VehicleActionStatus.uploading) {
      return;
    }
    _vehicleSetState(() {
      _isPicking[kind] = true;
      _selectionErrors[kind] = null;
    });

    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_vehicleDocumentTypeGroup],
      );
      if (file == null) {
        return;
      }
      final fileName = file.name.trim().isEmpty
          ? _fileNameFromPath(file.path)
          : file.name.trim();
      if (!_isAllowedImageName(fileName)) {
        _setSelectionError(kind, 'Choose a JPEG, JPG, PNG, or WebP image.');
        return;
      }
      final fileSize = await file.length();
      if (fileSize <= 0 || fileSize >= _maxVehicleDocumentBytes) {
        _setSelectionError(
          kind,
          'The document must be non-empty and under 10 MB (10,485,760 bytes).',
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty ||
          bytes.length >= _maxVehicleDocumentBytes ||
          bytes.length != fileSize) {
        _setSelectionError(
          kind,
          'The document changed while it was being read. Choose it again.',
        );
        return;
      }
      if (!_hasSupportedImageSignature(bytes)) {
        _setSelectionError(
          kind,
          'The selected file does not look like a supported image.',
        );
        return;
      }

      if (!_vehicleMounted) {
        return;
      }
      _vehicleSetState(() {
        _pendingDocuments[kind] = VehicleDocumentSelection(
          path: file.path,
          fileName: fileName,
          bytes: Uint8List.fromList(bytes),
        );
        _selectionErrors[kind] = null;
      });
    } catch (_) {
      _setSelectionError(
        kind,
        'The document could not be opened. Choose a supported image and try again.',
      );
    } finally {
      if (_vehicleMounted) {
        _vehicleSetState(() {
          _isPicking[kind] = false;
        });
      }
    }
  }

  Future<void> _uploadDocument(VehicleDocumentKind kind) async {
    final selection = _pendingDocuments[kind];
    if (selection == null ||
        _vehicleController.documentActionStatus(kind) ==
            VehicleActionStatus.uploading) {
      return;
    }
    _vehicleSetState(() {
      _cancelUploads[kind] = null;
      _selectionErrors[kind] = null;
    });

    final uploaded = await _vehicleController.uploadDocument(
      kind,
      selection,
      onCancel: (cancel) {
        if (_vehicleMounted) {
          _vehicleSetState(() {
            _cancelUploads[kind] = cancel;
          });
        }
      },
    );
    if (!_vehicleMounted) {
      return;
    }
    _vehicleSetState(() {
      _cancelUploads[kind] = null;
      if (uploaded) {
        _pendingDocuments[kind] = null;
      }
    });
    await _closeIfSessionEnded();
  }

  Future<void> _retryDocument(VehicleDocumentKind kind) async {
    final selection = _pendingDocuments[kind];
    if (selection == null) {
      return;
    }
    final documentStatus = _vehicleController.documentActionStatus(kind);
    final hasPendingAttempt =
        documentStatus == VehicleActionStatus.offline ||
        documentStatus == VehicleActionStatus.timeout ||
        documentStatus == VehicleActionStatus.failed;
    final retried = hasPendingAttempt
        ? await _vehicleController.retryDocument(kind)
        : await _vehicleController.uploadDocument(kind, selection);
    if (!_vehicleMounted) {
      return;
    }
    if (retried) {
      _vehicleSetState(() {
        _pendingDocuments[kind] = null;
      });
    }
    await _closeIfSessionEnded();
  }

  Future<void> _viewDocument(VehicleDocumentKind kind) async {
    await _vehicleController.loadDocument(kind);
    await _closeIfSessionEnded();
  }

  Future<void> _discardDocument(VehicleDocumentKind kind) async {
    if (!_vehicleMounted) {
      return;
    }
    _vehicleSetState(() {
      _pendingDocuments[kind] = null;
      _selectionErrors[kind] = null;
    });
  }

  void _setSelectionError(VehicleDocumentKind kind, String message) {
    if (!_vehicleMounted) {
      return;
    }
    _vehicleSetState(() {
      _selectionErrors[kind] = message;
    });
  }

  Future<void> _closeIfSessionEnded() async {
    if (!_vehicleMounted ||
        _authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(_vehicleContext).canPop()) {
      Navigator.of(_vehicleContext).pop();
    }
  }
}
