-- ============================================================================
--  20260726_propagate_new_modules.sql — Donner aux roles EXISTANTS les droits
--  des nouveaux modules (liaison, cantine, recompenses)
--
--  20260724_primary_tools accorde ces droits aux MODELES de roles
--  (role_template_permissions). Mais un modele ne sert qu'a la NAISSANCE d'un
--  role : une fois le role cree dans une ecole, il vit sa vie. Or 20260721 a
--  deja cree un role « Enseignant » dans chaque ecole.
--
--  Consequence sans cette migration : l'ecran du cahier de liaison s'affiche,
--  le bouton « Ecrire » est la, et la base refuse. Le prof ne comprend pas.
--
--  On propage donc les grants du modele vers les roles qui en descendent —
--  UNIQUEMENT pour les trois modules neufs. On ne retouche pas aux autres :
--  si un directeur a deliberement retire « Notes » a son Surveillant, ce n'est
--  pas a une migration de le lui rendre.
-- ============================================================================

insert into public.staff_role_permissions
  (staff_role_id, permission_key, sub_permission_key)
select r.id, tp.permission_key, tp.sub_permission_key
  from public.staff_roles r
  join public.role_template_permissions tp
    on tp.role_template_id = r.based_on_template_id
 where tp.permission_key in ('liaison', 'cantine', 'recompenses')
on conflict do nothing;

-- Les roles crees AVANT que `based_on_template_id` existe, ou renommes, n'ont
-- pas de lien vers leur modele. On les rattrape par le nom, qui est celui du
-- modele commun (cf. 20260719) tant que le directeur ne l'a pas change.
insert into public.staff_role_permissions
  (staff_role_id, permission_key, sub_permission_key)
select r.id, tp.permission_key, tp.sub_permission_key
  from public.staff_roles r
  join public.role_templates t
    on t.cycle = 'commun' and t.name = r.name
  join public.role_template_permissions tp
    on tp.role_template_id = t.id
 where r.based_on_template_id is null
   and tp.permission_key in ('liaison', 'cantine', 'recompenses')
on conflict do nothing;

--  users.permissions n'a pas a changer : ces trois modules n'ont pas
--  d'equivalent parmi les 11 anciennes cles, et legacy_permissions_of_role()
--  les ignore (le CASE renvoie NULL, la ligne est filtree). Les triggers de
--  20260717 vont recalculer la projection a l'identique. C'est voulu : ces
--  modules sont verrouilles en base par has_permission(), qui lit les vraies
--  tables de roles — pas la vieille projection.

-- ============================================================================
--  VERIFICATION — un prof EXISTANT peut ecrire dans le cahier :
--
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'teacher' limit 1),
--      'liaison', 'ecrire');            -- attendu : true
--
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'teacher' limit 1),
--      'recompenses', 'attribuer');     -- attendu : true
--
--  Et un parent, non :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'parent' limit 1),
--      'liaison', 'ecrire');            -- attendu : false
--
--  Detail des droits accordes, role par role :
--    select r.name, srp.permission_key, srp.sub_permission_key
--      from public.staff_role_permissions srp
--      join public.staff_roles r on r.id = srp.staff_role_id
--     where srp.permission_key in ('liaison','cantine','recompenses')
--     order by r.name, srp.permission_key, srp.sub_permission_key;
-- ============================================================================
