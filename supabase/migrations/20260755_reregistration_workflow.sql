-- ============================================================================
--  20260755_reregistration_workflow.sql — La décision de fin d'année PROPOSE,
--  la ré-inscription CONFIRME
--
--  ── Le problème ─────────────────────────────────────────────────────────────
--  `student_progressions` (20260754_student_lifecycle.sql) était pensée comme
--  un simple journal : la décision de fin d'année appliquait directement le
--  changement de classe. Mais une école a besoin d'un vrai palier entre les
--  deux : un élève ne se réinscrit pas tout seul parce que l'admin a coché
--  « passe en 5e » — il doit revenir confirmer (et souvent payer) avant que ce
--  soit effectif. Sans ce palier, on fait « passer » des élèves qui ne
--  reviendront peut-être pas l'année suivante.
--
--  ── Ce que ça change ─────────────────────────────────────────────────────────
--    • `student_progressions.status` : 'proposed' (décision prise par l'admin,
--      RIEN n'est encore appliqué sur `student_profiles`) → 'confirmed'
--      (ré-inscription traitée : la classe/le statut de l'élève bascule à CE
--      moment-là, pas avant) ou 'cancelled' (décision annulée, rien n'a bougé).
--    • Une fois confirmée ou annulée, la ligne redevient immuable (la policy
--      d'update n'autorise la transition que depuis 'proposed').
-- ============================================================================

alter table public.student_progressions
  add column if not exists status text not null default 'proposed';

alter table public.student_progressions
  drop constraint if exists student_progressions_status_check;
alter table public.student_progressions
  add constraint student_progressions_status_check
  check (status in ('proposed', 'confirmed', 'cancelled'));

comment on column public.student_progressions.status is
  'proposed = décidé par l''admin, PAS encore appliqué (l''élève reste dans sa
   classe actuelle). confirmed = ré-inscription traitée, le changement de
   classe/statut a été appliqué à cet instant. cancelled = décision annulée,
   rien n''a été appliqué. Transition uniquement proposed → confirmed/cancelled,
   jamais l''inverse (cf. policy update ci-dessous).';

create index if not exists idx_student_progressions_status
  on public.student_progressions (school_id, status, to_academic_year);

-- ── La transition proposed → confirmed/cancelled ────────────────────────────
--  Jusqu'ici aucune policy update/delete (le journal était censé être figé dès
--  l'écriture). On autorise maintenant UNE transition, et seulement depuis
--  'proposed' : une ligne déjà confirmée ou annulée redevient immuable.
drop policy if exists student_progressions_update on public.student_progressions;
create policy student_progressions_update on public.student_progressions
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'utilisateurs', 'modifier')
    and status = 'proposed'
  )
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'utilisateurs', 'modifier')
  );

-- ============================================================================
--  VERIFICATION :
--    select status, count(*) from public.student_progressions group by 1;
--    -- une ligne confirmée ne doit plus pouvoir être modifiée :
--    update student_progressions set reason = 'x' where status = 'confirmed';
--    -- 0 ligne affectée attendu
-- ============================================================================
