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

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function hasUrl(content: string) {
  return /(https?:\/\/|www\.)/i.test(content);
}

function toBytes(base64: string) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function safeSlug(value: string) {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 24) || 'invitado';
}

function isUnder13(birthDate: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) return null;
  const parsed = new Date(`${birthDate}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== birthDate) return null;
  const today = new Date();
  let age = today.getUTCFullYear() - parsed.getUTCFullYear();
  if (today.getUTCMonth() < parsed.getUTCMonth() ||
      (today.getUTCMonth() === parsed.getUTCMonth() && today.getUTCDate() < parsed.getUTCDate())) age--;
  return age < 13;
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
    const inviteCode = String(body.inviteCode ?? '').trim();
    const imageBase64 = String(body.imageBase64 ?? '').trim();
    const contentType = String(body.contentType ?? 'image/jpeg').trim();
    const filename = String(body.filename ?? 'guest.jpg').trim().slice(0, 80);
    const birthDate = String(body.birthDate ?? '').trim();
    const privacyPolicyVersion = String(body.privacyPolicyVersion ?? '').trim().slice(0, 64);
    const termsAccepted = body.termsAccepted === true;
    const termsVersion = String(body.termsVersion ?? '').trim().slice(0, 64);
    const under13 = isUnder13(birthDate);

    // This is intentionally the first state-changing gate: no user, object,
    // token or profile exists when it returns 403.
    if (under13 === null) return new Response(JSON.stringify({ error: 'birthDate is required and must use YYYY-MM-DD' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    if (under13) return new Response(JSON.stringify({ error: 'Vibeloop no esta dirigido a menores de 13 anos.' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    if (!privacyPolicyVersion || !termsAccepted || !termsVersion) return new Response(JSON.stringify({ error: 'Privacy policy and terms acceptance are required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

    if (!inviteCode) {
      return new Response(JSON.stringify({ error: 'inviteCode is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (inviteCode.length < 6 || inviteCode.length > 64 || !/^[a-zA-Z0-9_-]+$/.test(inviteCode)) {
      return new Response(JSON.stringify({ error: 'inviteCode is invalid' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!imageBase64) {
      return new Response(JSON.stringify({ error: 'imageBase64 is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (imageBase64.length > 7 * 1024 * 1024) {
      return new Response(JSON.stringify({ error: 'imageBase64 is too large' }), {
        status: 413,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!contentType.startsWith('image/')) {
      return new Response(JSON.stringify({ error: 'Only image uploads are allowed' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: group, error: groupError } = await supabase
      .from('groups')
      .select('id, name, invite_code')
      .eq('invite_code', inviteCode)
      .single();

    if (groupError || !group) {
      return new Response(JSON.stringify({ error: 'Invalid invite code' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const avatarBytes = toBytes(imageBase64);
    if (avatarBytes.byteLength === 0 || avatarBytes.byteLength > 5 * 1024 * 1024) {
      return new Response(JSON.stringify({ error: 'Invalid image size' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const uniqueSeed = crypto.randomUUID();
    const guestEmail = `guest_${uniqueSeed}@vibeloop.local`;
    const displayName = 'Invitado';
    const username = `${safeSlug(displayName)}_${uniqueSeed.slice(0, 8)}`;

    const { data: createdUser, error: createUserError } = await supabase.auth.admin.createUser({
      email: guestEmail,
      email_confirm: true,
      user_metadata: {
        guest: true,
        display_name: displayName,
      },
    });

    if (createUserError || !createdUser.user) {
      throw createUserError ?? new Error('No se pudo crear el acceso del invitado');
    }

    const userId = createdUser.user.id;
    const avatarPath = `${userId}/${Date.now()}-${filename.replace(/[^a-zA-Z0-9._-]/g, '_')}`;

    const { error: uploadError } = await supabase.storage.from('avatars').upload(avatarPath, new Blob([avatarBytes], { type: contentType }), {
      contentType,
      upsert: true,
    });

    if (uploadError) {
      throw uploadError;
    }

    const avatarUrl = supabase.storage.from('avatars').getPublicUrl(avatarPath).data.publicUrl;

    const { error: profileError } = await supabase.from('users').upsert({
      id: userId,
      username,
      display_name: displayName,
      avatar_url: avatarUrl,
      age_verified_13_plus: true,
      age_verified_at: new Date().toISOString(),
      privacy_consent_at: new Date().toISOString(),
      privacy_policy_version: privacyPolicyVersion,
      terms_accepted_at: new Date().toISOString(),
      terms_version: termsVersion,
    });

    if (profileError) {
      throw profileError;
    }

    const { error: membershipError } = await supabase.from('group_members').upsert({
      group_id: group.id,
      user_id: userId,
      role: 'member',
    }, {
      onConflict: 'group_id,user_id',
    });

    if (membershipError) {
      throw membershipError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        userId,
        groupId: group.id,
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
