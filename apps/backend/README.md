# VIBELOOP Backend

Backend propio para centralizar la lógica sensible sin quitar Supabase.

## Qué hace

- `POST /functions/v1/send-anonymous-message`
- `POST /functions/v1/resolve-invite`
- `POST /functions/v1/delete-account`
- `POST /functions/v1/register-user` interno
- `POST /functions/v1/join-guest-with-photo` interno
- `GET /health`

## Cómo se usa

- La web principal puede apuntar a este backend para enviar mensajes anónimos.
- La app móvil puede usarlo para el borrado de cuenta.
- Supabase sigue manejando Auth, Database y Storage.

## Variables de entorno

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY` opcional, solo para compatibilidad con rutas antiguas
- `BACKEND_INTERNAL_KEY` recomendado, protege rutas internas como registro y alta de invitado
- `PORT` opcional, por defecto `8787`
- `ALLOWED_ORIGINS` opcional, lista separada por comas de orígenes permitidos para CORS

## Rutas sensibles

- `delete-account` exige `Authorization: Bearer <supabase_token>` y valida el usuario con Supabase Auth antes de borrar datos.
- `register-user` y `join-guest-with-photo` requieren `x-backend-internal-key: <BACKEND_INTERNAL_KEY>`.
- `send-anonymous-message` sigue siendo pública pero con validación de origen, rate limit persistente y filtros de contenido.

## Arranque local

```bash
node apps/backend/server.mjs
```

O desde la carpeta del backend:

```bash
npm run dev
```
