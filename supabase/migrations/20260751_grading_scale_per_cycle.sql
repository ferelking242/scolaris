-- 20260751_grading_scale_per_cycle.sql — Barème par cycle (sans rien jeter)
--
-- Contexte : le barème de notation (`schools.grading_scale`) était UNIQUE pour
-- toute l'école. Un complexe scolaire (primaire + collège + lycée) ne pouvait
-- pas noter le primaire /10 et le secondaire /20. Le « /10 primaire » du
-- dashboard était donc bricolé en dur (avg/2), en contradiction avec le reste.
--
-- Principe NON destructif :
--   • `schools.grading_scale` RESTE le barème PAR DÉFAUT de l'école (repli).
--   • les surcharges par cycle vivent dans `schools.metadata.grading_by_cycle`
--     (jsonb déjà présent), ex. {"primaire":"numeric_10","lycee":"numeric_20"}.
--     Clés = valeurs de l'enum SchoolLevel (primaire|college|lycee|universite|
--     master|doctorat). Un cycle absent → retombe sur `grading_scale`.
--   • seul ajout de schéma : 'numeric_10' dans la liste autorisée du CHECK.
--
-- Élargir un CHECK ne peut jamais invalider une ligne existante → aucune perte.

alter table public.schools
  drop constraint if exists schools_grading_scale_check;

alter table public.schools
  add  constraint schools_grading_scale_check
  check (grading_scale in ('numeric_10', 'numeric_20', 'numeric_100', 'letter'));

comment on column public.schools.grading_scale is
  'Barème PAR DÉFAUT de l''école (numeric_10|numeric_20|numeric_100|letter). '
  'Surcharges par cycle : metadata.grading_by_cycle = '
  '{"primaire":"numeric_10","lycee":"numeric_20",...}.';
