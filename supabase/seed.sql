-- ============================================================
-- SCOLARIS — Données de démonstration (seed)
-- À exécuter dans : Supabase Dashboard > SQL Editor
-- Idempotent : ré-exécutable sans danger (ON CONFLICT DO NOTHING).
--
-- École cible : EAD Brazzaville (de3764d3-f0e6-4191-ba89-ab4c73cf37a1)
--
-- Comptes créés (mot de passe commun : demo1234) :
--   admin@ead-bzv.cg   → rôle admin  (interface Staff/Admin)
--   prof@ead-bzv.cg    → rôle teacher
--   eleve@ead-bzv.cg   → rôle student
--   parent@ead-bzv.cg  → rôle parent
-- ============================================================

begin;

-- ── Identifiants fixes (pour cohérence users <-> students) ───────────────────
-- admin   : d0000000-0000-0000-0000-000000000001
-- teacher : d0000000-0000-0000-0000-000000000002
-- student : d0000000-0000-0000-0000-000000000003  (users.id == students.id)
-- parent  : d0000000-0000-0000-0000-000000000004

-- ════════════════════════════════════════════════════════════════════════════
-- 1. COMPTES AUTH (auth.users + auth.identities)
--    Si cette section échoue selon ta version de Supabase, crée les 4 comptes
--    manuellement via Authentication > Add user (mêmes emails / mot de passe),
--    puis garde les UUID ci-dessus en mettant à jour users.auth_uid.
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
-- 2. PROFILS (public.users) — reliés aux comptes auth via auth_uid
-- ════════════════════════════════════════════════════════════════════════════
insert into public.users (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
values
  ('d0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000001','Direction EAD','admin@ead-bzv.cg','admin','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000002','Jean Makaya','prof@ead-bzv.cg','teacher','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','Grace Mabiala','eleve@ead-bzv.cg','student','active', now(), now()),
  ('d0000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000004','Pauline Mabiala','parent@ead-bzv.cg','parent','active', now(), now())
on conflict (id) do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 2b. PROFILS (public.profiles) — 2ᵉ système d'identité de la base.
--     invoices.student_id et attendance.student_id pointent ICI (pas vers users).
--     Mêmes UUID que users pour garder la cohérence.
-- ════════════════════════════════════════════════════════════════════════════
insert into public.profiles (id, school_id, entity_type, full_name, email, active, created_at, updated_at)
values
  ('d0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','staff','Direction EAD','admin@ead-bzv.cg', true, now(), now()),
  ('d0000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','teacher','Jean Makaya','prof@ead-bzv.cg', true, now(), now()),
  ('d0000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','student','Grace Mabiala','eleve@ead-bzv.cg', true, now(), now()),
  ('d0000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','parent','Pauline Mabiala','parent@ead-bzv.cg', true, now(), now())
on conflict (id) do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 3. ÉLÈVE (public.students) — même id que le profil pour cohérence
-- ════════════════════════════════════════════════════════════════════════════
insert into public.students (id, nom, prenom, email, niveau, classe, matricule, parent_id, actif)
values
  ('d0000000-0000-0000-0000-000000000003','Mabiala','Grace','eleve@ead-bzv.cg','collegien','4ème A','EAD-2025-001','d0000000-0000-0000-0000-000000000004', true)
on conflict (id) do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 4. CLASSE
-- ════════════════════════════════════════════════════════════════════════════
insert into public.classes (id, school_id, name, level, section, academic_year, main_teacher_id, room, max_students, is_active, created_at, updated_at)
values
  ('c0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','4ème A','college','A','2025-2026','d0000000-0000-0000-0000-000000000002','Salle 12', 35, true, now(), now())
on conflict (id) do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 5. MATIÈRES
-- ════════════════════════════════════════════════════════════════════════════
insert into public.subjects (id, school_id, name, code, coefficient, is_active, created_at)
values
  ('50000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Mathématiques','MATH', 4, true, now()),
  ('50000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Français','FR', 4, true, now()),
  ('50000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Anglais','ANG', 2, true, now()),
  ('50000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','SVT','SVT', 2, true, now()),
  ('50000000-0000-0000-0000-000000000005','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Histoire-Géographie','HG', 2, true, now()),
  ('50000000-0000-0000-0000-000000000006','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','Physique-Chimie','PC', 3, true, now())
on conflict (id) do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. NOTES (de l'élève Grace Mabiala)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.grades (id, school_id, student_id, subject_id, class_id, teacher_id, score, max_score, type, title, period, academic_year, graded_at, created_at, updated_at)
values
  ('60000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 15.5, 20, 'devoir','Devoir 1 — Théorème de Pythagore','T1','2025-2026', now(), now(), now()),
  ('60000000-0000-0000-0000-000000000002','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 13, 20, 'examen','Composition — Dissertation','T1','2025-2026', now(), now(), now()),
  ('60000000-0000-0000-0000-000000000003','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 17, 20, 'controle','Interro — Vocabulary','T1','2025-2026', now(), now(), now()),
  ('60000000-0000-0000-0000-000000000004','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000004','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 12.5, 20, 'devoir','Devoir — La cellule','T1','2025-2026', now(), now(), now()),
  ('60000000-0000-0000-0000-000000000005','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000006','c0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000002', 14, 20, 'devoir','Devoir — Les états de la matière','T1','2025-2026', now(), now(), now())
on conflict (id) do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. FACTURE (scolarité de l'élève)
-- ════════════════════════════════════════════════════════════════════════════
insert into public.invoices (id, school_id, student_id, invoice_number, description, amount, currency, due_date, issued_date, status, category, created_by, created_at, updated_at)
values
  ('f0000000-0000-0000-0000-000000000001','de3764d3-f0e6-4191-ba89-ab4c73cf37a1','d0000000-0000-0000-0000-000000000003','FAC-2025-0001','Frais de scolarité — Trimestre 1', 150000, 'XAF', (now() + interval '15 days')::date, now()::date, 'pending','tuition','d0000000-0000-0000-0000-000000000001', now(), now())
on conflict (id) do nothing;

commit;

-- ════════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION (optionnel) :
--   select email, role from public.users where school_id = 'de3764d3-f0e6-4191-ba89-ab4c73cf37a1';
--   select count(*) from public.grades where student_id = 'd0000000-0000-0000-0000-000000000003';
-- ════════════════════════════════════════════════════════════════════════════
