-- ============================================================================
--  20260774_deploy_comptabilite_rls.sql — Déployer POUR DE VRAI le modèle
--  `comptabilite.*` sur invoices / payments / fee_structures
--
--  ── Ce qu'on a découvert (audit du 27/07/2026) ──────────────────────────────
--  20260728_lock_money.sql décrivait un modèle par droits fins
--  (`comptabilite.voir_paiements/creer_facture/modifier_facture/
--  supprimer_facture/enregistrer_paiement/plans_facturation`) — mais cette
--  migration n'a JAMAIS été appliquée en production. La base live utilise
--  encore, sur ces trois tables, une policy `tenant_isolation` PERMISSIVE
--  (`is_member_of(school_id)`, ALL) qui donne à TOUT membre du personnel un
--  accès total aux factures et encaissements, quels que soient ses droits
--  fins cochés dans « Rôles & permissions ». Sur `fee_structures`, c'est pire :
--  aucune policy RESTRICTIVE ne distingue même le personnel des comptes
--  famille — n'importe quel membre de l'école peut réécrire le barème de
--  frais de scolarité.
--
--  Vérifié en direct : `select count(*) from pg_policies where qual ilike
--  '%comptabilite%' or with_check ilike '%comptabilite%'` → 0 avant cette
--  migration.
--
--  ── Ce qu'on préserve ────────────────────────────────────────────────────
--  Les policies RESTRICTIVE `family_scope` / `family_readonly_*` (invoices,
--  payments) gèrent déjà correctement l'accès FAMILLE (un parent/élève ne
--  voit que ses propres factures, ne peut jamais écrire) via `can_see_student`
--  / `is_family_account()` — elles ne sont PAS touchées. On remplace
--  uniquement le `tenant_isolation` permissif, qui gouvernait l'accès STAFF,
--  par des policies fines équivalentes à celles décrites dans 20260728.
-- ============================================================================

-- ── 1) FACTURES ──────────────────────────────────────────────────────────────
drop policy if exists tenant_isolation on public.invoices;

drop policy if exists invoices_read on public.invoices;
create policy invoices_read on public.invoices
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      (public.is_family_account() and public.can_see_student(student_id))
      or public.has_permission(auth.uid(), 'comptabilite', 'voir_paiements')
    )
  );

drop policy if exists invoices_insert on public.invoices;
create policy invoices_insert on public.invoices
  for insert to authenticated
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'comptabilite', 'creer_facture')
  );

-- Marquer une facture payée est un effet de bord de l'encaissement (cf.
-- recordPayment() côté Dart) : `enregistrer_paiement` suffit, en plus de
-- `modifier_facture` pour les vraies corrections de facture.
drop policy if exists invoices_update on public.invoices;
create policy invoices_update on public.invoices
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and (
      public.has_permission(auth.uid(), 'comptabilite', 'modifier_facture')
      or public.has_permission(auth.uid(), 'comptabilite', 'enregistrer_paiement')
    )
  )
  with check (public.is_member_of(school_id));

drop policy if exists invoices_delete on public.invoices;
create policy invoices_delete on public.invoices
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'comptabilite', 'supprimer_facture')
  );

-- ── 2) ENCAISSEMENTS ─────────────────────────────────────────────────────────
--  `payments` n'a pas de `school_id` propre : son école se déduit de l'élève.
--  Ce helper était prévu par 20260728 mais n'existait pas encore en live (la
--  policy `tenant_isolation` de `payments` répétait l'EXISTS en dur).
create or replace function public.school_of_student(p_student_id uuid)
returns uuid
language sql stable security definer
set search_path = public
as $fn$
  select school_id from public.users where id = p_student_id;
$fn$;

grant execute on function public.school_of_student(uuid) to authenticated;

drop policy if exists tenant_isolation on public.payments;

drop policy if exists payments_read on public.payments;
create policy payments_read on public.payments
  for select to authenticated
  using (
    public.is_member_of(public.school_of_student(student_id))
    and (
      (public.is_family_account() and public.can_see_student(student_id))
      or public.has_permission(auth.uid(), 'comptabilite', 'voir_paiements')
    )
  );

drop policy if exists payments_insert on public.payments;
create policy payments_insert on public.payments
  for insert to authenticated
  with check (
    public.is_member_of(public.school_of_student(student_id))
    and public.has_permission(auth.uid(), 'comptabilite', 'enregistrer_paiement')
  );

drop policy if exists payments_update on public.payments;
create policy payments_update on public.payments
  for update to authenticated
  using (
    public.is_member_of(public.school_of_student(student_id))
    and public.has_permission(auth.uid(), 'comptabilite', 'enregistrer_paiement')
  )
  with check (public.is_member_of(public.school_of_student(student_id)));

