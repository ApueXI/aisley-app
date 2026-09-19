import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/vehicle_models.dart';
import 'controllers/vehicle_controller.dart';

part 'components/vehicle_actions.dart';
part 'components/vehicle_details.dart';
part 'components/vehicle_documents.dart';
part 'components/vehicle_widgets.dart';

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

  VehicleController get _vehicleController => widget.vehicleController;

  AuthController get _authController => widget.authController;

  BuildContext get _vehicleContext => context;

  bool get _vehicleMounted => mounted;

  void _vehicleSetState(VoidCallback callback) => setState(callback);

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
}
