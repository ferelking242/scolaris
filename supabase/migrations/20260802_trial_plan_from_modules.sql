-- ============================================================
-- SCOLARIS — L'essai gratuit démarre déjà sur l'offre déduite des modules
--
-- `handle_new_school_trial()` insérait toujours `plan_code = 'simple'`, peu
-- importe ce que l'école avait coché à l'inscription (schools.metadata.modules,
-- cf. school_registration_screen.dart). Comme le prix est maintenant affiché
-- EN DIRECT pendant l'inscription selon les modules cochés (décision
-- utilisateur explicite), l'abonnement créé doit refléter ce même calcul dès
-- le départ — sinon l'admin verrait une offre différente de celle annoncée
-- une fois connecté.
--
-- Calcul dupliqué côté Dart dans `_planForModuleCount()` (school_registration_
-- screen.dart) : à mettre à jour des DEUX côtés si les seuils changent.
-- Idempotent.
-- ============================================================

begin;

create or replace function public.handle_new_school_trial()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  module_count integer;
  chosen_plan  text;
begin
  module_count := coalesce(jsonb_array_length(new.metadata -> 'modules'), 0);

  chosen_plan := case
    when module_count <= 1 then 'simple'
    when module_count <= 3 then 'pro'
    else 'max'
  end;

  insert into public.subscriptions (school_id, plan_code, status, trial_end)
  values (new.id, chosen_plan, 'trial', now() + interval '14 days');
  return new;
end;
$function$;

commit;
