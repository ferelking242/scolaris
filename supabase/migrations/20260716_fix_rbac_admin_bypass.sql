-- ============================================================================
--  20260716_fix_rbac_admin_bypass.sql
--
--  BUG : la page « Roles & permissions » ne sauvegardait rien.
--
--  Les policies d'ecriture de staff_roles / staff_role_permissions exigent
--  has_permission(auth.uid(), 'utilisateurs', 'gerer_roles'). Or cette fonction
--  cherche les droits A TRAVERS le role de l'utilisateur :
--      users.staff_role_id -> staff_roles -> staff_role_permissions
--
--  Le fondateur d'une ecole neuve n'a PAS de role (staff_role_id IS NULL) : son
--  acces total vient de users.permissions = ["*"]. La jointure ne renvoie donc
--  rien, has_permission() repond false, et la base refuse toute ecriture.
--
--  Serpent qui se mord la queue : pour creer le premier role, il fallait deja
--  en avoir un. Aucun role n'etait creable, par personne.
--
--  Correctif : has_permission() reconnait le detenteur de "*" (fondateur /
--  Direction). Le fix est dans la fonction plutot que dans les policies : toutes
--  les policies a venir en beneficient sans avoir a y penser.
-- ============================================================================

create or replace function public.has_permission(uid uuid, p_key text, p_sub text)
returns boolean
language sql
stable
security definer
as $fn$
  select exists (
    select 1
    from public.users u
    where u.auth_uid = uid
      and (
        -- Acces total historique (fondateur) : users.permissions contient "*".
        u.permissions @> '["*"]'::jsonb

        -- Sinon, le droit passe par le role du personnel.
        or exists (
          select 1
          from public.staff_roles r
          where r.id = u.staff_role_id
            and (
              r.is_admin_role
              or exists (
                select 1 from public.staff_role_permissions srp
                where srp.staff_role_id      = r.id
                  and srp.permission_key     = p_key
                  and srp.sub_permission_key = p_sub
              )
            )
        )
      )
  );
$fn$;

-- ── Garde-fou « dernier administrateur » ────────────────────────────────────
--
--  La base portait deja trg_prevent_admin_role_delete, qui refuse de supprimer
--  TOUT role admin — meme quand l'ecole en compte plusieurs, et sans rien dire
--  du cas ou on retire simplement le drapeau admin (meme resultat : plus
--  personne aux commandes).
--
--  On le remplace par guard_last_admin_role (20260715), qui protege ce qui
--  compte vraiment : qu'il reste AU MOINS UN administrateur, et qui couvre la
--  retrogradation autant que la suppression.

drop trigger if exists trg_prevent_admin_role_delete on public.staff_roles;
drop function if exists public.prevent_admin_role_delete();
