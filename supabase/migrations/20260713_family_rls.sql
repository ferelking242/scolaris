-- ============================================================================
-- SCOLARIS — Cloisonnement FAMILLE (parent / élève)
-- À RELIRE puis exécuter dans : Supabase Dashboard > SQL Editor.
-- Idempotent (drop policy if exists / create or replace). Rejouable.
--
-- PROBLÈME CORRIGÉ
--   La policy `tenant_isolation` (20260706_school_members.sql) dit :
--       for all to authenticated using (public.is_member_of(school_id))
--   → elle isole les ÉCOLES entre elles, mais n'isole PERSONNE à l'intérieur
--     d'une école. Un parent (ou un élève), étant membre de son école, peut
--     donc lire TOUS les élèves, TOUTES les notes, TOUTES les factures de
--     l'établissement — et, `for all` + `with check` obligent, potentiellement
--     les ÉCRIRE (modifier une note, p. ex.).
--
-- APPROCHE
--   On ne touche PAS à `tenant_isolation` (rollback simple, staff/profs
--   inchangés). On ajoute des policies **RESTRICTIVE**, qui se combinent en ET
--   avec l'existante : il faut désormais satisfaire l'isolation école ET
--   l'isolation famille. Les comptes non-familiaux (admin, staff, enseignant)
--   passent au travers sans changement.
--
-- ⚠️ Tester d'abord sur une base de staging si possible. Vérifications
--    suggérées après exécution : voir le bloc « TESTS » en fin de fichier.
--
-- ROLLBACK : voir le bloc « ROLLBACK » en fin de fichier.
-- ============================================================================

-- ── 1) Helpers d'identité ───────────────────────────────────────────────────
-- SECURITY DEFINER : lisent `users`/`parent_student` sans être bloqués par la
-- RLS de ces tables (sinon récursion infinie sur leurs propres policies).

-- L'id de profil (public.users.id) de l'utilisateur connecté.
create or replace function public.my_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.users where auth_uid = auth.uid() limit 1;
$$;

-- Le rôle applicatif de l'utilisateur connecté, en texte minuscule.
-- (`users.role` est un ENUM `user_role` → le cast est obligatoire.)
create or replace function public.my_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(role::text) from public.users where auth_uid = auth.uid() limit 1;
$$;

-- Compte « familial » = parent ou élève. Ce sont les seuls qu'on restreint.
create or replace function public.is_family_account()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.my_role() in ('student', 'parent'), false);
$$;

-- :sid est-il un enfant du parent connecté ?
create or replace function public.is_my_child(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.parent_student ps
    where ps.parent_id  = public.my_user_id()
      and ps.student_id = sid
  );
$$;

-- Le connecté a-t-il le droit de voir les données de l'élève :sid ?
--   • admin / staff / enseignant  → oui (inchangé, l'isolation école suffit)
--   • élève                       → uniquement lui-même
--   • parent                      → uniquement ses enfants
-- NULL (ligne sans student_id) → on laisse passer : la ligne n'est pas
-- nominative, `tenant_isolation` la couvre déjà.
create or replace function public.can_see_student(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when sid is null                then true
    when not public.is_family_account() then true
    when public.my_role() = 'student'   then sid = public.my_user_id()
    when public.my_role() = 'parent'    then public.is_my_child(sid)
    else false
  end;
$$;

grant execute on function public.my_user_id()          to authenticated;
grant execute on function public.my_role()             to authenticated;
grant execute on function public.is_family_account()   to authenticated;
grant execute on function public.is_my_child(uuid)     to authenticated;
grant execute on function public.can_see_student(uuid) to authenticated;

-- ── 2) Tables nominatives : lecture limitée à SOI / SES ENFANTS, et LECTURE
--       SEULE pour les comptes familiaux. ─────────────────────────────────────
-- Défensif : le dépôt n'est pas la source de vérité du schéma (cf. CLAUDE.md).
-- On ne crée la policy que si la table ET la colonne `student_id` existent.
do $$
declare
  t text;
  -- Données scolaires nominatives, jamais écrites par la famille.
  tables text[] := array[
    'grades', 'absences', 'attendance', 'invoices', 'payments', 'report_cards'
  ];
begin
  foreach t in array tables loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = t
        and column_name = 'student_id'
    ) then
      raise notice 'SKIP %( : table ou colonne student_id absente)', t;
      continue;
    end if;

    execute format('alter table public.%I enable row level security', t);

    -- 2a. Portée : la ligne doit concerner soi-même / son enfant.
    execute format('drop policy if exists family_scope on public.%I', t);
    execute format(
      'create policy family_scope on public.%I as restrictive for all '
      'to authenticated '
      'using (public.can_see_student(student_id)) '
      'with check (public.can_see_student(student_id))', t);

    -- 2b. Lecture seule : un parent/élève ne crée ni ne modifie une note,
    --     une absence, une facture… (l''école seule écrit ces lignes).
    execute format('drop policy if exists family_readonly_ins on public.%I', t);
    execute format(
      'create policy family_readonly_ins on public.%I as restrictive '
      'for insert to authenticated '
      'with check (not public.is_family_account())', t);

    execute format('drop policy if exists family_readonly_upd on public.%I', t);
    execute format(
      'create policy family_readonly_upd on public.%I as restrictive '
      'for update to authenticated '
      'using (not public.is_family_account())', t);

    execute format('drop policy if exists family_readonly_del on public.%I', t);
    execute format(
      'create policy family_readonly_del on public.%I as restrictive '
      'for delete to authenticated '
      'using (not public.is_family_account())', t);

    raise notice 'OK   % (portée famille + lecture seule)', t;
  end loop;
