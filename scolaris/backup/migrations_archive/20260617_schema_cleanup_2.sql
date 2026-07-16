-- ============================================================
-- SCOLARIS — Nettoyage du schema (PASSE 2 : doublons FR redondants)
-- A relire PUIS exécuter manuellement dans : Supabase Dashboard > SQL Editor
--
-- Suite de 20260617_schema_cleanup.sql (passe 1, 63 -> 41 tables).
-- Cette passe supprime 9 tables en FRANCAIS qui doublonnent une table anglaise
-- deja presente, et que le code Flutter ne lit JAMAIS (verifie : aucun
-- `.from('<table>')`). Leurs lignes sont des residus de demo de l'ancienne
-- generation du schema ; la version anglaise est la source de verite. Pas de
-- migration de donnees (l'app ne les expose nulle part).
--
-- ⚠️ DECISIONS DE PRUDENCE (ne PAS inclure ici) :
--   • filieres        : GARDEE — 114/115 classes ont un filiere_id rempli
--                       (FK active classes.filiere_id). Pas un vrai doublon.
--   • student_profiles / teacher_profiles / user_settings : GARDEES — donnees
--     riches et bien modelisees (matricule, moyenne, rang ; specialisation ;
--     preferences UI). Leur adoption vs la table `students` est une decision
--     d'architecture (passe 3), pas un nettoyage.
--
-- ⚠️ DESTRUCTIF & IRREVERSIBLE. Backup avant. Idempotent (IF EXISTS).
-- ============================================================

begin;

-- Notes (FR) -> public.grades (utilisee par l'app)
drop table if exists public.notes          cascade;  -- 14 lignes

-- Annonces (FR) -> public.announcements (utilisee par l'app)
drop table if exists public.annonces       cascade;  --  7 lignes

-- Cours / unites (FR) -> public.courses (canonique EN)
drop table if exists public.modules_ue     cascade;  --  8 lignes
drop table if exists public.cours          cascade;  -- 13 lignes

-- Devoirs & rendus (FR) -> public.assignments / public.submissions (canonique EN)
drop table if exists public.depot_travaux  cascade;  --  4 lignes
drop table if exists public.devoirs        cascade;  --  9 lignes

-- Examens (FR) -> public.exams (canonique EN)
drop table if exists public.examens        cascade;  --  8 lignes

-- Ressources (FR) -> public.resources (canonique EN ; biblio active = bibliotheque)
drop table if exists public.ressources     cascade;  --  8 lignes

-- Paiements (FR) -> public.payments (canonique EN ; facturation active = invoices)
drop table if exists public.paiements      cascade;  --  9 lignes

commit;

-- ============================================================
-- Bilan passe 2 : -9 tables (41 -> 32).
-- Schema passe de 63 (depart) a 32 tables, soit -49 %.
--
-- Reste (decisions, pas du nettoyage) :
--   • Passe 3 — Identite : trancher le modele canonique entre
--     users / profiles / students / student_profiles / teacher_profiles,
--     uniformiser les FK (grades/absences->users vs invoices/attendance->profiles),
--     puis adapter le code (supabase_db_source.dart) + migrer les donnees.
--   • Aligner l'enum plan_type (free/pro/enterprise) sur les offres
--     Simple/Pro/Max + creer la table `subscriptions`.
-- ============================================================
