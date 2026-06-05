import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/vibe_ui.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const String _supportEmail = 'soporte@vibeloop.app';
  static final Uri _emailUri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {
      'subject': 'Ayuda con VIBELOOP',
      'body': 'Hola equipo de VIBELOOP,\n\nNecesito ayuda con:\n\n- Descripcion del problema:\n- Grupo afectado (si aplica):\n- Dispositivo:\n- Captura o detalle adicional:\n',
    },
  );

  Future<void> _openEmail(BuildContext context) async {
    final launched = await launchUrl(_emailUri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el correo. Copia la dirección de soporte.')),
      );
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo de soporte copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('I need help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const GradientHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafetyBadge(label: 'Support', color: Colors.white),
                SizedBox(height: 14),
                Text(
                  'Ayuda clara, sin fricción',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Si algo no funciona como esperas, aquí tienes orientación rápida y una vía directa para escribir al equipo.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionIntroCard(
            title: 'Antes de escribirnos',
            body: 'Revisa si usas la versión más reciente, si tu conexión es estable y si el problema ocurre en un grupo o en toda la app.',
          ),
          const SizedBox(height: 12),
          const SectionIntroCard(
            title: 'Qué incluir',
            body: 'Comparte tu usuario, nombre del grupo, dispositivo, una descripción breve y, si puedes, una captura o detalle extra.',
          ),
          const SizedBox(height: 12),
          MessageThreadPreview(
            title: 'Escribir a soporte',
            subtitle: 'Abre el correo con un mensaje listo para enviar.',
            onTap: () => _openEmail(context),
          ),
          const SizedBox(height: 12),
          MessageThreadPreview(
            title: 'Copiar correo',
            subtitle: _supportEmail,
            onTap: () => _copyEmail(context),
          ),
          const SizedBox(height: 12),
          const ModerationWarningCard(
            title: 'Si tu caso es de seguridad',
            body: 'Si sospechas de abuso, acoso, contenido indebido o acceso no autorizado, revisa primero Recursos de seguridad desde Ajustes.',
          ),
        ],
      ),
    );
  }
}
