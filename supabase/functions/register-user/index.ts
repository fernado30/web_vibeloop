import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const supabase = createClient(supabaseUrl, serviceRoleKey, {
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

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isUnder13(birthDate: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) return null;
  const date = new Date(`${birthDate}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return null;
  const today = new Date();
  let age = today.getUTCFullYear() - date.getUTCFullYear();
  if (today.getUTCMonth() < date.getUTCMonth() ||
      (today.getUTCMonth() === date.getUTCMonth() && today.getUTCDate() < date.getUTCDate())) age--;
  return age < 13;
}

function safeSlug(value: string) {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 24) || 'usuario';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const email = String(body.email ?? '').trim().toLowerCase();
    const password = String(body.password ?? '').trim();
    const displayName = String(body.displayName ?? '').trim().slice(0, 60) || 'Usuario';
    const birthDate = String(body.birthDate ?? '').trim();
    const privacyPolicyVersion = String(body.privacyPolicyVersion ?? '').trim().slice(0, 64);
    const under13 = isUnder13(birthDate);
    if (under13 === null) return new Response(JSON.stringify({ error: 'birthDate is required and must use YYYY-MM-DD' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    if (under13) return new Response(JSON.stringify({ error: 'Vibeloop no está dirigido a menores de 13 años.' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    if (!privacyPolicyVersion) return new Response(JSON.stringify({ error: 'privacyPolicyVersion is required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

    if (!email || !emailPattern.test(email) || email.length > 254) {
      return new Response(JSON.stringify({ error: 'email is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (password.length < 8) {
      return new Response(JSON.stringify({ error: 'password must be at least 8 characters' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: createdUser, error: createUserError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        display_name: displayName,
        is_under_13: false,
      },
    });

    if (createUserError || !createdUser.user) {
      throw createUserError ?? new Error('No se pudo crear el usuario');
    }

    const user = createdUser.user;
    const username = `${safeSlug(displayName)}_${user.id.slice(0, 8)}`;

    const { error: profileError } = await supabase.from('users').upsert({
      id: user.id,
      username,
      display_name: displayName,
      avatar_url: null,
      is_under_13: false,
      privacy_policy_version: privacyPolicyVersion,
      privacy_consent_at: new Date().toISOString(),
    });

    if (profileError) {
      throw profileError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        userId: user.id,
        email: user.email,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unexpected error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
