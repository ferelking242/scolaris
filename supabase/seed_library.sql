-- ============================================================
-- SCOLARIS — Seed BIBLIOTHÈQUE (contenu central de plateforme)
--
-- Fonds de ressources curé par Scolaris, VISIBLE PAR TOUTES LES ÉCOLES Pro/Max
-- (restriction d'accès faite côté app via PlanGate). Indépendant du seed démo :
-- ces tables ne sont PAS liées à `schools`, donc `truncate schools cascade`
-- (seed.sql) ne les efface pas. À exécuter une fois après la migration
-- `20260620_library.sql`.
--
-- Idempotent : UUID fixes + `on conflict (id) do nothing` → ré-exécutable.
--
-- NB : les `url`/`file_url` sont à NULL pour l'instant (le lecteur affiche un
-- contenu d'exemple) — il suffira de les renseigner quand les PDF seront prêts.
-- ============================================================

begin;

-- ── 1. Livres (table `bibliotheque`) ────────────────────────────────────────
--   colonnes : id, titre, auteur, type, domaine, annee, url, resume
--   Contraintes CHECK en base :
--     type  ∈ {livre, memoire, article, rapport, these}  → on utilise 'livre'
--     acces ∈ {libre, restreint}  → laissé au défaut 'libre'
--   (`type` n'est pas affiché dans l'app ; le vrai sujet est `domaine`.)
insert into public.bibliotheque (id, titre, auteur, type, domaine, annee, url, resume, created_at) values
  ('b1000000-0000-0000-0000-000000000001','Mathématiques 4e — Collection IPAM','IPAM','livre','Mathématiques','2021',null,'Manuel complet de mathématiques pour la classe de 4e : nombres relatifs, calcul littéral, géométrie et statistiques.',now()),
  ('b1000000-0000-0000-0000-000000000002','Mathématiques Terminale C','A. Konaté','livre','Mathématiques','2022',null,'Analyse, probabilités, nombres complexes et géométrie dans l''espace pour la Terminale scientifique.',now()),
  ('b1000000-0000-0000-0000-000000000003','Le Français en 3e','M. Loubaki','livre','Français','2020',null,'Grammaire, conjugaison, expression écrite et étude de textes pour préparer le BEPC.',now()),
  ('b1000000-0000-0000-0000-000000000004','Grammaire française — l''essentiel','R. Ngoma','livre','Français','2019',null,'Toutes les règles de grammaire et d''orthographe expliquées avec des exemples.',now()),
  ('b1000000-0000-0000-0000-000000000005','Physique-Chimie 2nde','J. Bouyou','livre','Sciences physiques','2021',null,'Mécanique, optique, transformations chimiques : cours et exercices pour la Seconde.',now()),
  ('b1000000-0000-0000-0000-000000000006','SVT 5e','C. Mabiala','livre','SVT','2020',null,'Le corps humain, la nutrition, la respiration et l''environnement pour la classe de 5e.',now()),
  ('b1000000-0000-0000-0000-000000000007','Histoire-Géographie 4e','P. Samba','livre','Histoire','2021',null,'De la révolution industrielle au monde contemporain, avec cartes et documents.',now()),
  ('b1000000-0000-0000-0000-000000000008','Géographie du Congo','D. Okemba','livre','Géographie','2018',null,'Relief, climat, population et économie du Congo : un panorama complet.',now()),
  ('b1000000-0000-0000-0000-000000000009','Philosophie Terminale','F. Itoua','livre','Philosophie','2022',null,'Les grandes notions du programme : conscience, liberté, vérité, justice, avec méthode de la dissertation.',now()),
  ('b1000000-0000-0000-0000-00000000000a','Initiation à l''informatique','S. Mboungou','livre','Informatique','2023',null,'Découverte de l''ordinateur, bureautique, Internet et premiers pas en algorithmique.',now()),
  ('b1000000-0000-0000-0000-00000000000b','L''Économie pour tous','G. Ondongo','livre','Économie','2020',null,'Notions de base d''économie : production, marché, monnaie et développement.',now()),
  ('b1000000-0000-0000-0000-00000000000c','Anthologie de la littérature africaine','Collectif','livre','Littérature','2017',null,'Extraits choisis des grands auteurs africains francophones, du roman à la poésie.',now())
on conflict (id) do nothing;

-- ── 2. Annales d'examens (table `exam_subjects`) ─────────────────────────────
--   colonnes : id, title, subject, level, session, year, has_correction, url, correction_url
insert into public.exam_subjects (id, title, subject, level, session, year, has_correction, url, correction_url, created_at) values
  ('e1000000-0000-0000-0000-000000000001','CEPE — Mathématiques','Mathématiques','cepe','Juin',2023,true ,null,null,now()),
  ('e1000000-0000-0000-0000-000000000002','CEPE — Français','Français','cepe','Juin',2023,true ,null,null,now()),
  ('e1000000-0000-0000-0000-000000000003','BEPC — Mathématiques','Mathématiques','bepc','Juin',2022,true ,null,null,now()),
  ('e1000000-0000-0000-0000-000000000004','BEPC — Sciences physiques','Sciences physiques','bepc','Juin',2023,false,null,null,now()),
  ('e1000000-0000-0000-0000-000000000005','BEPC — Histoire-Géographie','Histoire','bepc','Juin',2022,true ,null,null,now()),
  ('e1000000-0000-0000-0000-000000000006','BAC C — Mathématiques','Mathématiques','bac','Juin',2023,true ,null,null,now()),
  ('e1000000-0000-0000-0000-000000000007','BAC A — Philosophie','Philosophie','bac','Juin',2023,true ,null,null,now()),
  ('e1000000-0000-0000-0000-000000000008','BAC D — Sciences physiques','Sciences physiques','bac','Juin',2022,false,null,null,now()),
  ('e1000000-0000-0000-0000-000000000009','BAC D — SVT','SVT','bac','Juin',2023,true ,null,null,now()),
  ('e1000000-0000-0000-0000-00000000000a','BAC — Français (anticipée)','Français','bac','Juin',2022,false,null,null,now())
on conflict (id) do nothing;

-- ── 3. Supports de cours (table `course_materials`) ──────────────────────────
--   colonnes : id, title, subject, type, level, publisher, year, file_url, size_kb
insert into public.course_materials (id, title, subject, type, level, publisher, year, file_url, size_kb, created_at) values
  ('a1000000-0000-0000-0000-000000000001','Fiche de révision — Théorème de Thalès','Mathématiques','Fiche','4e','Scolaris',2023,null, 320,now()),
  ('a1000000-0000-0000-0000-000000000002','TD — Équations du 1er degré','Mathématiques','TD','3e','Scolaris',2023,null, 480,now()),
  ('a1000000-0000-0000-0000-000000000003','Cours — La conjugaison des temps','Français','Cours','5e','Scolaris',2022,null,1240,now()),
  ('a1000000-0000-0000-0000-000000000004','Exercices — Les fractions','Mathématiques','Exercices','6e','Scolaris',2023,null, 540,now()),
  ('a1000000-0000-0000-0000-000000000005','Cours — La photosynthèse','SVT','Cours','5e','Scolaris',2022,null, 980,now()),
  ('a1000000-0000-0000-0000-000000000006','Fiche — Les figures de style','Français','Fiche','3e','Scolaris',2023,null, 260,now()),
  ('a1000000-0000-0000-0000-000000000007','Cours — Le mouvement (mécanique)','Sciences physiques','Cours','2nde','Scolaris',2022,null,1520,now()),
  ('a1000000-0000-0000-0000-000000000008','Diaporama — La Guerre froide','Histoire','Diaporama','Terminale','Scolaris',2023,null,2840,now())
on conflict (id) do nothing;

commit;

-- ════════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION :
--   select count(*) from public.bibliotheque;       -- 12 (+ existants)
--   select level, count(*) from public.exam_subjects group by level;
--   select type, count(*) from public.course_materials group by type;
-- ════════════════════════════════════════════════════════════════════════════
