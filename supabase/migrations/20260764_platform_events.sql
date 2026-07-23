-- ============================================================================
--  20260764_platform_events.sql — Vrai journal d'audit plateforme
--
--  Les onglets Activité/Journal de la fiche école affichaient des événements
--  INVENTÉS (PlatformMock.activityFor/timelineFor). Il n'existait aucune table
--  capturant les vrais événements du cycle de vie d'une école. On en crée une
--  (`platform_events`) alimentée automatiquement par des triggers — pas par le
--  client — pour qu'AUCUNE mutation (création d'école, changement de statut/
--  offre, prolongation d'essai, paiement) ne puisse être oubliée :
--
--  - `schools` (insert)              → 'school_created'
--  - `subscriptions` (insert/update) → 'subscription_started' / 'status_changed'
--                                       / 'plan_changed' / 'trial_extended'
--  - `subscription_payments` (insert)→ 'payment_received' / 'payment_failed'
--
--  Lecture réservée à `is_platform_admin()` (comme le reste de la console) ;
--  AUCUNE policy insert/update/delete côté client — seuls les triggers
--  (SECURITY DEFINER, donc hors RLS) écrivent dedans.
--
--  Backfill inclus pour les écoles déjà existantes (sinon leur journal serait
--  vide tant qu'aucune nouvelle action n'a lieu).
--
--  Idempotent. Rejouable (les triggers sont recréés ; le backfill utilise des
--  `where not exists` pour ne pas dupliquer à une deuxième exécution).
-- ============================================================================

create table if not exists public.platform_events (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools(id) on delete cascade,
  event_type text not null,
  metadata   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_platform_events_school
  on public.platform_events(school_id, created_at desc);

alter table public.platform_events enable row level security;
drop policy if exists platform_admin_read_events on public.platform_events;
create policy platform_admin_read_events
  on public.platform_events for select
  to authenticated
  using (public.is_platform_admin(auth.uid()));

-- ── Trigger : création d'école ───────────────────────────────────────────────
create or replace function public.log_school_created()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.platform_events (school_id, event_type, metadata, created_at)
  values (new.id, 'school_created', jsonb_build_object('name', new.name), new.created_at);
  return new;
end;
$$;

drop trigger if exists trg_log_school_created on public.schools;
create trigger trg_log_school_created
  after insert on public.schools
  for each row execute function public.log_school_created();

-- ── Trigger : abonnement (démarrage / statut / offre / échéance) ───────────
create or replace function public.log_subscription_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.platform_events (school_id, event_type, metadata, created_at)
    values (new.school_id, 'subscription_started',
            jsonb_build_object('plan_code', new.plan_code, 'status', new.status),
            new.created_at);
    return new;
  end if;

  if new.status is distinct from old.status then
    insert into public.platform_events (school_id, event_type, metadata)
    values (new.school_id, 'status_changed',
            jsonb_build_object('old_status', old.status, 'new_status', new.status));
  end if;

  if new.plan_code is distinct from old.plan_code then
    insert into public.platform_events (school_id, event_type, metadata)
    values (new.school_id, 'plan_changed',
            jsonb_build_object('old_plan', old.plan_code, 'new_plan', new.plan_code));
  end if;

  if new.current_period_end is distinct from old.current_period_end
     and old.current_period_end is not null
     and new.current_period_end > old.current_period_end then
    insert into public.platform_events (school_id, event_type, metadata)
    values (new.school_id, 'trial_extended',
            jsonb_build_object('days',
              round(extract(epoch from (new.current_period_end - old.current_period_end)) / 86400)::int));
  end if;

  return new;
end;
$$;

drop trigger if exists trg_log_subscription_change on public.subscriptions;
create trigger trg_log_subscription_change
  after insert or update on public.subscriptions
  for each row execute function public.log_subscription_change();

-- ── Trigger : paiement d'abonnement ─────────────────────────────────────────
create or replace function public.log_subscription_payment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.platform_events (school_id, event_type, metadata, created_at)
  values (new.school_id,
          case when new.status = 'success' then 'payment_received' else 'payment_failed' end,
          jsonb_build_object('amount', new.amount, 'currency', new.currency,
                              'method', coalesce(new.provider, new.method)),
          coalesce(new.paid_at, new.created_at));
  return new;
end;
$$;

drop trigger if exists trg_log_subscription_payment on public.subscription_payments;
create trigger trg_log_subscription_payment
  after insert on public.subscription_payments
  for each row execute function public.log_subscription_payment();

-- ── Backfill : écoles déjà existantes ────────────────────────────────────────
insert into public.platform_events (school_id, event_type, metadata, created_at)
select s.id, 'school_created', jsonb_build_object('name', s.name), s.created_at
from public.schools s
where not exists (
  select 1 from public.platform_events e
  where e.school_id = s.id and e.event_type = 'school_created'
);

insert into public.platform_events (school_id, event_type, metadata, created_at)
select sub.school_id, 'subscription_started',
       jsonb_build_object('plan_code', sub.plan_code, 'status', sub.status),
       sub.created_at
from public.subscriptions sub
where not exists (
  select 1 from public.platform_events e
  where e.school_id = sub.school_id and e.event_type = 'subscription_started'
);

insert into public.platform_events (school_id, event_type, metadata, created_at)
select sp.school_id,
       case when sp.status = 'success' then 'payment_received' else 'payment_failed' end,
       jsonb_build_object('amount', sp.amount, 'currency', sp.currency,
                           'method', coalesce(sp.provider, sp.method)),
       coalesce(sp.paid_at, sp.created_at)
from public.subscription_payments sp
where not exists (
  select 1 from public.platform_events e
  where e.school_id = sp.school_id
    and e.event_type in ('payment_received', 'payment_failed')
    and e.created_at = coalesce(sp.paid_at, sp.created_at)
);

-- ============================================================================
--  VERIFICATION (connecté en super-admin) :
--    select event_type, metadata, created_at from public.platform_events
--      where school_id = '<school_id>' order by created_at desc;
-- ============================================================================
