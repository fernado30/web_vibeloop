# VibeLoop Legal

Sitio estático independiente para:

- `index.html`: portada legal
- `privacy.html`: política de privacidad
- `terms.html`: términos de servicio

## Uso

Puedes desplegar esta carpeta como sitio estático independiente o servirla en local con cualquier servidor estático.

## Contacto

El correo actual del sitio es `emotivanadien@gmail.com`.

## Nota

Mantén este contenido sincronizado con la app móvil, la ficha de Google Play y la sección Data safety.

## Vercel

This folder is ready to be deployed as its own Vercel project.

Recommended project setup:

1. Create a new Vercel project from the same repo.
2. Set the `Root Directory` to `apps/legal`.
3. Leave the build command empty. Vercel will serve the static files directly.
4. Keep the output directory as the project root for that subproject.

Suggested domain split:

- Main app web: `www.vibeloop.app`
- Legal site: `https://web-legal-nadie.vercel.app/`

If you prefer a simpler setup:

- Main app web: `vibeloop.app`
- Legal site: `https://web-legal-nadie.vercel.app/`
