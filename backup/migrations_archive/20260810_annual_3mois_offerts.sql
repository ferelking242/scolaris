-- 2026-08-10 — passe la remise annuelle de 2 mois offerts (×10) à 3 mois offerts (×9)
-- sur tous les prix annuels de plan_prices (offres + emplacement de module à la carte).
update plan_prices set price = 135000 where plan_code = 'simple'     and period = 'annual'; -- Essentiel  15000 × 9
update plan_prices set price = 315000 where plan_code = 'pro'        and period = 'annual'; -- Croissance 35000 × 9
update plan_prices set price = 585000 where plan_code = 'max'        and period = 'annual'; -- Complet    65000 × 9
update plan_prices set price = 135000 where plan_code = 'addon_slot' and period = 'annual'; -- Emplacement à la carte 15000 × 9
