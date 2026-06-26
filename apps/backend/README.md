# VIBELOOP Backend

Backend propio para centralizar la lógica sensible sin quitar Supabase.

## Qué hace

- `POST /functions/v1/send-anonymous-message`
- `POST /functions/v1/resolve-invite`
- `POST /functions/v1/delete-account`
- `POST /functions/v1/register-user`
- `POST /functions/v1/join-guest-with-photo`
- `GET /health`

## Cómo se usa

- La web principal puede apuntar a este backend para enviar mensajes anónimos.
- La app móvil puede usarlo para el borrado de cuenta.
- Supabase sigue manejando Auth, Database y Storage.

## Variables de entorno

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY` opcional, solo para compatibilidad con rutas antiguas
- `PORT` opcional, por defecto `8787`

## Arranque local

```bash
node apps/backend/server.mjs
```

O desde la carpeta del backend:

```bash
npm run dev
```
