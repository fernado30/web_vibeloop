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

function getApiBaseUrl() {
  return (config.backendUrl && !config.backendUrl.includes('YOUR_BACKEND'))
    ? config.backendUrl.replace(/\/+$/, '')
    : config.supabaseUrl.replace(/\/+$/, '');
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
  if (joinMatch) return { kind: 'join', token: joinMatch[1] };

  const openMatch = path.match(/^\/open\/([^/]+)$/);
  if (openMatch) return { kind: 'open', token: openMatch[1] };

  const inviteMatch = path.match(/^\/invite\/([^/]+)$/);
  if (inviteMatch) return { kind: 'invite', token: inviteMatch[1] };

  const buzonMatch = path.match(/^\/buzon\/([^/]+)$/);
  if (buzonMatch) return { kind: 'buzon', token: buzonMatch[1] };

  return { kind: 'invalid', token: null };
}

function getInviteCode(token) {
  const parts = token.split('-');
  return parts[parts.length - 1] ?? null;
}

function buildNativeIntentUrl(token) {
  const fallbackUrl = `${window.location.origin}/invite/${token}?no_redirect=true`;
  return `intent://invite/${token}#Intent;scheme=vibeloop;package=${ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(fallbackUrl)};end`;
}

function updateCharacterCount() {
  charCountEl.textContent = `${messageInputEl.value.length}/${MAX_MESSAGE_LENGTH}`;
}

function setSendingState(isSending) {
  sendButtonEl.disabled = isSending;
  messageInputEl.disabled = isSending;
  sendButtonEl.textContent = isSending ? 'Enviando...' : '\u00a1Enviar!';
}

function flashFeedback(message, kind = 'success') {
  feedbackEl.textContent = message;
  feedbackEl.dataset.kind = kind;
  feedbackEl.classList.remove('hidden');
}

function hasUrl(content) {
  return /(https?:\/\/|www\.)/i.test(content);
}

async function postAnonymousMessage(endpointBaseUrl, inviteCode, content, includeAnonKey = false) {
  const response = await fetch(`${endpointBaseUrl.replace(/\/+$/, '')}/functions/v1/send-anonymous-message`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(includeAnonKey ? {
        apikey: config.supabaseAnonKey,
        Authorization: `Bearer ${config.supabaseAnonKey}`,
      } : {}),
    },
    body: JSON.stringify({ inviteCode, content }),
  });

  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(result.error ?? 'No se pudo enviar el mensaje.');
  }

  return result;
}

async function loadAnonymousInbox(token) {
  const inviteCode = getInviteCode(token);
  if (!inviteCode) {
    throw new Error('No pudimos leer el codigo del enlace.');
  }

  showInbox();
  groupNameEl.textContent = 'Buz\u00f3n an\u00f3nimo';
  groupDescriptionEl.textContent = 'Escribe algo an\u00f3nimo para este grupo. Sin login, sin nombre y sin perfil.';

  updateCharacterCount();

  messageFormEl.onsubmit = async (event) => {
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
      const apiBaseUrl = getApiBaseUrl();
      const usesBackend = apiBaseUrl !== config.supabaseUrl;

      try {
        await postAnonymousMessage(apiBaseUrl, inviteCode, content, !usesBackend);
      } catch (primaryError) {
        if (!usesBackend) {
          throw primaryError;
        }

        await postAnonymousMessage(config.supabaseUrl, inviteCode, content, true);
      }

      messageInputEl.value = '';
      updateCharacterCount();
      flashFeedback('Mensaje enviado de forma anonima.', 'success');
    } catch (err) {
      flashFeedback(
        err instanceof Error ? `No se pudo enviar el mensaje: ${err.message}` : 'No se pudo enviar el mensaje.',
        'error',
      );
    } finally {
      setSendingState(false);
    }
  };
}

function attemptNativeOpen(token) {
  const intentUrl = buildNativeIntentUrl(token);
  window.location.href = intentUrl;

  window.setTimeout(() => {
    if (document.visibilityState === 'visible') {
      landingHintEl.textContent = 'No detectamos la app. Si quieres entrar al chat del grupo, instalala primero.';
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
      showError('La ruta no es valida. Usa /open/:token o /invite/:token.');
      return;
    }

    if (route.kind === 'open' || route.kind === 'join') {
      showLanding();
      openNativeButtonEl.onclick = () => attemptNativeOpen(route.token);
      attemptNativeOpen(route.token);
      return;
    }

    if (route.kind === 'invite' || route.kind === 'buzon') {
      await loadAnonymousInbox(route.token);
      return;
    }
  } catch (err) {
    showError(err instanceof Error ? err.message : 'No se pudo iniciar la web.');
  }
}

bootstrap();
