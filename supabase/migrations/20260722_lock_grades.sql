-- ============================================================================
--  20260722_lock_grades.sql — Verrouiller les NOTES, pour de vrai
--
--  Etat avant : `grades` n'avait qu'UNE policy.
--
--      grades   ALL   tenant_isolation   is_member_of(school_id)
--
--  Traduction : toute personne membre de l'ecole peut lire, creer, modifier et
--  supprimer N'IMPORTE QUELLE note.
--
--  Un ELEVE est membre de son ecole. Il pouvait donc modifier ses propres notes.
--  Pas en trichant, pas en piratant : la base l'y autorisait. Il suffisait
--  d'appeler l'API directement au lieu de passer par l'application.
--
--  Cette policy faisait de l'ISOLATION entre ecoles (l'ecole A ne voit pas les
--  donnees de l'ecole B) — et ca, ca marchait. Mais AUCUNE autorisation a
--  l'interieur d'une ecole. C'est le vrai sens de « les permissions sont
--  decoratives » : ce n'est pas seulement que cocher une case ne fait rien, c'est
--  que rien ne protege quoi que ce soit.
--
--  Ci-dessous : la lecture reste large mais cadree, l'ecriture exige la
--  permission ET le perimetre.
-- ============================================================================

-- ── Helpers ─────────────────────────────────────────────────────────────────

-- La ligne `users` de la personne connectee (≠ auth.uid()).
create or replace function public.my_user_id()
returns uuid
language sql stable security definer
set search_path = public
as $fn$
  select id from public.users where auth_uid = auth.uid() limit 1;
$fn$;

-- Ce prof enseigne-t-il dans cette classe ?
--
-- Trois sources, et aucune n'est fiable seule :
--   • teacher_classes      : l'affectation explicite ;
--   • classes.main_teacher : l'instituteur du primaire, titulaire de sa classe,
--                            souvent sans affectation par matiere ;
--   • schedules            : le specialiste du college/lycee, connu par son
--                            emploi du temps.
create or replace function public.teaches_class(uid uuid, p_class_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.teacher_classes tc
     join public.users u on u.id = tc.teacher_id
    where u.auth_uid = uid and tc.class_id = p_class_id
  )
  or exists (
    select 1 from public.classes c
     join public.users u on u.id = c.main_teacher_id
    where u.auth_uid = uid and c.id = p_class_id
  )
  or exists (
    select 1 from public.schedules s
     join public.users u on u.id = s.teacher_id
    where u.auth_uid = uid and s.class_id = p_class_id
  );
$fn$;

-- Cet eleve est-il mon enfant ?
create or replace function public.is_my_child(uid uuid, p_student_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.parent_student ps
     join public.users u on u.id = ps.parent_id
    where u.auth_uid = uid and ps.student_id = p_student_id
  );
$fn$;

-- ── Policies ────────────────────────────────────────────────────────────────

drop policy if exists tenant_isolation on public.grades;

-- LECTURE ------------------------------------------------------------------
--  L'eleve voit SES notes. Le parent celles de ses enfants. Le prof celles de
--  SES classes (et pas celles du voisin). Le personnel autorise voit l'ecole.
drop policy if exists grades_read on public.grades;
create policy grades_read on public.grades
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or public.is_my_child(auth.uid(), student_id)
      or (public.get_my_role()::text = 'teacher'
          and public.teaches_class(auth.uid(), class_id))
      or (public.get_my_role()::text <> 'teacher'
          and public.has_permission(auth.uid(), 'notes', 'voir'))
    )
  );

-- SAISIE -------------------------------------------------------------------
--  Un prof ne saisit que dans SES classes. Le personnel autorise (adjoint,
--  direction) saisit partout dans l'ecole.
drop policy if exists grades_insert on public.grades;
create policy grades_insert on public.grades
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'saisir')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_class(auth.uid(), class_id)
    )
  );

-- MODIFICATION -------------------------------------------------------------
drop policy if exists grades_update on public.grades;
create policy grades_update on public.grades
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'modifier')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_class(auth.uid(), class_id)
    )
  )
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'modifier')
    and (
      public.get_my_role()::text <> 'teacher'
      or public.teaches_class(auth.uid(), class_id)
    )
  );

-- SUPPRESSION --------------------------------------------------------------
--  Volontairement plus stricte : `notes.supprimer` n'est accorde ni a
--  l'Enseignant ni au Surveillant dans les modeles. Effacer une note doit rester
--  un acte de direction.
drop policy if exists grades_delete on public.grades;
create policy grades_delete on public.grades
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'notes', 'supprimer')
  );

-- ============================================================================
--  VERIFICATION (a lancer apres) — chaque ligne doit dire ce qu'on attend :
--
--    -- un eleve ne peut plus modifier ses notes :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'student' limit 1),
--      'notes', 'modifier');           -- attendu : false
--
--    -- un prof le peut :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'teacher' limit 1),
--      'notes', 'modifier');           -- attendu : true
--
--    -- le chef d'etablissement aussi :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'admin' limit 1),
--      'notes', 'modifier');           -- attendu : true
-- ============================================================================
