-- ─────────────────────────────────────────────────────────────────────────────
-- Compte "Admin" démo distinct du super-admin plateforme.
--
-- kenganiboveldy@gmail.com est un vrai `platform_admin` : `roleHome()`
-- (app_router.dart) route TOUJOURS ce compte vers la console plateforme
-- (AppRoutes.platform), jamais vers l'admin d'école (AppRoutes.staff) — ce
-- n'est pas un bug, c'est le sens même du compte. Il fallait donc un compte
-- admin d'ÉCOLE séparé, sans entrée `platform_admins`, pour la tuile "Admin"
-- du panneau démo du login.
-- ─────────────────────────────────────────────────────────────────────────────

do $$
declare
  v_school_id uuid;
  v_admin_id  uuid := gen_random_uuid();
begin
  select id into v_school_id from schools where slug = 'ecole-test-scolaris';

  insert into public.users (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
  values (v_admin_id, v_school_id, v_admin_id, 'Sylvie Kanga', 'admin1@test.local', 'admin', 'active', now(), now());

  insert into public.staff_profiles (user_id, school_id, contract_type, created_at, updated_at)
  values (v_admin_id, v_school_id, 'permanent', now(), now());

  insert into public.school_members (user_id, school_id, role, status)
  values (v_admin_id, v_school_id, 'admin', 'active');

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', v_admin_id, 'authenticated', 'authenticated',
    'admin1@test.local', crypt('demo1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('sub', v_admin_id, 'email', 'admin1@test.local', 'full_name', 'Sylvie Kanga', 'role', 'admin', 'school_id', v_school_id)
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (
    gen_random_uuid(), v_admin_id, v_admin_id::text, 'email',
    jsonb_build_object('sub', v_admin_id, 'email', 'admin1@test.local'),
    now(), now(), now()
  );
end $$;
