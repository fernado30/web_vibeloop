alter table public.user_push_devices
  add column if not exists show_message_previews boolean not null default true,
  add column if not exists sounds_enabled boolean not null default true,
  add column if not exists vibration_enabled boolean not null default true;
