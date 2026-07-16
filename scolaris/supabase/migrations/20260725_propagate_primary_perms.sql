-- ============================================================================
--  20260725_propagate_primary_perms.sql — Donner les nouveaux droits aux roles
--  DEJA CREES
--
--  ── Pourquoi ce script existe ───────────────────────────────────────────────
--
--  `20260724_primary_tools.sql` a ajoute les modules `liaison` et `recompenses`
--  et les a accordes aux MODELES de roles (`role_template_permissions`).
--
--  La `cantine`, elle, n'est PAS propagee : elle est supprimee juste apres
--  (20260726_drop_canteen). Inutile d'accorder des droits sur une table qui
--  disparait dans la migration suivante.
--
--  Mais un role reel (`staff_roles`) ne LIT PAS son modele : il en garde une
--  COPIE, faite une fois pour toutes a sa creation (`staff_role_permissions`,
--  cf. 20260713_staff_rbac + 20260721_teachers_get_a_role). Deux tables
--  distinctes, et rien ne les resynchronise.
--
--  Constate en base, pas suppose :
--
--    full_name          role_nom     vient_d_un_modele                       droits_liaison
--    Jean Ngoubili      Enseignant   c20390bf-7f3e-4f71-9546-1abb4771404d    0
--    Celeste Ibara      Enseignant   11111111-0000-4000-8000-000000000006    0
--    Dr. Henri Loemba   Enseignant   11111111-0000-4000-8000-000000000006    0
--    Pascal Nzoukou     Enseignant   11111111-0000-4000-8000-000000000006    0
--
--  ⇒ has_permission(<prof>, 'liaison', 'ecrire') = false pour TOUS. Le prof
--    ouvrirait l'ecran, taperait son mot, et la RLS le refuserait.
--
--  ── Le piege, et pourquoi on ne joint PAS sur based_on_template_id ──────────
--
--  Trois profs pointent vers le modele commun (11111111-…-006). Jean Ngoubili
--  pointe vers `c20390bf-…` : un ANCIEN modele, d'avant l'unification des roles
--  par cycle (20260719_common_role_templates).
--
--  Une propagation « modele → ses roles » aurait donc servi trois profs sur
--  quatre, et laisse Jean sans droits — un bug isole, silencieux, et
--  incomprehensible depuis l'interface.
--
--  On fait donc la correspondance PAR NOM de role : un « Enseignant » est un
--  enseignant, qu'il vienne de l'ancien modele ou du nouveau. Le nom est ce que
--  l'ecole voit et ce qui porte le sens ; l'id du modele n'est qu'une plomberie
--  qui a change en cours de route.
--
--  ── Ce que le script ne touche pas ──────────────────────────────────────────
--    • les roles PERSONNALISES (based_on_template_id null) — leurs droits ont
--      ete choisis a la main par l'ecole, on ne s'y invite pas ;
--    • les permissions existantes (`on conflict do nothing`) ;
--    • le fondateur — son acces vient de is_admin_role, pas d'un grant.
--
--  Idempotent. Rejouable sans effet de bord.
-- ============================================================================

insert into public.staff_role_permissions
  (staff_role_id, permission_key, sub_permission_key)
select
  r.id,
  tp.permission_key,
  tp.sub_permission_key
from public.staff_roles r
--  Le modele dont ce role est issu (ancien ou nouveau, peu importe).
join public.role_templates t_source
  on t_source.id = r.based_on_template_id
--  Le modele COMMUN qui porte le meme nom : c'est lui qui detient les droits
--  des nouveaux modules (seuls les modeles 'commun' ont ete mis a jour).
join public.role_templates t_commun
  on t_commun.cycle = 'commun'
 and t_commun.name  = t_source.name
join public.role_template_permissions tp
  on tp.role_template_id = t_commun.id
where r.based_on_template_id is not null
  and tp.permission_key in ('liaison', 'recompenses')
on conflict do nothing;

-- ============================================================================
--  VERIFICATION (a lancer apres) — LE test qui compte :
--
--    select u.full_name,
--           public.has_permission(u.auth_uid, 'liaison', 'ecrire')          as ecrit_cahier,
--           public.has_permission(u.auth_uid, 'recompenses', 'attribuer')   as donne_bons_points
--      from public.users u
--     where u.role::text = 'teacher';
--
--    -- Attendu : true / true pour LES QUATRE, Jean Ngoubili compris.
--
--  Et le detail, si besoin :
--
--    select r.name, srp.permission_key, srp.sub_permission_key
--      from public.staff_role_permissions srp
--      join public.staff_roles r on r.id = srp.staff_role_id
--     where srp.permission_key in ('liaison','recompenses')
--     order by r.name, srp.permission_key, srp.sub_permission_key;
--
--    -- Attendu pour l'Enseignant : liaison.voir, liaison.ecrire,
--    --                             recompenses.voir, recompenses.attribuer.
-- ============================================================================

-- ============================================================================
--  ROLLBACK
--
--    delete from public.staff_role_permissions
--     where permission_key in ('liaison', 'recompenses');
-- ============================================================================
