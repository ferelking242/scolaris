-- ============================================================================
--  20260731_attendance_add_subject.sql — le prof, ET le cours
--
--  Suite de 20260731_attendance_per_teacher.sql. Retour utilisateur : au
--  collège/lycée, plusieurs profs prennent la même classe le même jour, mais
--  jamais dans le même cours. `teacher_id` seul ne suffit pas : un même prof
--  peut donner deux matières différentes à la même classe le même jour (ex.
--  titulaire qui fait aussi une heure de soutien) — ses deux pointages du jour
--  s'écraseraient encore l'un l'autre sans `subject_id` dans la clé.
--
--  `subject_id` existe déjà sur `absences` (comme `teacher_id`), toujours
--  NULL aujourd'hui. `null` reste légitime : le pointage « journée entière »
--  du titulaire (primaire) ou du staff (supervision) n'est lié à aucun cours
--  précis.
-- ============================================================================

drop index if exists public.absences_student_day_teacher_unique;

create unique index if not exists absences_student_day_teacher_subject_unique
  on public.absences (student_id, absence_date, teacher_id, subject_id);

comment on column public.absences.subject_id is
  'Le cours pour lequel CE pointage a été fait (NULL = pointage journée
   entière, titulaire ou staff). Avec teacher_id, isole chaque session de
   cours d''un même prof le même jour. Cf. 20260731_attendance_add_subject.sql.';

-- ============================================================================
--  VERIFICATION :
--
--    select indexname from pg_indexes
--     where schemaname='public' and tablename='absences';
--    -- attendu : absences_student_day_teacher_unique absent,
--    --           absences_student_day_teacher_subject_unique présent
-- ============================================================================
