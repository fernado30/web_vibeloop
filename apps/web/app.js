import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const config = window.VIBELOOP_WEB_CONFIG ?? {};
const landingViewEl = document.getElementById('landingView');
const inboxViewEl = document.getElementById('inboxView');
const statusEl = document.getElementById('status');
const errorViewEl = document.getElementById('errorView');
const groupNameEl = document.getElementById('groupName');
const groupDescriptionEl = document.getElementById('groupDescription');
const messageFormEl = document.getElementById('messageForm');
const messageInputEl = document.getElementById('messageInput');
const charCountEl = document.getElementById('charCount');
const sendButtonEl = document.getElementById('sendButton');
const feedbackEl = document.getElementById('feedback');
const openNativeButtonEl = document.getElementById('openNativeButton');
const landingHintEl = document.getElementById('landingHint');

const MAX_MESSAGE_LENGTH = 500;
const ANDROID_PACKAGE = 'com.vibeloop.vibeloop';
const ANDROID_PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.vibeloop.vibeloop';

function requireConfig() {
  const missing = [];
  if (!config.supabaseUrl || config.supabaseUrl.includes('YOUR_PROJECT')) missing.push('supabaseUrl');
  if (!config.supabaseAnonKey || config.supabaseAnonKey.includes('YOUR_SUPABASE')) missing.push('supabaseAnonKey');

  if (missing.length > 0) {
    throw new Error(`Falta configurar ${missing.join(', ')} en config.js.`);
  }
}

function showError(message) {
  landingViewEl.classList.add('hidden');
  inboxViewEl.classList.add('hidden');
  errorViewEl.textContent = message;
  errorViewEl.classList.remove('hidden');
}

function showLanding() {
  errorViewEl.classList.add('hidden');
  inboxViewEl.classList.add('hidden');
  landingViewEl.classList.remove('hidden');
}

function showInbox() {
  errorViewEl.classList.add('hidden');
  landingViewEl.classList.add('hidden');
  inboxViewEl.classList.remove('hidden');
}

function parseRoute() {
  const path = window.location.pathname.replace(/\/+$/, '') || '/';
  const joinMatch = path.match(/^\/join\/([^/]+)$/);
  if (joinMatch) {
    return { kind: 'join', token: joinMatch[1] };
  }

  const openMatch = path.match(/^\/open\/([^/]+)$/);
  if (openMatch) {
    return { kind: 'open', token: openMatch[1] };
  }

  const inviteMatch = path.match(/^\/invite\/([^/]+)$/);
  if (inviteMatch) {
    return { kind: 'invite', token: inviteMatch[1] };
  }

  return { kind: 'invalid', token: null };
}

function getInviteCode(token) {
  const parts = token.split('-');
  return parts[parts.length - 1] ?? null;
}

function emojiForSeed(seed) {
  const emojis = ['🙂', '✨', '🌙', '💙', '🫶', '🔥', '🌊', '🍀', '⚡', '🎧'];
  let hash = 0;
  for (let index = 0; index < seed.length; index += 1) {
    hash = (hash * 31 + seed.charCodeAt(index)) >>> 0;
  }
  return emojis[hash % emojis.length];
}

async function ensureGuestMembership(client, groupId, inviteCode) {
  const { data: sessionData, error: sessionError } = await client.auth.getSession();
  if (sessionError) {
    throw new Error(`No pudimos iniciar la sesión anónima: ${sessionError.message}`);
  }

  if (!sessionData.session) {
    const { error: signInError } = await client.auth.signInAnonymously();
    if (signInError) {
      throw new Error(`No pudimos iniciar la sesión anónima: ${signInError.message}`);
    }
  }

  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData.user) {
    throw new Error('No pudimos identificar la sesión invitada.');
  }

  const user = userData.user;
  const username = `invitado_${user.id.replace(/-/g, '').slice(0, 8)}`;
  const displayName = 'Invitado';

  const { error: profileError } = await client.from('users').upsert({
    id: user.id,
    username,
    display_name: displayName,
    avatar_url: null,
    emoji: emojiForSeed(inviteCode ?? user.id),
  });

  if (profileError) {
    throw new Error(`No pudimos preparar tu perfil invitado: ${profileError.message}`);
  }

  const { error: memberError } = await client.from('group_members').upsert(
    {
      group_id: groupId,
      user_id: user.id,
      role: 'member',
    },
    {
      onConflict: 'group_id,user_id',
    },
  );

  if (memberError) {
    throw new Error(`No pudimos unir tu sesión al grupo: ${memberError.message}`);
  }
}

