-- ═══════════════════════════════════════════════════════════════════════════
-- Pré-inscription publique des élèves (site web)
--
-- Comble les trois trous qui empêchaient un parent d'inscrire son enfant :
--   1. `schools.slug` unique  → chaque école a une adresse web stable
--   2. `schools.preregistration_open` / `is_public` → l'école décide
--   3. `enrollment_requests`  → la table que le code Flutter attend déjà
--      (lib/features/enrollment/data/prereg_request.dart, où la file d'attente
--       est aujourd'hui une maquette en mémoire).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Adresse web stable de l'école ───────────────────────────────────────
alter table public.schools add column if not exists slug text;

-- Reprise de l'existant : `code` sert déjà de slug côté app, mais sans unicité.
update public.schools
   set slug = regexp_replace(lower(coalesce(nullif(code, ''), name)), '[^a-z0-9]+', '-', 'g')
 where slug is null;

-- Désambiguïsation des doublons éventuels (suffixe numérique).
with d as (
  select id, slug, row_number() over (partition by slug order by created_at) as n
    from public.schools
)
update public.schools s
   set slug = s.slug || '-' || d.n
  from d
 where s.id = d.id and d.n > 1;

alter table public.schools alter column slug set not null;
create unique index if not exists schools_slug_key on public.schools (slug);

-- ── 2. L'école décide de sa visibilité ─────────────────────────────────────
alter table public.schools add column if not exists is_public boolean not null default false;
alter table public.schools add column if not exists preregistration_open boolean not null default false;

comment on column public.schools.is_public is
  'Visible dans l''annuaire public du site. L''école l''active elle-même.';
comment on column public.schools.preregistration_open is
  'Accepte les demandes d''inscription en ligne.';

-- ── 3. Les demandes d'inscription ──────────────────────────────────────────
create table if not exists public.enrollment_requests (
  id           uuid primary key default gen_random_uuid(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  reference    text not null unique,          -- code de suivi remis à la famille
  payload      jsonb not null default '{}',   -- champs remplis, cf. schools.enrollment_config
  status       text  not null default 'pending'
               check (status in ('pending', 'accepted', 'rejected')),
  student_id   uuid references public.users(id) on delete set null,  -- rempli à l'acceptation
  note         text,                          -- motif du refus / commentaire interne
  reviewed_by  uuid references public.users(id) on delete set null,
  reviewed_at  timestamptz,
  submitted_at timestamptz not null default now()
);

create index if not exists enrollment_requests_school_status_idx
  on public.enrollment_requests (school_id, status, submitted_at desc);

-- Référence lisible et non devinable : SCO-4F2K9A
create or replace function public.gen_enrollment_reference()
returns text language sql volatile as $$
  select 'SCO-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
$$;

alter table public.enrollment_requests
  alter column reference set default public.gen_enrollment_reference();

-- ── 4. RLS ─────────────────────────────────────────────────────────────────
alter table public.enrollment_requests enable row level security;

-- Le parent dépose sa demande sans compte — mais uniquement sur une école qui
-- a effectivement ouvert ses inscriptions. C'est le garde-fou anti-spam.
drop policy if exists enrollment_requests_public_insert on public.enrollment_requests;
create policy enrollment_requests_public_insert
  on public.enrollment_requests for insert to anon, authenticated
  with check (
    exists (
      select 1 from public.schools s
       where s.id = school_id
         and s.is_active
         and s.preregistration_open
    )
  );

-- L'école ne voit que ses propres demandes, et elle seule peut les traiter.
drop policy if exists enrollment_requests_school_read on public.enrollment_requests;
create policy enrollment_requests_school_read
  on public.enrollment_requests for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists enrollment_requests_school_update on public.enrollment_requests;
create policy enrollment_requests_school_update
  on public.enrollment_requests for update to authenticated
  using (public.is_member_of(school_id))
  with check (public.is_member_of(school_id));

-- ── 5. Lecture publique des écoles ouvertes ────────────────────────────────
-- La RLS de `schools` bloque tout SELECT anonyme. On ouvre le strict minimum,
-- via une vue : le site n'accède JAMAIS aux colonnes internes (db_config, etc.).
drop policy if exists schools_public_read on public.schools;
create policy schools_public_read
  on public.schools for select to anon
  using (is_active and is_public);

create or replace view public.public_schools
with (security_invoker = true) as
  select id, slug, name, city, country, address, logo_url, accent_color,
         website_url, contact_email, contact_phone,
         preregistration_open,
         enrollment_config,
         metadata -> 'types'              as types,
         metadata ->> 'motto'             as motto,
         metadata ->> 'year_founded'      as year_founded,
         metadata ->> 'educational_system' as educational_system
    from public.schools
   where is_active and is_public;

grant select on public.public_schools to anon, authenticated;

-- Le suivi de la demande par la famille : lecture par référence exacte
-- (le code n'est pas devinable), sans exposer la liste des demandes.
create or replace function public.track_enrollment_request(p_reference text)
returns table (reference text, status text, school_name text, submitted_at timestamptz, note text)
language sql stable security definer set search_path = public as $$
  select r.reference, r.status, s.name, r.submitted_at,
         case when r.status = 'rejected' then r.note end
    from public.enrollment_requests r
    join public.schools s on s.id = r.school_id
   where r.reference = upper(trim(p_reference));
$$;

grant execute on function public.track_enrollment_request(text) to anon, authenticated;
