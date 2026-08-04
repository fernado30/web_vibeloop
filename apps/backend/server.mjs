import { createServer } from 'node:http';
import { createSign, randomUUID } from 'node:crypto';

const port = Number(process.env.PORT ?? 8787);
const supabaseUrl = (process.env.SUPABASE_URL ?? '').trim().replace(/\/+$/, '');
const serviceRoleKey = (process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
const anonKey = (process.env.SUPABASE_ANON_KEY ?? '').trim();
const internalRouteKey = (process.env.BACKEND_INTERNAL_KEY ?? '').trim();
const firebaseProjectId = (process.env.FIREBASE_PROJECT_ID ?? '').trim();
const firebaseClientEmail = (process.env.FIREBASE_CLIENT_EMAIL ?? '').trim();
const firebasePrivateKey = (process.env.FIREBASE_PRIVATE_KEY ?? '').trim().replace(/\\n/g, '\n');
const allowedOrigins = new Set(
  (process.env.ALLOWED_ORIGINS ?? 'https://web-nadie.vercel.app,http://localhost:3000,http://localhost:4173,http://localhost:8080')
    .split(',')
    .map((origin) => origin.trim().replace(/\/+$/, ''))
    .filter(Boolean),
);

const corsAllowHeaders = 'authorization, x-client-info, apikey, content-type';
const corsAllowMethods = 'GET, POST, OPTIONS';

const inviteCodePattern = /^[a-zA-Z0-9_-]{4,64}$/;

export function isUnder13(birthDate) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) return null;
  const date = new Date(`${birthDate}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return null;
  const today = new Date();
  let age = today.getUTCFullYear() - date.getUTCFullYear();
  const birthdayPassed = today.getUTCMonth() > date.getUTCMonth() ||
    (today.getUTCMonth() === date.getUTCMonth() && today.getUTCDate() >= date.getUTCDate());
  if (!birthdayPassed) age -= 1;
  return age < 13;
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  });
}

function textResponse(body, status = 200) {
  return new Response(body, {
    status,
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}

function getRequestHeader(req, name) {
  const headers = req.headers ?? {};
  const lower = name.toLowerCase();
  return String(headers[lower] ?? headers[name] ?? '').trim();
}

async function readJson(req, maxBytes = 8 * 1024 * 1024) {
  const chunks = [];
  let totalBytes = 0;

  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    totalBytes += buffer.length;
    if (totalBytes > maxBytes) {
      throw new Error('Request body too large');
    }
    chunks.push(buffer);
  }

  if (chunks.length === 0) {
    return {};
  }

  const text = Buffer.concat(chunks).toString('utf8').trim();
  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function requireSupabaseConfig() {
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.');
  }
}

function normalizeOrigin(origin) {
  return origin?.trim().replace(/\/+$/, '') ?? '';
}

function buildCorsHeaders(origin) {
  const headers = {
    'Vary': 'Origin',
    'Access-Control-Allow-Headers': corsAllowHeaders,
    'Access-Control-Allow-Methods': corsAllowMethods,
  };

  const normalizedOrigin = normalizeOrigin(origin);
  if (normalizedOrigin && allowedOrigins.has(normalizedOrigin)) {
    headers['Access-Control-Allow-Origin'] = normalizedOrigin;
  }

  return headers;
}

function isOriginAllowed(origin) {
  const normalizedOrigin = normalizeOrigin(origin);
  return !normalizedOrigin || allowedOrigins.has(normalizedOrigin);
}

function sendResponse(req, res, response) {
  const origin = getRequestHeader(req, 'origin');
  const headers = new Headers(response.headers);
  const cors = buildCorsHeaders(origin);

  for (const [key, value] of Object.entries(cors)) {
    headers.set(key, value);
  }

  res.writeHead(response.status, Object.fromEntries(headers.entries()));
  return response.text().then((body) => res.end(body));
}

function getClientIp(req) {
  const forwardedFor = getRequestHeader(req, 'x-forwarded-for').split(',')[0]?.trim();
  const realIp = getRequestHeader(req, 'x-real-ip');
  return forwardedFor || realIp || 'unknown';
}

function getAuthToken(req) {
  const authorization = getRequestHeader(req, 'authorization');
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? '';
}

function getInternalRouteKey(req) {
  return getRequestHeader(req, 'x-backend-internal-key') || getRequestHeader(req, 'x-internal-key');
}

function requireInternalRoute(req) {
  if (!internalRouteKey) {
    return false;
  }

  const providedKey = getInternalRouteKey(req);
  return providedKey.length > 0 && providedKey === internalRouteKey;
}

function rejectIfNotInternal(req) {
  if (requireInternalRoute(req)) {
    return null;
  }

  return jsonResponse({ error: 'Forbidden' }, 403);
}

async function supabaseRest(path, init = {}, useServiceRole = true) {
  requireSupabaseConfig();

  const headers = new Headers(init.headers ?? {});
  const key = useServiceRole ? serviceRoleKey : anonKey;
  if (!key) {
    throw new Error(useServiceRole
      ? 'Missing SUPABASE_SERVICE_ROLE_KEY.'
      : 'Missing SUPABASE_ANON_KEY.');
  }
  headers.set('apikey', key);
  headers.set('Authorization', headers.get('Authorization') ?? `Bearer ${key}`);

  if (init.body != null && !headers.has('Content-Type') && typeof init.body === 'string') {
    headers.set('Content-Type', 'application/json');
  }

  return fetch(`${supabaseUrl}${path}`, {
    ...init,
    headers,
  });
}

let firebaseAccessTokenCache = null;
let firebaseAccessTokenExpiresAt = 0;

function base64UrlEncode(input) {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function hasFirebaseConfig() {
  return Boolean(firebaseProjectId && firebaseClientEmail && firebasePrivateKey);
}

async function getFirebaseAccessToken() {
  if (!hasFirebaseConfig()) {
    return null;
  }

  const now = Math.floor(Date.now() / 1000);
  if (firebaseAccessTokenCache && firebaseAccessTokenExpiresAt - 60 > now) {
    return firebaseAccessTokenCache;
  }

  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64UrlEncode(JSON.stringify({
    iss: firebaseClientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsignedToken = `${header}.${payload}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsignedToken);
  signer.end();

  const signedToken = signer.sign(firebasePrivateKey);
  const assertion = `${unsignedToken}.${base64UrlEncode(signedToken)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    return null;
  }

  const data = await response.json().catch(() => null);
  const accessToken = data?.access_token?.toString().trim();
  const expiresIn = Number(data?.expires_in ?? 0);
  if (!accessToken || !Number.isFinite(expiresIn) || expiresIn <= 0) {
    return null;
  }

  firebaseAccessTokenCache = accessToken;
  firebaseAccessTokenExpiresAt = now + expiresIn;
  return accessToken;
}

async function sendFirebaseMessageToToken({
  token,
  title,
  body,
  route,
  groupId,
  category,
  soundEnabled,
}) {
  const accessToken = await getFirebaseAccessToken();
  if (!accessToken) {
    return false;
  }

  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: {
          title,
          body,
        },
        data: {
          route,
          groupId,
          category,
        },
        android: {
          priority: 'HIGH',
          notification: {
            channel_id: 'vibeloop_activity',
            ...(soundEnabled ? { sound: 'default' } : {}),
          },
        },
        apns: {
          payload: {
            aps: {
              ...(soundEnabled ? { sound: 'default' } : {}),
            },
          },
        },
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => '');
    console.warn('[push] FCM send failed:', response.status, errorText);
    return false;
  }

  return true;
}

async function dispatchGroupPush({
  groupId,
  senderId = null,
  title,
  body,
  route,
  category,
  groupName = '',
}) {
  if (!hasFirebaseConfig()) {
    return;
  }

  const membersResponse = await supabaseRest(
    `/rest/v1/group_members?select=user_id&group_id=eq.${encodeURIComponent(groupId)}`,
    { method: 'GET' },
  );

  if (!membersResponse.ok) {
    const errorText = await membersResponse.text().catch(() => '');
    console.warn('[push] Could not load group members:', errorText);
    return;
  }

  const members = await membersResponse.json().catch(() => []);
  const recipientIds = Array.isArray(members)
    ? members
        .map((row) => row?.user_id?.toString().trim())
        .filter((userId) => userId && userId !== senderId)
    : [];

  if (recipientIds.length === 0) {
    return;
  }

  for (const recipientId of recipientIds) {
    const devicesResponse = await supabaseRest(
      `/rest/v1/user_push_devices?select=fcm_token,show_message_previews,sounds_enabled,vibration_enabled&user_id=eq.${encodeURIComponent(recipientId)}&notifications_enabled=eq.true`,
      { method: 'GET' },
    );

    if (!devicesResponse.ok) {
      const errorText = await devicesResponse.text().catch(() => '');
      console.warn('[push] Could not load push devices:', errorText);
      continue;
    }

    const devices = await devicesResponse.json().catch(() => []);
    for (const device of Array.isArray(devices) ? devices : []) {
      const token = device?.fcm_token?.toString().trim();
      if (!token) {
        continue;
      }

      const showPreviews = device?.show_message_previews !== false;
      const soundEnabled = device?.sounds_enabled !== false;
      const notificationBody = showPreviews
        ? category === 'anonymous'
          ? (groupName ? `Te han enviado un mensaje anónimo en ${groupName}` : 'Te han enviado un mensaje anónimo')
          : (groupName ? `Tienes un mensaje nuevo en ${groupName}` : 'Tienes un mensaje nuevo')
        : category === 'anonymous'
          ? 'Te han enviado un mensaje anónimo'
          : 'Tienes un mensaje nuevo';

      await sendFirebaseMessageToToken({
        token,
        title,
        body: notificationBody,
        route,
        groupId,
        category,
        soundEnabled,
      });
    }
  }
}

async function claimAnonymousMessageRateLimit(req, inviteCode) {
  const response = await supabaseRest('/rest/v1/rpc/claim_anonymous_message_rate_limit', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      p_invite_code: inviteCode,
      p_client_ip: getClientIp(req),
      p_max_events: 10,
      p_window_seconds: 60,
      p_min_interval_seconds: 1,
    }),
  });

  if (response.ok) {
    return;
  }

  const errorText = await response.text();
  if (errorText.includes('rate_limited_cooldown')) {
    throw new Error('rate_limited_cooldown');
  }

  if (errorText.includes('rate_limited')) {
    throw new Error('rate_limited');
  }

  throw new Error(errorText || 'Could not apply rate limit');
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
    return jsonResponse({ error: 'El mensaje anónimo debe contener entre 1 y 500 caracteres.' }, 400);
  }

  if (/(https?:\/\/|www\.|t\.me|wa\.me|instagram\.com|tiktok\.com|discord\.gg|discord\.com\/invite|snapchat\.com\/add)/i.test(content)) {
    return jsonResponse({ error: 'Los mensajes anónimos no pueden incluir enlaces ni redes sociales.' }, 400);
  }

  if (/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/i.test(content)) {
    return jsonResponse({ error: 'Los mensajes anónimos no pueden incluir correos electrónicos.' }, 400);
  }

  if (/(\+?\d{1,4}[\s-]?)?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}|\b\d{8,15}\b/.test(content)) {
    return jsonResponse({ error: 'Los mensajes anónimos no pueden incluir números telefónicos.' }, 400);
  }

  try {
    await claimAnonymousMessageRateLimit(req, inviteCode);
  } catch (error) {
    if (error instanceof Error && error.message === 'rate_limited') {
      return jsonResponse({ error: 'Too many requests. Try again later.' }, 429);
    }

    if (error instanceof Error && error.message === 'rate_limited_cooldown') {
      return jsonResponse({ error: 'Wait a moment before trying again.' }, 429);
    }

    return jsonResponse({ error: 'No se pudo aplicar el control de tasa.' }, 500);
  }

  const groupResponse = await supabaseRest(
    `/rest/v1/groups?select=id,name,invite_paused&invite_code=eq.${encodeURIComponent(inviteCode)}&limit=1`,
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

  await dispatchGroupPush({
    groupId: group.id,
    title: 'Mensaje anónimo',
    body: 'Te han enviado un mensaje anónimo',
    route: `/groups/${group.id}/anonymous`,
    category: 'anonymous',
    groupName: String(group.name ?? '').trim(),
  });

  return jsonResponse({ success: true, id: message?.id ?? null }, 200);
}

async function handleSendMessage(req) {
  const token = getAuthToken(req);
  if (!token) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const userResponse = await supabaseRest(
    '/auth/v1/user',
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
    false,
  );

  if (!userResponse.ok) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const user = await userResponse.json();
  if (!user?.id) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const body = await readJson(req);
  const groupId = String(body.groupId ?? '').trim();
  const content = String(body.content ?? '').trim();
  const type = String(body.type ?? 'text').trim() || 'text';
  const anonymousMessageId = String(body.anonymousMessageId ?? '').trim();

  if (!groupId) {
    return jsonResponse({ error: 'groupId is required' }, 400);
  }

  if (content.length < 1 || content.length > 500) {
    return jsonResponse({ error: 'content must be between 1 and 500 characters' }, 400);
  }

  const membershipResponse = await supabaseRest(
    `/rest/v1/group_members?select=id&group_id=eq.${encodeURIComponent(groupId)}&user_id=eq.${encodeURIComponent(user.id)}&limit=1`,
    { method: 'GET' },
  );

  if (!membershipResponse.ok) {
    return jsonResponse({ error: 'Could not verify membership' }, 502);
  }

  const memberships = await membershipResponse.json().catch(() => []);
  if (!Array.isArray(memberships) || memberships.length === 0) {
    return jsonResponse({ error: 'Forbidden' }, 403);
  }

  let finalContent = content;
  let finalType = type;

  if (anonymousMessageId) {
    const anonymousResponse = await supabaseRest(
      `/rest/v1/anonymous_messages?select=id,group_id,content&group_id=eq.${encodeURIComponent(groupId)}&id=eq.${encodeURIComponent(anonymousMessageId)}&limit=1`,
      { method: 'GET' },
    );

    if (!anonymousResponse.ok) {
      return jsonResponse({ error: 'Could not load anonymous message' }, 502);
    }

    const anonymousMessages = await anonymousResponse.json().catch(() => []);
    const anonymousMessage = Array.isArray(anonymousMessages) ? anonymousMessages[0] : null;
    if (!anonymousMessage) {
      return jsonResponse({ error: 'Anonymous message not found' }, 404);
    }

    finalContent = String(anonymousMessage.content ?? finalContent).trim();
    finalType = 'text';
  }

  const insertResponse = await supabaseRest('/rest/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    body: JSON.stringify({
      group_id: groupId,
      sender_id: user.id,
      content: finalContent,
      type: finalType,
    }),
  });

  if (!insertResponse.ok) {
    const errorText = await insertResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo enviar el mensaje.' }, 502);
  }

  if (anonymousMessageId) {
    await supabaseRest(
      `/rest/v1/anonymous_messages?id=eq.${encodeURIComponent(anonymousMessageId)}`,
      { method: 'DELETE' },
    );
  }

  const groupsResponse = await supabaseRest(
    `/rest/v1/groups?select=id,name&id=eq.${encodeURIComponent(groupId)}&limit=1`,
    { method: 'GET' },
  );
  const groups = groupsResponse.ok ? await groupsResponse.json().catch(() => []) : [];
  const group = Array.isArray(groups) ? groups[0] : null;

  if (group) {
    await dispatchGroupPush({
      groupId,
      senderId: user.id,
      title: 'Nuevo mensaje',
      body: 'Tienes un mensaje nuevo',
      route: `/groups/${groupId}/chat`,
      category: 'message',
      groupName: String(group?.name ?? '').trim(),
    });
  }

  const data = await insertResponse.json().catch(() => []);
  const message = Array.isArray(data) ? data[0] : data;
  return jsonResponse({ success: true, message }, 200);
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
  const confirmationText = String((await readJson(req)).confirmationText ?? '').trim().toUpperCase();
  if (confirmationText !== 'ELIMINAR') {
    return jsonResponse({ error: 'confirmationText must be ELIMINAR' }, 400);
  }

  const token = getAuthToken(req);
  if (!token) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const userResponse = await supabaseRest(
    '/auth/v1/user',
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
    false,
  );

  if (!userResponse.ok) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const user = await userResponse.json();
  if (!user?.id) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const userId = String(user.id);
  const groupPhotoRowsResponse = await supabaseRest(
    `/rest/v1/group_photos?select=storage_path&uploaded_by=eq.${encodeURIComponent(userId)}`,
    { method: 'GET' },
  );
  const groupPhotoRows = groupPhotoRowsResponse.ok ? await groupPhotoRowsResponse.json() : [];
  const photoPaths = Array.isArray(groupPhotoRows)
    ? groupPhotoRows
        .map((row) => row?.storage_path?.toString().trim())
        .filter((path) => typeof path === 'string' && path.length > 0)
    : [];

  const avatarListResponse = await fetch(`${supabaseUrl}/storage/v1/object/list/avatars`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prefix: userId, limit: 1000, offset: 0 }),
  });
  const avatarFiles = avatarListResponse.ok ? await avatarListResponse.json().catch(() => []) : [];
  const avatarPaths = Array.isArray(avatarFiles)
    ? avatarFiles
        .map((file) => `${userId}/${file.name}`)
        .filter((path) => typeof path === 'string' && path.trim().length > 0)
    : [];

  await Promise.all([
    supabaseRest('/rest/v1/user_hidden_words?user_id=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/user_blocked_users?user_id=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/user_message_filter_settings?user_id=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/notifications?user_id=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/user_push_devices?user_id=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/reactions?user_id=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/group_members?user_id=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/group_photos?uploaded_by=eq.' + encodeURIComponent(userId), { method: 'DELETE' }),
    supabaseRest('/rest/v1/users?id=eq.' + encodeURIComponent(userId), {
      method: 'PATCH',
      headers: {
        Prefer: 'return=minimal',
      },
      body: JSON.stringify({
        username: `deleted_${userId.slice(0, 8)}`,
        display_name: 'Cuenta eliminada',
        avatar_url: null,
        emoji: '🙂',
      }),
    }),
  ]);

  if (photoPaths.length > 0) {
    await fetch(`${supabaseUrl}/storage/v1/object/group-photos`, {
      method: 'DELETE',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ prefixes: Array.from(new Set(photoPaths)) }),
    });
  }

  if (avatarPaths.length > 0) {
    await fetch(`${supabaseUrl}/storage/v1/object/avatars`, {
      method: 'DELETE',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ prefixes: Array.from(new Set(avatarPaths)) }),
    });
  }

  const deleteUserResponse = await fetch(`${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
    method: 'DELETE',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
  });

  if (!deleteUserResponse.ok) {
    const errorText = await deleteUserResponse.text();
    return jsonResponse({ error: errorText || 'Could not delete user' }, 500);
  }

  return jsonResponse({ success: true });
}

