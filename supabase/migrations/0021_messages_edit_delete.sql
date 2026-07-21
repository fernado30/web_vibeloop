drop policy if exists "messages_update_own" on public.messages;
create policy "messages_update_own"
on public.messages
for update
using (
  auth.uid() = sender_id
  and private.is_group_member(group_id)
)
with check (
  auth.uid() = sender_id
  and private.is_group_member(group_id)
);

drop policy if exists "messages_delete_own" on public.messages;
create policy "messages_delete_own"
on public.messages
for delete
using (
  auth.uid() = sender_id
  and private.is_group_member(group_id)
);
