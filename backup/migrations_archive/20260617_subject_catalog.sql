-- ─────────────────────────────────────────────────────────────────────────────
-- Phase C — Matières : catalogue de référence + lien classe→niveau
--
-- But :
--   1. `classes.level_id` → relie une classe à son niveau de référence
--      (class_levels). La série, le cycle et le statut « classe d'examen »
--      deviennent connus automatiquement, sans rien retaper.
--   2. `subject_catalog` → matières « types » par cycle (francophone). Sert de
--      pré-rempli : l'admin clique « Charger les matières types » au lieu de tout
--      saisir. Données de référence (comme class_levels), pas par école.
--
-- NB : on ne recrée PAS `class_subjects` (classe×matière×coef×prof) ici — ça
--      viendra au moment des bulletins. On reste minimal et utile maintenant.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Lien classe → niveau de référence ----------------------------------------
alter table public.classes
  add column if not exists level_id uuid references public.class_levels(id);

-- 2. Catalogue des matières types ---------------------------------------------
create table if not exists public.subject_catalog (
  id            uuid primary key default gen_random_uuid(),
  system_type   text not null default 'francophone_africa',
  cycle         text not null,                 -- primaire | college | lycee
  name          text not null,                 -- « Mathématiques »
  short_name    text,                          -- « Maths »
  default_coefficient numeric not null default 1,
  order_num     integer not null default 0,
  created_at    timestamptz not null default now(),
  unique (system_type, cycle, name)
);

-- Référence publique en lecture seule (comme class_levels) : tout le monde lit,
-- personne n'écrit côté client.
alter table public.subject_catalog enable row level security;

drop policy if exists subject_catalog_read on public.subject_catalog;
create policy subject_catalog_read
  on public.subject_catalog for select
  using (true);

-- 3. Seed francophone ----------------------------------------------------------
insert into public.subject_catalog (cycle, name, short_name, default_coefficient, order_num) values
  -- Primaire
  ('primaire', 'Français',                 'Fr',     1, 10),
  ('primaire', 'Mathématiques',            'Maths',  1, 20),
  ('primaire', 'Éveil / Sciences',         'Éveil',  1, 30),
  ('primaire', 'Histoire-Géographie',      'HG',     1, 40),
  ('primaire', 'Éducation civique et morale','ECM',  1, 50),
  ('primaire', 'Éducation physique et sportive','EPS',1, 60),
  ('primaire', 'Dessin / Arts',            'Arts',   1, 70),
  ('primaire', 'Chant / Musique',          'Mus',    1, 80),
  -- Collège
  ('college', 'Français',                  'Fr',     4, 10),
  ('college', 'Mathématiques',             'Maths',  4, 20),
  ('college', 'Anglais',                   'Ang',    3, 30),
  ('college', 'Sciences de la Vie et de la Terre','SVT',2, 40),
  ('college', 'Sciences Physiques',        'PC',     2, 50),
  ('college', 'Histoire-Géographie',       'HG',     3, 60),
  ('college', 'Éducation civique',         'EC',     1, 70),
  ('college', 'Éducation physique et sportive','EPS',1, 80),
  ('college', 'Technologie',               'Techno', 1, 90),
  ('college', 'Arts plastiques',           'Arts',   1, 100),
  -- Lycée (coefficients indicatifs ; ajustés par série au moment des bulletins)
  ('lycee', 'Français',                    'Fr',     3, 10),
  ('lycee', 'Philosophie',                 'Philo',  2, 20),
  ('lycee', 'Mathématiques',               'Maths',  4, 30),
  ('lycee', 'Physique-Chimie',             'PC',     4, 40),
  ('lycee', 'Sciences de la Vie et de la Terre','SVT',3, 50),
  ('lycee', 'Anglais',                     'Ang',    3, 60),
  ('lycee', 'Histoire-Géographie',         'HG',     3, 70),
  ('lycee', 'Sciences économiques et sociales','SES',3, 80),
  ('lycee', 'Éducation physique et sportive','EPS',  1, 90)
on conflict (system_type, cycle, name) do nothing;
