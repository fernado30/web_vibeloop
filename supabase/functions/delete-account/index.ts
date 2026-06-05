import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function createUserClient(req: Request) {
  return createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: req.headers.get('Authorization') ?? '',
      },
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

function createAdminClient() {
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
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
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error('Missing Supabase configuration');
    }

    const body = await req.json().catch(() => ({}));
    const confirmationText = String(body.confirmationText ?? '').trim().toUpperCase();
    if (confirmationText !== 'ELIMINAR') {
      return new Response(JSON.stringify({ error: 'confirmationText must be ELIMINAR' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userClient = createUserClient(req);
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const user = userData.user;
    const admin = createAdminClient();

    const { data: photoRows, error: photoError } = await admin
      .from('group_photos')
      .select('storage_path')
      .eq('uploaded_by', user.id);

    if (photoError) throw photoError;

    const photoPaths = (photoRows ?? [])
      .map((row) => row.storage_path?.toString().trim())
      .filter((path) => typeof path === 'string' && path.length > 0);

    const { error: avatarListError, data: avatarFiles } = await admin.storage.from('avatars').list(user.id, {
      limit: 1000,
      offset: 0,
    });
    if (avatarListError) throw avatarListError;

    const avatarPaths = (avatarFiles ?? [])
      .map((file) => `${user.id}/${file.name}`)
      .filter((path) => path.trim().length > 0);

    await Promise.all([
      admin.from('user_hidden_words').delete().eq('user_id', user.id),
      admin.from('user_blocked_users').delete().eq('user_id', user.id),
      admin.from('user_message_filter_settings').delete().eq('user_id', user.id),
      admin.from('notifications').delete().eq('user_id', user.id),
      admin.from('reactions').delete().eq('user_id', user.id),
      admin.from('group_members').delete().eq('user_id', user.id),
      admin.from('group_photos').delete().eq('uploaded_by', user.id),
      admin.from('users').update({
        username: `deleted_${user.id.slice(0, 8)}`,
        display_name: 'Cuenta eliminada',
        avatar_url: null,
        emoji: '🙂',
      }).eq('id', user.id),
    ]);

    if (photoPaths.length > 0) {
      await admin.storage.from('group-photos').remove(Array.from(new Set(photoPaths)));
    }

    if (avatarPaths.length > 0) {
      await admin.storage.from('avatars').remove(Array.from(new Set(avatarPaths)));
    }

    await admin.auth.admin.deleteUser(user.id, true);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Unexpected error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
