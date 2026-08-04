-- ============================================================================
--  20260806_grades_check_within_scale.sql — Filet de securite : une note ne
--  peut pas depasser son propre bareme
--
--  Cote Flutter, le carnet du prof et la grille de l'admin clampaient (et
--  desormais valident) une note tapee hors bareme (ex. 15 saisi sur une
--  classe /10). Mais rien en base n'empechait un appel API direct d'ecrire
--  n'importe quelle valeur : `grades` n'avait aucun CHECK sur score/max_score.
--  Meme logique que grades_period_check/grades_type_check (20260723/20260725) :
--  une contrainte posee cote client uniquement n'en est pas une.
-- ============================================================================

alter table public.grades drop constraint if exists grades_score_within_scale_check;
alter table public.grades
  add constraint grades_score_within_scale_check
  check (
    max_score > 0
    and score >= 0
    and score <= max_score
  );

-- ============================================================================
--  VERIFICATION :
--    select conname, pg_get_constraintdef(oid) from pg_constraint
--     where conrelid = 'public.grades'::regclass and contype = 'c';
--    -- une insertion hors bareme doit etre rejetee :
--    -- insert into grades (..., score, max_score, ...) values (..., 15, 10, ...);
--    -- attendu : ERROR 23514 grades_score_within_scale_check
-- ============================================================================
