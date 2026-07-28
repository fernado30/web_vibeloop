-- PostgreSQL's standard string mode treats the previous doubled backslashes as
-- literal characters. Use an explicit POSIX character class for ISO dates.
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
  if p_birth_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
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
