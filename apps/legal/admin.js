// Supabase Client Initialization
const SUPABASE_URL = 'https://rkwugxemjrwtfjvtckes.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrd3VneGVtanJ3dGZqdnRja2VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3NzUxNjIsImV4cCI6MjA5NDM1MTE2Mn0.d4f7W2TDYJXj-BWfrSraX7tAVfgC_15TZs4CzDFglcs';

const supabase = window.supabase ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null;

let currentTab = 'pending';
let activeReports = [];
let selectedReport = null;

// On DOM load, check auth state
document.addEventListener('DOMContentLoaded', async () => {
  if (!supabase) {
    console.error('Supabase client failed to load.');
    return;
  }

  const { data: { session } } = await supabase.auth.getSession();
  if (session) {
    await verifyAdminAndLoad(session.user);
  } else {
    showLoginView();
  }

  supabase.auth.onAuthStateChange(async (event, session) => {
    if (event === 'SIGNED_IN' && session) {
      await verifyAdminAndLoad(session.user);
    } else if (event === 'SIGNED_OUT') {
      showLoginView();
    }
  });
});

async function verifyAdminAndLoad(user) {
  try {
    const { data: userData, error } = await supabase
      .from('users')
      .select('is_admin, display_name, username')
      .eq('id', user.id)
      .maybeSingle();

    if (error || !userData || !userData.is_admin) {
      await supabase.auth.signOut();
      showLoginAlert('Acceso denegado: Tu cuenta no posee permisos de administrador (is_admin = true).');
      showLoginView();
      return;
    }

    document.getElementById('admin-email-tag').textContent = `@${userData.username || user.email}`;
    showDashboardView();
    await loadReports();
  } catch (err) {
    showLoginAlert('Error al verificar permisos de administrador: ' + err.message);
    showLoginView();
  }
}

function showLoginView() {
  document.getElementById('login-view').classList.remove('hidden');
  document.getElementById('dashboard-view').classList.add('hidden');
  document.getElementById('logout-btn').classList.add('hidden');
}

function showDashboardView() {
  document.getElementById('login-view').classList.add('hidden');
  document.getElementById('dashboard-view').classList.remove('hidden');
  document.getElementById('logout-btn').classList.remove('hidden');
}

function showLoginAlert(msg) {
  const alertEl = document.getElementById('login-alert');
  alertEl.textContent = msg;
  alertEl.classList.remove('hidden');
}

function hideLoginAlert() {
  document.getElementById('login-alert').classList.add('hidden');
}

async function handleLogin(e) {
  e.preventDefault();
  hideLoginAlert();

  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;

  const btn = document.getElementById('login-btn');
  const spinner = document.getElementById('login-spinner');
  btn.disabled = true;
  spinner.classList.remove('hidden');

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      showLoginAlert('Error de inicio de sesión: ' + error.message);
    }
  } catch (err) {
    showLoginAlert('Error inesperado: ' + err.message);
  } finally {
    btn.disabled = false;
    spinner.classList.add('hidden');
  }
}

async function handleLogout() {
  await supabase.auth.signOut();
  showLoginView();
}

function setTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
  const activeBtn = document.getElementById(`tab-${tab}`);
  if (activeBtn) activeBtn.classList.add('active');
  renderReports();
}

async function loadReports() {
  const listEl = document.getElementById('reports-list');
  listEl.innerHTML = `
    <div class="loading-state">
      <div class="spinner dark"></div>
      <p>Cargando denuncias de la comunidad...</p>
    </div>
  `;

  try {
    const { data: reports, error } = await supabase
      .from('content_reports')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    activeReports = reports || [];

    const totalCount = activeReports.length;
    const pendingCount = activeReports.filter(r => r.status === 'pending').length;
    const actionCount = activeReports.filter(r => r.status === 'action_taken').length;
    const rejectedCount = activeReports.filter(r => r.status === 'resolved_rejected').length;

    document.getElementById('stat-total').textContent = totalCount;
    document.getElementById('stat-pending').textContent = pendingCount;
    document.getElementById('badge-pending').textContent = pendingCount;
    document.getElementById('stat-action').textContent = actionCount;
    document.getElementById('stat-rejected').textContent = rejectedCount;

    await resolveTargetDetails(activeReports);
    renderReports();
  } catch (err) {
    listEl.innerHTML = `
      <div class="alert error">
        <strong>Error al cargar la cola de denuncias:</strong> ${err.message}
      </div>
    `;
  }
}

