-- ============================================================
-- SCOLARIS — Baseline du schema reel (introspection PostgREST)
-- Genere le 2026-06-17 depuis le projet iaxwvgqusxyhmyansawi.
-- Source: spec OpenAPI PostgREST => schema public (tables, colonnes, types,
-- PK, FK, types enum). C'est la PREMIERE source de verite versionnee du schema.
--
-- LIMITES (introspection API, pas un pg_dump) : ne capture PAS les valeurs
-- DEFAULT, triggers, fonctions, policies RLS, index non-PK, ni CHECK. Pour un
-- dump 100% fidele : `supabase db dump` (necessite le mot de passe Postgres).
-- Sert de reference/documentation et de base pour assainir le schema.
-- ============================================================

-- ── Types enum ─────────────────────────────────────────────
DO $$ BEGIN CREATE TYPE public.resource_type AS ENUM ('pdf', 'video', 'link', 'doc', 'exam', 'correction', 'audio', 'image'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.resource_visibility AS ENUM ('all', 'class', 'role', 'private'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.user_role AS ENUM ('student', 'parent', 'teacher', 'admin', 'staff_custom', 'surveillance', 'finance'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.announcement_target AS ENUM ('all', 'students', 'parents', 'teachers', 'admin'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.announcement_priority AS ENUM ('normal', 'important', 'urgent'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.submission_status AS ENUM ('pending', 'submitted', 'late', 'graded', 'rejected'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.account_status AS ENUM ('active', 'suspended', 'pending'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.plan_type AS ENUM ('free', 'pro', 'enterprise'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE public.db_mode AS ENUM ('central', 'self_hosted'); EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ── Tables ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.absences (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  class_id uuid NOT NULL,
  subject_id uuid,
  teacher_id uuid,
  absence_date date NOT NULL,
  period text,
  justified boolean,
  reason text,
  justification_url text,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.annonces (
  id uuid NOT NULL,
  titre text NOT NULL,
  contenu text NOT NULL,
  date date NOT NULL,
  categorie text,
  auteur text NOT NULL,
  niveau_cible text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.announcement_comments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  announcement_id uuid NOT NULL,
  user_id uuid NOT NULL,
  content text NOT NULL,
  parent_id uuid,
  likes_count integer,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.announcement_likes (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  announcement_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.announcements (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  author_id uuid NOT NULL,
  title text NOT NULL,
  content text NOT NULL,
  target_role public.announcement_target NOT NULL,
  priority public.announcement_priority NOT NULL,
  target_class_id uuid,
  image_url text,
  is_pinned boolean,
  is_published boolean,
  likes_count integer,
  comments_count integer,
  views_count integer,
  expires_at timestamptz,
  published_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.assignments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  instructions text,
  max_score numeric,
  deadline timestamptz NOT NULL,
  allow_late boolean,
  attachment_urls jsonb,
  is_published boolean,
  submissions_count integer,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.attendance (
  id uuid NOT NULL,
  student_id uuid,
  class_id uuid,
  subject_id uuid,
  recorded_by uuid,
  date date NOT NULL,
  status text NOT NULL,
  arrival_time time,
  note text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid NOT NULL,
  actor_id uuid,
  action text NOT NULL,
  table_name text,
  record_id text,
  old_data jsonb,
  new_data jsonb,
  ip_address text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.bibliotheque (
  id uuid NOT NULL,
  titre text NOT NULL,
  auteur text,
  type text NOT NULL,
  domaine text NOT NULL,
  annee text,
  url text,
  acces text,
  resume text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.campuses (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  city text,
  is_main boolean,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.class_levels (
  id uuid NOT NULL,
  system_type text NOT NULL,
  cycle text NOT NULL,
  cycle_label text NOT NULL,
  name text NOT NULL,
  short_name text NOT NULL,
  order_num integer NOT NULL,
  series text,
  country_hint text[],
  metadata jsonb,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.class_subjects (
  id uuid NOT NULL,
  class_id uuid,
  subject_id uuid,
  teacher_id uuid,
  hours_per_week integer,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.classes (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  level text,
  section text,
  academic_year text,
  main_teacher_id uuid,
  room text,
  max_students integer,
  color text,
  is_active boolean,
  metadata jsonb,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  filiere_id uuid,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.conversation_participants (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  user_id uuid NOT NULL,
  last_read_at timestamptz,
  is_muted boolean,
  joined_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  title text,
  is_group boolean,
  created_by uuid,
  last_message_at timestamptz,
  last_message text,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.cours (
  id uuid NOT NULL,
  student_id uuid,
  classe text NOT NULL,
  matiere text NOT NULL,
  professeur text NOT NULL,
  salle text NOT NULL,
  heure_debut time NOT NULL,
  heure_fin time NOT NULL,
  jour text NOT NULL,
  couleur text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.courses (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid,
  name text NOT NULL,
  code text,
  teacher_id uuid,
  coef integer,
  hours_week integer,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.depot_travaux (
  id uuid NOT NULL,
  student_id uuid,
  module_code text,
  titre text NOT NULL,
  description text,
  fichier_url text,
  date_depot timestamptz,
  date_limite timestamptz NOT NULL,
  statut text,
  note numeric,
  commentaire_prof text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.device_sessions (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  user_id uuid NOT NULL,
  device_name text,
  device_type text,
  platform text,
  ip_address text,
  location text,
  push_token text,
  is_active boolean,
  last_active_at timestamptz,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.devoirs (
  id uuid NOT NULL,
  student_id uuid,
  matiere text NOT NULL,
  titre text NOT NULL,
  description text,
  date_limite date NOT NULL,
  statut text,
  priorite text,
  fichier_url text,
  created_at timestamptz,
  updated_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.enrollments (
  id uuid NOT NULL,
  student_id uuid,
  class_id uuid,
  academic_year text,
  enrollment_date date,
  status text,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.examens (
  id uuid NOT NULL,
  titre text NOT NULL,
  matiere text,
  date date NOT NULL,
  heure time NOT NULL,
  lieu text,
  type text,
  niveau text NOT NULL,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.exams (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  teacher_id uuid,
  title text NOT NULL,
  type text,
  exam_date timestamptz NOT NULL,
  duration_mins integer,
  room text,
  max_score numeric,
  coefficient numeric,
  instructions text,
  period text,
  academic_year text,
  is_published boolean,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.expense_categories (
  id uuid NOT NULL,
  school_id uuid,
  name text NOT NULL,
  parent_id uuid,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid NOT NULL,
  school_id uuid,
  category_id uuid,
  description text NOT NULL,
  amount numeric NOT NULL,
  currency text,
  expense_date date,
  approved_by uuid,
  receipt_url text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.filieres (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  department text,
  description text,
  color_hex text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.forum_comments (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  post_id uuid NOT NULL,
  author_id uuid NOT NULL,
  content text NOT NULL,
  parent_id uuid,
  upvotes integer,
  is_accepted boolean,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.forum_posts (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  author_id uuid NOT NULL,
  class_id uuid,
  subject_id uuid,
  title text NOT NULL,
  content text NOT NULL,
  tags text[],
  upvotes integer,
  comments_count integer,
  views_count integer,
  is_pinned boolean,
  is_resolved boolean,
  is_published boolean,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.forum_reponses (
  id uuid NOT NULL,
  post_id uuid,
  auteur_id uuid,
  auteur_nom text NOT NULL,
  contenu text NOT NULL,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.forum_upvotes (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.grades (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  class_id uuid NOT NULL,
  teacher_id uuid,
  score numeric NOT NULL,
  max_score numeric NOT NULL,
  weight numeric,
  type text,
  title text,
  comment text,
  academic_year text,
  period text,
  graded_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.groupes_collaboration (
  id uuid NOT NULL,
  nom text NOT NULL,
  module_code text,
  description text,
  actif boolean,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid NOT NULL,
  school_id uuid,
  student_id uuid,
  invoice_number text,
  description text NOT NULL,
  amount numeric NOT NULL,
  currency text,
  due_date date,
  issued_date date,
  status text,
  category text,
  notes text,
  created_by uuid,
  created_at timestamptz,
  updated_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.membres_groupe (
  id uuid NOT NULL,
  groupe_id uuid,
  student_id uuid,
  role text,
  joined_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  attachment_urls jsonb,
  message_type text,
  is_edited boolean,
  read_by uuid[],
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.modules_ue (
  id uuid NOT NULL,
  student_id uuid,
  code text NOT NULL,
  intitule text NOT NULL,
  credits integer NOT NULL,
  note numeric,
  statut text,
  semestre integer NOT NULL,
  annee_academique text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.notes (
  id uuid NOT NULL,
  student_id uuid,
  matiere text NOT NULL,
  note numeric NOT NULL,
  note_max numeric,
  type text NOT NULL,
  date date NOT NULL,
  trimestre integer NOT NULL,
  semestre integer,
  commentaire text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  user_id uuid NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  message text,
  action_url text,
  entity_type text,
  entity_id uuid,
  is_read boolean,
  read_at timestamptz,
  delivered_push boolean,
  delivered_email boolean,
  metadata jsonb,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.paiements (
  id uuid NOT NULL,
  student_id uuid,
  libelle text NOT NULL,
  montant numeric NOT NULL,
  statut text,
  date_echeance date NOT NULL,
  date_paiement date,
  methode text,
  reference_paiement text,
  recu_url text,
  created_at timestamptz,
  updated_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.parent_student (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  parent_id uuid NOT NULL,
  student_id uuid NOT NULL,
  relationship text,
  is_primary boolean,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.payments (
  id uuid NOT NULL,
  invoice_id uuid,
  student_id uuid,
  amount numeric NOT NULL,
  payment_date date,
  payment_method text,
  reference text,
  received_by uuid,
  notes text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.permission_scopes (
  id text NOT NULL,
  parent_id text,
  label_fr text NOT NULL,
  label_en text NOT NULL,
  description_fr text,
  description_en text,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid NOT NULL,
  school_id uuid,
  role_id uuid,
  entity_type text NOT NULL,
  full_name text NOT NULL,
  email text NOT NULL,
  phone text,
  avatar_url text,
  date_of_birth date,
  gender text,
  address text,
  nationality text,
  emergency_contact text,
  active boolean,
  custom_permissions text[],
  denied_permissions text[],
  created_at timestamptz,
  updated_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.report_cards (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  class_id uuid NOT NULL,
  period text NOT NULL,
  academic_year text,
  average numeric,
  rank_in_class integer,
  total_students integer,
  absences_count integer,
  teacher_comment text,
  principal_comment text,
  is_published boolean,
  published_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.resources (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  author_id uuid NOT NULL,
  subject_id uuid,
  class_id uuid,
  title text NOT NULL,
  description text,
  type public.resource_type NOT NULL,
  file_url text,
  thumbnail_url text,
  file_size_kb integer,
  visibility public.resource_visibility NOT NULL,
  downloads_count integer,
  views_count integer,
  tags text[],
  academic_year text,
  is_published boolean,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.ressources (
  id uuid NOT NULL,
  matiere text NOT NULL,
  titre text NOT NULL,
  type text NOT NULL,
  url text NOT NULL,
  date date NOT NULL,
  niveau text NOT NULL,
  taille_fichier bigint,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.roles (
  id uuid NOT NULL,
  school_id uuid,
  name text NOT NULL,
  entity_type text NOT NULL,
  is_system_default boolean,
  permissions text[],
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.roles_permissions (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  role public.user_role NOT NULL,
  permission_key text NOT NULL,
  allowed boolean NOT NULL,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.schedule_slots (
  id uuid NOT NULL,
  class_id uuid,
  subject_id uuid,
  teacher_id uuid,
  day_of_week integer NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  room text,
  academic_year text,
  effective_from date,
  effective_to date,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.schedules (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  teacher_id uuid,
  day_of_week smallint NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  room text,
  academic_year text,
  is_active boolean,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.school_branches (
  id uuid NOT NULL,
  school_id uuid,
  name text,
  city text NOT NULL,
  address text NOT NULL,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.school_classes (
  id uuid NOT NULL,
  school_id uuid,
  name text NOT NULL,
  level text,
  teacher_id uuid,
  max_students integer,
  academic_year text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.school_founders (
  id uuid NOT NULL,
  school_id uuid,
  full_name text NOT NULL,
  email text NOT NULL,
  phone text,
  role_label text,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.school_series (
  id uuid NOT NULL,
  school_id uuid,
  name text NOT NULL,
  code text NOT NULL,
  is_active boolean,
  created_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.schools (
  id uuid NOT NULL,
  name text NOT NULL,
  code text,
  country text,
  city text,
  address text,
  logo_url text,
  accent_color text,
  plan_type public.plan_type NOT NULL,
  db_mode public.db_mode NOT NULL,
  db_config jsonb,
  contact_email text,
  contact_phone text,
  website_url text,
  is_active boolean NOT NULL,
  max_students integer,
  academic_year text,
  metadata jsonb,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.student_profiles (
  user_id uuid NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid,
  matricule text,
  date_of_birth date,
  gender text,
  nationality text,
  average_score numeric,
  attendance_rate numeric,
  rank_in_class integer,
  academic_year text,
  notes text,
  metadata jsonb,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS public.students (
  id uuid NOT NULL,
  nom text NOT NULL,
  prenom text NOT NULL,
  email text NOT NULL,
  niveau text NOT NULL,
  classe text NOT NULL,
  matricule text,
  avatar_url text,
  date_naissance date,
  telephone text,
  parent_id uuid,
  actif boolean,
  created_at timestamptz,
  updated_at timestamptz,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.subjects (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  code text,
  color text,
  icon text,
  coefficient numeric,
  is_active boolean,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.submissions (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  student_id uuid NOT NULL,
  content text,
  file_urls jsonb,
  status public.submission_status NOT NULL,
  grade numeric,
  feedback text,
  submitted_at timestamptz,
  graded_at timestamptz,
  is_late boolean,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.teacher_classes (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  class_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  academic_year text,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.teacher_profiles (
  user_id uuid NOT NULL,
  school_id uuid NOT NULL,
  employee_id text,
  specialization text,
  qualification text,
  join_date date,
  metadata jsonb,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id uuid NOT NULL,
  school_id uuid NOT NULL,
  theme text,
  accent_color text,
  language text,
  date_format text,
  timezone text,
  grade_format text,
  notif_push boolean,
  notif_email boolean,
  notif_sms boolean,
  notif_whatsapp boolean,
  notif_freq text,
  silent_start time,
  silent_end time,
  text_size text,
  ui_density text,
  animations_on boolean,
  data_saver boolean,
  offline_mode boolean,
  custom_prefs jsonb,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS public.users (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  auth_uid uuid,
  full_name text NOT NULL,
  email text NOT NULL,
  phone text,
  avatar_url text,
  role public.user_role NOT NULL,
  status public.account_status NOT NULL,
  locale text,
  timezone text,
  last_seen_at timestamptz,
  push_token text,
  metadata jsonb,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (id)
);

-- ── Cles etrangeres ────────────────────────────────────────
ALTER TABLE public.absences ADD CONSTRAINT absences_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.absences ADD CONSTRAINT absences_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id);
ALTER TABLE public.absences ADD CONSTRAINT absences_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.absences ADD CONSTRAINT absences_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.absences ADD CONSTRAINT absences_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
ALTER TABLE public.announcement_comments ADD CONSTRAINT announcement_comments_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.announcement_comments ADD CONSTRAINT announcement_comments_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES public.announcements(id);
ALTER TABLE public.announcement_comments ADD CONSTRAINT announcement_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.announcement_comments ADD CONSTRAINT announcement_comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.announcement_comments(id);
ALTER TABLE public.announcement_likes ADD CONSTRAINT announcement_likes_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.announcement_likes ADD CONSTRAINT announcement_likes_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES public.announcements(id);
ALTER TABLE public.announcement_likes ADD CONSTRAINT announcement_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.announcements ADD CONSTRAINT announcements_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.announcements ADD CONSTRAINT announcements_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id);
ALTER TABLE public.announcements ADD CONSTRAINT announcements_target_class_id_fkey FOREIGN KEY (target_class_id) REFERENCES public.classes(id);
ALTER TABLE public.assignments ADD CONSTRAINT assignments_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.assignments ADD CONSTRAINT assignments_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.assignments ADD CONSTRAINT assignments_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.assignments ADD CONSTRAINT assignments_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.school_classes(id);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.attendance ADD CONSTRAINT attendance_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.profiles(id);
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id);
ALTER TABLE public.campuses ADD CONSTRAINT campuses_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.school_classes(id);
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.class_subjects ADD CONSTRAINT class_subjects_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.profiles(id);
ALTER TABLE public.classes ADD CONSTRAINT classes_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.classes ADD CONSTRAINT classes_main_teacher_id_fkey FOREIGN KEY (main_teacher_id) REFERENCES public.users(id);
ALTER TABLE public.classes ADD CONSTRAINT classes_filiere_id_fkey FOREIGN KEY (filiere_id) REFERENCES public.filieres(id);
ALTER TABLE public.conversation_participants ADD CONSTRAINT conversation_participants_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.conversation_participants ADD CONSTRAINT conversation_participants_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);
ALTER TABLE public.conversation_participants ADD CONSTRAINT conversation_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.conversations ADD CONSTRAINT conversations_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.conversations ADD CONSTRAINT conversations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);
ALTER TABLE public.cours ADD CONSTRAINT cours_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);
ALTER TABLE public.courses ADD CONSTRAINT courses_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.courses ADD CONSTRAINT courses_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.courses ADD CONSTRAINT courses_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.profiles(id);
ALTER TABLE public.depot_travaux ADD CONSTRAINT depot_travaux_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);
ALTER TABLE public.device_sessions ADD CONSTRAINT device_sessions_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.device_sessions ADD CONSTRAINT device_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.devoirs ADD CONSTRAINT devoirs_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);
ALTER TABLE public.enrollments ADD CONSTRAINT enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id);
ALTER TABLE public.enrollments ADD CONSTRAINT enrollments_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.school_classes(id);
ALTER TABLE public.exams ADD CONSTRAINT exams_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.exams ADD CONSTRAINT exams_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.exams ADD CONSTRAINT exams_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.exams ADD CONSTRAINT exams_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
ALTER TABLE public.expense_categories ADD CONSTRAINT expense_categories_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.expense_categories ADD CONSTRAINT expense_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.expense_categories(id);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.expense_categories(id);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.profiles(id);
ALTER TABLE public.filieres ADD CONSTRAINT filieres_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.forum_comments ADD CONSTRAINT forum_comments_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.forum_comments ADD CONSTRAINT forum_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.forum_posts(id);
ALTER TABLE public.forum_comments ADD CONSTRAINT forum_comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id);
ALTER TABLE public.forum_comments ADD CONSTRAINT forum_comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.forum_comments(id);
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id);
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.forum_posts ADD CONSTRAINT forum_posts_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.forum_reponses ADD CONSTRAINT forum_reponses_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.forum_posts(id);
ALTER TABLE public.forum_upvotes ADD CONSTRAINT forum_upvotes_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.forum_upvotes ADD CONSTRAINT forum_upvotes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.forum_posts(id);
ALTER TABLE public.forum_upvotes ADD CONSTRAINT forum_upvotes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.grades ADD CONSTRAINT grades_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.grades ADD CONSTRAINT grades_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id);
ALTER TABLE public.grades ADD CONSTRAINT grades_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.grades ADD CONSTRAINT grades_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.grades ADD CONSTRAINT grades_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);
ALTER TABLE public.membres_groupe ADD CONSTRAINT membres_groupe_groupe_id_fkey FOREIGN KEY (groupe_id) REFERENCES public.groupes_collaboration(id);
ALTER TABLE public.membres_groupe ADD CONSTRAINT membres_groupe_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);
ALTER TABLE public.messages ADD CONSTRAINT messages_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.messages ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);
ALTER TABLE public.messages ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id);
ALTER TABLE public.modules_ue ADD CONSTRAINT modules_ue_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);
ALTER TABLE public.notes ADD CONSTRAINT notes_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);
ALTER TABLE public.notifications ADD CONSTRAINT notifications_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.paiements ADD CONSTRAINT paiements_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);
ALTER TABLE public.parent_student ADD CONSTRAINT parent_student_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.parent_student ADD CONSTRAINT parent_student_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.users(id);
ALTER TABLE public.parent_student ADD CONSTRAINT parent_student_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id);
ALTER TABLE public.payments ADD CONSTRAINT payments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id);
ALTER TABLE public.payments ADD CONSTRAINT payments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id);
ALTER TABLE public.payments ADD CONSTRAINT payments_received_by_fkey FOREIGN KEY (received_by) REFERENCES public.profiles(id);
ALTER TABLE public.permission_scopes ADD CONSTRAINT permission_scopes_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.permission_scopes(id);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);
ALTER TABLE public.report_cards ADD CONSTRAINT report_cards_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.report_cards ADD CONSTRAINT report_cards_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id);
ALTER TABLE public.report_cards ADD CONSTRAINT report_cards_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.resources ADD CONSTRAINT resources_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.resources ADD CONSTRAINT resources_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id);
ALTER TABLE public.resources ADD CONSTRAINT resources_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.resources ADD CONSTRAINT resources_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.roles ADD CONSTRAINT roles_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.roles_permissions ADD CONSTRAINT roles_permissions_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.schedule_slots ADD CONSTRAINT schedule_slots_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.school_classes(id);
ALTER TABLE public.schedule_slots ADD CONSTRAINT schedule_slots_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.schedule_slots ADD CONSTRAINT schedule_slots_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.profiles(id);
ALTER TABLE public.schedules ADD CONSTRAINT schedules_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.schedules ADD CONSTRAINT schedules_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.schedules ADD CONSTRAINT schedules_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.schedules ADD CONSTRAINT schedules_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
ALTER TABLE public.school_branches ADD CONSTRAINT school_branches_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.school_classes ADD CONSTRAINT school_classes_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.school_classes ADD CONSTRAINT school_classes_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.profiles(id);
ALTER TABLE public.school_founders ADD CONSTRAINT school_founders_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.school_series ADD CONSTRAINT school_series_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.student_profiles ADD CONSTRAINT student_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.student_profiles ADD CONSTRAINT student_profiles_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.student_profiles ADD CONSTRAINT student_profiles_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.subjects ADD CONSTRAINT subjects_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.submissions ADD CONSTRAINT submissions_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.submissions ADD CONSTRAINT submissions_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.assignments(id);
ALTER TABLE public.submissions ADD CONSTRAINT submissions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id);
ALTER TABLE public.teacher_classes ADD CONSTRAINT teacher_classes_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.teacher_classes ADD CONSTRAINT teacher_classes_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
ALTER TABLE public.teacher_classes ADD CONSTRAINT teacher_classes_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);
ALTER TABLE public.teacher_classes ADD CONSTRAINT teacher_classes_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);
ALTER TABLE public.teacher_profiles ADD CONSTRAINT teacher_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.teacher_profiles ADD CONSTRAINT teacher_profiles_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.user_settings ADD CONSTRAINT user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
ALTER TABLE public.user_settings ADD CONSTRAINT user_settings_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);
ALTER TABLE public.users ADD CONSTRAINT users_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);

-- Total: 63 tables, 132 FK, 9 types enum.