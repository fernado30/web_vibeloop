insert into public.users (
  id,
  username,
  display_name,
  avatar_url,
  created_at
)
select
  u.id,
  left(
    regexp_replace(
      coalesce(
        nullif(u.raw_user_meta_data ->> 'display_name', ''),
        nullif(u.raw_user_meta_data ->> 'full_name', ''),
        nullif(split_part(coalesce(u.email, 'user'), '@', 1), ''),
        'user'
      ),
      '[^a-zA-Z0-9_]+',
      '_',
      'g'
    ) || '_' || substr(u.id::text, 1, 8),
    32
  ) as username,
  coalesce(
    nullif(u.raw_user_meta_data ->> 'display_name', ''),
    nullif(u.raw_user_meta_data ->> 'full_name', ''),
    nullif(split_part(coalesce(u.email, 'user'), '@', 1), ''),
    'VIBELOOP user'
  ) as display_name,
  u.raw_user_meta_data ->> 'avatar_url' as avatar_url,
  coalesce(u.created_at, now()) as created_at
from auth.users u
left join public.users pu on pu.id = u.id
where pu.id is null
on conflict (id) do nothing;
