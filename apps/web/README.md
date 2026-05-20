# VIBELOOP Web

Standalone web app for anonymous messages.

## What it does

- Opens links in the form `/open/:token` and `/invite/:token`
- Loads the group from Supabase using the public anon key
- Lets anyone write and send anonymous messages to that group
- `/open/:token` tries to open the mobile app with an Android `intent://` link and falls back to the web inbox
- `/invite/:token` opens the anonymous message inbox directly

## Setup

On Vercel, set these environment variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The build step will generate `config.js` automatically from those values.

For local testing, you can edit `config.js` directly.

## Deployment

Deploy the contents of this folder as a static site.

Make sure your host rewrites all routes to `index.html`, so direct visits to `/open/:token` and `/invite/:token` work.

This repo already includes a root `vercel.json` configured for that flow.

## Notes

- The mobile app generates links from its own `apps/mobile/assets/web.env` file.
- Keep that URL in sync with the deployed domain for this web app.
