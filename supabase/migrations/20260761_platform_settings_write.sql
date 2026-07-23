-- ============================================================================
--  20260761_platform_settings_write.sql — Réglages plateforme réels (tarifs)
--  + lecture de l'équipe super-admin
--
--  Page « Réglages » de la console : les tarifs (`plans.max_students`,
--  `plan_prices.price`) doivent pouvoir être modifiés par un admin plateforme
--  — `shared_read` (20260617_subscriptions.sql) n'autorisait que la lecture
--  pour tout connecté, aucune écriture. On ajoute des policies UPDATE
--  réservées à `is_platform_admin()`.
--
--  Pour l'équipe super-admin (lecture seule décidée pour l'instant — pas
--  d'ajout/retrait depuis l'app), on expose `platform_admin_list()` : la
--  policy SELECT sur `platform_admins` (20260756) ne donne que `user_id`,
--  pas l'email — impossible d'afficher une liste utile sans elle, et on ne
--  veut pas donner un accès large à `users` pour autant.
--
--  Idempotent. Rejouable.
-- ============================================================================

drop policy if exists platform_admin_update_plans on public.plans;
create policy platform_admin_update_plans
  on public.plans for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists platform_admin_update_plan_prices on public.plan_prices;
create policy platform_admin_update_plan_prices
  on public.plan_prices for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

create or replace function public.platform_admin_list()
returns table(user_id text, email text, full_name text)
language sql
stable
security definer
set search_path = public
as $$
  select u.id::text, u.email, u.full_name
  from public.platform_admins pa
  join public.users u on u.id = pa.user_id
  where public.is_platform_admin(auth.uid())
  order by u.email;
$$;

grant execute on function public.platform_admin_list() to authenticated;

-- ============================================================================
--  VERIFICATION (connecté en super-admin) :
--    update public.plans set max_students = max_students where code = 'simple';
--    select * from platform_admin_list();
-- ============================================================================
