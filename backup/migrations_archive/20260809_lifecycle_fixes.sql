-- 20260809_lifecycle_fixes.sql
--
-- Trois trous identifiés en analysant les scénarios école possibles avec un
-- paiement 100% manuel (pas d'agrégateur) — cf. conversation business plan
-- du 09/08/2026 :
--   1. Un downgrade d'offre ne retirait jamais les modules complémentaires
--      installés en trop (l'école gardait l'accès à des modules qu'elle ne
--      paie plus).
--   2. Rien ne faisait jamais basculer trial→expired ni active→past_due→
--      expired : le statut affiché à l'école pouvait mentir indéfiniment.
--   3. Une même référence de versement pouvait être réutilisée sur deux
--      paiements différents (double validation par erreur ou par fraude).

-- ── 1. Downgrade : retirer les modules excédentaires à la confirmation ─────
-- Reprend `platform_confirm_subscription_payment` (déjà modifiée par
-- 20260809_module_slot_addon.sql pour la branche 'addon_slot') et ajoute,
-- côté 'plan_change', un ajustement automatique de `schools.metadata.modules`
-- si le nouveau plan a un quota plus bas que le nombre de modules
-- complémentaires actuellement installés. Priorité de conservation :
-- Finances > Présences > Inscriptions (cf. discussion "utilité des modules"
-- du 09/08/2026) — on retire d'abord les moins prioritaires.
create or replace function platform_confirm_subscription_payment(p_payment_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_payment    record;
  v_end        timestamptz;
  v_school_id  uuid;
  v_new_quota  integer;
  v_extra      integer;
  v_modules    jsonb;
  v_complements text[];
  v_kept       text[];
  v_priority   text[] := array['finance', 'attendance', 'enrollment'];
begin
  if not public.is_platform_admin(auth.uid()) then
    raise exception 'Réservé aux admins plateforme.';
  end if;

  select * into v_payment
    from public.subscription_payments
   where id = p_payment_id and status = 'pending'
   for update;

  if not found then
    raise exception 'Versement introuvable ou déjà traité.';
  end if;

  if v_payment.payment_type = 'addon_slot' then
    -- Achat d'emplacement : n'altère PAS le plan_code/period/price en cours
    -- de l'offre — augmente seulement la capacité de modules complémentaires.
    update public.subscriptions
       set extra_module_slots = extra_module_slots + v_payment.quantity,
           updated_at         = now()
     where id = v_payment.subscription_id;
  else
    v_end := case when v_payment.period = 'annual'
      then now() + interval '1 year'
      else now() + interval '1 month'
    end;

    update public.subscriptions
       set plan_code           = v_payment.plan_code,
           status               = 'active',
           billing_period       = v_payment.period,
           price                = v_payment.amount + v_payment.credit_applied,
           currency             = v_payment.currency,
           current_period_end   = v_end,
           updated_at           = now()
     where id = v_payment.subscription_id
     returning school_id, extra_module_slots into v_school_id, v_extra;

    select max_modules into v_new_quota from public.plans where code = v_payment.plan_code;
    v_new_quota := coalesce(v_new_quota, 0) + coalesce(v_extra, 0);

    select metadata -> 'modules' into v_modules from public.schools where id = v_school_id;

    select array_agg(m) into v_complements
      from jsonb_array_elements_text(coalesce(v_modules, '[]'::jsonb)) m
     where m <> 'academic';

    if v_complements is not null and array_length(v_complements, 1) > v_new_quota then
      select array_agg(x) into v_kept
        from (
          select m as x
            from unnest(v_complements) m
           order by coalesce(array_position(v_priority, m), 999)
           limit v_new_quota
        ) t;

      update public.schools
         set metadata = jsonb_set(
               metadata, '{modules}',
               to_jsonb(array_prepend('academic', coalesce(v_kept, array[]::text[])))
             )
       where id = v_school_id;
    end if;
  end if;

  update public.subscription_payments
     set status  = 'success',
         paid_at = now()
   where id = p_payment_id;
end;
$$;

-- ── 2. Cycle de vie automatique : trial→expired, active→past_due→expired ──
-- Grâce de 7 jours en `past_due` après la fin de période avant `expired`
-- complet (le temps qu'un versement en retard soit vérifié manuellement —
-- cohérent avec le fait qu'il n'y a pas de prélèvement automatique).
create or replace function public.refresh_subscription_statuses()
returns void
language plpgsql
security definer
as $$
begin
  update public.subscriptions
     set status = 'expired', updated_at = now()
   where status = 'trial'
     and trial_end is not null
     and trial_end < now();

  update public.subscriptions
     set status = 'past_due', updated_at = now()
   where status = 'active'
     and current_period_end is not null
     and current_period_end < now();

  update public.subscriptions
     set status = 'expired', updated_at = now()
   where status = 'past_due'
     and current_period_end is not null
     and current_period_end < now() - interval '7 days';
end;
$$;

-- Planification horaire via pg_cron si l'extension est activable dans cet
-- environnement (elle ne l'est pas partout selon le rôle disponible) — sinon
-- ce bloc échoue silencieusement (RAISE NOTICE) et il faudra planifier
-- `select public.refresh_subscription_statuses();` autrement (Edge Function
-- planifiée, ou appel depuis l'app au chargement du dashboard super-admin).
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when insufficient_privilege then
    raise notice 'pg_cron non activable ici — planifier refresh_subscription_statuses() autrement.';
  end;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'refresh_subscription_statuses') then
      perform cron.unschedule('refresh_subscription_statuses');
    end if;
    perform cron.schedule('refresh_subscription_statuses', '0 * * * *',
      'select public.refresh_subscription_statuses();');
  end if;
end $$;

-- Corrige tout de suite les statuts déjà périmés (n'attend pas la 1ère
-- exécution planifiée).
select public.refresh_subscription_statuses();

-- ── 3. Une référence de versement ne peut plus être réutilisée ─────────────
-- Index unique PARTIEL (pas une contrainte table, qui ne supporte pas WHERE) :
-- exclut les versements 'failed' (rejetés) pour qu'une référence invalide,
-- une fois rejetée, reste re-soumissible proprement sur un nouveau versement
-- — seule la réutilisation d'une référence encore pending/success/refunded
-- est bloquée.
drop index if exists subscription_payments_provider_reference_uniq;
create unique index subscription_payments_provider_reference_uniq
  on subscription_payments (provider, reference)
  where status <> 'failed' and reference is not null;
