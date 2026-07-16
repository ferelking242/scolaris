-- ============================================================
-- SCOLARIS — Module Abonnement (SaaS B2B : l'ecole paie Scolaris)
-- A relire PUIS exécuter dans : Supabase Dashboard > SQL Editor.
--
-- Modele : 3 offres (Simple/Pro/Max) differenciees par fonctionnalites + limite
-- d'eleves. Prix = f(offre, pays, periode) → table plan_prices (multi-pays).
-- Chaque ecole a UN abonnement (essai → actif → ...). Paiements traces a part.
--
-- NB : `schools.plan_type` (enum free/pro/enterprise) devient obsolete au profit
--      de subscriptions.plan_code. On le laisse en place sans s'en servir.
-- Idempotent. Backup conseille.
-- ============================================================

begin;

-- ── 1. Offres (catalogue global, non lie a une ecole) ───────────────────────
create table if not exists public.plans (
  code         text primary key,                 -- 'simple' | 'pro' | 'max'
  name         text not null,
  tagline      text,
  max_students integer,                           -- NULL = illimite
  features     jsonb not null default '[]',       -- liste de cles de fonctionnalites
  sort_order   integer not null default 0,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

insert into public.plans (code, name, tagline, max_students, sort_order, features) values
  ('simple','Simple','Le socle pédagogique', 200, 1,
   '["eleves","classes","matieres","notes","bulletins","presences","emploi_du_temps"]'),
  ('pro','Pro','Parents, finance & communication', 1000, 2,
   '["simple","portail_parents","messagerie","annonces","finance","bibliotheque","qr","surveillance","rapports"]'),
  ('max','Max','Groupes scolaires & premium', null, 3,
   '["pro","multi_etablissements","marque_blanche","hors_ligne","support_dedie","export_api","analytics"]')
on conflict (code) do update
  set name = excluded.name, tagline = excluded.tagline,
      max_students = excluded.max_students, features = excluded.features,
      sort_order = excluded.sort_order;

-- ── 2. Grille de prix par pays / periode (multi-pays) ───────────────────────
create table if not exists public.plan_prices (
  id         uuid primary key default gen_random_uuid(),
  plan_code  text not null references public.plans(code) on delete cascade,
  country    text not null,                       -- code ISO pays ('CG', ...)
  currency   text not null,                       -- 'XAF', ...
  period     text not null check (period in ('monthly','annual')),
  price      numeric not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  unique (plan_code, country, period)
);

-- Congo (CG / XAF). Annuel = 10 mois payes (2 offerts).
insert into public.plan_prices (plan_code, country, currency, period, price) values
  ('simple','CG','XAF','monthly', 14900), ('simple','CG','XAF','annual', 149000),
  ('pro',   'CG','XAF','monthly', 29900), ('pro',   'CG','XAF','annual', 299000),
  ('max',   'CG','XAF','monthly', 59900), ('max',   'CG','XAF','annual', 599000)
on conflict (plan_code, country, period) do update set price = excluded.price;

-- ── 3. Abonnement d'une ecole (UN par ecole) ────────────────────────────────
create table if not exists public.subscriptions (
  id                   uuid primary key default gen_random_uuid(),
  school_id            uuid not null unique references public.schools(id) on delete cascade,
  plan_code            text references public.plans(code),     -- offre choisie (Simple pendant l'essai)
  status               text not null default 'trial'
                         check (status in ('trial','active','past_due','canceled','expired')),
  billing_period       text not null default 'monthly'
                         check (billing_period in ('monthly','annual')),
  country              text not null default 'CG',
  currency             text not null default 'XAF',
  price                numeric,                                 -- prix verrouille a la souscription
  trial_end            timestamptz,
  current_period_start timestamptz,
  current_period_end   timestamptz,
  cancel_at            timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index if not exists idx_sub_school on public.subscriptions(school_id);

-- ── 4. Paiements de l'abonnement (ecole → Scolaris) ─────────────────────────
create table if not exists public.subscription_payments (
  id              uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  school_id       uuid not null references public.schools(id) on delete cascade,
  amount          numeric not null,
  currency        text not null default 'XAF',
  method          text check (method in ('mobile_money','card','bank','cash')),
  provider        text,                                         -- 'mtn','airtel','visa'...
  reference       text,                                         -- ref transaction
  status          text not null default 'pending'
                    check (status in ('pending','success','failed','refunded')),
  paid_at         timestamptz,
  created_at      timestamptz not null default now()
);
create index if not exists idx_subpay_sub on public.subscription_payments(subscription_id);

-- ── 5. Essai gratuit pour l'ecole demo EAD (Simple pendant 30 jours) ────────
insert into public.subscriptions (school_id, plan_code, status, trial_end, current_period_start, current_period_end)
values ('de3764d3-f0e6-4191-ba89-ab4c73cf37a1','simple','trial',
        now() + interval '30 days', now(), now() + interval '30 days')
on conflict (school_id) do nothing;

-- ── 6. RLS ──────────────────────────────────────────────────────────────────
-- Catalogues (plans, plan_prices) : lecture pour tout connecte.
alter table public.plans       enable row level security;
alter table public.plan_prices enable row level security;
drop policy if exists shared_read on public.plans;
drop policy if exists shared_read on public.plan_prices;
create policy shared_read on public.plans       for select to authenticated using (true);
create policy shared_read on public.plan_prices for select to authenticated using (true);

-- Abonnement & paiements : cloisonnes par ecole (tenant).
alter table public.subscriptions         enable row level security;
alter table public.subscription_payments enable row level security;
drop policy if exists tenant_isolation on public.subscriptions;
drop policy if exists tenant_isolation on public.subscription_payments;
create policy tenant_isolation on public.subscriptions for all to authenticated
  using (school_id = public.current_school_id())
  with check (school_id = public.current_school_id());
create policy tenant_isolation on public.subscription_payments for all to authenticated
  using (school_id = public.current_school_id())
  with check (school_id = public.current_school_id());

commit;

-- ── 7. Aide a l'enforcement de la limite d'eleves ───────────────────────────
-- Renvoie la limite d'eleves de l'ecole (NULL = illimite), via son abonnement.
create or replace function public.school_student_limit(p_school uuid)
returns integer language sql stable security definer set search_path = public as $$
  select p.max_students
  from public.subscriptions s
  join public.plans p on p.code = s.plan_code
  where s.school_id = p_school
  limit 1;
$$;

-- Renvoie le nombre d'eleves actuels de l'ecole.
create or replace function public.school_student_count(p_school uuid)
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::int from public.users
  where school_id = p_school and role = 'student' and status = 'active';
$$;

-- Peut-on encore ajouter un eleve ? (tolerance +5% comme prevu au business plan)
create or replace function public.school_can_add_student(p_school uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when public.school_student_limit(p_school) is null then true       -- illimite (Max)
    else public.school_student_count(p_school) < floor(public.school_student_limit(p_school) * 1.05)
  end;
$$;
grant execute on function public.school_student_limit(uuid),
                         public.school_student_count(uuid),
                         public.school_can_add_student(uuid) to authenticated;

-- ============================================================
-- Resultat : 30 -> 34 tables. EAD = essai Pro 30 jours.
-- Verif : select * from public.plans;  select * from public.subscriptions;
-- ============================================================
