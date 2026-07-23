-- ============================================================================
--  20260763_platform_school_detail_read.sql — Fiche école : vrais élèves +
--  vrai historique de paiements d'abonnement
--
--  L'onglet Élèves de la fiche école (console super-admin) affichait un
--  roster INVENTÉ (déduit de l'id de l'école, cf. PlatformMock.studentsFor).
--  On expose maintenant la vraie liste via une fonction dédiée, SANS donner
--  d'accès large à `users` à un admin plateforme (même logique de privacy que
--  `platform_total_students()`/`platform_school_stats()`) : seuls nom, classe,
--  matricule et statut d'un élève sortent, rien d'autre (pas d'email/téléphone).
--
--  L'onglet Facturation affichait un historique de paiements inventé aussi —
--  `subscription_payments` existe déjà en base (paiements réels de l'école à
--  Scolaris) : il ne manquait qu'une policy de lecture pour la plateforme.
--
--  Idempotent. Rejouable.
-- ============================================================================

create or replace function public.platform_school_students(p_school_id uuid)
returns table(full_name text, class_name text, matricule text, active boolean)
language sql
stable
security definer
set search_path = public
as $$
  select u.full_name, c.name, sp.matricule, sp.enrollment_status = 'active'
  from public.users u
  join public.student_profiles sp on sp.user_id = u.id
  left join public.classes c on c.id = sp.class_id
  where u.school_id = p_school_id
    and u.role = 'student'
    and public.is_platform_admin(auth.uid())
  order by u.full_name;
$$;

grant execute on function public.platform_school_students(uuid) to authenticated;

drop policy if exists platform_admin_read_subscription_payments on public.subscription_payments;
create policy platform_admin_read_subscription_payments
  on public.subscription_payments for select
  to authenticated
  using (public.is_platform_admin(auth.uid()));

-- ============================================================================
--  VERIFICATION (connecté en super-admin) :
--    select * from platform_school_students('<school_id>') limit 5;
--    select * from public.subscription_payments limit 5;
-- ============================================================================
