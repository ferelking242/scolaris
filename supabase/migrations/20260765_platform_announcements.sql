-- ============================================================================
--  20260765_platform_announcements.sql — Vraies annonces plateforme
--
--  Jusqu'ici, publier une annonce (console super-admin) n'ajoutait qu'une
--  ligne dans une liste en mémoire — aucune école ne la voyait jamais. On crée
--  la vraie table + une fonction de distribution que l'app de CHAQUE école
--  appelle pour savoir quelles annonces la concernent, selon son statut
--  d'abonnement (toutes / payantes / en essai / en impayé).
--
--  Écriture : réservée à `is_platform_admin()` — SEULE table de la console où
--  on donne un vrai droit d'écriture au-delà des mutations déjà couvertes par
--  des méthodes dédiées (schools/subscriptions) : rédiger une annonce est
--  littérallement le rôle de cet écran, contrairement à `platform_admins` où
--  s'auto-accorder l'accès serait un risque.
--
--  Idempotent. Rejouable.
-- ============================================================================

create table if not exists public.platform_announcements (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  body       text not null,
  kind       text not null check (kind in ('info', 'maintenance', 'feature')),
  audience   text not null check (audience in ('all', 'paying', 'trials', 'past_due')),
  reach      integer not null default 0,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

alter table public.platform_announcements enable row level security;

drop policy if exists platform_admin_manage_announcements on public.platform_announcements;
create policy platform_admin_manage_announcements
  on public.platform_announcements for all
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

-- ── Distribution : ce que l'école CONNECTÉE doit voir ───────────────────────
-- Sécurité par construction : jamais de school_id en paramètre — toujours
-- `current_school_id()`, comme le reste de l'app (personne ne peut lire les
-- annonces destinées à une autre école en manipulant un paramètre).
create or replace function public.my_platform_announcements()
returns table(id uuid, title text, body text, kind text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.title, a.body, a.kind, a.created_at
  from public.platform_announcements a
  left join public.subscriptions s on s.school_id = public.current_school_id()
  where a.audience = 'all'
     or (a.audience = 'trials' and s.status = 'trial')
     or (a.audience = 'past_due' and s.status = 'past_due')
     or (a.audience = 'paying' and s.status in ('active', 'past_due'))
  order by a.created_at desc
  limit 5;
$$;

grant execute on function public.my_platform_announcements() to authenticated;

-- ============================================================================
--  VERIFICATION :
--    -- connecté en super-admin : insert public.platform_announcements(...) puis
--    select * from platform_announcements;
--    -- connecté en admin d'une école quelconque :
--    select * from my_platform_announcements();
-- ============================================================================
