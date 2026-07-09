drop policy if exists "groups_delete_by_owner" on public.groups;
create policy "groups_delete_by_owner"
on public.groups
for delete
using (auth.uid() = created_by);

grant delete on public.groups to authenticated;
