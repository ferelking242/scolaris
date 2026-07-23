-- ============================================================================
--  20260760_platform_school_write.sql — Écriture plateforme sur les écoles
--
--  La fiche école (console super-admin) doit pouvoir suspendre/réactiver une
--  école, prolonger son essai et changer son offre. 20260757 n'a ajouté que
--  des policies SELECT pour `is_platform_admin()` sur `schools`/`subscriptions`
--  — on ajoute ici les policies UPDATE, dans le même esprit (additives à
--  `tenant_isolation`, jamais à la place).
--
--  Idempotent. Rejouable.
-- ============================================================================

drop policy if exists platform_admin_update_schools on public.schools;
create policy platform_admin_update_schools
  on public.schools for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists platform_admin_update_subscriptions on public.subscriptions;
create policy platform_admin_update_subscriptions
  on public.subscriptions for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

-- ============================================================================
--  VERIFICATION (connecté en super-admin) :
--    update public.subscriptions set status = status where school_id = '<id>';
--    -- doit réussir (0 ou 1 ligne affectée, aucune erreur RLS).
-- ============================================================================
