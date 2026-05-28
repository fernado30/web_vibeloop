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
  created_at timestamptz default now()
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
  or groups.id::text = coalesce(coalesce(current_setting('request.headers', true), '{}')::jsonb ->> 'x-group-id', '')
);

drop policy if exists "groups_insert_by_owner" on public.groups;
create policy "groups_insert_by_owner"
on public.groups
for insert
with check (auth.uid() = created_by);

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
  or user_id = auth.uid()
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
values ('group-photos', 'group-photos', true)
on conflict (id) do update
set public = true,
    name = excluded.name;

drop policy if exists "group_photos_select_public" on storage.objects;
create policy "group_photos_select_public"
on storage.objects
for select
using (bucket_id = 'group-photos');

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
