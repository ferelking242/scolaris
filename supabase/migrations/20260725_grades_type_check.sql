-- ============================================================================
--  20260725_grades_type_check.sql — Rapatrier une contrainte posee a la main
--
--  `grades_type_check` existait sur le serveur sans figurer dans AUCUNE
--  migration. Troisieme fois que le depot ment sur l'etat reel de la base
--  (apres les tables du systeme de roles, les colonnes de `courses`, et
--  `grades_period_check`). On la remet dans le depot, telle qu'elle est, pour
--  qu'un `db reset` reconstruise vraiment la base.
--
--  Elle refusait la saisie : le carnet du prof envoyait 'interro1'/'interro2',
--  un vocabulaire que la base ne connait pas. Cote Dart, le carnet parle
--  desormais devoir | controle | examen — comme la base, et comme l'espace
--  eleve qui savait deja les afficher.
--
--  Aucune donnee a migrer : la contrainte empechait deja toute valeur hors
--  liste d'entrer.
-- ============================================================================

alter table public.grades drop constraint if exists grades_type_check;
alter table public.grades
  add constraint grades_type_check
  check (type in ('devoir', 'examen', 'controle', 'tp', 'oral', 'projet'));

-- ============================================================================
--  VERIFICATION :
--    select type, count(*) from public.grades group by 1 order by 2 desc;
-- ============================================================================
