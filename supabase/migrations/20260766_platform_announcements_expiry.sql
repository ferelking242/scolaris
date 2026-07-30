-- ============================================================================
--  20260766_platform_announcements_expiry.sql — Expiration + dépublication
--
--  Jusqu'ici une annonce restait active indéfiniment : une fois publiée, elle
--  n'avait aucune date de fin et ne pouvait pas être retirée en cas d'erreur —
--  seule chaque école pouvait la masquer chez elle (masquage local, pas une
--  vraie fin de diffusion). On ajoute :
--    - `expires_at` (optionnel) : l'annonce arrête d'être distribuée après
--      cette date, sans action du super-admin.
--    - `archived_at` : dépublication manuelle immédiate depuis la console.
--
--  Idempotent. Rejouable.
-- ============================================================================

alter table public.platform_announcements
  add column if not exists expires_at timestamptz,
  add column if not exists archived_at timestamptz;

-- ── Distribution : exclut désormais les annonces expirées/dépubliées ────────
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
  where a.archived_at is null
    and (a.expires_at is null or a.expires_at > now())
    and (
      a.audience = 'all'
      or (a.audience = 'trials' and s.status = 'trial')
      or (a.audience = 'past_due' and s.status = 'past_due')
      or (a.audience = 'paying' and s.status in ('active', 'past_due'))
    )
  order by a.created_at desc
  limit 5;
$$;

-- ============================================================================
--  VERIFICATION :
--    -- connecté en super-admin :
--    update platform_announcements set archived_at = now() where id = '...';
--    -- connecté en admin d'une école quelconque :
--    select * from my_platform_announcements(); -- ne doit plus la lister
-- ============================================================================
