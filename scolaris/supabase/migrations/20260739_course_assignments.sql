-- ============================================================================
--  20260739_course_assignments.sql — Le COURS devient l'affectation :
--  « cette classe etudie cette matiere, avec ce coefficient, par ces profs »
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  Depuis 20260738, un cours pointe enfin vers une matiere. Mais le fait
--  « qui enseigne quoi » restait ecrit dans l'EMPLOI DU TEMPS, et nulle part
--  ailleurs. Deux consequences :
--
--    • Pas de grille horaire = aucun prof ne peut noter. Or beaucoup d'ecoles
--      ne saisiront jamais leur emploi du temps la premiere annee.
--    • L'emploi du temps REPETE (classe, matiere, prof) a chaque creneau.
--      Mme Ibara fait maths en Terminale C ? C'est ecrit quatre fois dans la
--      semaine, et rien n'empeche le troisieme creneau de dire « M. Loko ».
--      Quatre verites pour un seul fait.
--
--  L'affectation d'un prof a une matiere dans une classe est un fait STABLE.
--  L'horaire est un detail d'organisation. Le fait doit etre ecrit une fois,
--  et l'horaire y renvoyer.
--
--  ── Le modele ───────────────────────────────────────────────────────────────
--
--    subjects         le catalogue de l'ecole. « Maths, coefficient 4 par defaut »
--    courses          LE PILIER. « Terminale C · Maths · coef 5 · 6h/semaine »
--                     -> quelles matieres la classe etudie, avec quel poids
--    course_teachers  qui les enseigne. PLUSIEURS profs possibles : au primaire
--                     le maitre fait francais/maths et la maitresse eveil/anglais ;
--                     ailleurs deux profs se partagent une matiere.
--    schedules        QUAND, et OU. Un creneau renvoie a un cours de la classe
--                     et a l'un de ses enseignants. Il ne peut plus le contredire.
--    classes.main_teacher_id  le raccourci du primaire : le titulaire enseigne
--                     toute sa classe, sans qu'on ait a lister ses matieres.
--
--  Un prof gagne l'acces a une classe par le COURS (ou par le titulariat), plus
--  par l'emploi du temps.
-- ============================================================================

-- ── 1. Les enseignants d'un cours ───────────────────────────────────────────
--  `courses.teacher_id` ne portait qu'un seul prof. Le co-enseignement est
--  courant (primaire surtout) : on passe a une table de liaison.
--
--  ATTENTION — c'est une CLE : qui peut ecrire ici peut se donner acces aux
--  notes d'une classe. Elle est verrouillee au point 6, comme parent_student.
create table if not exists public.course_teachers (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  course_id   uuid not null references public.courses(id) on delete cascade,
  teacher_id  uuid not null references public.users(id)   on delete cascade,
  -- 'principal' = le responsable de la matiere ; 'co' = co-enseignant.
  -- Les deux ont exactement les MEMES droits : noter, faire l'appel. Le role
  -- n'est qu'un affichage.
  role        text not null default 'principal',
  created_at  timestamptz not null default now(),
  constraint course_teachers_role_check check (role in ('principal', 'co'))
);

create unique index if not exists idx_course_teachers_unique
  on public.course_teachers (course_id, teacher_id);
create index if not exists idx_course_teachers_teacher
  on public.course_teachers (teacher_id);

comment on table public.course_teachers is
  'Qui enseigne ce cours. Plusieurs profs possibles (co-enseignement). C''est la
   source UNIQUE des droits d''un enseignant sur une classe, avec le titulariat.
   L''emploi du temps n''en est plus une.';

-- ── 2. Reprise : personne ne perd ses droits ────────────────────────────────

--  2a. Le prof unique du cours devient son enseignant principal.
insert into public.course_teachers (school_id, course_id, teacher_id, role)
select c.school_id, c.id, c.teacher_id, 'principal'
  from public.courses c
 where c.teacher_id is not null
on conflict (course_id, teacher_id) do nothing;

--  2b. Chaque creneau (classe, matiere, prof) sans cours correspondant CREE le
--      cours manquant. C'est la ou vivaient les affectations jusqu'ici : sans
--      cette etape, tous les profs du secondaire perdraient leurs classes.
insert into public.courses (id, school_id, class_id, subject_id, name, coef)
select distinct on (s.class_id, s.subject_id)
       gen_random_uuid(), s.school_id, s.class_id, s.subject_id,
       coalesce(sub.name, 'Cours'), coalesce(sub.coefficient, 1)
  from public.schedules s
  join public.subjects sub on sub.id = s.subject_id
 where s.subject_id is not null
   and not exists (
     select 1 from public.courses c
      where c.class_id = s.class_id and c.subject_id = s.subject_id
   );

--  2c. Les profs de ces creneaux deviennent les enseignants du cours.
insert into public.course_teachers (school_id, course_id, teacher_id, role)
select distinct c.school_id, c.id, s.teacher_id, 'principal'
  from public.schedules s
  join public.courses c
    on c.class_id = s.class_id and c.subject_id = s.subject_id
 where s.teacher_id is not null
on conflict (course_id, teacher_id) do nothing;

--  2d. `courses.teacher_id` n'est plus lu. On le garde une version (au cas ou)
--      mais on le neutralise : plus personne ne doit s'en servir.
comment on column public.courses.teacher_id is
  'OBSOLETE depuis 20260739 — remplace par course_teachers (co-enseignement).
   Ne plus lire ni ecrire : la colonne sera supprimee.';

