import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/account_models.dart';

abstract interface class AccountRepository {
  Future<CourierAccount> fetchAccount();

  Future<CourierAccount> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    String? idempotencyKey,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  });

  Future<CourierAccount> uploadProfilePhoto({
    required ProfilePhotoSelection selection,
    String? idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  });

  Future<ProfilePhotoData> fetchProfilePhoto(String profilePhotoUrl);

  Future<void> deleteProfilePhoto();
}

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository({required this._client});

  final ApiClient _client;

  @override
  Future<CourierAccount> fetchAccount() async {
    final response = await _client.get('/courier/account', authenticated: true);
    return _accountFromResponse(response.body);
  }

  @override
  Future<CourierAccount> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    String? idempotencyKey,
  }) async {
    final normalizedMiddleName = middleName?.trim();
    final response = await _client.patchJson(
      '/courier/account/profile',
      authenticated: true,
      headers: idempotencyKey == null
          ? null
          : <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'first_name': firstName.trim(),
        'middle_name':
            normalizedMiddleName == null || normalizedMiddleName.isEmpty
            ? null
            : normalizedMiddleName,
        'last_name': lastName.trim(),
        'contact_number': contactNumber.trim(),
      },
    );
    return _accountFromResponse(response.body);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.putJson(
      '/courier/account/password',
      authenticated: true,
      body: <String, Object?>{
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  @override
  Future<CourierAccount> uploadProfilePhoto({
    required ProfilePhotoSelection selection,
    String? idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    final response = await _client.postMultipart(
      '/courier/account/profile-photo',
      fields: const <String, String>{},
      filePaths: <String, String>{'photo': selection.path},
      authenticated: true,
      requestHeaders: idempotencyKey == null
          ? null
          : <String, String>{'Idempotency-Key': idempotencyKey},
      onCancel: onCancel,
    );

    if (response.body.trim().isEmpty) {
      return fetchAccount();
    }
    return _accountFromResponse(response.body);
  }

  @override
  Future<ProfilePhotoData> fetchProfilePhoto(String profilePhotoUrl) async {
    final response = await _fetchPrivatePhoto(profilePhotoUrl);
    final contentType = _contentType(response.headers['content-type']);
    if (contentType == null ||
        !_allowedPhotoContentTypes.contains(contentType)) {
      throw const ApiContractException('account.profile_photo.content_type');
    }
    if (response.bodyBytes.isEmpty) {
      throw const ApiContractException('account.profile_photo.body');
    }

    return ProfilePhotoData(
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }

  @override
  Future<void> deleteProfilePhoto() async {
    await _client.delete('/courier/account/profile-photo', authenticated: true);
  }

  Future<http.Response> _fetchPrivatePhoto(String profilePhotoUrl) async {
    try {
      return await _client.getServerUrl(profilePhotoUrl, authenticated: true);
    } on StateError {
      throw const ApiContractException('account.profile_photo.url');
    }
  }
}

const _allowedPhotoContentTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
};

String? _contentType(String? value) {
  final contentType = value?.split(';').first.trim().toLowerCase();
  return contentType == null || contentType.isEmpty ? null : contentType;
}

CourierAccount _accountFromResponse(String body) {
  if (body.trim().isEmpty) {
    throw const ApiContractException('account.response');
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiContractException('account.response');
    }
    return CourierAccount.fromResponse(decoded);
  } on FormatException {
    throw const ApiContractException('account.response');
  }
}
