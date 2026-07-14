-- ============================================================================
--  20260728_lock_money.sql — Verrouiller l'ARGENT
--
--  Etat avant :
--      invoices         ALL   tenant_isolation   is_member_of(school_id)
--      fee_structures   ALL   tenant_isolation   is_member_of(school_id)
--      payments         ALL   tenant_isolation   (via l'ecole de l'eleve)
--
--  Tout membre de l'ecole pouvait donc, en appelant l'API directement :
--    • passer sa facture de scolarite a status = 'paid' ;
--    • s'inscrire un encaissement de 150 000 F qui n'a jamais eu lieu ;
--    • baisser le montant de sa propre facture ;
--    • effacer les factures des autres.
--
--  Un ELEVE est membre de son ecole. Il pouvait faire tout cela.
--
--  ── Une particularite de `payments` ────────────────────────────────────────
--  Cette table n'a PAS de colonne `school_id` : son ecole se deduit de l'eleve
--  (`payments.student_id -> users.school_id`). Toutes les regles ci-dessous en
--  tiennent compte — on ne peut pas y appeler is_member_of(school_id).
-- ============================================================================

-- ── Helper : l'ecole d'un encaissement, deduite de l'eleve ──────────────────
create or replace function public.school_of_student(p_student_id uuid)
returns uuid
language sql stable security definer
set search_path = public
as $fn$
  select school_id from public.users where id = p_student_id;
$fn$;

grant execute on function public.school_of_student(uuid) to authenticated;

-- ============================================================================
--  1) FACTURES
-- ============================================================================
drop policy if exists tenant_isolation on public.invoices;

-- LECTURE — l'eleve voit SES factures, le parent celles de ses enfants, la
--  comptabilite celles de l'ecole. Une famille doit pouvoir consulter ce
--  qu'elle doit : c'est le coeur du suivi de scolarite.
drop policy if exists invoices_read on public.invoices;
create policy invoices_read on public.invoices
  for select to authenticated
  using (
    public.is_member_of(school_id)
    and (
      student_id = public.my_user_id()
      or public.is_my_child(auth.uid(), student_id)
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

-- MODIFICATION — c'est ici que se jouait le trou : `status = 'paid'` est une
--  simple mise a jour de facture. Elle exige desormais le droit de modifier une
--  facture, que ni l'eleve ni le parent n'auront jamais.
drop policy if exists invoices_update on public.invoices;
create policy invoices_update on public.invoices
  for update to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'comptabilite', 'modifier_facture')
  )
  with check (public.is_member_of(school_id));

drop policy if exists invoices_delete on public.invoices;
create policy invoices_delete on public.invoices
  for delete to authenticated
  using (
    public.is_member_of(school_id)
    and public.has_permission(auth.uid(), 'comptabilite', 'supprimer_facture')
  );

-- ============================================================================
--  2) ENCAISSEMENTS
--  Un paiement est une ECRITURE COMPTABLE : on l'enregistre, on ne l'invente
--  pas. Seule la caisse (comptabilite.enregistrer_paiement) en cree.
-- ============================================================================
drop policy if exists tenant_isolation on public.payments;

drop policy if exists payments_read on public.payments;
create policy payments_read on public.payments
  for select to authenticated
  using (
    public.is_member_of(public.school_of_student(student_id))
    and (
      student_id = public.my_user_id()
      or public.is_my_child(auth.uid(), student_id)
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

-- SUPPRESSION — effacer un encaissement, c'est faire disparaitre de l'argent
--  des livres. On l'aligne sur le droit le plus fort de la comptabilite.
drop policy if exists payments_delete on public.payments;
create policy payments_delete on public.payments
  for delete to authenticated
  using (
    public.is_member_of(public.school_of_student(student_id))
    and public.has_permission(auth.uid(), 'comptabilite', 'supprimer_facture')
  );

-- ── Qui a encaisse ? ────────────────────────────────────────────────────────
--  `payments.received_by` existait mais restait NULL : l'application ne le
--  renseignait pas. Sur une table d'argent, savoir qui a touche la caisse n'est
--  pas un luxe — c'est la premiere question posee le jour ou un montant manque.
--  On le fait poser par la base plutot que par l'appelant : impossible d'oublier,
--  impossible de mentir.
create or replace function public.stamp_payment_receiver()
returns trigger
language plpgsql security definer
set search_path = public
as $fn$
begin
  if new.received_by is null then
    new.received_by := public.my_user_id();
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_stamp_payment_receiver on public.payments;
create trigger trg_stamp_payment_receiver
  before insert on public.payments
  for each row execute function public.stamp_payment_receiver();

-- ============================================================================
--  3) GRILLES DE FRAIS
--  Le bareme de la scolarite : combien coute une annee, en combien d'echeances.
--  Lisible par l'ecole (une famille a le droit de savoir ce qu'elle paiera),
--  modifiable par qui etablit les plans de facturation.
-- ============================================================================
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

-- ============================================================================
--  VERIFICATION — un eleve ne doit RIEN pouvoir sur l'argent :
--
--    select
--      public.has_permission(u.auth_uid, 'comptabilite', 'modifier_facture')     as paie_sa_facture,
--      public.has_permission(u.auth_uid, 'comptabilite', 'enregistrer_paiement') as invente_un_versement
--    from public.users u
--    where u.role::text = 'student' limit 1;
--    -- attendu : false / false
--
--  Et le comptable, oui :
--    select r.name,
--           public.has_permission(u.auth_uid, 'comptabilite', 'enregistrer_paiement')
--      from public.users u
--      join public.staff_roles r on r.id = u.staff_role_id
--     where r.name = 'Comptable';
--    -- attendu : true
--
--  Le tampon d'encaissement fonctionne :
--    select p.amount, u.full_name as encaisse_par
--      from public.payments p
--      left join public.users u on u.id = p.received_by
--     order by p.created_at desc limit 5;
--    -- les nouveaux paiements doivent porter un nom (les anciens restent NULL).
-- ============================================================================

-- ============================================================================
--  ROLLBACK
--
--    drop trigger if exists trg_stamp_payment_receiver on public.payments;
--    drop function if exists public.stamp_payment_receiver();
--    drop function if exists public.school_of_student(uuid);
--    -- puis rejouer 20260617_multitenancy_rls_fix.sql pour retrouver les
--    -- policies `tenant_isolation` d'origine.
-- ============================================================================
