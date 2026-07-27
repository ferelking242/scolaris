-- ============================================================================
--  20260777_backfill_emploi_du_temps.sql — Oubli de 20260776 : le backfill ne
--  couvrait que `classes`, pas `emploi_du_temps`
--
--  20260776 a déployé `schedules_write` (exige désormais `emploi_du_temps.
--  modifier`) DANS LA MÊME migration que le verrouillage de `classes` — mais
--  son backfill ne restaurait que le module `classes` pour les rôles issus
--  d'un modèle. Un rôle comme Secrétaire (modèle primaire), qui prévoit aussi
--  `emploi_du_temps.creer/modifier/voir`, s'est retrouvé sans AUCUN droit sur
--  l'emploi du temps dès le déploiement — même raisonnement, même correctif,
--  qu'on aurait dû appliquer aux deux modules à la fois.
-- ============================================================================

insert into public.staff_role_permissions (staff_role_id, permission_key, sub_permission_key)
select distinct sr.id, 'emploi_du_temps', rtp.sub_permission_key
  from public.staff_roles sr
  join public.role_template_permissions rtp
    on rtp.role_template_id = sr.based_on_template_id
   and rtp.permission_key = 'emploi_du_temps'
 where not exists (
   select 1 from public.staff_role_permissions x
    where x.staff_role_id = sr.id and x.permission_key = 'emploi_du_temps'
 )
on conflict do nothing;

-- ============================================================================
--  VERIFICATION :
--    select sub_permission_key from staff_role_permissions
--     where permission_key = 'emploi_du_temps'
--       and staff_role_id = (select id from staff_roles
--             where school_id = '597bf04f-1e94-40a6-9eaa-93d16868e4fc'
--               and name = 'Secrétaire')
--     order by 1;
--    -- attendu : creer, modifier, voir
-- ============================================================================
