-- ============================================================================
--  20260804_platform_subscription_payments.sql — File de vérification des
--  versements d'abonnement (pas d'agrégateur branché)
--
--  Les écoles envoient leur règlement Mobile Money au numéro marchand de
--  Scolaris (hors app, USSD) puis saisissent la référence reçue par SMS —
--  ça écrit une ligne `subscription_payments` en `pending` (cf.
--  submitSubscriptionPayment dans supabase_db_source.dart). Il faut que la
--  console super-admin puisse VOIR ces versements en attente, toutes écoles
--  confondues, et les CONFIRMER/REJETER.
--
--  Même philosophie que 20260757 (lecture cross-écoles pour les admins
--  plateforme, sans élargir tenant_isolation) : lecture par policy RLS,
--  écriture UNIQUEMENT via des fonctions dédiées et étroites — jamais une
--  policy UPDATE générique, pour ne pas laisser la console modifier un
--  abonnement en contournant l'action prévue.
-- ============================================================================

-- ── Lecture cross-écoles (liste des versements en attente) ─────────────────
drop policy if exists platform_admin_read_subpay on public.subscription_payments;
create policy platform_admin_read_subpay on public.subscription_payments
  for select to authenticated
  using (public.is_platform_admin(auth.uid()));

-- ── Confirmation : active l'abonnement ET solde le versement, en une seule
-- transaction. Ne fait rien si l'appelant n'est pas admin plateforme ou si
-- le versement n'est plus `pending` (déjà traité).
create or replace function public.platform_confirm_subscription_payment(p_payment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
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

  update public.subscription_payments
     set status  = 'success',
         paid_at = now()
   where id = p_payment_id;
end;
$$;

grant execute on function public.platform_confirm_subscription_payment(uuid) to authenticated;

-- ── Rejet : la référence est invalide/introuvable — reste tracé, jamais
-- supprimé, et n'active rien.
create or replace function public.platform_reject_subscription_payment(p_payment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin(auth.uid()) then
    raise exception 'Réservé aux admins plateforme.';
  end if;

  update public.subscription_payments
     set status = 'failed'
   where id = p_payment_id and status = 'pending';
end;
$$;

grant execute on function public.platform_reject_subscription_payment(uuid) to authenticated;

-- ============================================================================
--  VERIFICATION (connecté en tant qu'admin plateforme) :
--    select * from subscription_payments where status = 'pending';  -- toutes écoles
--    select platform_confirm_subscription_payment('<id>');
-- ============================================================================
