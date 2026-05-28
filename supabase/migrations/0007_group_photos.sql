create table if not exists public.group_photos (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid references public.groups(id) on delete cascade,
  uploaded_by uuid references public.users(id) on delete cascade,
  uploader_emoji text not null default '🙂',
  image_url text not null,
  storage_path text not null unique,
  created_at timestamptz default now()
);

alter table public.group_photos enable row level security;

drop policy if exists "group_photos_select_member" on public.group_photos;
create policy "group_photos_select_member"
on public.group_photos
for select
using (
  private.is_group_member(group_id)
);

drop policy if exists "group_photos_insert_member" on public.group_photos;
create policy "group_photos_insert_member"
on public.group_photos
for insert
with check (
  auth.uid() = uploaded_by
  and private.is_group_member(group_id)
);

alter table public.group_photos
  add column if not exists uploader_emoji text not null default '🙂';

drop policy if exists "group_photos_delete_owner_or_member" on public.group_photos;
create policy "group_photos_delete_owner_or_member"
on public.group_photos
for delete
using (
  auth.uid() = uploaded_by
  or private.is_group_owner(group_id)
);

grant select, insert, update, delete on public.group_photos to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.group_photos;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

insert into storage.buckets (id, name, public)
values ('group-photos', 'group-photos', true)
on conflict (id) do update
set public = excluded.public,
    name = excluded.name;

drop policy if exists "group_photos_select_public" on storage.objects;
create policy "group_photos_select_public"
on storage.objects
for select
using (bucket_id = 'group-photos');

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
      where g.id::text = split_part(name, '/', 2)
        and g.created_by = auth.uid()
    )
  )
);
