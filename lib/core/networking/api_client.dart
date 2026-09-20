import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../security/token_storage.dart';
import 'network_socket_exception.dart';

class ApiClient {
  ApiClient({
    required this._config,
    required this._tokenStorage,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final AppConfig _config;
  final TokenStorage _tokenStorage;
  final http.Client _client;
  final Duration requestTimeout;

  Future<http.Response> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _request(
      method: 'GET',
      path: path,
      authenticated: authenticated,
      queryParameters: queryParameters,
      requestHeaders: headers,
    );
  }

  /// Fetches a server-provided API URL without treating it as a new API path.
  ///
  /// Account photo URLs are private API URLs returned by Laravel. They may be
  /// relative to the configured API origin or absolute URLs for that same
  /// origin, but they must never redirect the client to an arbitrary host.
  Future<http.Response> getServerUrl(
    String serverUrl, {
    bool authenticated = false,
  }) {
    return _requestUri(
      method: 'GET',
      uri: _resolveServerUrl(serverUrl),
      authenticated: authenticated,
      requestHeaders: const <String, String>{
        'Accept': 'image/jpeg, image/png, image/webp',
      },
    );
  }

  Future<http.Response> postJson(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: jsonEncode(body),
      authenticated: authenticated,
      requestHeaders: headers,
    );
  }

  Future<http.Response> patchJson(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) {
    return _request(
      method: 'PATCH',
      path: path,
      body: jsonEncode(body),
      authenticated: authenticated,
      requestHeaders: headers,
    );
  }

  Future<http.Response> putJson(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      body: jsonEncode(body),
      authenticated: authenticated,
      requestHeaders: headers,
    );
  }

  Future<http.Response> delete(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) {
    return _request(
      method: 'DELETE',
      path: path,
      authenticated: authenticated,
      requestHeaders: headers,
    );
  }

  Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Map<String, String> filePaths,
    bool authenticated = false,
    Map<String, String>? requestHeaders,
    void Function(void Function() cancel)? onCancel,
  }) async {
    final uri = _config.endpoint(path);
    final headers = <String, String>{'Accept': 'application/json'};
    if (requestHeaders != null) {
      headers.addAll(requestHeaders);
    }

    if (authenticated) {
      final token = await _tokenStorage.read();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'A valid session is required.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields.addAll(fields);
    final uploadClient = onCancel == null ? null : http.Client();
    final requestClient = uploadClient ?? _client;
    onCancel?.call(uploadClient!.close);

    try {
      for (final entry in filePaths.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value),
        );
      }

      final streamedResponse = await requestClient
          .send(request)
          .timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      throw ApiException.fromResponse(response);
    } on ApiException {
      rethrow;
    } on TokenStorageException {
      rethrow;
    } on TimeoutException {
      throw const ApiException.network(
        'The request timed out.',
        networkFailure: ApiNetworkFailure.timeout,
      );
    } on NetworkSocketException {
      throw const ApiException.network('The service could not be reached.');
    } on http.ClientException {
      throw const ApiException.network('The service could not be reached.');
    } finally {
      uploadClient?.close();
    }
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    required bool authenticated,
    String? body,
    Map<String, String>? queryParameters,
    Map<String, String>? requestHeaders,
  }) async {
    final uri = _config.endpoint(path, queryParameters);
    return _requestUri(
      method: method,
      uri: uri,
      authenticated: authenticated,
      body: body,
      requestHeaders: requestHeaders,
    );
  }

  Future<http.Response> _requestUri({
    required String method,
    required Uri uri,
    required bool authenticated,
    String? body,
    Map<String, String>? requestHeaders,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (requestHeaders != null) {
      headers.addAll(requestHeaders);
    }

    if (authenticated) {
      final token = await _tokenStorage.read();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'A valid session is required.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = switch (method) {
        'GET' =>
          await _client.get(uri, headers: headers).timeout(requestTimeout),
        'POST' =>
          await _client
              .post(uri, headers: headers, body: body)
              .timeout(requestTimeout),
        'PATCH' =>
          await _client
              .patch(uri, headers: headers, body: body)
              .timeout(requestTimeout),
        'PUT' =>
          await _client
              .put(uri, headers: headers, body: body)
              .timeout(requestTimeout),
        'DELETE' =>
          await _client.delete(uri, headers: headers).timeout(requestTimeout),
        _ => throw StateError('Unsupported HTTP method: $method'),
      };

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      throw ApiException.fromResponse(response);
    } on ApiException {
      rethrow;
    } on TokenStorageException {
      rethrow;
    } on TimeoutException {
      throw const ApiException.network(
        'The request timed out.',
        networkFailure: ApiNetworkFailure.timeout,
      );
    } on NetworkSocketException {
      throw const ApiException.network('The service could not be reached.');
    } on http.ClientException {
      throw const ApiException.network('The service could not be reached.');
    }
  }

  Uri _resolveServerUrl(String serverUrl) {
    final parsed = Uri.tryParse(serverUrl.trim());
    if (parsed == null || parsed.path.isEmpty || parsed.fragment.isNotEmpty) {
      throw StateError('The server returned an invalid resource URL.');
    }

    final base = Uri.parse(_config.baseUrl.replaceFirst(RegExp(r'/+$'), ''));
    if (base.scheme != 'https' && !_isLocalHost(base.host)) {
      throw StateError('Non-local API endpoints must use HTTPS.');
    }
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    final apiPath = '$basePath${AppConfig.apiPrefix}';
    final expectedPath = parsed.path;
    if (expectedPath != apiPath && !expectedPath.startsWith('$apiPath/')) {
      throw StateError('The server returned an unexpected resource URL.');
    }

    if (parsed.hasScheme || parsed.hasAuthority) {
      if (parsed.scheme != base.scheme ||
          parsed.host != base.host ||
          parsed.port != base.port ||
          parsed.userInfo.isNotEmpty) {
        throw StateError('The server returned an unexpected resource URL.');
      }
      return parsed;
    }

    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: '$basePath$expectedPath',
      query: parsed.query,
    );
  }

  static bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2';
  }
}

