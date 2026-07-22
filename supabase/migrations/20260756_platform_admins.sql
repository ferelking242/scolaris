-- ============================================================================
--  20260756_platform_admins.sql — La console super-admin sort de l'allowlist
--  codée en dur
--
--  ── Le problème ─────────────────────────────────────────────────────────────
--  `PlatformAdmins.emails` (lib/core/permissions/platform_admin.dart) était un
--  Set<String> codé en dur dans le client Flutter, seule protection de la
--  console qui gère TOUTES les écoles. Deux soucis :
--    1. Aucune barrière côté base : les pages plateforme lisent aujourd'hui des
--       données MOCK, donc pas de fuite réelle pour l'instant — mais le jour où
--       elles liront les vraies tables (schools, subscriptions...), rien
--       n'empêcherait un accès direct à l'API Supabase de tout lire, puisque
--       la seule protection vivait dans le code du client, pas dans la RLS.
--    2. Modifier la liste des admins = modifier le code source et redéployer.
--
--  ── Ce que ça change ─────────────────────────────────────────────────────────
--  Une vraie table + une fonction utilisable dans n'importe quelle policy RLS
--  future, dès qu'on branchera les pages plateforme sur les vraies données.
-- ============================================================================

create table if not exists public.platform_admins (
  user_id     uuid primary key references public.users(id) on delete cascade,
  granted_by  uuid references public.users(id) on delete set null,
  granted_at  timestamptz not null default now()
);

comment on table public.platform_admins is
  'Les super-admins plateforme (créateurs de Scolaris) — au-dessus de toutes
   les écoles. Remplace l''ancienne allowlist d''emails codée en dur côté
   client. Pas de policy insert/update/delete pour les clients authentifiés :
   on ajoute/retire un admin par SQL direct pour l''instant (v1), jamais
   depuis l''app — un admin plateforme ne doit pas pouvoir s''auto-accorder ce
   statut ni l''accorder à quelqu''un d''autre depuis l''interface.';

-- ── La fonction, réutilisable par toute future policy RLS plateforme ───────
--  Prend un auth_uid (auth.uid()), pas un users.id — c'est ce que l'app
--  connaît côté session, et ce que les futures policies passeront.
--  DOIT être créée AVANT la policy qui l'utilise ci-dessous.
create or replace function public.is_platform_admin(p_auth_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.platform_admins pa
      join public.users u on u.id = pa.user_id
     where u.auth_uid = p_auth_uid
  );
$$;

grant execute on function public.is_platform_admin(uuid) to authenticated;

alter table public.platform_admins enable row level security;

drop policy if exists platform_admins_read on public.platform_admins;
create policy platform_admins_read on public.platform_admins
  for select to authenticated
  using (public.is_platform_admin(auth.uid()));

-- Pas de policy insert/update/delete : voir le commentaire de table.

-- ── Seed : le compte actuellement dans l'allowlist ─────────────────────────
--  Reprend TOUTES les lignes `users` correspondant à cet email (un même auth
--  peut apparaître dans plusieurs écoles) — inoffensif si aucune ne correspond.
insert into public.platform_admins (user_id)
select id from public.users where email = 'kenganiboveldy@gmail.com'
on conflict (user_id) do nothing;

-- ============================================================================
--  VERIFICATION :
--    select pa.user_id, u.email, u.full_name from platform_admins pa
--      join users u on u.id = pa.user_id;
--    select public.is_platform_admin(u.auth_uid) from public.users u
--      where u.email = 'kenganiboveldy@gmail.com' limit 1;
-- ============================================================================
