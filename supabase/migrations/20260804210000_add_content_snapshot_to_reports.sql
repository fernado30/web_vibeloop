-- Migration: Add content_snapshot column to public.content_reports

alter table public.content_reports add column if not exists content_snapshot text;
