import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'courier_sanctum_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (error) {
      throw TokenStorageException('read', error);
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (error) {
      throw TokenStorageException('write', error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (error) {
      throw TokenStorageException('clear', error);
    }
  }
}

class TokenStorageException implements Exception {
  TokenStorageException(this.operation, this.cause);

  final String operation;
  final Object cause;

  @override
  String toString() => 'TokenStorageException(operation: $operation)';
}
