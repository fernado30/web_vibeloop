create extension if not exists "uuid-ossp";

create table if not exists public.users (
  id uuid references auth.users(id) primary key,
  username text unique not null,
  display_name text,
  avatar_url text,
  emoji text not null default '🙂',
  created_at timestamptz default now()
);

create table if not exists public.groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  image_url text,
  created_by uuid references public.users(id),
  invite_code text unique default substr(md5(random()::text), 1, 10),
  invite_paused boolean not null default false,
  created_at timestamptz default now(),
  last_activity_at timestamptz not null default now()
);

create table if not exists public.group_members (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  role text default 'member',
  joined_at timestamptz default now(),
  unique(group_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid references public.groups(id) on delete cascade,
  sender_id uuid references public.users(id),
  content text not null,
  type text default 'text',
  created_at timestamptz default now()
);

create table if not exists public.reactions (
  id uuid primary key default uuid_generate_v4(),
  message_id uuid references public.messages(id) on delete cascade,
  user_id uuid references public.users(id),
  emoji text not null,
  created_at timestamptz default now(),
  unique(message_id, user_id, emoji)
);

create table if not exists public.anonymous_messages (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid references public.groups(id) on delete cascade,
  content text not null,
  reactions jsonb default '{}',
  created_at timestamptz default now()
);

create table if not exists public.group_photos (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid references public.groups(id) on delete cascade,
  uploaded_by uuid references public.users(id) on delete cascade,
  uploader_emoji text not null default '🙂',
  image_url text not null,
  storage_path text not null unique,
  created_at timestamptz default now()
);

create table if not exists public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  type text not null,
  payload jsonb,
  read boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.user_hidden_words (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  word text not null,
  created_at timestamptz default now(),
  unique(user_id, word)
);

create table if not exists public.user_blocked_users (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  blocked_user_id uuid references public.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(user_id, blocked_user_id)
);

create table if not exists public.user_message_filter_settings (
  user_id uuid primary key references public.users(id) on delete cascade,
  hide_hidden_words boolean not null default true,
  hide_blocked_users boolean not null default true,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.messages enable row level security;
alter table public.reactions enable row level security;
alter table public.anonymous_messages enable row level security;
alter table public.group_photos enable row level security;
alter table public.notifications enable row level security;
alter table public.user_hidden_words enable row level security;
alter table public.user_blocked_users enable row level security;
alter table public.user_message_filter_settings enable row level security;

create schema if not exists private;

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

create or replace function private.is_group_member(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.group_members gm
    where gm.group_id = target_group_id
      and gm.user_id = auth.uid()
  );
$$;

create or replace function private.is_group_owner(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.groups g
    where g.id = target_group_id
      and g.created_by = auth.uid()
  );
$$;

create or replace function private.can_view_user_profile(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.group_members viewer_members
    join public.group_members sender_members
      on sender_members.group_id = viewer_members.group_id
    where viewer_members.user_id = auth.uid()
      and sender_members.user_id = target_user_id
  );
$$;

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

  if char_length(btrim(new.content)) < 1 or char_length(new.content) > 500 then
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
  if char_length(btrim(new.content)) < 1 or char_length(new.content) > 500 then
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

create or replace function private.touch_group_last_activity()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  update public.groups
  set last_activity_at = clock_timestamp()
  where id = new.group_id;

  return new;
end;
$$;

create or replace function private.touch_group_last_activity_from_reaction()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
declare
  v_group_id uuid;
begin
  select m.group_id
  into v_group_id
  from public.messages m
  where m.id = new.message_id;

  if v_group_id is not null then
    update public.groups
    set last_activity_at = clock_timestamp()
    where id = v_group_id;
  end if;

  return new;
end;
$$;

drop policy if exists "user_hidden_words_select_own" on public.user_hidden_words;
create policy "user_hidden_words_select_own"
on public.user_hidden_words
for select
using (auth.uid() = user_id);

drop policy if exists "user_hidden_words_insert_own" on public.user_hidden_words;
create policy "user_hidden_words_insert_own"
on public.user_hidden_words
for insert
with check (auth.uid() = user_id);

drop policy if exists "user_hidden_words_update_own" on public.user_hidden_words;
create policy "user_hidden_words_update_own"
on public.user_hidden_words
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user_hidden_words_delete_own" on public.user_hidden_words;
create policy "user_hidden_words_delete_own"
on public.user_hidden_words
for delete
using (auth.uid() = user_id);

drop policy if exists "user_blocked_users_select_own" on public.user_blocked_users;
create policy "user_blocked_users_select_own"
on public.user_blocked_users
for select
using (auth.uid() = user_id);

drop policy if exists "user_blocked_users_insert_own" on public.user_blocked_users;
create policy "user_blocked_users_insert_own"
on public.user_blocked_users
for insert
with check (auth.uid() = user_id);

drop policy if exists "user_blocked_users_update_own" on public.user_blocked_users;
create policy "user_blocked_users_update_own"
on public.user_blocked_users
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user_blocked_users_delete_own" on public.user_blocked_users;
create policy "user_blocked_users_delete_own"
on public.user_blocked_users
for delete
using (auth.uid() = user_id);

drop policy if exists "user_message_filter_settings_select_own" on public.user_message_filter_settings;
create policy "user_message_filter_settings_select_own"
on public.user_message_filter_settings
for select
using (auth.uid() = user_id);

drop policy if exists "user_message_filter_settings_insert_own" on public.user_message_filter_settings;
create policy "user_message_filter_settings_insert_own"
on public.user_message_filter_settings
for insert
with check (auth.uid() = user_id);

drop policy if exists "user_message_filter_settings_update_own" on public.user_message_filter_settings;
create policy "user_message_filter_settings_update_own"
on public.user_message_filter_settings
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
on public.users
for select
using (auth.uid() = id);

drop policy if exists "users_select_group_member" on public.users;
create policy "users_select_group_member"
on public.users
for select
using (
  auth.uid() = id
  or private.can_view_user_profile(public.users.id)
);

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
on public.users
for insert
with check (auth.uid() = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
on public.users
for update
using (auth.uid() = id)
with check (auth.uid() = id);

grant select on public.users to authenticated;

drop policy if exists "groups_select_member_or_invite" on public.groups;
create policy "groups_select_member_or_invite"
on public.groups
for select
using (
  auth.uid() = created_by
  or private.is_group_member(groups.id)
  or groups.invite_code = coalesce(coalesce(current_setting('request.headers', true), '{}')::jsonb ->> 'x-invite-code', '')
);

drop policy if exists "groups_insert_by_owner" on public.groups;
create policy "groups_insert_by_owner"
on public.groups
for insert
with check (auth.uid() = created_by);

drop policy if exists "groups_delete_by_owner" on public.groups;
create policy "groups_delete_by_owner"
on public.groups
for delete
using (auth.uid() = created_by);

grant delete on public.groups to authenticated;

drop policy if exists "group_members_select_own_or_group_owner" on public.group_members;
create policy "group_members_select_own_or_group_owner"
on public.group_members
for select
using (
  user_id = auth.uid()
  or private.is_group_owner(group_members.group_id)
);

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
        and g.invite_paused = false
        and (
          g.invite_code = coalesce(coalesce(current_setting('request.headers', true), '{}')::jsonb ->> 'x-invite-code', '')
        )
    )
  )
);

