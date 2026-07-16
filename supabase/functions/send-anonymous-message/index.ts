import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = resolveServiceRoleKey();
const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID')?.trim() ?? '';
const firebaseClientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')?.trim() ?? '';
const firebasePrivateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')?.trim().replace(/\\n/g, '\n') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const inviteCodePattern = /^[a-zA-Z0-9_-]{4,64}$/;

function hasUrl(content: string) {
  return /(https?:\/\/|www\.)/i.test(content);
}

function resolveServiceRoleKey() {
  const legacyKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim() ?? '';
  if (legacyKey) {
    return legacyKey;
  }

  const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS')?.trim() ?? '';
  if (!secretKeys) {
    return '';
  }

  try {
    const parsed = JSON.parse(secretKeys);
    if (!parsed || typeof parsed !== 'object') {
      return '';
    }

    const candidates = [
      'service_role',
      'serviceRole',
      'service_role_key',
      'serviceRoleKey',
      'service-role',
      'secret',
      'default',
    ];

    for (const candidate of candidates) {
      const value = (parsed as Record<string, unknown>)[candidate];
      if (typeof value === 'string' && value.trim()) {
        return value.trim();
      }
    }

    for (const value of Object.values(parsed as Record<string, unknown>)) {
      if (typeof value === 'string' && value.trim()) {
        return value.trim();
      }
    }
  } catch (_) {
    // Fall through to the empty-string error path below.
  }

  return '';
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function hasFirebaseConfig() {
  return Boolean(firebaseProjectId && firebaseClientEmail && firebasePrivateKey);
}

function base64UrlEncode(input: string | ArrayBuffer | Uint8Array) {
  const bytes =
    typeof input === 'string'
      ? new TextEncoder().encode(input)
      : input instanceof Uint8Array
        ? input
        : new Uint8Array(input);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function pemToDer(pem: string) {
  const raw = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binary = atob(raw);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

let firebaseKeyPromise: Promise<CryptoKey> | null = null;
let firebaseAccessTokenCache: string | null = null;
let firebaseAccessTokenExpiresAt = 0;

async function getFirebaseSigningKey() {
  if (firebaseKeyPromise) {
    return firebaseKeyPromise;
  }

  firebaseKeyPromise = crypto.subtle.importKey(
    'pkcs8',
    pemToDer(firebasePrivateKey),
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );

  return firebaseKeyPromise;
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
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    await getFirebaseSigningKey(),
    new TextEncoder().encode(unsignedToken),
  );
  const assertion = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

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
}: {
  token: string;
  title: string;
  body: string;
  route: string;
  groupId: string;
  category: string;
  soundEnabled: boolean;
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
  groupName,
  title,
  body,
  route,
  category,
}: {
  groupId: string;
  groupName: string;
  title: string;
  body: string;
  route: string;
  category: 'anonymous' | 'message';
}) {
  if (!hasFirebaseConfig()) {
    return;
  }

  const membersResponse = await adminClient
    .from('group_members')
    .select('user_id')
    .eq('group_id', groupId);

  if (membersResponse.error) {
    console.warn('[push] Could not load group members:', membersResponse.error);
    return;
  }

  const recipientIds = (membersResponse.data ?? [])
    .map((row) => row.user_id?.toString().trim())
    .filter((userId) => Boolean(userId));

  if (recipientIds.length === 0) {
    return;
  }

  for (const recipientId of recipientIds) {
    const devicesResponse = await adminClient
      .from('user_push_devices')
      .select('fcm_token,show_message_previews,sounds_enabled,vibration_enabled,notifications_enabled')
      .eq('user_id', recipientId)
      .eq('notifications_enabled', true);

    if (devicesResponse.error) {
      console.warn('[push] Could not load push devices:', devicesResponse.error);
      continue;
    }

    for (const device of devicesResponse.data ?? []) {
      const token = device.fcm_token?.toString().trim();
      if (!token) {
        continue;
      }

      const showPreviews = device.show_message_previews !== false;
      const soundEnabled = device.sounds_enabled !== false;
      const notificationBody = showPreviews
        ? category === 'anonymous'
          ? (groupName ? `Te han enviado un mensaje anónimo en ${groupName}` : 'Te han enviado un mensaje anónimo')
          : (groupName ? `Tienes un mensaje nuevo en ${groupName}` : 'Tienes un mensaje nuevo')
        : body;

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

const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error('Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY, or provide SUPABASE_SECRET_KEYS.');
    }

    const body = await req.json().catch(() => ({}));
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

    if (hasUrl(content)) {
      return jsonResponse({ error: 'URLs are not allowed' }, 400);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: group, error: groupError } = await adminClient
      .from('groups')
      .select('id, name, invite_paused')
      .eq('invite_code', inviteCode)
      .maybeSingle();

    if (groupError) {
      throw groupError;
    }

    if (!group) {
      return jsonResponse({ error: 'La invitacion no existe o ya no es valida.' }, 404);
    }

    if (group.invite_paused) {
      return jsonResponse({ error: 'Este enlace de invitacion esta pausado.' }, 403);
    }

    const { data, error } = await adminClient
      .from('anonymous_messages')
      .insert({
        group_id: group.id,
        content,
      })
      .select('id')
      .single();

    if (error) {
      throw error;
    }

    await dispatchGroupPush({
      groupId: group.id,
      groupName: String(group.name ?? '').trim(),
      title: 'Mensaje anónimo',
      body: 'Te han enviado un mensaje anónimo',
      route: `/groups/${group.id}/anonymous`,
      category: 'anonymous',
    });

    return jsonResponse({ success: true, id: data.id }, 200);
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : 'Unexpected error' }, 500);
  }
});
