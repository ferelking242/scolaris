-- ─────────────────────────────────────────────────────────────────────────────
-- Nettoyage complet des données de test + recréation d'une école de test
-- propre et ordonnée (primaire + collège + lycée), sur demande explicite de
-- l'utilisateur (2026-08-03).
--
-- Étape 1 : supprime les 11 écoles existantes (seed + tests manuels) et tout
-- ce qui en dépend (cascade déjà vérifié en direct sur `schools` — sauf
-- `invoices`, sans cascade, supprimées explicitement d'abord).
--
-- Étape 2 : recrée UNE école de test avec :
--  - votre compte admin (kenganiboveldy@gmail.com) — réutilise l'auth.users
--    existant (id d48d4f14-aeee-49c6-9499-bc553437923d), pas besoin de
--    nouveau mot de passe. Remis dans `platform_admins` (super-admin
--    plateforme, perdu par la suppression en cascade de l'ancienne école).
--  - 8 enseignants (pool réutilisé sur toutes les classes).
--  - 13 classes (CP1→CM2, 6ème→3ème, 2nde/1ère/Terminale série C), chacune
--    avec son programme généré depuis `subject_catalog` (même logique que
--    `generateDefaultProgramForClass`, reproduite ici en SQL) et 8 élèves.
--
-- ⚠️ Irréversible. Confirmé explicitement par l'utilisateur avant exécution.
-- Note : la plupart des comptes élèves/profs créés ici sont des FICHES DE
-- DONNÉES, pas des comptes de connexion (pas d'entrée `auth.users` associée)
-- — comme l'étaient déjà les précédentes données de démo/seed.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Étape 1 : nettoyage ──────────────────────────────────────────────────────
-- trg_guard_last_admin_role empêche de retirer le dernier rôle admin d'une
-- école (garde-fou en usage normal) — bloque ici car on supprime l'école
-- entière, pas juste son admin. Désactivé pour la durée du nettoyage, remis
-- immédiatement après.
alter table public.staff_roles disable trigger trg_guard_last_admin_role;
delete from public.invoices;
delete from public.schools;
alter table public.staff_roles enable trigger trg_guard_last_admin_role;

-- ── Étape 2 : recréation ─────────────────────────────────────────────────────
do $$
declare
  v_school_id   uuid;
  v_admin_id    uuid := 'd48d4f14-aeee-49c6-9499-bc553437923d';
  v_teacher_ids uuid[] := array[]::uuid[];
  v_teacher_id  uuid;
  v_student_id  uuid;
  v_course_id   uuid;
  i             int;
  email_seq     int := 0;

  level_names text[] := array[
    'CP1','CP2','CE1','CE2','CM1','CM2',
    '6ème','5ème','4ème','3ème',
    '2nde C','1ère C','Terminale C'
  ];
  lvl text;
  v_level_id  uuid;
  v_cycle     text;
  v_series    text;
  v_order_num int;
  v_class_id  uuid;
  v_subject_id uuid;
  v_titulaire  uuid;
  rec record;

  s int;
  fn text;
  ln text;
  first_names text[] := array['Alice','Brice','Chantal','David','Estelle','Fabrice','Grace','Herve','Ines','Joel','Karine','Lionel'];
  last_names  text[] := array['Moukoko','Nzoussi','Okemba','Ibara','Mombeki','Bakala','Loko','Nkodia','Samba','Bouanga','Malonga','Loemba'];
begin
  -- École ---------------------------------------------------------------------
  insert into schools (name, slug, country, city, plan_type, academic_year, metadata)
  values (
    'École Test Scolaris', 'ecole-test-scolaris', 'CG', 'Brazzaville', 'free', '2025-2026',
    jsonb_build_object('types', array['primaire','college','lycee'], 'system_type', 'francophone_africa')
  )
  returning id into v_school_id;

  -- Votre compte admin (réutilise l'auth existant) -----------------------------
  insert into users (id, school_id, auth_uid, full_name, email, role, status)
  values (v_admin_id, v_school_id, v_admin_id, 'Boveldy Kengani', 'kenganiboveldy@gmail.com', 'admin', 'active');

  insert into platform_admins (user_id) values (v_admin_id);

  -- Pool de 8 enseignants -------------------------------------------------------
  for i in 1..8 loop
    v_teacher_id := gen_random_uuid();
    email_seq := email_seq + 1;
    insert into users (id, school_id, full_name, email, role, status)
    values (
      v_teacher_id, v_school_id,
      first_names[i] || ' ' || last_names[i],
      'prof' || email_seq || '@test.local',
      'teacher', 'active'
    );
    insert into staff_profiles (user_id, school_id) values (v_teacher_id, v_school_id);
    v_teacher_ids := array_append(v_teacher_ids, v_teacher_id);
  end loop;

  -- Classes, programme, élèves --------------------------------------------------
  foreach lvl in array level_names loop
    select id, cycle, series, order_num into v_level_id, v_cycle, v_series, v_order_num
    from class_levels where system_type = 'francophone_africa' and name = lvl;

    v_titulaire := null;
    if v_cycle = 'primaire' then
      v_titulaire := v_teacher_ids[1 + (v_order_num % 8)];
    end if;

    insert into classes (school_id, name, level, level_id, main_teacher_id, max_students)
    values (v_school_id, lvl, v_cycle, v_level_id, v_titulaire, 40)
    returning id into v_class_id;

    -- Garantit les matières du catalogue (même logique que loadSubjectsFromCatalog)
    insert into subjects (school_id, name, code, coefficient)
    select v_school_id, sc.name, sc.short_name, sc.default_coefficient
    from subject_catalog sc
    where sc.cycle = v_cycle
      and (sc.series is null or sc.series = v_series)
      and (sc.min_order_num is null or sc.min_order_num <= v_order_num)
      and not exists (
        select 1 from subjects s2
        where s2.school_id = v_school_id and lower(s2.name) = lower(sc.name)
      );

    -- Cours (classe × matière) + un prof du pool en round-robin
    for rec in
      select sc.name, sc.short_name, sc.default_coefficient,
             row_number() over (order by sc.order_num) as rn
      from subject_catalog sc
      where sc.cycle = v_cycle
        and (sc.series is null or sc.series = v_series)
        and (sc.min_order_num is null or sc.min_order_num <= v_order_num)
    loop
      select id into v_subject_id from subjects
        where school_id = v_school_id and lower(name) = lower(rec.name) limit 1;

      insert into courses (school_id, class_id, subject_id, name, code, coef, hours_week)
      values (
        v_school_id, v_class_id, v_subject_id, rec.name, rec.short_name,
        greatest(round(rec.default_coefficient)::int, 1), 3
      )
      returning id into v_course_id;

      insert into course_teachers (school_id, course_id, teacher_id, role)
      values (v_school_id, v_course_id, v_teacher_ids[1 + (rec.rn::int % 8)], 'principal');
    end loop;

    -- 8 élèves
    for s in 1..8 loop
      email_seq := email_seq + 1;
      fn := first_names[1 + ((v_order_num * 7 + s) % array_length(first_names, 1))];
      ln := last_names[1 + ((v_order_num * 3 + s) % array_length(last_names, 1))];

      insert into users (school_id, full_name, email, role, status)
      values (v_school_id, fn || ' ' || ln, 'eleve' || email_seq || '@test.local', 'student', 'active')
      returning id into v_student_id;

      insert into student_profiles (user_id, school_id, class_id, matricule)
      values (v_student_id, v_school_id, v_class_id,
        'ET-' || upper(regexp_replace(lvl, '[^A-Za-z0-9]', '', 'g')) || '-' || lpad(s::text, 2, '0'));
    end loop;
  end loop;
end $$;
