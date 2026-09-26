import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_selection_loader.dart';

void main() {
  test('loads a valid selected JPEG without changing its filename', () async {
    final selection = await loadDeliveryPhotoSelection(
      XFile.fromData(
        Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
        path: '/tmp/delivery.jpg',
        mimeType: 'image/jpeg',
      ),
      captured: false,
    );

    expect(selection.fileName, 'delivery.jpg');
    expect(selection.bytes, <int>[0xff, 0xd8, 0xff, 0xd9]);
  });

  test('gives captured image data a supported filename', () async {
    final selection = await loadDeliveryPhotoSelection(
      XFile.fromData(
        Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
        path: '/tmp/camera-output',
      ),
      captured: true,
    );

    expect(selection.fileName, 'pod-photo.jpg');
  });

  test('rejects a selected filename that disagrees with its image data', () {
    expect(
      () => loadDeliveryPhotoSelection(
        XFile.fromData(
          Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
          path: '/tmp/delivery.png',
        ),
        captured: false,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('does not match'),
        ),
      ),
    );
  });

  test('rejects invalid photo bytes before upload', () {
    expect(
      () => loadDeliveryPhotoSelection(
        XFile.fromData(
          Uint8List.fromList(<int>[1, 2, 3, 4]),
          path: '/tmp/delivery.jpg',
        ),
        captured: false,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('valid JPEG, PNG, or WebP'),
        ),
      ),
    );
  });
}
