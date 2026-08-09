-- Le trigger serveur enforce_school_module_quota() bloquait l'installation
-- d'un module même après achat ET confirmation d'un emplacement à la carte :
-- il ne comptait que plans.max_modules, jamais subscriptions.extra_module_slots
-- (contrairement à updateSchoolModules() côté client, corrigé le 09/08/2026
-- mais qui ne suffisait pas puisque ce trigger validait indépendamment et
-- en dernier ressort). Message d'erreur identique observé en prod :
-- "Quota de modules dépassé : votre offre autorise 0 module(s)
-- complémentaire(s), 1 sélectionné(s)." alors que extra_module_slots=1.
create or replace function public.enforce_school_module_quota()
returns trigger
language plpgsql
as $$
declare
  quota integer;
  chosen_count integer;
begin
  if new.metadata -> 'modules' is null then
    return new;
  end if;
  if old.metadata -> 'modules' is not distinct from new.metadata -> 'modules' then
    return new;
  end if;

  select p.max_modules + coalesce(s.extra_module_slots, 0) into quota
  from public.subscriptions s
  join public.plans p on p.code = s.plan_code
  where s.school_id = new.id
  order by s.created_at desc
  limit 1;

  -- Pas d'abonnement trouvé (ex. école en cours de création, avant que le
  -- trigger trial ait tourné) : on ne bloque pas.
  if quota is null then
    return new;
  end if;

  select count(*) into chosen_count
  from jsonb_array_elements_text(new.metadata -> 'modules') m
  where m <> 'academic';

  if chosen_count > quota then
    raise exception
      'Quota de modules dépassé : votre offre autorise % module(s) complémentaire(s), % sélectionné(s). Passez à une offre supérieure ou achetez un emplacement supplémentaire.',
      quota, chosen_count;
  end if;

  return new;
end;
$$;
