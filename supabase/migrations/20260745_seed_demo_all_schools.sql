-- ============================================================================
--  20260745_seed_demo_all_schools.sql — Une classe de demo DANS CHAQUE ecole
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  20260742 a rempli UNE classe — celle au programme le plus fourni, toutes
--  ecoles confondues. C'est tombe sur « Licence 1 Droit » (Universite Denis
--  Sassou Nguesso). Resultat : l'admin d'une AUTRE ecole ne voit aucune classe
--  notee, et croit que rien ne marche.
--
--  Ici, on remplit UNE classe PAR ECOLE : quelle que soit l'ecole ou l'on se
--  connecte, elle a une classe de demonstration prete a juger.
--
--  Idempotent (fiches @demo.local, `on conflict do nothing`) et deterministe
--  (notes derivees d'un hash). Rejouer ne change rien.
--
--  ── POUR TOUT EFFACER ───────────────────────────────────────────────────────
--    delete from public.users where email like '%@demo.local';
-- ============================================================================

do $$
declare
  r_school  record;
  v_class   uuid;
  v_name    text;
  v_period  text;
  v_have    int;
  v_i       int;
  v_uid     uuid;
  v_total   int := 0;
  v_first   text[] := array['Jules','Grace','Kevin','Sarah','Landry','Divine',
                            'Prince','Merveille','Cedric','Naomi','Steve','Laura'];
  v_last    text[] := array['Mombeki','Nkodia','Ibara','Loko','Bakala','Mabiala',
                            'Ngoubili','Samba','Okemba','Malonga','Bouanga','Kimbembe'];
begin
  -- Pour chaque ecole qui a au moins une classe avec un programme.
  for r_school in
    select distinct s.id, s.name,
           case when s.period_system = 'semester' then 'S1' else 'T1' end as period
      from public.schools s
      join public.classes c on c.school_id = s.id
     where exists (select 1 from public.courses co
                    where co.class_id = c.id and co.subject_id is not null)
  loop
    v_period := r_school.period;

    -- La classe la mieux dotee de CETTE ecole.
    select c.id, c.name into v_class, v_name
      from public.classes c
     where c.school_id = r_school.id
       and exists (select 1 from public.courses co
                    where co.class_id = c.id and co.subject_id is not null)
     order by (select count(*) from public.courses co
                where co.class_id = c.id and co.subject_id is not null) desc,
              (select count(*) from public.student_profiles sp
                where sp.class_id = c.id) desc
     limit 1;

    if v_class is null then
      continue;
    end if;

    select count(*) into v_have
      from public.student_profiles sp where sp.class_id = v_class;

    -- Completer jusqu'a 12 eleves.
    for v_i in 1 .. greatest(0, 12 - v_have) loop
      v_uid := gen_random_uuid();
      insert into public.users
        (id, school_id, auth_uid, full_name, email, role, status,
         created_at, updated_at)
      values
        (v_uid, r_school.id, null,
         v_last[v_i] || ' ' || v_first[v_i],
         -- L'email doit etre unique : on y glisse un fragment de l'id d'ecole.
         lower(v_first[v_i] || '.' || v_last[v_i]) || '.'
           || substr(r_school.id::text, 1, 8) || '@demo.local',
         'student', 'active', now(), now());

      insert into public.student_profiles
        (user_id, school_id, class_id, matricule, academic_year,
         created_at, updated_at)
      values
        (v_uid, r_school.id, v_class,
         'DEMO' || to_char(v_i, 'FM000'),
         (select academic_year from public.schools where id = r_school.id),
         now(), now())
      on conflict (user_id) do nothing;
    end loop;

    -- Les notes : 3 devoirs + 1 composition, entre 6 et 18.
    with slots as (
      select 'devoir'::text as type, s as seq from generate_series(1, 3) s
      union all select 'examen', 1
    )
    insert into public.grades
      (id, student_id, class_id, school_id, subject_id,
       score, max_score, period, type, sequence, graded_at, created_at)
    select
      gen_random_uuid(), sp.user_id, v_class, r_school.id, co.subject_id,
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

    v_total := v_total + 1;
    raise notice 'Ecole « % » -> classe « % » remplie (periode %).',
      r_school.name, v_name, v_period;
  end loop;

  raise notice 'Termine : % ecole(s) dotee(s) d''une classe de demo.', v_total;
end $$;

-- ============================================================================
--  VERIFICATION — chaque ecole a-t-elle une classe notee ?
--
--    select s.name as ecole, cl.name as classe,
--           count(distinct g.student_id) as eleves, count(*) as notes
--      from public.grades g
--      join public.classes cl on cl.id = g.class_id
--      join public.schools s on s.id = g.school_id
--     group by s.name, cl.name
--     order by s.name;
-- ============================================================================
