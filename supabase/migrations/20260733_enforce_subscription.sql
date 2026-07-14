-- ============================================================================
--  20260733_enforce_subscription.sql — L'OFFRE devient une regle, pas un affichage
--
--  ── Le probleme ─────────────────────────────────────────────────────────────
--  Les offres sont definies en base (`plans.features`), mais UNE SEULE chose y
--  etait reellement tenue : le plafond d'eleves (20260618).
--
--  Tout le reste n'etait qu'un AFFICHAGE. `PlanGate` est un widget : il CACHE un
--  ecran quand l'offre ne suffit pas. Une ecole Simple ne voit pas le bouton
--  « Facturation ». Mais un appel direct a l'API creait la facture sans broncher.
--  Elle payait 14 900 F et utilisait les fonctions a 29 900 F.
--
--  ── Deux regles, decidees avec l'editeur ────────────────────────────────────
--
--  1. IMPAYE → LECTURE SEULE. Une ecole dont l'abonnement a expire consulte tout
--     (notes, bulletins, factures) mais ne cree ni ne modifie plus rien. Ses
--     donnees restent intactes et visibles : elle voit ce qu'elle perd, et on ne
--     detruit rien. Couper l'acces aux notes en plein trimestre serait brutal, et
--     mauvais commercialement.
--
--  2. En offre SIMPLE, les eleves et les parents N'ONT PAS DE COMPTE. Simple est
--     un outil INTERNE : personnel et enseignants. Le portail des familles est
--     une fonctionnalite Pro. C'est cela qu'il faut tenir en base — pas seulement
--     la facturation.
--
--  Rien n'est detruit lors d'une retrogradation : on ne desactive JAMAIS un eleve
--  deja inscrit (ce serait perdre son dossier en cours d'annee). On bloque
--  seulement les nouveaux au-dela du plafond — ce que le declencheur fait deja.
--
--  ── Comment, sans reecrire les 40 policies deja posees ──────────────────────
--  PostgreSQL connait les policies RESTRICTIVES : elles se combinent en ET avec
--  toutes les autres, au lieu du OU habituel. Une seule suffit donc par table et
--  par operation, sans toucher a ce qui existe.
-- ============================================================================

-- ── 1. L'abonnement est-il en regle ? ───────────────────────────────────────
create or replace function public.subscription_is_active(p_school uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.subscriptions s
     where s.school_id = p_school
       and s.status in ('trial', 'active')
       -- Une periode terminee ne vaut plus rien, meme si le statut n'a pas
       -- encore ete bascule par le job de facturation.
       and (s.current_period_end is null or s.current_period_end > now())
       and (s.status <> 'trial' or s.trial_end is null or s.trial_end > now())
  );
$fn$;

-- ── 2. L'offre couvre-t-elle cette fonctionnalite ? ─────────────────────────
--  Les offres s'emboitent : Pro contient la cle "simple", Max contient "pro".
--  On resout donc l'heritage, sinon une ecole Max n'aurait pas droit a la
--  finance (qui n'est listee que dans Pro).
create or replace function public.school_has_feature(p_school uuid, p_feature text)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  with recursive plan_chain(code) as (
    -- L'offre de l'ecole...
    select s.plan_code
      from public.subscriptions s
     where s.school_id = p_school
    union
    -- ... et toutes celles qu'elle englobe : Pro contient la cle "simple",
    -- Max contient "pro". Sans cela, une ecole Max n'aurait pas droit a la
    -- finance, qui n'est listee que dans Pro.
    select p2.code
      from plan_chain c
      join public.plans p            on p.code = c.code
      cross join lateral jsonb_array_elements_text(p.features) as f(feature)
      join public.plans p2           on p2.code = f.feature
  )
  select exists (
    select 1
      from plan_chain c
      join public.plans p on p.code = c.code
      cross join lateral jsonb_array_elements_text(p.features) as f(feature)
     where f.feature = p_feature
  );
$fn$;

-- ── 3. Le verdict : cette ecole peut-elle ECRIRE, ici et maintenant ? ───────
create or replace function public.school_can_write(p_school uuid)
returns boolean
language sql stable security definer
set search_path = public
as $fn$
  select public.subscription_is_active(p_school);
$fn$;

grant execute on function public.subscription_is_active(uuid) to authenticated;
grant execute on function public.school_has_feature(uuid, text) to authenticated;
grant execute on function public.school_can_write(uuid)         to authenticated;

-- ── 4. IMPAYE = LECTURE SEULE, sur toutes les tables de l'ecole ─────────────
--  Une policy RESTRICTIVE par operation d'ecriture. La lecture n'est jamais
--  touchee : c'est tout l'interet de la decision.
do $$
declare
  t text;
  tables text[] := array[
    'grades', 'absences', 'report_cards',
    'invoices', 'fee_structures',
    'classes', 'subjects', 'courses', 'schedules', 'assignments', 'submissions',
    'users', 'student_profiles', 'parent_student',
    'liaison_entries', 'merit_points', 'student_badges'
  ];
begin
  foreach t in array tables loop
    -- La table peut ne pas exister (cantine supprimee, etc.) : on ne casse pas.
    if to_regclass('public.' || t) is null then
      continue;
    end if;

    execute format('drop policy if exists %I on public.%I',
                   t || '_sub_write', t);
    execute format(
      'create policy %I on public.%I as restrictive '
      'for insert to authenticated '
      'with check (public.school_can_write(school_id))',
      t || '_sub_write', t);

    execute format('drop policy if exists %I on public.%I',
                   t || '_sub_update', t);
    execute format(
      'create policy %I on public.%I as restrictive '
      'for update to authenticated '
      'using (public.school_can_write(school_id))',
      t || '_sub_update', t);

    execute format('drop policy if exists %I on public.%I',
                   t || '_sub_delete', t);
    execute format(
      'create policy %I on public.%I as restrictive '
      'for delete to authenticated '
      'using (public.school_can_write(school_id))',
      t || '_sub_delete', t);
  end loop;
end $$;

--  `payments` n'a pas de school_id : elle se rattache a l'eleve (cf. 20260728).
drop policy if exists payments_sub_write on public.payments;
create policy payments_sub_write on public.payments
  as restrictive for insert to authenticated
  with check (public.school_can_write(public.school_of_student(student_id)));

drop policy if exists payments_sub_update on public.payments;
create policy payments_sub_update on public.payments
  as restrictive for update to authenticated
  using (public.school_can_write(public.school_of_student(student_id)));

drop policy if exists payments_sub_delete on public.payments;
create policy payments_sub_delete on public.payments
  as restrictive for delete to authenticated
  using (public.school_can_write(public.school_of_student(student_id)));

-- ── 5. LA FINANCE est une fonctionnalite PRO ────────────────────────────────
--  Une ecole Simple ne facture pas. Elle ne voyait deja pas le bouton ; la base
--  refuse desormais l'ecriture, quel que soit le chemin emprunte.
--  RESTRICTIVE sur TOUTES les operations, lecture comprise : sans l'offre, il n'y
--  a rien a lire — ces tables sont vides pour elle.
do $$
declare t text;
begin
  foreach t in array array['invoices', 'fee_structures'] loop
    execute format('drop policy if exists %I on public.%I', t || '_needs_pro', t);
    execute format(
      'create policy %I on public.%I as restrictive '
      'for all to authenticated '
      'using (public.school_has_feature(school_id, ''finance'')) '
      'with check (public.school_has_feature(school_id, ''finance''))',
      t || '_needs_pro', t);
  end loop;
end $$;

drop policy if exists payments_needs_pro on public.payments;
create policy payments_needs_pro on public.payments
  as restrictive for all to authenticated
  using      (public.school_has_feature(public.school_of_student(student_id), 'finance'))
  with check (public.school_has_feature(public.school_of_student(student_id), 'finance'));

-- ── 6. LE PORTAIL DES FAMILLES est une fonctionnalite PRO ───────────────────
--  En offre Simple, un eleve ou un parent n'a PAS de compte. Sa fiche existe
--  (l'ecole la gere en interne), mais elle ne se connecte pas.
--
--  On ne peut pas l'exprimer en policy : la connexion ne passe pas par une
--  ecriture RLS. C'est un declencheur sur `users` qui refuse de RATTACHER un
--  compte d'authentification (`auth_uid`) a un eleve ou un parent quand l'offre
--  ne comporte pas le portail.
create or replace function public.guard_family_portal()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
begin
  -- Seul le RATTACHEMENT d'un login nous interesse : la fiche, elle, est
  -- toujours autorisee (une ecole Simple gere bien ses eleves).
  if new.auth_uid is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.auth_uid is not distinct from new.auth_uid then
    return new;
  end if;

  if new.role::text in ('student', 'parent')
     and new.school_id is not null
     and not public.school_has_feature(new.school_id, 'portail_parents') then
    raise exception
      'Le portail des familles n''est pas inclus dans l''offre de cette école. '
      'Les élèves et les parents n''ont pas de compte en offre Simple.'
      using errcode = '42501';
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_guard_family_portal on public.users;
create trigger trg_guard_family_portal
  before insert or update on public.users
  for each row execute function public.guard_family_portal();

-- ============================================================================
--  VERIFICATION :
--
--    -- Ce a quoi chaque ecole a droit :
--    select s.name,
--           sub.plan_code,
--           public.subscription_is_active(s.id)                  as en_regle,
--           public.school_has_feature(s.id, 'finance')           as facture,
--           public.school_has_feature(s.id, 'portail_parents')   as portail_familles,
--           public.school_has_feature(s.id, 'notes')             as notes
--      from public.schools s
--      left join public.subscriptions sub on sub.school_id = s.id;
--
--    -- L'heritage fonctionne : une ecole MAX doit avoir `facture` = true,
--    -- alors que « finance » n'est listee que dans l'offre PRO.
--
--    -- Une ecole SIMPLE doit avoir facture = false et portail_familles = false.
-- ============================================================================

-- ============================================================================
--  ROLLBACK
--
--    drop trigger if exists trg_guard_family_portal on public.users;
--    drop function if exists public.guard_family_portal();
--    -- puis supprimer les policies *_sub_write / *_sub_update / *_sub_delete
--    -- et *_needs_pro (elles sont RESTRICTIVES : leur suppression rouvre tout).
-- ============================================================================
