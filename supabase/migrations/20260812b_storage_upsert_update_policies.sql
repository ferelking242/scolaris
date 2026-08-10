-- ============================================================================
--  20260812b_storage_upsert_update_policies.sql — les uploads de photo
--  (`FileOptions(upsert: true)`, cf. uploadStudentPhoto/uploadRegistrationAvatar/
--  uploadEnrollmentDocument) déclenchent un UPSERT : si le même chemin existe
--  déjà (retente après échec réseau, même session d'upload rouverte…),
--  Storage passe par la voie UPDATE — qui n'avait AUCUNE policy, sur AUCUN
--  bucket. Confirmé en direct : un INSERT réussit, le UPSERT du même chemin
--  échoue avec "new row violates row-level security policy" faute de policy
--  UPDATE. Symptôme exact du popup signalé.
--
--  On rejoue simplement chaque policy INSERT existante, mais pour UPDATE.
-- ============================================================================

drop policy if exists avatars_registration_upload_update on storage.objects;
create policy avatars_registration_upload_update
  on storage.objects for update to anon, authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = 'pending')
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = 'pending');

drop policy if exists avatars_student_upload_staff_update on storage.objects;
create policy avatars_student_upload_staff_update
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and public.is_member_of(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'avatars' and public.is_member_of(((storage.foldername(name))[1])::uuid));

drop policy if exists avatars_student_upload_public_update on storage.objects;
create policy avatars_student_upload_public_update
  on storage.objects for update to anon
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] in (
      select s.id::text from public.schools s where s.is_active and s.preregistration_open
    )
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] in (
      select s.id::text from public.schools s where s.is_active and s.preregistration_open
    )
  );

drop policy if exists enrollment_documents_staff_upload_update on storage.objects;
create policy enrollment_documents_staff_upload_update
  on storage.objects for update to authenticated
  using (bucket_id = 'enrollment-documents' and public.is_member_of(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'enrollment-documents' and public.is_member_of(((storage.foldername(name))[1])::uuid));

drop policy if exists enrollment_documents_public_upload_update on storage.objects;
create policy enrollment_documents_public_upload_update
  on storage.objects for update to anon, authenticated
  using (
    bucket_id = 'enrollment-documents'
    and (storage.foldername(name))[1] in (
      select s.id::text from public.schools s where s.is_active and s.preregistration_open
    )
  )
  with check (
    bucket_id = 'enrollment-documents'
    and (storage.foldername(name))[1] in (
      select s.id::text from public.schools s where s.is_active and s.preregistration_open
    )
  );

drop policy if exists library_content_upload_update on storage.objects;
create policy library_content_upload_update
  on storage.objects for update to authenticated
  using (bucket_id = 'library-content')
  with check (bucket_id = 'library-content');

-- ============================================================================
--  VERIFICATION :
--    select policyname, cmd from pg_policies
--     where tablename='objects' and cmd='UPDATE';
--    -- attendu : les 6 policies ci-dessus
-- ============================================================================
