-- ============================================================================
--  20260812_fix_public_upload_name_ambiguity.sql — corrige un vrai bug RLS,
--  pas juste un accès manquant : la policy d'upload anonyme (pré-inscription
--  publique) ne fonctionnait JAMAIS, ni pour les documents ni pour la photo
--  élève, ni même avant cette conversation (le bug existait déjà dans
--  20260751_enrollment_documents_storage.sql).
--
--  Preuve en direct (`begin; set local role anon; insert into storage.objects
--  (bucket_id, name) values ('avatars', '<school>/x.jpg'); rollback;`) :
--    ERROR: new row violates row-level security policy for table "objects"
--
--  Cause : dans
--    exists (select 1 from public.schools s
--             where s.id::text = (storage.foldername(name))[1] ...)
--  le `name` NU, à l'intérieur du sous-select, se lie à `schools.name` (le
--  NOM de l'école — cette colonne existe !) plutôt qu'au `name` de la ligne
--  storage.objects en cours d'insertion, à cause des règles standard de
--  portée SQL (la table la plus proche gagne pour un nom non qualifié).
--  `pg_policies` le confirme : la policy stockée affichait bien
--  `storage.foldername(s.name)`, jamais `storage.foldername(name)`.
--  `schools.name` sur une seule école n'a pas de "/", donc `foldername()`
--  renvoie toujours NULL → la condition est toujours fausse.
--
--  Correctif : extraire `(storage.foldername(name))[1]` AVANT le sous-select
--  (dans la clause `IN`), pour que `name` ne soit jamais évalué dans la
--  portée du sous-select — donc jamais capturé par `schools.name`.
-- ============================================================================

drop policy if exists enrollment_documents_public_upload on storage.objects;
create policy enrollment_documents_public_upload
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'enrollment-documents'
    and (storage.foldername(name))[1] in (
      select s.id::text from public.schools s
       where s.is_active and s.preregistration_open
    )
  );

drop policy if exists avatars_student_upload_public on storage.objects;
create policy avatars_student_upload_public
  on storage.objects for insert to anon
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] in (
      select s.id::text from public.schools s
       where s.is_active and s.preregistration_open
    )
  );

-- ============================================================================
--  VERIFICATION (rejoue la preuve ci-dessus, doit maintenant réussir) :
--    begin;
--    set local role anon;
--    insert into storage.objects (bucket_id, name)
--    values ('avatars', '<school_id_avec_preregistration_open>/x.jpg');
--    -- attendu : succès (puis rollback pour ne rien laisser)
--    rollback;
-- ============================================================================
