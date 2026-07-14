-- ============================================================================
--  20260731_lock_structure.sql — La derniere fausse cle, et la structure
--
--  ── 1. parent_student : LA fausse cle ───────────────────────────────────────
--
--  Les verrous poses jusqu'ici disent, encore et encore :
--      « le parent voit les notes / factures / absences de SES enfants »
--  et ils demandent a `is_my_child()`, qui lit `parent_student`.
--
--  Or `parent_student` etait ouverte en ecriture a tout membre de l'ecole.
--  Un eleve s'y declarait parent d'un camarade — et lisait ses notes, ses
--  factures, ses absences, son cahier de liaison. Pas en forcant un verrou : en
--  se fabriquant la cle que le verrou reclame.
--
--  C'est le meme defaut que `teacher_classes` (20260730), et le dernier du
--  genre : une table de RATTACHEMENT libre d'ecriture rend caduc tout verrou qui
--  s'appuie dessus.
--
--  ── 2. La structure pedagogique ─────────────────────────────────────────────
--  classes, matieres, cours, emploi du temps, devoirs, remises. Toutes en
--  `tenant_isolation ALL` : un eleve pouvait supprimer une classe entiere, une
--  matiere, ou l'emploi du temps de l'ecole.
-- ============================================================================

-- ============================================================================
--  1) PARENT ↔ ENFANT
-- ============================================================================
drop policy if exists tenant_isolation on public.parent_student;

-- LECTURE — chacun voit ses propres liens (le parent ses enfants, l'eleve ses
--  parents). Le personnel autorise voit l'annuaire des familles.
drop policy if exists parent_student_read on public.parent_student;
create policy parent_student_read on public.parent_student
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      parent_id  = public.my_user_id()
      or student_id = public.my_user_id()
      or public.has_permission(auth.uid(), 'eleves', 'voir')
    )
  );

-- ECRITURE — rattacher un enfant a un parent est un acte d'INSCRIPTION. Il
--  appartient a l'ecole, jamais a la famille.
drop policy if exists parent_student_insert on public.parent_student;
create policy parent_student_insert on public.parent_student
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'eleves', 'ajouter')
  );

drop policy if exists parent_student_update on public.parent_student;
create policy parent_student_update on public.parent_student
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'eleves', 'modifier')
  )
  with check (public.is_member_of(school_id));

drop policy if exists parent_student_delete on public.parent_student;
create policy parent_student_delete on public.parent_student
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'eleves', 'supprimer')
  );

-- ============================================================================
--  2) CLASSES, MATIERES, COURS
--  Tout le monde LIT (un eleve doit voir sa classe et ses matieres) ; seule
--  l'administration ECRIT.
-- ============================================================================
--  NB : `execute` ne lance qu'UNE instruction a la fois — d'ou un appel par
--  policy plutot qu'un seul bloc.
do $$
declare t text;
begin
  foreach t in array array['classes', 'subjects', 'courses'] loop
    execute format('drop policy if exists tenant_isolation on public.%I', t);

    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format(
      'create policy %I on public.%I for select to authenticated '
      'using (public.is_member_of(school_id))', t || '_read', t);

    execute format('drop policy if exists %I on public.%I', t || '_insert', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated '
      'with check (public.is_member_of(school_id) '
      '  and public.has_permission(auth.uid(), ''classes'', ''creer''))',
      t || '_insert', t);

    execute format('drop policy if exists %I on public.%I', t || '_update', t);
    execute format(
      'create policy %I on public.%I for update to authenticated '
      'using (public.is_member_of(school_id) '
      '  and public.has_permission(auth.uid(), ''classes'', ''modifier'')) '
      'with check (public.is_member_of(school_id))',
      t || '_update', t);

    execute format('drop policy if exists %I on public.%I', t || '_delete', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated '
      'using (public.is_member_of(school_id) '
      '  and public.has_permission(auth.uid(), ''classes'', ''supprimer''))',
      t || '_delete', t);
  end loop;
end $$;

-- ============================================================================
--  3) EMPLOI DU TEMPS
--  L'eleve le consulte, l'administration le construit.
-- ============================================================================
drop policy if exists tenant_isolation on public.schedules;

