-- Migración 0014: Simplificar políticas RLS del invite
-- El header x-invite-code ya no se usa desde el cliente JS.
-- La Edge Function resolve-invite valida el invite_code con service_role
-- (omite RLS), por lo que las políticas RLS ya no necesitan esa condición.
-- ============================================================
-- groups: eliminar la condición de x-invite-code del SELECT
-- Ahora solo el owner y los miembros pueden leer el grupo vía RLS.
-- La Edge Function resolve-invite usa service_role para buscar por invite_code.
-- ============================================================
drop policy if exists "groups_select_member_or_invite" on public.groups;
create policy "groups_select_member_or_invite"
on public.groups
for select
using (
  auth.uid() = created_by
  or private.is_group_member(groups.id)
);
-- ============================================================
-- group_members: eliminar la condición de x-invite-code del INSERT
-- Ahora solo el owner puede insertar miembros directamente desde el cliente.
-- Los invitados son añadidos por la Edge Function resolve-invite con service_role.
-- ============================================================
drop policy if exists "group_members_insert_by_owner" on public.group_members;
create policy "group_members_insert_by_owner"
on public.group_members
for insert
with check (
  private.is_group_owner(group_id)
  or user_id = auth.uid()
);
