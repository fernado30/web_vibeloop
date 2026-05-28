import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  static const String _termsText = '''
Términos de uso de VIBELOOP
Última actualización: 28 de mayo de 2026

1. Aceptación
Al usar VIBELOOP, aceptas estos términos y te comprometes a utilizar la app de forma responsable, legal y respetuosa.

2. Descripción del servicio
VIBELOOP es una app social para crear grupos, participar en chats, compartir fotos del grupo, reaccionar a mensajes, usar el buzón anónimo y unirte a grupos mediante enlaces de invitación.

3. Cuenta y acceso
Para usar la app puedes crear una cuenta o entrar como invitado en grupos permitidos por enlace. Eres responsable de mantener la confidencialidad de tu acceso y de la información asociada a tu cuenta o sesión.

4. Uso permitido
Aceptas no usar VIBELOOP para:
- enviar spam, fraude o contenido malicioso;
- acosar, amenazar o vulnerar a otros usuarios;
- publicar contenido ilegal, sexualmente explícito, violento o que infrinja derechos de terceros;
- intentar acceder sin autorización a cuentas, grupos, enlaces o funciones internas;
- interferir con la estabilidad, seguridad o disponibilidad de la app.

5. Contenido generado por el usuario
Eres responsable del contenido que publicas, incluyendo mensajes, fotos, nombres de grupos, descripciones, reacciones y mensajes anónimos. Debes asegurarte de tener derechos para compartir dicho contenido.

VIBELOOP puede conservar, mostrar, moderar, limitar o eliminar contenido cuando sea necesario para cumplir estos términos, la ley, requisitos de seguridad o reglas de la plataforma.

6. Grupos, invitaciones y acceso como invitado
Los enlaces de invitación y accesos invitados están destinados a facilitar la participación dentro de un grupo. No debes compartirlos de forma abusiva ni utilizarlos para evadir restricciones, seguridad o moderación.

7. Fotos del grupo y almacenamiento
Las fotos del grupo se almacenan y muestran dentro de la app para los miembros autorizados o para quienes tengan acceso válido según la función utilizada. El usuario que sube contenido confirma que cuenta con los derechos y permisos necesarios para hacerlo.

8. Buzón anónimo
El buzón anónimo está diseñado para permitir mensajes sin mostrar públicamente la identidad del remitente dentro del flujo previsto por la app. Su uso indebido puede resultar en restricciones de cuenta o eliminación de contenido.

9. Anuncios y servicios de terceros
VIBELOOP puede utilizar servicios de terceros como Supabase y Google AdMob para operar la app y monetizarla de forma controlada. Esos servicios pueden procesar datos técnicos o de uso según sus propias políticas.

10. Suspensión y eliminación
Podemos limitar, suspender o terminar el acceso si detectamos abuso, fraude, incumplimiento de estos términos o actividad que comprometa la seguridad de otros usuarios o de la plataforma.

11. Cambios al servicio
Podemos agregar, modificar o retirar funciones para mejorar la experiencia, cumplir requisitos legales o mantener la seguridad y estabilidad de la app.

12. Limitación de responsabilidad
La app se ofrece en su estado actual y, en la medida permitida por la ley, no garantizamos que estará libre de errores, interrupciones o fallos. Hacemos esfuerzos razonables para mantenerla operativa y segura.

13. Contacto
Si tienes preguntas sobre estos términos, contáctanos en soporte@vibeloop.app o en el canal oficial de soporte que utilicemos en producción.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Términos de uso'),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _termsText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Términos copiados al portapapeles')),
              );
            },
          ),
        ],
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
              'Estos términos están redactados para reflejar el uso real de VIBELOOP. Antes de publicarlos en Play Store, revísalos con asesoría legal y reemplaza el contacto por el canal oficial de soporte.',
              style: TextStyle(
                color: Color(0xFF4B5563),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _PolicySection(
            title: 'Resumen',
            body:
                'VIBELOOP es una app social para grupos, chat, fotos, reacciones, invitaciones y buzón anónimo. El uso indebido, abusivo o ilegal puede terminar en restricciones o suspensión de acceso.',
          ),
          const _PolicySection(
            title: 'Uso permitido',
            body:
                'Debes usar la app de manera legal y respetuosa. No se permite spam, fraude, acoso, contenido ilegal, intentos de acceso no autorizado ni acciones que comprometan la seguridad o estabilidad del servicio.',
          ),
          const _PolicySection(
            title: 'Contenido y responsabilidad',
            body:
                'Eres responsable del contenido que publicas. Debes tener derechos para compartir textos, fotos, nombres, descripciones y otros materiales dentro de grupos o mensajes anónimos.',
          ),
          const _PolicySection(
            title: 'Servicios de terceros',
            body:
                'La app puede usar Supabase para autenticación, base de datos, almacenamiento y tiempo real, y Google AdMob para anuncios cuando la monetización esté activa.',
          ),
          const _PolicySection(
            title: 'Texto completo',
            body: _termsText,
            monospace: true,
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.title,
    required this.body,
    this.monospace = false,
  });

  final String title;
  final String body;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final textStyle = monospace
        ? const TextStyle(
            fontFamily: 'monospace',
            height: 1.45,
            color: Color(0xFF111827),
          )
        : const TextStyle(
            height: 1.45,
            color: Color(0xFF111827),
            fontWeight: FontWeight.w500,
          );

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
            Text(body, style: textStyle),
          ],
        ),
      ),
    );
  }
}
