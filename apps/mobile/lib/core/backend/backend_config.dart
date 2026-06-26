import 'package:flutter/services.dart';

class BackendConfig {
  const BackendConfig({
    required this.backendUrl,
  });

  final String? backendUrl;

  static Future<BackendConfig> load() async {
    final raw = await rootBundle.loadString('assets/.env');
    final values = <String, String>{};

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
        continue;
      }

      final index = trimmed.indexOf('=');
      final key = trimmed.substring(0, index).trim();
      final value = trimmed.substring(index + 1).trim();
      values[key] = value;
    }

    final backendUrl = values['VIBELOOP_BACKEND_URL']?.trim() ?? '';
    if (backendUrl.isEmpty || backendUrl.contains('YOUR_BACKEND_URL')) {
      return const BackendConfig(backendUrl: null);
    }

    return BackendConfig(
      backendUrl: backendUrl.replaceAll(RegExp(r'/+$'), ''),
    );
  }
}
