-- 20260809_module_slot_addon.sql
--
-- Achat à la carte d'un EMPLACEMENT de module supplémentaire — décision du
-- 09/08/2026 (cf. conversation business plan) : l'école achète de la
-- CAPACITÉ, pas un module précis. Elle choisit ensuite depuis le catalogue
-- existant (`AdminSubscriptionPage`) quel module installer dedans — un
-- emplacement acheté fonctionne pour n'importe quel module actuel ou futur
-- du catalogue, ce qui évite de créer un SKU par module et reste cohérent
-- avec le modèle "app store" à quota introduit par
-- 20260809_module_marketplace.sql.

-- ── 1. Compteur d'emplacements achetés en plus du quota de l'offre ─────────
alter table subscriptions add column if not exists extra_module_slots integer not null default 0;

-- ── 2. Pseudo-offre cachée pour rattacher les paiements d'emplacement
--      (plan_code sur subscription_payments est FK -> plans, obligatoire) —
--      jamais listée publiquement (is_active = false donc absente de
--      `getPlans()`, qui filtre is_active = true).
insert into plans (code, name, tagline, max_students, features, sort_order, is_active, included_students, max_modules)
values ('addon_slot', 'Emplacement supplémentaire',
        'Un emplacement de module complémentaire en plus de votre offre',
        null, '[]'::jsonb, 99, false, null, null)
on conflict (code) do nothing;

insert into plan_prices (plan_code, period, price, currency, country, is_active)
values
  ('addon_slot', 'monthly', 15000, 'XAF', 'CG', true),
  ('addon_slot', 'annual', 150000, 'XAF', 'CG', true)
on conflict (plan_code, country, period) do nothing;

-- ── 3. Distinction du type de versement : un versement d'emplacement ne
--      doit JAMAIS écraser le plan_code/period en cours à la confirmation
--      (contrairement à un changement d'offre classique).
alter table subscription_payments add column if not exists payment_type text not null default 'plan_change';
alter table subscription_payments drop constraint if exists subscription_payments_payment_type_check;
alter table subscription_payments add constraint subscription_payments_payment_type_check
  check (payment_type in ('plan_change', 'addon_slot'));

alter table subscription_payments add column if not exists quantity integer not null default 1;

-- ── 4. Confirmation (super-admin) : branche selon le type de versement.
--      Signature/sécurité identiques à la version d'origine (security definer).
create or replace function platform_confirm_subscription_payment(p_payment_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_payment record;
  v_end     timestamptz;
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
     where id = v_payment.subscription_id;
  end if;

  update public.subscription_payments
     set status  = 'success',
         paid_at = now()
   where id = p_payment_id;
end;
$$;
