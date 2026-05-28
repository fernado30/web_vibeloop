do $$
begin
  alter publication supabase_realtime add table public.anonymous_messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
