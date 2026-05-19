import 'package:flutter/services.dart';

class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    required this.deepLinkScheme,
  });

  final String url;
  final String anonKey;
  final String deepLinkScheme;

  static Future<SupabaseConfig> load() async {
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

    final url = values['SUPABASE_URL']?.trim() ?? '';
    final anonKey = values['SUPABASE_ANON_KEY']?.trim() ?? '';
    final deepLinkScheme = values['VIBELOOP_DEEP_LINK_SCHEME']?.trim() ?? '';

    if (url.isEmpty || url.contains('YOUR_PROJECT.supabase.co')) {
      throw StateError('Supabase URL is not configured. Update apps/mobile/assets/.env with your project URL.');
    }

    if (anonKey.isEmpty || anonKey.contains('YOUR_SUPABASE_ANON_KEY')) {
      throw StateError('Supabase anon key is not configured. Update apps/mobile/assets/.env with your anon key.');
    }

    if (deepLinkScheme.isEmpty || deepLinkScheme.contains('YOUR_DEEP_LINK_SCHEME')) {
      throw StateError('VIBELOOP deep link scheme is not configured. Update apps/mobile/assets/.env with your app scheme.');
    }

    return SupabaseConfig(
      url: url,
      anonKey: anonKey,
      deepLinkScheme: deepLinkScheme,
    );
  }
}
