import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final Uri _privacyUrl = Uri.parse('https://web-vibeloop-legal.vercel.app/privacy');
  static final Uri _termsUrl = Uri.parse('https://web-vibeloop-legal.vercel.app/terms');

  Future<void> _openExternalLink(BuildContext context, Uri url, String errorMessage) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
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
                iconAsset: VibeAssetIcons.blocked,
                title: 'Usuarios bloqueados',
                subtitle: 'Gestiona tu espacio con más calma',
                onTap: () => context.push('/groups/settings/blocked-users'),
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
              if (!isUnregistered)
                _SettingsRow(
                  iconAsset: VibeAssetIcons.blocked,
                  title: 'Eliminar cuenta',
                  subtitle: 'Salida definitiva y segura',
                  titleColor: VibeColors.dangerRed,
                  iconColor: VibeColors.dangerRed,
                  onTap: () => context.push('/groups/settings/delete-account'),
                ),
            ],
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
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
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
    final background = Theme.of(context).colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: VibeColors.primaryDeepBlue.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          final showDivider = index != children.length - 1;
          return Column(
            children: [
              children[index],
              if (showDivider)
                Padding(
                  padding: const EdgeInsets.only(left: 156, right: 22),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    this.icon,
    this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final defaultIcon = iconColor ?? VibeColors.primaryViolet;
    final defaultTitle = titleColor ?? Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      defaultIcon.withValues(alpha: 0.12),
                      defaultIcon.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: iconAsset != null
                      ? VibeSvgIcon(iconAsset!, size: 27, color: defaultIcon)
                      : Icon(icon, size: 31, color: defaultIcon),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: defaultTitle,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: muted,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                size: 30,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
