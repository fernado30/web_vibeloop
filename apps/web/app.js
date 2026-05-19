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
const hintEl = document.getElementById('hint');

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

function buildMobileLink(token) {
  return `vibeloop:/invite/${token}`;
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

    const client = createClient(config.supabaseUrl, config.supabaseAnonKey, {
      global: {
        headers: {
          'x-invite-code': inviteCode,
        },
      },
    });

    const { data: groups, error } = await client
      .from('groups')
      .select('id, name, description, created_at, invite_code, group_members(id)')
      .eq('invite_code', inviteCode)
      .limit(1);

    if (error) {
      throw new Error(`No se pudo cargar la invitación: ${error.message}`);
    }

    const group = Array.isArray(groups) ? groups[0] : null;

    if (!group) {
      throw new Error('La invitación no existe o ya no es válida.');
    }

    showInvite();
    groupNameEl.textContent = group.name ?? 'Grupo';
    groupDescriptionEl.textContent = group.description || 'Sin descripción.';
    memberCountEl.textContent = `${group.group_members?.length ?? 0} miembros`;
    createdAtEl.textContent = `Creado ${formatDate(group.created_at)}`;

    let selectedFile = null;
    let previewUrl = null;

    photoInputEl.addEventListener('change', (event) => {
      const file = event.target.files?.[0] ?? null;
      selectedFile = file;
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
        previewUrl = null;
      }

      if (file) {
        previewUrl = URL.createObjectURL(file);
        previewEl.style.backgroundImage = `url(${previewUrl})`;
        previewEl.classList.remove('hidden');
        joinButtonEl.disabled = false;
        hintEl.textContent = 'Tu foto está lista. Pulsa acceder para abrir el chat en la app.';
      } else {
        setPreview(null);
        joinButtonEl.disabled = true;
        hintEl.textContent = 'Primero sube una foto para continuar.';
      }
    });

    joinButtonEl.addEventListener('click', async () => {
      if (!selectedFile) {
        showError('Primero sube una foto para poder acceder al grupo.');
        return;
      }

      joinButtonEl.disabled = true;
      joinButtonEl.textContent = 'Abriendo la app...';

      const mobileLink = buildMobileLink(token);
      window.location.href = mobileLink;

      setTimeout(() => {
        if (document.visibilityState === 'visible') {
          joinButtonEl.disabled = false;
          joinButtonEl.textContent = 'Acceder al grupo';
          hintEl.textContent = 'Si la app no se abrió, revisa que VIBELOOP esté instalado en tu teléfono.';
        }
      }, 1500);
    });

    joinButtonEl.disabled = true;
    joinButtonEl.textContent = 'Acceder al grupo';
    hintEl.textContent = 'Sube tu foto y pulsa acceder para abrir el chat en la app móvil.';
  } catch (err) {
    showError(err instanceof Error ? err.message : 'No se pudo iniciar la web.');
  }
}

bootstrap();
