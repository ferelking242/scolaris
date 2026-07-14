-- ============================================================================
--  20260734_family_portal_per_school.sql — Le portail des familles se perd AUSSI
--  quand on retrograde, et se juge ECOLE PAR ECOLE
--
--  ── Le trou laisse par 20260733 ─────────────────────────────────────────────
--
--  Le declencheur `guard_family_portal` refuse de RATTACHER un compte a un eleve
--  ou un parent quand l'offre ne comporte pas le portail. Il garde la porte
--  d'entree.
--
--  Mais il ne dit rien de ceux qui sont DEJA dans la maison. Une ecole Pro dont
--  les parents ont un compte, qui redescend en Simple : ses parents continuent de
--  se connecter et de tout voir. Elle paie 14 900 F et garde les fonctions a
--  29 900 F — exactement le probleme qu'on pretendait resoudre, a l'envers.
--
--  ── Le cas du parent a cheval sur deux ecoles ───────────────────────────────
--
--  Un parent peut avoir un enfant a l'ecole A (Pro) et un autre a l'ecole B
--  (Simple). Le droit ne se juge donc PAS au niveau du compte, mais ECOLE PAR
--  ECOLE : il doit voir l'enfant A, et pas l'enfant B.
--
--  ── Ou corriger ─────────────────────────────────────────────────────────────
--
--  `is_member_of(school_id)` est appelee par TOUTES les policies, et elle prend
--  deja l'ecole en argument. C'est le seul endroit a toucher : un eleve ou un
--  parent n'est « membre » d'une ecole que si cette ecole a paye le portail.
--  Pour le personnel et les enseignants, rien ne change.
--
--  Effet concret d'une retrogradation : la famille se connecte encore (le compte
--  existe), mais ne voit plus RIEN de cette ecole. Aucune donnee n'est detruite —
--  elle reapparait telle quelle si l'ecole repasse en Pro.
-- ============================================================================

create or replace function public.is_member_of(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.school_members m
      join public.users u on u.id = m.user_id
     where u.auth_uid  = auth.uid()
       and m.school_id = sid
       and m.status    = 'active'
       -- Le personnel et les enseignants : inchange.
       -- Les familles : seulement si CETTE ecole a le portail dans son offre.
       and (
         u.role::text not in ('student', 'parent')
         or public.school_has_feature(sid, 'portail_parents')
       )
  );
$$;

grant execute on function public.is_member_of(uuid) to anon, authenticated;

-- ============================================================================
--  VERIFICATION :
--
--    -- Ce que voit chaque famille, ecole par ecole :
--    select u.full_name, u.role, s.name as ecole, sub.plan_code,
--           public.school_has_feature(s.id, 'portail_parents') as acces_portail
--      from public.school_members m
--      join public.users u   on u.id = m.user_id
--      join public.schools s on s.id = m.school_id
--      left join public.subscriptions sub on sub.school_id = s.id
--     where u.role::text in ('student', 'parent');
--
--    -- Attendu : acces_portail = false pour toute ecole en offre Simple.
--    -- Ces comptes se connectent encore, mais leur espace est VIDE.
--
--  ⚠ A SAVOIR : un espace vide sans explication est deroutant. L'application
--    devrait afficher « Votre etablissement n'a pas active l'espace familles »
--    plutot qu'une liste vide. C'est un travail cote Flutter, pas en base.
-- ============================================================================

-- ============================================================================
--  ROLLBACK — revenir a l'adhesion sans condition d'offre :
--
--    create or replace function public.is_member_of(sid uuid)
--    returns boolean language sql stable security definer set search_path = public
--    as $$
--      select exists (
--        select 1 from public.school_members m
--          join public.users u on u.id = m.user_id
--         where u.auth_uid = auth.uid() and m.school_id = sid and m.status = 'active'
--      );
--    $$;
-- ============================================================================
