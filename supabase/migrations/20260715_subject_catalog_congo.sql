-- ─────────────────────────────────────────────────────────────────────────────
-- Matières types (subject_catalog) — programme réel République du Congo
--
-- But :
--   1. Colonne `series` : au lycée le coefficient d'une matière dépend de la
--      série (Maths coef 5 en C, 4 en D…). `series = NULL` = tronc commun
--      (toutes séries). Sert de RÉFÉRENCE pour pré-remplir le coef par série
--      dans `class_subjects` plus tard ; la table `subjects` de l'école reste
--      plate (un seul coef par nom).
--   2. Seed complet Congo : préscolaire, primaire, collège, lycée (séries A/C/D).
--
-- ⚠️ Idempotent : rejouable sans doublon (index unique + on conflict do nothing).
-- ⚠️ Le dépôt n'est PAS la source de vérité du schéma : cette migration doit
--    être jouée dans le SQL Editor du dashboard Supabase (la clé anon du client
--    est en lecture seule sur cette table).
--
-- Coefficients lycée (source : réglages transmis par l'école) :
--   Série C : Maths 5 · Physique-Chimie 5 · SVT 4 · Philo 3 · reste 3 · EPS 2
--   Série D : Maths 4 · Physique-Chimie 5 · SVT 5 · Philo 3 · reste 3 · EPS 2
--   Série A : Philo 5 · (reste provisoire — à préciser par l'école)
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.subject_catalog (
  id            uuid primary key default gen_random_uuid(),
  system_type   text not null default 'francophone_africa',
  cycle         text not null,                 -- prescolaire | primaire | college | lycee
  name          text not null,
  short_name    text,
  default_coefficient numeric not null default 1,
  order_num     integer not null default 0,
  created_at    timestamptz not null default now()
);

-- 1. Colonne série ------------------------------------------------------------
alter table public.subject_catalog
  add column if not exists series text;                -- A | C | D…  (NULL = tronc commun)

-- 2. Unicité : (système, cycle, nom, série). L'ancienne contrainte sans série
--    interdisait « Mathématiques » en C ET en D. On la remplace par un index
--    qui traite NULL comme '' (sinon deux troncs communs de même nom passeraient).
alter table public.subject_catalog
  drop constraint if exists subject_catalog_system_type_cycle_name_key;
drop index if exists subject_catalog_uni;
create unique index subject_catalog_uni
  on public.subject_catalog (system_type, cycle, name, coalesce(series, ''));

-- 3. RLS : référence publique en lecture seule --------------------------------
alter table public.subject_catalog enable row level security;
drop policy if exists subject_catalog_read on public.subject_catalog;
create policy subject_catalog_read
  on public.subject_catalog for select using (true);

-- 4. Seed francophone_africa (Congo) ------------------------------------------
insert into public.subject_catalog (cycle, name, short_name, default_coefficient, order_num, series) values
  -- ── Préscolaire (coef indicatif) ──
  ('prescolaire', 'Langage et expression orale',   'Langage',   1, 10,  null),
  ('prescolaire', 'Pré-lecture / Graphisme',       'Graphisme', 1, 20,  null),
  ('prescolaire', 'Pré-mathématiques',             'Pré-maths', 1, 30,  null),
  ('prescolaire', 'Éveil / Découverte du monde',   'Éveil',     1, 40,  null),
  ('prescolaire', 'Activités artistiques',         'Arts',      1, 50,  null),
  ('prescolaire', 'Motricité / EPS',               'EPS',       1, 60,  null),

  -- ── Primaire (CP1 → CM2) ──
  ('primaire', 'Français',                          'Fr',       1, 10,  null),
  ('primaire', 'Mathématiques',                     'Maths',    1, 20,  null),
  ('primaire', 'Sciences d''observation',           'Sciences', 1, 30,  null),
  ('primaire', 'Histoire',                          'Hist',     1, 40,  null),
  ('primaire', 'Géographie',                        'Géo',      1, 50,  null),
  ('primaire', 'Éducation Civique et Morale',       'ECM',      1, 60,  null),
  ('primaire', 'Éducation physique et sportive',    'EPS',      1, 70,  null),
  ('primaire', 'Dessin / Arts plastiques',          'Arts',     1, 80,  null),
  ('primaire', 'Chant / Musique',                   'Musique',  1, 90,  null),
  ('primaire', 'Activités manuelles',               'AM',       1, 100, null),

  -- ── Collège (6e → 3e, BEPC) — sans Éducation technologique ──
  ('college', 'Français',                           'Fr',       4, 10,  null),
  ('college', 'Mathématiques',                      'Maths',    4, 20,  null),
  ('college', 'Anglais',                            'Ang',      3, 30,  null),
  ('college', 'Espagnol / Allemand (LV2)',          'LV2',      2, 40,  null),
  ('college', 'Sciences de la Vie et de la Terre',  'SVT',      2, 50,  null),
  ('college', 'Sciences Physiques',                 'PC',       2, 60,  null),
  ('college', 'Histoire-Géographie',                'HG',       3, 70,  null),
  ('college', 'Éducation Civique',                  'EC',       1, 80,  null),
  ('college', 'Éducation physique et sportive',     'EPS',      1, 90,  null),
  ('college', 'Éducation Artistique',               'Arts',     1, 100, null),
  ('college', 'Éducation Musicale',                 'Musique',  1, 110, null),

  -- ── Lycée — tronc commun (series = NULL) — sans Informatique ──
  ('lycee', 'Français',                             'Fr',       3, 10,  null),
  ('lycee', 'Anglais',                              'Ang',      3, 20,  null),
  ('lycee', 'Espagnol / Allemand (LV2)',            'LV2',      3, 30,  null),
  ('lycee', 'Histoire-Géographie',                  'HG',       3, 40,  null),
  ('lycee', 'Éducation Civique',                    'EC',       3, 50,  null),
  ('lycee', 'Éducation physique et sportive',       'EPS',      2, 60,  null),

  -- ── Lycée — Série C (maths-physique) ──
  ('lycee', 'Mathématiques',                        'Maths',    5, 110, 'C'),
  ('lycee', 'Physique-Chimie',                      'PC',       5, 120, 'C'),
  ('lycee', 'Sciences de la Vie et de la Terre',    'SVT',      4, 130, 'C'),
  ('lycee', 'Philosophie',                          'Philo',    3, 140, 'C'),

  -- ── Lycée — Série D (maths-SVT) ──
  ('lycee', 'Mathématiques',                        'Maths',    4, 210, 'D'),
  ('lycee', 'Physique-Chimie',                      'PC',       5, 220, 'D'),
  ('lycee', 'Sciences de la Vie et de la Terre',    'SVT',      5, 230, 'D'),
  ('lycee', 'Philosophie',                          'Philo',    3, 240, 'D'),

  -- ── Lycée — Série A (littéraire) — provisoire (coefs à préciser) ──
  ('lycee', 'Mathématiques',                        'Maths',    2, 310, 'A'),
  ('lycee', 'Philosophie',                          'Philo',    5, 320, 'A')
on conflict do nothing;
