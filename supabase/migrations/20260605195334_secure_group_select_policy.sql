drop policy if exists "groups_select_member_or_invite" on public.groups;
create policy "groups_select_member_or_invite"
on public.groups
for select
using (
  auth.uid() = created_by
  or private.is_group_member(groups.id)
  or groups.invite_code = coalesce(coalesce(current_setting('request.headers', true), '{}')::jsonb ->> 'x-invite-code', '')
);
