alter table public.groups
  add column if not exists invite_paused boolean not null default false;

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

alter table public.user_hidden_words enable row level security;
alter table public.user_blocked_users enable row level security;
alter table public.user_message_filter_settings enable row level security;

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
