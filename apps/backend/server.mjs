import { createServer } from 'node:http';

const port = Number(process.env.PORT ?? 8787);
const supabaseUrl = (process.env.SUPABASE_URL ?? '').trim().replace(/\/+$/, '');
const serviceRoleKey = (process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
const anonKey = (process.env.SUPABASE_ANON_KEY ?? '').trim();

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

const inviteCodePattern = /^[a-zA-Z0-9_-]{4,64}$/;

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function textResponse(body, status = 200) {
  return new Response(body, {
    status,
    headers: corsHeaders,
  });
}

async function readJson(req) {
  return req.json().catch(() => ({}));
}

function requireSupabaseConfig() {
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.');
  }
}

async function supabaseRest(path, init = {}) {
  requireSupabaseConfig();

  const headers = new Headers(init.headers ?? {});
  headers.set('apikey', serviceRoleKey);
  headers.set('Authorization', `Bearer ${serviceRoleKey}`);

  if (init.body != null && !headers.has('Content-Type') && typeof init.body === 'string') {
    headers.set('Content-Type', 'application/json');
  }

  return fetch(`${supabaseUrl}${path}`, {
    ...init,
    headers,
  });
}

async function proxyToSupabaseFunction(name, req) {
  requireSupabaseConfig();

  const body = await req.text();
  const headers = new Headers();
  headers.set('Content-Type', req.headers.get('content-type') ?? 'application/json');
  headers.set('Authorization', req.headers.get('authorization') ?? '');
  headers.set('apikey', anonKey || serviceRoleKey);

  const response = await fetch(`${supabaseUrl}/functions/v1/${name}`, {
    method: req.method,
    headers,
    body,
  });

  return new Response(await response.text(), {
    status: response.status,
    headers: {
      ...corsHeaders,
      'Content-Type': response.headers.get('content-type') ?? 'application/json',
    },
  });
}

async function handleSendAnonymousMessage(req) {
  const body = await readJson(req);
  const inviteCode = String(body.inviteCode ?? '').trim();
  const content = String(body.content ?? '').trim();

  if (!inviteCode) {
    return jsonResponse({ error: 'inviteCode is required' }, 400);
  }

  if (!inviteCodePattern.test(inviteCode)) {
    return jsonResponse({ error: 'inviteCode has invalid format' }, 400);
  }

  if (content.length < 1 || content.length > 500) {
    return jsonResponse({ error: 'content must be between 1 and 500 characters' }, 400);
  }

  if (/(https?:\/\/|www\.)/i.test(content)) {
    return jsonResponse({ error: 'URLs are not allowed' }, 400);
  }

  const groupResponse = await supabaseRest(
    `/rest/v1/groups?select=id,invite_paused&invite_code=eq.${encodeURIComponent(inviteCode)}&limit=1`,
    { method: 'GET' },
  );

  if (!groupResponse.ok) {
    const errorText = await groupResponse.text();
    return jsonResponse({ error: errorText || 'Could not load invitation' }, 502);
  }

  const groups = await groupResponse.json();
  const group = Array.isArray(groups) ? groups[0] : null;

  if (!group) {
    return jsonResponse({ error: 'La invitacion no existe o ya no es valida.' }, 404);
  }

  if (group.invite_paused) {
    return jsonResponse({ error: 'Este enlace de invitacion esta pausado.' }, 403);
  }

  const insertResponse = await supabaseRest('/rest/v1/anonymous_messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    body: JSON.stringify({
      group_id: group.id,
      content,
    }),
  });

  if (!insertResponse.ok) {
    const errorText = await insertResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo enviar el mensaje.' }, 502);
  }

  const data = await insertResponse.json().catch(() => []);
  const message = Array.isArray(data) ? data[0] : data;

  return jsonResponse({ success: true, id: message?.id ?? null }, 200);
}

async function handleResolveInvite(req) {
  const body = await readJson(req);
  const inviteCode = String(body.inviteCode ?? '').trim();

  if (!inviteCode) {
    return jsonResponse({ error: 'inviteCode is required' }, 400);
  }

  if (!inviteCodePattern.test(inviteCode)) {
    return jsonResponse({ error: 'inviteCode has invalid format' }, 400);
  }

  const response = await supabaseRest(
    `/rest/v1/groups?select=id,name,description,invite_paused&invite_code=eq.${encodeURIComponent(inviteCode)}&limit=1`,
    { method: 'GET' },
  );

  if (!response.ok) {
    const errorText = await response.text();
    return jsonResponse({ error: errorText || 'Could not load invite' }, 502);
  }

  const groups = await response.json();
  const group = Array.isArray(groups) ? groups[0] : null;

  if (!group) {
    return jsonResponse({ error: 'La invitacion no existe o ya no es valida.' }, 404);
  }

  if (group.invite_paused) {
    return jsonResponse({ error: 'Este enlace de invitacion esta pausado.' }, 403);
  }

  return jsonResponse({
    groupId: group.id,
    groupName: group.name,
    groupDescription: group.description ?? '',
  });
}

async function handleDeleteAccount(req) {
  return proxyToSupabaseFunction('delete-account', req);
}

async function handleRegisterUser(req) {
  return proxyToSupabaseFunction('register-user', req);
}

async function handleJoinGuestWithPhoto(req) {
  return proxyToSupabaseFunction('join-guest-with-photo', req);
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);

    if (req.method === 'OPTIONS') {
      res.writeHead(204, corsHeaders);
      res.end();
      return;
    }

    if (url.pathname === '/health') {
      res.writeHead(200, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
      return;
    }

    if (req.method === 'GET' && url.pathname === '/') {
      res.writeHead(200, { ...corsHeaders, 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ name: 'vibeloop-backend', ok: true }));
      return;
    }

    if (req.method !== 'POST') {
      const response = jsonResponse({ error: 'Method not allowed' }, 405);
      res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
      res.end(await response.text());
      return;
    }

    if (url.pathname === '/functions/v1/send-anonymous-message') {
      const response = await handleSendAnonymousMessage(req);
      res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
      res.end(await response.text());
      return;
    }

    if (url.pathname === '/functions/v1/resolve-invite') {
      const response = await handleResolveInvite(req);
      res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
      res.end(await response.text());
      return;
    }

    if (url.pathname === '/functions/v1/delete-account') {
      const response = await handleDeleteAccount(req);
      res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
      res.end(await response.text());
      return;
    }

    if (url.pathname === '/functions/v1/register-user') {
      const response = await handleRegisterUser(req);
      res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
      res.end(await response.text());
      return;
    }

    if (url.pathname === '/functions/v1/join-guest-with-photo') {
      const response = await handleJoinGuestWithPhoto(req);
      res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
      res.end(await response.text());
      return;
    }

    const response = jsonResponse({ error: 'Not found' }, 404);
    res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
    res.end(await response.text());
  } catch (error) {
    const response = jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error' },
      500,
    );
    res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
    res.end(await response.text());
  }
});

server.listen(port, () => {
  console.log(`VIBELOOP backend running on http://localhost:${port}`);
});
