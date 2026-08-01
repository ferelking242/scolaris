-- ============================================================================
--  20260782_enrollment_status_lookup.sql — fonction publique de suivi de
--  dossier pour le site vitrine (site_saas/suivi.html).
--
--  `enrollment_requests` n'a volontairement AUCUNE policy SELECT pour anon
--  (payload = données personnelles de la famille). Pour permettre à un
--  parent de suivre sa demande sans compte, on expose une fonction
--  SECURITY DEFINER qui ne renvoie que le strict nécessaire (statut, nom de
--  l'école, note éventuelle) pour une référence EXACTE — jamais le payload,
--  jamais de liste, jamais de recherche partielle.
-- ============================================================================

create or replace function public.get_enrollment_status(p_reference text)
returns table (status text, school_name text, note text)
language sql
stable
security definer
set search_path = public
as $$
  select r.status, s.name, r.note
    from public.enrollment_requests r
    join public.schools s on s.id = r.school_id
   where r.reference = p_reference
   limit 1;
$$;

revoke all on function public.get_enrollment_status(text) from public;
grant execute on function public.get_enrollment_status(text) to anon, authenticated;

-- ============================================================================
--  VERIFICATION :
--    select * from public.get_enrollment_status('SCO-XXXXXX');
-- ============================================================================
