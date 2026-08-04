create table if not exists public.content_reports (
  id uuid primary key default uuid_generate_v4(),
  reporter_id uuid references public.users(id) on delete set null,
  target_type text not null check (target_type in ('message', 'anonymous_message', 'group_photo', 'group', 'user')),
  target_id uuid not null,
  reason text not null,
  details text,
  status text not null default 'pending',
  created_at timestamptz default now()
);

alter table public.content_reports enable row level security;

drop policy if exists "content_reports_insert_authenticated" on public.content_reports;
create policy "content_reports_insert_authenticated"
on public.content_reports
for insert
with check (
  auth.uid() = reporter_id
);

drop policy if exists "content_reports_select_own" on public.content_reports;
create policy "content_reports_select_own"
on public.content_reports
for select
using (
  auth.uid() = reporter_id
);

grant select, insert on public.content_reports to authenticated;

create or replace function private.guard_report_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  perform private.enforce_rate_limit('content_reports', auth.uid()::text, 10, interval '5 minutes', interval '2 seconds');

  if char_length(btrim(new.reason)) < 1 then
    raise exception 'Invalid report reason';
  end if;

  if new.target_type not in ('message', 'anonymous_message', 'group_photo', 'group', 'user') then
    raise exception 'Invalid report target type';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_content_reports_insert on public.content_reports;
create trigger guard_content_reports_insert
before insert on public.content_reports
for each row
execute function private.guard_report_creation();
