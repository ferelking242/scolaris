-- ============================================================================
--  20260769_preserve_financial_records_on_delete.sql — un compte supprimé ne
--  doit pas effacer les pièces comptables ni les décisions de passage.
--
--  ── Le problème ────────────────────────────────────────────────────────────
--  `invoices_student_id_fkey` et `payments_student_id_fkey` sont en NO ACTION :
--  supprimer un élève qui a des factures/paiements est bloqué (FK 23503).
--  `student_progressions_student_id_fkey` est en CASCADE : supprimer un élève
--  efface silencieusement l'historique de ses décisions de passage/redoublement.
--  Ces trois tables sont des pièces à conserver (comptabilité, administratif),
--  au même titre que `report_cards`, qui garde déjà `student_name` en dur et
--  n'a volontairement aucune FK vers `users`.
--
--  ── Le correctif ────────────────────────────────────────────────────────────
--  1. Ajoute `student_name` (snapshot) sur les 3 tables, rempli par trigger à
--     l'insertion — aucun changement requis côté app/Dart.
--  2. Bascule les 3 FK en `ON DELETE SET NULL` : le lien vers le compte
--     disparaît si le compte est supprimé, mais la ligne (montant, décision,
--     nom figé) reste consultable.
-- ============================================================================

-- 1. Colonnes de snapshot.
alter table public.invoices add column if not exists student_name text;
alter table public.payments add column if not exists student_name text;
alter table public.student_progressions add column if not exists student_name text;

-- Backfill des lignes existantes.
update public.invoices i set student_name = u.full_name
  from public.users u where u.id = i.student_id and i.student_name is null;
update public.payments p set student_name = u.full_name
  from public.users u where u.id = p.student_id and p.student_name is null;
update public.student_progressions sp set student_name = u.full_name
  from public.users u where u.id = sp.student_id and sp.student_name is null;

-- 2. Trigger : fige le nom au moment de l'insertion (silencieux si student_id
--    absent — la ligne reste insérable, juste sans nom figé).
create or replace function public.snapshot_student_name()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
  if new.student_name is null and new.student_id is not null then
    select full_name into new.student_name from public.users where id = new.student_id;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_invoices_snapshot_name on public.invoices;
create trigger trg_invoices_snapshot_name
  before insert on public.invoices
  for each row execute function public.snapshot_student_name();

drop trigger if exists trg_payments_snapshot_name on public.payments;
create trigger trg_payments_snapshot_name
  before insert on public.payments
  for each row execute function public.snapshot_student_name();

drop trigger if exists trg_progressions_snapshot_name on public.student_progressions;
create trigger trg_progressions_snapshot_name
  before insert on public.student_progressions
  for each row execute function public.snapshot_student_name();

-- 3. FK : SET NULL au lieu de bloquer / effacer silencieusement.
alter table public.invoices
  drop constraint invoices_student_id_fkey,
  add constraint invoices_student_id_fkey
    foreign key (student_id) references public.users(id) on delete set null;

alter table public.payments
  drop constraint payments_student_id_fkey,
  add constraint payments_student_id_fkey
    foreign key (student_id) references public.users(id) on delete set null;

alter table public.student_progressions
  drop constraint student_progressions_student_id_fkey,
  add constraint student_progressions_student_id_fkey
    foreign key (student_id) references public.users(id) on delete set null;
