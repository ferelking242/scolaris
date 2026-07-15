-- ============================================================================
--  20260750_seed_role_demos.sql — Un compte de demo PAR ROLE
--
--  ── Pourquoi ────────────────────────────────────────────────────────────────
--  20260735 a donne une Comptable et un Surveillant. Il manque un compte pour
--  chacun des autres roles communs, afin de VOIR de ses yeux ce que chaque role
--  peut faire (et surtout ne pas faire) :
--
--      Gaston Milandou   chef.elc@elc.cg        / demo1234  → Chef d'etablissement
--      Firmin Loubota    adjoint.elc@elc.cg     / demo1234  → Adjoint
--      Clarisse Ndinga   secretaire.elc@elc.cg  / demo1234  → Secretaire
--      Basile Kaya       enseignant.elc@elc.cg  / demo1234  → Enseignant
--
--  Avec la Comptable (comptable.elc) et le Surveillant (surveillant.elc) deja
--  seedes, les SIX roles communs ont chacun leur compte, tous a l'Ecole Lumiere
--  du Congo — le reste du jeu de demo.
--
--  Meme methode que 20260735, a un detail pres : le Chef d'etablissement est un
--  role de DIRECTION (is_admin_role = true) — son acces vient du drapeau admin,
--  pas d'une liste de droits. On le derive donc du `level` du modele au lieu de
--  le figer a false.
--
--  Idempotent. Rejouable.
-- ============================================================================

do $$
declare
  v_school_id uuid;
  m record;
  v_role_id   uuid;
  v_is_admin  boolean;
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
      ('d0000000-0000-4000-8000-00000000a0a1'::uuid,
       'chef.elc@elc.cg',       'Gaston Milandou',  'Chef d''établissement'),
      ('d0000000-0000-4000-8000-00000000b0b1'::uuid,
       'adjoint.elc@elc.cg',    'Firmin Loubota',   'Adjoint'),
      ('d0000000-0000-4000-8000-00000000e0e1'::uuid,
       'secretaire.elc@elc.cg', 'Clarisse Ndinga',  'Secrétaire'),
      ('d0000000-0000-4000-8000-00000000f0f1'::uuid,
       'enseignant.elc@elc.cg', 'Basile Kaya',      'Enseignant')
    ) as t(uid, email, full_name, role_name)
  loop
    -- Direction ? Alors role administrateur (acces total via le drapeau).
    select (t.level = 'Direction') into v_is_admin
      from public.role_templates t
     where t.cycle = 'commun' and t.name = m.role_name;

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
    insert into public.staff_roles
      (school_id, name, description, is_admin_role, based_on_template_id,
       level, color, icon_key)
    select v_school_id, t.name, t.description, v_is_admin, t.id,
           t.level, t.color, t.icon_key
      from public.role_templates t
     where t.cycle = 'commun' and t.name = m.role_name
    on conflict (school_id, name) do nothing;

    select r.id into v_role_id
      from public.staff_roles r
     where r.school_id = v_school_id and r.name = m.role_name;

    -- Un role de Direction n'a aucune permission enumeree : tout vient du drapeau.
    insert into public.staff_role_permissions
      (staff_role_id, permission_key, sub_permission_key)
    select v_role_id, tp.permission_key, tp.sub_permission_key
      from public.role_templates t
      join public.role_template_permissions tp on tp.role_template_id = t.id
     where t.cycle = 'commun' and t.name = m.role_name
    on conflict do nothing;

    -- 3) La fiche. `users.role` = 'staff_custom' : c'est l'ESPACE qu'il voit
    --    (le tableau de bord d'administration). Ce qu'il a le DROIT d'y faire
    --    vient du role ci-dessus.
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
--  VERIFICATION — les droits FINS, role par role :
--
--    select u.full_name, u.role_title,
--           public.has_permission(u.auth_uid, 'notes',        'modifier') as notes,
--           public.has_permission(u.auth_uid, 'comptabilite', 'enregistrer_paiement') as encaisse,
--           public.has_permission(u.auth_uid, 'presences',    'saisir')   as appel,
--           public.has_permission(u.auth_uid, 'classes',      'creer')    as classes
--      from public.users u
--     where u.email in ('chef.elc@elc.cg','adjoint.elc@elc.cg',
--                       'secretaire.elc@elc.cg','enseignant.elc@elc.cg')
--     order by u.role_title;
--
--    -- Attendu — Chef     : tout true (role admin)
--    -- Attendu — Adjoint  : notes/appel/classes true, encaisse false
--    -- Attendu — Secretaire : classes true, notes/encaisse false
--    -- Attendu — Enseignant : notes/appel true, encaisse/classes false
-- ============================================================================

-- ============================================================================
--  ROLLBACK
--    delete from public.school_members where user_id in (
--      'd0000000-0000-4000-8000-00000000a0a1','d0000000-0000-4000-8000-00000000b0b1',
--      'd0000000-0000-4000-8000-00000000e0e1','d0000000-0000-4000-8000-00000000f0f1');
--    delete from public.users    where id in (
--      'd0000000-0000-4000-8000-00000000a0a1','d0000000-0000-4000-8000-00000000b0b1',
--      'd0000000-0000-4000-8000-00000000e0e1','d0000000-0000-4000-8000-00000000f0f1');
--    delete from auth.identities where user_id in (
--      'd0000000-0000-4000-8000-00000000a0a1','d0000000-0000-4000-8000-00000000b0b1',
--      'd0000000-0000-4000-8000-00000000e0e1','d0000000-0000-4000-8000-00000000f0f1');
--    delete from auth.users      where id in (
--      'd0000000-0000-4000-8000-00000000a0a1','d0000000-0000-4000-8000-00000000b0b1',
--      'd0000000-0000-4000-8000-00000000e0e1','d0000000-0000-4000-8000-00000000f0f1');
-- ============================================================================
