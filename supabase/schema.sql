create extension if not exists "uuid-ossp";

create table if not exists public.users (
  id uuid references auth.users(id) primary key,
  username text unique not null,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

create table if not exists public.groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  image_url text,
  created_by uuid references public.users(id),
  invite_code text unique default substr(md5(random()::text), 1, 10),
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

create table if not exists public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  type text not null,
  payload jsonb,
  read boolean default false,
  created_at timestamptz default now()
);

alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.messages enable row level security;
alter table public.reactions enable row level security;
alter table public.anonymous_messages enable row level security;
alter table public.notifications enable row level security;

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

create or replace function public.group_member_count(target_group_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::integer
  from public.group_members gm
  where gm.group_id = target_group_id;
$$;

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
on public.users
for select
using (auth.uid() = id);

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

drop policy if exists "anonymous_messages_select_all" on public.anonymous_messages;
create policy "anonymous_messages_select_all"
on public.anonymous_messages
for select
using (true);

drop policy if exists "anonymous_messages_insert_all" on public.anonymous_messages;
create policy "anonymous_messages_insert_all"
on public.anonymous_messages
for insert
with check (true);

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
