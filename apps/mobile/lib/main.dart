import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notifications/app_notification_service.dart';
import 'core/app_update/app_version_gate.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_config.dart';
import 'core/settings/app_preferences_repository.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(false);

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
      return true;
    };

    try {
      final config = await SupabaseConfig.load();
      await Supabase.initialize(
        url: config.url,
        anonKey: config.anonKey,
      );

      runApp(
        AppVersionGate(
          appBuilder: (status) => ProviderScope(
            child: VibeloopApp(updateStatus: status),
          ),
        ),
      );
    } catch (error, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: true,
      );
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
  }, (error, stackTrace) async {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: true,
    );
  });
}

class VibeloopApp extends ConsumerStatefulWidget {
  const VibeloopApp({
    required this.updateStatus,
    super.key,
  });

  final AppVersionStatus updateStatus;

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
      builder: (context, child) {
        final app = NotificationBootstrap(
          router: router,
          child: child ?? const SizedBox.shrink(),
        );
        return OptionalUpdateBanner(
          status: widget.updateStatus,
          child: app,
        );
      },
      debugShowCheckedModeBanner: false,
      title: 'Nadie',
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
                    'No pudimos iniciar Nadie',
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