async function resolveTargetDetails(reports) {
  if (!reports || reports.length === 0) return;

  const groupIds = new Set();
  const messageIds = [];
  const anonMessageIds = [];
  const photoIds = [];
  const userIds = [];

  reports.forEach(r => {
    if (r.target_type === 'group') groupIds.add(r.target_id);
    else if (r.target_type === 'message') messageIds.push(r.target_id);
    else if (r.target_type === 'anonymous_message') anonMessageIds.push(r.target_id);
    else if (r.target_type === 'group_photo') photoIds.push(r.target_id);
    else if (r.target_type === 'user') userIds.push(r.target_id);
  });

  const reportGroupNames = {};
  const reportPreviews = {};

  if (groupIds.size > 0) {
    const { data: groups } = await supabase
      .from('groups')
      .select('id, name')
      .in('id', Array.from(groupIds));
    (groups || []).forEach(g => {
      reports.forEach(r => {
        if (r.target_type === 'group' && r.target_id === g.id) {
          reportGroupNames[r.id] = g.name;
        }
      });
    });
  }

  if (messageIds.length > 0) {
    const { data: msgs } = await supabase
      .from('messages')
      .select('id, content, group_id, groups(name)')
      .in('id', messageIds);
    (msgs || []).forEach(m => {
      reports.forEach(r => {
        if (r.target_type === 'message' && r.target_id === m.id) {
          if (m.groups && m.groups.name) reportGroupNames[r.id] = m.groups.name;
          if (m.content) reportPreviews[r.id] = m.content;
        }
      });
    });
  }

  if (anonMessageIds.length > 0) {
    const { data: anons } = await supabase
      .from('anonymous_messages')
      .select('id, content, group_id, groups(name)')
      .in('id', anonMessageIds);
    (anons || []).forEach(m => {
      reports.forEach(r => {
        if (r.target_type === 'anonymous_message' && r.target_id === m.id) {
          if (m.groups && m.groups.name) reportGroupNames[r.id] = m.groups.name;
          if (m.content) reportPreviews[r.id] = m.content;
        }
      });
    });
  }

  if (photoIds.length > 0) {
    const { data: photos } = await supabase
      .from('group_photos')
      .select('id, group_id, groups(name)')
      .in('id', photoIds);
    (photos || []).forEach(p => {
      reports.forEach(r => {
        if (r.target_type === 'group_photo' && r.target_id === p.id) {
          if (p.groups && p.groups.name) reportGroupNames[r.id] = p.groups.name;
        }
      });
    });
  }

  if (userIds.length > 0) {
    const { data: users } = await supabase
      .from('users')
      .select('id, display_name, username')
      .in('id', userIds);
    (users || []).forEach(u => {
      reports.forEach(r => {
        if (r.target_type === 'user' && r.target_id === u.id) {
          reportGroupNames[r.id] = `Usuario: @${u.username || u.display_name}`;
        }
      });
    });
  }

  reports.forEach(r => {
    r.resolved_group_name = reportGroupNames[r.id] || 'Grupo no disponible';
    r.resolved_preview = reportPreviews[r.id] || null;
  });
}

function formatTargetTypeLabel(type) {
  switch (type) {
    case 'message': return 'Mensaje de chat';
    case 'anonymous_message': return 'Mensaje anónimo';
    case 'group_photo': return 'Foto de grupo';
    case 'group': return 'Grupo';
    case 'user': return 'Usuario';
    default: return type;
  }
}

