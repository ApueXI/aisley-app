part of '../registration_screen.dart';

extension _RegistrationSections on _RegistrationScreenState {
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
          : (value) => _updateState(() => _organization = value),
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
}
