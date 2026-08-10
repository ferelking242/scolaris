-- L'inscription ne fait plus choisir des modules un par un (décision
-- utilisateur du 09/08/2026 : "je préfère que ça soit juste le choix d'une
-- offre, c'est plus simple à comprendre") — school_registration_screen.dart
-- envoie désormais metadata.chosen_plan ('simple'|'pro'|'max') et
-- metadata.modules = ['academic'] uniquement (l'école installe ses modules
-- complémentaires elle-même depuis la page « Modules » après inscription).
--
-- handle_new_school_trial() doit donc lire chosen_plan en priorité. Le
-- fallback sur le comptage de modules est conservé pour les tests/outils
-- internes qui pourraient encore poser 'modules' sans 'chosen_plan'.
create or replace function public.handle_new_school_trial()
returns trigger
language plpgsql
as $$
declare
  module_count integer;
  chosen_plan  text;
begin
  chosen_plan := new.metadata ->> 'chosen_plan';

  if chosen_plan is null or chosen_plan not in ('simple', 'pro', 'max') then
    select count(*) into module_count
    from jsonb_array_elements_text(coalesce(new.metadata -> 'modules', '[]'::jsonb)) m
    where m <> 'academic';

    chosen_plan := case
      when module_count <= 0 then 'simple'
      when module_count <= 1 then 'pro'
      else 'max'
    end;
  end if;

  insert into public.subscriptions (school_id, plan_code, status, trial_end)
  values (new.id, chosen_plan, 'trial', now() + interval '14 days');
  return new;
end;
$$;
