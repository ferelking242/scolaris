-- ============================================================================
--  20260747_notes_audit.sql — ETAPE 2 : la trace de qui a change quoi
--
--  ── Le but ──────────────────────────────────────────────────────────────────
--
--  Une note corrigee apres coup, une decision modifiee : en cas de litige, il
--  faut pouvoir dire QUI a change QUOI, QUAND, de quelle valeur a quelle valeur,
--  et POURQUOI. Sans ca, une correction legitime est indistinguable d'une
--  fraude.
--
--  ── Les principes ───────────────────────────────────────────────────────────
--
--    • La trace est ecrite par un TRIGGER, pas par l'application : impossible
--      d'oublier une ligne ou de la maquiller.
--    • Elle est IMMUABLE : aucune policy d'update ni de delete. On n'efface pas
--      un journal.
--    • Le NOM de l'auteur est copie a l'instant du changement : le journal reste
--      lisible meme si le compte est supprime dans dix ans.
--    • Le MOTIF est obligatoire des qu'on corrige une periode VALIDEE. Il voyage
--      par une variable de session que l'appli pose juste avant d'ecrire.
-- ============================================================================

-- ── 1. Le journal ───────────────────────────────────────────────────────────
create table if not exists public.notes_audit (
  id            uuid primary key default gen_random_uuid(),
  school_id     uuid not null,
  class_id      uuid,
  student_id    uuid,
  subject_id    uuid,
  period        text,
  -- 'note' | 'appreciation' | 'suppression' | 'statut_periode' | 'recalcul'
  change_type   text not null,
  field         text,
  old_value     text,
  new_value     text,
  reason        text,
  actor_id      uuid,
  actor_name    text,                       -- denormalise : lisible pour toujours
  created_at    timestamptz not null default now()
);

create index if not exists idx_notes_audit_scope
  on public.notes_audit (class_id, period, created_at desc);
create index if not exists idx_notes_audit_student
  on public.notes_audit (student_id, created_at desc);

comment on table public.notes_audit is
  'Journal IMMUABLE des modifications de notes/appreciations/decisions. Ecrit par
   trigger, jamais efface. Sert la tracabilite et le reglement des litiges.';

-- ── 2. De qui parle-t-on, et pourquoi ? ─────────────────────────────────────
create or replace function public.current_actor_name()
returns text
language sql stable security definer
set search_path = public
as $fn$
  select full_name from public.users where auth_uid = auth.uid() limit 1;
$fn$;

--  Le motif pose par l'appli : set_config('app.change_reason', '…', true).
create or replace function public.current_change_reason()
returns text
language sql stable
as $fn$
  select nullif(trim(coalesce(current_setting('app.change_reason', true), '')), '');
$fn$;

-- ── 3. Tracer chaque modification d'une note existante ──────────────────────
--  On ne trace PAS l'insertion d'une note neuve (c'est la saisie normale, pas
--  une modification). On trace le changement de valeur, le changement
--  d'appreciation (comment), et la suppression.
create or replace function public.audit_grade_change()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
declare
  v_reason text := public.current_change_reason();
  v_actor  text := public.current_actor_name();
begin
  if tg_op = 'UPDATE' then
    if new.score is distinct from old.score then
      insert into public.notes_audit (school_id, class_id, student_id, subject_id,
        period, change_type, field, old_value, new_value, reason, actor_id, actor_name)
      values (old.school_id, old.class_id, old.student_id, old.subject_id,
        old.period, 'note',
        coalesce(old.type,'') || ' #' || coalesce(old.sequence::text,'1'),
        to_char(old.score, 'FM990.00'), to_char(new.score, 'FM990.00'),
        v_reason, auth.uid(), v_actor);
    end if;
    if new.comment is distinct from old.comment then
      insert into public.notes_audit (school_id, class_id, student_id, subject_id,
        period, change_type, field, old_value, new_value, reason, actor_id, actor_name)
      values (old.school_id, old.class_id, old.student_id, old.subject_id,
        old.period, 'appreciation', 'appreciation',
        old.comment, new.comment, v_reason, auth.uid(), v_actor);
    end if;
  elsif tg_op = 'DELETE' then
    insert into public.notes_audit (school_id, class_id, student_id, subject_id,
      period, change_type, field, old_value, new_value, reason, actor_id, actor_name)
    values (old.school_id, old.class_id, old.student_id, old.subject_id,
      old.period, 'suppression',
      coalesce(old.type,'') || ' #' || coalesce(old.sequence::text,'1'),
      to_char(old.score, 'FM990.00'), null, v_reason, auth.uid(), v_actor);
  end if;
  return null; -- AFTER trigger : la valeur de retour est ignoree
end;
$fn$;

drop trigger if exists trg_audit_grade_change on public.grades;
create trigger trg_audit_grade_change
  after update or delete on public.grades
  for each row execute function public.audit_grade_change();

-- ── 4. Le motif devient OBLIGATOIRE sur une periode validee ─────────────────
--  On reprend le garde-fou de l'etape 1 en y ajoutant l'exigence du motif :
--  corriger une note gelee sans dire pourquoi n'a pas de sens.
create or replace function public.guard_grade_period()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
declare
  v_class  uuid;
  v_period text;
  v_status text;
begin
  if tg_op = 'DELETE' then
    v_class := old.class_id;  v_period := old.period;
  else
    v_class := new.class_id;  v_period := new.period;
  end if;

  v_status := public.grade_period_status(v_class, v_period);

  if v_status = 'open' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if v_status = 'locked' then
    raise exception
      'Periode verrouillee : cette note ne peut plus etre modifiee. Deverrouillez la periode d''abord.'
      using errcode = '42501';
  end if;

  -- Validee : droit de correction ...
  if not public.has_permission(auth.uid(), 'notes', 'corriger') then
    raise exception
      'Periode validee : la correction d''une note demande le droit « Corriger une note verrouillee ».'
      using errcode = '42501';
  end if;

  -- ... ET motif obligatoire.
  if public.current_change_reason() is null then
    raise exception
      'Periode validee : indiquez un motif pour corriger cette note (il sera trace).'
      using errcode = '42501';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

-- ── 5. RLS : on lit le journal, on ne le reecrit jamais ─────────────────────
alter table public.notes_audit enable row level security;

drop policy if exists notes_audit_read on public.notes_audit;
create policy notes_audit_read on public.notes_audit
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'voir')
  );

--  Pas de policy insert / update / delete : les clients ne peuvent NI ecrire NI
--  effacer. Seul le trigger (security definer) alimente la table. Un journal
--  qu'on pourrait modifier ne vaudrait rien.

-- ============================================================================
--  VERIFICATION :
--
--    -- Le journal est-il alimente ? (corrigez une note validee, puis :)
--    select created_at, actor_name, change_type, field, old_value, new_value, reason
--      from public.notes_audit order by created_at desc limit 20;
--
--    -- Tenter d'effacer une ligne doit ECHOUER (aucune policy delete) :
--    delete from public.notes_audit;   -- 0 ligne / refus attendu
-- ============================================================================
