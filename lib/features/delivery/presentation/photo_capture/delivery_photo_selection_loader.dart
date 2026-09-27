import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/networking/multipart_file_adapter.dart';
import '../../domain/delivery_models.dart';

Future<DeliveryPhotoSelection> loadDeliveryPhotoSelection(
  XFile file, {
  required bool captured,
}) async {
  final length = await file.length();
  if (length == 0 || length >= maxImageUploadBytes) {
    throw const FormatException('Choose a non-empty photo under 10 MiB.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length >= maxImageUploadBytes) {
    throw const FormatException('Choose a non-empty photo under 10 MiB.');
  }
  final detectedExtension = deliveryPhotoExtension(bytes);
  if (detectedExtension == null) {
    throw const FormatException(
      'The photo must contain valid JPEG, PNG, or WebP image data.',
    );
  }
  final name = file.name.trim();
  final suppliedExtension = _normalizedExtension(name);
  if (!captured && suppliedExtension == null) {
    throw const FormatException('Choose a JPEG, PNG, or WebP photo.');
  }
  if (suppliedExtension != null &&
      !_extensionsMatch(suppliedExtension, detectedExtension)) {
    throw const FormatException(
      'The selected filename does not match the photo data.',
    );
  }
  final fileName = suppliedExtension == null
      ? 'pod-photo.${detectedExtension == 'jpeg' ? 'jpg' : detectedExtension}'
      : name;
  return DeliveryPhotoSelection(
    path: kIsWeb ? null : file.path,
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
  );
}

String? deliveryPhotoExtension(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'jpeg';
  }
  const pngHeader = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= pngHeader.length) {
    var matches = true;
    for (var index = 0; index < pngHeader.length; index++) {
      if (bytes[index] != pngHeader[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return 'png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  return null;
}

String? _normalizedExtension(String fileName) {
  final separator = fileName.lastIndexOf('.');
  if (separator < 0 || separator == fileName.length - 1) return null;
  final extension = fileName.substring(separator + 1).toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'jpeg',
    'png' => 'png',
    'webp' => 'webp',
    _ => null,
  };
}

bool _extensionsMatch(String supplied, String detected) => supplied == detected;
