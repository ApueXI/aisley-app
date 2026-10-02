import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/vehicle/data/vehicle_repository.dart';
import 'package:aisley_app/features/vehicle/domain/vehicle_models.dart';
import 'package:aisley_app/features/vehicle/presentation/controllers/vehicle_controller.dart';
import 'package:aisley_app/features/vehicle/presentation/vehicle_screen.dart';

void main() {
  testWidgets('loads an existing truck vehicle without a dropdown assertion', (
    WidgetTester tester,
  ) async {
    final controller = VehicleController(
      vehicleRepository: _FakeVehicleRepository(vehicleType: 'truck'),
    );
    final auth = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    )..status = AuthStatus.authenticated;
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleScreen(
          authController: auth,
          vehicleController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('truck')), findsOneWidget);
    expect(controller.vehicle?.vehicleType, 'truck');
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects Truck and saves only the revision-checked type edit', (
    WidgetTester tester,
  ) async {
    final repository = _FakeVehicleRepository();
    final controller = VehicleController(vehicleRepository: repository);
    final auth = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    )..status = AuthStatus.authenticated;
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleScreen(
          authController: auth,
          vehicleController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Truck').last);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save vehicle details');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.savedChanges, <String, Object?>{'vehicle_type': 'truck'});
    expect(repository.savedRevision, 4);
    expect(controller.vehicle?.id, 'vehicle-1');
    expect(controller.vehicle?.vehicleType, 'truck');
    expect(controller.vehicle?.revision, 5);
    expect(controller.vehicle?.officialReceipt?.id, 'or-1');
    expect(controller.vehicle?.certificateOfRegistration, isNull);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('Your vehicle details were updated.'), findsOneWidget);
  });

  testWidgets('shows independently managed vehicle details and documents', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    )..status = AuthStatus.authenticated;
    final vehicleController = VehicleController(
      vehicleRepository: _FakeVehicleRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VehicleScreen(
          authController: authController,
          vehicleController: vehicleController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vehicle management'), findsOneWidget);
    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('Plate number'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Official Receipt'), findsOneWidget);
    expect(find.text('Certificate of Registration'), findsOneWidget);
    expect(find.text('A private OR is on file.'), findsOneWidget);
    expect(find.text('No current CR is on file.'), findsOneWidget);
  });
}

class _FakeVehicleRepository implements VehicleRepository {
  _FakeVehicleRepository({this.vehicleType = 'motorcycle'});

  String vehicleType;
  int revision = 4;
  Map<String, Object?>? savedChanges;
  int? savedRevision;

  @override
  Future<CourierVehicle> fetchVehicle() async => CourierVehicle(
    id: 'vehicle-1',
    vehicleType: vehicleType,
    plateNumber: 'ABC-1234',
    make: 'Honda',
    model: 'Click',
    revision: revision,
    officialReceipt: const VehicleDocumentReference(
      id: 'or-1',
      url: '/api/v1/courier/vehicle/documents/official_receipt',
    ),
  );

  @override
  Future<CourierVehicle> updateVehicle({
    required Map<String, Object?> changes,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    savedChanges = Map<String, Object?>.from(changes);
    savedRevision = expectedRevision;
    vehicleType = changes['vehicle_type'] as String? ?? vehicleType;
    revision++;
    return fetchVehicle();
  }

  @override
  Future<CourierVehicle> uploadDocument({
    required VehicleDocumentKind kind,
    required VehicleDocumentSelection selection,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async => fetchVehicle();

  @override
  Future<VehicleDocumentData> fetchDocument(VehicleDocumentKind kind) async {
    return VehicleDocumentData(
      bytes: Uint8List.fromList(<int>[1]),
      contentType: 'image/png',
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<bool> hasStoredToken() async => false;

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async {
    return const <LogisticsOption>[];
  }

  @override
  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CourierIdentity> currentCourier() async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    throw UnimplementedError();
  }
}