-- ── 3. Le coefficient de la matiere DANS CETTE CLASSE ───────────────────────
--  Au lycee, les maths pesent 5 en serie C et 2 en serie A. Meme matiere, poids
--  different. `courses.coef` n'etait lu par personne : on peut le redefinir sans
--  rien casser. Il vaut par defaut celui de la matiere.
update public.courses c
   set coef = s.coefficient
  from public.subjects s
 where c.subject_id = s.id
   and s.coefficient is not null
   and c.coef is distinct from s.coefficient
   and c.coef = 1;  -- seulement la valeur par defaut : on n'ecrase pas un choix

comment on column public.courses.coef is
  'Poids de cette matiere DANS CETTE CLASSE (serie C : maths 5 ; serie A : 2).
   Herite du coefficient de la matiere a la creation, puis vit sa vie.';

-- ── 4. Un prof enseigne-t-il cette classe ? ─────────────────────────────────
--  DEUX sources, et deux seulement :
--    • le titulariat  -> toute la classe (primaire) ;
--    • un cours       -> les matieres qu'il y enseigne (college / lycee).
--  L'emploi du temps N'EST PLUS une source : il ne fait que placer dans le temps
--  des cours qui existent deja.
create or replace function public.teaches_class(uid uuid, p_class_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.classes c
     join public.users u on u.id = c.main_teacher_id
    where u.auth_uid = uid and c.id = p_class_id
  )
  or exists (
    select 1 from public.course_teachers ct
     join public.courses c on c.id = ct.course_id
     join public.users   u on u.id = ct.teacher_id
    where u.auth_uid = uid and c.class_id = p_class_id
  );
$fn$;

--  Et cette MATIERE dans cette classe ? Le titulaire enseigne tout ; les autres
--  seulement les matieres dont ils ont le cours. Sans quoi le prof de maths
--  pourrait noter en francais dans la meme classe.
create or replace function public.teaches_subject(uid uuid, p_class_id uuid, p_subject_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.classes c
     join public.users u on u.id = c.main_teacher_id
    where u.auth_uid = uid and c.id = p_class_id
  )
  or exists (
    select 1 from public.course_teachers ct
     join public.courses c on c.id = ct.course_id
     join public.users   u on u.id = ct.teacher_id
    where u.auth_uid = uid
      and c.class_id   = p_class_id
      and c.subject_id = p_subject_id
  );
$fn$;

-- ── 5. Un creneau ne peut plus contredire le programme ──────────────────────
--  Une policy RLS ne sait pas verifier ca (elle ne voit qu'une ligne, pas la
--  coherence entre tables) : il faut un trigger.
create or replace function public.guard_schedule_matches_course()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
declare
  v_course_id uuid;
begin
  -- Un creneau sans matiere (etude, permanence) reste libre.
  if new.subject_id is null then
    return new;
  end if;

  select c.id into v_course_id
    from public.courses c
   where c.class_id = new.class_id and c.subject_id = new.subject_id;

  if v_course_id is null then
    raise exception
      'Cette classe n''etudie pas cette matiere. Ajoutez-la d''abord au programme de la classe.'
      using errcode = '23514';
  end if;

  -- Le prof du creneau doit enseigner ce cours. Sinon on aurait de nouveau deux
  -- verites : le programme dirait Mme Ibara, l'horaire M. Loko.
  if new.teacher_id is not null
     and not exists (
       select 1 from public.course_teachers ct
        where ct.course_id = v_course_id and ct.teacher_id = new.teacher_id
     )
  then
    raise exception
      'Ce professeur n''enseigne pas cette matiere dans cette classe. Ajoutez-le au cours d''abord.'
      using errcode = '23514';
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_guard_schedule_matches_course on public.schedules;
create trigger trg_guard_schedule_matches_course
  before insert or update on public.schedules
  for each row execute function public.guard_schedule_matches_course();

-- ── 6. Verrou : course_teachers est une CLE ─────────────────────────────────
--  Meme lecon que teacher_classes et parent_student : une table de liaison
--  ouverte a l'ecriture annule tous les verrous qui s'appuient dessus. Un prof
--  qui pourrait s'ajouter a un cours s'ouvrirait les notes de la classe.
alter table public.course_teachers enable row level security;

drop policy if exists course_teachers_read on public.course_teachers;
create policy course_teachers_read on public.course_teachers
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists course_teachers_insert on public.course_teachers;
create policy course_teachers_insert on public.course_teachers
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'classes', 'modifier')
  );

drop policy if exists course_teachers_update on public.course_teachers;
create policy course_teachers_update on public.course_teachers
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'classes', 'modifier')
  )
  with check (public.is_member_of(school_id));

drop policy if exists course_teachers_delete on public.course_teachers;
create policy course_teachers_delete on public.course_teachers
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'classes', 'modifier')
  );

-- ============================================================================
--  VERIFICATION :
--
--    -- Le programme de chaque classe, avec ses profs.
--    select cl.name as classe, s.name as matiere, c.coef,
--           string_agg(u.full_name, ', ' order by ct.role) as profs
--      from public.courses c
--      join public.classes  cl on cl.id = c.class_id
--      left join public.subjects s on s.id = c.subject_id
--      left join public.course_teachers ct on ct.course_id = c.id
--      left join public.users u on u.id = ct.teacher_id
--     group by cl.name, s.name, c.coef
--     order by cl.name, s.name;
--
--    -- Un prof a-t-il perdu ses classes ? (creneaux dont le prof n'est pas
--    -- rattache au cours : doit renvoyer 0)
--    select count(*)
--      from public.schedules s
--      join public.courses c on c.class_id = s.class_id and c.subject_id = s.subject_id
--     where s.teacher_id is not null
--       and not exists (select 1 from public.course_teachers ct
--                        where ct.course_id = c.id and ct.teacher_id = s.teacher_id);
-- ============================================================================
