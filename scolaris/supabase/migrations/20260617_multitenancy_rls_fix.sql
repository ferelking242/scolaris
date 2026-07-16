-- ============================================================
-- SCOLARIS — Multi-tenancy RLS : CORRECTIF (ménage des policies parasites)
-- A relire PUIS exécuter dans : Supabase Dashboard > SQL Editor.
--
-- Probleme detecte au test : certaines tables (ex. `classes`, `schools`) avaient
-- d'ANCIENNES policies permissives (`using(true)`) heritees des debuts du projet.
-- Comme les policies RLS se cumulent en OU, elles ANNULAIENT l'isolation par
-- ecole (un admin EAD voyait les 115 classes de toutes les ecoles).
--
-- Ce script efface TOUTES les policies de chaque table tenant, puis recree
-- uniquement : (1) l'isolation par ecole, (2) les policies d'inscription anon
-- necessaires au parcours self-service. Resultat = etat propre et deterministe.
--
-- Remplace/complete 20260617_multitenancy_rls.sql. Idempotent. Backup conseille.
-- ============================================================

-- Fonction school_id courant (recreee au cas ou).
create or replace function public.current_school_id()
returns uuid language sql stable security definer set search_path = public
as $$ select school_id from public.users where auth_uid = auth.uid() limit 1; $$;
grant execute on function public.current_school_id() to anon, authenticated;

-- 1) Effacer TOUTES les policies existantes sur chaque table tenant.
do $$
declare
  r record;
  t text;
  tenant text[] := array[
    'absences','announcement_comments','announcement_likes','announcements',
    'assignments','classes','courses','exams','filieres','grades','invoices',
    'messages','parent_student','resources','school_branches','school_classes',
    'school_founders','school_series','student_profiles','subjects','submissions',
    'teacher_classes','teacher_profiles','user_settings','users',
    'schools','attendance','payments','bibliotheque'
  ];
begin
  -- effacer toutes les policies existantes sur ces tables
  for r in
    select tablename, policyname from pg_policies
    where schemaname = 'public' and tablename = any(tenant)
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;

  -- s'assurer que la RLS est active partout
  foreach t in array tenant loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- 2) Isolation par ecole sur les tables a school_id direct.
do $$
declare
  t text;
  tables text[] := array[
    'absences','announcement_comments','announcement_likes','announcements',
    'assignments','classes','courses','exams','filieres','grades','invoices',
    'messages','parent_student','resources','school_branches','school_classes',
    'school_founders','school_series','student_profiles','subjects','submissions',
    'teacher_classes','teacher_profiles','user_settings','users'
  ];
begin
  foreach t in array tables loop
    execute format(
      'create policy tenant_isolation on public.%I for all to authenticated '
      'using (school_id = public.current_school_id()) '
      'with check (school_id = public.current_school_id())', t);
  end loop;
end $$;

-- 3) Tables a rattachement indirect.
create policy tenant_isolation on public.schools for all to authenticated
  using (id = public.current_school_id())
  with check (id = public.current_school_id());

create policy tenant_isolation on public.attendance for all to authenticated
  using (exists (select 1 from public.classes c
                 where c.id = attendance.class_id and c.school_id = public.current_school_id()))
  with check (exists (select 1 from public.classes c
                      where c.id = attendance.class_id and c.school_id = public.current_school_id()));

create policy tenant_isolation on public.payments for all to authenticated
  using (exists (select 1 from public.users u
                 where u.id = payments.student_id and u.school_id = public.current_school_id()))
  with check (exists (select 1 from public.users u
                      where u.id = payments.student_id and u.school_id = public.current_school_id()));

-- 4) Catalogue partage : bibliotheque (lecture pour tout connecte).
create policy shared_read on public.bibliotheque for select to authenticated using (true);

-- 5) Inscription self-service : INSERT anon sur les tables creees a l'inscription.
--    (re-cree apres le grand menage de l'etape 1)
create policy inscription_insert on public.schools         for insert to anon, authenticated with check (true);
create policy inscription_insert on public.school_branches for insert to anon, authenticated with check (true);
create policy inscription_insert on public.school_founders for insert to anon, authenticated with check (true);
create policy inscription_insert on public.school_series   for insert to anon, authenticated with check (true);
create policy inscription_insert on public.school_classes  for insert to anon, authenticated with check (true);

-- ============================================================
-- Apres execution : un admin EAD ne doit voir QUE les classes/élèves/etc. EAD.
-- (class_levels reste un catalogue public de reference, inchangé.)
-- ============================================================
