-- ============================================================================
--  20260811_avatars_student_photo.sql — la photo d'un élève (champ « Photo
--  d'identité » du formulaire d'inscription, cf. shared/data/enrollment_config.dart)
--  rejoint le bucket public `avatars` créé en
--  20260810_registration_avatar_storage.sql, sous le préfixe {school_id}/ —
--  distinct du préfixe `pending/` réservé à la photo du fondateur avant que
--  l'école n'existe.
--
--  Deux cas d'usage, deux policies :
--   1. Le personnel inscrit un élève depuis le dashboard (authentifié,
--      membre de l'école) → `avatars_student_upload_staff`.
--   2. Un parent s'auto-inscrit via le formulaire public (anonyme, l'école
--      existe déjà) → `avatars_student_upload_public`, même garde-fou que
--      les documents de pré-inscription (école active + période ouverte).
-- ============================================================================

drop policy if exists avatars_student_upload_staff on storage.objects;
create policy avatars_student_upload_staff
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and public.is_member_of(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists avatars_student_upload_public on storage.objects;
create policy avatars_student_upload_public
  on storage.objects for insert to anon
  with check (
    bucket_id = 'avatars'
    and exists (
      select 1 from public.schools s
       where s.id::text = (storage.foldername(name))[1]
         and s.is_active
         and s.preregistration_open
    )
  );

-- ============================================================================
--  VERIFICATION :
--    select policyname from pg_policies
--     where tablename = 'objects' and policyname like 'avatars_%';
--    -- attendu : avatars_registration_upload, avatars_student_upload_staff,
--    --           avatars_student_upload_public
-- ============================================================================
