part of '../vehicle_screen.dart';

extension _VehicleScreenDetails on _VehicleScreenState {
  Widget _buildVehicleState(BuildContext context) {
    final controller = _vehicleController;
    if (controller.loadStatus == VehicleLoadStatus.loading) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Loading vehicle information',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    final canRetry =
        controller.loadStatus != VehicleLoadStatus.unauthorized &&
        controller.loadStatus != VehicleLoadStatus.forbidden;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                controller.loadStatus == VehicleLoadStatus.forbidden
                    ? Icons.lock_outline
                    : Icons.two_wheeler_outlined,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                controller.errorMessage ??
                    'Vehicle information is not available right now.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (canRetry) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: controller.loadStatus == VehicleLoadStatus.loading
                      ? null
                      : _loadVehicle,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleForm(BuildContext context, CourierVehicle vehicle) {
    final controller = _vehicleController;
    final scheme = Theme.of(context).colorScheme;
    final updateBusy = controller.updateStatus == VehicleActionStatus.saving;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        Card(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.directions_car_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your registered vehicle',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vehicle changes update the same Courier-owned record. They do not create another vehicle or reset Logistics approval.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (controller.loadStatus == VehicleLoadStatus.loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (controller.errorMessage != null &&
            controller.loadStatus != VehicleLoadStatus.loaded) ...[
          const SizedBox(height: 16),
          _VehicleBanner(message: controller.errorMessage!, isError: true),
        ],
        if (controller.updateErrorMessage != null) ...[
          const SizedBox(height: 16),
          _VehicleBanner(
            message: controller.updateErrorMessage!,
            isError: true,
          ),
        ],
        if (controller.updateSuccessMessage != null) ...[
          const SizedBox(height: 16),
          _VehicleBanner(
            message: controller.updateSuccessMessage!,
            isError: false,
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'Vehicle details',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Keep the details for the one vehicle assigned to your Courier account current.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(_vehicleType),
                    initialValue: _vehicleType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Vehicle type',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      errorText: controller.updateFieldErrors['vehicle_type']
                          ?.join(' '),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'motorcycle',
                        child: Text('Motorcycle'),
                      ),
                      DropdownMenuItem(value: 'car', child: Text('Car')),
                      DropdownMenuItem(value: 'van', child: Text('Van')),
                    ],
                    onChanged: updateBusy
                        ? null
                        : (value) {
                            if (value != null) {
                              _vehicleSetState(() {
                                _vehicleType = value;
                              });
                            }
                          },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Choose a vehicle type.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _plateController,
                    enabled: !updateBusy,
                    maxLength: 64,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Plate number',
                      prefixIcon: const Icon(
                        Icons.confirmation_number_outlined,
                      ),
                      errorText: controller.updateFieldErrors['plate_number']
                          ?.join(' '),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the plate number.';
                      }
                      if (value.trim().length > 64) {
                        return 'Plate number must be 64 characters or fewer.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _makeController,
                    enabled: !updateBusy,
                    maxLength: 255,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Make (optional)',
                      prefixIcon: const Icon(Icons.build_outlined),
                      errorText: controller.updateFieldErrors['make']?.join(
                        ' ',
                      ),
                    ),
                    validator: (value) => _maxLength(value, 'Make', 255),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _modelController,
                    enabled: !updateBusy,
                    maxLength: 255,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Model (optional)',
                      prefixIcon: const Icon(Icons.car_repair_outlined),
                      errorText: controller.updateFieldErrors['model']?.join(
                        ' ',
                      ),
                    ),
                    validator: (value) => _maxLength(value, 'Model', 255),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    button: true,
                    label: updateBusy
                        ? 'Saving vehicle details'
                        : 'Save vehicle details',
                    child: FilledButton.icon(
                      onPressed: updateBusy ? null : _saveVehicle,
                      icon: updateBusy
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
                        updateBusy ? 'Saving…' : 'Save vehicle details',
                      ),
                    ),
                  ),
                  if (controller.hasPendingUpdate &&
                      (controller.updateStatus == VehicleActionStatus.offline ||
                          controller.updateStatus ==
                              VehicleActionStatus.timeout ||
                          controller.updateStatus ==
                              VehicleActionStatus.failed)) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: updateBusy ? null : controller.retryUpdate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry vehicle save'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'Vehicle documents',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'OR and CR are private images. Replace them independently when the current document changes.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final kind in VehicleDocumentKind.values) ...[
          _buildDocumentCard(context, vehicle, kind),
          if (kind != VehicleDocumentKind.values.last)
            const SizedBox(height: 16),
        ],
      ],
    );
  }
}
