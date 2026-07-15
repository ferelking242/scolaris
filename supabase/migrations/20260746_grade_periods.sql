-- ============================================================================
--  20260746_grade_periods.sql — ÉTAPE 1 : le verrou REEL du trimestre
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--
--  Le « verrou » d'une note etait cosmetique : le carnet n'affichait pas le
--  champ, mais RIEN n'empechait l'ecriture cote serveur. Un appel direct a l'API
--  passait outre. Un bulletin officiel ne peut pas reposer sur un verrou qu'on
--  contourne en une requete.
--
--  ── Ce que fait cette etape ─────────────────────────────────────────────────
--
--  Une periode de notes (une CLASSE x un TRIMESTRE) a desormais un ETAT :
--
--    open       saisie libre — les regles habituelles s'appliquent (le prof, sa
--               classe). C'est l'etat par defaut : sans ligne, tout est ouvert.
--    validated  GELEE. Le prof ne touche plus. Seul `notes.corriger` peut
--               encore ecrire (l'etape 2 y ajoutera le motif obligatoire + la
--               trace). Le bulletin officiel a ete fige.
--    locked     SCELLEE. Personne n'ecrit, point. Il faut deverrouiller d'abord.
--
--  Le garde-fou est un TRIGGER `security definer` sur `grades` : l'application ne
--  peut pas le contourner, contrairement a une simple policy d'ecran.
--
--  Cette etape ne CREE aucune periode : toutes restent donc « open », et le
--  comportement actuel est inchange. Les transitions (valider / verrouiller)
--  arrivent a l'etape 3.
-- ============================================================================

-- ── 1. L'etat d'une periode ─────────────────────────────────────────────────
--  Cle = (classe, periode). La classe porte deja son annee scolaire : pas
--  besoin de la repeter dans la cle. On la garde pour l'affichage.
create table if not exists public.grade_periods (
  id             uuid primary key default gen_random_uuid(),
  school_id      uuid not null references public.schools(id) on delete cascade,
  class_id       uuid not null references public.classes(id) on delete cascade,
  period         text not null,
  academic_year  text,
  status         text not null default 'open'
                   check (status in ('open', 'validated', 'locked')),
  validated_by   uuid references public.users(id) on delete set null,
  validated_at   timestamptz,
  locked_by      uuid references public.users(id) on delete set null,
  locked_at      timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (class_id, period)
);

create index if not exists idx_grade_periods_class
  on public.grade_periods (class_id, period);

comment on table public.grade_periods is
  'L''etat d''une periode de notes (classe x trimestre) : open | validated |
   locked. C''est ce qui gele les notes et scelle le bulletin. Cf. 20260746.';

-- ── 2. L'etat courant d'une periode (open si aucune ligne) ──────────────────
create or replace function public.grade_period_status(p_class uuid, p_period text)
returns text
language sql stable security definer
set search_path = public
as $fn$
  select coalesce(
    (select status from public.grade_periods
      where class_id = p_class and period = p_period),
    'open');
$fn$;

-- ── 3. Le garde-fou : aucune ecriture sur une note gelee ou scellee ─────────
--  Une policy RLS ne suffit pas : elle ne voit qu'une ligne, et surtout on veut
--  la MEME regle a l'INSERT, a l'UPDATE et au DELETE, en lisant l'etat d'une
--  AUTRE table. C'est le role d'un trigger.
create or replace function public.guard_grade_period()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
declare
  v_class  uuid;
  v_period text;
  v_status text;
