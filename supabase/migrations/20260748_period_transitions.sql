-- ============================================================================
--  20260748_period_transitions.sql — ETAPE 3 (base) : valider, verrouiller,
--  rouvrir — et corriger AVEC motif
--
--  Les transitions d'etat d'une periode sont des actes graves : elles gelent ou
--  liberent des notes. On ne les laisse pas a une simple ecriture d'ecran — elles
--  passent par des fonctions `security definer` qui verifient le droit, posent
--  l'etat, et TRACENT le changement dans notes_audit.
--
--  Le SNAPSHOT (report_cards) n'est PAS calcule ici : il l'est en Dart, par le
--  seul moteur teste (buildBulletins). Recalculer la moyenne en SQL recreerait un
--  troisieme calcul divergent — l'erreur qu'on a passe des jours a effacer.
--  Ici on ne fait que geler/liberer et tracer.
-- ============================================================================

-- ── Un helper interne : tracer un changement d'etat ─────────────────────────
create or replace function public._audit_period(
  p_class uuid, p_period text, p_old text, p_new text, p_reason text)
returns void
language sql security definer set search_path = public
as $fn$
  insert into public.notes_audit (school_id, class_id, period, change_type,
    field, old_value, new_value, reason, actor_id, actor_name)
  select c.school_id, p_class, p_period, 'statut_periode', 'statut',
         p_old, p_new, p_reason, auth.uid(), public.current_actor_name()
    from public.classes c where c.id = p_class;
$fn$;

-- ── 1. VALIDER : open -> validated ──────────────────────────────────────────
--  Gele les notes. Le snapshot doit avoir ete ecrit juste avant, cote app.
create or replace function public.validate_period(p_class uuid, p_period text)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_school uuid;
  v_year   text;
  v_old    text;
begin
  select school_id, academic_year into v_school, v_year
    from public.classes where id = p_class;
  if v_school is null then
    raise exception 'Classe introuvable.' using errcode = 'P0002';
  end if;
  if not public.has_permission(auth.uid(), 'notes', 'valider') then
    raise exception 'Vous n''avez pas le droit de valider une periode.'
      using errcode = '42501';
  end if;

  v_old := public.grade_period_status(p_class, p_period);

  insert into public.grade_periods
    (school_id, class_id, period, academic_year, status, validated_by, validated_at)
  values (v_school, p_class, p_period, v_year, 'validated', auth.uid(), now())
  on conflict (class_id, period) do update
    set status = 'validated', validated_by = auth.uid(), validated_at = now(),
        locked_by = null, locked_at = null, updated_at = now();

  perform public._audit_period(p_class, p_period, v_old, 'validated', null);
end;
$fn$;

-- ── 2. VERROUILLER : validated -> locked ────────────────────────────────────
create or replace function public.lock_period(p_class uuid, p_period text)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_school uuid; v_year text; v_old text;
begin
  select school_id, academic_year into v_school, v_year
    from public.classes where id = p_class;
  if not public.has_permission(auth.uid(), 'notes', 'verrouiller') then
    raise exception 'Vous n''avez pas le droit de verrouiller une periode.'
      using errcode = '42501';
  end if;

  v_old := public.grade_period_status(p_class, p_period);
  if v_old <> 'validated' then
    raise exception 'Seule une periode VALIDEE peut etre verrouillee.'
      using errcode = '22023';
  end if;

  update public.grade_periods
     set status = 'locked', locked_by = auth.uid(), locked_at = now(),
         updated_at = now()
   where class_id = p_class and period = p_period;

  perform public._audit_period(p_class, p_period, v_old, 'locked', null);
end;
$fn$;

-- ── 3. ROUVRIR : validated|locked -> open ───────────────────────────────────
--  Le plus sensible : on relache un verrou. Reserve a `notes.verrouiller`, et le
--  motif est vivement recommande (impose si la periode etait verrouillee).
create or replace function public.reopen_period(
  p_class uuid, p_period text, p_reason text default null)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_old text;
begin
  if not public.has_permission(auth.uid(), 'notes', 'verrouiller') then
    raise exception 'Vous n''avez pas le droit de rouvrir une periode.'
      using errcode = '42501';
  end if;

  v_old := public.grade_period_status(p_class, p_period);
  if v_old = 'open' then
    return; -- deja ouverte, rien a faire
  end if;
  if v_old = 'locked' and nullif(trim(coalesce(p_reason,'')), '') is null then
    raise exception 'Rouvrir une periode VERROUILLEE exige un motif (il sera trace).'
      using errcode = '42501';
  end if;

  update public.grade_periods
     set status = 'open', validated_by = null, validated_at = null,
         locked_by = null, locked_at = null, updated_at = now()
   where class_id = p_class and period = p_period;

  perform public._audit_period(p_class, p_period, v_old, 'open',
    nullif(trim(coalesce(p_reason,'')), ''));
end;
$fn$;

-- ── 4. CORRIGER UNE NOTE avec motif, en une seule transaction ───────────────
--  PostgREST envoie une requete = une transaction. Pour que le trigger d'audit
--  VOIE le motif, il faut poser la variable de session ET ecrire la note dans le
--  MEME appel. D'ou cette fonction : elle pose le motif, puis fait l'upsert.
--
--  `security invoker` (defaut) : les policies de `grades` et le garde-fou de
--  periode s'appliquent normalement — on ne veut RIEN contourner, juste
--  transporter le motif.
create or replace function public.save_grade(
  p_student uuid, p_class uuid, p_school uuid, p_subject uuid,
  p_score numeric, p_max numeric, p_period text, p_type text,
  p_sequence smallint, p_reason text default null)
returns void
language plpgsql
set search_path = public
as $fn$
begin
  perform set_config('app.change_reason',
    coalesce(nullif(trim(coalesce(p_reason,'')), ''), ''), true);

  insert into public.grades
    (id, student_id, class_id, school_id, subject_id, score, max_score,
     period, type, sequence, graded_at, created_at, updated_at)
  values (gen_random_uuid(), p_student, p_class, p_school, p_subject, p_score,
     p_max, p_period, p_type, p_sequence, now(), now(), now())
  on conflict (student_id, subject_id, period, type, sequence) do update
    set score = excluded.score, max_score = excluded.max_score,
        updated_at = now();
end;
$fn$;

grant execute on function public.validate_period(uuid, text) to authenticated;
grant execute on function public.lock_period(uuid, text) to authenticated;
grant execute on function public.reopen_period(uuid, text, text) to authenticated;
grant execute on function public.save_grade(uuid, uuid, uuid, uuid, numeric, numeric, text, text, smallint, text) to authenticated;

-- ============================================================================
--  VERIFICATION :
--    select public.validate_period('<class_uuid>', 'T1');   -- gele la periode
--    select status, validated_at from public.grade_periods where period='T1';
--    -- corriger une note gelee sans droit -> refus ; avec droit + motif -> trace
-- ============================================================================
