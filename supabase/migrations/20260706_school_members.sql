-- ============================================================
-- SCOLARIS — Phase B : identité portable (adhésions multi-écoles)
-- À RELIRE puis exécuter dans : Supabase Dashboard > SQL Editor.
-- Idempotent (create if not exists / drop policy if exists). Rejouable.
--
-- Objectif : découpler l'identité (un compte) de l'école. Un prof (ou un
-- parent) peut appartenir à plusieurs écoles via la table `school_members`.
--
-- ⚠️ SÉCURITÉ : ce script réécrit la RLS de TOUTES les tables cloisonnées.
--    Grâce au backfill (étape 2), chaque utilisateur existant devient membre de
--    son école actuelle → l'accès reste IDENTIQUE à aujourd'hui pour le
--    mono-école. Le multi-école s'active uniquement quand on ajoute des
--    adhésions. Recommandé : tester d'abord sur une base de staging.
--
-- ROLLBACK : rejouer l'ancienne policy en remplaçant `public.is_member_of(school_id)`
--    par `school_id = public.current_school_id()` (cf. 20260617_multitenancy_rls.sql).
-- ============================================================

-- 1) Table des adhésions (N–N : user <-> school)
create table if not exists public.school_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  role text,
  status text not null default 'active',   -- active | pending | revoked
  created_at timestamptz not null default now(),
  unique (user_id, school_id)
);
create index if not exists school_members_user_idx   on public.school_members(user_id);
create index if not exists school_members_school_idx on public.school_members(school_id);

-- 2) Backfill : chaque utilisateur devient membre (actif) de son école actuelle.
--    => aucune perte d'accès pour l'existant.
insert into public.school_members (user_id, school_id, role, status)
select u.id, u.school_id, u.role, 'active'
from public.users u
where u.school_id is not null
on conflict (user_id, school_id) do nothing;

-- 3) Helper : l'utilisateur connecté est-il membre ACTIF de :sid ?
--    SECURITY DEFINER => lit school_members/users sans être bloqué par leur RLS
--    (évite la récursion sur la policy de `users`).
create or replace function public.is_member_of(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.school_members m
    join public.users u on u.id = m.user_id
    where u.auth_uid = auth.uid()
      and m.school_id = sid
      and m.status = 'active'
  );
$$;
grant execute on function public.is_member_of(uuid) to anon, authenticated;

-- 4) RLS de la table `school_members` : chacun lit ses propres adhésions,
--    et les membres d'une école voient les adhésions de cette école.
alter table public.school_members enable row level security;
drop policy if exists own_memberships on public.school_members;
create policy own_memberships on public.school_members for all to authenticated
  using (
    exists (select 1 from public.users u
            where u.id = school_members.user_id and u.auth_uid = auth.uid())
    or public.is_member_of(school_members.school_id)
  )
  with check (
    exists (select 1 from public.users u
            where u.id = school_members.user_id and u.auth_uid = auth.uid())
    or public.is_member_of(school_members.school_id)
  );

-- 5) Bascule des policies d'isolation :
--    AVANT : school_id = current_school_id()   (une seule école)
--    APRÈS : is_member_of(school_id)           (toutes ses écoles)
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
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists tenant_isolation on public.%I', t);
    execute format(
      'create policy tenant_isolation on public.%I for all to authenticated '
      'using (public.is_member_of(school_id)) '
      'with check (public.is_member_of(school_id))', t);
  end loop;
end $$;

-- Tables sans school_id direct (rattachement indirect) :

-- schools : on voit/gère les écoles dont on est membre.
drop policy if exists tenant_isolation on public.schools;
create policy tenant_isolation on public.schools for all to authenticated
  using (public.is_member_of(id))
  with check (public.is_member_of(id));

-- attendance : rattachée via la classe.
drop policy if exists tenant_isolation on public.attendance;
create policy tenant_isolation on public.attendance for all to authenticated
  using (exists (select 1 from public.classes c
                 where c.id = attendance.class_id and public.is_member_of(c.school_id)))
  with check (exists (select 1 from public.classes c
                      where c.id = attendance.class_id and public.is_member_of(c.school_id)));

-- payments : rattachée via l'élève.
drop policy if exists tenant_isolation on public.payments;
create policy tenant_isolation on public.payments for all to authenticated
  using (exists (select 1 from public.users u
                 where u.id = payments.student_id and public.is_member_of(u.school_id)))
  with check (exists (select 1 from public.users u
                      where u.id = payments.student_id and public.is_member_of(u.school_id)));

-- ============================================================
-- Après application :
--  • mono-école → comportement identique (backfill) ;
--  • pour tester le multi-école : insérer une adhésion supplémentaire, ex.
--      insert into public.school_members(user_id, school_id, status)
--      values ('<user_uuid>', '<autre_school_uuid>', 'active');
--    puis se reconnecter et utiliser le sélecteur d'école dans l'app.
-- ============================================================