drop policy if exists schedules_read on public.schedules;
create policy schedules_read on public.schedules
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists schedules_write on public.schedules;
create policy schedules_write on public.schedules
  for all to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'emploi_du_temps', 'modifier')
  )
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'emploi_du_temps', 'modifier')
  );

-- ============================================================================
--  4) DEVOIRS
--  Le prof donne un devoir dans SES classes. L'eleve le lit, il ne l'ecrit pas.
--  (Meme raisonnement que les notes : la permission NE SUFFIT PAS, il faut aussi
--   le perimetre.)
-- ============================================================================
drop policy if exists tenant_isolation on public.assignments;

drop policy if exists assignments_read on public.assignments;
create policy assignments_read on public.assignments
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists assignments_write on public.assignments;
create policy assignments_write on public.assignments
  for all to authenticated
  using (
    public.is_member_of(school_id)
    and (
      (public.get_my_role()::text = 'teacher'
       and public.teaches_class(auth.uid(), class_id))
      or (public.get_my_role()::text <> 'teacher'
          and public.has_permission(auth.uid(), 'classes', 'modifier'))
    )
  )
  with check (
    public.is_member_of(school_id)
    and (
      (public.get_my_role()::text = 'teacher'
       and public.teaches_class(auth.uid(), class_id))
      or (public.get_my_role()::text <> 'teacher'
          and public.has_permission(auth.uid(), 'classes', 'modifier'))
    )
  );

-- ============================================================================
--  5) REMISES DE DEVOIRS
--  C'est la SEULE table ou l'eleve ecrit legitimement : il rend son travail.
--  Mais il ne rend que le SIEN, et il ne le corrige pas apres coup.
-- ============================================================================
drop policy if exists tenant_isolation on public.submissions;

drop policy if exists submissions_read on public.submissions;
create policy submissions_read on public.submissions
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or public.is_my_child(auth.uid(), student_id)
      or public.has_permission(auth.uid(), 'notes', 'voir')
      or (public.get_my_role()::text = 'teacher'
          and exists (select 1 from public.assignments a
                       where a.id = assignment_id
                         and public.teaches_class(auth.uid(), a.class_id)))
    )
  );

--  L'eleve rend SON devoir, sous SON nom.
drop policy if exists submissions_insert on public.submissions;
create policy submissions_insert on public.submissions
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or public.has_permission(auth.uid(), 'notes', 'saisir')
    )
  );

--  La CORRECTION appartient au prof (note, appreciation). L'eleve ne revient pas
--  sur une copie rendue : ce serait la corriger apres avoir vu la note.
drop policy if exists submissions_update on public.submissions;
create policy submissions_update on public.submissions
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'notes', 'saisir')
      or (public.get_my_role()::text = 'teacher'
          and exists (select 1 from public.assignments a
                       where a.id = assignment_id
                         and public.teaches_class(auth.uid(), a.class_id)))
    )
  )
  with check (public.is_member_of(school_id));

drop policy if exists submissions_delete on public.submissions;
create policy submissions_delete on public.submissions
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'supprimer')
  );

-- ============================================================================
--  RESTE OUVERT — a traiter ensuite, pour que ce soit ECRIT quelque part :
--    messages, announcements        (un eleve peut ecrire au nom d'un autre)
--    bibliotheque, course_materials, exam_subjects, library_favorites,
--    reading_progress               (contenu pedagogique — risque faible)
--    school_branches / school_series / school_classes / school_founders
--    subscriptions, plans, plan_prices  (le prochain chantier)
-- ============================================================================

-- ============================================================================
--  VERIFICATION :
--
--    -- un eleve ne peut plus se declarer parent d'un camarade :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'student' limit 1),
--      'eleves', 'ajouter');          -- attendu : false
--
--    -- ni supprimer une classe :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'student' limit 1),
--      'classes', 'supprimer');       -- attendu : false
--
--    -- le prof donne toujours des devoirs dans ses classes :
--    select u.full_name, public.teaches_class(u.auth_uid, c.id)
--      from public.users u
--      join public.classes c on c.main_teacher_id = u.id
--     where u.role::text = 'teacher';
--    -- attendu : true
-- ============================================================================
