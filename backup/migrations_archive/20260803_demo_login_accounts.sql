-- ─────────────────────────────────────────────────────────────────────────────
-- Comptes de connexion réels pour le panneau « Comptes démo » du login
-- (login_screen.dart), après le nettoyage complet des données de test du
-- 2026-08-03. La plupart des profs/élèves recréés ce jour-là sont de pures
-- fiches (pas d'entrée `auth.users`) — il en faut quelques-uns qui puissent
-- RÉELLEMENT se connecter pour ce panneau de démo.
--
-- Réutilise les lignes `public.users` déjà créées (même id) plutôt que d'en
-- créer de nouvelles, pour rester cohérent avec le reste des données seedées.
-- Mot de passe unique : demo1234 (même convention que l'existant).
-- ─────────────────────────────────────────────────────────────────────────────

do $$
declare
  v_school_id  uuid;
  v_teacher_id uuid := '61faef55-2357-4c1c-ab43-0338417742a6'; -- prof1@test.local
  v_student_id uuid := '2406a606-85a4-4877-b84a-1e7a995c142c'; -- eleve51@test.local (Alice Moukoko, CM2)
  v_parent_id  uuid := gen_random_uuid();
begin
  select id into v_school_id from schools where slug = 'ecole-test-scolaris';

  -- Nom du prof démo distinct de l'élève démo (les deux tiraient "Alice
  -- Moukoko" du même pool de prénoms/noms — cosmétique, sans conséquence sur
  -- les données, mais source de confusion dans le panneau de démo).
  update users set full_name = 'Georges Mombeki' where id = v_teacher_id;

  -- ── Auth du prof (réutilise l'id existant) ─────────────────────────────────
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', v_teacher_id, 'authenticated', 'authenticated',
    'prof1@test.local', crypt('demo1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('sub', v_teacher_id, 'email', 'prof1@test.local', 'full_name', 'Georges Mombeki', 'role', 'teacher', 'school_id', v_school_id)
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (
    gen_random_uuid(), v_teacher_id, v_teacher_id::text, 'email',
    jsonb_build_object('sub', v_teacher_id, 'email', 'prof1@test.local'),
    now(), now(), now()
  );
  update users set auth_uid = v_teacher_id where id = v_teacher_id;

  -- ── Auth de l'élève (réutilise l'id existant) ──────────────────────────────
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', v_student_id, 'authenticated', 'authenticated',
    'eleve51@test.local', crypt('demo1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('sub', v_student_id, 'email', 'eleve51@test.local', 'full_name', 'Alice Moukoko', 'role', 'student', 'school_id', v_school_id)
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (
    gen_random_uuid(), v_student_id, v_student_id::text, 'email',
    jsonb_build_object('sub', v_student_id, 'email', 'eleve51@test.local'),
    now(), now(), now()
  );
  update users set auth_uid = v_student_id where id = v_student_id;

  -- ── Nouveau compte parent, lié à l'élève démo ci-dessus ────────────────────
  insert into users (id, school_id, auth_uid, full_name, email, role, status)
  values (v_parent_id, v_school_id, v_parent_id, 'Pauline Moukoko', 'parent1@test.local', 'parent', 'active');

  insert into parent_student (school_id, parent_id, student_id, relationship, is_primary)
  values (v_school_id, v_parent_id, v_student_id, 'mere', true);

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', v_parent_id, 'authenticated', 'authenticated',
    'parent1@test.local', crypt('demo1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('sub', v_parent_id, 'email', 'parent1@test.local', 'full_name', 'Pauline Moukoko', 'role', 'parent', 'school_id', v_school_id)
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (
    gen_random_uuid(), v_parent_id, v_parent_id::text, 'email',
    jsonb_build_object('sub', v_parent_id, 'email', 'parent1@test.local'),
    now(), now(), now()
  );

  -- ── Corrige les métadonnées périmées de votre compte super-admin ───────────
  -- (pointaient encore vers l'ancienne école "College teste", supprimée).
  update auth.users
  set raw_user_meta_data = raw_user_meta_data || jsonb_build_object('school_id', v_school_id)
  where email = 'kenganiboveldy@gmail.com';
end $$;
