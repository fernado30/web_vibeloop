insert into storage.buckets (id, name, public)
values ('group-photos', 'group-photos', false)
on conflict (id) do update
set public = false,
    name = excluded.name;

drop policy if exists "group_photos_select_public" on storage.objects;
drop policy if exists "group_photos_select_member" on storage.objects;
create policy "group_photos_select_member"
on storage.objects
for select
using (
  bucket_id = 'group-photos'
  and (storage.foldername(name))[1] = 'groups'
  and private.is_group_member((storage.foldername(name))[2]::uuid)
);

drop policy if exists "group_photos_insert_authenticated" on storage.objects;
create policy "group_photos_insert_authenticated"
on storage.objects
for insert
with check (
  bucket_id = 'group-photos'
  and auth.role() = 'authenticated'
  and owner = auth.uid()
);

drop policy if exists "group_photos_delete_owner" on storage.objects;
create policy "group_photos_delete_owner"
on storage.objects
for delete
using (
  bucket_id = 'group-photos'
  and (
    owner = auth.uid()
    or exists (
      select 1
      from public.groups g
      where g.id::text = (storage.foldername(name))[2]
        and g.created_by = auth.uid()
    )
  )
);
