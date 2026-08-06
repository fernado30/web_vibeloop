import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final Uri _privacyUrl = Uri.parse('https://web-legal-nadie.vercel.app/privacy');
  static final Uri _termsUrl = Uri.parse('https://web-legal-nadie.vercel.app/terms');
  static final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  Future<void> _openExternalLink(BuildContext context, Uri url, String errorMessage) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Cerrar sesión'),
              content: const Text(
                '¿Estás seguro de que quieres cerrar la sesión actual? Podrás volver a iniciar sesión o usar otra cuenta.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: VibeColors.dangerRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldSignOut || !context.mounted) {
      return;
    }

    try {
      await ref.read(authStateProvider.notifier).signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.maybeWhen(authenticated: (user) => user, orElse: () => null);
    final isUnregistered = user == null || user.isAnonymous;

    final surface = Theme.of(context).colorScheme.surface;
    final text = Theme.of(context).colorScheme.onSurface;

    return VibeScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Ajustes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Material(
            color: surface,
            elevation: 0,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () => context.pop(),
              icon: VibeSvgIcon(
                VibeAssetIcons.arrowBack,
                size: 20,
                color: text,
              ),
            ),
          ),
        ),
        leadingWidth: 64,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(
            icon: Icons.tune_rounded,
            label: 'Preferencias',
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            children: [
              _SettingsRow(
                iconAsset: VibeAssetIcons.bell,
                title: 'Notificaciones',
                subtitle: 'Decide qué actividad te interrumpe',
                onTap: () => context.push('/groups/settings/notifications'),
              ),
              _SettingsRow(
                iconAsset: VibeAssetIcons.moon,
                title: 'Apariencia',
                subtitle: 'Modo claro, oscuro o seguir sistema',
                onTap: () => context.push('/groups/settings/appearance'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const _SectionHeader(
            icon: Icons.shield_outlined,
            label: 'Controles de seguridad',
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.text_fields_rounded,
                title: 'Palabras ocultas',
                subtitle: 'Filtra contenido que no quieras ver',
                onTap: () => context.push('/groups/settings/hidden-words'),
              ),
              _SettingsRow(
                icon: Icons.block_rounded,
                title: 'Usuarios bloqueados',
                subtitle: 'Gestiona personas cuya actividad ocultas',
                onTap: () => context.push('/groups/settings/blocked-users'),
              ),
              _SettingsRow(
                icon: Icons.shield_outlined,
                title: 'Mis denuncias',
                subtitle: 'Consulta el estado y resultado de tus reportes',
                onTap: () => context.push('/groups/settings/moderation-queue'),
              ),
              _SettingsRow(
                iconAsset: VibeAssetIcons.pause,
                title: 'Pausa mi enlace',
                subtitle: 'Detén nuevas entradas por invitación',
                onTap: () => context.push('/groups/settings/pause-link'),
              ),
              _SettingsRow(
                iconAsset: VibeAssetIcons.filter,
                title: 'Filtrado avanzado',
                subtitle: 'Oculta mensajes sensibles o no deseados',
                onTap: () => context.push('/groups/settings/message-filtering'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const _SectionHeader(
            icon: Icons.info_outline_rounded,
            label: 'Ayuda y legal',
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.question_mark_rounded,
                title: 'Necesito ayuda',
                subtitle: null,
                onTap: () => context.push('/groups/settings/help'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            children: [
              _SettingsRow(
                iconAsset: VibeAssetIcons.shield,
                title: 'Recursos de seguridad',
                subtitle: 'Buenas prácticas y acciones recomendadas',
                onTap: () => context.push('/groups/settings/security-resources'),
              ),
              _SettingsRow(
                icon: Icons.copyright_rounded,
                title: 'Copyright y DMCA',
                subtitle: 'Avisos de retirada y contraavisos',
                onTap: () => context.push('/groups/settings/dmca'),
              ),
              _SettingsRow(
                iconAsset: VibeAssetIcons.settings,
                title: 'Términos de uso',
                subtitle: 'Condiciones y límites del servicio',
                onTap: () => _openExternalLink(
                  context,
                  _termsUrl,
                  'No se pudieron abrir los términos de uso.',
                ),
              ),
              _SettingsRow(
                iconAsset: VibeAssetIcons.shield,
                title: 'Política de privacidad',
                subtitle: 'Cómo usamos y protegemos tus datos',
                onTap: () => _openExternalLink(
                  context,
                  _privacyUrl,
                  'No se pudo abrir la política de privacidad.',
                ),
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Opciones de privacidad de anuncios',
                subtitle: 'Gestiona o modifica tus preferencias de consentimiento UMP',
                onTap: () => AdService.instance.showPrivacyOptionsForm(context),
              ),
              if (!isUnregistered)
                _SettingsRow(
                  iconAsset: VibeAssetIcons.blocked,
                  title: 'Eliminar cuenta',
                  subtitle: 'Salida definitiva y segura',
                  titleColor: VibeColors.dangerRed,
                  iconColor: VibeColors.dangerRed,
                  onTap: () => context.push('/groups/settings/delete-account'),
                ),
              _SettingsRow(
                icon: Icons.logout_rounded,
                title: 'Cerrar sesión',
                subtitle: 'Salir o cambiar de cuenta',
                titleColor: VibeColors.dangerRed,
                iconColor: VibeColors.dangerRed,
                onTap: () => _handleSignOut(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              final version = snapshot.data;
              final label = version == null
                  ? 'Version'
                  : 'Version ${version.version}+${version.buildNumber}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 18, color: text.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    this.icon,
    this.iconAsset,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.iconColor,
    required this.onTap,
  }) : assert(icon != null || iconAsset != null, 'Debe proveer un icon o iconAsset');

  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final defaultIconColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      onTap: onTap,
      leading: icon != null
          ? Icon(icon, color: iconColor ?? defaultIconColor)
          : VibeSvgIcon(
              iconAsset!,
              size: 22,
              color: iconColor ?? defaultIconColor,
            ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }
}
