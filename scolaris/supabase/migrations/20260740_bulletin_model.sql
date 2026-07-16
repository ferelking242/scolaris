-- ============================================================================
--  20260740_bulletin_model.sql — Le bulletin congolais : devoirs, composition,
--  et une moyenne qui n'est pas une moyenne bete
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  Le bulletin de l'app calculait la moyenne d'une matiere comme la moyenne
--  ARITHMETIQUE de toutes ses notes, tous types confondus. Un vrai bulletin
--  (Complexe Scolaire Bilingue Felix Eboue, Brazzaville) fait autre chose :
--
--      Matiere    Devoir 1  Devoir 2   D.D     M.C    Compo   Coef   Moy
--      Francais    12,50     10,00    13,00   11,83   12,50    3    12,17
--
--      M.C  = moyenne des DEVOIRS            (12,50+10,00+13,00)/3 = 11,83
--      Moy  = (M.C + Compo) / 2              (11,83 + 12,50)/2     = 12,17
--
--  La COMPOSITION pese autant que tous les devoirs reunis. Notre moyenne bete
--  aurait donne (12,50+10+13+12,50)/4 = 12,00 — pas 12,17. Faux bulletin, faux
--  rang, fausse mention, faux passage en classe superieure.
--
--  Et pour ecrire « Devoir 1 » puis « Devoir 2 », il fallait pouvoir les
--  DISTINGUER. Or `grades` est unique sur (eleve, matiere, periode, type) : la
--  deuxieme note de type « devoir » ECRASAIT la premiere. Le modele ne savait
--  pas compter jusqu'a deux.
--
--  ── La decision ─────────────────────────────────────────────────────────────
--
--  Le nombre de devoirs et le poids de la composition appartiennent a l'ECOLE,
--  pas au code. Meme lecon que les trimestres/semestres et que le bareme : une
--  regle nationale figee dans le code est une bombe a retardement le jour ou
--  une ecole note autrement.
-- ============================================================================

-- ── 1. La formule appartient a l'ecole ──────────────────────────────────────
alter table public.schools
  add column if not exists bulletin_devoirs smallint not null default 3,
  add column if not exists bulletin_compo_weight numeric(3,2) not null default 0.50;

alter table public.schools drop constraint if exists schools_bulletin_devoirs_check;
alter table public.schools
  add constraint schools_bulletin_devoirs_check
  check (bulletin_devoirs between 1 and 6);

alter table public.schools drop constraint if exists schools_bulletin_compo_check;
alter table public.schools
  add constraint schools_bulletin_compo_check
  check (bulletin_compo_weight >= 0 and bulletin_compo_weight <= 1);

comment on column public.schools.bulletin_devoirs is
  'Combien de devoirs par matiere et par periode (CSBFE : 3 — Devoir 1, Devoir 2,
   D.D). Leur moyenne forme la « M.C ».';
comment on column public.schools.bulletin_compo_weight is
  'Poids de la COMPOSITION dans la moyenne de la matiere. 0.50 (CSBFE) :
   Moy = M.C x 0.5 + Compo x 0.5 — la compo pese autant que tous les devoirs.
   0.33 ferait Moy = (2 x M.C + Compo)/3. 0 = pas de composition.';

-- ── 2. Une note sait desormais dire « je suis le deuxieme devoir » ──────────
alter table public.grades
  add column if not exists sequence smallint not null default 1;

comment on column public.grades.sequence is
  'Rang de la note dans son type : Devoir 1, Devoir 2, D.D = devoirs 1, 2, 3.
   La composition n''en a qu''une (1). Sans cette colonne, la 2e note d''un meme
   type ecrasait la 1re — le modele ne savait pas compter jusqu''a deux.';

--  L'unicite doit inclure la sequence, sinon l'upsert du carnet continue
--  d'ecraser. On remplace la contrainte de 20260618.
alter table public.grades drop constraint if exists grades_student_subject_period_type_key;
drop index if exists public.grades_student_subject_period_type_key;

--  Dedoublonnage prealable : si deux notes du meme type existaient deja (elles
--  ne le devraient pas — la contrainte l'interdisait — mais on ne fait pas
--  confiance au depot pour connaitre l'etat du serveur), on les numerote.
with ranked as (
  select id,
         row_number() over (
           partition by student_id, subject_id, period, type
           order by graded_at nulls last, created_at nulls last, id
         ) as rn
    from public.grades
)
update public.grades g
   set sequence = r.rn
  from ranked r
 where r.id = g.id
   and r.rn > 1;

alter table public.grades
  add constraint grades_student_subject_period_type_seq_key
  unique (student_id, subject_id, period, type, sequence);

-- ── 3. Ce que le bulletin doit garder, et qu'il ne gardait pas ─────────────
--  Le conseil de classe, les absences, le rang, la moyenne de la classe, le
--  premier et le dernier : tout cela figure sur le document que le parent
--  emporte. Un bulletin est une PHOTO — il doit rester lisible dans dix ans,
--  meme si l'eleve a change de classe et l'ecole de coefficients.
alter table public.report_cards
  add column if not exists class_average  numeric,   -- moyenne de la classe
  add column if not exists best_average   numeric,   -- le premier
  add column if not exists worst_average  numeric,   -- le dernier
  add column if not exists absences_count integer not null default 0,
  add column if not exists late_count     integer not null default 0,
  add column if not exists decision       text,      -- ADMIS(E) / REDOUBLE…
  add column if not exists council_comment text;     -- « Bon travail »

comment on column public.report_cards.lines is
  'Lignes FIGEES du bulletin. Depuis 20260740, chacune porte le detail :
   { "subject": "Francais", "coef": 3, "devoirs": [12.5, 10, 13], "mc": 11.83,
     "compo": 12.5, "average": 12.17, "total": 36.5, "rank": 3,
     "appreciation": "Assez-Bien" }
   Le rang (« RG ») est celui de l''eleve DANS CETTE MATIERE.';

-- ============================================================================
--  VERIFICATION :
--
--    select name, bulletin_devoirs, bulletin_compo_weight from public.schools;
--
--    -- Aucune note perdue ? (doit renvoyer le meme nombre qu'avant)
--    select count(*) from public.grades;
--
--    -- Le carnet peut-il ecrire deux devoirs ?
--    select student_id, subject_id, period, type, sequence, score
--      from public.grades order by student_id, subject_id, type, sequence limit 20;
-- ============================================================================
