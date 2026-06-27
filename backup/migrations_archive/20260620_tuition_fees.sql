-- ============================================================
-- SCOLARIS — Frais de scolarité : grille + échéancier
--
-- Objectif : ne plus créer les factures à la main une par une. L'admin
-- définit UNE grille de frais par classe (montant + rythme + nb de périodes),
-- puis génère l'échéancier annuel de tous les élèves en 1 clic. Les échéances
-- sont des lignes `invoices` (catégorie 'tuition') portant une `period`.
--
-- Idempotent / ré-exécutable.
-- ============================================================

begin;

-- ── 1. Grille de frais (une config par classe et année) ─────────────────────
create table if not exists public.fee_structures (
  id                uuid primary key default gen_random_uuid(),
  school_id         uuid not null references public.schools(id) on delete cascade,
  class_id          uuid not null references public.classes(id) on delete cascade,
  academic_year     text not null,
  rhythm            text not null default 'monthly'
                      check (rhythm in ('monthly','term')),   -- mensualités | tranches
  periods_count     integer not null default 10
                      check (periods_count between 1 and 12),
  amount_per_period numeric not null check (amount_per_period >= 0),
  start_month       integer not null default 9
                      check (start_month between 1 and 12),    -- mois de début (9 = sept.)
  due_day           integer not null default 5
                      check (due_day between 1 and 28),         -- jour d'échéance
  currency          text not null default 'XAF',
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (class_id, academic_year)
);
create index if not exists idx_fee_struct_school on public.fee_structures(school_id);

-- ── 2. `period` sur les factures (ex. '2025-09' ou '2025-T1') ───────────────
alter table public.invoices add column if not exists period text;

-- Anti-doublon : une seule échéance de scolarité par (élève, période).
-- Permet de re-générer sans risque (les lignes déjà créées sont ignorées).
create unique index if not exists idx_invoice_unique_period
  on public.invoices (student_id, period)
  where category = 'tuition' and period is not null;

create index if not exists idx_invoice_period on public.invoices(period);

-- ── 3. RLS — isolation par école (tenant) ───────────────────────────────────
alter table public.fee_structures enable row level security;
drop policy if exists tenant_isolation on public.fee_structures;
create policy tenant_isolation on public.fee_structures for all to authenticated
  using (school_id = public.current_school_id())
  with check (school_id = public.current_school_id());

commit;

-- ════════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION (optionnel) :
--   select * from public.fee_structures where school_id = 'de3764d3-f0e6-4191-ba89-ab4c73cf37a1';
--   select period, count(*) from public.invoices where category='tuition' group by period;
-- ════════════════════════════════════════════════════════════════════════════
