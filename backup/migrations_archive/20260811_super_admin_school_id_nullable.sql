-- ─────────────────────────────────────────────────────────────────────────
-- users.school_id devient nullable pour les comptes platform_admins :
-- un super-admin plateforme n'est logiquement propriétaire d'aucune école.
-- cf. mémoire [[super-admin-school-id-gap]] (résolu par cette migration).
--
-- Appliquée en direct le 11/08/2026 via `supabase db query --file` (pas de
-- `db push` : historique migrations remote vide, cf. mémoire
-- [[supabase-cli-linked]]).
-- ─────────────────────────────────────────────────────────────────────────

-- 1) Autoriser NULL.
alter table public.users alter column school_id drop not null;

-- 2) RLS : un platform_admin avec school_id NULL doit pouvoir lire/modifier
--    SA PROPRE ligne, indépendamment de is_member_of() (qui ne matche jamais
--    NULL — comparaison `m.school_id = sid` avec sid NULL). Restreint à
--    id = my_user_id() : pas un blanc-seing sur toutes les lignes
--    school_id NULL, seulement sa propre fiche.
alter policy users_read on public.users
  using (
    is_member_of(school_id)
    or (school_id is null and id = my_user_id() and is_platform_admin(auth.uid()))
  );

alter policy users_update on public.users
  using (
    (
      is_member_of(school_id)
      or (school_id is null and id = my_user_id() and is_platform_admin(auth.uid()))
    )
    and (
      id = my_user_id()
      or has_permission(auth.uid(), 'utilisateurs', 'modifier')
      or has_permission(auth.uid(), 'eleves', 'modifier')
    )
  )
  with check (
    is_member_of(school_id)
    or (school_id is null and id = my_user_id() and is_platform_admin(auth.uid()))
  );

-- 3) Détache le compte super-admin réel (kenganiboveldy@gmail.com). Sa ligne
--    school_members vers « École Test Scolaris » est VOLONTAIREMENT
--    conservée : il continue d'y avoir accès via le sélecteur d'école
--    (activeSchoolIdProvider + getMyMemberships), juste plus comme
--    propriétaire par défaut (users.school_id).
--
--    ⚠️ Effet de bord attendu : tant qu'il n'a pas choisi une école via le
--    sélecteur après cette migration, `currentSchoolIdProvider` renvoie null
--    (authSessionProvider.schoolId est maintenant null, et
--    activeSchoolIdProvider ne s'auto-sélectionne pas) — les écrans admin
--    qui exigent un schoolId resteront vides jusqu'au premier choix manuel.
--    Sans impact sur son statut super-admin (résolu via `platform_admins`,
--    indépendant de school_id).
update public.users
set school_id = null
where email = 'kenganiboveldy@gmail.com';
