-- ============================================================================
--  20260749_delete_user_with_reason.sql — corrige la suppression d'un compte
--  élève/famille bloquée par le garde-fou de période validée.
--
--  ── Le bug ──────────────────────────────────────────────────────────────────
--  `deleteUser` faisait un simple `delete from users where id = ...`. Supprimer
--  un élève cascade sur ses `grades` (FK on delete cascade). Si une seule de
--  ces notes appartient à une période VALIDÉE, `guard_grade_period` (cf.
--  20260747) exige un motif transporté par `app.change_reason` — motif que
--  `deleteUser` ne posait jamais. Résultat : suppression impossible, avec le
--  message "Periode validee : indiquez un motif...", qui ne veut rien dire
--  pour quelqu'un qui essaie de supprimer un COMPTE, pas une note.
--
--  ── Le correctif ────────────────────────────────────────────────────────────
--  Même recette que `save_grade` (20260748) : poser `app.change_reason` et
--  faire la suppression dans la MÊME transaction, via une fonction SQL.
--  `security invoker` (défaut) : la policy `users_delete` (droit
--  `utilisateurs.supprimer` ou `eleves.supprimer`) s'applique normalement, on
--  ne contourne rien — on transporte juste le motif jusqu'au trigger d'audit.
-- ============================================================================

create or replace function public.delete_user_account(p_id uuid, p_reason text default null)
returns void
language plpgsql
set search_path = public
as $fn$
begin
  perform set_config('app.change_reason',
    coalesce(nullif(trim(coalesce(p_reason,'')), ''), ''), true);

  delete from public.users where id = p_id;
end;
$fn$;

grant execute on function public.delete_user_account(uuid, text) to authenticated;

-- ============================================================================
--  VERIFICATION :
--    select public.delete_user_account('<user_uuid>', 'Doublon créé par erreur');
--    -- si l'élève a des notes sur une période validée et que l'appelant a le
--    -- droit notes.corriger : suppression OK, tracée dans notes_audit
--    -- (change_type = 'suppression', reason = motif fourni).
--    -- sans ce droit : refus normal (garde-fou intact).
-- ============================================================================
