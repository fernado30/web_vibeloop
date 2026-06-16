create schema if not exists private;

alter table public.groups
  add column if not exists invite_paused boolean not null default false;

create table if not exists private.request_rate_limits (
  scope text not null,
  scope_key text not null,
  user_id uuid not null,
  session_id text not null,
  window_started_at timestamptz not null default now(),
  last_action_at timestamptz not null default now(),
  action_count integer not null default 0,
  primary key (scope, scope_key, user_id, session_id)
);

create or replace function private.enforce_rate_limit(
  p_scope text,
  p_scope_key text,
  p_max_events integer,
  p_window interval,
  p_min_interval interval default interval '0 seconds'
)
returns void
language plpgsql
security definer
set search_path = private, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_session_id text := coalesce(nullif(current_setting('request.jwt.claim.session_id', true), ''), v_user_id::text);
  v_scope_key text := coalesce(nullif(btrim(p_scope_key), ''), 'global');
  v_now timestamptz := clock_timestamp();
  v_row private.request_rate_limits%rowtype;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into v_row
  from private.request_rate_limits
  where scope = p_scope
    and scope_key = v_scope_key
    and user_id = v_user_id
    and session_id = v_session_id
  for update;

  if not found then
    insert into private.request_rate_limits (
      scope,
      scope_key,
      user_id,
      session_id,
      window_started_at,
      last_action_at,
      action_count
    )
    values (
      p_scope,
      v_scope_key,
      v_user_id,
      v_session_id,
      v_now,
      v_now,
      1
    );
    return;
  end if;

  if v_now - v_row.window_started_at >= p_window then
    update private.request_rate_limits
    set window_started_at = v_now,
        last_action_at = v_now,
        action_count = 1
    where scope = p_scope
      and scope_key = v_scope_key
      and user_id = v_user_id
      and session_id = v_session_id;
    return;
  end if;

  if v_now - v_row.last_action_at < p_min_interval then
    raise exception 'rate_limited_cooldown';
  end if;

  if v_row.action_count + 1 > p_max_events then
    raise exception 'rate_limited';
  end if;

  update private.request_rate_limits
  set last_action_at = v_now,
      action_count = v_row.action_count + 1
  where scope = p_scope
    and scope_key = v_scope_key
    and user_id = v_user_id
    and session_id = v_session_id;
end;
$$;

create or replace function private.guard_group_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  perform private.enforce_rate_limit('groups', auth.uid()::text, 3, interval '10 minutes', interval '30 seconds');

  if char_length(btrim(new.name)) < 1 or char_length(btrim(new.name)) > 60 then
    raise exception 'Invalid group name';
  end if;

  return new;
end;
$$;

create or replace function private.guard_message_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  perform private.enforce_rate_limit('messages', new.group_id::text, 12, interval '1 minute', interval '1 second');

  if char_length(btrim(new.content)) < 1 or char_length(btrim(new.content)) > 500 then
    raise exception 'Invalid message length';
  end if;

  return new;
end;
$$;

create or replace function private.guard_anonymous_message_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  if auth.uid() is not null then
    perform private.enforce_rate_limit('anonymous_messages', new.group_id::text, 4, interval '1 minute', interval '8 seconds');
  end if;

  if char_length(btrim(new.content)) < 1 or char_length(btrim(new.content)) > 500 then
    raise exception 'Invalid anonymous message length';
  end if;

  if new.content ~* '(https?://|www\.)' then
    raise exception 'URLs are not allowed';
  end if;

  return new;
end;
$$;

create or replace function private.guard_group_photo_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  perform private.enforce_rate_limit('group_photos', new.group_id::text, 6, interval '5 minutes', interval '15 seconds');

  if char_length(btrim(new.image_url)) < 1 or char_length(btrim(new.storage_path)) < 1 then
    raise exception 'Invalid photo payload';
  end if;

  if new.storage_path !~ '^groups/[0-9a-fA-F-]+/[0-9a-fA-F-]+/.+$' then
    raise exception 'Invalid storage path';
  end if;

  return new;
end;
$$;

drop policy if exists "group_members_insert_by_owner" on public.group_members;
create policy "group_members_insert_by_owner"
on public.group_members
for insert
with check (
  private.is_group_owner(group_id)
  or (
    auth.uid() = user_id
    and exists (
      select 1
      from public.groups g
      where g.id = group_members.group_id
        and coalesce((to_jsonb(g)->>'invite_paused')::boolean, false) = false
        and (
          g.invite_code = coalesce(coalesce(current_setting('request.headers', true), '{}')::jsonb ->> 'x-invite-code', '')
        )
    )
  )
);

drop trigger if exists guard_groups_insert on public.groups;
create trigger guard_groups_insert
before insert on public.groups
for each row
execute function private.guard_group_creation();

drop trigger if exists guard_messages_insert on public.messages;
create trigger guard_messages_insert
before insert on public.messages
for each row
execute function private.guard_message_creation();

drop trigger if exists guard_anonymous_messages_insert on public.anonymous_messages;
create trigger guard_anonymous_messages_insert
before insert on public.anonymous_messages
for each row
execute function private.guard_anonymous_message_creation();

drop trigger if exists guard_group_photos_insert on public.group_photos;
create trigger guard_group_photos_insert
before insert on public.group_photos
for each row
execute function private.guard_group_photo_creation();
