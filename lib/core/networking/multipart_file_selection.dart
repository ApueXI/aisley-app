/// A file selected for a multipart upload.
///
/// [path] is usable only on platforms that provide a readable native file
/// path. Browser selections must use [bytes] instead.
class MultipartFileSelection {
  const MultipartFileSelection({
    required this.path,
    required this.fileName,
    required this.bytes,
  });

  final String? path;
  final String fileName;
  final List<int> bytes;
}
