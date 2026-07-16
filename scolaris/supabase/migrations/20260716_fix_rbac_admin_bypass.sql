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
--  Verifie en base le 13/07/2026 : TOUS les comptes ont permissions = '[]' et
--  staff_role_id = NULL — y compris les 5 comptes role='admin' (fondateurs des
--  ecoles de demo). L'app accorde l'acces total sur la foi de users.role =
--  'admin' (cf. supabase_auth_source), mais la base n'en savait rien : cote SQL
--  ces comptes n'avaient AUCUN droit. Les deux ne racontaient pas la meme
--  histoire, et c'est cet ecart qui bloquait tout.
--
--  Correctif : has_permission() reconnait le fondateur — soit par users.role =
--  'admin' (le cas reel), soit par users.permissions contenant "*" (le cas
--  suppose, conserve par prudence). Le fix est dans la fonction plutot que dans
--  les policies : toutes les policies a venir en beneficient sans y penser.
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
        -- Fondateur / chef d'etablissement : c'est ainsi qu'il est reellement
        -- marque en base (users.role = 'admin', permissions restee vide).
        -- Meme liste que supabase_auth_source, qui accorde {'*'} a ces roles :
        -- la base et l'app doivent dire la meme chose, sinon on recree l'ecart
        -- qui est precisement la cause de ce bug.
        u.role::text in ('admin', 'direction', 'directeur', 'dg')

        -- Acces total via la liste plate, si un jour elle est renseignee.
        or u.permissions @> '["*"]'::jsonb

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
