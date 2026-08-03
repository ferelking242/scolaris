-- ─────────────────────────────────────────────────────────────────────────────
-- Refonte du catalogue primaire (subject_catalog) — épreuves réelles du
-- bulletin (Dictée, Écriture, Copie/Rédaction, Calcul écrit/mental, Questions
-- de cours, Lecture, Poésie, Dessin) au lieu de matières génériques
-- (Français/Maths/Éveil/HG/ECM/EPS/Arts/Musique).
--
-- Anglais n'est pas enseigné dès le CP1 : ajout de `min_order_num` pour que
-- generateDefaultProgramForClass puisse le réserver aux classes dont le
-- niveau (class_levels.order_num) est au moins celui du CM1.
--
-- ⚠️ À appliquer manuellement (SQL editor Supabase) — pas de CLI/service-role
-- disponible dans cet environnement. Revérifier avant exécution :
--   - que `subject_catalog` a bien la forme attendue (colonnes actuelles) ;
--   - les `order_num` réels de `class_levels` pour 'francophone_africa'/'primaire'
--     (attendus ici : CP1=10, CP2=11, CE1=12, CE2=13, CM1=14, CM2=15 — cf.
--     backup/migrations_archive/20260603_create_class_levels.sql).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Granularité par niveau : NULL = toute la classe d'âge du cycle (comportement
--    actuel, inchangé pour collège/lycée) ; une valeur = réservé aux niveaux dont
--    l'order_num (même cycle) est >= à cette valeur.
alter table public.subject_catalog
  add column if not exists min_order_num integer;

-- 2. Remplacement complet du primaire (décision explicite : pas d'ajout aux
--    8 matières génériques existantes, elles disparaissent).
delete from public.subject_catalog where cycle = 'primaire';

insert into public.subject_catalog
  (cycle, name, short_name, default_coefficient, order_num, min_order_num) values
  ('primaire', 'Dictée',              'Dict.',  1, 10, null),
  ('primaire', 'Écriture',            'Écr.',   1, 20, null),
  ('primaire', 'Copie / Rédaction',   'Réd.',   1, 30, null),
  ('primaire', 'Calcul écrit',        'Calc.É', 1, 40, null),
  ('primaire', 'Calcul mental',       'Calc.M', 1, 50, null),
  ('primaire', 'Questions de cours',  'QC',     1, 60, null),
  ('primaire', 'Lecture',             'Lect.',  1, 70, null),
  ('primaire', 'Poésie',              'Poés.',  1, 80, null),
  ('primaire', 'Dessin',              'Dess.',  1, 90, null),
  -- Réservé CM1+ (order_num 14 pour 'francophone_africa' — à revérifier en direct).
  ('primaire', 'Anglais',             'Angl.',  1, 100, 14);
-- (pas de ON CONFLICT : aucune contrainte unique n'existe réellement sur cette
-- table en prod, malgré ce que prétendait l'ancienne migration archivée — le
-- DELETE ci-dessus rend de toute façon un conflit impossible ici.)
