import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_preferences_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appPreferencesControllerProvider);
    final controller = ref.read(appPreferencesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Notificaciones'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _IntroCard(
            title: 'Define qué avisos quieres recibir',
            body:
                'Estas preferencias se guardan en el dispositivo y preparan la base para notificaciones más completas en el futuro. También ayudan a mantener una experiencia más tranquila en la app.',
          ),
          const SizedBox(height: 16),
          if (!state.loaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
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
                  const Divider(height: 1),
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
                  const Divider(height: 1),
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
                  const Divider(height: 1),
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
          const _InfoCard(
            title: 'Qué hace ahora',
            body:
                'Por ahora estas preferencias quedan listas y guardadas para usarse dentro de VIBELOOP. Más adelante pueden conectarse a push notifications o a avisos locales más visibles.',
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              height: 1.45,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.45, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }
}
