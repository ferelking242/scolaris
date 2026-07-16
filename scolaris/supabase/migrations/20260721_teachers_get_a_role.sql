-- ============================================================================
--  20260721_teachers_get_a_role.sql — Les enseignants entrent dans le systeme
--
--  Jusqu'ici un prof invite recevait users.role = 'teacher' et AUCUN role du
--  personnel (staff_role_id NULL). Ses acces etaient figes dans le code Flutter.
--
--  Ca tenait tant que les permissions ne servaient a rien. Ca ne tient plus :
--  la migration suivante verrouille les notes en exigeant has_permission(...,
--  'notes', 'saisir'). Or has_permission() cherche les droits A TRAVERS le role.
--  Sans role, un prof ne pourrait plus saisir une seule note.
--
--  Il y avait donc deux facons d'etre enseignant dans le meme systeme. On en
--  garde une : le prof porte le role « Enseignant », comme le reste du personnel.
--  Le directeur peut alors decider « chez moi les profs ne modifient pas une note
--  apres publication » — et ca s'applique a tous, sans toucher au code.
--
--  users.role reste 'teacher' : c'est ce qui pilote son interface (son tableau de
--  bord, ses classes). Le ROLE dit ce qu'il a le droit de faire ; users.role dit
--  quel espace il voit. Deux questions differentes.
-- ============================================================================

-- ── 1. Chaque école a un rôle « Enseignant » ────────────────────────────────
--  Cree depuis le modele commun (20260719) pour les ecoles qui n'en ont pas.

insert into public.staff_roles
  (school_id, name, description, is_admin_role, based_on_template_id,
   level, color, icon_key)
select
  s.id,
  t.name,
  t.description,
  false,
  t.id,
  t.level,
  t.color,
  t.icon_key
from public.schools s
cross join public.role_templates t
where t.cycle = 'commun'
  and t.name  = 'Enseignant'
  and not exists (
    select 1 from public.staff_roles r
     where r.school_id = s.id
       and r.name = 'Enseignant'
  );

-- Ses permissions, reprises du modele.
insert into public.staff_role_permissions
  (staff_role_id, permission_key, sub_permission_key)
select r.id, tp.permission_key, tp.sub_permission_key
from public.staff_roles r
join public.role_templates t
  on t.cycle = 'commun' and t.name = 'Enseignant'
join public.role_template_permissions tp
  on tp.role_template_id = t.id
where r.name = 'Enseignant'
on conflict do nothing;

-- ── 2. Les profs sans rôle reçoivent celui-là ───────────────────────────────
--  Le trigger de 20260717 recalcule users.permissions dans la foulee : ces
--  comptes, qui avaient permissions = '[]' (aucun acces), retrouvent enfin les
--  leurs.

update public.users u
   set staff_role_id = r.id
  from public.staff_roles r
 where u.role::text  = 'teacher'
   and u.staff_role_id is null
   and r.school_id = u.school_id
   and r.name = 'Enseignant';
