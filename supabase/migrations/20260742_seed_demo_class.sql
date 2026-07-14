-- ============================================================================
--  20260742_seed_demo_class.sql — Une VRAIE classe pour juger le bulletin
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  Chaque classe de la base a UN seul eleve. Avec un eleve :
--    • il est toujours 1er ;
--    • la moyenne de la classe est la sienne ;
--    • le premier et le dernier aussi.
--
--  Le rang, le classement, la moyenne de la classe — tout ce que le bulletin
--  affiche de plus qu'une simple liste de notes — reste invisible. On ne peut
--  rien juger.
--
--  ── Ce que fait cette migration ─────────────────────────────────────────────
--
--  Elle remplit la classe qui a le PLUS DE MATIERES a son programme jusqu'a
--  douze eleves, puis leur donne des notes : 3 devoirs + 1 composition par
--  matiere.
--
--  Les eleves sont des FICHES, pas des comptes : `auth_uid` reste NULL. Ils ne
--  peuvent pas se connecter, et aucun mot de passe n'existe. Leur email est en
--  `@demo.local` — un domaine reserve, qui ne part nulle part.
--
--  Deterministe : les notes derivent de hashtext(eleve, matiere, rang). Rejouer
--  ne change rien. Non destructif : `on conflict do nothing` partout.
--
--  ── POUR TOUT EFFACER ───────────────────────────────────────────────────────
--    delete from public.users where email like '%@demo.local';
--    (les notes et le profil partent en cascade)
-- ============================================================================

do $$
declare
  v_class   uuid;
  v_school  uuid;
  v_name    text;
  v_period  text;
  v_have    int;
  v_need    int;
  v_i       int;
  v_uid     uuid;
  v_notes   int;

  -- Des noms d'ici, pas des « Élève 1, Élève 2 » : on veut voir a quoi
  -- ressemble un vrai listing de classe, avec des noms de vraie longueur.
  v_first   text[] := array['Jules','Grace','Kevin','Sarah','Landry','Divine',
                            'Prince','Merveille','Cedric','Naomi','Steve','Laura'];
  v_last    text[] := array['Mombeki','Nkodia','Ibara','Loko','Bakala','Mabiala',
                            'Ngoubili','Samba','Okemba','Malonga','Bouanga','Kimbembe'];
begin
  -- ── 1. La classe : celle qui a le programme le plus fourni ────────────────
  select c.id, c.school_id, c.name
    into v_class, v_school, v_name
    from public.classes c
   where exists (select 1 from public.courses co
                  where co.class_id = c.id and co.subject_id is not null)
   order by (select count(*) from public.courses co
              where co.class_id = c.id and co.subject_id is not null) desc,
            (select count(*) from public.student_profiles sp
              where sp.class_id = c.id) desc
   limit 1;

  if v_class is null then
    raise exception 'Aucune classe n''a de programme (cours rattaches a une matiere). Creez-en d''abord dans « Cours ».';
  end if;

  select count(*) into v_have
    from public.student_profiles sp where sp.class_id = v_class;

  v_need := greatest(0, 12 - v_have);

  select case when s.period_system = 'semester' then 'S1' else 'T1' end
    into v_period
    from public.schools s where s.id = v_school;

  -- ── 2. Les eleves manquants ───────────────────────────────────────────────
  for v_i in 1 .. v_need loop
    v_uid := gen_random_uuid();

    insert into public.users
      (id, school_id, auth_uid, full_name, email, role, status,
       created_at, updated_at)
    values
      (v_uid, v_school, null,
       v_last[v_i] || ' ' || v_first[v_i],
       lower(v_first[v_i] || '.' || v_last[v_i]) || '@demo.local',
       'student', 'active', now(), now());

    insert into public.student_profiles
      (user_id, school_id, class_id, matricule, academic_year,
       created_at, updated_at)
    values
      (v_uid, v_school, v_class,
       'DEMO' || to_char(v_i, 'FM000'),
       (select academic_year from public.schools where id = v_school),
       now(), now())
    on conflict (user_id) do nothing;
  end loop;

  -- ── 3. Les notes — pour TOUTE la classe, anciens eleves compris ───────────
  --  Entre 6,0 et 18,0 : il faut des eleves en difficulte, sinon la mention
  --  « Insuffisant » et la decision « REDOUBLE » ne s'affichent jamais et on ne
  --  les voit pas a l'oeuvre.
  with slots as (
    select 'devoir'::text as type, s as seq from generate_series(1, 3) s
    union all
    select 'examen', 1
  )
  insert into public.grades
    (id, student_id, class_id, school_id, subject_id,
     score, max_score, period, type, sequence, graded_at, created_at)
  select
    gen_random_uuid(), sp.user_id, v_class, v_school, co.subject_id,
    6 + (abs(hashtext(sp.user_id::text || co.subject_id::text || sl.type || sl.seq::text)) % 25) / 2.0,
    20, v_period, sl.type, sl.seq, now(), now()
    from public.student_profiles sp
   cross join (
     select distinct subject_id from public.courses
      where class_id = v_class and subject_id is not null
   ) co
   cross join slots sl
   where sp.class_id = v_class
  on conflict (student_id, subject_id, period, type, sequence) do nothing;

  get diagnostics v_notes = row_count;

  raise notice 'Classe « % » : % eleves ajoutes (total %), % notes ecrites, periode %.',
    v_name, v_need, v_have + v_need, v_notes, v_period;
end $$;

-- ============================================================================
--  VERIFICATION — le classement, calcule en SQL. A comparer avec l'ecran :
--  si les deux ne disent pas la meme chose, l'un des deux ment.
--
--    with moy as (
--      select g.student_id, g.subject_id, co.coef,
--             avg(g.score) filter (where g.type = 'devoir')  as mc,
--             max(g.score) filter (where g.type = 'examen')  as compo
--        from public.grades g
--        join public.courses co
--          on co.class_id = g.class_id and co.subject_id = g.subject_id
--       group by g.student_id, g.subject_id, co.coef
--    ),
--    gen as (
--      select student_id,
--             round(sum((mc * 0.5 + compo * 0.5) * coef) / sum(coef), 2) as moyenne
--        from moy group by student_id
--    )
--    select rank() over (order by g.moyenne desc) as rg,
--           u.full_name, g.moyenne
--      from gen g join public.users u on u.id = g.student_id
--     order by g.moyenne desc;
--
--  ── Notes orphelines ────────────────────────────────────────────────────────
--  Le bulletin ne lit que les DEVOIRS (sequence 1..3) et la COMPOSITION
--  (type 'examen'). D'anciennes notes de type 'controle' n'apparaissent nulle
--  part — ni au carnet, ni au bulletin. Pour les voir :
--
--    select type, sequence, count(*) from public.grades
--     group by type, sequence order by type, sequence;
-- ============================================================================
