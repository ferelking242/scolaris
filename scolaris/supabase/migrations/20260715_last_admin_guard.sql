-- ============================================================================
--  20260715_last_admin_guard.sql — Une ecole garde toujours un administrateur
--
--  Les roles de Direction (Proviseur, Principal, Recteur, Directeur) portent
--  l'acces total via staff_roles.is_admin_role, et non via des grants enumeres
--  (cf. 20260713_staff_rbac.sql : leurs role_template_permissions sont vides).
--
--  Consequence : supprimer ce role, ou lui retirer son drapeau admin, enferme
--  le directeur DEHORS de sa propre ecole — et il n'y a personne au-dessus de
--  lui pour rouvrir la porte. Le support devient le seul recours.
--
--  Ce garde-fou vit en base, pas dans l'app : une protection que le client peut
--  contourner n'en est pas une.
-- ============================================================================

create or replace function public.guard_last_admin_role()
returns trigger
language plpgsql
security definer
as $fn$
declare
  v_school uuid;
  v_remaining integer;
begin
  -- Quel role disparait du pool d'admins ?
  if tg_op = 'DELETE' then
    if not old.is_admin_role then
      return old;                       -- role non-admin : rien a proteger
    end if;
    v_school := old.school_id;
  else -- UPDATE
    if not (old.is_admin_role and not new.is_admin_role) then
      return new;                       -- le drapeau admin n'est pas retire
    end if;
    v_school := old.school_id;
  end if;

  select count(*) into v_remaining
  from public.staff_roles
  where school_id = v_school
    and is_admin_role
    and id <> old.id;

  if v_remaining = 0 then
    raise exception
      'Cette ecole n''aurait plus aucun administrateur. Nommez d''abord un autre role administrateur.'
      using errcode = 'check_violation';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_guard_last_admin_role on public.staff_roles;
create trigger trg_guard_last_admin_role
  before delete or update of is_admin_role on public.staff_roles
  for each row
  execute function public.guard_last_admin_role();
