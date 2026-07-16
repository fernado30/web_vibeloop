create table if not exists public.user_push_devices (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  fcm_token text unique not null,
  platform text not null,
  notifications_enabled boolean not null default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.user_push_devices enable row level security;

drop policy if exists "user_push_devices_select_own" on public.user_push_devices;
create policy "user_push_devices_select_own"
on public.user_push_devices
for select
using (auth.uid() = user_id);

drop policy if exists "user_push_devices_insert_own" on public.user_push_devices;
create policy "user_push_devices_insert_own"
on public.user_push_devices
for insert
with check (auth.uid() = user_id);

drop policy if exists "user_push_devices_update_own" on public.user_push_devices;
create policy "user_push_devices_update_own"
on public.user_push_devices
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user_push_devices_delete_own" on public.user_push_devices;
create policy "user_push_devices_delete_own"
on public.user_push_devices
for delete
using (auth.uid() = user_id);

grant select, insert, update, delete on public.user_push_devices to authenticated;
