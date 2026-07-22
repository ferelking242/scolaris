-- ============================================================================
--  20260757_platform_dashboard_read.sql — Le Dashboard super-admin lit enfin
--  les vraies écoles
--
--  ── Le problème ─────────────────────────────────────────────────────────────
--  `schools` et `subscriptions` sont protégées par `tenant_isolation` (RLS
--  `for all to authenticated using (is_member_of(school_id))`) : un super-admin
--  plateforme n'est PAS forcément membre de chaque école, donc une requête
--  brute depuis la console plateforme ne renverrait que SES propres écoles
--  (souvent zéro), pas la liste complète nécessaire au Dashboard.
--
--  ── Ce que ça change ─────────────────────────────────────────────────────────
--    • Policies de LECTURE supplémentaires sur `schools` et `subscriptions`
--      pour `is_platform_admin(auth.uid())` — s'ajoutent à `tenant_isolation`,
--      ne la remplacent pas (un membre normal garde son accès habituel).
--      Volontairement LECTURE SEULE : la console ne doit pas pouvoir modifier
--      une école ou son abonnement en contournant les écrans/actions dédiés.
--    • `platform_total_students()` : le nombre total d'élèves, SANS exposer
--      la table `users` (noms, emails, téléphones de tout le monde) à la
--      console — un admin plateforme a besoin d'un compte, pas d'un annuaire.
-- ============================================================================

drop policy if exists platform_admin_read_schools on public.schools;
create policy platform_admin_read_schools on public.schools
  for select to authenticated
  using (public.is_platform_admin(auth.uid()));

drop policy if exists platform_admin_read_subscriptions on public.subscriptions;
create policy platform_admin_read_subscriptions on public.subscriptions
  for select to authenticated
  using (public.is_platform_admin(auth.uid()));

create or replace function public.platform_total_students()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select case when public.is_platform_admin(auth.uid())
    then (select count(*) from public.users where role = 'student')
    else 0
  end;
$$;

grant execute on function public.platform_total_students() to authenticated;

-- ============================================================================
--  VERIFICATION (connecté en tant qu'admin plateforme) :
--    select count(*) from public.schools;         -- doit voir TOUTES les écoles
--    select count(*) from public.subscriptions;    -- idem
--    select public.platform_total_students();      -- un nombre, pas 0
-- ============================================================================
