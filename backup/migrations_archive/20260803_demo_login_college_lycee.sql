-- ─────────────────────────────────────────────────────────────────────────────
-- Complète le panneau « Comptes démo » du login (login_screen.dart) avec un
-- élève Collège et un élève Lycée réellement connectables — jusqu'ici seul
-- un élève de Primaire (eleve51@test.local, CM2) avait un vrai login.
-- Même convention que 20260803_demo_login_accounts.sql : réutilise les
-- lignes `public.users` déjà seedées, mot de passe unique demo1234.
-- ─────────────────────────────────────────────────────────────────────────────

do $$
declare
  v_school_id  uuid;
  v_college_id uuid := '6cee18fa-81c8-4205-a124-371f0341ab0c'; -- eleve74@test.local (Alice Samba, 4ème)
  v_lycee_id   uuid := 'af05db67-90d6-4d3d-9f5e-0b93c1e6504e'; -- eleve106@test.local (Estelle Samba, Terminale C)
begin
  select id into v_school_id from schools where slug = 'ecole-test-scolaris';

  -- ── Auth de l'élève Collège ─────────────────────────────────────────────
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', v_college_id, 'authenticated', 'authenticated',
    'eleve74@test.local', crypt('demo1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('sub', v_college_id, 'email', 'eleve74@test.local', 'full_name', 'Alice Samba', 'role', 'student', 'school_id', v_school_id)
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (
    gen_random_uuid(), v_college_id, v_college_id::text, 'email',
    jsonb_build_object('sub', v_college_id, 'email', 'eleve74@test.local'),
    now(), now(), now()
  );
  update users set auth_uid = v_college_id where id = v_college_id;

  -- ── Auth de l'élève Lycée ───────────────────────────────────────────────
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', v_lycee_id, 'authenticated', 'authenticated',
    'eleve106@test.local', crypt('demo1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('sub', v_lycee_id, 'email', 'eleve106@test.local', 'full_name', 'Estelle Samba', 'role', 'student', 'school_id', v_school_id)
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (
    gen_random_uuid(), v_lycee_id, v_lycee_id::text, 'email',
    jsonb_build_object('sub', v_lycee_id, 'email', 'eleve106@test.local'),
    now(), now(), now()
  );
  update users set auth_uid = v_lycee_id where id = v_lycee_id;
end $$;
