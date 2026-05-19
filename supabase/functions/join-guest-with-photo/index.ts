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
    const body = await req.json();
    const inviteCode = String(body.inviteCode ?? '').trim();
    const imageBase64 = String(body.imageBase64 ?? '').trim();
    const contentType = String(body.contentType ?? 'image/jpeg').trim();
    const filename = String(body.filename ?? 'guest.jpg').trim();

    if (!inviteCode) {
      return new Response(JSON.stringify({ error: 'inviteCode is required' }), {
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
    });

    if (profileError) {
      throw profileError;
    }

    const { error: membershipError } = await supabase.from('group_members').upsert({
      group_id: group.id,
      user_id: userId,
      role: 'member',
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
