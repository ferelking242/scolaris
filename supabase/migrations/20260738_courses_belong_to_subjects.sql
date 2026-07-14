-- ============================================================================
--  20260738_courses_belong_to_subjects.sql — Un COURS est le programme d'une
--  MATIERE dans une CLASSE
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  Trois notions coexistaient, et l'une d'elles ne servait presque a rien :
--
--    classes    un groupe d'eleves. Le pilier : notes, presences, bulletins,
--               emploi du temps s'y rattachent tous.
--    subjects   le referentiel de l'ecole. Il porte le COEFFICIENT — sans lui,
--               aucune moyenne ponderee, aucun bulletin. `grades.subject_id` et
--               `schedules.subject_id` pointent dessus.
--    courses    une classe, un NOM, un prof, un coefficient, un volume horaire.
--
--  Regardez la troisieme ligne : un cours porte un `name`, PAS un `subject_id`.
--  Il n'est relie a aucune matiere. Donc :
--
--    • aucune note ne pointe vers un cours (elles vont a la matiere) ;
--    • l'emploi du temps ne l'utilise pas (il relie classe + matiere + prof) ;
--    • le carnet du prof ne l'utilise pas ;
--    • son `coef` est IGNORE — le bulletin lit celui de la matiere.
--
--  « Qui enseigne quoi dans quelle classe » etait donc ecrit DEUX fois : dans
--  l'emploi du temps, qui est branche sur tout, et dans les cours, qui ne sont
--  branches sur rien. Et comme rien ne les relie, on pouvait declarer un cours
--  de maths avec M. Ngoubili et un creneau de maths avec Mme Ibara, dans la
--  meme classe, sans que personne ne voie la contradiction.
--
--  Meme famille de bug que 'S1' contre 'T1' : deux moities d'une idee qui ne se
--  parlent jamais.
--
--  ── La decision ─────────────────────────────────────────────────────────────
--
--  Le cours reste, mais il se RATTACHE a la matiere. Il devient « le PROGRAMME
--  de cette matiere dans cette classe » : descriptif, chapitres, volume horaire,
--  salle. Il COMPLETE la matiere au lieu de la doubler.
--
--  Le coefficient reste celui de la MATIERE : une seule source. Celui du cours
--  n'etait de toute facon lu par personne.
-- ============================================================================

-- ── 1. Le rattachement ──────────────────────────────────────────────────────
alter table public.courses
  add column if not exists subject_id uuid references public.subjects(id) on delete set null;

create index if not exists idx_courses_subject on public.courses(subject_id);

comment on column public.courses.subject_id is
  'La matiere dont ce cours est le programme. Le COEFFICIENT vient de la matiere,
   jamais du cours : une seule source.';

-- ── 2. Rattacher les cours existants, par leur nom ──────────────────────────
--  C'est le seul lien qu'ils aient jamais eu. On le materialise avant qu'il ne
--  se perde. Comparaison insensible a la casse et aux espaces : « Mathematiques »
--  et « mathematiques » designent la meme matiere.
update public.courses c
   set subject_id = s.id
  from public.subjects s
 where c.subject_id is null
   and s.school_id = c.school_id
   and lower(trim(s.name)) = lower(trim(c.name));

-- ── 3. Un seul cours par (classe, matiere) ──────────────────────────────────
--  Deux « programmes de maths en CM2 A » n'ont aucun sens : c'est le meme cours,
--  saisi deux fois. On dedoublonne (on garde le plus ancien) puis on l'interdit.
delete from public.courses a
 using public.courses b
 where a.subject_id is not null
   and a.subject_id = b.subject_id
   and a.class_id   = b.class_id
   and a.ctid > b.ctid;

create unique index if not exists idx_courses_class_subject
  on public.courses (class_id, subject_id)
  where subject_id is not null;

-- ============================================================================
--  VERIFICATION :
--
--    -- Les cours et leur matiere. `matiere` a NULL = un cours dont le nom ne
--    -- correspond a aucune matiere de l'ecole : a rattacher a la main dans
--    -- l'application (ou a supprimer, s'il ne veut rien dire).
--    select c.name as cours, s.name as matiere, s.coefficient, cl.name as classe
--      from public.courses c
--      left join public.subjects s on s.id = c.subject_id
--      left join public.classes  cl on cl.id = c.class_id
--     order by cl.name, c.name;
--
--    -- Combien restent orphelins ?
--    select count(*) from public.courses where subject_id is null;
-- ============================================================================
