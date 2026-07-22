-- ============================================================================
--  20260754_student_lifecycle.sql — Fin de scolarité : passage de classe et
--  sortie d'élève (transfert, diplôme, radiation, abandon)
--
--  ── Le problème ─────────────────────────────────────────────────────────────
--  Aucune des deux choses n'existait :
--    • Passage de classe : rien ne fait avancer un élève d'une classe à
--      l'autre en fin d'année — ni écran, ni fonction, ni trace de la
--      décision (admis/redouble).
--    • Sortie d'élève : le seul chemin existant est `delete_user_account()`
--      (20260749_delete_user_with_reason.sql) — une SUPPRESSION DÉFINITIVE.
--      Un élève transféré, diplômé, ou qui abandonne perd tout son dossier
--      (notes, bulletins) au lieu de simplement quitter les effectifs actifs.
--
--  ── Ce que ça change ─────────────────────────────────────────────────────────
--    • `student_profiles.enrollment_status` : 'active' (par défaut) |
--      'graduated' | 'transferred' | 'withdrawn'. Un élève qui quitte l'école
--      n'est plus supprimé : il change de statut, garde son dossier complet,
--      et disparaît des effectifs actifs (classes, carnets de notes).
--    • `student_progressions` : le journal des décisions de fin d'année (une
--      ligne par élève par année) — promu vers telle classe, redouble, ou
--      sorti (avec motif). Sert à la fois le passage de classe ET la sortie :
--      ce sont la MÊME décision de fin d'année, juste avec des issues
--      différentes.
-- ============================================================================

-- ── 1. Le statut de scolarité de l'élève ────────────────────────────────────
alter table public.student_profiles
  add column if not exists enrollment_status text not null default 'active',
  add column if not exists exit_reason text,
  add column if not exists exit_date date;

alter table public.student_profiles
  drop constraint if exists student_profiles_enrollment_status_check;
alter table public.student_profiles
  add constraint student_profiles_enrollment_status_check
  check (enrollment_status in ('active', 'graduated', 'transferred', 'withdrawn'));

comment on column public.student_profiles.enrollment_status is
  'Statut de scolarité DANS CETTE ÉCOLE — distinct de users.status (compte
   suspendu/actif, sans rapport). ''active'' = élève courant. Les 3 autres =
   sorti (cf. exit_reason/exit_date) : garde tout son dossier, mais disparaît
   des effectifs actifs (classes, carnets de notes, listes admin par défaut).';

create index if not exists idx_student_profiles_enrollment_status
  on public.student_profiles (school_id, enrollment_status);

-- ── 2. Le journal des décisions de fin d'année ──────────────────────────────
create table if not exists public.student_progressions (
  id                uuid primary key default gen_random_uuid(),
  school_id         uuid not null references public.schools(id) on delete cascade,
  student_id        uuid not null references public.users(id) on delete cascade,
  from_class_id     uuid references public.classes(id) on delete set null,
  to_class_id       uuid references public.classes(id) on delete set null,
  from_academic_year text,
  to_academic_year   text,
  -- 'promoted' (classe supérieure) | 'repeated' (redouble, même niveau) |
  -- 'transferred' | 'graduated' | 'withdrawn' (les 3 = sortie de l'école).
  decision          text not null check (
                       decision in ('promoted', 'repeated', 'transferred',
                                    'graduated', 'withdrawn')),
  average           numeric,        -- moyenne annuelle au moment de la décision
  reason            text,           -- motif, surtout utile pour transferred/withdrawn
  decided_by        uuid references public.users(id) on delete set null,
  decided_by_name   text,           -- dénormalisé : lisible même si le compte part
  decided_at        timestamptz not null default now()
);

create index if not exists idx_student_progressions_student
  on public.student_progressions (student_id, decided_at desc);
create index if not exists idx_student_progressions_school_year
  on public.student_progressions (school_id, to_academic_year);

comment on table public.student_progressions is
  'Historique des décisions de fin d''année : passage de classe (promoted/
   repeated) ou sortie de l''école (transferred/graduated/withdrawn). Une
   ligne = un élève, une année, une décision. Jamais modifié après coup — une
   décision corrigée en ajoute une nouvelle, elle n''écrase pas l''ancienne.';

alter table public.student_progressions enable row level security;

drop policy if exists student_progressions_read on public.student_progressions;
create policy student_progressions_read on public.student_progressions
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists student_progressions_write on public.student_progressions;
create policy student_progressions_write on public.student_progressions
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'utilisateurs', 'modifier')
  );

-- Pas de policy update/delete : une décision de fin d'année ne se corrige pas
-- en place, elle s'annule par une nouvelle ligne (cf. commentaire ci-dessus).

-- ============================================================================
--  VERIFICATION :
--    select enrollment_status, count(*) from public.student_profiles group by 1;
--    select decision, count(*) from public.student_progressions group by 1;
-- ============================================================================
