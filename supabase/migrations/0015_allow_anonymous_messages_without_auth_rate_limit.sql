create or replace function private.guard_anonymous_message_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  if char_length(btrim(new.content)) < 1 or char_length(btrim(new.content)) > 500 then
    raise exception 'Invalid anonymous message length';
  end if;

  if new.content ~* '(https?://|www\.)' then
    raise exception 'URLs are not allowed';
  end if;

  return new;
end;
$$;
