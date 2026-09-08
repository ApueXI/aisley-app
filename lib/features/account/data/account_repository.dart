import 'dart:convert';

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
