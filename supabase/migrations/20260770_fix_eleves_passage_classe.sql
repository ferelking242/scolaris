-- ============================================================================
--  20260770_fix_eleves_passage_classe.sql — `eleves.passage_classe` était
--  décoratif : la vraie policy n'a jamais été mise à jour pour l'accepter
--
--  ── Le problème ─────────────────────────────────────────────────────────────
--  20260762 a ajouté la sous-permission fine `eleves.passage_classe` au
--  catalogue (visible comme case à cocher dans « Rôles & permissions ») et a
--  fait un backfill de la clé PLATE `promotion` côté `users.permissions`. Mais
--  la vraie policy qui protège l'écriture (`student_progressions_write`,
--  20260754, et `student_progressions_update`, 20260755) n'a jamais été
--  touchée : elle exige encore, seule, `utilisateurs.modifier`.
--
--  Résultat : cocher UNIQUEMENT `eleves.passage_classe` pour un rôle (sans
--  `utilisateurs.modifier`) ne débloque RIEN — ni le bouton (l'écran ne le
--  testait pas non plus, corrigé côté Flutter dans le même chantier), ni
--  l'écriture en base si jamais le bouton avait été affiché par erreur.
--
--  Même recette que `eleves.ajouter/modifier/supprimer` sur `users`
--  (20260724) et `parent_student` (20260731) : la policy accepte le droit fin
--  DÉDIÉ, OU le droit large `utilisateurs.modifier`, jamais l'un sans l'autre.
-- ============================================================================

drop policy if exists student_progressions_write on public.student_progressions;
create policy student_progressions_write on public.student_progressions
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'utilisateurs', 'modifier')
      or public.has_permission(auth.uid(), 'eleves', 'passage_classe')
    )
  );

drop policy if exists student_progressions_update on public.student_progressions;
create policy student_progressions_update on public.student_progressions
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'utilisateurs', 'modifier')
      or public.has_permission(auth.uid(), 'eleves', 'passage_classe')
    )
    and status = 'proposed'
  )
  with check (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'utilisateurs', 'modifier')
      or public.has_permission(auth.uid(), 'eleves', 'passage_classe')
    )
  );

-- ============================================================================
--  VERIFICATION :
--    -- Un rôle avec SEULEMENT eleves.passage_classe (pas utilisateurs.modifier)
--    -- peut désormais proposer une décision de fin d'année :
--    select policyname, cmd from pg_policies
--     where tablename = 'student_progressions';
-- ============================================================================
