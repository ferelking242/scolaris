-- ============================================================================
--  20260744_notes_corriger.sql — Le droit de corriger une note VERROUILLEE
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  Une note validee par le prof est verrouillee : le prof lui-meme ne peut plus
--  la changer (c'est voulu — une note publiee ne bouge pas dans le dos de
--  l'eleve). Mais une erreur arrive : un 8 saisi au lieu d'un 18, un nom
--  d'eleve decale d'une ligne. Il faut alors quelqu'un qui puisse RATTRAPER —
--  le secretariat, la direction — sans rendre ce pouvoir a tout le monde.
--
--  C'est une permission, pas une regle en dur : le directeur decide QUI, dans
--  son ecole, peut corriger une note verrouillee. Meme logique que tout le
--  reste — c'est le role qui tranche.
--
--  ── Pourquoi une NOUVELLE permission ────────────────────────────────────────
--
--  `notes.modifier` existe deja, mais l'ENSEIGNANT la possede : la reutiliser
--  rendrait le verrou du prof inutile (il pourrait deverrouiller ses propres
--  notes). Il faut un droit distinct, que le prof n'a pas par defaut.
--
--    notes.saisir    saisir une note vide           (prof, admin)
--    notes.modifier  modifier une note NON verrouillee
--    notes.corriger  passer OUTRE le verrou          (admin, secretariat) ← NOUVEAU
-- ============================================================================

-- ── 1. La permission entre au catalogue (elle apparait alors comme case a
--       cocher dans l'ecran Roles & permissions) ────────────────────────────
insert into public.sub_permission_catalog (permission_key, key, label, order_num)
values ('notes', 'corriger', 'Corriger une note verrouillée', 7)
on conflict (permission_key, key) do update
  set label = excluded.label, order_num = excluded.order_num;

-- ── 2. Les modeles de roles qui l'obtiennent d'office ────────────────────────
--  Chef d'etablissement, Adjoint, Secretaire — ceux dont c'est le metier de
--  tenir les dossiers. Pas l'Enseignant, pas le Comptable, pas le Surveillant.
insert into public.role_template_permissions
  (role_template_id, permission_key, sub_permission_key)
values
  ('11111111-0000-4000-8000-000000000001', 'notes', 'corriger'),  -- Chef d'etablissement
  ('11111111-0000-4000-8000-000000000002', 'notes', 'corriger'),  -- Adjoint
  ('11111111-0000-4000-8000-000000000004', 'notes', 'corriger')   -- Secretaire
on conflict do nothing;

-- ── 3. Propager aux roles DEJA crees dans les ecoles ────────────────────────
--  Un modele ne se propage pas tout seul aux `staff_roles` existants. On vise
--  ceux qui savent deja gerer la STRUCTURE de l'ecole (classes.modifier) : c'est
--  le signal « personnel administratif », et l'enseignant ne l'a pas. Signal
--  fiable, independant du nom du role — une ecole a pu renommer « Adjoint » en
--  « Censeur ».
insert into public.staff_role_permissions (staff_role_id, permission_key, sub_permission_key)
select distinct sp.staff_role_id, 'notes', 'corriger'
  from public.staff_role_permissions sp
 where sp.permission_key = 'classes'
   and sp.sub_permission_key = 'modifier'
   and not exists (
     select 1 from public.staff_role_permissions x
      where x.staff_role_id = sp.staff_role_id
        and x.permission_key = 'notes'
        and x.sub_permission_key = 'corriger'
   )
on conflict do nothing;

-- ============================================================================
--  VERIFICATION :
--
--    -- Quels roles peuvent desormais corriger une note verrouillee ?
--    select sr.name, s.name as ecole
--      from public.staff_role_permissions p
--      join public.staff_roles sr on sr.id = p.staff_role_id
--      join public.schools s on s.id = sr.school_id
--     where p.permission_key = 'notes' and p.sub_permission_key = 'corriger'
--     order by s.name, sr.name;
--
--  Le FONDATEUR (users.role in admin/direction/directeur/dg) n'apparait pas ici
--  et n'en a pas besoin : il a '*'. C'est normal.
-- ============================================================================
