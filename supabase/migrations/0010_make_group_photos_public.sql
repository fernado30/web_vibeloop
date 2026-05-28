insert into storage.buckets (id, name, public)
values ('group-photos', 'group-photos', true)
on conflict (id) do update
set public = true,
    name = excluded.name;

drop policy if exists "group_photos_select_public" on storage.objects;
create policy "group_photos_select_public"
on storage.objects
for select
using (bucket_id = 'group-photos');
