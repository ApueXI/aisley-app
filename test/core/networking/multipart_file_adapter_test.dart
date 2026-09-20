import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/multipart_file_adapter.dart';
import 'package:aisley_app/core/networking/multipart_file_selection.dart';

void main() {
  test('builds browser-safe multipart files from selected bytes', () async {
    final file = await MultipartFileAdapter.build(
      field: 'photo',
      selection: const MultipartFileSelection(
        path: 'blob:browser-selection',
        fileName: 'courier.png',
        bytes: <int>[0x89, 0x50, 0x4e, 0x47],
      ),
      useNativePath: false,
    );

    expect(file.filename, 'courier.png');
    expect(file.contentType.mimeType, 'image/png');
    expect(file.length, 4);
    expect(await file.finalize().toBytes(), <int>[0x89, 0x50, 0x4e, 0x47]);
  });

  test(
    'preserves the native path multipart branch for Android and desktop',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'aisley_multipart_adapter_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/vehicle.webp';
      final bytes = <int>[0x52, 0x49, 0x46, 0x46, 0x57, 0x45, 0x42, 0x50];
      await File(path).writeAsBytes(bytes);

      final file = await MultipartFileAdapter.build(
        field: 'file',
        selection: MultipartFileSelection(
          path: path,
          fileName: 'vehicle.webp',
          bytes: bytes,
        ),
        useNativePath: true,
      );

      expect(file.filename, 'vehicle.webp');
      expect(file.contentType.mimeType, 'image/webp');
      expect(file.length, bytes.length);
      expect(await file.finalize().toBytes(), bytes);
    },
  );

  test(
    'falls back to selected bytes when a native path is unavailable',
    () async {
      final file = await MultipartFileAdapter.build(
        field: 'government_id',
        selection: const MultipartFileSelection(
          path: null,
          fileName: 'id.jpg',
          bytes: <int>[0xff, 0xd8, 0xff],
        ),
        useNativePath: true,
      );

      expect(await file.finalize().toBytes(), <int>[0xff, 0xd8, 0xff]);
    },
  );

  test('rejects an empty browser selection', () async {
    await expectLater(
      MultipartFileAdapter.build(
        field: 'photo',
        selection: const MultipartFileSelection(
          path: 'blob:empty',
          fileName: 'empty.png',
          bytes: <int>[],
        ),
        useNativePath: false,
      ),
      throwsArgumentError,
    );
  });
}
