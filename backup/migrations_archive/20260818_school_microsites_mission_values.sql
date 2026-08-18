-- Refonte qualité du mini-site (18/08/2026, retour utilisateur direct :
-- le rendu était trop pauvre comparé à un vrai site vitrine sur-mesure).
-- Ajoute 2 champs optionnels pour permettre une page plus riche (section
-- mission + 3 piliers de valeurs) sans obliger l'école à tout remplir —
-- ecole.html masque ces sections si vides.
alter table public.school_microsites
  add column if not exists mission text,
  add column if not exists values_pillars jsonb not null default '[]'::jsonb;

-- Réexposer dans la vue publique. DROP+CREATE (pas CREATE OR REPLACE) car
-- on insère des colonnes au milieu de la liste — Postgres refuse ça avec
-- REPLACE (« cannot change name of view column »).
drop view if exists public.public_school_microsites;
create view public.public_school_microsites as
select
  m.id,
  m.school_id,
  s.slug            as school_slug,
  m.slug            as site_slug,
  m.template_id,
  m.logo_url,
  m.accent_color,
  m.tagline,
  m.description,
  m.mission,
  m.values_pillars,
  m.hours_text,
  m.contact_phone,
  m.contact_email,
  m.address,
  m.photos,
  s.name            as school_name,
  s.city,
  s.country,
  s.preregistration_open
from public.school_microsites m
join public.schools s on s.id = m.school_id
where m.published = true
  and s.is_active
  and s.is_public;

grant select on public.public_school_microsites to anon, authenticated;
