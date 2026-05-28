import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SectionTitle(icon: Icons.star_rounded, label: 'Preferencias'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                onTap: () => context.push('/groups/settings/notifications'),
              ),
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Apariencia',
                onTap: () => context.push('/groups/settings/appearance'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(icon: Icons.warning_amber_rounded, label: 'Controles de seguridad'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.text_fields_rounded,
                title: 'Palabras ocultas',
                onTap: () => context.push('/groups/settings/hidden-words'),
              ),
              _SettingsTile(
                icon: Icons.block_rounded,
                title: 'Usuarios bloqueados',
                onTap: () => context.push('/groups/settings/blocked-users'),
              ),
              _SettingsTile(
                icon: Icons.pause_circle_outline_rounded,
                title: 'Pausa mi enlace',
                onTap: () => context.push('/groups/settings/pause-link'),
              ),
              _SettingsTile(
                icon: Icons.filter_alt_outlined,
                title: 'Filtrado avanzado de mensajes',
                onTap: () => context.push('/groups/settings/message-filtering'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(icon: Icons.home_rounded, label: 'Más'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'I need help',
                onTap: () => context.push('/groups/settings/help'),
              ),
              _SettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Recursos de seguridad',
                onTap: () => context.push('/groups/settings/security-resources'),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Términos de uso',
                onTap: () => context.push('/groups/settings/terms-of-use'),
              ),
              _SettingsTile(
                icon: Icons.policy_outlined,
                title: 'Política de privacidad',
                onTap: () => context.push('/groups/settings/privacy-policy'),
              ),
              _SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: 'Eliminar cuenta',
                titleColor: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: const Text('Esta acción se implementará con un flujo seguro de confirmación.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eliminación de cuenta pendiente de implementación segura.')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4B5563),
              ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? const Color(0xFF111827);
    final effectiveTitleColor = titleColor ?? const Color(0xFF111827);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Icon(icon, size: 20, color: effectiveIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: effectiveTitleColor,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}
