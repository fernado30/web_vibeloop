# VIBELOOP Web

Standalone web app for invitation links.

## What it does

- Opens links in the form `/invite/:token`
- Loads the group from Supabase using the public anon key
- Lets a guest upload a photo and join the group

## Setup

On Vercel, set these environment variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The build step will generate `config.js` automatically from those values.

For local testing, you can edit `config.js` directly.

## Deployment

Deploy the contents of this folder as a static site.

Make sure your host rewrites all routes to `index.html`, so direct visits to `/invite/:token` work.

This repo already includes a root `vercel.json` configured for that flow.

## Notes

- The mobile app generates links from its own `apps/mobile/assets/web.env` file.
- Keep that URL in sync with the deployed domain for this web app.
