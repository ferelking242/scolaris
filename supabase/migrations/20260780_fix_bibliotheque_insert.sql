-- ============================================================================
--  20260780_fix_bibliotheque_insert.sql — `bibliotheque.ajouter` jamais
--  vérifié : n'importe quel compte authentifié pouvait soumettre au catalogue
--
--  ── Le trou ─────────────────────────────────────────────────────────────────
--  `bibliotheque_insert` n'exigeait que `auth.uid() is not null` — un élève,
--  un parent, n'importe qui avec un compte pouvait soumettre une ressource au
--  catalogue partagé, sans passer par le droit fin `bibliotheque.ajouter`
--  affiché dans « Rôles & permissions ». La modération (`bibliotheque_moderate`,
--  réservée à `is_platform_admin`) reste le dernier filtre avant publication,
--  donc le risque réel était limité au bruit/spam en file de modération — pas
--  une fuite de données — mais la case ne protégeait toujours rien.
--
--  ── Vérifié avant d'agir ─────────────────────────────────────────────────────
--  Aucun modèle de rôle n'accorde `bibliotheque.ajouter` — seule la Direction
--  l'a via le bypass fondateur/`is_admin_role`. Aucun backfill nécessaire.
-- ============================================================================

drop policy if exists bibliotheque_insert on public.bibliotheque;
create policy bibliotheque_insert on public.bibliotheque
  for insert to authenticated
  with check (
    auth.uid() is not null
    and public.has_permission(auth.uid(), 'bibliotheque', 'ajouter')
  );

-- ============================================================================
--  VERIFICATION :
--    select has_permission(u.auth_uid,'bibliotheque','ajouter')
--      from users u where u.role::text = 'student' limit 1;
--    -- attendu : false
-- ============================================================================
