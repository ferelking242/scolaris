-- ============================================================================
--  20260714_schema_reconcile.sql — Reconciliation schema vs base live
--
--  Corrige deux ecarts constates le 13/07/2026 en comparant les migrations
--  rejouees a la base reelle (projet iaxwvgqusxyhmyansawi).
--
--  A jouer en dernier : c'est un filet de securite, pas une migration
--  fonctionnelle. Sur la base existante, elle est sans effet.
-- ============================================================================

-- 1. Tables fantomes (bug d'ordre de rejeu) ---------------------------------
--
--    20260617_identity_p3.sql supprime students/profiles, mais porte la meme
--    date que 20260617_schema_baseline.sql qui les cree. A date egale, les
--    migrations sont rejouees par ordre alphabetique : identity_p3 passe AVANT
--    schema_baseline, donc le drop est annule par la creation qui suit.
--
--    Sur une base neuve, ces deux tables (doublons FR abandonnes) reapparaissent
--    donc alors qu'elles sont absentes de la base live. On les retire ici, une
--    fois que toutes les migrations du 17/06 sont passees.

drop table if exists public.students cascade;
drop table if exists public.profiles cascade;

-- 2. Derive de public.courses ------------------------------------------------
--
--    Ces 6 colonnes existent en base mais n'ont jamais ete versionnees :
--    elles ont ete ajoutees directement sur le serveur.

alter table public.courses add column if not exists description     text;
alter table public.courses add column if not exists room            text;
alter table public.courses add column if not exists color           text     default '#8B1A00';
alter table public.courses add column if not exists days_of_week    text[]   default '{}';
alter table public.courses add column if not exists chapter_count   integer  default 0;
alter table public.courses add column if not exists program_summary text;
