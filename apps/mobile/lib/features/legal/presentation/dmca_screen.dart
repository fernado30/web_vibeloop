import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/vibe_ui.dart';

class DmcaScreen extends StatelessWidget {
  const DmcaScreen({super.key});

  static const String _supportEmail = 'emotivavibeloop@gmail.com';

  static Uri _noticeUri(String subject) => Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {
          'subject': subject,
          'body': 'Nombre completo:\nEntidad (si aplica):\nDirección:\nTeléfono:\n\nObra protegida: \nUbicación exacta del contenido en VIBELOOP: \nURL o identificador del grupo/contenido: \n\nDeclaro de buena fe que el uso descrito no está autorizado por el titular, su agente o la ley.\n\nFirma electrónica (escribe tu nombre):',
        },
      );

  Future<void> _openMail(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el correo de soporte.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(title: const Text('Copyright y DMCA')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionIntroCard(
            title: 'Avisos de copyright',
            body: 'VIBELOOP respeta los derechos de autor. Si crees que un contenido alojado en la app infringe tus derechos, puedes enviar un aviso para que lo revisemos.',
          ),
          const SizedBox(height: 12),
          _DmcaCard(
            title: 'Enviar un aviso de retirada',
            body: 'Incluye tu nombre, datos de contacto, identificación de la obra, ubicación exacta del contenido, una declaración de buena fe y tu firma electrónica.',
            actionLabel: 'Enviar aviso',
            onTap: () => _openMail(context, _noticeUri('[DMCA] Aviso de infracción')),
          ),
          const SizedBox(height: 12),
          _DmcaCard(
            title: 'Enviar un contraaviso',
            body: 'Si tu contenido fue retirado por error, escríbenos indicando el material retirado, su ubicación anterior, tus datos de contacto, una declaración de buena fe y tu consentimiento a la jurisdicción aplicable.',
            actionLabel: 'Enviar contraaviso',
            onTap: () => _openMail(context, _noticeUri('[DMCA] Contraaviso')),
          ),
          const SizedBox(height: 12),
          const SectionIntroCard(
            title: 'Canal de contacto',
            body: 'Los avisos se reciben en emotivavibeloop@gmail.com con el asunto “[DMCA]”. El operador deberá completar y mantener actualizados los datos de la entidad y del agente designado, y registrar al agente ante la U.S. Copyright Office si busca acogerse al puerto seguro de la DMCA.',
          ),
          const SizedBox(height: 12),
          const SectionIntroCard(
            title: 'Uso responsable',
            body: 'Los avisos falsos o presentados de mala fe pueden generar responsabilidad. VIBELOOP puede solicitar información adicional y tomar medidas sobre cuentas que infrinjan repetidamente derechos de autor.',
          ),
        ],
      ),
    );
  }
}

class _DmcaCard extends StatelessWidget {
  const _DmcaCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onTap,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
