create or replace function private.guard_anonymous_message_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  if auth.uid() is not null then
    perform private.enforce_rate_limit('anonymous_messages', new.group_id::text, 4, interval '1 minute', interval '8 seconds');
  end if;

  if char_length(btrim(new.content)) < 1 or char_length(btrim(new.content)) > 500 then
    raise exception 'Invalid anonymous message length';
  end if;

  if new.content ~* '(https?://|www\.)' then
    raise exception 'URLs are not allowed';
  end if;

  return new;
end;
$$;
