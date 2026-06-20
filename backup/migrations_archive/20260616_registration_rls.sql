-- ============================================================
-- SCOLARIS — RLS : autoriser l'inscription d'une école
-- À exécuter dans : Supabase Dashboard > SQL Editor
--
-- Le formulaire d'inscription (school_registration_screen.dart) insère, SANS
-- être connecté, dans 5 tables. Sans politique INSERT, la RLS bloque (42501).
-- Cette migration ouvre l'INSERT public (anon + authenticated) sur ces tables.
--
-- ⚠️ Sécurité : cela permet à quiconque possède la clé anon de créer une école.
--    Acceptable pour un parcours d'inscription self-service au lancement.
--    À durcir plus tard (captcha / edge function / modération / rate-limit).
-- ============================================================

-- S'assurer que la RLS est active (sans casser les policies existantes)
alter table public.schools          enable row level security;
alter table public.school_branches  enable row level security;
alter table public.school_founders  enable row level security;
alter table public.school_series    enable row level security;
alter table public.school_classes   enable row level security;

-- ── schools ──────────────────────────────────────────────────────────────────
drop policy if exists "Inscription publique - schools" on public.schools;
create policy "Inscription publique - schools"
  on public.schools for insert to anon, authenticated
  with check (true);

-- ── school_branches ──────────────────────────────────────────────────────────
drop policy if exists "Inscription publique - branches" on public.school_branches;
create policy "Inscription publique - branches"
  on public.school_branches for insert to anon, authenticated
  with check (true);

-- ── school_founders ──────────────────────────────────────────────────────────
drop policy if exists "Inscription publique - founders" on public.school_founders;
create policy "Inscription publique - founders"
  on public.school_founders for insert to anon, authenticated
  with check (true);

-- ── school_series ────────────────────────────────────────────────────────────
drop policy if exists "Inscription publique - series" on public.school_series;
create policy "Inscription publique - series"
  on public.school_series for insert to anon, authenticated
  with check (true);

-- ── school_classes ───────────────────────────────────────────────────────────
drop policy if exists "Inscription publique - classes" on public.school_classes;
create policy "Inscription publique - classes"
  on public.school_classes for insert to anon, authenticated
  with check (true);
