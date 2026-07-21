create schema if not exists private;

alter table public.users
  add column if not exists is_under_13 boolean not null default false,
  add column if not exists account_status text not null default 'active',
  add column if not exists child_deletion_requested_at timestamptz;

alter table public.users drop constraint if exists users_account_status_check;
alter table public.users add constraint users_account_status_check
  check (account_status in ('active', 'blocked_under_13', 'deleted'));

comment on column public.users.is_under_13 is 'Eligibility flag only; date of birth is never stored.';
comment on column public.users.account_status is 'Account lifecycle status; blocked_under_13 prevents collection.';

create or replace function private.guard_user_age()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' and coalesce(new.is_under_13, false) then
    raise exception 'Vibeloop is not available to users under 13';
  end if;
  if coalesce(new.is_under_13, false) then
    new.account_status := 'blocked_under_13';
    new.child_deletion_requested_at := coalesce(new.child_deletion_requested_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists guard_user_age on public.users;
create trigger guard_user_age before insert or update on public.users
for each row execute function private.guard_user_age();

create table if not exists public.child_data_deletion_requests (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete set null,
  requested_at timestamptz not null default now(),
  status text not null default 'pending',
  constraint child_data_deletion_requests_status_check check (status in ('pending', 'processing', 'completed'))
);
alter table public.child_data_deletion_requests enable row level security;
drop policy if exists "child_deletion_request_own" on public.child_data_deletion_requests;
create policy "child_deletion_request_own" on public.child_data_deletion_requests
for insert to authenticated with check (auth.uid() = user_id);

create or replace function public.request_child_data_deletion()
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare request_id uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  update public.users set is_under_13 = true, account_status = 'blocked_under_13',
    child_deletion_requested_at = coalesce(child_deletion_requested_at, now()) where id = auth.uid();
  insert into public.child_data_deletion_requests (user_id) values (auth.uid()) returning id into request_id;
  return request_id;
end;
$$;
revoke all on function public.request_child_data_deletion() from public;
grant execute on function public.request_child_data_deletion() to authenticated;

-- Defense in depth for direct Supabase sign-up: an explicit under-13 flag is
-- rejected and no date of birth is stored in auth metadata or public.users.
create or replace function private.guard_auth_user_age()
returns trigger language plpgsql security definer set search_path = auth, public, pg_temp as $$
begin
  if coalesce(new.raw_user_meta_data->>'guest', 'false') = 'true' then return new; end if;
  if coalesce(new.raw_user_meta_data->>'is_anonymous', 'false') = 'true' then return new; end if;
  if coalesce(new.raw_user_meta_data->>'is_under_13', 'false') = 'true' then
    raise exception 'Vibeloop is not available to users under 13';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_auth_user_age on auth.users;
create trigger guard_auth_user_age before insert on auth.users
for each row execute function private.guard_auth_user_age();
