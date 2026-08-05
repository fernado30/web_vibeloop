import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/vibe_ui.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const String _supportEmail = 'emotivanadie@gmail.com';
  static final Uri _emailUri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {
      'subject': 'Ayuda con Nadie',
      'body': 'Hola equipo de Nadie,\n\nNecesito ayuda con:\n\n- Descripcion del problema:\n- Grupo afectado (si aplica):\n- Dispositivo:\n- Captura o detalle adicional:\n',
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
      appBar: AppBar(title: const Text('Necesito ayuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
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
          MessageThreadPreview(
            title: 'Recursos de seguridad y denuncias',
            subtitle: 'Políticas de moderación, prevención de abuso e informes de seguridad',
            onTap: () => context.push('/groups/settings/security-resources'),
          ),
          const SizedBox(height: 12),
          MessageThreadPreview(
            title: 'Copyright y DMCA',
            subtitle: 'Enviar avisos de retirada o contraavisos',
            onTap: () => context.push('/groups/settings/dmca'),
          ),
          const SizedBox(height: 12),
          const ModerationWarningCard(
            title: 'Si tu caso es de seguridad urgente',
            body: 'Si detectas acoso, contenido ilegal o explotación, repórtalo directamente con el botón de bandera en el mensaje o grupo.',
          ),
        ],
      ),
    );
  }
}
