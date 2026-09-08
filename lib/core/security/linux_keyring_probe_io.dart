import 'dart:async';
import 'dart:io';

class SecureStoragePlatformProbe {
  const SecureStoragePlatformProbe._();

  static const _probeTimeout = Duration(seconds: 2);

  static Future<void> ensureAvailable() async {
    if (!Platform.isLinux) {
      return;
    }

    final serviceProperties = await _runGdbus(<String>[
      'call',
      '--session',
      '--dest',
      'org.freedesktop.secrets',
      '--object-path',
      '/org/freedesktop/secrets',
      '--method',
      'org.freedesktop.DBus.Properties.Get',
      'org.freedesktop.Secret.Service',
      'Collections',
    ]);
    if (serviceProperties.exitCode != 0) {
      throw StateError('The Linux Secret Service is unavailable.');
    }

    final alias = await _runGdbus(<String>[
      'call',
      '--session',
      '--dest',
      'org.freedesktop.secrets',
      '--object-path',
      '/org/freedesktop/secrets',
      '--method',
      'org.freedesktop.Secret.Service.ReadAlias',
      'default',
    ]);

    // A fresh Secret Service profile may not have a default collection yet.
    // flutter_secure_storage_linux handles that case safely for a first read.
    if (alias.exitCode != 0) {
      return;
    }

    final pathMatch = RegExp(r"'(/org/freedesktop/secrets/[^']+)'")
        .firstMatch(alias.stdout);
    final collectionPath = pathMatch?.group(1);
    if (collectionPath == null) {
      throw StateError('The Linux default keyring could not be inspected.');
    }

    final locked = await _runGdbus(<String>[
      'call',
      '--session',
      '--dest',
      'org.freedesktop.secrets',
      '--object-path',
      collectionPath,
      '--method',
      'org.freedesktop.DBus.Properties.Get',
      'org.freedesktop.Secret.Collection',
      'Locked',
    ]);
    if (locked.exitCode != 0 || locked.stdout.contains('<true>')) {
      throw StateError('The Linux default keyring is locked.');
    }
  }

  static Future<ProcessResult> _runGdbus(List<String> arguments) async {
    try {
      return await Process.run('gdbus', arguments).timeout(_probeTimeout);
    } on TimeoutException {
      throw StateError('The Linux Secret Service did not respond.');
    } on ProcessException catch (error) {
      throw StateError(
        'The Linux Secret Service probe failed: ${error.message}',
      );
    }
  }
}
