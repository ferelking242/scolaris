-- ============================================================================
--  20260752_monthly_period_system.sql — Le primaire note chaque MOIS, pas
--  chaque trimestre.
--
--  Contexte : le bulletin du primaire suit un rythme mensuel dans beaucoup
--  d'écoles congolaises, alors que le secondaire reste au trimestre. Jusqu'ici
--  `schools.period_system` ne connaissait que 'trimester'/'semester' (cf.
--  20260723_school_periods.sql), et les CHECK sur `grades.period` /
--  `report_cards.period` n'acceptaient que 'T1'..'T3'/'S1'..'S2' : une classe
--  de primaire notée en 'monthly' aurait vu CHAQUE insertion de note et
--  CHAQUE génération de bulletin rejetée par la base.
--
--  Ce que ça change :
--   • `period_system` accepte désormais aussi 'monthly'.
--   • `grades.period` / `report_cards.period` acceptent en plus les codes
--     mensuels `"YYYY-MM"` (ex. '2025-09') produits par SchoolFormat côté Dart,
--     et leur repli `"M1".."M10"` (année scolaire non renseignée).
--   • La périodicité PAR CYCLE (primaire=mensuel, secondaire=trimestre dans la
--     même école) est une surcharge dans `schools.metadata.period_system_by_cycle`
--     (jsonb) — pas de colonne dédiée, même mécanique que
--     `metadata.grading_by_cycle` (20260751_grading_scale_per_cycle.sql).
-- ============================================================================

alter table public.schools
  drop constraint if exists schools_period_system_check;
alter table public.schools
  add constraint schools_period_system_check
  check (period_system in ('trimester', 'semester', 'monthly'));

alter table public.grades drop constraint if exists grades_period_check;
alter table public.grades
  add constraint grades_period_check
  check (
    period is null
    or period in ('T1','T2','T3','S1','S2')
    or period ~ '^20[0-9]{2}-(0[1-9]|1[0-2])$'
    or period ~ '^M([1-9]|10)$'
  );

alter table public.report_cards drop constraint if exists report_cards_period_check;
alter table public.report_cards
  add constraint report_cards_period_check
  check (
    period in ('T1','T2','T3','S1','S2')
    or period ~ '^20[0-9]{2}-(0[1-9]|1[0-2])$'
    or period ~ '^M([1-9]|10)$'
  );

-- ============================================================================
--  VERIFICATION :
--    select conname, pg_get_constraintdef(oid) from pg_constraint
--      where conrelid in ('public.grades'::regclass, 'public.report_cards'::regclass,
--                          'public.schools'::regclass)
--        and conname like '%period%';
-- ============================================================================
