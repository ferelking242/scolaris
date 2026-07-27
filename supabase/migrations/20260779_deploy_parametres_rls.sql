-- ============================================================================
--  20260779_deploy_parametres_rls.sql — `parametres.*` n'a jamais été
--  appliqué : n'importe quel membre pouvait modifier la fiche école
--
--  ── Le trou ─────────────────────────────────────────────────────────────────
--  `schools` n'avait que `tenant_isolation` (ALL, is_member_of) côté membres
--  de l'école (en plus des policies plateforme, non touchées ici) : N'IMPORTE
--  QUEL membre — élève ou parent inclus — pouvait modifier le nom, l'adresse,
--  l'année scolaire ou tout autre champ de configuration de l'école via un
--  appel API direct. Aucune policy ne référençait `parametres.*`.
--
--  ── Vérifié avant d'agir ─────────────────────────────────────────────────────
--  Aucun modèle de rôle (`role_template_permissions`) n'accorde jamais
--  `parametres.*` — seule la Direction l'a, via le bypass `is_admin_role`/
--  fondateur. Aucun backfill nécessaire : déployer l'application réelle ne
--  retire d'accès à personne aujourd'hui.
--
--  La LECTURE reste ouverte à tout membre (un élève doit pouvoir voir le nom
--  et l'année scolaire de son établissement) — seule l'ÉCRITURE est verrouillée.
-- ============================================================================

drop policy if exists tenant_isolation on public.schools;

drop policy if exists schools_read on public.schools;
create policy schools_read on public.schools
  for select to authenticated
  using (public.is_member_of(id));

drop policy if exists schools_update on public.schools;
create policy schools_update on public.schools
  for update to authenticated
  using (
    public.is_member_of(id)
    and public.has_permission(auth.uid(), 'parametres', 'modifier')
  )
  with check (
    public.is_member_of(id)
    and public.has_permission(auth.uid(), 'parametres', 'modifier')
  );

-- ============================================================================
--  VERIFICATION :
--    select policyname, cmd from pg_policies where tablename = 'schools';
--
--    -- Un élève ne doit pas pouvoir modifier son école :
--    select has_permission(u.auth_uid,'parametres','modifier')
--      from users u where u.role::text = 'student' limit 1;
--    -- attendu : false
-- ============================================================================
