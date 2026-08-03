-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige 3 défauts de qualité relevés dans le seed du 2026-08-03 :
--
-- 1. L'école est à l'offre "Essentiel" (plan `simple`, max_modules=1) mais
--    `schools.metadata` n'avait jamais de clé `modules` -> le code
--    (supabase_db_source.dart:1240) traite une clé absente comme "école créée
--    avant le choix de modules -> tous les modules actifs", ce qui contredit
--    le plan. On fixe `modules: ['academic']` (1 seul module, cohérent).
--
-- 2. Les 8 enseignants seedés avaient `role='teacher'` mais aucun
--    `staff_role_id` -> la page Personnel les affiche "Sans rôle" (rouge) et,
--    plus grave, le commentaire dans users_page.dart est explicite : "un
--    membre du personnel sans rôle ne peut RIEN faire, la base lui refuse
--    tout". On crée un rôle "Enseignant" (staff_roles + permissions clonées
--    d'un role_template existant) et on l'assigne aux 8 comptes.
--
-- 3. Les 104 élèves partageaient un pool de prénoms/noms trop petit pour le
--    nombre de classes -> jusqu'à 5 élèves avec le nom EXACT dans toute
--    l'école (ex. 5x "Joel Nzoussi"). Renommage avec un pool 12x12=144
--    combinaisons, assignées de façon injective (garanti unique pour 101
--    élèves) — les 3 élèves déjà câblés dans le panneau démo du login
--    (eleve51/74/106) sont exclus du renommage pour ne pas casser
--    `login_screen.dart`.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Modules cohérents avec l'offre Essentiel (1 module) ─────────────────
update schools
set metadata = metadata || '{"modules": ["academic"]}'::jsonb
where slug = 'ecole-test-scolaris';

-- ── 2. Rôle "Enseignant" pour les 8 profs ───────────────────────────────────
do $$
declare
  v_school_id uuid;
  v_role_id   uuid;
begin
  select id into v_school_id from schools where slug = 'ecole-test-scolaris';

  insert into staff_roles (school_id, name, description, is_admin_role, level, color, icon_key)
  values (v_school_id, 'Enseignant', 'Notes, présences de ses classes', false, 'Pédagogique', '#0277BD', 'menu_book')
  on conflict (school_id, name) do update set description = excluded.description
  returning id into v_role_id;

  insert into staff_role_permissions (staff_role_id, permission_key, sub_permission_key)
  values
    (v_role_id, 'eleves', 'voir'),
    (v_role_id, 'emploi_du_temps', 'voir'),
    (v_role_id, 'notes', 'modifier'),
    (v_role_id, 'notes', 'publier'),
    (v_role_id, 'notes', 'saisir'),
    (v_role_id, 'notes', 'voir'),
    (v_role_id, 'presences', 'saisir'),
    (v_role_id, 'presences', 'voir')
  on conflict do nothing;

  update users
  set staff_role_id = v_role_id
  where school_id = v_school_id and role = 'teacher';
end $$;

-- ── 3. Noms uniques pour les élèves (hors comptes démo câblés au login) ────
do $$
declare
  v_school_id uuid;
  v_prenoms text[] := array['Aline','Bruno','Carine','Didier','Emma','Franck',
    'Gaelle','Hugo','Ines','Jules','Kelly','Marc'];
  v_noms    text[] := array['Ondongo','Ngoma','Massamba','Kimbembe','Batantou',
    'Ngouabi','Foutou','Mizele','Bakekolo','Ossete','Tchibota','Mabiala'];
  v_np int := array_length(v_prenoms, 1);
  v_nn int := array_length(v_noms, 1);
  r record;
  v_idx int := 0;
begin
  select id into v_school_id from schools where slug = 'ecole-test-scolaris';

  for r in
    select id from users
    where school_id = v_school_id and role = 'student'
      and email not in ('eleve51@test.local', 'eleve74@test.local', 'eleve106@test.local')
    order by email
  loop
    update users
    set full_name = v_prenoms[(v_idx % v_np) + 1] || ' ' || v_noms[((v_idx / v_np) % v_nn) + 1]
    where id = r.id;
    v_idx := v_idx + 1;
  end loop;
end $$;
