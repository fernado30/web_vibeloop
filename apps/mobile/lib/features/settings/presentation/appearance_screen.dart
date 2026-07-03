import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/vibe_ui.dart';
import '../../../core/settings/app_preferences_repository.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appPreferencesControllerProvider);
    final controller = ref.read(appPreferencesControllerProvider.notifier);

    return VibeScaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Controla como se ve VIBELOOP',
            body: 'Puedes cambiar entre modo claro, oscuro o seguir el sistema. El cambio se guarda y se aplica en toda la app al instante.',
            badge: SafetyBadge(label: 'Tema'),
          ),
          const SizedBox(height: 16),
          if (!state.loaded)
            const LoadingStateCard(label: 'Cargando preferencias visuales...')
          else
            GlassCard(
              child: Column(
                children: [
                  _ThemeTile(
                    title: 'Seguir sistema',
                    subtitle: 'Adapta el tema al de tu dispositivo',
                    selected: state.themeMode == ThemeMode.system,
                    onTap: () => controller.setThemeMode(ThemeMode.system),
                  ),
                  const SizedBox(height: 10),
                  _ThemeTile(
                    title: 'Modo claro',
                    subtitle: 'Limpio, suave y luminoso',
                    selected: state.themeMode == ThemeMode.light,
                    onTap: () => controller.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(height: 10),
                  _ThemeTile(
                    title: 'Modo oscuro',
                    subtitle: 'Más profundo y nocturno',
                    selected: state.themeMode == ThemeMode.dark,
                    onTap: () => controller.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary.withValues(alpha: 0.10) : colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? colorScheme.primary.withValues(alpha: 0.22) : colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary.withValues(alpha: 0.16) : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.brightness_6_outlined,
                  color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
