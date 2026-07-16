import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/app_notification_service.dart';
import '../../../core/settings/app_preferences_repository.dart';
import '../../../core/widgets/vibe_ui.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appPreferencesControllerProvider);
    final controller = ref.read(appPreferencesControllerProvider.notifier);
    final notificationService = ref.read(appNotificationServiceProvider);

    return VibeScaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Activa avisos reales',
            body: 'Estas preferencias controlan notificaciones locales del dispositivo. Verás que llegó un mensaje o un mensaje anónimo, pero no el contenido.',
            badge: SafetyBadge(label: 'Real'),
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
                    onChanged: (value) async {
                      if (value) {
                        final granted = await notificationService.requestPermissions();
                        if (!granted) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Necesitamos permiso de notificaciones para activar los avisos.'),
                              ),
                            );
                          }
                          return;
                        }
                      }

                      await controller.updateNotifications(
                        state.notifications.copyWith(notificationsEnabled: value),
                      );
                    },
                    title: const Text('Notificaciones activadas'),
                    subtitle: const Text('Activa avisos del sistema cuando llegue actividad nueva.'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: state.notifications.showMessagePreviews,
                    onChanged: state.notifications.notificationsEnabled
                        ? (value) async {
                            await controller.updateNotifications(
                              state.notifications.copyWith(showMessagePreviews: value),
                            );
                          }
                        : null,
                    title: const Text('Mostrar el origen'),
                    subtitle: const Text('Muestra el grupo en el aviso sin revelar el contenido del mensaje.'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: state.notifications.soundsEnabled,
                    onChanged: state.notifications.notificationsEnabled
                        ? (value) async {
                            await controller.updateNotifications(
                              state.notifications.copyWith(soundsEnabled: value),
                            );
                          }
                        : null,
                    title: const Text('Sonidos'),
                    subtitle: const Text('Reproduce un sonido suave en cada aviso compatible.'),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: state.notifications.vibrationEnabled,
                    onChanged: state.notifications.notificationsEnabled
                        ? (value) async {
                            await controller.updateNotifications(
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
            title: 'Contenido privado',
            body: 'Los avisos nuevos solo indican que llegó actividad. El texto del mensaje no se muestra en la notificación.',
          ),
        ],
      ),
    );
  }
}
