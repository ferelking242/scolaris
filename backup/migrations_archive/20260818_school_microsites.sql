-- Mini-site école (module Inscriptions, palier Croissance+) — 18/08/2026.
-- Contenu de configuration uniquement pour l'instant : pas de rendu public
-- branché tant que l'hébergement/domaine n'est pas décidé (cf. conversation
-- "module site web"). Une école prépare son contenu, `published` reste false
-- jusqu'à ce que la fonctionnalité de diffusion existe réellement.

create table if not exists public.school_microsites (
  id            uuid primary key default gen_random_uuid(),
  school_id     uuid not null references public.schools(id) on delete cascade,
  slug          text not null unique,
  template_id   text not null default 'basique',
  logo_url      text,
  accent_color  text,
  tagline       text,
  description   text,
  hours_text    text,
  contact_phone text,
  contact_email text,
  address       text,
  photos        jsonb not null default '[]'::jsonb,
  published     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint school_microsites_school_unique unique (school_id)
);

create index if not exists idx_school_microsites_school on public.school_microsites(school_id);

alter table public.school_microsites enable row level security;

-- Lecture/écriture réservées au staff de l'école propriétaire — même schéma
-- que les autres tables admin (school_members).
drop policy if exists school_microsites_staff_all on public.school_microsites;
create policy school_microsites_staff_all on public.school_microsites
  for all
  using (
    exists (
      select 1 from public.school_members sm
      where sm.school_id = school_microsites.school_id
        and sm.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.school_members sm
      where sm.school_id = school_microsites.school_id
        and sm.user_id = auth.uid()
    )
  );

create or replace function public.set_school_microsites_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_school_microsites_updated_at on public.school_microsites;
create trigger trg_school_microsites_updated_at
  before update on public.school_microsites
  for each row execute function public.set_school_microsites_updated_at();

-- Table créée après 20260809_enforce_subscription_rls.sql : son trigger
-- générique (boucle sur toutes les tables avec school_id) ne l'a pas
-- couverte rétroactivement — posé explicitement ici. Une école hors règle
-- (abonnement expiré) ne doit pas pouvoir enregistrer de config mini-site.
drop trigger if exists trg_enforce_subscription_active on public.school_microsites;
create trigger trg_enforce_subscription_active
  before insert or update on public.school_microsites
  for each row execute function public.enforce_subscription_active();
