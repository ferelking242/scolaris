-- ============================================================================
--  20260726_drop_canteen.sql — Retirer la CANTINE
--
--  Decision utilisateur (14 juillet 2026) : « pour la cantine supprime-le, on
--  n'a pas besoin de cela pour l'instant ».
--
--  L'application ne reference plus rien de la cantine (page, provider, modeles
--  et methodes supprimes). Ce script nettoie la base pour que le schema dise la
--  meme chose que le code — sinon on garde des tables fantomes que personne
--  n'ecrit et que plus personne ne lit.
--
--  ⚠ DESTRUCTIF. Les menus deja saisis seraient perdus. En pratique les tables
--    viennent d'etre creees (20260724) et sont VIDES : il n'y a rien a perdre.
--    A verifier avant, si vous voulez en avoir le coeur net :
--
--       select count(*) from public.canteen_menus;   -- attendu : 0
--       select count(*) from public.canteen_dishes;  -- attendu : 0
--
--  Le reste de 20260724 (cahier de liaison, recompenses) n'est PAS touche.
-- ============================================================================

-- 1) Les tables. `cascade` emporte les policies et l'index qui en dependent.
--    canteen_dishes part de toute facon avec canteen_menus (FK on delete
--    cascade), mais on est explicite : ce script doit se lire sans supposer.
drop table if exists public.canteen_dishes cascade;
drop table if exists public.canteen_menus  cascade;

-- 2) Le module de permission « cantine » et ses sous-permissions.
--    Ordre impose par les cles etrangeres : les grants d'abord, puis les
--    sous-permissions, puis le module.
delete from public.staff_role_permissions   where permission_key = 'cantine';
delete from public.role_template_permissions where permission_key = 'cantine';
delete from public.sub_permission_catalog    where permission_key = 'cantine';
delete from public.permission_catalog        where key            = 'cantine';

-- Les helpers `my_class_id()` et `has_child_in_class()` sont CONSERVES : le
-- cahier de liaison s'en sert (un mot adresse a toute une classe).

-- ============================================================================
--  VERIFICATION (a lancer apres) :
--
--    select table_name from information_schema.tables
--     where table_schema = 'public'
--       and table_name in ('canteen_menus','canteen_dishes');
--    -- attendu : 0 ligne
--
--    select key from public.permission_catalog where key = 'cantine';
--    -- attendu : 0 ligne
--
--    -- Le cahier de liaison et les recompenses doivent etre INTACTS :
--    select table_name from information_schema.tables
--     where table_schema = 'public'
--       and table_name in ('liaison_entries','liaison_acks','merit_points',
--                          'badge_catalog','student_badges');
--    -- attendu : 5 lignes
-- ============================================================================
