-- ============================================================
-- SCOLARIS — Données de démonstration (seed) — RESET COMPLET
-- À exécuter dans : Supabase Dashboard > SQL Editor
--
-- ⚠️  DESTRUCTIF : ce script VIDE toutes les données métier (toutes écoles)
--     via `TRUNCATE public.schools CASCADE`, puis recrée UNE école propre.
--     Les catalogues globaux (plans, plan_prices, class_levels, subject_catalog)
--     sont conservés. Les comptes auth démo sont (re)créés si absents.
--
-- École : EAD Brazzaville (collège-lycée) — offre PRO
-- Comptes (mot de passe commun : demo1234) :
--   admin@ead-bzv.cg   → admin
--   prof@ead-bzv.cg    → teacher (Jean Makaya)
--   eleve@ead-bzv.cg   → student (Grace Mabiala, 4ème A)
--   parent@ead-bzv.cg  → parent (Pauline Mabiala)
-- ============================================================

-- Identifiants fixes
--   school   : de3764d3-f0e6-4191-ba89-ab4c73cf37a1
--   admin    : d0000000-…-000000000001
--   teacher  : d0000000-…-000000000002
--   student  : d0000000-…-000000000003  (Grace, compte de test)
--   parent   : d0000000-…-000000000004
--   élèves+  : d0000000-…-000000000005 / 006 / 007  (roster, sans login)
--   classe   : c0000000-…-000000000001  (4ème A)

begin;

-- ════════════════════════════════════════════════════════════════════════════
-- 0. RESET COMPLET — vide toutes les écoles et tout ce qui en dépend.
--    (plans / plan_prices / class_levels / subject_catalog sont préservés)
-- ════════════════════════════════════════════════════════════════════════════
truncate table public.schools cascade;

