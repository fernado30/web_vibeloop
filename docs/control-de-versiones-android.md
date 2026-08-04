# Control de versiones para Android

La aplicación utiliza la API oficial de **Google Play Store (`in_app_update`)** para detectar automáticamente y en tiempo real cuando una nueva versión (`.aab`) es aprobada y publicada en Google Play Console.

## Detección Automática (Sin intervención manual)

En cuanto Google Play autoriza y publica una nueva compilación (por ejemplo, compilación `+6`):
1. **Compilación inmediatamente anterior (`+5`)**: La app detectará `latest_build = 6` y mostrará un banner opcional/sugerido de actualización.
2. **Compilaciones anteriores (`+4` o menor)**: Al haber 2 o más compilaciones de diferencia ($\text{latest\_build} - \text{localBuild} \ge 2$), la app mostrará automáticamente la pantalla de **Actualización Necesaria** obligando a actualizar.

**No requieres realizar ningún cambio manual en la base de datos** al subir una compilación a la Google Play Store.

## Publicar una versión nueva

1. Aumenta el número de compilación en `apps/mobile/pubspec.yaml`. Por ejemplo, de `1.0.0+5` a `1.0.1+6`.
2. Compila el `.aab` y súbelo a Google Play Console (Prueba Abierta o Producción).
3. Tan pronto como Google apruebe el lanzamiento, los usuarios recibirán automáticamente el aviso/bloqueo de actualización.

## Respaldo remoto (Supabase)

Si por algún motivo un dispositivo no cuenta con Google Play Services o se utiliza una versión fuera de la tienda, la aplicación consulta como respaldo la tabla `public.app_version_policies` de Supabase. El trigger automático en Supabase mantiene `min_supported_build = latest_build - 1`.

