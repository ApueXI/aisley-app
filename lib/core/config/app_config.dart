class AppConfig {
  const AppConfig({required this.baseUrl});

  static const fromEnvironment = AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000',
    ),
  );

  static const apiPrefix = '/api/v1';

  final String baseUrl;

  Uri endpoint(String path, [Map<String, String>? queryParameters]) {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$apiPrefix$normalizedPath');

    if (uri.scheme != 'https' && !_isLocalHost(uri.host)) {
      throw StateError('Non-local API endpoints must use HTTPS.');
    }

    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  static bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2';
  }
}
