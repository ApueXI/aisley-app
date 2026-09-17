import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/vehicle_models.dart';
import 'vehicle_controller.dart';

const _maxVehicleDocumentBytes = 10 * 1024 * 1024;
const _vehicleDocumentTypeGroup = XTypeGroup(
  label: 'Vehicle documents',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
);

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({
    required this.authController,
    required this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final VehicleController vehicleController;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final Map<VehicleDocumentKind, VehicleDocumentSelection?> _pendingDocuments =
      <VehicleDocumentKind, VehicleDocumentSelection?>{};
  final Map<VehicleDocumentKind, String?> _selectionErrors =
      <VehicleDocumentKind, String?>{};
  final Map<VehicleDocumentKind, bool> _isPicking =
      <VehicleDocumentKind, bool>{};
  final Map<VehicleDocumentKind, VoidCallback?> _cancelUploads =
      <VehicleDocumentKind, VoidCallback?>{};

  String _vehicleType = 'motorcycle';
  bool _hasPopulatedVehicle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadVehicle();
      }
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    await widget.vehicleController.load();
    if (!mounted) {
      return;
    }
    final vehicle = widget.vehicleController.vehicle;
    if (vehicle != null && !_hasPopulatedVehicle) {
      _populateVehicle(vehicle);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _refreshVehicle() async {
    final hadLocalEdits = _hasLocalVehicleEdits();
    await widget.vehicleController.load();
    if (!mounted) {
      return;
    }
    final vehicle = widget.vehicleController.vehicle;
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
    final vehicle = widget.vehicleController.vehicle;
    if (vehicle == null || !_hasPopulatedVehicle) {
      return false;
    }
    return _vehicleType != vehicle.vehicleType ||
        _plateController.text.trim() != vehicle.plateNumber ||
        _makeController.text.trim() != (vehicle.make ?? '') ||
        _modelController.text.trim() != (vehicle.model ?? '');
  }

  Future<void> _saveVehicle() async {
    if (widget.vehicleController.updateStatus == VehicleActionStatus.saving ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final vehicle = widget.vehicleController.vehicle;
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
    final saved = await widget.vehicleController.updateVehicle(
      changes: changes,
    );
    if (!mounted) {
      return;
    }
    final updatedVehicle = widget.vehicleController.vehicle;
    if (saved && updatedVehicle != null) {
      _populateVehicle(updatedVehicle);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _pickDocument(VehicleDocumentKind kind) async {
    if (_isPicking[kind] == true ||
        widget.vehicleController.documentActionStatus(kind) ==
            VehicleActionStatus.uploading) {
      return;
    }
    setState(() {
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
      if (file.path.trim().isEmpty) {
        _setSelectionError(
          kind,
          'The selected document could not be opened. Choose it again.',
        );
        return;
      }

      final fileSize = await file.length();
      if (fileSize >= _maxVehicleDocumentBytes) {
        _setSelectionError(
          kind,
          'The document must be under 10 MB (10,485,760 bytes).',
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length >= _maxVehicleDocumentBytes) {
        _setSelectionError(
          kind,
          'The document must be under 10 MB (10,485,760 bytes).',
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

      if (!mounted) {
        return;
      }
      setState(() {
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
      if (mounted) {
        setState(() {
          _isPicking[kind] = false;
        });
      }
    }
  }

  Future<void> _uploadDocument(VehicleDocumentKind kind) async {
    final selection = _pendingDocuments[kind];
    if (selection == null ||
        widget.vehicleController.documentActionStatus(kind) ==
            VehicleActionStatus.uploading) {
      return;
    }
    setState(() {
      _cancelUploads[kind] = null;
      _selectionErrors[kind] = null;
    });

    final uploaded = await widget.vehicleController.uploadDocument(
      kind,
      selection,
      onCancel: (cancel) {
        if (mounted) {
          setState(() {
            _cancelUploads[kind] = cancel;
          });
        }
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
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
    final documentStatus = widget.vehicleController.documentActionStatus(kind);
    final hasPendingAttempt =
        documentStatus == VehicleActionStatus.offline ||
        documentStatus == VehicleActionStatus.timeout ||
        documentStatus == VehicleActionStatus.failed;
    final retried = hasPendingAttempt
        ? await widget.vehicleController.retryDocument(kind)
        : await widget.vehicleController.uploadDocument(kind, selection);
    if (!mounted) {
      return;
    }
    if (retried) {
      setState(() {
        _pendingDocuments[kind] = null;
      });
    }
    await _closeIfSessionEnded();
  }

  Future<void> _viewDocument(VehicleDocumentKind kind) async {
    await widget.vehicleController.loadDocument(kind);
    await _closeIfSessionEnded();
  }

  Future<void> _discardDocument(VehicleDocumentKind kind) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingDocuments[kind] = null;
      _selectionErrors[kind] = null;
    });
  }

  void _setSelectionError(VehicleDocumentKind kind, String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionErrors[kind] = message;
    });
  }

  Future<void> _closeIfSessionEnded() async {
    if (!mounted || widget.authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.vehicleController,
      builder: (context, child) {
        final vehicle = widget.vehicleController.vehicle;
        return Scaffold(
          appBar: AppBar(title: const Text('Vehicle management')),
          body: vehicle == null
              ? _buildVehicleState(context)
              : RefreshIndicator(
                  onRefresh: _refreshVehicle,
                  child: _buildVehicleForm(context, vehicle),
                ),
        );
      },
    );
  }

  Widget _buildVehicleState(BuildContext context) {
    final controller = widget.vehicleController;
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
    final controller = widget.vehicleController;
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
                              setState(() {
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

  Widget _buildDocumentCard(
    BuildContext context,
    CourierVehicle vehicle,
    VehicleDocumentKind kind,
  ) {
    final controller = widget.vehicleController;
    final scheme = Theme.of(context).colorScheme;
    final selection = _pendingDocuments[kind];
    final preview = controller.documentPreview(kind);
    final actionStatus = controller.documentActionStatus(kind);
    final previewStatus = controller.documentPreviewStatus(kind);
    final busy = actionStatus == VehicleActionStatus.uploading;
    final currentDocument = vehicle.document(kind);
    final actionError =
        controller.documentFieldError(kind, 'file') ??
        controller.documentActionError(kind) ??
        _selectionErrors[kind];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentDocument == null
                            ? 'No current ${kind.shortLabel} is on file.'
                            : 'A private ${kind.shortLabel} is on file.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selection != null) ...[
              const SizedBox(height: 16),
              _LocalDocumentPreview(selection: selection),
              const SizedBox(height: 8),
              Text(
                '${selection.fileName} · ${_formatFileSize(selection.sizeInBytes)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Local preview — upload to save this document.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ] else if (previewStatus ==
                VehicleDocumentPreviewStatus.loading) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                label: 'Loading private ${kind.shortLabel}',
                child: const LinearProgressIndicator(),
              ),
            ] else if (previewStatus ==
                    VehicleDocumentPreviewStatus.available &&
                preview != null) ...[
              const SizedBox(height: 16),
              _PrivateDocumentPreview(bytes: preview.bytes, kind: kind),
            ],
            if (busy) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label: 'Uploading ${kind.shortLabel}',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 8),
              Text('Uploading…', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (actionError != null) ...[
              const SizedBox(height: 14),
              _VehicleBanner(message: actionError, isError: true),
            ],
            if (controller.documentPreviewError(kind) != null &&
                actionError == null) ...[
              const SizedBox(height: 14),
              _VehicleBanner(
                message: controller.documentPreviewError(kind)!,
                isError: true,
              ),
            ],
            if (controller.documentActionSuccessMessage(kind) != null) ...[
              const SizedBox(height: 14),
              _VehicleBanner(
                message: controller.documentActionSuccessMessage(kind)!,
                isError: false,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (currentDocument != null && selection == null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _viewDocument(kind),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(
                      previewStatus == VehicleDocumentPreviewStatus.loading
                          ? 'Loading…'
                          : 'View current ${kind.shortLabel}',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy || _isPicking[kind] == true
                      ? null
                      : () => _pickDocument(kind),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    currentDocument == null
                        ? 'Choose ${kind.shortLabel}'
                        : 'Replace ${kind.shortLabel}',
                  ),
                ),
                if (selection != null)
                  FilledButton.icon(
                    onPressed: busy ? null : () => _uploadDocument(kind),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text('Upload ${kind.shortLabel}'),
                  ),
                if (selection != null)
                  TextButton(
                    onPressed: busy ? null : () => _discardDocument(kind),
                    child: const Text('Discard'),
                  ),
                if (selection != null &&
                    (actionStatus == VehicleActionStatus.offline ||
                        actionStatus == VehicleActionStatus.timeout ||
                        actionStatus == VehicleActionStatus.failed))
                  TextButton.icon(
                    onPressed: busy ? null : () => _retryDocument(kind),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry upload'),
                  ),
                if (busy && _cancelUploads[kind] != null)
                  TextButton.icon(
                    onPressed: _cancelUploads[kind],
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel upload'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'JPEG, JPG, PNG, or WebP under 10 MB. The server validates the file before saving it.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalDocumentPreview extends StatelessWidget {
  const _LocalDocumentPreview({required this.selection});

  final VehicleDocumentSelection selection;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Local vehicle document preview',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          selection.bytes,
          width: 124,
          height: 92,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _brokenPreview(context),
        ),
      ),
    );
  }
}

class _PrivateDocumentPreview extends StatelessWidget {
  const _PrivateDocumentPreview({required this.bytes, required this.kind});

  final Uint8List bytes;
  final VehicleDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Current private ${kind.shortLabel} preview',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: 124,
          height: 92,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _brokenPreview(context),
        ),
      ),
    );
  }
}

Widget _brokenPreview(BuildContext context) {
  return Container(
    width: 124,
    height: 92,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}

class _VehicleBanner extends StatelessWidget {
  const _VehicleBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      label: '${isError ? 'Vehicle error' : 'Vehicle update'}: $message',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

String? _maxLength(String? value, String label, int maximum) {
  if (value != null && value.trim().length > maximum) {
    return '$label must be $maximum characters or fewer.';
  }
  return null;
}

String? _emptyAsNull(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').last;
}

bool _isAllowedImageName(String fileName) {
  final lower = fileName.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp');
}

bool _hasSupportedImageSignature(List<int> bytes) {
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final png =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  final webp =
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
  return jpeg || png || webp;
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
