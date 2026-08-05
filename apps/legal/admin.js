// Supabase Client Configuration
const SUPABASE_URL = 'https://rkwugxemjrwtfjvtckes.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrd3VneGVtanJ3dGZqdnRja2VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3NzUxNjIsImV4cCI6MjA5NDM1MTE2Mn0.d4f7W2TDYJXj-BWfrSraX7tAVfgC_15TZs4CzDFglcs';

let _supabaseClient = null;

function getSupabase() {
  if (_supabaseClient) return _supabaseClient;

  const sb = window.supabase;
  if (sb && typeof sb.createClient === 'function') {
    _supabaseClient = sb.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    return _supabaseClient;
  }
  return null;
}

let currentTab = 'pending';
let activeReports = [];
let selectedReport = null;

async function initApp() {
  const client = getSupabase();
  if (!client) {
    setTimeout(initApp, 150);
    return;
  }

  try {
    const { data: { session } } = await client.auth.getSession();
    if (session && session.user) {
      await verifyAdminAndLoad(session.user);
    } else {
      showLoginView();
    }

    client.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session && session.user) {
        await verifyAdminAndLoad(session.user);
      } else if (event === 'SIGNED_OUT') {
        showLoginView();
      }
    });
  } catch (err) {
    console.error('Error during init:', err);
    showLoginView();
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}

async function verifyAdminAndLoad(user) {
  const client = getSupabase();
  if (!client || !user) return;

  try {
    const { data: userData, error } = await client
      .from('users')
      .select('is_admin, display_name, username')
      .eq('id', user.id)
      .maybeSingle();

    if (error) {
      console.error('Error checking user admin status:', error);
      showLoginAlert('Error de base de datos al verificar permisos: ' + error.message);
      await client.auth.signOut();
      showLoginView();
      return;
    }

    if (!userData || !userData.is_admin) {
      await client.auth.signOut();
      showLoginAlert('Acceso denegado: La cuenta ' + user.email + ' no posee rol de administrador (is_admin = true).');
      showLoginView();
      return;
    }

    document.getElementById('admin-email-tag').textContent = `@${userData.username || user.email}`;
    showDashboardView();
    await loadReports();
  } catch (err) {
    console.error('Unexpected error in verifyAdminAndLoad:', err);
    showLoginAlert('Error al verificar permisos: ' + err.message);
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
  if (alertEl) {
    alertEl.textContent = msg;
    alertEl.classList.remove('hidden');
  }
}

function hideLoginAlert() {
  const alertEl = document.getElementById('login-alert');
  if (alertEl) {
    alertEl.classList.add('hidden');
  }
}

async function handleLogin(e) {
  if (e) e.preventDefault();
  hideLoginAlert();

  const client = getSupabase();
  if (!client) {
    showLoginAlert('Conectando con el servidor de autenticación... Por favor intenta en un momento.');
    return;
  }

  const emailInput = document.getElementById('email');
  const passwordInput = document.getElementById('password');

  const email = emailInput ? emailInput.value.trim() : '';
  const password = passwordInput ? passwordInput.value : '';

  if (!email || !password) {
    showLoginAlert('Por favor ingresa tu correo y contraseña.');
    return;
  }

  const btn = document.getElementById('login-btn');
  const spinner = document.getElementById('login-spinner');
  if (btn) btn.disabled = true;
  if (spinner) spinner.classList.remove('hidden');

  try {
    const { data, error } = await client.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      showLoginAlert('Error de autenticación: ' + (error.message || 'Credenciales no válidas.'));
    } else if (data && data.user) {
      await verifyAdminAndLoad(data.user);
    }
  } catch (err) {
    showLoginAlert('Error inesperado: ' + (err.message || String(err)));
  } finally {
    if (btn) btn.disabled = false;
    if (spinner) spinner.classList.add('hidden');
  }
}

