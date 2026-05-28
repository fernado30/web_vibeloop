alter table public.users
  add column if not exists emoji text not null default '🙂';

update public.users
set emoji = '🙂'
where emoji is null or btrim(emoji) = '';
