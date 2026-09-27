import 'dart:typed_data';

import '../../../core/networking/api_contract_exception.dart';
import '../../../core/networking/multipart_file_adapter.dart';

const _allowedProofPhotoTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
};

enum ProofPhotoLoadStatus {
  idle,
  loading,
  loaded,
  unavailable,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

class DeliveryProofPhoto {
  DeliveryProofPhoto({required Uint8List bytes, required this.contentType})
    : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String contentType;

  factory DeliveryProofPhoto.fromResponse({
    required List<int> bytes,
    required String? contentTypeHeader,
  }) {
    final contentType = contentTypeHeader
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType == null || !_allowedProofPhotoTypes.contains(contentType)) {
      throw const ApiContractException('delivery.proof_photo.content_type');
    }
    if (bytes.isEmpty || bytes.length >= maxImageUploadBytes) {
      throw const ApiContractException('delivery.proof_photo.body');
    }
    final copiedBytes = Uint8List.fromList(bytes);
    if (!_matchesContentType(contentType, copiedBytes)) {
      throw const ApiContractException('delivery.proof_photo.signature');
    }
    return DeliveryProofPhoto(bytes: copiedBytes, contentType: contentType);
  }
}

bool _matchesContentType(String contentType, Uint8List bytes) {
  if (contentType == 'image/jpeg') {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }
  if (contentType == 'image/png') {
    const header = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < header.length) return false;
    for (var index = 0; index < header.length; index++) {
      if (bytes[index] != header[index]) return false;
    }
    return true;
  }
  return bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
}