async function handleRegisterUser(req) {
  const blockedResponse = rejectIfNotInternal(req);
  if (blockedResponse) {
    return blockedResponse;
  }

  const body = await readJson(req);
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '').trim();
  const displayName = String(body.displayName ?? '').trim().slice(0, 60) || 'Usuario';
  const birthDate = String(body.birthDate ?? '').trim();
  const privacyPolicyVersion = String(body.privacyPolicyVersion ?? '').trim().slice(0, 64);
  const under13 = isUnder13(birthDate);

  if (under13 === null) return jsonResponse({ error: 'birthDate is required and must use YYYY-MM-DD' }, 400);
  if (under13) return jsonResponse({ error: 'Vibeloop no está dirigido a menores de 13 años.' }, 403);
  if (!privacyPolicyVersion) return jsonResponse({ error: 'privacyPolicyVersion is required' }, 400);

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    return jsonResponse({ error: 'email is required' }, 400);
  }

  if (password.length < 8) {
    return jsonResponse({ error: 'password must be at least 8 characters' }, 400);
  }

  const createUserResponse = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: displayName, is_under_13: false },
    }),
  });

  if (!createUserResponse.ok) {
    const errorText = await createUserResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo crear el usuario' }, 500);
  }

  const createdUser = await createUserResponse.json();
  const userId = createdUser?.id ?? createdUser?.user?.id;
  if (!userId) {
    return jsonResponse({ error: 'No se pudo crear el usuario' }, 500);
  }

  const username = `${displayName
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 24) || 'usuario'}_${String(userId).slice(0, 8)}`;

  const profileResponse = await supabaseRest('/rest/v1/users?on_conflict=id', {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify({
      id: userId,
      username,
      display_name: displayName,
      avatar_url: null,
      is_under_13: false,
      privacy_policy_version: privacyPolicyVersion,
      privacy_consent_at: new Date().toISOString(),
    }),
  });

  if (!profileResponse.ok) {
    const errorText = await profileResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo crear el perfil' }, 500);
  }

  return jsonResponse({
    success: true,
    userId,
    email,
  });
}

