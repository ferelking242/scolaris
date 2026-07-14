-- ============================================================================
--  20260729_unify_attendance.sql — UNE seule table de presence, et son verrou
--
--  ── Le bug ──────────────────────────────────────────────────────────────────
--  Deux tables coexistaient, et ne se parlaient pas :
--
--    attendance   l'appel du jour (date, status, arrival_time)   ← le prof ECRIT
--    absences     l'absence (motif, justifiee, justificatif)     ← la famille LIT
--
--  Le prof faisait l'appel, marquait un eleve absent : la ligne partait dans
--  `attendance`. L'eleve et ses parents lisaient `absences`, qui restait vide.
--  Une absence marquee n'apparaissait NULLE PART.
--
--  Meme famille de bug que les notes ecrites en 'S1' que le bulletin cherchait
--  en 'T1' : deux moities d'une fonctionnalite qui ne se rejoignent jamais, et
--  aucun message d'erreur pour le dire.
--
--  ── La decision ─────────────────────────────────────────────────────────────
--  `absences` devient LA table. Elle a deja ce qu'une ecole doit garder :
--  school_id (indispensable au cloisonnement — `attendance` n'en avait pas),
--  le motif, la justification et le justificatif.
--
--  On lui ajoute ce qui lui manquait : un vrai `status`. Jusqu'ici l'app
--  detournait la colonne `period` pour y ecrire 'retard' — un champ utilise a
--  contre-emploi, que personne n'aurait devine six mois plus tard.
-- ============================================================================

-- ── 1. Ce qui manquait a `absences` ─────────────────────────────────────────

alter table public.absences
  add column if not exists status text not null default 'absent'
  check (status in ('present', 'late', 'absent', 'excused'));

alter table public.absences add column if not exists arrival_time time;
alter table public.absences add column if not exists recorded_by  uuid references public.users(id);

-- Ces defauts manquaient : sans eux, un insert sans `id` explicite echoue.
alter table public.absences alter column id         set default gen_random_uuid();
alter table public.absences alter column created_at set default now();

comment on column public.absences.status is
  'present | late | absent | excused. Remplace le detournement de `period`,
   ou l''app ecrivait ''retard''.';

-- L'appel se fait une fois par eleve et par jour : c'est ce qui permet au prof
-- de se corriger (upsert) au lieu d'empiler des lignes.
create unique index if not exists absences_student_day_unique
  on public.absences (student_id, absence_date);

-- ── 2. Rapatrier l'appel deja saisi ─────────────────────────────────────────
--  `attendance` n'a pas de school_id : on le deduit de l'eleve, comme le faisait
--  sa policy d'isolation.
insert into public.absences
  (id, school_id, student_id, class_id, subject_id, teacher_id,
   absence_date, status, arrival_time, justified, created_at)
select
  gen_random_uuid(),
  u.school_id,
  a.student_id,
  a.class_id,
  a.subject_id,
  a.recorded_by,
  a.date,
  a.status,
  a.arrival_time,
  false,
  coalesce(a.created_at, now())
from public.attendance a
join public.users u on u.id = a.student_id
where a.student_id is not null
  and a.class_id  is not null
  and u.school_id is not null
on conflict (student_id, absence_date) do nothing;

-- Les lignes ou `period` servait de statut : on les remet d'aplomb.
update public.absences
   set status = 'late'
 where lower(coalesce(period, '')) = 'retard'
   and status = 'absent';

-- ── 3. La table morte disparait ─────────────────────────────────────────────
--  Garder une table que plus personne n'ecrit ni ne lit, c'est garantir qu'un
--  jour quelqu'un la reutilisera par erreur.
drop table if exists public.attendance cascade;

-- ============================================================================
--  4. LE VERROU
--
--  Etat avant : absences ALL tenant_isolation is_member_of(school_id).
--  Un eleve pouvait donc EFFACER ses propres absences, ou se declarer « excuse ».
-- ============================================================================
drop policy if exists tenant_isolation on public.absences;

-- LECTURE — l'eleve voit les siennes, le parent celles de ses enfants, le prof
--  celles de SES classes, la vie scolaire celles de l'ecole.
drop policy if exists absences_read on public.absences;
create policy absences_read on public.absences
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or public.is_my_child(auth.uid(), student_id)
      or (public.get_my_role()::text = 'teacher'
          and public.teaches_class(auth.uid(), class_id))
      or (public.get_my_role()::text <> 'teacher'
          and public.has_permission(auth.uid(), 'presences', 'voir'))
    )
  );

-- SAISIE — l'appel. Le prof ne fait l'appel que dans SES classes.
drop policy if exists absences_insert on public.absences;
create policy absences_insert on public.absences
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'presences', 'saisir')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_class(auth.uid(), class_id)
    )
  );

-- CORRECTION — se corriger apres l'appel, et JUSTIFIER une absence (l'acte du
--  surveillant : « le mot des parents est arrive »).
drop policy if exists absences_update on public.absences;
create policy absences_update on public.absences
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'presences', 'modifier')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_class(auth.uid(), class_id)
    )
  )
  with check (public.is_member_of(school_id));

-- SUPPRESSION — effacer une absence, c'est reecrire l'histoire. Reserve a qui
--  peut deja les corriger, et jamais a un enseignant sur une autre classe.
drop policy if exists absences_delete on public.absences;
create policy absences_delete on public.absences
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'presences', 'modifier')
    and public.get_my_role()::text <> 'teacher'
  );

-- ── Qui a fait l'appel ? ────────────────────────────────────────────────────
create or replace function public.stamp_absence_recorder()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
begin
  if new.recorded_by is null then
    new.recorded_by := public.my_user_id();
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_stamp_absence_recorder on public.absences;
create trigger trg_stamp_absence_recorder
  before insert on public.absences
  for each row execute function public.stamp_absence_recorder();

-- ============================================================================
--  5. BULLETINS — un document INTERNE a l'etablissement
--
--  Decision : le bulletin reste chez l'administration et le personnel autorise.
--  Ni l'eleve ni le parent n'y ont acces — pas meme au bulletin publie, pas meme
--  en lecture. Le bulletin se remet, il ne se consulte pas en libre-service.
--
--  Etat avant : `tenant_isolation` laissait tout membre de l'ecole LIRE ET
--  ECRIRE la table. Un eleve voyait donc son bulletin des le brouillon — et
--  pouvait changer sa moyenne generale, son rang et sa mention.
-- ============================================================================
drop policy if exists tenant_isolation on public.report_cards;

drop policy if exists report_cards_read on public.report_cards;
create policy report_cards_read on public.report_cards
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'voir')
  );

drop policy if exists report_cards_write on public.report_cards;
create policy report_cards_write on public.report_cards
  for all to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'publier')
  )
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'publier')
  );

-- ============================================================================
--  VERIFICATION :
--
--    -- la table morte a disparu :
--    select table_name from information_schema.tables
--     where table_schema = 'public' and table_name = 'attendance';   -- 0 ligne
--
--    -- l'appel rapatrie :
--    select status, count(*) from public.absences group by 1;
--
--    -- un eleve ne peut plus s'excuser lui-meme :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'student' limit 1),
--      'presences', 'modifier');        -- attendu : false
--
--    -- le prof fait l'appel :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'teacher' limit 1),
--      'presences', 'saisir');          -- attendu : true
-- ============================================================================