drop policy if exists "messages_select_if_member" on public.messages;
create policy "messages_select_if_member"
on public.messages
for select
using (
  private.is_group_member(messages.group_id)
);

drop policy if exists "messages_insert_if_member" on public.messages;
create policy "messages_insert_if_member"
on public.messages
for insert
with check (
  auth.uid() = sender_id
  and private.is_group_member(group_id)
);

drop policy if exists "reactions_select_if_member" on public.reactions;
create policy "reactions_select_if_member"
on public.reactions
for select
using (
  exists (
    select 1
    from public.messages m
    where m.id = reactions.message_id
      and private.is_group_member(m.group_id)
  )
);

drop policy if exists "reactions_insert_if_member" on public.reactions;
create policy "reactions_insert_if_member"
on public.reactions
for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.messages m
    where m.id = reactions.message_id
      and private.is_group_member(m.group_id)
  )
);

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.reactions;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.anonymous_messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.group_photos;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

drop policy if exists "anonymous_messages_select_all" on public.anonymous_messages;
create policy "anonymous_messages_select_all"
on public.anonymous_messages
for select
using (
  private.is_group_member(group_id)
);

drop policy if exists "anonymous_messages_insert_all" on public.anonymous_messages;
create policy "anonymous_messages_insert_all"
on public.anonymous_messages
for insert
with check (
  private.is_group_member(group_id)
);

drop policy if exists "anonymous_messages_delete_if_member" on public.anonymous_messages;
create policy "anonymous_messages_delete_if_member"
on public.anonymous_messages
for delete
using (
  private.is_group_member(group_id)
);

