-- Migration: Moderation Governance, Queue, Sanctions & Audit Logs

-- 1. Extend public.users with is_admin flag
alter table public.users add column if not exists is_admin boolean not null default false;

-- Function to check if a user is admin
create or replace function public.is_admin(user_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select coalesce((select is_admin from public.users where id = user_id), false);
$$;

-- 2. Update public.content_reports with moderator columns & status constraints
alter table public.content_reports add column if not exists moderator_id uuid references public.users(id) on delete set null;
alter table public.content_reports add column if not exists moderator_notes text;
alter table public.content_reports add column if not exists resolved_at timestamptz;

-- 3. Create user sanctions table
create table if not exists public.user_sanctions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  sanction_type text not null check (sanction_type in ('warning', 'mute_24h', 'mute_7d', 'ban')),
  reason text not null,
  report_id uuid references public.content_reports(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz default now()
);

alter table public.user_sanctions enable row level security;

-- 4. Create moderation logs (Audit trail)
create table if not exists public.moderation_logs (
  id uuid primary key default uuid_generate_v4(),
  report_id uuid references public.content_reports(id) on delete set null,
  moderator_id uuid not null references public.users(id) on delete set null,
  action text not null check (action in ('dismiss', 'warn_user', 'delete_content', 'mute_user', 'ban_user')),
  target_type text not null,
  target_id uuid not null,
  notes text,
  created_at timestamptz default now()
);

alter table public.moderation_logs enable row level security;

-- 5. Security Policies (RLS)

drop policy if exists "content_reports_select_own_or_admin" on public.content_reports;
create policy "content_reports_select_own_or_admin"
on public.content_reports
for select
using (
  auth.uid() = reporter_id or public.is_admin(auth.uid()) = true
);

drop policy if exists "content_reports_update_admin" on public.content_reports;
create policy "content_reports_update_admin"
on public.content_reports
for update
using (
  public.is_admin(auth.uid()) = true
);

drop policy if exists "user_sanctions_select_own_or_admin" on public.user_sanctions;
create policy "user_sanctions_select_own_or_admin"
on public.user_sanctions
for select
using (
  auth.uid() = user_id or public.is_admin(auth.uid()) = true
);

drop policy if exists "user_sanctions_admin_all" on public.user_sanctions;
create policy "user_sanctions_admin_all"
on public.user_sanctions
for all
using (
  public.is_admin(auth.uid()) = true
);

drop policy if exists "moderation_logs_admin_all" on public.moderation_logs;
create policy "moderation_logs_admin_all"
on public.moderation_logs
for all
using (
  public.is_admin(auth.uid()) = true
);

grant select, insert, update on public.content_reports to authenticated;
grant select, insert, update, delete on public.user_sanctions to authenticated;
grant select, insert on public.moderation_logs to authenticated;

-- 6. Trigger to block posting from sanctioned/muted/banned users
create or replace function private.guard_user_sanction_status()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
declare
  v_sanction record;
begin
  select sanction_type, reason, expires_at into v_sanction
  from public.user_sanctions
  where user_id = auth.uid()
    and sanction_type in ('mute_24h', 'mute_7d', 'ban')
    and (expires_at is null or expires_at > now())
  order by created_at desc
  limit 1;

  if found then
    if v_sanction.sanction_type = 'ban' then
      raise exception 'Tu cuenta se encuentra suspendida por violar las normas comunitarias.';
    else
      raise exception 'Tu cuenta está silenciada temporalmente por la moderación. Motivo: %', v_sanction.reason;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists guard_user_sanction_messages on public.messages;
create trigger guard_user_sanction_messages
before insert on public.messages
for each row
execute function private.guard_user_sanction_status();

drop trigger if exists guard_user_sanction_anonymous on public.anonymous_messages;
create trigger guard_user_sanction_anonymous
before insert on public.anonymous_messages
for each row
execute function private.guard_user_sanction_status();

drop trigger if exists guard_user_sanction_photos on public.group_photos;
create trigger guard_user_sanction_photos
before insert on public.group_photos
for each row
execute function private.guard_user_sanction_status();

drop trigger if exists guard_user_sanction_groups on public.groups;
create trigger guard_user_sanction_groups
before insert on public.groups
for each row
execute function private.guard_user_sanction_status();

-- 7. Operational RPC: resolve_content_report
create or replace function public.resolve_content_report(
  p_report_id uuid,
  p_action text,
  p_notes text default null,
  p_mute_hours int default 24
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_report record;
  v_target_user_id uuid;
  v_sanction_type text;
  v_expires_at timestamptz;
  v_notes text;
begin
  v_notes := nullif(btrim(p_notes), '');

  if not public.is_admin(auth.uid()) then
    raise exception 'Acceso denegado: tu cuenta de usuario no posee el rol de administrador (is_admin = true).';
  end if;

  select * into v_report
  from public.content_reports
  where id = p_report_id;

  if not found then
    raise exception 'La denuncia no fue encontrada o ya fue procesada.';
  end if;

  if v_report.target_type = 'user' then
    v_target_user_id := v_report.target_id;
  elsif v_report.target_type = 'message' then
    select sender_id into v_target_user_id from public.messages where id = v_report.target_id;
  elsif v_report.target_type = 'group_photo' then
    select uploaded_by into v_target_user_id from public.group_photos where id = v_report.target_id;
  elsif v_report.target_type = 'group' then
    select created_by into v_target_user_id from public.groups where id = v_report.target_id;
  end if;

  if p_action = 'dismiss' then
    update public.content_reports
    set status = 'resolved_rejected',
        moderator_id = auth.uid(),
        moderator_notes = v_notes,
        resolved_at = now()
    where id = p_report_id;

  elsif p_action = 'delete_content' then
    if v_report.target_type = 'message' then
      delete from public.messages where id = v_report.target_id;
    elsif v_report.target_type = 'anonymous_message' then
      delete from public.anonymous_messages where id = v_report.target_id;
    elsif v_report.target_type = 'group_photo' then
      delete from public.group_photos where id = v_report.target_id;
    elsif v_report.target_type = 'group' then
      delete from public.groups where id = v_report.target_id;
    end if;

    update public.content_reports
    set status = 'action_taken',
        moderator_id = auth.uid(),
        moderator_notes = coalesce(v_notes, 'Contenido eliminado por moderación.'),
        resolved_at = now()
    where id = p_report_id;

  elsif p_action in ('warn_user', 'mute_user', 'ban_user') then
    if v_report.target_type = 'message' then
      delete from public.messages where id = v_report.target_id;
    elsif v_report.target_type = 'anonymous_message' then
      delete from public.anonymous_messages where id = v_report.target_id;
    elsif v_report.target_type = 'group_photo' then
      delete from public.group_photos where id = v_report.target_id;
    end if;

    if v_target_user_id is not null then
      if p_action = 'warn_user' then
        v_sanction_type := 'warning';
        v_expires_at := null;
      elsif p_action = 'mute_user' then
        if coalesce(p_mute_hours, 24) >= 168 then
          v_sanction_type := 'mute_7d';
        else
          v_sanction_type := 'mute_24h';
        end if;
        v_expires_at := now() + (coalesce(p_mute_hours, 24) || ' hours')::interval;
      elsif p_action = 'ban_user' then
        v_sanction_type := 'ban';
        v_expires_at := null;
      end if;

      insert into public.user_sanctions (
        user_id,
        sanction_type,
        reason,
        report_id,
        created_by,
        expires_at
      ) values (
        v_target_user_id,
        v_sanction_type,
        coalesce(v_notes, 'Sanción aplicada por moderación tras denuncia.'),
        p_report_id,
        auth.uid(),
        v_expires_at
      );
    end if;

    update public.content_reports
    set status = 'action_taken',
        moderator_id = auth.uid(),
        moderator_notes = v_notes,
        resolved_at = now()
    where id = p_report_id;

  else
    raise exception 'Acción de moderación no válida: %', p_action;
  end if;

  insert into public.moderation_logs (
    report_id,
    moderator_id,
    action,
    target_type,
    target_id,
    notes
  ) values (
    p_report_id,
    auth.uid(),
    p_action,
    v_report.target_type,
    v_report.target_id,
    v_notes
  );

  return jsonb_build_object(
    'success', true,
    'report_id', p_report_id,
    'action', p_action
  );
end;
$$;
