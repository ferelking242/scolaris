-- ============================================================
-- SCOLARIS — Offres alignées sur les modules + supplément de taille
--
-- Remplace la logique "3 paliers génériques" (Simple/Pro/Max, peu différenciés
-- en pratique — Max n'ajoutait qu'un seul écran réellement construit) par une
-- logique à deux axes indépendants :
--   1. Modules choisis (metadata.modules de schools) → détermine le palier
--      (1 module = Essentiel, jusqu'à 3 = Croissance, les 4 = Complet).
--   2. Nombre réel d'élèves → un supplément mensuel, calculé par tranche,
--      au-delà de la franchise incluse dans le palier (`included_students`).
--
-- Les `code` de la table `plans` restent 'simple'/'pro'/'max' (pas de
-- renommage) pour ne pas casser la FK `subscriptions.plan_code` des écoles
-- déjà abonnées — seuls le nom affiché, le tarif et le contenu changent.
-- Idempotent.
-- ============================================================

begin;

alter table public.plans
  add column if not exists included_students integer,
  add column if not exists max_modules integer;

update public.plans set
  name = 'Essentiel', tagline = '1 module au choix',
  max_students = null, included_students = 200, max_modules = 1,
  features = '["1_module_au_choix"]'
where code = 'simple';

update public.plans set
  name = 'Croissance', tagline = 'Jusqu''à 3 modules',
  max_students = null, included_students = 500, max_modules = 3,
  features = '["jusqu_a_3_modules"]'
where code = 'pro';

update public.plans set
  name = 'Complet', tagline = 'Les 4 modules + rapport premium',
  max_students = null, included_students = 1500, max_modules = 4,
  features = '["4_modules","rapport_premium"]'
where code = 'max';

-- Prix revus à la baisse (Congo / XAF). Annuel = 10 mois payés (2 offerts).
update public.plan_prices set price = 8900   where plan_code = 'simple' and country = 'CG' and period = 'monthly';
update public.plan_prices set price = 89000  where plan_code = 'simple' and country = 'CG' and period = 'annual';
update public.plan_prices set price = 17900  where plan_code = 'pro'    and country = 'CG' and period = 'monthly';
update public.plan_prices set price = 179000 where plan_code = 'pro'    and country = 'CG' and period = 'annual';
update public.plan_prices set price = 29900  where plan_code = 'max'    and country = 'CG' and period = 'monthly';
update public.plan_prices set price = 299000 where plan_code = 'max'    and country = 'CG' and period = 'annual';

-- ── Supplément de taille, par tranche d'élèves, au-delà de la franchise ─────
create table if not exists public.plan_size_surcharges (
  id           uuid primary key default gen_random_uuid(),
  plan_code    text not null references public.plans(code) on delete cascade,
  country      text not null,
  currency     text not null,
  min_students integer not null,
  max_students integer,   -- null = tranche ouverte (illimité)
  surcharge    numeric,   -- null = "sur devis" (contacter le support)
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

alter table public.plan_size_surcharges enable row level security;
drop policy if exists shared_read on public.plan_size_surcharges;
create policy shared_read on public.plan_size_surcharges for select to authenticated using (true);

delete from public.plan_size_surcharges where country = 'CG';
insert into public.plan_size_surcharges (plan_code, country, currency, min_students, max_students, surcharge) values
  ('simple','CG','XAF', 0,    200,  0),
  ('simple','CG','XAF', 201,  1000, 5000),
  ('simple','CG','XAF', 1001, 3000, 12000),
  ('simple','CG','XAF', 3001, null, null),
  ('pro',   'CG','XAF', 0,    500,  0),
  ('pro',   'CG','XAF', 501,  1000, 5000),
  ('pro',   'CG','XAF', 1001, 3000, 12000),
  ('pro',   'CG','XAF', 3001, null, null),
  ('max',   'CG','XAF', 0,    1500, 0),
  ('max',   'CG','XAF', 1501, 3000, 7000),
  ('max',   'CG','XAF', 3001, null, null);

commit;
