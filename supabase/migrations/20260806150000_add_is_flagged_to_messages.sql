-- Migration: Add is_flagged column and fix content_reports RLS for Google Perspective AI moderation
alter table public.messages add column if not exists is_flagged boolean not null default false;
alter table public.anonymous_messages add column if not exists is_flagged boolean not null default false;

-- Allow automatic reporting in content_reports
alter table public.content_reports alter column reporter_id set default auth.uid();

drop policy if exists "content_reports_insert_authenticated" on public.content_reports;
create policy "content_reports_insert_authenticated"
on public.content_reports
for insert
with check (
  reporter_id is null or auth.uid() = reporter_id
);

-- Notify PostgREST to reload schema cache
notify pgrst, 'reload schema';
