import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const INVITE_CODE_RE = /^[a-zA-Z0-9_-]{4,64}$/;

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error('Missing Supabase configuration');
    }

    const body = await req.json().catch(() => ({}));
    const inviteCode = String(body.inviteCode ?? '').trim();

    if (!inviteCode) {
      return jsonResponse({ error: 'inviteCode is required' }, 400);
    }

    if (!INVITE_CODE_RE.test(inviteCode)) {
      return jsonResponse({ error: 'inviteCode has invalid format' }, 400);
    }

    const { data: group, error: groupError } = await adminClient
      .from('groups')
      .select('id, name, description, invite_paused')
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

    return jsonResponse({
      groupId: group.id,
      groupName: group.name,
      groupDescription: group.description ?? '',
    });
  } catch (err) {
    console.error('resolve-invite error:', err);
    return jsonResponse(
      { error: err instanceof Error ? err.message : 'Error inesperado.' },
      500,
    );
  }
});
