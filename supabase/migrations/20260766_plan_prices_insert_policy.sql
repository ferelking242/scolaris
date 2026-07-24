-- ============================================================================
--  20260766_plan_prices_insert_policy.sql — Policy INSERT manquante sur
--  `plan_prices`
--
--  20260761_platform_settings_write.sql n'ajoutait qu'une policy UPDATE sur
--  `plan_prices`, mais `PlatformRepository.setPlanSettings()` fait un
--  `upsert()` — pour un couple (plan_code, country, period) sans ligne
--  existante, Postgres tente un INSERT, que la RLS refusait faute de policy
--  dédiée ("new row violates row-level security policy for table
--  plan_prices"). On ajoute la policy INSERT symétrique.
--
--  Idempotent. Rejouable.
-- ============================================================================

drop policy if exists platform_admin_insert_plan_prices on public.plan_prices;
create policy platform_admin_insert_plan_prices
  on public.plan_prices for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

-- ============================================================================
--  VERIFICATION (connecté en super-admin) :
--    insert into public.plan_prices (plan_code, country, currency, period, price)
--    values ('simple', 'CG', 'XAF', 'monthly', 15000)
--    on conflict (plan_code, country, period) do update set price = excluded.price;
-- ============================================================================
