-- ============================================================
-- SCOLARIS — Nettoyage du schema (PASSE 1 : modules jamais branches)
-- A relire PUIS exécuter manuellement dans : Supabase Dashboard > SQL Editor
--
-- Contexte : l'introspection (voir 20260617_schema_baseline.sql) a revele 63
-- tables = deux generations de schema empilees. L'app n'en requete que ~18.
-- Cette passe supprime UNIQUEMENT des modules morts, jamais branches au code
-- Flutter (verifie : aucun `.from('<table>')` ne les vise). Aucune table active
-- n'est touchee. Les doublons FR (notes/cours/paiements...) et la consolidation
-- d'identite (student_profiles/teacher_profiles) sont reportes a une passe 2.
--
-- CASCADE : retire aussi les contraintes FK des tables GARDEES qui pointaient
-- vers ces tables (messages.conversation_id, profiles.role_id). Les colonnes
-- orphelines correspondantes sont nettoyees explicitement en fin de script.
--
-- ⚠️ DESTRUCTIF & IRREVERSIBLE. Faire un backup (Dashboard > Database > Backups)
--    avant d'executer. Idempotent : IF EXISTS => rejouable sans erreur.
-- ============================================================

begin;

-- ── Permissions legacy (remplacees par l'enum public.user_role) ──────────────
drop table if exists public.roles_permissions   cascade;  -- 43 lignes
drop table if exists public.permission_scopes    cascade;  -- 42 lignes
drop table if exists public.roles                cascade;  --  0 lignes

-- ── Emploi du temps legacy (non branche) ─────────────────────────────────────
drop table if exists public.schedule_slots       cascade;  --  0 lignes
drop table if exists public.schedules            cascade;  -- 46 lignes

-- ── Module Forum / collaboration (abandonne) ─────────────────────────────────
drop table if exists public.forum_upvotes        cascade;  --  0 lignes
drop table if exists public.forum_reponses       cascade;  --  1 ligne
drop table if exists public.forum_comments       cascade;  --  0 lignes
drop table if exists public.forum_posts          cascade;  --  4 lignes
drop table if exists public.membres_groupe       cascade;  --  2 lignes
drop table if exists public.groupes_collaboration cascade;  --  2 lignes

-- ── Messagerie alternative (l'app utilise public.messages) ───────────────────
drop table if exists public.conversation_participants cascade;  -- 0 lignes
drop table if exists public.conversations        cascade;  --  0 lignes

-- ── Comptabilite avancee (non branchee) ──────────────────────────────────────
drop table if exists public.expenses             cascade;  --  0 lignes
drop table if exists public.expense_categories   cascade;  --  0 lignes

-- ── Tables d'infrastructure vides / inutilisees ──────────────────────────────
drop table if exists public.campuses             cascade;  --  0 lignes (cf. school_branches)
drop table if exists public.enrollments          cascade;  --  0 lignes
drop table if exists public.report_cards         cascade;  --  0 lignes
drop table if exists public.class_subjects       cascade;  --  0 lignes
drop table if exists public.audit_log            cascade;  --  0 lignes
drop table if exists public.device_sessions      cascade;  --  0 lignes
drop table if exists public.notifications        cascade;  --  3 lignes

-- ── Nettoyage des colonnes orphelines laissees par les CASCADE ci-dessus ─────
alter table public.messages drop column if exists conversation_id;  -- pointait vers conversations
alter table public.profiles drop column if exists role_id;          -- pointait vers roles

commit;

-- ============================================================
-- Bilan passe 1 : -22 tables (63 -> 41). Restera a traiter en passe 2 :
--   • Doublons FR a fusionner : notes, cours, modules_ue, paiements, devoirs,
--     depot_travaux, examens, ressources, annonces, filieres.
--   • Identite a consolider : student_profiles, teacher_profiles, user_settings.
--   • Decision EN canonique vs bibliotheque : courses, resources.
-- ============================================================
