-- ============================================================
-- SCOLARIS — Reçus d'abonnement (SaaS : l'école paie Scolaris)
-- A relire PUIS exécuter dans : Supabase Dashboard > SQL Editor.
--
-- La table `subscription_payments` existe déjà (cf. 20260617_subscriptions.sql,
-- volontairement conservée par 20260730_prune_dead_tables.sql). On l'enrichit
-- pour que CHAQUE reçu soit AUTO-PORTEUR : l'offre et la période sont figées au
-- moment du paiement, car l'abonnement de l'école peut changer ensuite (un reçu
-- ré-imprimé un an plus tard doit toujours montrer l'offre payée ce jour-là).
--
-- Idempotent. Aucune donnée existante (table à 0 ligne au moment de ce chantier).
-- ============================================================

begin;

alter table public.subscription_payments
  add column if not exists plan_code      text references public.plans(code),
  add column if not exists period         text check (period in ('monthly','annual')),
  add column if not exists credit_applied numeric not null default 0;

comment on column public.subscription_payments.plan_code      is 'Offre payée, figée pour le reçu (peut différer de l''abonnement courant).';
comment on column public.subscription_payments.period         is 'Période facturée : monthly | annual.';
comment on column public.subscription_payments.credit_applied is 'Crédit (prorata + report) déduit du prix plein ; montant plein = amount + credit_applied.';

commit;

-- Vérif : select id, plan_code, period, amount, credit_applied, currency, status, paid_at
--         from public.subscription_payments order by paid_at desc;
