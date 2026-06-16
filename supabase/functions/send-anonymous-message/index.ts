import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const inviteCodePattern = /^[a-zA-Z0-9_-]{4,64}$/;

function hasUrl(content: string) {
  return /(https?:\/\/|www\.)/i.test(content);
}

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
      .select('id, invite_paused')
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

    return jsonResponse({ success: true, id: data.id }, 200);
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : 'Unexpected error' }, 500);
  }
});
