part of '../registration_screen.dart';

extension _RegistrationAddress on _RegistrationScreenState {
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
                    : () => _updateState(() {
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
              : () => _updateState(() => _useManualAddress = true),
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
}
