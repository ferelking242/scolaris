-- ============================================================
-- SCOLARIS — Bibliothèque : annales, supports, favoris & suivi de lecture
--
-- Objectif : brancher la section « Bibliothèque » de l'app élève sur de vraies
-- données. Jusqu'ici seuls les LIVRES (table `bibliotheque`, catalogue partagé)
-- étaient réels ; les annales, supports de cours, favoris et statistiques de
-- lecture étaient codés en dur côté Flutter. On crée ici leurs tables.
--
-- 4 tables :
--   • exam_subjects     — annales d'examens (CEPE/BEPC/BAC), catalogue PARTAGÉ
--   • course_materials  — supports de cours, cloisonnés par école (tenant)
--   • library_favorites — favoris par utilisateur (livre / annale / support)
--   • reading_progress  — suivi de lecture par utilisateur (reprise + stats)
--
-- Idempotent / ré-exécutable.
-- ============================================================

begin;

-- ── 1. Annales d'examens — catalogue partagé (comme `bibliotheque`) ──────────
create table if not exists public.exam_subjects (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  subject         text not null,
  level           text not null check (level in ('cepe','bepc','bac')),
  session         text,                                   -- ex. 'Juin', 'Septembre'
  year            integer not null,
  has_correction  boolean not null default false,
  url             text,                                   -- sujet (PDF)
  correction_url  text,                                   -- corrigé (PDF), si dispo
  created_at      timestamptz not null default now()
);
create index if not exists idx_exam_subjects_level on public.exam_subjects(level);
create index if not exists idx_exam_subjects_year  on public.exam_subjects(year);

alter table public.exam_subjects enable row level security;
drop policy if exists shared_read on public.exam_subjects;
create policy shared_read on public.exam_subjects
  for select to authenticated using (true);

-- ── 2. Supports de cours — catalogue PARTAGÉ (curé par la plateforme) ────────
-- La bibliothèque (livres + annales + supports) est un fonds de ressources que
-- NOUS (Scolaris) mettons à disposition : même contenu visible par toutes les
-- écoles. L'accès est réservé aux offres Pro/Max côté app (PlanGate), pas par
-- école. → pas de school_id ici, lecture partagée comme `bibliotheque`.
create table if not exists public.course_materials (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  subject      text,
  type         text not null default 'Cours',            -- Cours | TD | Fiche | Exercices…
  level        text,                                      -- niveau cible (ex. '5e', 'Lycée')
  publisher    text,                                      -- éditeur / source du support
  year         integer,
  file_url     text,
  size_kb      integer,
  created_at   timestamptz not null default now()
);

alter table public.course_materials enable row level security;
drop policy if exists shared_read on public.course_materials;
create policy shared_read on public.course_materials
  for select to authenticated using (true);

-- ── 3. Favoris — par utilisateur ─────────────────────────────────────────────
create table if not exists public.library_favorites (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  resource_type  text not null check (resource_type in ('book','exam','material')),
  resource_id    uuid not null,
  created_at     timestamptz not null default now(),
  unique (user_id, resource_type, resource_id)
);
create index if not exists idx_library_fav_user on public.library_favorites(user_id);

alter table public.library_favorites enable row level security;
drop policy if exists owner_all on public.library_favorites;
create policy owner_all on public.library_favorites for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ── 4. Suivi de lecture — par utilisateur (reprise + statistiques) ───────────
create table if not exists public.reading_progress (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  resource_type  text not null check (resource_type in ('book','exam','material')),
  resource_id    uuid not null,
  title          text,
  subject        text,
  progress       numeric not null default 0 check (progress between 0 and 1),
  pages_read     integer not null default 0,
  minutes        integer not null default 0,              -- temps cumulé (stats)
  last_opened    timestamptz not null default now(),
  unique (user_id, resource_type, resource_id)
);
create index if not exists idx_reading_user on public.reading_progress(user_id);
create index if not exists idx_reading_last on public.reading_progress(user_id, last_opened desc);

alter table public.reading_progress enable row level security;
drop policy if exists owner_all on public.reading_progress;
create policy owner_all on public.reading_progress for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

commit;

-- ════════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION (optionnel) :
--   select level, count(*) from public.exam_subjects group by level;
--   select count(*) from public.course_materials where school_id = public.current_school_id();
--   select * from public.reading_progress where user_id = auth.uid() order by last_opened desc;
-- ════════════════════════════════════════════════════════════════════════════