function hasUrl(content) {
  return /(https?:\/\/|www\.)/i.test(content);
}

function buildNativeIntentUrl(token) {
  const fallbackUrl = `${window.location.origin}/invite/${token}`;
  return `intent://invite/${token}#Intent;scheme=vibeloop;package=${ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(fallbackUrl)};end`;
}

function updateCharacterCount() {
  charCountEl.textContent = `${messageInputEl.value.length}/${MAX_MESSAGE_LENGTH}`;
}

function setSendingState(isSending) {
  sendButtonEl.disabled = isSending;
  messageInputEl.disabled = isSending;
  sendButtonEl.textContent = isSending ? 'Enviando...' : '¡Enviar!';
}

function flashFeedback(message, kind = 'success') {
  feedbackEl.textContent = message;
  feedbackEl.dataset.kind = kind;
  feedbackEl.classList.remove('hidden');
}

async function loadAnonymousInbox(token) {
  const inviteCode = getInviteCode(token);
  if (!inviteCode) {
    throw new Error('No pudimos leer el código del enlace.');
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
    .select('id, name, description, created_at')
    .eq('invite_code', inviteCode)
    .limit(1);

  if (error) {
    throw new Error(`No se pudo cargar el buzón anónimo: ${error.message}`);
  }

  const group = Array.isArray(groups) ? groups[0] : null;
  if (!group) {
    throw new Error('La invitación no existe o ya no es válida.');
  }

  await ensureGuestMembership(client, group.id, inviteCode);

  showInbox();
  groupNameEl.textContent = group.name ?? 'Mensajes anónimos';
  groupDescriptionEl.textContent = group.description || 'Escribe algo anónimo para este grupo. Sin login, sin nombre y sin perfil.';

  updateCharacterCount();
  messageInputEl.addEventListener('input', updateCharacterCount);

  messageFormEl.addEventListener('submit', async (event) => {
    event.preventDefault();

    const content = messageInputEl.value.trim();
    if (!content) {
      flashFeedback('Escribe un mensaje antes de enviar.', 'error');
      return;
    }

    if (content.length > MAX_MESSAGE_LENGTH) {
      flashFeedback(`El mensaje no puede pasar de ${MAX_MESSAGE_LENGTH} caracteres.`, 'error');
      return;
    }

    if (hasUrl(content)) {
      flashFeedback('No permitimos URLs dentro del mensaje.', 'error');
      return;
    }

    setSendingState(true);
    feedbackEl.classList.add('hidden');

    try {
      const { error: insertError } = await client.from('anonymous_messages').insert({
        group_id: group.id,
        content,
      });

      if (insertError) {
        throw new Error(insertError.message);
      }

      messageInputEl.value = '';
      updateCharacterCount();
      flashFeedback('Mensaje enviado de forma anónima.', 'success');
    } catch (err) {
      flashFeedback(
        err instanceof Error ? `No se pudo enviar el mensaje: ${err.message}` : 'No se pudo enviar el mensaje.',
        'error',
      );
    } finally {
      setSendingState(false);
    }
  });
}

function attemptNativeOpen(token) {
  const intentUrl = buildNativeIntentUrl(token);
  window.location.href = intentUrl;

  window.setTimeout(() => {
    if (document.visibilityState === 'visible') {
      landingHintEl.textContent = 'No detectamos la app. Si quieres entrar al chat del grupo, instálala primero.';
      openNativeButtonEl.textContent = 'Instalar la app';
      openNativeButtonEl.onclick = () => {
        window.location.href = ANDROID_PLAY_STORE_URL;
      };
    }
  }, 1500);
}

async function bootstrap() {
  try {
    requireConfig();

    const route = parseRoute();
    if (route.kind === 'invalid') {
      showError('La ruta no es válida. Usa /open/:token o /invite/:token.');
      return;
    }

    if (route.kind === 'open') {
      showLanding();
      openNativeButtonEl.onclick = () => attemptNativeOpen(route.token);
      attemptNativeOpen(route.token);
      return;
    }

    await loadAnonymousInbox(route.token);
  } catch (err) {
    showError(err instanceof Error ? err.message : 'No se pudo iniciar la web.');
  }
}

bootstrap();
