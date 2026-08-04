import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

enum AppUpdateType { none, optional, required }

class AppVersionStatus {
  const AppVersionStatus._({
    required this.type,
    this.message,
    this.storeUrl,
  });

  const AppVersionStatus.none() : this._(type: AppUpdateType.none);

  const AppVersionStatus.optional({
    required String message,
    required Uri storeUrl,
  }) : this._(
          type: AppUpdateType.optional,
          message: message,
          storeUrl: storeUrl,
        );

  const AppVersionStatus.required({
    required String message,
    required Uri storeUrl,
  }) : this._(
          type: AppUpdateType.required,
          message: message,
          storeUrl: storeUrl,
        );

  final AppUpdateType type;
  final String? message;
  final Uri? storeUrl;
}

class AppVersionChecker {
  static const _platform = 'android';
  static final _defaultStoreUrl = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.vibeloop.vibeloop',
  );

  Future<AppVersionStatus> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const AppVersionStatus.none();
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(packageInfo.buildNumber);
      if (localBuild == null) return const AppVersionStatus.none();

      // 1. Intentar verificación automática en tiempo real con Google Play Store API
      try {
        final updateInfo = await InAppUpdate.checkForUpdate()
            .timeout(const Duration(seconds: 4));

        if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          final latestBuild = updateInfo.availableVersionCode;
          if (latestBuild != null && latestBuild > localBuild) {
            final minSupportedBuild = latestBuild - 1;

            if (localBuild < minSupportedBuild) {
              return AppVersionStatus.required(
                message:
                    'Hay una nueva versión de Nadie disponible en Google Play. Es necesario actualizar para continuar.',
                storeUrl: _defaultStoreUrl,
              );
            }

            return AppVersionStatus.optional(
              message:
                  'Hay una nueva versión de Nadie disponible. ¡Actualiza para disfrutar de las últimas mejoras!',
              storeUrl: _defaultStoreUrl,
            );
          }
        }
      } catch (_) {
        // Si no está disponible en desarrollo/debug o falla la consulta nativa, continuar con el respaldo.
      }

      // 2. Respaldo (Fallback): Consultar política en Supabase
      final row = await Supabase.instance.client
          .from('app_version_policies')
          .select('latest_build, min_supported_build, update_message, store_url')
          .eq('platform', _platform)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (row == null) return const AppVersionStatus.none();

      final latestBuild = _asInt(row['latest_build']);
      final minimumBuild = _asInt(row['min_supported_build']);
      final storeUrl = Uri.tryParse(row['store_url']?.toString() ?? '') ?? _defaultStoreUrl;
      final message = row['update_message']?.toString().trim();

      if (latestBuild == null || minimumBuild == null) {
        return const AppVersionStatus.none();
      }

      final resolvedMessage = message == null || message.isEmpty
          ? 'Hay una actualización disponible.'
          : message;

      if (localBuild < minimumBuild) {
        return AppVersionStatus.required(
          message: resolvedMessage,
          storeUrl: storeUrl,
        );
      }

      if (localBuild < latestBuild) {
        return AppVersionStatus.optional(
          message: resolvedMessage,
          storeUrl: storeUrl,
        );
      }
    } catch (_) {
      // Un problema temporal de red o configuración nunca debe bloquear al usuario.
    }

    return const AppVersionStatus.none();
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}


class AppVersionGate extends StatefulWidget {
  const AppVersionGate({
    required this.appBuilder,
    super.key,
  });

  final Widget Function(AppVersionStatus status) appBuilder;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> {
  late final Future<AppVersionStatus> _status = AppVersionChecker().check();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppVersionStatus>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _VersionShell(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final status = snapshot.data ?? const AppVersionStatus.none();
        if (status.type == AppUpdateType.required) {
          return _VersionShell(
            child: _RequiredUpdateScreen(status: status),
          );
        }

        return widget.appBuilder(status);
      },
    );
  }
}

class OptionalUpdateBanner extends StatefulWidget {
  const OptionalUpdateBanner({
    required this.status,
    required this.child,
    super.key,
  });

  final AppVersionStatus status;
  final Widget child;

  @override
  State<OptionalUpdateBanner> createState() => _OptionalUpdateBannerState();
}

class _OptionalUpdateBannerState extends State<OptionalUpdateBanner> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible || widget.status.type != AppUpdateType.optional) {
      return widget.child;
    }

    return Column(
      children: [
        MaterialBanner(
          content: Text(widget.status.message!),
          leading: const Icon(Icons.system_update_alt_rounded),
          actions: [
            TextButton(
              onPressed: _openStore,
              child: const Text('Actualizar'),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => setState(() => _visible = false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  Future<void> _openStore() async {
    final url = widget.status.storeUrl;
    if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _VersionShell extends StatelessWidget {
  const _VersionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: vibeloopTheme,
      darkTheme: vibeloopDarkTheme,
      home: Scaffold(body: SafeArea(child: child)),
    );
  }
}

class _RequiredUpdateScreen extends StatelessWidget {
  const _RequiredUpdateScreen({required this.status});

  final AppVersionStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Actualización necesaria',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                status.message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () async {
                  final url = status.storeUrl;
                  if (url != null) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Actualizar ahora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
