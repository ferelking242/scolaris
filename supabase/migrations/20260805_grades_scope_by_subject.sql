-- ============================================================================
--  20260805_grades_scope_by_subject.sql — Noter, c'est par MATIERE, pas par classe
--
--  ── Le trou ─────────────────────────────────────────────────────────────────
--
--  20260739_course_assignments.sql a introduit `teaches_subject(uid, class_id,
--  subject_id)` avec ce commentaire : « Sans quoi le prof de maths pourrait
--  noter en francais dans la meme classe. » Mais les policies grades_insert et
--  grades_update de 20260722_lock_grades.sql n'ont jamais ete mises a jour :
--  elles verifient encore `teaches_class`, qui ne regarde que l'acces a la
--  CLASSE (via n'importe quel cours ou le titulariat), pas a la matiere notee.
--
--  Consequence reelle : un prof affecte a un seul `course` (ex. Maths) dans une
--  classe de college pouvait, via l'API (pas forcement visible dans l'UI
--  Flutter), inserer/modifier une note dans n'importe quelle autre matiere de
--  cette meme classe. Le titulaire de primaire garde lui tous les droits sur
--  toute sa classe (teaches_subject couvre aussi ce cas via main_teacher_id).
-- ============================================================================

drop policy if exists grades_insert on public.grades;
create policy grades_insert on public.grades
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'saisir')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_subject(auth.uid(), class_id, subject_id)
    )
  );

drop policy if exists grades_update on public.grades;
create policy grades_update on public.grades
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'modifier')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_subject(auth.uid(), class_id, subject_id)
    )
  )
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'modifier')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_subject(auth.uid(), class_id, subject_id)
    )
  );

-- ============================================================================
--  VERIFICATION :
--
--    -- un prof affecte seulement au cours Maths d'une classe college...
--    -- ...peut noter en Maths dans cette classe :
--    select public.teaches_subject('<auth_uid prof maths>', '<class_id>', '<subject_id maths>');
--    -- attendu : true
--    -- ...mais pas en Francais :
--    select public.teaches_subject('<auth_uid prof maths>', '<class_id>', '<subject_id francais>');
--    -- attendu : false
--
--    -- le titulaire du primaire garde tous les droits sur sa classe, toutes matieres :
--    select public.teaches_subject('<auth_uid titulaire>', '<class_id primaire>', '<n''importe quel subject_id de la classe>');
--    -- attendu : true
-- ============================================================================
