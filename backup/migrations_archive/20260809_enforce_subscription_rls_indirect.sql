-- 20260809_enforce_subscription_rls_indirect.sql
--
-- Complète 20260809_enforce_subscription_rls.sql (qui ne couvrait que les
-- tables avec une colonne `school_id` DIRECTE) pour les tables qui rattachent
-- l'école soit par une clé étrangère à une jointure, soit par une colonne au
-- nom différent. Découvert en cartographiant les 49 tables restantes :
--
--   - payments               → invoice_id  → invoices.school_id
--   - liaison_acks           → entry_id    → liaison_entries.school_id
--   - staff_role_permissions → staff_role_id → staff_roles.school_id
--   - library_favorites      → user_id     → users.school_id
--   - reading_progress       → user_id     → users.school_id
--   - bibliotheque / course_materials / exam_subjects → submitted_by_school_id (direct, nom différent)
--   - schools elle-même      → id (c'est l'école, pas une colonne school_id)
--
-- Volontairement EXCLUS (catalogues globaux plateforme, aucune école
-- propriétaire, écrits par l'admin plateforme pas par une école) :
-- plans, plan_prices, class_levels, subject_catalog, permission_catalog,
-- sub_permission_catalog, role_templates, role_template_permissions.

-- ── Jointure à un niveau (fk_col sur cette table → id sur ref_table, qui a school_id) ──
create or replace function public.enforce_subscription_active_via_fk()
returns trigger
language plpgsql
security definer
as $$
declare
  v_fk_col    text := TG_ARGV[0];
  v_ref_table text := TG_ARGV[1];
  v_fk_value  uuid;
  v_school_id uuid;
begin
  if public.is_platform_admin(auth.uid()) then
    return coalesce(new, old);
  end if;

  execute format('select ($1).%I', v_fk_col) using coalesce(new, old) into v_fk_value;
  if v_fk_value is null then
    return coalesce(new, old);
  end if;

  execute format('select school_id from public.%I where id = $1', v_ref_table)
    using v_fk_value into v_school_id;

  if v_school_id is not null and not public.subscription_is_active(v_school_id) then
    raise exception 'Abonnement en lecture seule — vos données restent visibles, mais choisissez une offre pour pouvoir enregistrer.'
      using errcode = '42501';
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_enforce_subscription_active on public.payments;
create trigger trg_enforce_subscription_active
  before insert or update on public.payments
  for each row execute function public.enforce_subscription_active_via_fk('invoice_id', 'invoices');

drop trigger if exists trg_enforce_subscription_active on public.liaison_acks;
create trigger trg_enforce_subscription_active
  before insert or update on public.liaison_acks
  for each row execute function public.enforce_subscription_active_via_fk('entry_id', 'liaison_entries');

drop trigger if exists trg_enforce_subscription_active on public.staff_role_permissions;
create trigger trg_enforce_subscription_active
  before insert or update on public.staff_role_permissions
  for each row execute function public.enforce_subscription_active_via_fk('staff_role_id', 'staff_roles');

drop trigger if exists trg_enforce_subscription_active on public.library_favorites;
create trigger trg_enforce_subscription_active
  before insert or update on public.library_favorites
  for each row execute function public.enforce_subscription_active_via_fk('user_id', 'users');

drop trigger if exists trg_enforce_subscription_active on public.reading_progress;
create trigger trg_enforce_subscription_active
  before insert or update on public.reading_progress
  for each row execute function public.enforce_subscription_active_via_fk('user_id', 'users');

-- ── Colonne school_id existe mais sous un autre nom (submitted_by_school_id) ──
create or replace function public.enforce_subscription_active_submitted()
returns trigger
language plpgsql
security definer
as $$
begin
  if public.is_platform_admin(auth.uid()) then
    return coalesce(new, old);
  end if;

  if new.submitted_by_school_id is not null
     and not public.subscription_is_active(new.submitted_by_school_id) then
    raise exception 'Abonnement en lecture seule — vos données restent visibles, mais choisissez une offre pour pouvoir enregistrer.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['bibliotheque', 'course_materials', 'exam_subjects']
  loop
    execute format('drop trigger if exists trg_enforce_subscription_active on public.%I;', t);
    execute format(
      'create trigger trg_enforce_subscription_active
         before insert or update on public.%I
         for each row execute function public.enforce_subscription_active_submitted();', t);
  end loop;
end $$;

-- ── La table schools elle-même : id EST l'école (pas de colonne school_id) ──
-- Seulement en UPDATE (pas INSERT — à la création, aucun abonnement n'existe
-- encore de toute façon, et subscription_is_active() est déjà fail-open dans
-- ce cas ; on évite juste la requête inutile à l'inscription).
create or replace function public.enforce_subscription_active_self()
returns trigger
language plpgsql
security definer
as $$
begin
  if public.is_platform_admin(auth.uid()) then
    return new;
  end if;

  if not public.subscription_is_active(old.id) then
    raise exception 'Abonnement en lecture seule — vos données restent visibles, mais choisissez une offre pour pouvoir enregistrer.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_subscription_active_self on public.schools;
create trigger trg_enforce_subscription_active_self
  before update on public.schools
  for each row execute function public.enforce_subscription_active_self();
