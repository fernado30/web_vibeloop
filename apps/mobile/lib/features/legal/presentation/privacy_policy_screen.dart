import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/vibe_ui.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _policyText = '''
Política de Privacidad de VIBELOOP
Última actualización: 28 de mayo de 2026

1. Quiénes somos
VIBELOOP es una aplicación social para crear grupos, conversar en tiempo real, compartir fotos del grupo, enviar mensajes anónimos dentro de un grupo y entrar a grupos mediante enlaces de invitación.

2. Información que recopilamos
Podemos recopilar y procesar la siguiente información cuando usas la app:
- Datos de cuenta: correo electrónico, nombre de usuario, nombre visible, avatar, emoji de perfil y datos de autenticación.
- Contenido que creas: mensajes de chat, reacciones, fotos del grupo, nombre y descripción del grupo, mensajes anónimos e invitaciones compartidas.
- Datos de grupo y membresía: grupos a los que perteneces, roles dentro del grupo, códigos o enlaces de invitación y metadatos asociados.
- Datos técnicos y de uso: modelo del dispositivo, sistema operativo, idioma, zona horaria, identificadores técnicos, registros de error, eventos de interacción y estado de la sesión.
- Datos de notificaciones: token push o identificador necesario para enviar alertas cuando el sistema de notificaciones esté habilitado.
- Datos relacionados con publicidad: información técnica o de uso que pueda procesarse por terceros como Google AdMob cuando la monetización esté activa.

3. Cómo usamos la información
Usamos esta información para:
- Crear y administrar tu cuenta.
- Permitir el acceso al chat, grupos, fotos, reacciones y buzón anónimo.
- Mostrar y sincronizar contenido entre miembros de un mismo grupo en tiempo real.
- Procesar invitaciones, acceso como invitado y participación en grupos.
- Mostrar notificaciones relacionadas con actividad de grupos, mensajes o invitaciones.
- Mejorar la estabilidad, el rendimiento, la seguridad y la experiencia de uso.
- Detectar errores, prevenir abuso y moderar funciones que puedan ser utilizadas de forma indebida.
- Mostrar anuncios de prueba durante el desarrollo y anuncios reales cuando la monetización esté habilitada en producción.

4. Contenido visible para otros usuarios
Cuando publicas contenido dentro de un grupo, ese contenido puede ser visible para otros miembros del grupo y, en algunos casos, para personas que acceden mediante un enlace de invitación válido según la función utilizada.

Las fotos del grupo, mensajes, reacciones, nombres de grupo y mensajes anónimos se almacenan en infraestructura de terceros y pueden ser mostrados dentro de la app o a través de enlaces generados para su visualización.

5. Proveedores de servicio
Podemos compartir o procesar información con proveedores que ayudan a operar VIBELOOP:
- Supabase: autenticación, base de datos, almacenamiento, tiempo real y funciones relacionadas.
- Google AdMob: entrega y medición de anuncios cuando la monetización está activa.
- Servicios de notificaciones y transporte de mensajes, si se habilitan en el futuro.

6. Base legal y uso permitido
Tratamos la información cuando es necesaria para:
- prestar el servicio solicitado por ti;
- mantener la seguridad e integridad de la app;
- cumplir obligaciones legales;
- prevenir fraude, abuso o uso no autorizado;
- mejorar el funcionamiento y la experiencia del producto.

7. Conservación de datos
Conservamos tus datos mientras tu cuenta permanezca activa o mientras sea necesario para prestar el servicio, resolver incidencias, cumplir obligaciones legales o mantener copias de respaldo razonables.

Si eliminas tu cuenta o solicitas la eliminación de datos, eliminaremos o anonimizaremos la información cuando sea posible y cuando la ley lo permita. Algunos registros técnicos pueden conservarse durante un periodo limitado por razones de seguridad, auditoría o respaldo.

8. Seguridad
Aplicamos medidas razonables para proteger tu información, como controles de acceso, reglas de seguridad, cifrado en tránsito y separación de permisos por función.

Aun así, ningún sistema es totalmente seguro. Te recomendamos mantener tu dispositivo protegido y no compartir tus credenciales con terceros.

9. Menores de edad
VIBELOOP no está dirigida a menores de edad sin supervisión. Si detectamos información de un menor o una solicitud de eliminación relacionada, podremos revisar, restringir o eliminar la cuenta según corresponda y de acuerdo con la ley aplicable.

10. Tus derechos y controles
Dependiendo de tu país, puedes tener derecho a:
- acceder a tus datos;
- corregir información inexacta;
- solicitar eliminación de tu cuenta o contenido;
- oponerte a ciertos tratamientos;
- retirar permisos del dispositivo, como notificaciones, si tu sistema lo permite.

11. Cambios a esta política
Podemos actualizar esta política cuando agreguemos funciones nuevas, cambiemos proveedores o debamos ajustarla a requisitos legales o de seguridad.

12. Contacto
Si tienes preguntas sobre privacidad, eliminación de cuenta o manejo de datos, contáctanos en soporte@vibeloop.app o en el canal oficial que usemos para soporte al momento de publicar.
''';

  @override
  Widget build(BuildContext context) {
    return VibeScaffold(
      appBar: AppBar(
        title: const Text('Politica de privacidad'),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _policyText));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Politica copiada al portapapeles')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          SectionIntroCard(
            title: 'Resumen legal y operativo',
            body: 'Este texto refleja el funcionamiento real de VIBELOOP. Antes de publicarlo en una store, revísalo con asesoría legal y actualiza el contacto oficial.',
            badge: SafetyBadge(label: 'Legal'),
          ),
          SizedBox(height: 16),
          _PolicySection(
            title: 'Resumen',
            body: 'VIBELOOP recopila datos de cuenta, contenido compartido, actividad de grupos, fotos y datos técnicos para que el chat, los grupos, las invitaciones y las funciones sociales funcionen correctamente.',
          ),
          _PolicySection(
            title: 'Datos que usamos',
            body: 'Correo, nombre de usuario, nombre visible, emoji de perfil, avatar, mensajes, reacciones, fotos del grupo, datos de membresía, invitaciones, notificaciones y datos técnicos necesarios para operar la app.',
          ),
          _PolicySection(
            title: 'Uso de terceros',
            body: 'Supabase se usa para autenticación, base de datos, almacenamiento y tiempo real. Google AdMob puede procesar datos técnicos o de uso para mostrar anuncios cuando la monetización esté activa.',
          ),
          _PolicySection(
            title: 'Tus controles',
            body: 'Puedes solicitar eliminación de cuenta, dejar de usar la app, retirar permisos del dispositivo y revisar las opciones de privacidad o seguridad disponibles en Ajustes cuando se habiliten.',
          ),
          _PolicySection(
            title: 'Texto completo',
            body: _policyText,
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
        ? const TextStyle(fontFamily: 'monospace', height: 1.45)
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body, style: textStyle),
          ],
        ),
      ),
    );
  }
}
