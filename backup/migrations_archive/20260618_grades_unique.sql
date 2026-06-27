-- Prérequis à l'enregistrement des notes (carnet prof → upsertGrade).
-- 1) Défaut sur grades.id : l'app n'envoie pas d'id à l'upsert. Le projet réel
--    a normalement déjà ce défaut (le baseline d'introspection ne montre PAS les
--    DEFAULT) ; on le (re)pose ici pour être auto-suffisant et idempotent.
-- 2) Contrainte unique : indispensable au `upsert ... onConflict:
--    'student_id,subject_id,period,type'`. Sans elle, l'enregistrement échoue.
--    NB : PostgreSQL ne supporte PAS `ADD CONSTRAINT IF NOT EXISTS` (erreur 42601)
--    → on passe par un bloc DO qui vérifie l'existence avant de créer.

-- 1) Défaut d'id (sans risque si déjà présent)
alter table public.grades alter column id set default gen_random_uuid();

-- 2) Contrainte unique (créée seulement si absente)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'grades_student_subject_period_type_key'
  ) then
    alter table public.grades
      add constraint grades_student_subject_period_type_key
      unique (student_id, subject_id, period, type);
  end if;
end$$;
