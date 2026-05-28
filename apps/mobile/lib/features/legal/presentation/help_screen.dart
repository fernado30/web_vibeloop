import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const String _supportEmail = 'soporte@vibeloop.app';
  static final Uri _emailUri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {
      'subject': 'Ayuda con VIBELOOP',
      'body': 'Hola equipo de VIBELOOP,\n\nNecesito ayuda con:\n\n- Descripción del problema:\n- Grupo afectado (si aplica):\n- Dispositivo:\n- Captura o detalle adicional:\n',
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('I need help'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'Esta sección concentra el soporte básico de VIBELOOP. Si algo no funciona como esperas, aquí puedes encontrar orientación rápida y una forma directa de escribir al equipo.',
              style: TextStyle(
                color: Color(0xFF4B5563),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _HelpSection(
            title: 'Antes de escribirnos',
            body:
                'Revisa si estás usando la versión más reciente, si tu conexión es estable y si el problema ocurre solo en un grupo o en toda la app. Eso nos ayuda a resolverlo más rápido.',
          ),
          const _HelpSection(
            title: 'Problemas frecuentes',
            body:
                'Si un grupo no abre, prueba volver a entrar desde la lista principal. Si una foto no aparece, verifica que el archivo se haya subido correctamente. Si no ves mensajes, confirma que tienes acceso al grupo o al enlace correcto.',
          ),
          const _HelpSection(
            title: 'Qué incluir al reportar un problema',
            body:
                'Indica tu usuario, el nombre del grupo, el dispositivo que usas, una breve descripción del problema y, si puedes, una captura de pantalla. Con eso podemos ayudarte de forma más precisa.',
          ),
          _ActionCard(
            title: 'Escribir a soporte',
            subtitle: 'Te abrirá el correo con un mensaje listo para enviar.',
            icon: Icons.email_outlined,
            onTap: () => _openEmail(context),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Copiar correo',
            subtitle: 'Copia el correo oficial para compartirlo o guardarlo.',
            icon: Icons.copy_rounded,
            onTap: () => _copyEmail(context),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Soporte rápido',
            subtitle: _supportEmail,
            icon: Icons.support_agent_rounded,
            onTap: () => _copyEmail(context),
          ),
          const SizedBox(height: 16),
          const _HelpSection(
            title: 'Si tu caso es de seguridad',
            body:
                'Si sospechas de abuso, acoso, contenido indebido o acceso no autorizado, entra a Recursos de seguridad desde Ajustes para revisar las acciones recomendadas antes de escribir al soporte.',
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(24),
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
                color: Color(0xFF111827),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