async function handleJoinGuestWithPhoto(req) {
  const blockedResponse = rejectIfNotInternal(req);
  if (blockedResponse) {
    return blockedResponse;
  }

  const body = await readJson(req);
  const inviteCode = String(body.inviteCode ?? '').trim();
  const imageBase64 = String(body.imageBase64 ?? '').trim();
  const contentType = String(body.contentType ?? 'image/jpeg').trim();
  const filename = String(body.filename ?? 'guest.jpg').trim().slice(0, 80);

  if (!inviteCode) {
    return jsonResponse({ error: 'inviteCode is required' }, 400);
  }

  if (inviteCode.length < 6 || inviteCode.length > 64 || !/^[a-zA-Z0-9_-]+$/.test(inviteCode)) {
    return jsonResponse({ error: 'inviteCode is invalid' }, 400);
  }

  if (!imageBase64) {
    return jsonResponse({ error: 'imageBase64 is required' }, 400);
  }

  if (imageBase64.length > 7 * 1024 * 1024) {
    return jsonResponse({ error: 'imageBase64 is too large' }, 413);
  }

  if (!contentType.startsWith('image/')) {
    return jsonResponse({ error: 'Only image uploads are allowed' }, 400);
  }

  const groupResponse = await supabaseRest(
    `/rest/v1/groups?select=id,name,invite_code&invite_code=eq.${encodeURIComponent(inviteCode)}&limit=1`,
    { method: 'GET' },
  );

  const groups = groupResponse.ok ? await groupResponse.json() : [];
  const group = Array.isArray(groups) ? groups[0] : null;

  if (!group) {
    return jsonResponse({ error: 'Invalid invite code' }, 404);
  }

  const avatarBytes = Uint8Array.from(atob(imageBase64), (char) => char.charCodeAt(0));
  if (avatarBytes.byteLength === 0 || avatarBytes.byteLength > 5 * 1024 * 1024) {
    return jsonResponse({ error: 'Invalid image size' }, 400);
  }

  const uniqueSeed = randomUUID();
  const guestEmail = `guest_${uniqueSeed}@vibeloop.local`;
  const displayName = 'Invitado';
  const username = `${displayName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 24) || 'invitado'}_${uniqueSeed.slice(0, 8)}`;

  const createUserResponse = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: guestEmail,
      email_confirm: true,
      user_metadata: {
        guest: true,
        display_name: displayName,
      },
    }),
  });

  if (!createUserResponse.ok) {
    const errorText = await createUserResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo crear el acceso del invitado' }, 500);
  }

  const createdUser = await createUserResponse.json();
  const userId = createdUser?.id ?? createdUser?.user?.id;
  if (!userId) {
    return jsonResponse({ error: 'No se pudo crear el acceso del invitado' }, 500);
  }

  const avatarPath = `${userId}/${Date.now()}-${filename.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
  const uploadResponse = await fetch(`${supabaseUrl}/storage/v1/object/avatars/${encodeURIComponent(avatarPath)}`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': contentType,
      'x-upsert': 'true',
    },
    body: avatarBytes,
  });

  if (!uploadResponse.ok) {
    const errorText = await uploadResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo subir la imagen' }, 500);
  }

  const avatarUrl = `${supabaseUrl}/storage/v1/object/public/avatars/${avatarPath
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/')}`;

  const profileResponse = await supabaseRest('/rest/v1/users?on_conflict=id', {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify({
      id: userId,
      username,
      display_name: displayName,
      avatar_url: avatarUrl,
    }),
  });

  if (!profileResponse.ok) {
    const errorText = await profileResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo guardar el perfil' }, 500);
  }

  const membershipResponse = await supabaseRest('/rest/v1/group_members?on_conflict=group_id,user_id', {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify({
      group_id: group.id,
      user_id: userId,
      role: 'member',
    }),
  });

  if (!membershipResponse.ok) {
    const errorText = await membershipResponse.text();
    return jsonResponse({ error: errorText || 'No se pudo unir al invitado al grupo' }, 500);
  }

  return jsonResponse({
    success: true,
    userId,
    groupId: group.id,
  });
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
    const origin = getRequestHeader(req, 'origin');

    if (!isOriginAllowed(origin)) {
      await sendResponse(req, res, jsonResponse({ error: 'Origin not allowed' }, 403));
      return;
    }

    if (req.method === 'OPTIONS') {
      const response = textResponse('', 204);
      await sendResponse(req, res, response);
      return;
    }

    if (url.pathname === '/health') {
      await sendResponse(req, res, jsonResponse({ ok: true }, 200));
      return;
    }

    if (req.method === 'GET' && url.pathname === '/') {
      await sendResponse(req, res, jsonResponse({ name: 'vibeloop-backend', ok: true }, 200));
      return;
    }

    if (req.method !== 'POST') {
      const response = jsonResponse({ error: 'Method not allowed' }, 405);
      await sendResponse(req, res, response);
      return;
    }

    if (url.pathname === '/functions/v1/send-anonymous-message') {
      const response = await handleSendAnonymousMessage(req);
      await sendResponse(req, res, response);
      return;
    }

    if (url.pathname === '/functions/v1/send-message') {
      const response = await handleSendMessage(req);
      await sendResponse(req, res, response);
      return;
    }

    if (url.pathname === '/functions/v1/resolve-invite') {
      const response = await handleResolveInvite(req);
      await sendResponse(req, res, response);
      return;
    }

    if (url.pathname === '/functions/v1/delete-account') {
      const response = await handleDeleteAccount(req);
      await sendResponse(req, res, response);
      return;
    }

    if (url.pathname === '/functions/v1/register-user') {
      const response = await handleRegisterUser(req);
      await sendResponse(req, res, response);
      return;
    }

    if (url.pathname === '/functions/v1/join-guest-with-photo') {
      const response = await handleJoinGuestWithPhoto(req);
      await sendResponse(req, res, response);
      return;
    }

    const response = jsonResponse({ error: 'Not found' }, 404);
    await sendResponse(req, res, response);
  } catch (error) {
    const response = jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error' },
      500,
    );
    await sendResponse(req, res, response);
  }
});

if (process.env.NODE_ENV !== 'test') {
  server.listen(port, () => {
    console.log(`VIBELOOP backend running on http://localhost:${port}`);
  });
}
