-- 20260809_module_marketplace.sql
--
-- Refonte du modèle d'offres : « Académique » devient un socle TOUJOURS actif
-- (notes/bulletins/emploi du temps/stats), plus un module qu'on choisit ou
-- compte. Les offres se distinguent désormais par le nombre d'EMPLACEMENTS de
-- modules complémentaires (Finances / Présences / Inscriptions) débloqués :
--   - Essentiel (simple) : 0 emplacement
--   - Croissance (pro)   : 1 emplacement
--   - Complet (max)      : 3 emplacements (tout le catalogue actuel)
-- Décision utilisateur du 09/08/2026 (cf. conversation "business plan").

-- ── 1. Quotas et libellés des offres ────────────────────────────────────────
update plans set
  max_modules = 0,
  features    = '["academique_inclus"]'::jsonb,
  tagline     = 'Académique inclus (notes, bulletins, emploi du temps)'
where code = 'simple';

update plans set
  max_modules = 1,
  features    = '["academique_inclus", "1_module_complementaire_au_choix"]'::jsonb,
  tagline     = 'Académique inclus + 1 module complémentaire au choix'
where code = 'pro';

update plans set
  max_modules = 3,
  features    = '["academique_inclus", "tous_modules_complementaires", "rapport_premium"]'::jsonb,
  tagline     = 'Académique inclus + tous les modules complémentaires + rapport premium'
where code = 'max';

-- ── 2. Essai gratuit : le calcul du palier ignore 'academic' (toujours
--      inclus, jamais compté) et se base sur le nombre de modules
--      complémentaires réellement choisis à l'inscription.
create or replace function handle_new_school_trial()
returns trigger
language plpgsql
as $$
declare
  module_count integer;
  chosen_plan  text;
begin
  select count(*) into module_count
  from jsonb_array_elements_text(coalesce(new.metadata -> 'modules', '[]'::jsonb)) m
  where m <> 'academic';

  chosen_plan := case
    when module_count <= 0 then 'simple'
    when module_count <= 1 then 'pro'
    else 'max'
  end;

  insert into public.subscriptions (school_id, plan_code, status, trial_end)
  values (new.id, chosen_plan, 'trial', now() + interval '14 days');
  return new;
end;
$$;

-- ── 3. Garde-fou serveur : une école ne peut pas s'auto-attribuer plus de
--      modules complémentaires que son offre en cours ne le permet
--      (plans.max_modules). Comble le trou où `updateSchoolModules` n'était
--      vérifié que côté client (UI). Ne bloque QUE si le nombre de modules
--      complémentaires choisis dépasse le quota — jamais le retrait.
create or replace function enforce_school_module_quota()
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

  select p.max_modules into quota
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

drop trigger if exists trg_enforce_school_module_quota on schools;
create trigger trg_enforce_school_module_quota
before update on schools
for each row execute function enforce_school_module_quota();
