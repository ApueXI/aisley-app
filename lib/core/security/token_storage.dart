import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'linux_keyring_probe_stub.dart'
    if (dart.library.io) 'linux_keyring_probe_io.dart';

abstract interface class TokenStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'courier_sanctum_token';
  static const _operationTimeout = Duration(seconds: 5);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      await SecureStoragePlatformProbe.ensureAvailable();
      return await _storage.read(key: _tokenKey).timeout(_operationTimeout);
    } catch (error) {
      throw TokenStorageException('read', error);
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await SecureStoragePlatformProbe.ensureAvailable();
      await _storage
          .write(key: _tokenKey, value: token)
          .timeout(_operationTimeout);
    } catch (error) {
      throw TokenStorageException('write', error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await SecureStoragePlatformProbe.ensureAvailable();
      await _storage.delete(key: _tokenKey).timeout(_operationTimeout);
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
