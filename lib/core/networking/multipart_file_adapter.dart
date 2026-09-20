import 'package:http/http.dart' as http;

import 'multipart_file_selection.dart';

const maxImageUploadBytes = 10 * 1024 * 1024;

class MultipartFileAdapter {
  const MultipartFileAdapter._();

  static Future<http.MultipartFile> build({
    required String field,
    required MultipartFileSelection selection,
    required bool useNativePath,
  }) async {
    final fileName = _fileName(selection.fileName);
    final contentType = _contentType(fileName);

    if (useNativePath) {
      final path = selection.path?.trim();
      if (path != null && path.isNotEmpty) {
        return http.MultipartFile.fromPath(
          field,
          path,
          filename: fileName,
          contentType: contentType,
        );
      }
    }

    if (selection.bytes.isEmpty) {
      throw ArgumentError.value(
        selection.fileName,
        'selection',
        'must contain readable bytes when a native path is unavailable',
      );
    }
    if (selection.bytes.length >= maxImageUploadBytes) {
      throw ArgumentError.value(
        selection.fileName,
        'selection',
        'must be smaller than 10 MiB',
      );
    }

    return http.MultipartFile.fromBytes(
      field,
      selection.bytes,
      filename: fileName,
      contentType: contentType,
    );
  }
}

String _fileName(String value) {
  final normalized = value.trim().replaceAll('\\', '/');
  final separator = normalized.lastIndexOf('/');
  final name = separator < 0 ? normalized : normalized.substring(separator + 1);
  return name.isEmpty ? 'selected-image' : name;
}

http.MediaType? _contentType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return http.MediaType('image', 'jpeg');
  }
  if (lower.endsWith('.png')) {
    return http.MediaType('image', 'png');
  }
  if (lower.endsWith('.webp')) {
    return http.MediaType('image', 'webp');
  }
  return null;
}
