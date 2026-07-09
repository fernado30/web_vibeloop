create schema if not exists private;

alter table public.groups
  add column if not exists last_activity_at timestamptz;

update public.groups g
set last_activity_at = greatest(
  coalesce(g.created_at, 'epoch'::timestamptz),
  coalesce((select max(m.created_at) from public.messages m where m.group_id = g.id), 'epoch'::timestamptz),
  coalesce((select max(am.created_at) from public.anonymous_messages am where am.group_id = g.id), 'epoch'::timestamptz),
  coalesce((select max(gp.created_at) from public.group_photos gp where gp.group_id = g.id), 'epoch'::timestamptz),
  coalesce((select max(gm.joined_at) from public.group_members gm where gm.group_id = g.id), 'epoch'::timestamptz),
  coalesce(
    (
      select max(r.created_at)
      from public.reactions r
      join public.messages m on m.id = r.message_id
      where m.group_id = g.id
    ),
    'epoch'::timestamptz
  )
)
where g.last_activity_at is null;

alter table public.groups
  alter column last_activity_at set default now(),
  alter column last_activity_at set not null;

create or replace function private.touch_group_last_activity()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
begin
  update public.groups
  set last_activity_at = clock_timestamp()
  where id = new.group_id;

  return new;
end;
$$;

create or replace function private.touch_group_last_activity_from_reaction()
returns trigger
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
declare
  v_group_id uuid;
begin
  select m.group_id
  into v_group_id
  from public.messages m
  where m.id = new.message_id;

  if v_group_id is not null then
    update public.groups
    set last_activity_at = clock_timestamp()
    where id = v_group_id;
  end if;

  return new;
end;
$$;

drop trigger if exists touch_group_activity_messages on public.messages;
create trigger touch_group_activity_messages
after insert on public.messages
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_anonymous_messages on public.anonymous_messages;
create trigger touch_group_activity_anonymous_messages
after insert or update on public.anonymous_messages
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_group_photos on public.group_photos;
create trigger touch_group_activity_group_photos
after insert on public.group_photos
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_group_members on public.group_members;
create trigger touch_group_activity_group_members
after insert on public.group_members
for each row
execute function private.touch_group_last_activity();

drop trigger if exists touch_group_activity_reactions on public.reactions;
create trigger touch_group_activity_reactions
after insert or update on public.reactions
for each row
execute function private.touch_group_last_activity_from_reaction();
