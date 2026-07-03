import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_preferences_repository.dart';
import '../../../core/widgets/vibe_ui.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appPreferencesControllerProvider);
    final controller = ref.read(appPreferencesControllerProvider.notifier);

    return VibeScaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Define qué avisos quieres recibir',
            body: 'Estas preferencias se guardan en el dispositivo y dejan lista una experiencia más tranquila y personal.',
            badge: SafetyBadge(label: 'Enfoque'),
          ),
          const SizedBox(height: 16),
          if (!state.loaded)
            const LoadingStateCard(label: 'Cargando preferencias...')
          else
            GlassCard(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: state.notifications.notificationsEnabled,
                    onChanged: (value) {
                      controller.updateNotifications(
                        state.notifications.copyWith(notificationsEnabled: value),
                      );
                    },
                    title: const Text('Notificaciones activadas'),
                    subtitle: const Text('Permite recibir avisos relacionados con grupos y actividad general.'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: state.notifications.showMessagePreviews,
                    onChanged: state.notifications.notificationsEnabled
                        ? (value) {
                            controller.updateNotifications(
                              state.notifications.copyWith(showMessagePreviews: value),
                            );
                          }
                        : null,
                    title: const Text('Mostrar vista previa'),
                    subtitle: const Text('Muestra un resumen corto del contenido en los avisos.'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: state.notifications.soundsEnabled,
                    onChanged: state.notifications.notificationsEnabled
                        ? (value) {
                            controller.updateNotifications(
                              state.notifications.copyWith(soundsEnabled: value),
                            );
                          }
                        : null,
                    title: const Text('Sonidos'),
                    subtitle: const Text('Reproduce un sonido suave cuando haya actividad.'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: state.notifications.vibrationEnabled,
                    onChanged: state.notifications.notificationsEnabled
                        ? (value) {
                            controller.updateNotifications(
                              state.notifications.copyWith(vibrationEnabled: value),
                            );
                          }
                        : null,
                    title: const Text('Vibración'),
                    subtitle: const Text('Activa una vibración breve en alertas compatibles.'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const ModerationWarningCard(
            title: 'Preparado para crecer',
            body: 'Por ahora estas preferencias quedan guardadas y listas para futuras notificaciones push o avisos locales.',
          ),
        ],
      ),
    );
  }
}
