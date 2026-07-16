-- Correctif : school_can_add_student renvoyait TRUE quand school_student_limit
-- était NULL. Or NULL survient dans DEUX cas :
--   (1) offre Max (max_students NULL = illimité)  → on doit autoriser
--   (2) AUCUN abonnement (le JOIN ne renvoie rien) → on doit BLOQUER
-- Avant ce correctif, une école sans souscription échappait à toute limite.
-- On distingue désormais les deux cas via un EXISTS explicite sur subscriptions.

create or replace function public.school_can_add_student(p_school uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    -- Pas d'abonnement du tout → on bloque (sécurité)
    when not exists (
      select 1 from public.subscriptions where school_id = p_school
    ) then false
    -- Abonnement Max (max_students NULL) → illimité
    when public.school_student_limit(p_school) is null then true
    -- Sinon : sous la limite + tolérance 5% (cf. business plan)
    else public.school_student_count(p_school)
         < floor(public.school_student_limit(p_school) * 1.05)
  end;
$$;
