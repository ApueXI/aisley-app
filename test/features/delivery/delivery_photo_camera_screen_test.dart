import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_camera_platform.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_camera_screen.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';

void main() {
  testWidgets('captures a still photo from the rear-camera session', (
    tester,
  ) async {
    final session = _FakeCameraSession();
    DeliveryPhotoCaptureResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<DeliveryPhotoCaptureResult>(
                  builder: (_) => DeliveryPhotoCameraScreen(
                    platform: _FakeCameraPlatform(session: session),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Rear camera preview for photo proof'),
      findsOneWidget,
    );

    await tester.tap(find.text('Take POD photo'));
    await tester.pumpAndSettle();

    expect(result?.status, DeliveryPhotoCaptureStatus.captured);
    expect(result?.file?.name, 'captured.jpg');
    expect(session.takePictureCalls, 1);
    expect(session.disposed, isTrue);
  });

  testWidgets('offers retry and file fallback when permission is denied', (
    tester,
  ) async {
    DeliveryPhotoCaptureResult? result;
    final platform = _FakeCameraPlatform(
      failure: const DeliveryPhotoCameraFailure(
        DeliveryPhotoCameraFailureKind.permissionDenied,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<DeliveryPhotoCaptureResult>(
                  builder: (_) => DeliveryPhotoCameraScreen(platform: platform),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission was denied'), findsOneWidget);
    expect(find.text('Retry camera'), findsOneWidget);
    expect(find.text('Use file chooser instead'), findsOneWidget);

    await tester.tap(find.text('Retry camera'));
    await tester.pumpAndSettle();
    expect(platform.openCalls, 2);

    await tester.tap(find.text('Use file chooser instead'));
    await tester.pumpAndSettle();
    expect(result?.status, DeliveryPhotoCaptureStatus.chooseFile);
  });

  testWidgets('keeps capture failure recoverable without leaving camera', (
    tester,
  ) async {
    final session = _FakeCameraSession(
      takeFailure: const DeliveryPhotoCameraFailure(
        DeliveryPhotoCameraFailureKind.captureFailed,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryPhotoCameraScreen(
          platform: _FakeCameraPlatform(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take POD photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not captured'), findsOneWidget);
    expect(find.text('Take POD photo'), findsOneWidget);
  });

  testWidgets('reports an unavailable rear camera with file fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryPhotoCameraScreen(
          platform: _FakeCameraPlatform(
            failure: const DeliveryPhotoCameraFailure(
              DeliveryPhotoCameraFailureKind.unavailable,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('rear camera is unavailable'), findsOneWidget);
    expect(find.text('Retry camera'), findsOneWidget);
    expect(find.text('Use file chooser instead'), findsOneWidget);
  });

  testWidgets('returns a cancelled state and releases the camera', (
    tester,
  ) async {
    final session = _FakeCameraSession();
    DeliveryPhotoCaptureResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<DeliveryPhotoCaptureResult>(
                  builder: (_) => DeliveryPhotoCameraScreen(
                    platform: _FakeCameraPlatform(session: session),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result?.status, DeliveryPhotoCaptureStatus.cancelled);
    expect(session.disposed, isTrue);
  });
}

class _FakeCameraPlatform implements DeliveryPhotoCameraPlatform {
  _FakeCameraPlatform({this.session, this.failure});

  final DeliveryPhotoCameraSession? session;
  final DeliveryPhotoCameraFailure? failure;
  int openCalls = 0;

  @override
  Future<DeliveryPhotoCameraSession> openRearCamera() async {
    openCalls++;
    if (failure != null) throw failure!;
    return session!;
  }
}

class _FakeCameraSession implements DeliveryPhotoCameraSession {
  _FakeCameraSession({this.takeFailure});

  final DeliveryPhotoCameraFailure? takeFailure;
  int takePictureCalls = 0;
  bool disposed = false;

  @override
  double get aspectRatio => 1;

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);

  @override
  Future<XFile> takePicture() async {
    takePictureCalls++;
    if (takeFailure != null) throw takeFailure!;
    return XFile.fromData(
      Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
      path: '/tmp/captured.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
