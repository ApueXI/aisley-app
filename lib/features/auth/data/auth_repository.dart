import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Future<bool> hasStoredToken();

  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  });

  Future<CourierIdentity> currentCourier();

  Future<void> logout();

  Future<void> clearStoredToken();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required ApiClient client,
    required TokenStorage tokenStorage,
  }) : _client = client,
       _tokenStorage = tokenStorage;

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  @override
  Future<bool> hasStoredToken() async {
    final token = await _tokenStorage.read();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final response = await _client.postJson(
      '/courier/auth/login',
      body: <String, Object?>{
        'email': email.trim().toLowerCase(),
        'password': password,
        'device_name': deviceName,
      },
    );

    final payload = _decodeObject(response.body);
    final token = payload?['token'];
    final plainTextToken = token is String && token.isNotEmpty
        ? token
        : _plainTextToken(response.body);

    if (plainTextToken == null || plainTextToken.isEmpty) {
      throw const ApiContractException('login.token');
    }

    await _tokenStorage.write(plainTextToken);

    final courierJson = payload?['courier'];
    if (courierJson is Map<String, dynamic>) {
      return CourierIdentity.fromJson(courierJson);
    }

    return currentCourier();
  }

  @override
  Future<CourierIdentity> currentCourier() async {
    final response = await _client.get('/courier/auth/me', authenticated: true);
    final payload = _decodeObject(response.body);
    final courierJson = payload?['courier'];

    if (courierJson is! Map<String, dynamic>) {
      throw const ApiContractException('me.courier');
    }

    return CourierIdentity.fromJson(courierJson);
  }

  @override
  Future<void> logout() async {
    try {
      await _client.postJson('/courier/auth/logout', authenticated: true);
      await _tokenStorage.clear();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _tokenStorage.clear();
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> clearStoredToken() => _tokenStorage.clear();
}

Map<String, dynamic>? _decodeObject(String body) {
  if (body.trim().isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

String? _plainTextToken(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty || trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return null;
  }
  return trimmed;
}
