-- ============================================================================
--  20260753_enrollment_api.sql — Clé API par école + validation serveur des
--  champs obligatoires pour la pré-inscription
--
--  Jusqu'ici (20260714_public_enrollment.sql), `submitEnrollmentRequest`
--  acceptait n'importe quel payload dès lors que l'école avait ouvert ses
--  inscriptions (`preregistration_open`) : rien ne distinguait une école
--  d'une autre au niveau de la policy (n'importe qui connaissant un
--  `school_id` pouvait déposer POUR CETTE ÉCOLE), et aucun champ obligatoire
--  n'était vérifié côté serveur — seulement dans le widget Flutter. Un site
--  externe (hors app, via un simple POST HTTP) pouvait donc déposer un
--  dossier vide, ou usurper une autre école.
--
--  Ce que ça change :
--   • `schools.enrollment_api_key` : clé « publiable » propre à l'école
--     (comme une clé publishable Stripe — sûre à mettre dans le code source
--     du site de l'école, la vraie protection reste côté serveur), exposée
--     via `public_schools` pour que l'app ET un site tiers l'utilisent de la
--     même façon. Régénérable depuis Paramètres école, ce qui invalide
--     l'ancienne immédiatement.
--   • Validation des champs obligatoires AVANT insertion, par un trigger qui
--     renvoie un message clair listant les champs manquants — une policy RLS
--     ne renverrait qu'une erreur 42501 générique, inexploitable par un
--     site tiers pour afficher une erreur utile à son visiteur.
-- ============================================================================

-- ── 1. La clé, une par école ─────────────────────────────────────────────────
alter table public.schools
  add column if not exists enrollment_api_key text unique;

-- gen_random_uuid() est du cœur Postgres (>=13), pas besoin de pgcrypto —
-- cf. gen_enrollment_reference() qui fait déjà ce choix.
update public.schools
   set enrollment_api_key =
         'sch_live_' || replace(gen_random_uuid()::text, '-', '')
                     || replace(gen_random_uuid()::text, '-', '')
 where enrollment_api_key is null;

alter table public.schools
  alter column enrollment_api_key set not null,
  alter column enrollment_api_key set default (
    'sch_live_' || replace(gen_random_uuid()::text, '-', '')
                || replace(gen_random_uuid()::text, '-', '')
  );

comment on column public.schools.enrollment_api_key is
  'Clé que l''école place sur SON site pour déposer des pré-inscriptions via
   l''API REST Supabase, en plus de school_id — publiable (comme une clé
   Stripe publishable) : la protection réelle est le trigger
   enrollment_requests_guard(), pas le secret de cette valeur. Régénérable
   depuis Paramètres école (invalide l''ancienne).';

-- Exposée au même endroit que le reste de la config publique de
-- pré-inscription : l'app ET un site tiers la lisent depuis cette vue.
create or replace view public.public_schools
with (security_invoker = true) as
  select id, slug, name, city, country, address, logo_url, accent_color,
         website_url, contact_email, contact_phone,
         preregistration_open,
         enrollment_config,
         metadata -> 'types'              as types,
         metadata ->> 'motto'             as motto,
         metadata ->> 'year_founded'      as year_founded,
         metadata ->> 'educational_system' as educational_system,
         -- Ajoutée en DERNIER : `create or replace view` ne peut qu'ajouter
         -- des colonnes en fin de liste, jamais en insérer au milieu (sinon
         -- 42P16 « cannot change name of view column »).
         enrollment_api_key
    from public.schools
   where is_active and is_public;

-- ── 2. Le champ qu'un appelant fournit pour s'authentifier ──────────────────
--  Jamais conservé (voir le trigger : mis à NULL après vérification), pour ne
--  pas laisser une clé — révoquée ou non — traîner dans l'historique.
alter table public.enrollment_requests
  add column if not exists api_key text;

-- ── 3. Validation serveur : clé + champs obligatoires ───────────────────────
--  Les 3 champs « alwaysRequired » (first_name, last_name, level) le sont
--  dans TOUTE école (cf. EnrollmentFields.all côté Dart, lib/shared/data/
--  enrollment_config.dart) ; les autres dépendent de
--  schools.enrollment_config.fields[id].required, réglable par l'admin.
--  ⚠️ Si la liste alwaysRequired change côté Dart, la reporter ici aussi.
create or replace function public.enrollment_requests_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  required_ids text[];
  extra_required text[];
  missing text[];
  fid text;
begin
  select is_active, preregistration_open, enrollment_api_key, enrollment_config
    into s
    from public.schools
   where id = new.school_id;

  if not found or not s.is_active then
    raise exception 'École introuvable.' using errcode = '22023';
  end if;

  if not s.preregistration_open then
    raise exception 'Cette école n''accepte pas de pré-inscription en ce moment.'
      using errcode = '22023';
  end if;

  if new.api_key is null or new.api_key <> s.enrollment_api_key then
    raise exception 'Clé API invalide pour cette école.' using errcode = '22023';
  end if;

  required_ids := array['first_name', 'last_name', 'level'];
  if s.enrollment_config is not null then
    select array_agg(key) into extra_required
      from jsonb_each(coalesce(s.enrollment_config -> 'fields', '{}'::jsonb)) as f(key, value)
     where (value ->> 'enabled')::boolean is true
       and (value ->> 'required')::boolean is true;
    if extra_required is not null then
      required_ids := required_ids || extra_required;
    end if;
  end if;

  missing := array[]::text[];
  foreach fid in array required_ids loop
    if coalesce(nullif(trim(both from (new.payload ->> fid)), ''), '') = '' then
      missing := missing || fid;
    end if;
  end loop;

  if array_length(missing, 1) > 0 then
    raise exception 'Champs obligatoires manquants : %', array_to_string(missing, ', ')
      using errcode = '22023', detail = array_to_string(missing, ',');
  end if;

  -- La clé n'est qu'un jeton d'authentification à l'envoi : jamais stockée.
  new.api_key := null;
  return new;
end;
$$;

drop trigger if exists enrollment_requests_guard on public.enrollment_requests;
create trigger enrollment_requests_guard
  before insert on public.enrollment_requests
  for each row execute function public.enrollment_requests_guard();

-- ============================================================================
--  VERIFICATION :
--    select enrollment_api_key from public.public_schools limit 1;
--    -- doit réussir (clé publiable) :
--    insert into enrollment_requests(school_id, api_key, payload)
--      values ('<id>', '<sa vraie clé>', '{"first_name":"A","last_name":"B","level":"Collège (6e)"}'::jsonb);
--    -- doit échouer avec « Champs obligatoires manquants : ... » :
--    insert into enrollment_requests(school_id, api_key, payload)
--      values ('<id>', '<sa vraie clé>', '{}'::jsonb);
--    -- doit échouer avec « Clé API invalide... » :
--    insert into enrollment_requests(school_id, api_key, payload)
--      values ('<id>', 'fausse-cle', '{"first_name":"A","last_name":"B","level":"x"}'::jsonb);
-- ============================================================================