enum ApiNetworkFailure { offline, timeout }

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors = const <String, List<String>>{},
    this.retryAfter,
    this.networkFailure = ApiNetworkFailure.offline,
  });

  const ApiException.network(
    this.message, {
    this.networkFailure = ApiNetworkFailure.offline,
  }) : statusCode = null,
       code = 'NETWORK_ERROR',
       fieldErrors = const <String, List<String>>{},
       retryAfter = null;

  final int? statusCode;
  final String code;
  final String message;
  final Map<String, List<String>> fieldErrors;
  final Duration? retryAfter;
  final ApiNetworkFailure networkFailure;

  bool get isNetworkError => statusCode == null;

  factory ApiException.fromResponse(http.Response response) {
    final payload = _decodeObject(response.body);
    final responseCode = payload?['code'];
    final responseMessage = payload?['message'];
    final errors = _decodeFieldErrors(payload?['errors']);
    final retryAfterSeconds = int.tryParse(
      response.headers['retry-after'] ?? '',
    );

    return ApiException(
      statusCode: response.statusCode,
      code: responseCode is String ? responseCode : _defaultCode(response),
      message: responseMessage is String
          ? responseMessage
          : _defaultMessage(response.statusCode),
      fieldErrors: errors,
      retryAfter: retryAfterSeconds == null
          ? null
          : Duration(seconds: retryAfterSeconds),
    );
  }

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, code: $code)';
  }

  static String _defaultCode(http.Response response) {
    return switch (response.statusCode) {
      401 => 'UNAUTHENTICATED',
      403 => 'FORBIDDEN',
      404 => 'NOT_FOUND',
      409 => 'CONFLICT',
      422 => 'VALIDATION_ERROR',
      429 => 'THROTTLED',
      _ => 'SERVER_ERROR',
    };
  }

  static String _defaultMessage(int statusCode) {
    return switch (statusCode) {
      401 => 'Authentication is required.',
      403 => 'This action is not allowed.',
      404 => 'The requested resource was not found.',
      409 => 'The request conflicts with current server state.',
      422 => 'The submitted data is invalid.',
      429 => 'Too many requests. Try again later.',
      _ => 'The service returned an error.',
    };
  }
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

Map<String, List<String>> _decodeFieldErrors(Object? value) {
  if (value is! Map) {
    return const <String, List<String>>{};
  }

  final errors = <String, List<String>>{};
  void collect(Object? current, String prefix) {
    if (current is Map) {
      for (final entry in current.entries) {
        final key = entry.key.toString();
        final nestedKey = prefix.isEmpty ? key : '$prefix.$key';
        collect(entry.value, nestedKey);
      }
      return;
    }

    final fieldValue = current;
    if (fieldValue is String) {
      errors[prefix] = <String>[fieldValue];
    } else if (fieldValue is List) {
      final messages = fieldValue.whereType<String>().toList(growable: false);
      if (messages.isNotEmpty) {
        errors[prefix] = messages;
      }
    }
  }

  collect(value, '');
  return errors;
}
