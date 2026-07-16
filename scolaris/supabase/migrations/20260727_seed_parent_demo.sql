-- ============================================================================
--  20260727_seed_parent_demo.sql — Un compte PARENT de demonstration
--
--  ── Pourquoi ────────────────────────────────────────────────────────────────
--  Les 16 comptes de demo (ecran de connexion) ne comptent AUCUN parent. Or
--  tout l'espace parent repose sur la table `parent_student` : sans un parent
--  reellement rattache a un enfant, l'app affiche « Aucun enfant rattache » et
--  rien n'est testable — ni la fiche enfant, ni le cahier de liaison, ni la
--  signature, ni les recompenses.
--
--  On cree donc UNE mere, rattachee a une eleve du PRIMAIRE :
--
--      Pauline Moukoko   parent.elc@elc.cg / demo1234
--        └─ mere de Alice Moukoko (CM2 A · Ecole Lumiere du Congo)
--
--  Le primaire est le bon choix : c'est le cycle ou le parent est l'utilisateur
--  principal, et c'est la que vivent le cahier de liaison et les recompenses.
--  Alice est deja en CM2 A, la classe de Jean Ngoubili — le prof qui peut
--  desormais ecrire dans le cahier (cf. 20260725).
--
--  ── Le piege du trigger ─────────────────────────────────────────────────────
--  `on_auth_user_created` (20260616) cree la ligne public.users AUTOMATIQUEMENT
--  si `raw_user_meta_data` contient un `school_id`… mais il insere AUSSI dans
--  `public.profiles`, une table qui n'existe PLUS (supprimee du schema).
--  ⇒ L'insertion auth echouerait.
--
--  On cree donc le compte auth SANS metadonnees d'ecole (le trigger ne fait
--  rien), puis on insere la ligne `users` a la main.
--
--  Idempotent. Rejouable.
-- ============================================================================

-- ── Prealable : un lien parent-enfant est UNIQUE ────────────────────────────
--  `parent_student` n'avait aucune contrainte d'unicite sur (parent, enfant) :
--  sa seule cle est `id`, alimentee par gen_random_uuid(). Un `on conflict do
--  nothing` ne s'y declenche donc JAMAIS — rejouer ce script aurait rattache
--  Pauline a Alice une seconde fois, et l'espace parent aurait affiche Alice en
--  double.
--
--  Le defaut depasse le seed : `createOrLinkGuardian` (cote app) fait le meme
--  insert. Deux clics sur « Ajouter un parent » suffisaient a dupliquer le lien.
--  On pose la contrainte qui manquait — apres avoir nettoye les doublons deja
--  crees, s'il y en a.
delete from public.parent_student a
 using public.parent_student b
 where a.parent_id = b.parent_id
   and a.student_id = b.student_id
   and a.ctid > b.ctid;          -- on garde la plus ancienne ligne

create unique index if not exists parent_student_unique_link
  on public.parent_student (parent_id, student_id);

do $$
declare
  v_parent_uid uuid := 'd0000000-0000-4000-8000-00000000e1c1'; -- fixe = rejouable
  v_alice_id   uuid;
  v_school_id  uuid;
begin
  -- 1) L'eleve a rattacher, et son ecole. On resout par EMAIL : les ids des
  --    comptes de demo ne sont pas dans le depot.
  select u.id, u.school_id
    into v_alice_id, v_school_id
    from public.users u
   where u.email = 'alice.moukoko@elc.cg'
     and u.role::text = 'student'
   limit 1;

  if v_alice_id is null then
    raise exception 'Eleve alice.moukoko@elc.cg introuvable — verifier le seed de demo.';
  end if;

  -- 2) Le compte d'authentification. Pas de school_id dans les metadonnees :
  --    voir « le piege du trigger » ci-dessus.
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_parent_uid,
    'authenticated', 'authenticated',
    'parent.elc@elc.cg',
    crypt('demo1234', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Pauline Moukoko"}',
    now(), now(), '', '', '', ''
  )
  on conflict (id) do nothing;

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_parent_uid, v_parent_uid::text,
    format('{"sub":"%s","email":"parent.elc@elc.cg"}', v_parent_uid)::jsonb,
    'email', now(), now(), now()
  )
  on conflict do nothing;

  -- 3) La fiche (public.users). L'id = l'auth_uid, comme partout ailleurs.
  insert into public.users
    (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
  values
    (v_parent_uid, v_school_id, v_parent_uid, 'Pauline Moukoko',
     'parent.elc@elc.cg', 'parent', 'active', now(), now())
  on conflict (id) do nothing;

  -- 4) L'adhesion a l'ecole. SANS elle, `is_member_of()` renvoie false et la
  --    RLS bloque TOUT : le parent se connecterait sur un espace vide.
  insert into public.school_members (user_id, school_id, role, status)
  values (v_parent_uid, v_school_id, 'parent', 'active')
  on conflict (user_id, school_id) do nothing;

  -- 5) LE lien qui fait tout marcher : mere -> enfant.
  insert into public.parent_student
    (id, school_id, parent_id, student_id, relationship, is_primary, created_at)
  values
    (gen_random_uuid(), v_school_id, v_parent_uid, v_alice_id, 'mere', true, now())
  on conflict (parent_id, student_id) do nothing;   -- cf. l'index pose plus haut

  raise notice 'OK — Pauline Moukoko (parent.elc@elc.cg) rattachee a Alice Moukoko.';
end $$;

-- ============================================================================
--  VERIFICATION (a lancer apres) :
--
--    select p.full_name as parent, p.email,
--           e.full_name as enfant, ps.relationship
--      from public.parent_student ps
--      join public.users p on p.id = ps.parent_id
--      join public.users e on e.id = ps.student_id;
--    -- attendu : Pauline Moukoko → Alice Moukoko (mere) — UNE seule ligne,
--    --           meme apres plusieurs rejeux du script.
--
--    -- L'adhesion existe (sinon la RLS bloque tout) :
--    select status from public.school_members
--     where user_id = 'd0000000-0000-4000-8000-00000000e1c1';
--    -- attendu : active
--
--  Puis dans l'app : parent.elc@elc.cg / demo1234
-- ============================================================================

-- ============================================================================
--  ROLLBACK
--
--    delete from public.parent_student where parent_id = 'd0000000-0000-4000-8000-00000000e1c1';
--    delete from public.school_members  where user_id   = 'd0000000-0000-4000-8000-00000000e1c1';
--    delete from public.users           where id        = 'd0000000-0000-4000-8000-00000000e1c1';
--    delete from auth.identities        where user_id   = 'd0000000-0000-4000-8000-00000000e1c1';
--    delete from auth.users             where id        = 'd0000000-0000-4000-8000-00000000e1c1';
--
--  (L'index `parent_student_unique_link` est CONSERVE : il corrige un defaut
--   reel de l'application, il ne fait pas partie du jeu de demonstration.)
-- ============================================================================
