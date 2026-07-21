alter table public.users
  add column if not exists privacy_consent_at timestamptz,
  add column if not exists privacy_policy_version text;

comment on column public.users.privacy_consent_at is
  'UTC timestamp at which the user authorized the personal-data treatment policy.';
comment on column public.users.privacy_policy_version is
  'Version of the personal-data treatment policy accepted by the user.';
