-- ─────────────────────────────────────────────────────────────────────────────
-- Phase D5 — Emploi du temps : recréation de la table `schedules`
--
-- (Supprimée au nettoyage — 46 lignes de démo perdues, sans valeur.) On la
-- recrée proprement, isolée par école (RLS), pour un emploi du temps réel :
-- une ligne = un cours hebdomadaire d'une classe (matière + prof + jour + heure).
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.schedules (
  id            uuid primary key default gen_random_uuid(),
  school_id     uuid not null references public.schools(id) on delete cascade,
  class_id      uuid not null references public.classes(id) on delete cascade,
  subject_id    uuid references public.subjects(id) on delete set null,
  teacher_id    uuid references public.users(id) on delete set null,
  day_of_week   smallint not null,            -- 1 = lundi … 6 = samedi (7 = dim.)
  start_time    time not null,
  end_time      time not null,
  room          text,
  academic_year text default '2025-2026',
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists schedules_class_idx on public.schedules (class_id);
create index if not exists schedules_school_idx on public.schedules (school_id);

-- RLS : isolation par école (même schéma que les autres tables tenant).
alter table public.schedules enable row level security;
drop policy if exists tenant_isolation on public.schedules;
create policy tenant_isolation on public.schedules for all to authenticated
  using (school_id = public.current_school_id())
  with check (school_id = public.current_school_id());
