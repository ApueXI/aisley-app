import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/domain/delivery_proof_photo.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

void main() {
  testWidgets(
    'camera capture can be previewed, replaced, removed, and uploaded',
    (tester) async {
      final repository = _WidgetDeliveryRepository();
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_outForDeliveryTask];
      final launcher = _WidgetPhotoCaptureLauncher(
        result: DeliveryPhotoCaptureResult.captured(
          XFile.fromData(
            Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
            path: '/tmp/captured.jpg',
            mimeType: 'image/jpeg',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: _authenticatedAuthController(),
            deliveryController: controller,
            task: _outForDeliveryTask,
            photoCaptureLauncher: launcher,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openCamera = find.widgetWithText(
        FilledButton,
        'Open camera for POD',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(openCamera);
      await tester.pumpAndSettle();

      expect(launcher.captureCalls, 1);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Retake photo'), findsOneWidget);
      expect(find.text('Replace from files'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);

      final submitPhoto = find.widgetWithText(
        FilledButton,
        'Submit photo proof',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(submitPhoto);
      await tester.pumpAndSettle();

      expect(repository.uploadedPhoto?.fileName, 'captured.jpg');
      expect(find.textContaining('Photo proof received.'), findsOneWidget);
      await tester.ensureVisible(find.text('Submitted photo'));
      await tester.pumpAndSettle();
      expect(find.text('Submitted photo'), findsOneWidget);
      expect(
        controller.proofPhotoStatuses['proof-1'],
        ProofPhotoLoadStatus.loaded,
      );
    },
  );

  testWidgets('camera denial is explicit and file fallback remains available', (
    tester,
  ) async {
    final controller = DeliveryController(
      deliveryRepository: _WidgetDeliveryRepository(),
    )..tasks = <PickupTask>[_outForDeliveryTask];

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: _authenticatedAuthController(),
          deliveryController: controller,
          task: _outForDeliveryTask,
          photoCaptureLauncher: _WidgetPhotoCaptureLauncher(
            result: const DeliveryPhotoCaptureResult.permissionDenied(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openCamera = find.widgetWithText(FilledButton, 'Open camera for POD');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(openCamera);
    await tester.pumpAndSettle();

    expect(find.textContaining('Camera permission was denied'), findsOneWidget);
    expect(find.text('Choose photo file'), findsOneWidget);
    expect(find.textContaining('Photo proof received.'), findsNothing);
  });

  testWidgets('non-Android targets show only the file chooser', (tester) async {
    final controller = DeliveryController(
      deliveryRepository: _WidgetDeliveryRepository(),
    )..tasks = <PickupTask>[_outForDeliveryTask];

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: _authenticatedAuthController(),
          deliveryController: controller,
          task: _outForDeliveryTask,
          photoCaptureLauncher: _WidgetPhotoCaptureLauncher(
            supported: false,
            result: const DeliveryPhotoCaptureResult.unavailable(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open camera for POD'), findsNothing);
    expect(find.text('Choose photo'), findsOneWidget);
  });

  testWidgets(
    'shows Delivered intent after photo proof 202 while Logistics validation is pending',
    (tester) async {
      final repository = _WidgetDeliveryRepository();
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_outForDeliveryTask];
      final proofSubmitted = await controller.submitProof(
        _outForDeliveryTask,
        photo: DeliveryPhotoSelection(
          path: null,
          fileName: 'proof.jpg',
          bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
        ),
      );

      expect(proofSubmitted, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: _authenticatedAuthController(),
            deliveryController: controller,
            task: _outForDeliveryTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ORD-100'), findsOneWidget);
      expect(find.text('WB-100'), findsOneWidget);
      expect(find.textContaining('Photo proof received.'), findsOneWidget);
      final submitIntent = find.text('Submit Delivered intent');
      await tester.ensureVisible(submitIntent);
      await tester.pumpAndSettle();
      expect(submitIntent, findsOneWidget);
      expect(find.text('Delivery completed by the server.'), findsNothing);

      await tester.tap(submitIntent);
      await tester.pumpAndSettle();
      expect(find.text('Confirm COD collection'), findsOneWidget);
      expect(find.text('Amount to collect: PHP 115.00'), findsOneWidget);
      expect(find.text('I collected PHP 115.00 in full.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit intent'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('I collected PHP 115.00 in full.'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit intent'));
      await tester.pumpAndSettle();

      expect(repository.completionEvidenceId, 'proof-1');
      expect(repository.codCollected, isTrue);
      expect(
        find.textContaining('Completion intent accepted by the server.'),
        findsOneWidget,
      );
      expect(find.text('Delivery completed by the server.'), findsNothing);
    },
  );

  testWidgets('failed photo upload shows the error, not pending delivery', (
    tester,
  ) async {
    final repository = _WidgetDeliveryRepository()
      ..proofError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'The photo field is invalid.',
      );
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask];
    final submitted = await controller.submitProof(
      _outForDeliveryTask,
      photo: DeliveryPhotoSelection(
        path: null,
        fileName: 'proof.jpg',
        bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
      ),
    );

    expect(submitted, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: _authenticatedAuthController(),
          deliveryController: controller,
          task: _outForDeliveryTask,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The photo field is invalid.'), findsOneWidget);
    expect(find.textContaining('Photo proof received.'), findsNothing);
    expect(find.text('Submit Delivered intent'), findsNothing);
  });

  testWidgets(
    'missing COD total blocks the intent without using parcel price',
    (tester) async {
      final repository = _WidgetDeliveryRepository()
        ..deliveryContext = const DeliveryContext(
          taskId: 'delivery-task-1',
          status: 'out_for_delivery',
          revision: 7,
          paymentMethod: 'cod',
          paymentStatus: 'pending',
          currency: 'PHP',
        );
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_outForDeliveryTask];
      await controller.submitProof(
        _outForDeliveryTask,
        photo: DeliveryPhotoSelection(
          path: null,
          fileName: 'proof.jpg',
          bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: _authenticatedAuthController(),
            deliveryController: controller,
            task: _outForDeliveryTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitIntent = find.text('Submit Delivered intent');
      await tester.ensureVisible(submitIntent);
      await tester.pumpAndSettle();
      await tester.tap(submitIntent);
      await tester.pumpAndSettle();

      expect(find.text('Confirm COD collection'), findsNothing);
      expect(find.textContaining('payable total'), findsWidgets);
      expect(repository.completionEvidenceId, isNull);
    },
  );
}

AuthController _authenticatedAuthController() {
  final controller = AuthController(
    authRepository: _WidgetAuthRepository(),
    dashboardRepository: _WidgetDashboardRepository(),
  );
  controller.status = AuthStatus.authenticated;
  controller.courier = CourierIdentity.fromJson(const <String, dynamic>{
    'id': 'courier-1',
    'email': 'courier@example.com',
    'role': 'courier',
    'status': 'active',
    'profile': <String, dynamic>{'first_name': 'Ana', 'last_name': 'Santos'},
    'logistics': <String, dynamic>{
      'status': 'approved',
      'organization': 'Aisley Express',
      'hub': 'Makati Hub',
    },
  });
  return controller;
}

class _WidgetDeliveryRepository implements DeliveryRepository {
  String? completionEvidenceId;
  bool? codCollected;
  DeliveryPhotoSelection? uploadedPhoto;
  ApiException? proofError;
  DeliveryContext deliveryContext = const DeliveryContext(
    taskId: 'delivery-task-1',
    status: 'out_for_delivery',
    revision: 7,
    hub: PickupLocation(name: 'Makati Hub'),
    destination: PickupLocation(
      cityMunicipality: 'Pasig',
      province: 'Metro Manila',
    ),
    paymentMethod: 'cod',
    paymentStatus: 'pending',
    payableTotal: '115.00',
    currency: 'PHP',
  );

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    return <PickupTask>[_outForDeliveryTask];
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async {
    return _outForDeliveryTask;
  }

  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async {
    return deliveryContext;
  }

  @override
  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    return DeliveryStatusUpdate(
      taskId: taskId,
      status: status,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<ProofSubmission> submitProof({
    required String taskId,
    required DeliveryPhotoSelection photo,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (proofError != null) throw proofError!;
    uploadedPhoto = photo;
    return const ProofSubmission(
      taskId: 'delivery-task-1',
      proofId: 'proof-1',
      evidenceStatus: 'awaiting_validation',
      custodyState: 'out_for_delivery',
      completionEligible: false,
    );
  }

  @override
  Future<CompletionProjection> fetchCompletion(String taskId) async {
    final hasEvidence = uploadedPhoto != null;
    return CompletionProjection(
      taskId: 'delivery-task-1',
      taskStatus: 'out_for_delivery',
      completionStatus: completionEvidenceId == null
          ? null
          : 'awaiting_validation',
      evidenceStatus: hasEvidence ? 'awaiting_validation' : null,
      evidenceId: hasEvidence ? 'proof-1' : null,
      revision: 7,
    );
  }

  @override
  Future<DeliveryProofPhoto> fetchProofPhoto(String proofId) async {
    return DeliveryProofPhoto(
      bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
      contentType: 'image/jpeg',
    );
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
    required bool codCollected,
  }) async {
    completionEvidenceId = evidenceId;
    this.codCollected = codCollected;
    return const CompletionProjection(
      taskId: 'delivery-task-1',
      intentId: 'intent-1',
      taskStatus: 'out_for_delivery',
      completionStatus: 'awaiting_validation',
      evidenceStatus: 'awaiting_validation',
      evidenceId: 'proof-1',
      revision: 7,
    );
  }
}

class _WidgetPhotoCaptureLauncher implements DeliveryPhotoCaptureLauncher {
  _WidgetPhotoCaptureLauncher({required this.result, this.supported = true});

  final DeliveryPhotoCaptureResult result;
  final bool supported;
  int captureCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<DeliveryPhotoCaptureResult> capture(BuildContext context) async {
    captureCalls++;
    return result;
  }
}

class _WidgetAuthRepository implements AuthRepository {
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
  Future<CourierIdentity> currentCourier() async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _WidgetDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    return const DashboardSnapshot(
      sections: <String, DashboardSection>{},
      freshness: DashboardFreshness(state: DashboardFreshnessState.scaffold),
    );
  }
}

const _outForDeliveryTask = PickupTask(
  id: 'delivery-task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'out_for_delivery',
  revision: 7,
  order: PickupOrderReference(reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
  destinationArea: PickupLocation(
    cityMunicipality: 'Pasig',
    province: 'Metro Manila',
  ),
);