end $$;

-- ── 3) `submissions` : cas particulier ───────────────────────────────────────
-- L'élève DOIT pouvoir déposer SON devoir → portée oui, lecture seule NON.
-- (Il ne peut ni voir ni déposer pour un autre élève. Le parent voit ceux de
--  ses enfants, en lecture — le `with check` l'empêche d'en créer.)
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'submissions'
      and column_name = 'student_id'
  ) then
    alter table public.submissions enable row level security;

    drop policy if exists family_scope on public.submissions;
    create policy family_scope on public.submissions as restrictive for all
      to authenticated
      using (public.can_see_student(student_id))
      with check (public.can_see_student(student_id));

    -- Un parent ne dépose pas le devoir à la place de son enfant.
    drop policy if exists family_no_submit on public.submissions;
    create policy family_no_submit on public.submissions as restrictive
      for insert to authenticated
      with check (coalesce(public.my_role(), '') <> 'parent');

    raise notice 'OK   submissions (portée famille, dépôt réservé à l''élève)';
  else
    raise notice 'SKIP submissions';
  end if;
end $$;

-- ── 4) `users` : ne plus exposer l'annuaire de l'école aux familles ─────────
-- Aujourd'hui un parent/élève peut lister TOUS les users de l'école (noms,
-- emails, téléphones des autres familles). On restreint aux lignes utiles :
--   • soi-même
--   • ses enfants (parent)
--   • le personnel et les enseignants  ← gardé volontairement : l'UI affiche
--     le nom du prof d'une matière, l'expéditeur d'un message, etc.
-- Effet : un parent ne voit plus les AUTRES élèves ni les AUTRES parents.
do $$
begin
  drop policy if exists family_directory_scope on public.users;
  create policy family_directory_scope on public.users as restrictive
    for select to authenticated
    using (
      not public.is_family_account()
      or id = public.my_user_id()
      or public.is_my_child(id)
      or lower(role::text) not in ('student', 'parent')
    );

  -- Une famille ne modifie que SA propre ligne (profil), pas celle d'un autre.
  drop policy if exists family_self_update on public.users;
  create policy family_self_update on public.users as restrictive
    for update to authenticated
    using (not public.is_family_account() or id = public.my_user_id());

  drop policy if exists family_no_user_insert on public.users;
  create policy family_no_user_insert on public.users as restrictive
    for insert to authenticated
    with check (not public.is_family_account());

  drop policy if exists family_no_user_delete on public.users;
  create policy family_no_user_delete on public.users as restrictive
    for delete to authenticated
    using (not public.is_family_account());

  raise notice 'OK   users (annuaire cloisonné pour les familles)';
end $$;

-- ── 5) `parent_student` : le lien lui-même ──────────────────────────────────
-- Un parent ne doit voir que SES liens (sinon il reconstitue l'annuaire des
-- familles de l'école). Et il ne s'auto-rattache évidemment pas à un enfant.
do $$
begin
  drop policy if exists family_link_scope on public.parent_student;
  create policy family_link_scope on public.parent_student as restrictive
    for all to authenticated
    using (
      not public.is_family_account()
      or parent_id  = public.my_user_id()
      or student_id = public.my_user_id()
    )
    with check (not public.is_family_account());

  raise notice 'OK   parent_student (liens cloisonnés)';
end $$;

-- ============================================================================
-- TESTS suggérés (à jouer connecté en tant que… , ou via l'app)
--
--   -- En tant que PARENT :
--   select count(*) from users where role = 'student';  -- attendu : ses enfants
--   select count(*) from grades;                        -- attendu : ceux de ses enfants
--   update grades set score = 20;                       -- attendu : 0 ligne / refusé
--
--   -- En tant qu'ÉLÈVE :
--   select count(*) from grades;                        -- attendu : SES notes
--
--   -- En tant qu'ADMIN : tout doit être INCHANGÉ (mêmes volumes qu'avant).
--
-- ⚠️ Si l'app d'un rôle non-familial se met à voir 0 ligne, c'est que
--    `users.role` de ce compte n'est pas celui attendu : vérifier
--    `select role from users where auth_uid = auth.uid()`.
-- ============================================================================

-- ============================================================================
-- ROLLBACK (annule TOUT ce script, laisse `tenant_isolation` intacte)
--
--   do $$
--   declare t text;
--   begin
--     foreach t in array array['grades','absences','attendance','invoices',
--                              'payments','report_cards','submissions'] loop
--       execute format('drop policy if exists family_scope        on public.%I', t);
--       execute format('drop policy if exists family_readonly_ins on public.%I', t);
--       execute format('drop policy if exists family_readonly_upd on public.%I', t);
--       execute format('drop policy if exists family_readonly_del on public.%I', t);
--     end loop;
--   end $$;
--   drop policy if exists family_no_submit        on public.submissions;
--   drop policy if exists family_directory_scope  on public.users;
--   drop policy if exists family_self_update      on public.users;
--   drop policy if exists family_no_user_insert   on public.users;
--   drop policy if exists family_no_user_delete   on public.users;
--   drop policy if exists family_link_scope       on public.parent_student;
-- ============================================================================
