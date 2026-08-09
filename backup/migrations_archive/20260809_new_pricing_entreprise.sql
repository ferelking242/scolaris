-- 20260809_new_pricing_entreprise.sql
--
-- Nouvelle grille tarifaire (décision utilisateur du 09/08/2026, cf.
-- conversation business plan) — l'ancienne grille (8 900/17 900/29 900 XAF)
-- était trop basse pour un ENT B2B. Nouveaux montants cohérents avec le
-- modèle "Académique inclus + quota de modules complémentaires" et avec
-- l'emplacement à la carte (15 000 XAF/mois, cf. 20260809_module_slot_addon.sql
-- — coïncide volontairement avec le nouveau prix Essentiel, cohérent : c'est
-- le prix d'"un module complémentaire de plus").

update plan_prices set price = 15000  where plan_code = 'simple' and period = 'monthly';
update plan_prices set price = 150000 where plan_code = 'simple' and period = 'annual';
update plan_prices set price = 35000  where plan_code = 'pro'    and period = 'monthly';
update plan_prices set price = 350000 where plan_code = 'pro'    and period = 'annual';
update plan_prices set price = 65000  where plan_code = 'max'    and period = 'monthly';
update plan_prices set price = 650000 where plan_code = 'max'    and period = 'annual';

-- ── Nouvelle offre ENTREPRISE — quatrième palier, sur devis ────────────────
-- Pas de ligne plan_prices : sur devis, jamais de prix affiché ni de bouton
-- "Choisir cette offre" en libre-service (cf. _PlanCard, adapté pour cette
-- offre : bouton "Nous contacter" au lieu du paiement Mobile Money habituel).
-- max_modules = 99 : pas de vrai plafond vu que le catalogue actuel n'a que
-- 3 modules complémentaires (évite de gérer `null` comme "illimité" côté
-- app — cf. moduleQuota = plan.maxModules + extraModuleSlots).
insert into plans (code, name, tagline, max_students, features, sort_order, is_active, included_students, max_modules)
values (
  'entreprise', 'Entreprise',
  'Multi-établissements, marque blanche, API, support dédié — sur devis',
  null,
  '["academique_inclus", "tous_modules_complementaires", "rapport_premium", "multi_etablissements", "marque_blanche", "support_dedie", "export_api"]'::jsonb,
  4, true, null, 99
)
on conflict (code) do update set
  name = excluded.name,
  tagline = excluded.tagline,
  features = excluded.features,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  included_students = excluded.included_students,
  max_modules = excluded.max_modules;
