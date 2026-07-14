-- ============================================================================
--  20260741_seed_demo_grades.sql — Des notes pour VOIR le bulletin
--
--  Le calcul est teste (test/bulletin_math_test.dart, verifie contre le vrai
--  bulletin du CSBFE). Mais tant qu'aucune classe n'a de notes, l'ecran reste
--  vide : impossible de juger le rendu, le rang, la mention.
--
--  On remplit donc UNE classe — celle qui a le plus d'eleves ET un programme —
--  avec des notes plausibles : 3 devoirs + 1 composition par matiere.
--
--  ── Deterministe, pas aleatoire ─────────────────────────────────────────────
--
--  Les notes derivent de `hashtext(eleve || matiere || rang)`. Rejouer cette
--  migration redonne exactement les memes notes : le bulletin ne bouge pas
--  entre deux essais, et un ecart affiche est un vrai ecart, pas du bruit.
--
--  ── Non destructif ──────────────────────────────────────────────────────────
--
--  `on conflict do nothing` : une note deja saisie a la main n'est jamais
--  ecrasee. Pour recommencer a zero, supprimer d'abord (requete en bas).
-- ============================================================================

do $$
declare
  v_class    uuid;
  v_school   uuid;
  v_period   text;
  v_students int;
  v_courses  int;
  v_inserted int;
begin
  -- ── 1. La classe la plus fournie, parmi celles qui ont un programme ───────
  select c.id, c.school_id
    into v_class, v_school
    from public.classes c
   where exists (select 1 from public.courses co
                  where co.class_id = c.id and co.subject_id is not null)
   order by (select count(*) from public.student_profiles sp
              where sp.class_id = c.id) desc
   limit 1;

  if v_class is null then
    raise notice 'Aucune classe avec un programme (cours + matiere). Rien a faire.';
    return;
  end if;

  select count(*) into v_students
    from public.student_profiles sp where sp.class_id = v_class;

  if v_students = 0 then
    raise notice 'La classe % n''a aucun eleve. Rien a faire.', v_class;
    return;
  end if;

  select count(*) into v_courses
    from public.courses co
   where co.class_id = v_class and co.subject_id is not null;

  -- La periode depend de l'ecole : T1 en trimestres, S1 en semestres. Ecrire
  -- « T1 » en dur ferait echouer la contrainte dans une ecole a semestres —
  -- exactement le bug de 20260723.
  select case when s.period_system = 'semester' then 'S1' else 'T1' end
    into v_period
    from public.schools s where s.id = v_school;

  -- ── 2. Les notes ──────────────────────────────────────────────────────────
  --  3 devoirs (sequence 1, 2, 3) + 1 composition (type 'examen', sequence 1).
  --  Entre 8,0 et 18,0 par pas de 0,5 : une classe credible — quelques eleves
  --  en difficulte, quelques tres bons, une majorite au milieu.
  with slots as (
    select 'devoir'::text as type, s as seq from generate_series(1, 3) s
    union all
    select 'examen', 1
  )
  insert into public.grades
    (id, student_id, class_id, school_id, subject_id,
     score, max_score, period, type, sequence, graded_at, created_at)
  select
    gen_random_uuid(),
    sp.user_id,
    v_class,
    v_school,
    co.subject_id,
    8 + (abs(hashtext(sp.user_id::text || co.subject_id::text || sl.type || sl.seq::text)) % 21) / 2.0,
    20,
    v_period,
    sl.type,
    sl.seq,
    now(),
    now()
    from public.student_profiles sp
   cross join (
     select distinct subject_id from public.courses
      where class_id = v_class and subject_id is not null
   ) co
   cross join slots sl
   where sp.class_id = v_class
  on conflict (student_id, subject_id, period, type, sequence) do nothing;

  get diagnostics v_inserted = row_count;

  raise notice 'Classe % : % eleves x % matieres x 4 notes -> % notes ecrites (periode %).',
    v_class, v_students, v_courses, v_inserted, v_period;
end $$;

-- ============================================================================
--  VERIFICATION :
--
--    -- Quelle classe a ete remplie, et combien de notes ?
--    select cl.name as classe, g.period, count(*) as notes,
--           count(distinct g.student_id) as eleves,
--           count(distinct g.subject_id) as matieres
--      from public.grades g
--      join public.classes cl on cl.id = g.class_id
--     group by cl.name, g.period
--     order by notes desc;
--
--    -- Le bulletin d'un eleve, calcule en SQL (a comparer a l'ecran) :
--    with mc as (
--      select g.student_id, g.subject_id,
--             avg(g.score) filter (where g.type = 'devoir') as mc,
--             max(g.score) filter (where g.type = 'examen') as compo
--        from public.grades g
--       group by g.student_id, g.subject_id
--    )
--    select u.full_name, s.name as matiere, co.coef,
--           round(mc.mc, 2) as mc, mc.compo,
--           round(mc.mc * 0.5 + mc.compo * 0.5, 2) as moy
--      from mc
--      join public.users u    on u.id = mc.student_id
--      join public.subjects s on s.id = mc.subject_id
--      join public.courses co on co.subject_id = mc.subject_id
--     order by u.full_name, s.name;
--
--  POUR RECOMMENCER (efface les notes de demonstration) :
--    delete from public.grades where class_id = '<uuid de la classe>';
-- ============================================================================