drop policy if exists "group_photos_select_member" on public.group_photos;
create policy "group_photos_select_member"
on public.group_photos
for select
using (
  private.is_group_member(group_id)
);

drop policy if exists "group_photos_insert_member" on public.group_photos;
create policy "group_photos_insert_member"
on public.group_photos
for insert
with check (
  auth.uid() = uploaded_by
  and private.is_group_member(group_id)
);

alter table public.group_photos
  add column if not exists uploader_emoji text not null default '🙂';

drop policy if exists "group_photos_delete_owner_or_member" on public.group_photos;
create policy "group_photos_delete_owner_or_member"
on public.group_photos
for delete
using (
  auth.uid() = uploaded_by
  or private.is_group_owner(group_id)
);

grant select, insert, update, delete on public.group_photos to authenticated;

create or replace function public.publish_anonymous_message(p_anonymous_message_id uuid)
returns public.messages
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  anon_row public.anonymous_messages%rowtype;
  inserted_row public.messages%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into anon_row
  from public.anonymous_messages
  where id = p_anonymous_message_id
    and private.is_group_member(group_id)
  for update;

  if not found then
    raise exception 'Anonymous message not found';
  end if;

  insert into public.messages (group_id, sender_id, content, type)
  values (anon_row.group_id, auth.uid(), anon_row.content, 'text')
  returning * into inserted_row;

  delete from public.anonymous_messages
  where id = anon_row.id;

  return inserted_row;
end;
$$;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
on public.notifications
for select
using (auth.uid() = user_id);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
on public.notifications
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update
set public = excluded.public,
    name = excluded.name;

drop policy if exists "avatars_select_public" on storage.objects;
create policy "avatars_select_public"
on storage.objects
for select
using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_authenticated" on storage.objects;
create policy "avatars_insert_authenticated"
on storage.objects
for insert
with check (
  bucket_id = 'avatars'
  and auth.role() = 'authenticated'
  and owner = auth.uid()
);

drop policy if exists "avatars_update_owner" on storage.objects;
create policy "avatars_update_owner"
on storage.objects
for update
using (
  bucket_id = 'avatars'
  and owner = auth.uid()
)
with check (
  bucket_id = 'avatars'
  and owner = auth.uid()
);

drop policy if exists "avatars_delete_owner" on storage.objects;
create policy "avatars_delete_owner"
on storage.objects
for delete
using (
  bucket_id = 'avatars'
  and owner = auth.uid()
);

drop policy if exists "group_photos_delete_owner" on storage.objects;
create policy "group_photos_delete_owner"
on storage.objects
for delete
using (
  bucket_id = 'group-photos'
  and (
    owner = auth.uid()
    or exists (
      select 1
      from public.groups g
      where g.id::text = split_part(name, '/', 2)
        and g.created_by = auth.uid()
    )
  )
);

insert into storage.buckets (id, name, public)
values ('group-photos', 'group-photos', false)
on conflict (id) do update
set public = false,
    name = excluded.name;

drop policy if exists "group_photos_select_public" on storage.objects;
drop policy if exists "group_photos_select_member" on storage.objects;
create policy "group_photos_select_member"
on storage.objects
for select
using (
  bucket_id = 'group-photos'
  and (storage.foldername(name))[1] = 'groups'
  and private.is_group_member((storage.foldername(name))[2]::uuid)
);

drop policy if exists "group_photos_insert_authenticated" on storage.objects;
create policy "group_photos_insert_authenticated"
on storage.objects
for insert
with check (
  bucket_id = 'group-photos'
  and auth.role() = 'authenticated'
  and owner = auth.uid()
);

drop policy if exists "group_photos_delete_owner" on storage.objects;
create policy "group_photos_delete_owner"
on storage.objects
for delete
using (
  bucket_id = 'group-photos'
  and owner = auth.uid()
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

drop trigger if exists touch_group_activity_messages on public.messages;
create trigger touch_group_activity_messages
after insert on public.messages
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_anonymous_messages on public.anonymous_messages;
create trigger touch_group_activity_anonymous_messages
after insert or update on public.anonymous_messages
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_group_photos on public.group_photos;
create trigger touch_group_activity_group_photos
after insert on public.group_photos
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_group_members on public.group_members;
create trigger touch_group_activity_group_members
after insert on public.group_members
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_reactions on public.reactions;
create trigger touch_group_activity_reactions
after insert or update on public.reactions
for each row
execute function private.touch_group_last_activity_from_reaction();
