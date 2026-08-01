-- ============================================================================
--  20260781_enrollment_documents_staff_upload.sql — corrige l'upload de
--  documents/photo bloqué (403 RLS) quand un membre du personnel inscrit un
--  élève manuellement (EnrollmentPage isAdminMode:true, ex. users_page.dart).
--
--  La policy d'origine (20260751) exigeait `schools.preregistration_open`
--  pour TOUT dépôt, anon comme authenticated. Mais `preregistration_open`
--  est un interrupteur métier pour le formulaire PUBLIC uniquement — un membre
--  du personnel qui crée une fiche depuis l'admin doit pouvoir déposer une
--  photo même si la période de pré-inscription publique est fermée.
--  Cohérent avec `enrollment_documents_school_read`, qui autorise déjà tout
--  membre actif de l'école sans condition de période.
-- ============================================================================

drop policy if exists enrollment_documents_public_upload on storage.objects;

-- Dépôt anonyme (formulaire public) : uniquement si la période est ouverte.
create policy enrollment_documents_public_upload
  on storage.objects for insert to anon
  with check (
    bucket_id = 'enrollment-documents'
    and exists (
      select 1 from public.schools s
       where s.id::text = (storage.foldername(name))[1]
         and s.is_active
         and s.preregistration_open
    )
  );

-- Dépôt par un membre du personnel de l'école (ex. inscription manuelle
-- depuis l'admin) : autorisé sans condition de période, comme la lecture.
create policy enrollment_documents_staff_upload
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'enrollment-documents'
    and public.is_member_of(((storage.foldername(name))[1])::uuid)
  );

-- ============================================================================
--  VERIFICATION :
--    select policyname, roles::text from pg_policies
--     where tablename='objects' and policyname like 'enrollment_documents%';
-- ============================================================================
