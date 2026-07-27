-- ============================================================================
--  20260775_fix_absences_saisir_modifier.sql — Un prof ne pouvait jamais
--  corriger l'appel du jour
--
--  ── Le bug ──────────────────────────────────────────────────────────────────
--  `saveAttendance()` envoie TOUJOURS tous les élèves de la classe dans un
--  seul `upsert()`, à chaque clic sur « Enregistrer » — pas seulement les
--  nouveaux. Marquer un élève la première fois exige `presences.saisir` ;
--  re-corriger un élève déjà marqué le même jour exige `presences.modifier`
--  (policy `absences_update`, distincte de `absences_insert`).
--
--  Le modèle de rôle « Enseignant » (primaire/collège/lycée/université) n'a
--  QUE `saisir` + `voir`, jamais `modifier` (vérifié en direct sur
--  `role_template_permissions`). Résultat : un prof qui fait l'appel puis
--  rouvre l'écran plus tard pour corriger UN SEUL retard voit tout le lot
--  rejeté par la base — l'upsert masse insert et update dans une seule
--  requête, et RLS refuse le tout dès qu'une ligne (déjà existante) viole la
--  policy d'update.
--
--  ── Le correctif ────────────────────────────────────────────────────────────
--  Prendre l'appel et le corriger LE JOUR MÊME est le même geste pour
--  l'enseignant, pas deux droits différents. `presences.modifier` reste la
--  vraie distinction pour un membre du staff qui corrige un jour PASSÉ (via
--  l'écran admin) — ce correctif ne change rien pour lui, il ajoute juste
--  `saisir` comme alternative suffisante, comme le fait déjà `enregistrer_paiement`
--  pour `invoices_update` (cf. 20260774).
-- ============================================================================

drop policy if exists absences_update on public.absences;
create policy absences_update on public.absences
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'presences', 'modifier')
      or public.has_permission(auth.uid(), 'presences', 'saisir')
    )
    and (public.get_my_role()::text <> 'teacher' or public.teaches_class(auth.uid(), class_id))
  )
  with check (public.is_member_of(school_id));

-- ============================================================================
--  VERIFICATION :
--    select policyname, qual from pg_policies
--     where tablename = 'absences' and policyname = 'absences_update';
--
--    -- Un enseignant (saisir + voir seulement) peut re-corriger l'appel du
--    -- jour de SA classe :
--    select has_permission(u.auth_uid,'presences','saisir')
--      from users u where u.role::text = 'teacher' limit 1;
--    -- attendu : true (déjà vrai avant — ce qui change, c'est que l'UPDATE
--    -- l'accepte maintenant aussi, pas seulement l'INSERT)
-- ============================================================================
