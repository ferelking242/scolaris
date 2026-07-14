-- ============================================================================
--  20260724_lock_users.sql — Verrouiller les COMPTES et les FICHES ELEVES
--
--  Le pire trou de la base, pire encore que les notes.
--
--  Etat avant :
--      users              ALL   tenant_isolation   is_member_of(school_id)
--      student_profiles   ALL   tenant_isolation   is_member_of(school_id)
--
--  Un eleve est membre de son ecole. Il pouvait donc, en appelant l'API
--  directement :
--    • se donner   role = 'admin'         → tout le tableau de bord de direction
--    • se donner   permissions = [...]    → tous les acces
--    • se rattacher a un staff_role_id    → les droits du chef d'etablissement
--    • supprimer   n'importe quel compte  → y compris celui du directeur
--    • changer     son school_id          → passer dans une AUTRE ecole
--
--  Ce n'est pas une faille a exploiter : c'est le comportement documente de la
--  policy. « Tout membre peut tout faire sur cette table. »
--
--  ── Pourquoi une policy ne suffit PAS ici ──────────────────────────────────
--
--  Une personne doit pouvoir modifier SA fiche (telephone, nom). Mais pas sa
--  colonne `role`. Or une policy RLS ne sait pas comparer l'ancienne et la
--  nouvelle valeur d'une colonne : `USING` ne voit que l'ancienne ligne,
--  `WITH CHECK` que la nouvelle. Impossible d'y ecrire « role n'a pas change ».
--
--  D'ou deux etages :
--    1. les policies disent QUI peut ecrire sur la ligne ;
--    2. un declencheur dit QUELLES COLONNES chacun a le droit de bouger.
-- ============================================================================

-- ── 1. Policies sur `users` ─────────────────────────────────────────────────

drop policy if exists tenant_isolation on public.users;

-- LECTURE — inchangee : l'annuaire de l'ecole reste visible a ses membres.
--  (Restreindre qui voit quoi dans l'annuaire est un autre sujet, de
--  confidentialite et non de securite : on ne le traite pas ici.)
drop policy if exists users_read on public.users;
create policy users_read on public.users
  for select to authenticated
  using (public.is_member_of(school_id));

-- CREATION — reservee a qui a le droit d'inscrire.
--  L'application cree des lignes `users` sans compte de connexion : une fiche
--  eleve, une fiche parent. C'est different de l'INSCRIPTION d'une ecole, ou du
--  premier compte : ceux-la passent par le declencheur `handle_new_user`, qui
--  est `security definer` et ne voit donc pas la RLS. Ce verrou ne les casse pas.
drop policy if exists users_insert on public.users;
create policy users_insert on public.users
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'eleves', 'ajouter')
      or public.has_permission(auth.uid(), 'utilisateurs', 'creer')
    )
  );

-- MODIFICATION — sa propre fiche, ou celle des autres si on en a le droit.
--  Ce que chacun peut y CHANGER est decide plus bas, par le declencheur.
drop policy if exists users_update on public.users;
create policy users_update on public.users
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and (
      id = public.my_user_id()
      or public.has_permission(auth.uid(), 'utilisateurs', 'modifier')
      or public.has_permission(auth.uid(), 'eleves', 'modifier')
    )
  )
  with check (public.is_member_of(school_id));

-- SUPPRESSION — jamais sa propre fiche (on ne s'efface pas soi-meme par megarde).
drop policy if exists users_delete on public.users;
create policy users_delete on public.users
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and id <> public.my_user_id()
    and (
      public.has_permission(auth.uid(), 'utilisateurs', 'supprimer')
      or public.has_permission(auth.uid(), 'eleves', 'supprimer')
    )
  );

-- ── 2. Le declencheur : quelles colonnes chacun peut bouger ─────────────────
--
--  Les colonnes SENSIBLES sont celles qui donnent du pouvoir ou changent
--  d'appartenance : role, permissions, staff_role_id, school_id, status.
--  Les toucher exige `utilisateurs.gerer_roles` — le droit d'administrer les
--  comptes, que le Chef d'etablissement a et qu'un eleve n'aura jamais.
--
--  Tout le reste (nom, email, telephone, titre) reste modifiable par la
--  personne elle-meme.

create or replace function public.guard_user_privileges()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
begin
  -- auth.uid() est NULL cote serveur : Edge Function (service_role), declencheur
  -- d'inscription, script de migration. Ces chemins sont deja de confiance.
  if auth.uid() is null then
    return new;
  end if;

  if (new.role         is distinct from old.role)
  or (new.permissions  is distinct from old.permissions)
  or (new.staff_role_id is distinct from old.staff_role_id)
  or (new.school_id    is distinct from old.school_id)
  or (new.status       is distinct from old.status)
  then
    if not public.has_permission(auth.uid(), 'utilisateurs', 'gerer_roles') then
      raise exception
        'Modification refusee : seul un administrateur peut changer le role, les acces ou le statut d''un compte.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_guard_user_privileges on public.users;
create trigger trg_guard_user_privileges
  before update on public.users
  for each row execute function public.guard_user_privileges();

-- ── 3. Policies sur `student_profiles` ──────────────────────────────────────
--  La fiche scolaire : matricule, classe, date de naissance, annee scolaire.
--  Un eleve pouvait changer sa propre CLASSE — donc son emploi du temps, ses
--  notes, ses bulletins.

drop policy if exists tenant_isolation on public.student_profiles;

drop policy if exists student_profiles_read on public.student_profiles;
create policy student_profiles_read on public.student_profiles
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists student_profiles_insert on public.student_profiles;
create policy student_profiles_insert on public.student_profiles
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'eleves', 'ajouter')
  );

drop policy if exists student_profiles_update on public.student_profiles;
create policy student_profiles_update on public.student_profiles
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'eleves', 'modifier')
  )
  with check (public.is_member_of(school_id));

drop policy if exists student_profiles_delete on public.student_profiles;
create policy student_profiles_delete on public.student_profiles
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'eleves', 'supprimer')
  );

-- ============================================================================
--  VERIFICATION — un eleve ne doit RIEN pouvoir :
--
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'student' limit 1),
--      'utilisateurs', 'gerer_roles');     -- attendu : false
--
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'student' limit 1),
--      'eleves', 'modifier');              -- attendu : false
--
--  Et le chef d'etablissement, tout :
--    select public.has_permission(
--      (select auth_uid from public.users where role::text = 'admin' limit 1),
--      'utilisateurs', 'gerer_roles');     -- attendu : true
-- ============================================================================
