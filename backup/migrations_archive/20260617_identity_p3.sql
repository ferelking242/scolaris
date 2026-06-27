-- ============================================================
-- SCOLARIS — PASSE 3 : consolidation de l'identite sur `users`
-- A relire PUIS exécuter dans : Supabase Dashboard > SQL Editor.
-- ⚠️ Exécuter APRES avoir déployé le nouveau code (l'app ne lit plus `students`)
--    et AVANT/AVEC le seed propre 20260617_seed_clean.sql.
--
-- Decision (cf. discussion) : `users` devient LA table unique des personnes
-- (1 ligne/humain, role student/teacher/parent/admin). Les fiches metier vivent
-- dans student_profiles / teacher_profiles. On supprime les 2 tables doublons
-- d'identite : `profiles` et `students`.
--
-- ⚠️ DESTRUCTIF & IRREVERSIBLE. Backup avant. Idempotent (IF EXISTS).
-- ============================================================

begin;

-- 1) Repointer vers public.users les FK qui visaient public.profiles.
--    (verifie : tous les profiles.id existent deja dans users.id => sans perte)
alter table public.invoices       drop constraint if exists invoices_student_id_fkey;
alter table public.invoices       add  constraint invoices_student_id_fkey
      foreign key (student_id) references public.users(id);

alter table public.attendance     drop constraint if exists attendance_student_id_fkey;
alter table public.attendance     add  constraint attendance_student_id_fkey
      foreign key (student_id) references public.users(id);

alter table public.payments       drop constraint if exists payments_student_id_fkey;
alter table public.payments       add  constraint payments_student_id_fkey
      foreign key (student_id) references public.users(id);

alter table public.courses        drop constraint if exists courses_teacher_id_fkey;
alter table public.courses        add  constraint courses_teacher_id_fkey
      foreign key (teacher_id) references public.users(id);

alter table public.school_classes drop constraint if exists school_classes_teacher_id_fkey;
alter table public.school_classes add  constraint school_classes_teacher_id_fkey
      foreign key (teacher_id) references public.users(id);

-- 2) Supprimer les deux tables doublons d'identite.
--    Plus aucune FK ne les vise apres l'etape 1 ; CASCADE par securite.
drop table if exists public.students cascade;
drop table if exists public.profiles cascade;

-- 3) Trigger d'inscription : ne plus ecrire dans profiles (table supprimee).
--    Cree uniquement la ligne `users` a partir des metadonnees du signUp.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_school uuid;
  v_role   text;
  v_name   text;
begin
  v_school := nullif(new.raw_user_meta_data->>'school_id', '')::uuid;
  v_role   := coalesce(nullif(new.raw_user_meta_data->>'role', ''), 'student');
  v_name   := coalesce(nullif(new.raw_user_meta_data->>'full_name', ''),
                       split_part(new.email, '@', 1));

  if v_school is not null then
    insert into public.users (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
    values (new.id, v_school, new.id, v_name, new.email, v_role::public.user_role, 'active', now(), now())
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$;

-- (le trigger on_auth_user_created pointe deja sur cette fonction, rien a recreer)

commit;

-- ============================================================
-- Resultat : 32 -> 30 tables. Identite = users (+ student_profiles /
-- teacher_profiles / user_settings / parent_student en extensions).
-- Toutes les FK *.student_id pointent desormais vers users.id.
-- Lancer ensuite 20260617_seed_clean.sql pour une demo coherente.
-- ============================================================
