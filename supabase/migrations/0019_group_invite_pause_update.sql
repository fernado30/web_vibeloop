drop policy if exists "groups_update_by_owner" on public.groups;
create policy "groups_update_by_owner"
on public.groups
for update
using (auth.uid() = created_by)
with check (auth.uid() = created_by);
