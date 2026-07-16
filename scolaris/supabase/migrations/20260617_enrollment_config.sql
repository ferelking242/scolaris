-- ─────────────────────────────────────────────────────────────────────────────
-- Phase D6 — Persistance de la configuration du formulaire d'inscription
--
-- La page « Inscription — Configuration » laisse l'admin activer/désactiver
-- chaque champ et le marquer obligatoire. Jusqu'ici ces réglages étaient perdus
-- au rechargement. On les stocke en JSON sur l'école (1 config par école).
--
-- Forme : { "fields": { "<id>": { "enabled": bool, "required": bool } },
--           "allowOnlineSubmission": bool, "requirePaymentAtRegistration": bool,
--           "welcomeMessage": text|null }
--
-- L'UPDATE est déjà couvert par la policy RLS `tenant_isolation` sur `schools`
-- (l'admin gère sa propre école).
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.schools
  add column if not exists enrollment_config jsonb;
