-- ============================================================================
--  20260732_drop_messaging.sql — Retirer la MESSAGERIE et les ANNONCES
--
--  Decision utilisateur (14 juillet 2026) : « Message et announcement supprime-le,
--  on n'en a pas besoin pour l'instant ».
--
--  Ces deux tables etaient aussi le dernier trou beant de la RLS : en
--  `tenant_isolation ALL`, un eleve pouvait ECRIRE UN MESSAGE AU NOM D'UN AUTRE,
--  et publier une annonce signee du directeur. Les supprimer ferme le trou et
--  retire du code mort — deux fois mieux que de les verrouiller pour rien.
--
--  ⚠ DESTRUCTIF. A verifier avant, si vous voulez en avoir le coeur net :
--       select count(*) from public.messages;
--       select count(*) from public.announcements;
--
--  Le centre de notifications de l'eleve n'est PAS supprime : il agrege aussi
--  les notes, les absences et les factures. Seule la section « annonces » en
--  disparait.
-- ============================================================================

-- ── 1. Les tables ───────────────────────────────────────────────────────────
--  Les commentaires et « j'aime » n'ont jamais ete branches (0 ligne) ; ils
--  n'ont plus de raison d'exister sans les annonces.
drop table if exists public.announcement_comments cascade;
drop table if exists public.announcement_likes    cascade;
drop table if exists public.announcements         cascade;
drop table if exists public.messages              cascade;

-- ── 2. Le module de permission « Messages » ─────────────────────────────────
--  Il n'a plus rien a proteger. Le laisser afficherait dans la page des roles
--  une case a cocher qui ne commande RIEN — exactement ce qu'on a passe ce
--  chantier a supprimer.
--  Ordre impose par les cles etrangeres : les grants, puis les sous-permissions,
--  puis le module.
delete from public.staff_role_permissions    where permission_key = 'messages';
delete from public.role_template_permissions where permission_key = 'messages';
delete from public.sub_permission_catalog    where permission_key = 'messages';
delete from public.permission_catalog        where key            = 'messages';

-- ── 3. La projection historique ─────────────────────────────────────────────
--  `legacy_permissions_of_role()` (20260717) traduit les modules RBAC vers les
--  anciennes cles plates. Elle projetait 'messages' -> 'communication'. Ce
--  module n'existant plus, la ligne est retiree : sinon la fonction continuerait
--  d'accorder une cle que plus rien ne justifie.
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
      when 'utilisateurs'    then 'staff_manage'
      when 'parametres'      then 'school_config'
      -- 'messages' -> 'communication' : retire, le module n'existe plus.
    end as p
    from modules
    union
    -- discipline : deduite des presences (pas de module dedie)
    select 'discipline' from modules where k = 'presences'
  )
  select case
    when (select is_admin_role from public.staff_roles where id = p_role_id)
      then '["*"]'::jsonb
    else coalesce(jsonb_agg(p order by p) filter (where p is not null), '[]'::jsonb)
  end
  from mapped;
$fn$;

-- Les porteurs de role gardent une projection a jour (le trigger de 20260717 ne
-- se declenche que sur ecriture des grants : on force le recalcul une fois).
update public.users u
   set permissions = public.legacy_permissions_of_role(u.staff_role_id),
       updated_at  = now()
 where u.staff_role_id is not null;

-- ============================================================================
--  VERIFICATION :
--
--    select table_name from information_schema.tables
--     where table_schema = 'public'
--       and table_name in ('messages','announcements',
--                          'announcement_comments','announcement_likes');
--    -- attendu : 0 ligne
--
--    select key from public.permission_catalog order by order_num;
--    -- attendu : plus de 'messages'
-- ============================================================================
