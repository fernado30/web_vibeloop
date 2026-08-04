create table if not exists public.app_version_policies (
  platform text primary key check (platform in ('android', 'ios')),
  latest_build integer not null check (latest_build > 0),
  min_supported_build integer not null check (min_supported_build > 0 and min_supported_build <= latest_build),
  update_message text not null default 'Hay una actualización disponible.',
  store_url text not null,
  updated_at timestamptz not null default timezone('utc'::text, now())
);

alter table public.app_version_policies enable row level security;

create or replace function private.keep_previous_app_version_supported()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.min_supported_build := greatest(1, new.latest_build - 1);
  new.updated_at := timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists keep_previous_app_version_supported on public.app_version_policies;
create trigger keep_previous_app_version_supported
before insert or update on public.app_version_policies
for each row
execute function private.keep_previous_app_version_supported();

drop policy if exists "app_version_policies_read" on public.app_version_policies;
create policy "app_version_policies_read"
on public.app_version_policies
for select
to anon, authenticated
using (true);

grant select on public.app_version_policies to anon, authenticated;

insert into public.app_version_policies (
  platform,
  latest_build,
  min_supported_build,
  update_message,
  store_url
)
values (
  'android',
  5,
  4,
  'Hay una actualización disponible. Actualiza Nadie para disfrutar de las últimas mejoras.',
  'https://play.google.com/store/apps/details?id=com.vibeloop.vibeloop'
)
on conflict (platform) do nothing;
