-- ============================================================================
--  20260718_staff_profiles.sql — Fiche du personnel
--
--  Jusqu'ici, un membre du personnel n'etait qu'un nom, un email et un role.
--  Pas de telephone (la colonne users.phone existait, remplie pour les eleves et
--  les parents, mais jamais demandee au personnel — impossible de joindre sa
--  propre secretaire), pas de matricule, pas de date d'embauche.
--
--  Les enseignants avaient deja une fiche (teacher_profiles : employee_id,
--  specialization, qualification, join_date). Le reste du personnel n'avait
--  RIEN. Cette table comble le trou, sur le meme modele.
-- ============================================================================

create table if not exists public.staff_profiles (
  user_id       uuid primary key references public.users(id) on delete cascade,
  school_id     uuid not null references public.schools(id) on delete cascade,

  employee_id   text,                       -- matricule employe (propre a l'ecole)
  gender        text,                       -- 'M' | 'F' | autre
  date_of_birth date,
  join_date     date,                       -- date d'embauche

  -- 'permanent'   : contrat sans terme
  -- 'vacataire'   : paye a la vacation / heures
  -- 'prestataire' : intervenant externe (une date de fin d'acces viendra plus
  --                 tard — cf. discussion sur les prestataires)
  contract_type text not null default 'permanent'
    check (contract_type in ('permanent', 'vacataire', 'prestataire')),

  metadata      jsonb default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_staff_profiles_school
  on public.staff_profiles (school_id);

-- Un matricule est unique DANS une ecole (deux ecoles peuvent avoir un « 001 »).
create unique index if not exists idx_staff_profiles_matricule
  on public.staff_profiles (school_id, employee_id)
  where employee_id is not null;

alter table public.staff_profiles enable row level security;

-- Lecture : les membres de l'ecole (meme regle que les autres tables metier,
-- qui passent toutes par is_member_of).
drop policy if exists "Voir les fiches du personnel de son ecole" on public.staff_profiles;
create policy "Voir les fiches du personnel de son ecole" on public.staff_profiles
  for select using (public.is_member_of(school_id));

-- Ecriture : qui gere les utilisateurs (ou un role admin).
drop policy if exists "Gerer les fiches du personnel" on public.staff_profiles;
create policy "Gerer les fiches du personnel" on public.staff_profiles
  for all
  using      (public.is_member_of(school_id)
              and public.has_permission(auth.uid(), 'utilisateurs', 'modifier'))
  with check (public.is_member_of(school_id)
              and public.has_permission(auth.uid(), 'utilisateurs', 'modifier'));
