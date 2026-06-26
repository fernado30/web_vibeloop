create schema if not exists private;

create table if not exists private.anonymous_message_rate_limits (
  invite_code text not null,
  client_ip text not null,
  window_started_at timestamptz not null default now(),
  last_action_at timestamptz not null default now(),
  action_count integer not null default 0,
  primary key (invite_code, client_ip)
);

create or replace function private.claim_anonymous_message_rate_limit(
  p_invite_code text,
  p_client_ip text,
  p_max_events integer,
  p_window_seconds integer,
  p_min_interval_seconds integer default 0
)
returns void
language plpgsql
security definer
set search_path = private, pg_temp
as $$
declare
  v_invite_code text := coalesce(nullif(btrim(p_invite_code), ''), 'global');
  v_client_ip text := coalesce(nullif(btrim(p_client_ip), ''), 'unknown');
  v_now timestamptz := clock_timestamp();
  v_window interval := make_interval(secs => greatest(p_window_seconds, 1));
  v_min_interval interval := make_interval(secs => greatest(p_min_interval_seconds, 0));
  v_row private.anonymous_message_rate_limits%rowtype;
begin
  select *
  into v_row
  from private.anonymous_message_rate_limits
  where invite_code = v_invite_code
    and client_ip = v_client_ip
  for update;

  if not found then
    insert into private.anonymous_message_rate_limits (
      invite_code,
      client_ip,
      window_started_at,
      last_action_at,
      action_count
    )
    values (
      v_invite_code,
      v_client_ip,
      v_now,
      v_now,
      1
    );
    return;
  end if;

  if v_now - v_row.window_started_at >= v_window then
    update private.anonymous_message_rate_limits
    set window_started_at = v_now,
        last_action_at = v_now,
        action_count = 1
    where invite_code = v_invite_code
      and client_ip = v_client_ip;
    return;
  end if;

  if v_now - v_row.last_action_at < v_min_interval then
    raise exception 'rate_limited_cooldown';
  end if;

  if v_row.action_count + 1 > p_max_events then
    raise exception 'rate_limited';
  end if;

  update private.anonymous_message_rate_limits
  set last_action_at = v_now,
      action_count = v_row.action_count + 1
  where invite_code = v_invite_code
    and client_ip = v_client_ip;
end;
$$;

create or replace function public.claim_anonymous_message_rate_limit(
  p_invite_code text,
  p_client_ip text,
  p_max_events integer,
  p_window_seconds integer,
  p_min_interval_seconds integer default 0
)
returns void
language sql
security invoker
set search_path = public, private, pg_temp
as $$
  select private.claim_anonymous_message_rate_limit(
    p_invite_code,
    p_client_ip,
    p_max_events,
    p_window_seconds,
    p_min_interval_seconds
  );
$$;

grant execute on function public.claim_anonymous_message_rate_limit(text, text, integer, integer, integer) to authenticated, anon;