drop policy if exists payments_delete on public.payments;
create policy payments_delete on public.payments
  for delete to authenticated
  using (
    public.is_member_of(public.school_of_student(student_id))
    and public.has_permission(auth.uid(), 'comptabilite', 'supprimer_facture')
  );

-- ── 3) GRILLES DE FRAIS ──────────────────────────────────────────────────────
--  Le trou le plus grave : aucune restriction n'excluait les comptes famille.
--  Lecture ouverte à l'école (une famille a le droit de savoir ce qu'elle
--  paiera) ; écriture réservée à `plans_facturation`.
drop policy if exists tenant_isolation on public.fee_structures;

drop policy if exists fee_structures_read on public.fee_structures;
create policy fee_structures_read on public.fee_structures
  for select to authenticated
  using (public.is_member_of(school_id));

drop policy if exists fee_structures_write on public.fee_structures;
create policy fee_structures_write on public.fee_structures
  for all to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'comptabilite', 'plans_facturation')
  )
  with check (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'comptabilite', 'plans_facturation')
  );

-- ── 4) Backfill : ne retirer aucun accès déjà réellement utilisé ────────────
--  Un rôle qui a déjà `creer_facture` est, par construction, LE rôle
--  comptabilité de son école — il gérait déjà factures et encaissements sans
--  restriction (tenant_isolation permissif). On lui donne aussi
--  `supprimer_facture` et `plans_facturation`, qu'il n'avait jamais eu besoin
--  de cocher explicitement puisque rien ne les vérifiait avant cette
--  migration. Sans ce backfill, ce déploiement retirerait silencieusement un
--  accès déjà en usage — même leçon que 20260744/20260746/20260762.
insert into public.staff_role_permissions (staff_role_id, permission_key, sub_permission_key)
select distinct sp.staff_role_id, 'comptabilite', missing.key
  from public.staff_role_permissions sp
  cross join (values ('supprimer_facture'), ('plans_facturation')) as missing(key)
 where sp.permission_key = 'comptabilite'
   and sp.sub_permission_key = 'creer_facture'
   and not exists (
     select 1 from public.staff_role_permissions x
      where x.staff_role_id = sp.staff_role_id
        and x.permission_key = 'comptabilite'
        and x.sub_permission_key = missing.key
   )
on conflict do nothing;

-- ============================================================================
--  VERIFICATION :
--
--    select count(*) from pg_policies
--     where qual ilike '%comptabilite%' or with_check ilike '%comptabilite%';
--    -- attendu : > 0 (avant cette migration : 0)
--
--    -- Un élève ne doit RIEN pouvoir sur l'argent :
--    select
--      public.has_permission(u.auth_uid, 'comptabilite', 'creer_facture'),
--      public.has_permission(u.auth_uid, 'comptabilite', 'enregistrer_paiement')
--    from public.users u where u.role::text = 'student' limit 1;
--    -- attendu : false / false (déjà vrai avant, via family_readonly_*  —
--    -- cette migration ne change rien pour les familles)
--
--    -- Le rôle Comptable garde tous ses droits après backfill :
--    select sub_permission_key from public.staff_role_permissions
--     where permission_key = 'comptabilite'
--       and staff_role_id = (select id from public.staff_roles where name = 'Comptable' limit 1)
--     order by 1;
--    -- attendu : creer_facture, enregistrer_paiement, exporter,
--    --           modifier_facture, plans_facturation, rapports,
--    --           supprimer_facture, voir_paiements
-- ============================================================================

-- ============================================================================
--  ROLLBACK — retrouver le comportement d'avant (permissif, non recommandé) :
--
--    drop policy if exists invoices_read   on public.invoices;
--    drop policy if exists invoices_insert on public.invoices;
--    drop policy if exists invoices_update on public.invoices;
--    drop policy if exists invoices_delete on public.invoices;
--    create policy tenant_isolation on public.invoices for all to authenticated
--      using (public.is_member_of(school_id)) with check (public.is_member_of(school_id));
--
--    drop policy if exists payments_read   on public.payments;
--    drop policy if exists payments_insert on public.payments;
--    drop policy if exists payments_update on public.payments;
--    drop policy if exists payments_delete on public.payments;
--    create policy tenant_isolation on public.payments for all to authenticated
--      using (exists (select 1 from public.users u where u.id = payments.student_id and public.is_member_of(u.school_id)))
--      with check (exists (select 1 from public.users u where u.id = payments.student_id and public.is_member_of(u.school_id)));
--
--    drop policy if exists fee_structures_read  on public.fee_structures;
--    drop policy if exists fee_structures_write on public.fee_structures;
--    create policy tenant_isolation on public.fee_structures for all to authenticated
--      using (school_id = public.current_school_id()) with check (school_id = public.current_school_id());
-- ============================================================================
