-- Age-gating is deliberately evidence-only: no date of birth is persisted.
alter table public.users
  add column if not exists age_verified_at timestamptz,
  add column if not exists age_verified_13_plus boolean not null default false,
  add column if not exists privacy_consent_at timestamptz,
  add column if not exists privacy_policy_version text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists terms_version text;

create or replace function private.has_verified_age()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid()
      and u.age_verified_13_plus = true
      and u.age_verified_at is not null
      and u.account_status = 'active'
  );
$$;

-- Only this SECURITY DEFINER function may turn on the age flag.  The input is
-- parsed and assessed inside Postgres and is never written to a table or log.
create or replace function public.complete_age_verification(
  p_birth_date text,
  p_privacy_policy_version text,
  p_terms_accepted boolean,
  p_terms_version text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_birth_date date;
  v_age integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_birth_date !~ '^\\d{4}-\\d{2}-\\d{2}$' then
    raise exception 'birthDate must use YYYY-MM-DD';
  end if;
  begin
    v_birth_date := p_birth_date::date;
  exception when others then
    raise exception 'birthDate must use YYYY-MM-DD';
  end;
  if v_birth_date > current_date then raise exception 'birthDate is invalid'; end if;
  v_age := extract(year from age(current_date, v_birth_date));
  if v_age < 13 then
    update public.users
      set is_under_13 = true, account_status = 'blocked_under_13',
          child_deletion_requested_at = coalesce(child_deletion_requested_at, now())
    where id = auth.uid();
    raise exception 'Vibeloop is not available to users under 13';
  end if;
  if coalesce(btrim(p_privacy_policy_version), '') = '' or not p_terms_accepted
     or coalesce(btrim(p_terms_version), '') = '' then
    raise exception 'Privacy policy and terms acceptance are required';
  end if;
  update public.users
    set age_verified_13_plus = true,
        age_verified_at = coalesce(age_verified_at, now()),
        privacy_consent_at = coalesce(privacy_consent_at, now()),
        privacy_policy_version = p_privacy_policy_version,
        terms_accepted_at = coalesce(terms_accepted_at, now()),
        terms_version = p_terms_version,
        is_under_13 = false,
        account_status = 'active'
  where id = auth.uid();
end;
$$;
revoke all on function public.complete_age_verification(text, text, boolean, text) from public;
grant execute on function public.complete_age_verification(text, text, boolean, text) to authenticated;

-- Do not allow clients to forge the server-side verification fields.
create or replace function private.guard_age_verification_evidence()
returns trigger language plpgsql as $$
begin
  if current_user not in ('postgres', 'service_role', 'supabase_admin') and (
    coalesce(new.age_verified_13_plus, false) <> coalesce(old.age_verified_13_plus, false)
    or new.age_verified_at is distinct from old.age_verified_at
    or new.privacy_consent_at is distinct from old.privacy_consent_at
    or new.privacy_policy_version is distinct from old.privacy_policy_version
    or new.terms_accepted_at is distinct from old.terms_accepted_at
    or new.terms_version is distinct from old.terms_version
  ) then raise exception 'Age verification evidence can only be recorded by the server'; end if;
  return new;
end;
$$;
drop trigger if exists guard_age_verification_evidence on public.users;
create trigger guard_age_verification_evidence
before update on public.users for each row execute function private.guard_age_verification_evidence();

-- Every sensitive write requires verified evidence. Existing accounts remain
-- readable and can sign in, but must verify when they next attempt one.
drop policy if exists "groups_insert_by_owner" on public.groups;
create policy "groups_insert_by_owner" on public.groups for insert to authenticated
with check (auth.uid() = created_by and (select private.has_verified_age()));

drop policy if exists "group_members_insert_by_owner" on public.group_members;
create policy "group_members_insert_by_owner" on public.group_members for insert to authenticated
with check (
  (select private.has_verified_age()) and (
    private.is_group_owner(group_id)
    or (auth.uid() = user_id and exists (
      select 1 from public.groups g where g.id = group_members.group_id
        and g.invite_paused = false
        and g.invite_code = coalesce(coalesce(current_setting('request.headers', true), '{}')::jsonb ->> 'x-invite-code', '')
    ))
  )
);

drop policy if exists "messages_insert_if_member" on public.messages;
create policy "messages_insert_if_member" on public.messages for insert to authenticated
with check (auth.uid() = sender_id and private.is_group_member(group_id) and (select private.has_verified_age()));
drop policy if exists "messages_update_own" on public.messages;
create policy "messages_update_own" on public.messages for update to authenticated
using (auth.uid() = sender_id and private.is_group_member(group_id) and (select private.has_verified_age()))
with check (auth.uid() = sender_id and private.is_group_member(group_id) and (select private.has_verified_age()));

drop policy if exists "anonymous_messages_insert_all" on public.anonymous_messages;
create policy "anonymous_messages_insert_all" on public.anonymous_messages for insert to authenticated
with check (private.is_group_member(group_id) and (select private.has_verified_age()));
drop policy if exists "group_photos_insert_member" on public.group_photos;
create policy "group_photos_insert_member" on public.group_photos for insert to authenticated
with check (auth.uid() = uploaded_by and private.is_group_member(group_id) and (select private.has_verified_age()));

drop policy if exists "user_push_devices_insert_own" on public.user_push_devices;
create policy "user_push_devices_insert_own" on public.user_push_devices for insert to authenticated
with check (auth.uid() = user_id and (select private.has_verified_age()));
drop policy if exists "user_push_devices_update_own" on public.user_push_devices;
create policy "user_push_devices_update_own" on public.user_push_devices for update to authenticated
using (auth.uid() = user_id and (select private.has_verified_age()))
with check (auth.uid() = user_id and (select private.has_verified_age()));

drop policy if exists "avatars_insert_authenticated" on storage.objects;
create policy "avatars_insert_authenticated" on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and owner = auth.uid() and (select private.has_verified_age()));
drop policy if exists "avatars_update_owner" on storage.objects;
create policy "avatars_update_owner" on storage.objects for update to authenticated
using (bucket_id = 'avatars' and owner = auth.uid() and (select private.has_verified_age()))
with check (bucket_id = 'avatars' and owner = auth.uid() and (select private.has_verified_age()));
drop policy if exists "group_photos_insert_authenticated" on storage.objects;
create policy "group_photos_insert_authenticated" on storage.objects for insert to authenticated
with check (bucket_id = 'group-photos' and owner = auth.uid() and (select private.has_verified_age()));
