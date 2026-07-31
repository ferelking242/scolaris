-- ============================================================================
--  20260731_attendance_per_teacher.sql — un pointage par PROF, pas par classe
--
--  ── Le bug ──────────────────────────────────────────────────────────────────
--  `absences_student_day_unique` sur (student_id, absence_date) : une seule
--  ligne par élève et par jour, tous profs confondus. Au collège/lycée, une
--  classe a plusieurs profs dans la journée : le dernier qui fait
--  `saveAttendance` (upsert on_conflict student_id,absence_date) écrase le
--  pointage du précédent pour toute la journée, sans le savoir.
--
--  `teacher_id` existe déjà sur `absences` (schéma de base) mais n'était
--  jamais renseigné par l'app (0 ligne sur 12 aujourd'hui) — vérifié en direct
--  avant cette migration, `information_schema`/`pg_indexes`, 2026-07-31.
--
--  ── La décision ─────────────────────────────────────────────────────────────
--  Chaque pointage est désormais isolé par (élève, jour, prof qui l'a fait).
--  Plusieurs profs peuvent pointer la même classe le même jour sans se
--  marcher dessus ; chacun ne voit/modifie que sa propre ligne (filtré côté
--  app par `teacher_id`). Le staff (vie scolaire) a lui aussi sa propre ligne
--  indépendante — un pointage de supervision de plus, pas un remplacement.
--
--  Les 12 lignes existantes ont `teacher_id` NULL : NULL est toujours distinct
--  dans un index unique Postgres, donc rien ne viole le nouvel index. Il faut
--  seulement que l'app renseigne désormais TOUJOURS `teacher_id` en écriture
--  (sinon deux upserts avec teacher_id NULL ne se détecteraient jamais comme
--  conflit, et dupliqueraient des lignes au lieu de se corriger).
-- ============================================================================

drop index if exists public.absences_student_day_unique;

create unique index if not exists absences_student_day_teacher_unique
  on public.absences (student_id, absence_date, teacher_id);

comment on column public.absences.teacher_id is
  'Qui a fait CE pointage (prof de la période, ou membre du staff/vie scolaire).
   Désormais toujours renseigné par l''app — nécessaire pour que deux profs de
   la même classe le même jour aient des lignes distinctes au lieu de
   s''écraser. Cf. 20260731_attendance_per_teacher.sql.';

-- ============================================================================
--  VERIFICATION :
--
--    select indexname, indexdef from pg_indexes
--     where schemaname='public' and tablename='absences';
--    -- attendu : absences_student_day_unique absent,
--    --           absences_student_day_teacher_unique présent
-- ============================================================================