async function handleLogout() {
  const client = getSupabase();
  if (client) {
    await client.auth.signOut();
  }
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
  if (!listEl) return;

  listEl.innerHTML = `
    <div class="loading-state">
      <div class="spinner dark"></div>
      <p>Cargando denuncias de la comunidad...</p>
    </div>
  `;

  const client = getSupabase();
  if (!client) return;

  try {
    const { data: reports, error } = await client
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
  const client = getSupabase();
  if (!client) return;

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

  const reportGroupIds = {};
  const reportPreviews = {};

  if (messageIds.length > 0) {
    const { data: msgs } = await client
      .from('messages')
      .select('id, content, group_id')
      .in('id', messageIds);
    (msgs || []).forEach(m => {
      if (m.group_id) groupIds.add(m.group_id);
      reports.forEach(r => {
        if (r.target_type === 'message' && r.target_id === m.id) {
          if (m.group_id) reportGroupIds[r.id] = m.group_id;
          if (m.content) reportPreviews[r.id] = m.content;
        }
      });
    });
  }

  if (anonMessageIds.length > 0) {
    const { data: anons } = await client
      .from('anonymous_messages')
      .select('id, content, group_id')
      .in('id', anonMessageIds);
    (anons || []).forEach(m => {
      if (m.group_id) groupIds.add(m.group_id);
      reports.forEach(r => {
        if (r.target_type === 'anonymous_message' && r.target_id === m.id) {
          if (m.group_id) reportGroupIds[r.id] = m.group_id;
          if (m.content) reportPreviews[r.id] = m.content;
        }
      });
    });
  }

  if (photoIds.length > 0) {
    const { data: photos } = await client
      .from('group_photos')
      .select('id, group_id')
      .in('id', photoIds);
    (photos || []).forEach(p => {
      if (p.group_id) groupIds.add(p.group_id);
      reports.forEach(r => {
        if (r.target_type === 'group_photo' && r.target_id === p.id) {
          if (p.group_id) reportGroupIds[r.id] = p.group_id;
        }
      });
    });
  }

  const groupMap = {};
  if (groupIds.size > 0) {
    const { data: groups } = await client
      .from('groups')
      .select('id, name')
      .in('id', Array.from(groupIds));
    (groups || []).forEach(g => {
      groupMap[g.id] = g.name;
    });
  }

  const userMap = {};
  if (userIds.length > 0) {
    const { data: users } = await client
      .from('users')
      .select('id, display_name, username')
      .in('id', userIds);
    (users || []).forEach(u => {
      userMap[u.id] = `@${u.username || u.display_name || 'usuario'}`;
    });
  }

  reports.forEach(r => {
    if (r.target_type === 'group') {
      r.resolved_group_name = groupMap[r.target_id] || 'Grupo desconocido';
    } else if (r.target_type === 'user') {
      r.resolved_group_name = userMap[r.target_id] ? `Usuario: ${userMap[r.target_id]}` : 'Usuario desconocido';
    } else {
      const gId = reportGroupIds[r.id];
      r.resolved_group_name = gId && groupMap[gId] ? groupMap[gId] : 'Grupo no especificado';
    }
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
  if (!listEl) return;

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
        <strong>Grupo: ${escapeHtml(r.resolved_group_name)}</strong>
      </div>

      <div class="report-reason-box">
        <span class="reason-label">🚨 Causa de la denuncia:</span>
        <span class="reason-text">${escapeHtml(r.reason)}</span>
      </div>

      ${r.resolved_preview ? `
        <div class="reported-content-box">
          <span class="content-box-label">💬 Contenido, Imagen o Palabra Denunciada:</span>
          ${(r.target_type === 'group_photo' || r.resolved_preview.startsWith('http://') || r.resolved_preview.startsWith('https://')) ? `
            <div class="image-preview-wrapper">
              <img src="${escapeHtml(r.resolved_preview)}" class="reported-image-preview" alt="Foto denunciada" onerror="this.parentNode.innerHTML='<span class=\"invalid-img-msg\">[Imagen no disponible o enlace expirado]</span>'">
            </div>
          ` : `
            <blockquote class="report-quote">
              "${escapeHtml(r.resolved_preview)}"
            </blockquote>
          `}
        </div>
      ` : ''}

      ${r.details ? `
        <div class="report-body">
          <p class="report-details"><strong>Detalles adicionales:</strong> ${escapeHtml(r.details)}</p>
        </div>
      ` : ''}

      <div class="report-meta">
        <span>Denunciado el ${new Date(r.created_at).toLocaleString()}</span>
      </div>

      ${r.moderator_notes ? `
        <div class="mod-notes-box">
          <strong>Notas del moderador:</strong> ${escapeHtml(r.moderator_notes)}
        </div>
      ` : ''}

      ${(r.reason?.includes('CSAM') || r.reason?.includes('infantil') || r.moderator_notes?.includes('CSAM')) ? `
        <button class="btn-ncmec-export" onclick="generateNcmecEvidence('${r.id}')" style="margin-top: 10px; background: #991b1b; color: #ffffff; border: none; padding: 10px 14px; border-radius: 8px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 6px;">
          📥 Exportar Expediente de Evidencia NCMEC (.json)
        </button>
      ` : ''}

      ${r.status === 'pending' ? `
        <button class="btn-resolve" onclick="openResolutionModal('${r.id}')">
          ⚖️ Resolver Denuncia
        </button>
      ` : ''}
    </div>
  `).join('');
}

function generateNcmecEvidence(reportId) {
  const r = activeReports.find(item => item.id === reportId);
  if (!r) return;

  const payload = {
    incident_type: "CSAM / Child Sexual Exploitation Report",
    ncmec_cybertip_target: "https://report.cybertip.org",
    generated_at: new Date().toISOString(),
    service_provider: {
      app_name: "Nadie",
      legal_entity: "Nadie Legal & Compliance",
      contact_email: "emotivanadie@gmail.com"
    },
    incident_data: {
      report_id: r.id,
      reported_at: r.created_at,
      target_type: r.target_type,
      target_id: r.target_id,
      group_name: r.resolved_group_name || "N/A",
      reason_category: r.reason,
      reporter_details: r.details || "N/A",
      content_snapshot: r.resolved_preview || "Purged / Isolated",
      moderator_notes: r.moderator_notes || "ESCALADO A NCMEC"
    },
    law_enforcement_chain_of_custody: {
      evidence_preservation_period: "90 días (18 U.S.C. § 2258A)",
      status: "CONTENT_REMOVED_USER_BANNED_EVIDENCE_ISOLATED"
    }
  };

  const jsonStr = JSON.stringify(payload, null, 2);
  const blob = new Blob([jsonStr], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `NCMEC_EVIDENCE_${r.id.slice(0, 8)}_${Date.now()}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
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

function openResolutionModal(reportId) {
  selectedReport = activeReports.find(r => r.id === reportId);
  if (!selectedReport) return;

  document.getElementById('modal-target-badge').textContent = formatTargetTypeLabel(selectedReport.target_type);
  document.getElementById('modal-group-name').textContent = `📌 Grupo: ${selectedReport.resolved_group_name}`;
  document.getElementById('modal-content-snippet').textContent = selectedReport.resolved_preview ? `"${selectedReport.resolved_preview}"` : '';
  document.getElementById('modal-reason-text').textContent = `🚨 Causa: ${selectedReport.reason}`;
  document.getElementById('mod-notes').value = '';

  document.getElementById('resolution-modal').classList.remove('hidden');
}

function closeResolutionModal() {
  document.getElementById('resolution-modal').classList.add('hidden');
  selectedReport = null;
}

async function submitResolution(e) {
  if (e) e.preventDefault();
  if (!selectedReport) return;

  const client = getSupabase();
  if (!client) return;

  const rawAction = document.querySelector('input[name="mod_action"]:checked')?.value || 'dismiss';
  const isCsam = rawAction === 'csam_escalation';
  const action = isCsam ? 'ban_user' : rawAction;
  const userNotes = document.getElementById('mod-notes').value.trim();
  const notes = isCsam
    ? `[ESCALAMIENTO OBLIGATORIO CSAM/NCMEC] ${userNotes}`.trim()
    : userNotes;

  const btn = document.getElementById('confirm-mod-btn');
  const spinner = document.getElementById('mod-spinner');
  if (btn) btn.disabled = true;
  if (spinner) spinner.classList.remove('hidden');

  try {
    const { data, error } = await client.rpc('resolve_content_report', {
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
    if (isCsam) {
      alert('🚨 RETIRO Y ESCALAMIENTO COMPLETADO:\n\n1. Contenido eliminado de la plataforma.\n2. Usuario baneado permanentemente.\n3. Registro preservado para informe oficial.\n\nPor favor, remite los detalles del incidente al portal oficial de NCMEC CyberTipline (https://report.cybertip.org) o autoridad competente.');
    } else {
      alert('✅ Resolución y sanción aplicadas con éxito.');
    }
  } catch (err) {
    alert('❌ Error al resolver la denuncia: ' + err.message);
  } finally {
    if (btn) btn.disabled = false;
    if (spinner) spinner.classList.add('hidden');
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
