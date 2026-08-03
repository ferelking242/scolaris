-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige la suppression de classe bloquée par « Impossible : un élément lié
-- est introuvable ou a été supprimé. » (23503 — foreign key violation).
--
-- `courses.class_id` n'avait pas de ON DELETE CASCADE, contrairement à toutes
-- les autres tables liées à `classes` (schedules, grades, absences,
-- assignments, grade_periods, liaison_entries — vérifié en direct, toutes en
-- CASCADE). Sans conséquence tant que les classes étaient créées vides ; devenu
-- bloquant systématique depuis `generateDefaultProgramForClass` qui rattache
-- ~9 cours par défaut à chaque classe primaire créée.
--
-- `course_teachers.course_id` cascade déjà depuis `courses` (vérifié en
-- direct) — rien à faire de ce côté, le cascade se propage tout seul.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.courses
  drop constraint courses_class_id_fkey,
  add constraint courses_class_id_fkey
    foreign key (class_id) references public.classes(id) on delete cascade;