-- ════════════════════════════════════════════════════════════════════════════
-- 1. COMPTES AUTH (auth.users + auth.identities)
--    Si cette section échoue selon ta version de Supabase, crée les 4 comptes
--    manuellement via Authentication > Add user (mêmes emails / demo1234) en
--    réutilisant les UUID ci-dessus, puis relance à partir de la section 2.
-- ════════════════════════════════════════════════════════════════════════════
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
values
  ('00000000-0000-0000-0000-000000000000','d0000000-0000-0000-0000-000000000001','authenticated','authenticated','admin@ead-bzv.cg',  crypt('demo1234', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}','{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000','d0000000-0000-0000-0000-000000000002','authenticated','authenticated','prof@ead-bzv.cg',   crypt('demo1234', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}','{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000','d0000000-0000-0000-0000-000000000003','authenticated','authenticated','eleve@ead-bzv.cg',  crypt('demo1234', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}','{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000','d0000000-0000-0000-0000-000000000004','authenticated','authenticated','parent@ead-bzv.cg', crypt('demo1234', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}','{}', now(), now(), '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
)
values
  (gen_random_uuid(),'d0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','{"sub":"d0000000-0000-0000-0000-000000000001","email":"admin@ead-bzv.cg"}','email', now(), now(), now()),
  (gen_random_uuid(),'d0000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002','{"sub":"d0000000-0000-0000-0000-000000000002","email":"prof@ead-bzv.cg"}','email', now(), now(), now()),
  (gen_random_uuid(),'d0000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000003','{"sub":"d0000000-0000-0000-0000-000000000003","email":"eleve@ead-bzv.cg"}','email', now(), now(), now()),
  (gen_random_uuid(),'d0000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000004','{"sub":"d0000000-0000-0000-0000-000000000004","email":"parent@ead-bzv.cg"}','email', now(), now(), now())
on conflict do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 2. ÉCOLE (collège-lycée) — metadata.types pilote le dynamisme par niveau
-- ════════════════════════════════════════════════════════════════════════════
insert into public.schools (
  id, name, code, country, city, plan_type, db_mode, is_active,
  max_students, academic_year, accent_color, contact_email, metadata,
  created_at, updated_at
)
values (
  'de3764d3-f0e6-4191-ba89-ab4c73cf37a1','EAD Brazzaville','EAD','CG','Brazzaville',
  'pro','central', true, 1000, '2025-2026', '#8B1A00','admin@ead-bzv.cg',
  '{"types": ["college", "lycee"]}'::jsonb,
  now(), now()
);

-- ── Abonnement PRO (actif) → l'élève accède aux features Pro ────────────────
insert into public.subscriptions (
  school_id, plan_code, status, billing_period, country, currency,
  current_period_start, current_period_end, created_at, updated_at
)
values (
  'de3764d3-f0e6-4191-ba89-ab4c73cf37a1','pro','active','monthly','CG','XAF',
  now(), now() + interval '30 days', now(), now()
);

-- ════════════════════════════════════════════════════════════════════════════
-- 3. UTILISATEURS (admin, prof, élèves, parent)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.users (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
values
  ('d0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000001','Direction EAD','admin@ead-bzv.cg','admin','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000002','Jean Makaya','prof@ead-bzv.cg','teacher','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','Grace Mabiala','eleve@ead-bzv.cg','student','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000004','Pauline Mabiala','parent@ead-bzv.cg','parent','active', now(), now()),
  -- Camarades de classe (roster, sans compte de connexion auth)
  ('d0000000-0000-0000-0000-000000000005','de3764d3-f0e6-4191-ba89-ab4c73cf37a1', null,'David Nkouka',     'david.nkouka@ead-bzv.cg',   'student','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000006','de3764d3-f0e6-4191-ba89-ab4c73cf37a1', null,'Sarah Loemba',     'sarah.loemba@ead-bzv.cg',   'student','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000007','de3764d3-f0e6-4191-ba89-ab4c73cf37a1', null,'Joseph Bantsimba', 'joseph.bantsimba@ead-bzv.cg','student','active', now(), now());

-- ════════════════════════════════════════════════════════════════════════════
-- 4. CLASSE (4ème A — collège)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.classes (id, school_id, name, level, section, academic_year, main_teacher_id, room, max_students, is_active, created_at, updated_at)
values
  ('c0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','4ème A','college','A','2025-2026','d0000000-0000-0000-0000-000000000002','Salle 12', 35, true, now(), now());

-- ── Fiches élèves (4 élèves rattachés à la 4ème A) ──────────────────────────
insert into public.student_profiles (user_id, school_id, class_id, matricule, academic_year, created_at, updated_at)
values
  ('d0000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','EAD-2025-001','2025-2026', now(), now()),
  ('d0000000-0000-0000-0000-000000000005','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','EAD-2025-002','2025-2026', now(), now()),
  ('d0000000-0000-0000-0000-000000000006','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','EAD-2025-003','2025-2026', now(), now()),
  ('d0000000-0000-0000-0000-000000000007','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','EAD-2025-004','2025-2026', now(), now());

-- ── Fiche enseignant ────────────────────────────────────────────────────────
insert into public.teacher_profiles (user_id, school_id, employee_id, specialization, created_at, updated_at)
values ('d0000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','EAD-EMP-001','Mathématiques', now(), now());

-- ── Lien parent → enfant (Pauline mère de Grace) ────────────────────────────
insert into public.parent_student (id, school_id, parent_id, student_id, relationship, is_primary, created_at)
values ('b0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1',
        'd0000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000003','mother', true, now());

-- ════════════════════════════════════════════════════════════════════════════
-- 5. MATIÈRES (noms alignés sur la palette de l'app → couleurs EDT)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.subjects (id, school_id, name, code, coefficient, is_active, created_at)
values
  ('50000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Mathématiques','MATH', 4, true, now()),
  ('50000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Français','FR', 4, true, now()),
  ('50000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Anglais','ANG', 2, true, now()),
  ('50000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','SVT','SVT', 2, true, now()),
  ('50000000-0000-0000-0000-000000000005','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Histoire-Géo','HG', 2, true, now()),
  ('50000000-0000-0000-0000-000000000006','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Sciences Physiques','PC', 3, true, now());

-- ════════════════════════════════════════════════════════════════════════════
-- 6. EMPLOI DU TEMPS (4ème A — lundi→vendredi)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.schedules (id, school_id, class_id, subject_id, teacher_id, day_of_week, start_time, end_time, room, academic_year, is_active, created_at, updated_at)
values
  -- Lundi (1)
  ('5c000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002',1,'08:00','10:00','Salle 12','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002',1,'10:15','12:15','Salle 12','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000002',1,'14:00','16:00','Labo SVT','2025-2026', true, now(), now()),
  -- Mardi (2)
  ('5c000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000006','d0000000-0000-0000-0000-000000000002',2,'08:00','10:00','Labo Physique','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-000000000005','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002',2,'10:15','12:15','Salle 12','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-000000000006','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000002',2,'14:00','16:00','Salle 12','2025-2026', true, now(), now()),
  -- Mercredi (3)
  ('5c000000-0000-0000-0000-000000000007','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002',3,'08:00','10:00','Salle 12','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-000000000008','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000005','d0000000-0000-0000-0000-000000000002',3,'10:15','12:15','Salle 12','2025-2026', true, now(), now()),
  -- Jeudi (4)
  ('5c000000-0000-0000-0000-000000000009','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002',4,'08:00','10:00','Salle 12','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-00000000000a','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000002',4,'10:15','12:15','Labo SVT','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-00000000000b','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000006','d0000000-0000-0000-0000-000000000002',4,'14:00','16:00','Labo Physique','2025-2026', true, now(), now()),
  -- Vendredi (5)
  ('5c000000-0000-0000-0000-00000000000c','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000005','d0000000-0000-0000-0000-000000000002',5,'08:00','10:00','Salle 12','2025-2026', true, now(), now()),
  ('5c000000-0000-0000-0000-00000000000d','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000002',5,'10:15','12:15','Salle 12','2025-2026', true, now(), now());

-- ════════════════════════════════════════════════════════════════════════════
-- 7. DEVOIRS (assignments) + REMISES (submissions) de Grace
-- ════════════════════════════════════════════════════════════════════════════
insert into public.assignments (id, school_id, class_id, subject_id, teacher_id, title, description, max_score, deadline, allow_late, is_published, created_at, updated_at)
values
  -- en retard (échéance passée, non rendu)
  ('a1000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000002','Schéma annoté — La cellule','Réaliser un schéma légendé de la cellule végétale.', 20, now() - interval '2 days', true, true, now(), now()),
  -- à rendre bientôt (non rendu)
  ('a1000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002','Exercices — Théorème de Pythagore','Exercices 12 à 18 page 84.', 20, now() + interval '2 days', false, true, now(), now()),
  -- à rendre plus tard (rendu, pas encore corrigé)
  ('a1000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002','Rédaction — Mon village','Rédiger un texte de 20 lignes.', 20, now() + interval '6 days', false, true, now(), now()),
  -- corrigé (rendu + noté)
  ('a1000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000002','Essay — My family','Write a short essay about your family.', 20, now() - interval '7 days', false, true, now(), now());

insert into public.submissions (id, school_id, assignment_id, student_id, status, grade, feedback, submitted_at, graded_at, is_late, created_at, updated_at)
values
  -- Rédaction : rendu, pas encore noté → onglet "Rendu"
  ('5b000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','a1000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000003','submitted', null, null, now() - interval '1 day', null, false, now(), now()),
  -- Essay anglais : rendu + noté → onglets "Rendu" et "Corrigé"
  ('5b000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','a1000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000003','graded', 16, 'Très bon travail, attention au vocabulaire.', now() - interval '6 days', now() - interval '4 days', false, now(), now());

-- ════════════════════════════════════════════════════════════════════════════
-- 8. NOTES de Grace (graduées sur plusieurs semaines → courbe de progression)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.grades (id, school_id, student_id, subject_id, class_id, teacher_id, score, max_score, type, title, period, academic_year, graded_at, created_at, updated_at)
values
  ('60000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 12.5, 20, 'devoir','Devoir 1 — Calcul littéral','T1','2025-2026', now() - interval '40 days', now(), now()),
  ('60000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 13, 20, 'examen','Composition — Dictée','T1','2025-2026', now() - interval '32 days', now(), now()),
  ('60000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 14.5, 20, 'controle','Interro — Vocabulary','T1','2025-2026', now() - interval '24 days', now(), now()),
  ('60000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000004','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 15, 20, 'devoir','Devoir — La cellule','T1','2025-2026', now() - interval '16 days', now(), now()),
  ('60000000-0000-0000-0000-000000000005','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000006','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 15.5, 20, 'devoir','Devoir — États de la matière','T1','2025-2026', now() - interval '8 days', now(), now()),
  ('60000000-0000-0000-0000-000000000006','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 16, 20, 'controle','Interro — Pythagore','T1','2025-2026', now() - interval '3 days', now(), now());

-- ════════════════════════════════════════════════════════════════════════════
-- 9. ABSENCES de Grace
-- ════════════════════════════════════════════════════════════════════════════
insert into public.absences (id, school_id, student_id, class_id, subject_id, absence_date, period, justified, reason, created_at)
values
  ('ab000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000004',(now() - interval '5 days')::date,'Matin', true, 'Rendez-vous médical', now()),
  ('ab000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',(now() - interval '12 days')::date,'Après-midi', false, null, now());

-- ════════════════════════════════════════════════════════════════════════════
-- 10. FACTURES (scolarité : 2 payées + 1 en attente)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.invoices (id, school_id, student_id, invoice_number, description, amount, currency, due_date, issued_date, status, category, created_by, created_at, updated_at)
values
  ('f0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','FAC-2025-0001','Frais de scolarité — 1ère tranche', 75000, 'XAF', (now() - interval '90 days')::date, (now() - interval '100 days')::date, 'paid','tuition','d0000000-0000-0000-0000-000000000001', now(), now()),
  ('f0000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','FAC-2025-0002','Frais de scolarité — 2ème tranche', 75000, 'XAF', (now() - interval '10 days')::date, (now() - interval '20 days')::date, 'paid','tuition','d0000000-0000-0000-0000-000000000001', now(), now()),
  ('f0000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','FAC-2025-0003','Frais de scolarité — 3ème tranche', 75000, 'XAF', (now() + interval '20 days')::date, now()::date, 'pending','tuition','d0000000-0000-0000-0000-000000000001', now(), now());

-- ════════════════════════════════════════════════════════════════════════════
-- 11. ANNONCES (visibles dans Notifications de l'élève)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.announcements (id, school_id, author_id, title, content, target_role, priority, is_pinned, is_published, published_at, created_at, updated_at)
values
  ('aa000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000001','Réunion de rentrée','La réunion de rentrée aura lieu le 15 septembre à 09h00 au réfectoire.','all','important', true, true, now() - interval '2 days', now() - interval '2 days', now()),
  ('aa000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000001','Composition du 1er trimestre','Les compositions du 1er trimestre débutent lundi prochain. Bon courage !','students','normal', false, true, now() - interval '1 days', now() - interval '1 days', now());

commit;

-- ════════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION (optionnel) :
--   select email, role from public.users where school_id = 'de3764d3-f0e6-4191-ba89-ab4c73cf37a1';
--   select count(*) from public.schedules  where class_id  = 'c0000000-0000-0000-0000-000000000001';
--   select count(*) from public.assignments where class_id = 'c0000000-0000-0000-0000-000000000001';
--   select plan_code, status from public.subscriptions where school_id = 'de3764d3-f0e6-4191-ba89-ab4c73cf37a1';
-- ════════════════════════════════════════════════════════════════════════════
