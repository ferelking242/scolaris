-- ============================================================================
--  20260759_platform_school_stats.sql — Effectifs par école pour la console
--  super-admin (page « Écoles »)
--
--  Le repertoire `platform/` a besoin d'afficher élèves/profs/classes par
--  école dans la liste — sans donner à la console un accès direct à `users`
--  (qui exposerait noms/emails/téléphones de tout le monde, cf. le choix déjà
--  fait pour `platform_total_students()` dans 20260757). On agrège donc via
--  une fonction SECURITY DEFINER dédiée, gardée par `is_platform_admin()`.
--
--  Idempotent. Rejouable.
-- ============================================================================

create or replace function public.platform_school_stats()
returns table(school_id text, student_count bigint, teacher_count bigint, class_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id::text,
    (select count(*) from public.users u where u.school_id = s.id and u.role = 'student'),
    (select count(*) from public.users u where u.school_id = s.id and u.role = 'teacher'),
    (select count(*) from public.classes c where c.school_id = s.id)
  from public.schools s
  where public.is_platform_admin(auth.uid());
$$;

grant execute on function public.platform_school_stats() to authenticated;

-- ============================================================================
--  VERIFICATION (connecté en super-admin) :
--    select * from platform_school_stats() limit 5;
--    -- doit renvoyer une ligne par école, [] si l'appelant n'est pas
--    -- platform admin (le where filtre tout).
-- ============================================================================
