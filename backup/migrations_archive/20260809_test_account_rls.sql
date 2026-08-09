-- 20260809_test_account_rls.sql
--
-- Compte de test dédié pour vérifier en conditions réelles le blocage
-- "abonnement en lecture seule" (cf. 20260809_enforce_subscription_rls*.sql).
-- École séparée d'"École Test Scolaris" pour ne pas perturber les données de
-- test existantes. Abonnement forcé `expired` immédiatement après création
-- pour que le blocage soit visible dès la première connexion.

do $$
declare
  v_school_id uuid;
  v_admin_id  uuid := gen_random_uuid();
begin
  insert into public.schools (name, slug, country, city, plan_type, academic_year, metadata)
  values (
    'École Test RLS', 'ecole-test-rls', 'CG', 'Brazzaville', 'free', '2025-2026',
    jsonb_build_object('types', array['college'], 'system_type', 'francophone_africa',
                        'modules', array['academic'])
  )
  returning id into v_school_id;

  insert into public.users (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
  values (v_admin_id, v_school_id, v_admin_id, 'Admin Test RLS', 'admin.rls@test.local', 'admin', 'active', now(), now());

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
    'admin.rls@test.local', crypt('Test1234!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('sub', v_admin_id, 'email', 'admin.rls@test.local', 'full_name', 'Admin Test RLS', 'role', 'admin', 'school_id', v_school_id)
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
  values (
    gen_random_uuid(), v_admin_id, v_admin_id::text, 'email',
    jsonb_build_object('sub', v_admin_id, 'email', 'admin.rls@test.local'),
    now(), now(), now()
  );

  -- Le trigger handle_new_school_trial (AFTER INSERT ON schools) vient de
  -- créer l'abonnement en 'trial' — on le force à 'expired' tout de suite
  -- pour que le blocage soit immédiatement testable, sans attendre 14 jours
  -- ni le passage du cron horaire.
  update public.subscriptions
     set status = 'expired',
         trial_end = now() - interval '1 day'
   where school_id = v_school_id;
end $$;
