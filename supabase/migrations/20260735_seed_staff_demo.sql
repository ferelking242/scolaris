-- ============================================================================
--  20260735_seed_staff_demo.sql — Une COMPTABLE et un SURVEILLANT de demo
--
--  ── Pourquoi ────────────────────────────────────────────────────────────────
--  Les comptes de demo ne couvrent que l'admin, l'enseignant, l'eleve et (depuis
--  20260727) le parent. Impossible de VERIFIER que les droits fins fonctionnent :
--  il n'existe aucun compte porteur d'un role limite.
--
--  Or c'est tout l'enjeu du chantier. Sans un compte Comptable, on ne peut pas
--  constater qu'il voit la facturation mais pas les notes. Sans un Surveillant,
--  qu'il saisit les presences mais ne supprime pas une absence.
--
--      Sylvie Bakala    comptable.elc@elc.cg    / demo1234   → role Comptable
--      Andre Mabiala    surveillant.elc@elc.cg  / demo1234   → role Surveillant
--
--  Les deux a l'Ecole Lumiere du Congo, comme le reste du jeu de demo.
--
--  ── Le piege du trigger (repris de 20260727) ────────────────────────────────
--  `on_auth_user_created` cree la ligne public.users automatiquement SI
--  `raw_user_meta_data` contient un `school_id`… mais il insere AUSSI dans
--  `public.profiles`, une table SUPPRIMEE. L'insertion auth echouerait.
--  On cree donc le compte auth SANS metadonnees d'ecole, puis la ligne `users`
--  a la main.
--
--  ── Le role vient du MODELE, pas d'une liste de droits ecrite ici ───────────
--  On ne recopie pas les permissions : on cree (ou reutilise) le role de l'ecole
--  issu du modele commun, et on rattache la personne. C'est exactement ce que
--  fait l'application quand l'admin invite quelqu'un. Si le directeur modifie
--  ensuite le role Comptable, Sylvie suit — c'est le principe meme.
--
--  Idempotent. Rejouable.
-- ============================================================================

do $$
declare
  v_school_id uuid;
  m record;
  v_role_id   uuid;
begin
  -- L'ecole de demo, resolue par un compte connu (les ids ne sont pas au depot).
  select u.school_id into v_school_id
    from public.users u
   where u.email = 'alice.moukoko@elc.cg'
   limit 1;

  if v_school_id is null then
    raise exception 'Ecole de demo introuvable — verifier le seed.';
  end if;

  for m in
    select * from (values
      ('d0000000-0000-4000-8000-00000000c0c1'::uuid,
       'comptable.elc@elc.cg',   'Sylvie Bakala', 'Comptable'),
      ('d0000000-0000-4000-8000-00000000d0d1'::uuid,
       'surveillant.elc@elc.cg', 'André Mabiala', 'Surveillant')
    ) as t(uid, email, full_name, role_name)
  loop
    -- 1) Le compte d'authentification.
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      m.uid, 'authenticated', 'authenticated',
      m.email,
      crypt('demo1234', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('full_name', m.full_name),
      now(), now(), '', '', '', ''
    )
    on conflict (id) do nothing;

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), m.uid, m.uid::text,
      jsonb_build_object('sub', m.uid::text, 'email', m.email),
      'email', now(), now(), now()
    )
    on conflict do nothing;

    -- 2) Le ROLE de l'ecole, cree depuis le modele commun s'il n'existe pas
    --    encore. Ses permissions viennent du modele : on ne les recopie pas ici.
    --  `role_templates` n'a pas de colonne is_admin_role : ni la Comptable ni le
    --  Surveillant ne sont administrateurs, c'est donc `false` — et c'est bien
    --  le but, un role qui court-circuiterait tout ne testerait rien.
    insert into public.staff_roles
      (school_id, name, description, is_admin_role, based_on_template_id,
       level, color, icon_key)
    select v_school_id, t.name, t.description, false, t.id,
           t.level, t.color, t.icon_key
      from public.role_templates t
     where t.cycle = 'commun' and t.name = m.role_name
    on conflict (school_id, name) do nothing;

    select r.id into v_role_id
      from public.staff_roles r
     where r.school_id = v_school_id and r.name = m.role_name;

    insert into public.staff_role_permissions
      (staff_role_id, permission_key, sub_permission_key)
    select v_role_id, tp.permission_key, tp.sub_permission_key
      from public.role_templates t
      join public.role_template_permissions tp on tp.role_template_id = t.id
     where t.cycle = 'commun' and t.name = m.role_name
    on conflict do nothing;

    -- 3) La fiche. `users.role` = 'staff_custom' : c'est l'ESPACE qu'elle voit
    --    (le tableau de bord d'administration). Ce qu'elle a le DROIT d'y faire
    --    vient du role ci-dessus. Deux questions differentes, deux mecanismes.
    insert into public.users
      (id, school_id, auth_uid, full_name, email, role, role_title,
       staff_role_id, permissions, status, created_at, updated_at)
    values
      (m.uid, v_school_id, m.uid, m.full_name, m.email,
       'staff_custom', m.role_name, v_role_id,
       public.legacy_permissions_of_role(v_role_id),
       'active', now(), now())
    on conflict (id) do update set
      staff_role_id = excluded.staff_role_id,
      role_title    = excluded.role_title,
      permissions   = excluded.permissions;

    -- 4) L'adhesion. SANS elle, is_member_of() renvoie false et la RLS bloque
    --    TOUT : la personne se connecterait sur un espace vide.
    insert into public.school_members (user_id, school_id, role, status)
    values (m.uid, v_school_id, 'staff_custom', 'active')
    on conflict (user_id, school_id) do nothing;

    raise notice 'OK — % (%) → role %', m.full_name, m.email, m.role_name;
  end loop;
end $$;

-- ============================================================================
--  VERIFICATION — LE test qui compte, celui des droits FINS :
--
--    select u.full_name, r.name as role,
--           public.has_permission(u.auth_uid, 'comptabilite', 'enregistrer_paiement') as encaisse,
--           public.has_permission(u.auth_uid, 'notes',        'modifier')             as modifie_notes,
--           public.has_permission(u.auth_uid, 'presences',    'saisir')               as fait_appel,
--           public.has_permission(u.auth_uid, 'classes',      'supprimer')            as supprime_classe
--      from public.users u
--      join public.staff_roles r on r.id = u.staff_role_id
--     where u.email in ('comptable.elc@elc.cg', 'surveillant.elc@elc.cg');
--
--    -- Attendu — Sylvie (Comptable)     : encaisse = true,  le reste = false
--    -- Attendu — André  (Surveillant)   : fait_appel = true, encaisse = false
--
--  Puis dans l'app : comptable.elc@elc.cg / demo1234
-- ============================================================================

-- ============================================================================
--  ROLLBACK
--
--    delete from public.school_members where user_id in
--      ('d0000000-0000-4000-8000-00000000c0c1','d0000000-0000-4000-8000-00000000d0d1');
--    delete from public.users     where id in
--      ('d0000000-0000-4000-8000-00000000c0c1','d0000000-0000-4000-8000-00000000d0d1');
--    delete from auth.identities  where user_id in
--      ('d0000000-0000-4000-8000-00000000c0c1','d0000000-0000-4000-8000-00000000d0d1');
--    delete from auth.users       where id in
--      ('d0000000-0000-4000-8000-00000000c0c1','d0000000-0000-4000-8000-00000000d0d1');
-- ============================================================================
