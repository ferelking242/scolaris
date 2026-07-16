-- ============================================================================
--  20260717_sync_user_permissions.sql
--  « Le droit suit le ROLE » — jusqu'au bout.
--
--  users.permissions (jsonb, 11 cles plates) est ce que lisent le menu, les
--  gardes de pages et AppUser.can(). Depuis la bascule RBAC, ce n'est plus une
--  saisie : c'est une PROJECTION des grants du role porte par l'employe
--  (users.staff_role_id -> staff_role_permissions).
--
--  Probleme : une projection ecrite une seule fois, a l'invitation, se perime.
--  Retirer « Finances » au role Comptable ne changeait RIEN pour les comptables
--  deja en poste — chacun gardait sa copie. C'est l'exact contraire de ce que le
--  modele promet : modifier le role doit mettre a jour tous ceux qui le portent.
--
--  On recalcule donc la projection en base, par trigger. Peu importe qui ecrit
--  (l'app, un script, la console Supabase) : la projection suit.
--
--  Correspondance module RBAC -> cle historique (miroir de RbacMapping cote Dart,
--  lib/core/permissions/rbac_mapping.dart — garder les deux alignes) :
--      eleves          -> students        rapports        -> reports
--      classes         -> classes         emploi_du_temps -> timetable
--      notes           -> grades          messages        -> communication
--      presences       -> attendance      utilisateurs    -> staff_manage
--      comptabilite    -> finance         parametres      -> school_config
--  `discipline` n'a pas de module RBAC : la vie scolaire suit `presences`.
-- ============================================================================

create or replace function public.legacy_permissions_of_role(p_role_id uuid)
returns jsonb
language sql
stable
as $fn$
  with modules as (
    select distinct srp.permission_key as k
    from public.staff_role_permissions srp
    where srp.staff_role_id = p_role_id
  ),
  mapped as (
    select case k
      when 'eleves'          then 'students'
      when 'classes'         then 'classes'
      when 'notes'           then 'grades'
      when 'presences'       then 'attendance'
      when 'comptabilite'    then 'finance'
      when 'rapports'        then 'reports'
      when 'emploi_du_temps' then 'timetable'
      when 'messages'        then 'communication'
      when 'utilisateurs'    then 'staff_manage'
      when 'parametres'      then 'school_config'
    end as p
    from modules
    union
    -- discipline : deduite des presences (pas de module dedie)
    select 'discipline' from modules where k = 'presences'
  )
  select case
    -- Role admin : acces total, quels que soient ses grants enumeres.
    when (select is_admin_role from public.staff_roles where id = p_role_id)
      then '["*"]'::jsonb
    else coalesce(jsonb_agg(p order by p) filter (where p is not null), '[]'::jsonb)
  end
  from mapped;
$fn$;

-- Recalcule users.permissions pour tous les porteurs d'un role.
create or replace function public.sync_users_of_role(p_role_id uuid)
returns void
language sql
security definer
as $fn$
  update public.users
     set permissions = public.legacy_permissions_of_role(p_role_id),
         updated_at  = now()
   where staff_role_id = p_role_id;
$fn$;

-- ── Triggers ────────────────────────────────────────────────────────────────

-- 1. Les permissions du role changent (updateRoleGrants = delete puis insert).
create or replace function public.trg_sync_on_grants()
returns trigger
language plpgsql
security definer
as $fn$
begin
  perform public.sync_users_of_role(
    coalesce(new.staff_role_id, old.staff_role_id));
  return coalesce(new, old);
end;
$fn$;

drop trigger if exists trg_sync_users_on_grants on public.staff_role_permissions;
create trigger trg_sync_users_on_grants
  after insert or delete on public.staff_role_permissions
  for each row execute function public.trg_sync_on_grants();

-- 2. Le role devient (ou cesse d'etre) un role admin.
create or replace function public.trg_sync_on_role_admin()
returns trigger
language plpgsql
security definer
as $fn$
begin
  if new.is_admin_role is distinct from old.is_admin_role then
    perform public.sync_users_of_role(new.id);
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_sync_users_on_role_admin on public.staff_roles;
create trigger trg_sync_users_on_role_admin
  after update of is_admin_role on public.staff_roles
  for each row execute function public.trg_sync_on_role_admin();

-- 3. Un employe change de role (ou en recoit un).
create or replace function public.trg_sync_on_user_role()
returns trigger
language plpgsql
security definer
as $fn$
begin
  if new.staff_role_id is distinct from old.staff_role_id then
    new.permissions := case
      when new.staff_role_id is null then new.permissions
      else public.legacy_permissions_of_role(new.staff_role_id)
    end;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_sync_user_on_role_change on public.users;
create trigger trg_sync_user_on_role_change
  before update of staff_role_id on public.users
  for each row execute function public.trg_sync_on_user_role();

-- ── Rattrapage des comptes existants ────────────────────────────────────────
--  Tout le personnel deja en base a permissions = '[]' et staff_role_id = NULL :
--  personne n'a jamais recu de droits. On aligne au moins ceux qui portent deja
--  un role (aucun aujourd'hui — c'est un filet pour les rejeux futurs).

update public.users u
   set permissions = public.legacy_permissions_of_role(u.staff_role_id),
       updated_at  = now()
 where u.staff_role_id is not null;
