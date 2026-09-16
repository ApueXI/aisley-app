import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/vehicle/data/vehicle_repository.dart';
import 'package:aisley_app/features/vehicle/domain/vehicle_models.dart';
import 'package:aisley_app/features/vehicle/presentation/vehicle_controller.dart';
import 'package:aisley_app/features/vehicle/presentation/vehicle_screen.dart';

void main() {
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
  @override
  Future<CourierVehicle> fetchVehicle() async => const CourierVehicle(
    id: 'vehicle-1',
    vehicleType: 'motorcycle',
    plateNumber: 'ABC-1234',
    make: 'Honda',
    model: 'Click',
    revision: 4,
    officialReceipt: VehicleDocumentReference(
      id: 'or-1',
      url: '/api/v1/courier/vehicle/documents/official_receipt',
    ),
  );

  @override
  Future<CourierVehicle> updateVehicle({
    required Map<String, Object?> changes,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => fetchVehicle();

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
