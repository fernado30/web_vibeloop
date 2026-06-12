import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/ads/ad_service.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_config.dart';
import 'core/settings/app_preferences_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = await SupabaseConfig.load();
    await Supabase.initialize(
      url: config.url,
      anonKey: config.anonKey,
    );
    try {
      await AdService.instance.initialize();
    } catch (error) {
      debugPrint('AdMob init failed: $error');
    }
    runApp(const ProviderScope(child: VibeloopApp()));
  } catch (error, stackTrace) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _BootstrapErrorScreen(
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  }
}

class VibeloopApp extends ConsumerStatefulWidget {
  const VibeloopApp({super.key});

  @override
  ConsumerState<VibeloopApp> createState() => _VibeloopAppState();
}

class _VibeloopAppState extends ConsumerState<VibeloopApp> {
  bool _deepLinkInitialized = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final preferences = ref.watch(appPreferencesControllerProvider);

    // Initialize the deep link service once the router is available.
    if (!_deepLinkInitialized) {
      _deepLinkInitialized = true;
      DeepLinkService.instance.init(router);
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'VIBELOOP',
      theme: vibeloopTheme,
      darkTheme: vibeloopDarkTheme,
      themeMode: preferences.themeMode,
      routerConfig: router,
    );
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No pudimos iniciar VIBELOOP',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error.toString(),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Revisa el archivo apps/mobile/assets/.env y vuelve a abrir la app.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    child: Text(
                      stackTrace.toString(),
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