function formatStatusBadge(status) {
  switch (status) {
    case 'pending': return '<span class="status-badge pending">Pendiente</span>';
    case 'action_taken': return '<span class="status-badge action">Sancionado</span>';
    case 'resolved_rejected': return '<span class="status-badge rejected">Desestimado</span>';
    default: return `<span class="status-badge">${status}</span>`;
  }
}

function renderReports() {
  const listEl = document.getElementById('reports-list');
  const filtered = activeReports.filter(r => r.status === currentTab);

  if (filtered.length === 0) {
    listEl.innerHTML = `
      <div class="empty-state">
        <span class="empty-icon">🛡️</span>
        <h3>No hay denuncias en esta lista</h3>
        <p>Todas las denuncias bajo este filtro han sido procesadas o están vacías.</p>
      </div>
    `;
    return;
  }

  listEl.innerHTML = filtered.map(r => `
    <div class="report-card">
      <div class="report-card-header">
        <span class="target-badge">${formatTargetTypeLabel(r.target_type)}</span>
        ${formatStatusBadge(r.status)}
      </div>

      <div class="report-group-row">
        <span class="icon">📌</span>
        <strong>${escapeHtml(r.resolved_group_name)}</strong>
      </div>

      ${r.resolved_preview ? `
        <blockquote class="report-quote">
          "${escapeHtml(r.resolved_preview)}"
        </blockquote>
      ` : ''}

      <div class="report-body">
        <p class="report-reason"><strong>Motivo:</strong> ${escapeHtml(r.reason)}</p>
        ${r.details ? `<p class="report-details"><strong>Detalles:</strong> ${escapeHtml(r.details)}</p>` : ''}
      </div>

      <div class="report-meta">
        <span>Denunciado el ${new Date(r.created_at).toLocaleString()}</span>
      </div>

      ${r.moderator_notes ? `
        <div class="mod-notes-box">
          <strong>Notas del moderador:</strong> ${escapeHtml(r.moderator_notes)}
        </div>
      ` : ''}

      ${r.status === 'pending' ? `
        <button class="btn-resolve" onclick="openResolutionModal('${r.id}')">
          ⚖️ Resolver Denuncia
        </button>
      ` : ''}
    </div>
  `).join('');
}

function openResolutionModal(reportId) {
  selectedReport = activeReports.find(r => r.id === reportId);
  if (!selectedReport) return;

  document.getElementById('modal-target-badge').textContent = formatTargetTypeLabel(selectedReport.target_type);
  document.getElementById('modal-group-name').textContent = `📌 ${selectedReport.resolved_group_name}`;
  document.getElementById('modal-content-snippet').textContent = selectedReport.resolved_preview ? `"${selectedReport.resolved_preview}"` : '';
  document.getElementById('modal-reason-text').textContent = `Motivo: ${selectedReport.reason}`;
  document.getElementById('mod-notes').value = '';

  document.getElementById('resolution-modal').classList.remove('hidden');
}

function closeResolutionModal() {
  document.getElementById('resolution-modal').classList.add('hidden');
  selectedReport = null;
}

async function submitResolution(e) {
  e.preventDefault();
  if (!selectedReport) return;

  const action = document.querySelector('input[name="mod_action"]:checked')?.value || 'dismiss';
  const notes = document.getElementById('mod-notes').value.trim();

  const btn = document.getElementById('confirm-mod-btn');
  const spinner = document.getElementById('mod-spinner');
  btn.disabled = true;
  spinner.classList.remove('hidden');

  try {
    const { data, error } = await supabase.rpc('resolve_content_report', {
      p_report_id: selectedReport.id,
      p_action: action,
      p_notes: notes || null,
      p_mute_hours: action === 'mute_user' ? 24 : 0
    });

    if (error) {
      throw error;
    }

    closeResolutionModal();
    await loadReports();
    alert('✅ Resolución y sanción aplicadas con éxito.');
  } catch (err) {
    alert('❌ Error al resolver la denuncia: ' + err.message);
  } finally {
    btn.disabled = false;
    spinner.classList.add('hidden');
  }
}

function escapeHtml(str) {
  if (!str) return '';
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
