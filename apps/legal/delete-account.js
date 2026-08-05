function handleAccountDeletionRequest(event) {
  event.preventDefault();
  
  const emailInput = document.getElementById('user-email');
  const reasonInput = document.getElementById('deletion-reason');
  const confirmCheckbox = document.getElementById('confirm-deletion');
  const feedbackEl = document.getElementById('deletion-feedback');
  const btnSubmit = document.getElementById('btn-submit-deletion');

  const email = emailInput ? emailInput.value.trim() : '';
  const reason = reasonInput ? reasonInput.value.trim() : '';

  if (!email || !email.includes('@')) {
    showFeedback('Por favor ingresa un correo electrónico válido registrado en Nadie.', 'error');
    return;
  }

  if (!confirmCheckbox || !confirmCheckbox.checked) {
    showFeedback('Debes confirmar que comprendes que la eliminación es permanente e irreversible.', 'error');
    return;
  }

  btnSubmit.disabled = true;
  btnSubmit.innerHTML = '⏳ Procesando solicitud...';

  // Simulate network request / API logging
  setTimeout(() => {
    const formContainer = document.getElementById('deletion-form-container');
    if (formContainer) {
      formContainer.innerHTML = `
        <div class="deletion-success-card">
          <div class="success-icon">✅</div>
          <h3>Solicitud de Eliminación Registrada</h3>
          <p>Hemos recibido la solicitud para la cuenta vinculada a <strong>${escapeHtml(email)}</strong>.</p>
          <p>Un agente de soporte verificará el estado de la cuenta e iniciará el proceso de purgado de datos personales en un plazo máximo de <strong>48 horas hábiles</strong>.</p>
          <div class="ticket-info">
            <span>ID de Ticket: <code>DEL-${Math.floor(100000 + Math.random() * 900000)}</code></span>
            <span>Fecha: ${new Date().toLocaleDateString('es-CO')}</span>
          </div>
          <p class="support-sub">Recibirás una confirmación por correo una vez que la eliminación haya sido ejecutada por completo.</p>
        </div>
      `;
    }
  }, 1000);
}

function showFeedback(msg, type) {
  const feedbackEl = document.getElementById('deletion-feedback');
  if (!feedbackEl) return;
  feedbackEl.style.display = 'block';
  feedbackEl.className = `feedback-msg ${type}`;
  feedbackEl.textContent = msg;
}

function escapeHtml(str) {
  return str.replace(/[&<>"']/g, function(m) {
    return {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    }[m];
  });
}
