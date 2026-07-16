-- ============================================================
-- SCOLARIS — Bulletins officiels (report_cards)
--
-- Un bulletin n'est PAS une vue temps réel des notes : c'est un document
-- OFFICIEL FIGÉ, produit en fin de trimestre par l'administration. Cette table
-- stocke chaque bulletin déjà calculé (moyennes par matière, moyenne générale,
-- rang, mention) — une fois publié, il ne bouge plus, même si une note change.
--
-- Flux : l'admin GÉNÈRE (statut 'draft', calculé pour toute la classe) puis
-- PUBLIE ('published'). L'élève et le parent ne voient que le 'published'.
--
-- Périmètre v1 : collège/lycée (trimestres T1/T2/T3, notes /20, coefficients).
-- Idempotent / ré-exécutable.
-- ============================================================

begin;

create table if not exists public.report_cards (
  id               uuid primary key default gen_random_uuid(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  student_id       uuid not null,
  student_name     text,
  class_id         uuid not null,
  academic_year    text not null,
  period           text not null,                 -- 'T1' | 'T2' | 'T3'
  -- Lignes figées : [{ "subject": "...", "coef": 4, "average": 14.25,
  --                    "appreciation": "..." }, ...]
  lines            jsonb not null default '[]',
  general_average  numeric not null default 0,
  rank             integer,                        -- rang dans la classe
  class_size       integer,                        -- nb d'élèves classés
  mention          text,
  status           text not null default 'draft'
                     check (status in ('draft','published')),
  generated_at     timestamptz not null default now(),
  published_at     timestamptz,
  created_by       uuid,
  unique (student_id, academic_year, period)
);
create index if not exists idx_report_cards_class
  on public.report_cards(class_id, academic_year, period);
create index if not exists idx_report_cards_student
  on public.report_cards(student_id);

-- RLS : isolation par école (même modèle que `grades`). La distinction
-- admin / élève / parent et le filtre « publié uniquement » sont faits côté app
-- (l'élève ne lit jamais les brouillons).
alter table public.report_cards enable row level security;
drop policy if exists tenant_isolation on public.report_cards;
create policy tenant_isolation on public.report_cards for all to authenticated
  using (school_id = public.current_school_id())
  with check (school_id = public.current_school_id());

commit;

-- ════════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION :
--   select period, status, count(*) from public.report_cards group by period, status;
-- ════════════════════════════════════════════════════════════════════════════
