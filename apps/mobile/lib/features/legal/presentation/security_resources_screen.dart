import 'package:flutter/material.dart';

class SecurityResourcesScreen extends StatelessWidget {
  const SecurityResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Recursos de seguridad'),
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
              'Usa esta sección para proteger tu experiencia en VIBELOOP. Aquí reunimos las acciones más útiles para moderar grupos, reducir abuso y mantener tu cuenta bajo control.',
              style: TextStyle(
                color: Color(0xFF4B5563),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SecuritySection(
            title: 'Protege tus grupos',
            body:
                'Comparte enlaces solo con personas de confianza. Si un enlace se volvió público, usa la opción de pausa del enlace cuando esté disponible para detener accesos no deseados.',
          ),
          const _SecuritySection(
            title: 'Controla el contenido molesto',
            body:
                'Bloquea usuarios abusivos, oculta palabras que no quieras ver y revisa el filtrado de mensajes cuando esté habilitado. Eso ayuda a mantener el chat más limpio y seguro.',
          ),
          const _SecuritySection(
            title: 'Revisa mensajes anónimos con cuidado',
            body:
                'Los mensajes anónimos pueden ser útiles, pero también requieren moderación. Si detectas abuso, conserva evidencia y usa los controles de seguridad para reducir el impacto en tu grupo.',
          ),
          const _SecuritySection(
            title: 'Verifica invitaciones y enlaces',
            body:
                'Antes de compartir un grupo, confirma que el enlace correcto esté activo y que las personas invitadas entiendan las normas básicas del grupo. Evita publicar enlaces en sitios públicos si no lo deseas.',
          ),
          const _SecuritySection(
            title: 'Tu cuenta y tu privacidad',
            body:
                'No compartas tu acceso, mantén tu dispositivo protegido y revisa periódicamente la información visible en tu perfil. Si ya no quieres usar la app, elimina la cuenta desde Ajustes cuando la función esté lista.',
          ),
          const _SecuritySection(
            title: 'Cuándo escribir a soporte',
            body:
                'Escribe a soporte si detectas acoso, contenido ilegal, suplantación, acceso indebido o problemas con invitaciones, fotos o mensajes que no puedas resolver desde la app.',
          ),
        ],
      ),
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.title, required this.body});

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
