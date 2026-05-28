drop policy if exists "anonymous_messages_delete_if_member" on public.anonymous_messages;
create policy "anonymous_messages_delete_if_member"
on public.anonymous_messages
for delete
using (
  private.is_group_member(group_id)
);

create or replace function public.publish_anonymous_message(p_anonymous_message_id uuid)
returns public.messages
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  anon_row public.anonymous_messages%rowtype;
  inserted_row public.messages%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into anon_row
  from public.anonymous_messages
  where id = p_anonymous_message_id
    and private.is_group_member(group_id)
  for update;

  if not found then
    raise exception 'Anonymous message not found';
  end if;

  insert into public.messages (group_id, sender_id, content, type)
  values (anon_row.group_id, auth.uid(), anon_row.content, 'text')
  returning * into inserted_row;

  delete from public.anonymous_messages
  where id = anon_row.id;

  return inserted_row;
end;
$$;
