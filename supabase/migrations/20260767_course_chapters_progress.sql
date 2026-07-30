-- ============================================================================
--  20260767_course_chapters_progress.sql — Suivi de progression par le prof
--
--  Le programme (texte + nombre de chapitres) reste écrit par l'admin/staff
--  (`program_summary`/`chapter_count`, cf. 20260738/20260739) — c'est le
--  programme OFFICIEL de l'école, partagé entre tous les profs d'une même
--  matière. Mais aucun prof ne pouvait indiquer où il en est réellement dans
--  ce programme. On ajoute une colonne de progression (`chapters_done`),
--  modifiable UNIQUEMENT par le(s) prof(s) affecté(s) au cours, via une
--  fonction dédiée — jamais par UPDATE direct sur `courses` (qui resterait
--  réservé à l'admin) pour ne pas ouvrir l'écriture des autres colonnes
--  (coefficient, horaires…) aux enseignants.
--
--  Idempotent. Rejouable.
-- ============================================================================

alter table public.courses
  add column if not exists chapters_done integer not null default 0;

alter table public.courses
  drop constraint if exists courses_chapters_done_check;
alter table public.courses
  add constraint courses_chapters_done_check check (chapters_done >= 0);

-- ── Mise à jour de la progression — réservée au(x) prof(s) du cours ─────────
create or replace function public.set_course_chapters_done(
  p_course_id uuid,
  p_chapters_done integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chapter_count integer;
  v_is_teacher boolean;
begin
  select chapter_count into v_chapter_count
  from public.courses
  where id = p_course_id;

  if v_chapter_count is null then
    raise exception 'Cours introuvable';
  end if;

  select exists(
    select 1 from public.course_teachers ct
    join public.users u on u.id = ct.teacher_id
    where ct.course_id = p_course_id and u.auth_uid = auth.uid()
  ) into v_is_teacher;

  if not v_is_teacher then
    raise exception 'Seul un enseignant affecté à ce cours peut modifier sa progression';
  end if;

  if p_chapters_done < 0 then
    raise exception 'La progression ne peut pas être négative';
  end if;
  if v_chapter_count > 0 and p_chapters_done > v_chapter_count then
    raise exception 'La progression ne peut pas dépasser le nombre de chapitres du programme (%)', v_chapter_count;
  end if;

  update public.courses set chapters_done = p_chapters_done where id = p_course_id;
end;
$$;

grant execute on function public.set_course_chapters_done(uuid, integer) to authenticated;

-- ============================================================================
--  VERIFICATION :
--    -- connecté en tant que prof affecté au cours :
--    select set_course_chapters_done('<course_id>', 3);
--    -- connecté en tant que prof NON affecté :
--    select set_course_chapters_done('<course_id>', 3); -- doit échouer
-- ============================================================================
