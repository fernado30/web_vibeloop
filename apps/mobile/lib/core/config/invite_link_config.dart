import 'package:flutter/services.dart';

class InviteLinkConfig {
  const InviteLinkConfig({
    required this.webUrl,
  });

  final String webUrl;

  static Future<InviteLinkConfig> load() async {
    final raw = await rootBundle.loadString('assets/web.env');
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

    final webUrl = values['VIBELOOP_WEB_URL']?.trim() ?? '';
    if (webUrl.isEmpty || webUrl.contains('YOUR_WEB_URL')) {
      throw StateError(
        'VIBELOOP web URL is not configured. Update apps/mobile/assets/web.env with your web invitation URL.',
      );
    }

    return InviteLinkConfig(webUrl: webUrl);
  }
}
