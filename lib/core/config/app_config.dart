import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig({required this.baseUrl});

  static const fromEnvironment = AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000',
    ),
  );

  static const apiPrefix = '/api/v1';

  /// Loads the local `.env` asset and falls back to `--dart-define` or the
  /// local development URL when the asset is unavailable.
  static Future<AppConfig> load() async {
    final values = await _loadEnvAsset();
    final fileBaseUrl = values['API_BASE_URL']?.trim();

    if (fileBaseUrl != null && fileBaseUrl.isNotEmpty) {
      return AppConfig(baseUrl: fileBaseUrl);
    }

    return fromEnvironment;
  }

  final String baseUrl;

  static Future<Map<String, String>> _loadEnvAsset() async {
    try {
      final contents = await rootBundle.loadString('.env');
      return _parseEnv(contents);
    } catch (_) {
      return const {};
    }
  }

  static Map<String, String> _parseEnv(String contents) {
    final values = <String, String>{};

    for (final rawLine in contents.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }

      var key = line.substring(0, separator).trim();
      if (key.startsWith('export ')) {
        key = key.substring('export '.length).trim();
      }

      if (key.isEmpty) {
        continue;
      }

      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }

      values[key] = value;
    }

    return values;
  }

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