begin
  -- La ligne concernee (NEW a l'ecriture, OLD au delete).
  if tg_op = 'DELETE' then
    v_class := old.class_id;  v_period := old.period;
  else
    v_class := new.class_id;  v_period := new.period;
  end if;

  v_status := public.grade_period_status(v_class, v_period);

  -- Ouverte : rien de plus a verifier ici. Les policies existantes de `grades`
  -- (le prof, sa classe, has_permission notes.saisir) font deja le tri.
  if v_status = 'open' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  -- Scellee : personne. Il faut deverrouiller la periode d'abord.
  if v_status = 'locked' then
    raise exception
      'Periode verrouillee : cette note ne peut plus etre modifiee. Deverrouillez la periode d''abord.'
      using errcode = '42501';
  end if;

  -- Validee : seule une correction habilitee passe. Le motif obligatoire et la
  -- trace arrivent a l'etape 2 (audit).
  if not public.has_permission(auth.uid(), 'notes', 'corriger') then
    raise exception
      'Periode validee : la correction d''une note demande le droit « Corriger une note verrouillee ».'
      using errcode = '42501';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

drop trigger if exists trg_guard_grade_period on public.grades;
create trigger trg_guard_grade_period
  before insert or update or delete on public.grades
  for each row execute function public.guard_grade_period();

-- ── 4. RLS sur grade_periods ────────────────────────────────────────────────
--  Tout le monde LIT l'etat (un prof doit savoir que sa periode est fermee).
--  L'ECRITURE passe par les fonctions de transition (etape 3), donc on
--  restreint deja l'ecriture directe aux droits idoines.
alter table public.grade_periods enable row level security;

drop policy if exists grade_periods_read on public.grade_periods;
create policy grade_periods_read on public.grade_periods
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists grade_periods_write on public.grade_periods;
create policy grade_periods_write on public.grade_periods
  for all to authenticated
  using (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'notes', 'valider')
      or public.has_permission(auth.uid(), 'notes', 'verrouiller')
    )
  )
  with check (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'notes', 'valider')
      or public.has_permission(auth.uid(), 'notes', 'verrouiller')
    )
  );

-- ── 5. Les deux nouveaux droits ─────────────────────────────────────────────
--  `notes.publier` gouvernait la publication aux familles — qui n'existe plus.
--  On ne le supprime pas brutalement (des roles s'y referent), on le rend
--  muet et on introduit les droits qui ont un sens desormais.
insert into public.sub_permission_catalog (permission_key, key, label, order_num)
values
  ('notes', 'valider',     'Valider une période (geler les notes)', 8),
  ('notes', 'verrouiller', 'Verrouiller / déverrouiller une période', 9)
on conflict (permission_key, key) do update
  set label = excluded.label, order_num = excluded.order_num;

--  Modeles : Chef d'etablissement et Adjoint valident ; seul le Chef verrouille.
insert into public.role_template_permissions
  (role_template_id, permission_key, sub_permission_key)
values
  ('11111111-0000-4000-8000-000000000001', 'notes', 'valider'),
  ('11111111-0000-4000-8000-000000000001', 'notes', 'verrouiller'),
  ('11111111-0000-4000-8000-000000000002', 'notes', 'valider')
on conflict do nothing;

--  Propager aux roles DEJA crees : ceux qui geraient la publication (publier)
--  heritent de « valider » ; ceux qui peuvent gerer la structure ET publier
--  (profil direction, pas l'enseignant) heritent de « verrouiller ».
insert into public.staff_role_permissions (staff_role_id, permission_key, sub_permission_key)
select distinct sp.staff_role_id, 'notes', 'valider'
  from public.staff_role_permissions sp
 where sp.permission_key = 'notes' and sp.sub_permission_key = 'publier'
on conflict do nothing;

insert into public.staff_role_permissions (staff_role_id, permission_key, sub_permission_key)
select distinct sp.staff_role_id, 'notes', 'verrouiller'
  from public.staff_role_permissions sp
 where sp.permission_key = 'notes' and sp.sub_permission_key = 'publier'
   and exists (
     select 1 from public.staff_role_permissions x
      where x.staff_role_id = sp.staff_role_id
        and x.permission_key = 'classes' and x.sub_permission_key = 'modifier'
   )
on conflict do nothing;

-- ============================================================================
--  VERIFICATION :
--
--    -- Tout est ouvert (aucune periode figee) ?
--    select count(*) from public.grade_periods;   -- 0 attendu
--
--    -- Le garde-fou est en place ?
--    select tgname from pg_trigger where tgname = 'trg_guard_grade_period';
--
--    -- Qui peut valider / verrouiller ?
--    select sr.name, p.sub_permission_key
--      from public.staff_role_permissions p
--      join public.staff_roles sr on sr.id = p.staff_role_id
--     where p.permission_key = 'notes'
--       and p.sub_permission_key in ('valider','verrouiller')
--     order by sr.name;
-- ============================================================================
