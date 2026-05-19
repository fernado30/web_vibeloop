import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const config = window.VIBELOOP_WEB_CONFIG ?? {};
const statusEl = document.getElementById('status');
const inviteViewEl = document.getElementById('inviteView');
const errorViewEl = document.getElementById('errorView');
const groupNameEl = document.getElementById('groupName');
const groupDescriptionEl = document.getElementById('groupDescription');
const memberCountEl = document.getElementById('memberCount');
const createdAtEl = document.getElementById('createdAt');
const photoInputEl = document.getElementById('photo');
const previewEl = document.getElementById('preview');
const joinButtonEl = document.getElementById('joinButton');

function showError(message) {
  statusEl.classList.add('hidden');
  inviteViewEl.classList.add('hidden');
  errorViewEl.textContent = message;
  errorViewEl.classList.remove('hidden');
}

function showInvite() {
  statusEl.classList.add('hidden');
  errorViewEl.classList.add('hidden');
  inviteViewEl.classList.remove('hidden');
}

function parseInviteToken() {
  const match = window.location.pathname.match(/^\/invite\/([^/]+)\/?$/);
  if (!match) {
    return null;
  }

  return match[1];
}

function getInviteCode(token) {
  const parts = token.split('-');
  return parts[parts.length - 1] ?? null;
}

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return 'Fecha no disponible';
  }

  return new Intl.DateTimeFormat('es', {
    dateStyle: 'medium',
  }).format(date);
}

function requireConfig() {
  const missing = [];

  if (!config.supabaseUrl || config.supabaseUrl.includes('YOUR_PROJECT')) missing.push('supabaseUrl');
  if (!config.supabaseAnonKey || config.supabaseAnonKey.includes('YOUR_SUPABASE')) missing.push('supabaseAnonKey');

  if (missing.length > 0) {
    throw new Error(`Falta configurar ${missing.join(', ')} en config.js.`);
  }
}

function setPreview(file) {
  if (!file) {
    previewEl.classList.add('hidden');
    previewEl.style.backgroundImage = '';
    return;
  }

  const objectUrl = URL.createObjectURL(file);
  previewEl.style.backgroundImage = `url(${objectUrl})`;
  previewEl.classList.remove('hidden');
}

async function uploadPhoto(client, file, userId) {
  const extension = file.name.split('.').pop()?.toLowerCase() || 'jpg';
  const contentType = file.type || (extension === 'png' ? 'image/png' : 'image/jpeg');
  const path = `${userId}/${Date.now()}.${extension}`;

  const { error } = await client.storage.from('avatars').upload(path, file, {
    contentType,
    upsert: true,
  });

  if (error) {
    throw new Error(`No se pudo subir la foto: ${error.message}`);
  }

  return client.storage.from('avatars').getPublicUrl(path).data.publicUrl;
}

async function bootstrap() {
  try {
    requireConfig();
    const token = parseInviteToken();
    if (!token) {
      showError('La ruta no es válida. Abre un link con formato /invite/:token.');
      return;
    }

    const inviteCode = getInviteCode(token);
    if (!inviteCode) {
      showError('No pudimos leer el código de invitación.');
      return;
    }

    const client = createClient(config.supabaseUrl, config.supabaseAnonKey);
    const { error: authError } = await client.auth.signInAnonymously();
    if (authError) {
      throw new Error(`No se pudo iniciar sesión anónima: ${authError.message}`);
    }

    const { data: group, error } = await client
      .from('groups')
      .select('id, name, description, created_at, invite_code, group_members(id)')
      .eq('invite_code', inviteCode)
      .single();

    if (error) {
      throw new Error(`No se pudo cargar la invitación: ${error.message}`);
    }

    if (!group) {
      throw new Error('La invitación no existe o ya no es válida.');
    }

    showInvite();
    groupNameEl.textContent = group.name ?? 'Grupo';
    groupDescriptionEl.textContent = group.description || 'Sin descripción.';
    memberCountEl.textContent = `${group.group_members?.length ?? 0} miembros`;
    createdAtEl.textContent = `Creado ${formatDate(group.created_at)}`;

    const user = client.auth.currentUser;
    if (!user) {
      throw new Error('No hay una sesión activa para continuar.');
    }

    let selectedFile = null;

    photoInputEl.addEventListener('change', (event) => {
      const file = event.target.files?.[0] ?? null;
      selectedFile = file;
      setPreview(file);
    });

    joinButtonEl.addEventListener('click', async () => {
      joinButtonEl.disabled = true;
      joinButtonEl.textContent = 'Entrando...';

      try {
        let avatarUrl = null;
        if (selectedFile) {
          avatarUrl = await uploadPhoto(client, selectedFile, user.id);
        }

        const displayName = 'Invitado';
        const username = `${displayName.toLowerCase()}_${user.id.substring(0, 8)}`;

        const { error: profileError } = await client.from('users').upsert({
          id: user.id,
          username,
          display_name: displayName,
          avatar_url: avatarUrl,
        });

        if (profileError) {
          throw new Error(`No se pudo guardar tu perfil: ${profileError.message}`);
        }

        const { error: joinError } = await client.from('group_members').upsert({
          group_id: group.id,
          user_id: user.id,
          role: 'member',
        });

        if (joinError) {
          throw new Error(`No se pudo entrar al grupo: ${joinError.message}`);
        }

        statusEl.textContent = 'Listo. Ya puedes usar este grupo desde la app o seguir construyendo la web.';
        statusEl.classList.remove('hidden');
        inviteViewEl.classList.add('hidden');
      } catch (joinErr) {
        showError(joinErr instanceof Error ? joinErr.message : 'No se pudo completar el ingreso al grupo.');
      } finally {
        joinButtonEl.disabled = false;
        joinButtonEl.textContent = 'Entrar al grupo';
      }
    });
  } catch (err) {
    showError(err instanceof Error ? err.message : 'No se pudo iniciar la web.');
  }
}

bootstrap();
