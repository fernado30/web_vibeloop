import 'package:flutter/material.dart';

import '../../../core/widgets/vibe_ui.dart';

class SecurityResourcesScreen extends StatelessWidget {
  const SecurityResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('Recursos de seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          SectionIntroCard(
            title: 'Protege tu experiencia en Nadien',
            body: 'Aquí reunimos las acciones más útiles para moderar grupos, reducir abuso y mantener tu cuenta bajo control.',
            badge: SafetyBadge(label: 'Seguridad'),
          ),
          SizedBox(height: 12),
          SectionIntroCard(
            title: 'Protege tus grupos',
            body: 'Comparte enlaces solo con personas de confianza y pausa accesos no deseados si un link se vuelve demasiado público.',
          ),
          SizedBox(height: 12),
          SectionIntroCard(
            title: 'Controla el contenido molesto',
            body: 'Bloquea usuarios abusivos, oculta palabras que no quieras ver y revisa el filtrado de mensajes cuando lo necesites.',
          ),
          SizedBox(height: 12),
          SectionIntroCard(
            title: 'Revisa mensajes anónimos con cuidado',
            body: 'Los mensajes anónimos pueden ser útiles, pero también requieren moderación. Si detectas abuso, conserva evidencia y reduce el impacto desde la app.',
          ),
          SizedBox(height: 12),
          SectionIntroCard(
            title: 'Tu cuenta y tu privacidad',
            body: 'No compartas tu acceso, mantén tu dispositivo protegido y revisa la información visible en tu perfil con frecuencia.',
          ),
          SizedBox(height: 12),
          ModerationWarningCard(
            title: 'Cuando escribir a soporte',
            body: 'Hazlo si detectas acoso, contenido ilegal, suplantación, acceso indebido o problemas con invitaciones, fotos o mensajes que no puedas resolver desde la app.',
          ),
        ],
      ),
    );
  }
}
