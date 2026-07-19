-- ============================================================================
--  20260751_enrollment_documents_storage.sql — stockage réel des photos/
--  documents de la pré-inscription (jusqu'ici : maquette, aucun vrai fichier).
--
--  Chemin de chaque objet : {school_id}/{reference-ou-uuid}/{field_id}-{nom}
--  → le school_id en tête de chemin permet à la policy d'appliquer EXACTEMENT
--    la même règle anti-spam que `enrollment_requests` (période ouverte),
--    sans avoir besoin d'auth pour le dépôt public.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('enrollment-documents', 'enrollment-documents', false)
on conflict (id) do nothing;

-- Dépôt public (photo/pièces jointes du formulaire), même garde-fou que la
-- table `enrollment_requests` : uniquement si l'école a ouvert sa période.
drop policy if exists enrollment_documents_public_upload on storage.objects;
create policy enrollment_documents_public_upload
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'enrollment-documents'
    and exists (
      select 1 from public.schools s
       where s.id::text = (storage.foldername(name))[1]
         and s.is_active
         and s.preregistration_open
    )
  );

-- Lecture réservée au personnel de l'école concernée (dossier = school_id).
drop policy if exists enrollment_documents_school_read on storage.objects;
create policy enrollment_documents_school_read
  on storage.objects for select to authenticated
  using (
    bucket_id = 'enrollment-documents'
    and public.is_member_of(((storage.foldername(name))[1])::uuid)
  );

-- ============================================================================
--  VERIFICATION :
--    select id, public from storage.buckets where id = 'enrollment-documents';
--    -- attendu : public = false (accès uniquement via ces policies)
-- ============================================================================
