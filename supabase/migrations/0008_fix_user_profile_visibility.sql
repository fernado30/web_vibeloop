create or replace function private.can_view_user_profile(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.group_members viewer_members
    join public.group_members sender_members
      on sender_members.group_id = viewer_members.group_id
    where viewer_members.user_id = auth.uid()
      and sender_members.user_id = target_user_id
  );
$$;

drop policy if exists "users_select_group_member" on public.users;
create policy "users_select_group_member"
on public.users
for select
using (
  auth.uid() = id
  or private.can_view_user_profile(public.users.id)
);
