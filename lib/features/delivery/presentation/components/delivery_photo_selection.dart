part of '../delivery_screen.dart';

mixin _DeliveryPhotoSelection on State<DeliveryTaskScreen> {
  DeliveryPhotoSelection? _selectedPhoto;
  String? _photoSelectionError;
  bool _isPickingPhoto = false;
  void Function()? _cancelPhotoUpload;
  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) return;
    setState(() {
      _isPickingPhoto = true;
      _photoSelectionError = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_deliveryPhotoTypeGroup],
      );
      if (file == null) return;
      final name = file.name.trim();
      final extension = name.split('.').last.toLowerCase();
      if (!<String>{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        throw const FormatException('Choose a JPEG, PNG, or WebP photo.');
      }
      final length = await file.length();
      if (length == 0 || length >= maxImageUploadBytes) {
        throw const FormatException('Choose a non-empty photo under 10 MiB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty ||
          bytes.length >= maxImageUploadBytes ||
          !_matchesPhotoSignature(extension, bytes)) {
        throw const FormatException(
          'The selected file does not match a JPEG, PNG, or WebP photo under 10 MiB.',
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedPhoto = DeliveryPhotoSelection(
          path: file.path,
          fileName: name,
          bytes: Uint8List.fromList(bytes),
        );
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _photoSelectionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoSelectionError =
              'The photo could not be opened. Choose it again and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _submitPhoto(PickupTask task) async {
    final photo = _selectedPhoto;
    if (photo == null) return;
    final submitted = await widget.deliveryController.submitProof(
      task,
      photo: photo,
      onCancel: (cancel) {
        if (mounted) setState(() => _cancelPhotoUpload = cancel);
      },
    );
    if (!mounted) return;
    setState(() {
      _cancelPhotoUpload = null;
      if (submitted) _selectedPhoto = null;
    });
  }
}

bool _matchesPhotoSignature(String extension, Uint8List bytes) {
  if (extension == 'jpg' || extension == 'jpeg') {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }
  if (extension == 'png') {
    const header = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    return bytes.length >= header.length &&
        List.generate(
          header.length,
          (index) => index,
        ).every((index) => bytes[index] == header[index]);
  }
  return bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
}
