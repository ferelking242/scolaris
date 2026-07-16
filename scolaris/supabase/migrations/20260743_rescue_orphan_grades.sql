-- ============================================================================
--  20260743_rescue_orphan_grades.sql — Les notes que plus personne ne lit
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--    select type, sequence, count(*) from public.grades group by 1, 2;
--
--      controle  1   34      <-- invisibles
--      devoir    1  184
--      devoir    2   96
--      devoir    3   96
--      examen    1  184
--
--  Depuis que le carnet et le bulletin parlent le vocabulaire du bulletin
--  congolais (3 DEVOIRS + 1 COMPOSITION, cf. 20260740), le type « controle »
--  n'est plus lu par personne. Ces 34 notes existent en base, et ne s'affichent
--  NULLE PART : ni au carnet du prof, ni au bulletin de l'eleve.
--
--  C'est la meme famille de bug que d'habitude : deux moities d'une idee qui ne
--  se parlent plus. Une note qu'on ne peut pas voir est pire qu'une note
--  absente — le prof croit l'avoir saisie.
--
--  ── La decision ─────────────────────────────────────────────────────────────
--
--  Un « controle » EST un devoir : une evaluation en cours de periode, par
--  opposition a la composition qui cloture. On le reclasse donc comme devoir,
--  dans le premier creneau LIBRE de l'eleve pour cette matiere.
--
--  Celles qui ne trouvent pas de place — l'eleve a deja ses trois devoirs — sont
--  supprimees : elles ne pourraient de toute facon jamais s'afficher, et les
--  garder ne ferait que reproduire le probleme.
-- ============================================================================

do $$
declare
  v_moved   int;
  v_dropped int;
  v_max     int;
begin
  -- Le nombre de devoirs depend de l'ECOLE. On prend le maximum en vigueur : une
  -- ecole a 3 devoirs, une autre pourrait en avoir 4. Reclasser au-dela de ce que
  -- l'ecole affiche reviendrait a recreer une note invisible.
  select coalesce(max(bulletin_devoirs), 3) into v_max from public.schools;

  -- ── 1. Reclasser, dans le premier creneau libre ───────────────────────────
  with candidats as (
    select g.id, g.student_id, g.subject_id, g.period,
           row_number() over (
             partition by g.student_id, g.subject_id, g.period
             order by g.graded_at nulls last, g.created_at nulls last, g.id
           ) as n
      from public.grades g
     where g.type = 'controle'
  ),
  libres as (
    select c.id,
           (select min(s.seq)
              from generate_series(1, v_max) s(seq)
             where not exists (
               select 1 from public.grades d
                where d.student_id = c.student_id
                  and d.subject_id = c.subject_id
                  and d.period     = c.period
                  and d.type       = 'devoir'
                  and d.sequence   = s.seq
             )
             -- Deux controles pour la meme matiere ? Le second prend le creneau
             -- SUIVANT : sans ce decalage, ils se disputeraient la meme place et
             -- l'un des deux serait rejete par la contrainte d'unicite.
             and s.seq >= c.n
           ) as seq
      from candidats c
  )
  update public.grades g
     set type = 'devoir', sequence = l.seq
    from libres l
   where g.id = l.id
     and l.seq is not null;

  get diagnostics v_moved = row_count;

  -- ── 2. Supprimer celles qui n'ont plus de place ───────────────────────────
  delete from public.grades where type = 'controle';
  get diagnostics v_dropped = row_count;

  raise notice '% note(s) « controle » reclassee(s) en devoir, % supprimee(s) faute de creneau libre.',
    v_moved, v_dropped;
end $$;

-- ============================================================================
--  VERIFICATION — plus aucune note invisible :
--
--    select type, sequence, count(*) from public.grades
--     group by type, sequence order by type, sequence;
--
--  Il ne doit rester que `devoir` (1..3) et `examen` (1). Tout autre type est
--  une note que personne ne verra jamais.
-- ============================================================================
