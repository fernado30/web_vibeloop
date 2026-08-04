-- Migration: Anonymous Safety Validation (Phone Numbers, Emails, URLs, Social Links & Length)

create or replace function private.guard_anonymous_message_creation()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  -- 1. Length check
  if char_length(btrim(new.content)) < 1 or char_length(btrim(new.content)) > 500 then
    raise exception 'El mensaje anónimo debe contener entre 1 y 500 caracteres.';
  end if;

  -- 2. URL & Social Media Links check
  if new.content ~* '(https?://|www\.|t\.me|wa\.me|instagram\.com|tiktok\.com|discord\.gg|discord\.com/invite|snapchat\.com/add)' then
    raise exception 'Los mensajes anónimos no pueden incluir enlaces ni redes sociales.';
  end if;

  -- 3. Email addresses check
  if new.content ~* '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' then
    raise exception 'Los mensajes anónimos no pueden incluir correos electrónicos.';
  end if;

  -- 4. Phone numbers check
  if new.content ~* '(\+?[0-9]{1,4}[\s-]?)?\(?[0-9]{3}\)?[\s-]?[0-9]{3}[\s-]?[0-9]{4}|\m[0-9]{8,15}\M' then
    raise exception 'Los mensajes anónimos no pueden incluir números telefónicos.';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_anonymous_messages_insert on public.anonymous_messages;
create trigger guard_anonymous_messages_insert
before insert on public.anonymous_messages
for each row
execute function private.guard_anonymous_message_creation();
