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
    const groupId = String(body.groupId ?? '').trim();
    if (!groupId) {
      return new Response(JSON.stringify({ error: 'groupId is required' }), {
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

    const { data: group, error: groupError } = await admin
      .from('groups')
      .select('id, created_by, name')
      .eq('id', groupId)
      .maybeSingle();

    if (groupError) throw groupError;
    if (!group) {
      return new Response(JSON.stringify({ error: 'Group not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (group.created_by !== user.id) {
      return new Response(JSON.stringify({ error: 'Only the group owner can delete it' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: photoRows, error: photoError } = await admin
      .from('group_photos')
      .select('storage_path')
      .eq('group_id', groupId);
    if (photoError) throw photoError;

    const storagePaths = (photoRows ?? [])
      .map((row) => String(row.storage_path ?? '').trim())
      .filter((path) => typeof path === 'string' && path.length > 0);

    if (storagePaths.length > 0) {
      const { error: storageError } = await admin.storage.from('group-photos').remove(Array.from(new Set(storagePaths)));
      if (storageError) throw storageError;
    }

    const { error: deleteGroupError } = await admin.from('groups').delete().eq('id', groupId);
    if (deleteGroupError) throw deleteGroupError;

    return new Response(JSON.stringify({ success: true, groupId }), {
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
