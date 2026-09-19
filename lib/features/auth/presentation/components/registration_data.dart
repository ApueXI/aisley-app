part of '../registration_screen.dart';

extension _RegistrationData on _RegistrationScreenState {
  Future<void> _loadOrganizations() async {
    if (mounted) {
      _updateState(() {
        _isLoadingOrganizations = true;
        _optionsError = null;
      });
    }

    try {
      final organizations = await widget.authController.fetchLogisticsOptions();
      if (!mounted) {
        return;
      }
      _updateState(() {
        _organizations = organizations;
        _isLoadingOrganizations = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _updateState(() {
        _isLoadingOrganizations = false;
        _optionsError = _messageForOptionsError(error);
      });
    } on ApiContractException {
      if (!mounted) {
        return;
      }
      _updateState(() {
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
      _updateState(() {
        _psgcRegions = regions;
        _isLoadingPsgc = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _updateState(() {
        _isLoadingPsgc = false;
        _useManualAddress = true;
        _psgcError = 'The bundled address directory is unavailable. Manual address entry is available.';
      });
    }
  }

  Future<void> _selectPsgcRegion(PsgcRegion? region) async {
    _updateState(() {
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
      _updateState(() {
        _psgcRegionTree = tree;
        _isLoadingPsgcRegion = false;
      });
    } catch (_) {
      if (!mounted || _psgcRegion?.code != region.code) {
        return;
      }
      _updateState(() {
        _isLoadingPsgcRegion = false;
        _useManualAddress = true;
        _psgcError = 'This region could not be opened from the bundled directory. Manual address entry is available.';
      });
    }
  }

  void _selectPsgcProvince(PsgcAddressNode? province) {
    _updateState(() {
      _psgcProvince = province;
      _psgcCity = null;
      _psgcBarangay = null;
      _provinceController.text = province?.name ?? '';
      _cityMunicipalityController.clear();
      _barangayController.clear();
    });
  }

  void _selectPsgcCity(PsgcAddressNode? city) {
    _updateState(() {
      _psgcCity = city;
      _psgcBarangay = null;
      _cityMunicipalityController.text = city?.name ?? '';
      _barangayController.clear();
    });
  }

  void _selectPsgcBarangay(PsgcAddressNode? barangay) {
    _updateState(() {
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
      _updateState(() {
        _submissionError = 'Wait for the address directory to finish loading, or choose manual address entry.';
      });
      return false;
    }
    if (_psgcRegion == null || _psgcRegionTree == null) {
      _updateState(() {
        _submissionError = 'Select a region from the address directory.';
      });
      return false;
    }
    if (_psgcProvinceOptions.isNotEmpty && _psgcProvince == null) {
      _updateState(() {
        _submissionError = 'Select a province from the address directory.';
      });
      return false;
    }
    if (_provinceController.text.trim().isEmpty) {
      _updateState(() {
        _submissionError = 'Enter the province for this address.';
      });
      return false;
    }
    if (_psgcCity == null) {
      _updateState(() {
        _submissionError =
            'Select a city or municipality from the address directory.';
      });
      return false;
    }
    if (_psgcBarangay == null) {
      _updateState(() {
        _submissionError = 'Select a barangay from the address directory.';
      });
      return false;
    }
    return true;
  }
}
