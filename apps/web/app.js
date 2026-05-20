import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const config = window.VIBELOOP_WEB_CONFIG ?? {};
const statusEl = document.getElementById('status');
const errorViewEl = document.getElementById('errorView');
const inboxViewEl = document.getElementById('inboxView');
const groupNameEl = document.getElementById('groupName');
const groupDescriptionEl = document.getElementById('groupDescription');
const messageFormEl = document.getElementById('messageForm');
const messageInputEl = document.getElementById('messageInput');
const charCountEl = document.getElementById('charCount');
const sendButtonEl = document.getElementById('sendButton');
const openAppButtonEl = document.getElementById('openAppButton');
const feedbackEl = document.getElementById('feedback');

const MAX_MESSAGE_LENGTH = 500;

function showError(message) {
  statusEl.classList.add('hidden');
  inboxViewEl.classList.add('hidden');
  errorViewEl.textContent = message;
  errorViewEl.classList.remove('hidden');
}

function showInbox() {
  statusEl.classList.add('hidden');
  errorViewEl.classList.add('hidden');
  inboxViewEl.classList.remove('hidden');
}

function parseInviteToken() {
  const match = window.location.pathname.match(/^\/invite\/([^/]+)\/?$/);
  return match ? match[1] : null;
}

function getInviteCode(token) {
  const parts = token.split('-');
  return parts[parts.length - 1] ?? null;
}

function requireConfig() {
  const missing = [];

  if (!config.supabaseUrl || config.supabaseUrl.includes('YOUR_PROJECT')) missing.push('supabaseUrl');
  if (!config.supabaseAnonKey || config.supabaseAnonKey.includes('YOUR_SUPABASE')) missing.push('supabaseAnonKey');

  if (missing.length > 0) {
    throw new Error(`Falta configurar ${missing.join(', ')} en config.js.`);
  }
}

function buildMobileLink(token) {
  return `vibeloop:/invite/${token}`;
}

function hasUrl(content) {
  return /(https?:\/\/|www\.)/i.test(content);
}

function updateCharacterCount() {
  charCountEl.textContent = `${messageInputEl.value.length}/${MAX_MESSAGE_LENGTH}`;
}

function setSendingState(isSending) {
  sendButtonEl.disabled = isSending;
  messageInputEl.disabled = isSending;
  openAppButtonEl.disabled = isSending;
  sendButtonEl.textContent = isSending ? 'Enviando...' : '¡Enviar!';
}

function flashFeedback(message, kind = 'success') {
  feedbackEl.textContent = message;
  feedbackEl.dataset.kind = kind;
  feedbackEl.classList.remove('hidden');
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
      showError('No pudimos leer el código del enlace.');
      return;
    }

    const client = createClient(config.supabaseUrl, config.supabaseAnonKey);
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

    showInbox();
    groupNameEl.textContent = group.name ?? 'Mensajes anónimos';
    groupDescriptionEl.textContent = group.description || 'Escribe algo anónimo para este grupo. Sin login, sin nombre y sin perfil.';
    openAppButtonEl.addEventListener('click', () => {
      window.location.href = buildMobileLink(token);
    });

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
  } catch (err) {
    showError(err instanceof Error ? err.message : 'No se pudo iniciar la web.');
  }
}

bootstrap();
