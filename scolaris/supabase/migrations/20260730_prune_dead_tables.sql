-- ============================================================================
--  20260730_prune_dead_tables.sql — Fermer les portes que plus personne ne
--  regarde, sans jeter de donnees
--
--  Constat : la base compte des tables que le code n'interroge JAMAIS. Certaines
--  sont des doublons oublies, une autre est un piege.
--
--  ── Le piege : teacher_classes ──────────────────────────────────────────────
--
--  L'application ne lit ni n'ecrit cette table. Elle deduit les classes d'un
--  prof de DEUX sources : l'emploi du temps (`schedules.teacher_id`) et le
--  statut de titulaire (`classes.main_teacher_id`).
--
--  Mais `teaches_class()` (20260722), elle, la consultait — et c'est cette
--  fonction qui decide si un prof a le droit de noter une classe. Or
--  `teacher_classes` etait ouverte en ecriture a tout membre de l'ecole
--  (tenant_isolation ALL).
--
--  Un prof s'y ajoutait la classe du voisin, et le verrou sur les notes le
--  croyait. On avait verrouille la porte en laissant le trousseau sur la table
--  — dans une piece ou personne ne va jamais.
--
--  Elle est VIDE (0 ligne, verifie en base). On la supprime, et on la retire de
--  la fonction.
-- ============================================================================

-- ── 1. Les informations des profs ne sont pas perdues ───────────────────────
--  `teacher_profiles` (4 lignes reelles) fait doublon avec `staff_profiles`
--  (20260718). Mais elle porte DEUX champs que staff_profiles n'avait pas, et
--  qui n'ont de sens que pour un enseignant : sa specialite et son diplome.
--  On les recupere avant de supprimer la table.

alter table public.staff_profiles add column if not exists specialization text;
alter table public.staff_profiles add column if not exists qualification  text;

comment on column public.staff_profiles.specialization is
  'Matiere / domaine enseigne. Vient de l''ancienne table teacher_profiles.';
comment on column public.staff_profiles.qualification is
  'Diplome. Vient de l''ancienne table teacher_profiles.';

insert into public.staff_profiles
  (user_id, school_id, employee_id, join_date, specialization, qualification)
select tp.user_id, tp.school_id, tp.employee_id, tp.join_date,
       tp.specialization, tp.qualification
from public.teacher_profiles tp
on conflict (user_id) do update set
  employee_id    = coalesce(public.staff_profiles.employee_id,    excluded.employee_id),
  join_date      = coalesce(public.staff_profiles.join_date,      excluded.join_date),
  specialization = coalesce(excluded.specialization, public.staff_profiles.specialization),
  qualification  = coalesce(excluded.qualification,  public.staff_profiles.qualification);

-- ── 2. `teaches_class()` ne fait plus confiance a une table fantome ─────────
--  Deux sources, les memes que l'application. Ni plus, ni moins : une fonction
--  de securite ne doit pas etre plus permissive que ce que l'app sait produire.
create or replace function public.teaches_class(uid uuid, p_class_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  -- 1. Le titulaire (l'instituteur du primaire, souvent sans matiere attitree).
  select exists (
    select 1 from public.classes c
     join public.users u on u.id = c.main_teacher_id
    where u.auth_uid = uid and c.id = p_class_id
  )
  -- 2. L'emploi du temps (le specialiste du college / lycee).
  or exists (
    select 1 from public.schedules s
     join public.users u on u.id = s.teacher_id
    where u.auth_uid = uid and s.class_id = p_class_id
  );
$fn$;

-- ── 3. Les tables mortes ────────────────────────────────────────────────────
--  Toutes VIDES (verifie en base) et jamais interrogees par le code.
--  Une table morte n'est pas neutre : c'est une surface ouverte que plus
--  personne ne surveille, et que quelqu'un rebranchera un jour par erreur.

drop table if exists public.teacher_classes  cascade;  -- 0 ligne — LE piege
drop table if exists public.teacher_profiles cascade;  -- 4 lignes, rapatriees ci-dessus
drop table if exists public.filieres         cascade;  -- 0 ligne — doublon de school_series
drop table if exists public.resources        cascade;  -- 0 ligne — doublon de bibliotheque
drop table if exists public.exams            cascade;  -- 0 ligne — le code passe par assignments

-- ── 4. Ce qu'on GARDE, et pourquoi ─────────────────────────────────────────
--
--  • user_settings (18 lignes) — preferences reelles (theme, langue,
--    notifications). L'app ne les lit pas ENCORE. On ne jette pas des donnees
--    parce qu'un ecran n'est pas fini. On la verrouille (voir ci-dessous).
--
--  • subscription_payments (0 ligne) — fait partie du modele des abonnements,
--    le prochain chantier. La supprimer pour la recreer dans une semaine n'a
--    aucun sens.
--
--  • enrollment_requests (0 ligne) — la pre-inscription est une maquette, mais
--    c'est une fonctionnalite PREVUE, pas un oubli.
--
--  • announcement_comments / announcement_likes (0 ligne) — meme raison :
--    `announcements` vit, ses commentaires ne sont pas encore branches.

-- ── 5. user_settings : chacun ses reglages ─────────────────────────────────
--  Elle etait en tenant_isolation ALL : n'importe quel membre de l'ecole
--  pouvait changer le theme, la langue et les notifications de n'importe qui.
--  Sans gravite, mais sans raison non plus.
drop policy if exists tenant_isolation on public.user_settings;

drop policy if exists user_settings_own on public.user_settings;
create policy user_settings_own on public.user_settings
  for all to authenticated
  using      (user_id = public.my_user_id())
  with check (user_id = public.my_user_id());

-- ============================================================================
--  VERIFICATION :
--
--    -- les 5 tables ont disparu :
--    select table_name from information_schema.tables
--     where table_schema = 'public'
--       and table_name in ('teacher_classes','teacher_profiles','filieres',
--                          'resources','exams');
--    -- attendu : 0 ligne
--
--    -- les infos des 4 profs sont bien arrivees :
--    select u.full_name, sp.employee_id, sp.specialization, sp.qualification
--      from public.staff_profiles sp
--      join public.users u on u.id = sp.user_id
--     where sp.specialization is not null or sp.qualification is not null;
--    -- attendu : les 4 enseignants, avec leur specialite / diplome.
--
--    -- le prof enseigne toujours dans ses classes (sans teacher_classes) :
--    select u.full_name, public.teaches_class(u.auth_uid, c.id)
--      from public.users u, public.classes c
--     where u.role::text = 'teacher' and c.main_teacher_id = u.id;
--    -- attendu : true
-- ============================================================================
