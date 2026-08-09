-- 20260809_enforce_subscription_rls.sql
--
-- Restaure (recrée en fait — la version d'origine décrite par les commentaires
-- Dart de `supabase_db_source.dart` référençant `20260733_enforce_subscription.sql`
-- / `subscription_is_active()` n'existe PAS dans cette base, probablement perdue
-- lors du reset du 03/08/2026) le blocage serveur des écritures pour une école
-- dont l'abonnement n'est plus en règle. Jusqu'ici, une école `expired` pouvait
-- toujours écrire en base normalement — seul l'affichage laissait croire à un
-- blocage (`_friendlyPostgrestMessage` gérait un code 42501 qui ne se
-- déclenchait jamais).
--
-- Approche : TRIGGER générique (pas une ré-écriture de policy par policy —
-- trop de tables, trop de risque de casser une policy existante) posé sur
-- toute table `public.*` possédant une colonne `school_id` directe, sauf :
--   - subscriptions / subscription_payments : DOIVENT rester écrivables même
--     hors règle, sinon une école past_due ne pourrait jamais soumettre le
--     versement qui la réactive.
--   - platform_events : journal interne Scolaris, pas une écriture école.
-- Un admin plateforme (`is_platform_admin`) contourne toujours le blocage
-- (support/dépannage). Lecture (SELECT) jamais concernée — conforme à
-- « vos données restent visibles, mais choisissez une offre pour enregistrer ».
--
-- ⚠️ Portée connue et volontairement incomplète : seules les tables avec une
-- colonne `school_id` DIRECTE sont couvertes ici. Des tables qui ne
-- rattachent l'école qu'indirectement (via student_id/class_id/course_id...)
-- ne sont PAS couvertes par ce trigger générique — à traiter séparément si
-- besoin (ex. via une fonction qui résout l'école par jointure).

create or replace function public.subscription_is_active(p_school_id uuid)
returns boolean
language sql
stable
security definer
as $$
  select coalesce((
    select case
      when s.status not in ('trial', 'active') then false
      when s.current_period_end is not null and s.current_period_end <= now() then false
      when s.status = 'trial' and s.trial_end is not null and s.trial_end <= now() then false
      else true
    end
    from public.subscriptions s
   where s.school_id = p_school_id
   order by s.created_at desc
   limit 1
  ), true); -- pas d'abonnement trouvé (ex. école en cours de création) : on ne bloque pas
$$;

create or replace function public.enforce_subscription_active()
returns trigger
language plpgsql
security definer
as $$
declare
  v_school_id uuid;
begin
  if public.is_platform_admin(auth.uid()) then
    return coalesce(new, old);
  end if;

  v_school_id := coalesce(new.school_id, old.school_id);
  if v_school_id is not null and not public.subscription_is_active(v_school_id) then
    raise exception 'Abonnement en lecture seule — vos données restent visibles, mais choisissez une offre pour pouvoir enregistrer.'
      using errcode = '42501';
  end if;

  return coalesce(new, old);
end;
$$;

-- Pose le trigger sur toute table avec une colonne school_id directe, à
-- l'exception des 3 listées ci-dessus. Générique : couvre automatiquement
-- toute future table ayant une colonne school_id, sans nouvelle migration.
do $$
declare
  t text;
begin
  for t in
    select table_name from information_schema.columns
    where table_schema = 'public'
      and column_name = 'school_id'
      and table_name not in ('subscriptions', 'subscription_payments', 'platform_events')
  loop
    execute format('drop trigger if exists trg_enforce_subscription_active on public.%I;', t);
    execute format(
      'create trigger trg_enforce_subscription_active
         before insert or update on public.%I
         for each row execute function public.enforce_subscription_active();', t);
  end loop;
end $$;
