-- Phase 3 mini-site (18/08/2026) — domaine personnalisé, palier Complet.
-- Stockage uniquement : aucune vérification DNS/CNAME automatisée pour
-- l'instant (pas d'infra de reverse-proxy multi-domaine en place). L'école
-- saisit son domaine, un humain (support Scolaris) le branche manuellement
-- côté hébergeur le jour où c'est demandé — cf. conversation "module site
-- web". `custom_domain_verified` sert de futur signal une fois l'automatisation
-- construite ; reste false tant que ce n'est pas le cas.
alter table public.school_microsites
  add column if not exists custom_domain text,
  add column if not exists custom_domain_verified boolean not null default false;

-- Réexposer les nouvelles colonnes dans la vue publique (le domaine perso
-- reste privé — seul le statut vérifié est utile publiquement, pour
-- éventuellement rediriger plus tard ; pas exposé pour l'instant, non ajouté
-- à la vue tant qu'il n'y a pas d'usage public réel).
