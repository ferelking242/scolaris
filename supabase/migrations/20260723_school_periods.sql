-- ============================================================================
--  20260723_school_periods.sql — Le decoupage de l'annee appartient a l'ECOLE
--
--  Symptome : « new row for relation "grades" violates check constraint
--  "grades_period_check" » des qu'on saisit une note.
--
--  Cause : l'application parlait DEUX langues.
--    • saisie des notes (carnet du prof, page admin)  →  'S1' 'S2' 'S3'  (« Semestre »)
--    • bulletin et espace eleve                       →  'T1' 'T2' 'T3'  (« trimestre »)
--
--  La base n'accepte que les trimestres : la saisie etait donc refusee. Et meme
--  sans cette contrainte, le bug aurait ete PIRE et silencieux : le bulletin
--  cherche les notes de 'T1', on les ecrivait dans 'S1'. On aurait rempli un
--  tiroir que personne ne relit — des notes saisies, des bulletins vides.
--
--  Le fond du probleme : le nombre de periodes etait code en dur, alors qu'il
--  depend de l'etablissement. Un lycee congolais est en TRIMESTRES (3). Une
--  universite est en SEMESTRES (2). Comme la devise et le bareme, c'est un
--  reglage de l'ecole.
-- ============================================================================

-- ── 1. Le reglage ───────────────────────────────────────────────────────────
alter table public.schools
  add column if not exists period_system text not null default 'trimester'
  check (period_system in ('trimester', 'semester'));

comment on column public.schools.period_system is
  'Decoupage de l''annee : trimester → T1/T2/T3 (primaire, college, lycee) ;
   semester → S1/S2 (universite, LMD). Determine les periodes de notation et de
   bulletin. Cf. SchoolFormat cote Dart.';

-- Les universites passent en semestres ; tout le reste reste en trimestres.
update public.schools
   set period_system = 'semester'
 where metadata -> 'types' ? 'universite';

-- ── 2. La contrainte, ecrite ici plutot que posee a la main sur le serveur ──
--  Elle existait en base sans figurer dans aucune migration. On la reprend, en
--  acceptant les deux vocabulaires : chaque ecole n'en utilise qu'un.
alter table public.grades drop constraint if exists grades_period_check;
alter table public.grades
  add constraint grades_period_check
  check (period is null or period in ('T1','T2','T3','S1','S2'));

-- Meme vocabulaire pour les bulletins : c'est la meme periode.
alter table public.report_cards drop constraint if exists report_cards_period_check;
alter table public.report_cards
  add constraint report_cards_period_check
  check (period in ('T1','T2','T3','S1','S2'));

-- ── 3. Les notes deja saisies en 'S*' dans une ecole en trimestres ──────────
--  Il ne devrait pas y en avoir (la contrainte les refusait), mais si la
--  contrainte a ete posee apres coup, ces lignes existent et sont invisibles au
--  bulletin. On les rapatrie : S1→T1, S2→T2, S3→T3.
update public.grades g
   set period = case g.period
         when 'S1' then 'T1' when 'S2' then 'T2' when 'S3' then 'T3'
       end
  from public.schools s
 where s.id = g.school_id
   and s.period_system = 'trimester'
   and g.period in ('S1','S2','S3');

-- ============================================================================
--  VERIFICATION :
--    select period_system, count(*) from public.schools group by 1;
--    select period, count(*) from public.grades group by 1 order by 1;
-- ============================================================================
