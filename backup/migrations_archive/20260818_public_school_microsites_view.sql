-- Vue publique du mini-site (18/08/2026) — même schéma de sécurité que
-- `public_schools` (vue non `security_invoker`, contourne la RLS staff-only
-- de `school_microsites` volontairement, mais NE RENVOIE QUE les colonnes de
-- contenu déjà destinées à être publiques + uniquement les sites publiés).
create or replace view public.public_school_microsites as
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
