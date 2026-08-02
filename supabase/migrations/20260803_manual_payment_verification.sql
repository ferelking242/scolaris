-- ─────────────────────────────────────────────────────────────────────────
-- Paiement Mobile Money SANS agrégateur : le parent envoie l'argent lui-même
-- (USSD, hors app) vers le numéro marchand de l'école, puis saisit la
-- référence reçue par SMS dans l'app. Ça crée un versement `pending`, que
-- l'admin vérifie sur son propre relevé marchand avant de confirmer.
--
-- `payments.status` n'existait pas : tout INSERT valait encaissement ferme.
-- Défaut 'confirmed' pour ne rien casser sur les lignes existantes et les
-- écritures directes du staff (caisse) — seul le flux famille écrit 'pending'.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.payments
  add column if not exists status text not null default 'confirmed'
    check (status in ('pending','confirmed','rejected'));

create index if not exists idx_payments_status on public.payments(status);

comment on column public.payments.status is
  'pending = référence Mobile Money saisie par la famille, pas encore vérifiée par l''admin. confirmed = encaissement acquis (compte dans le solde). rejected = référence invalide/introuvable.';
