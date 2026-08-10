-- ============================================================================
--  20260810_registration_avatar_storage.sql — photo de profil du fondateur,
--  choisie à l'étape 2 (Administrateur) de l'inscription.
--
--  Au moment où l'utilisateur choisit sa photo, ni l'école ni le compte
--  auth n'existent encore (créés seulement à la soumission finale, étape 3)
--  → même situation que les documents de pré-inscription
--  (20260751_enrollment_documents_storage.sql) : le dépôt doit être anonyme.
--
--  Chemin de chaque objet : pending/{upload_id}-{nom} où upload_id est un
--  UUID généré côté client à l'ouverture de l'étape 2 (pas le school_id,
--  qui n'existe pas encore à ce moment).
--
--  Bucket PUBLIC (comme `library-content`) : une photo de profil n'est pas
--  un document sensible, et doit être affichable directement (avatar dans
--  les listes d'utilisateurs) sans passer par une URL signée à chaque fois.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Dépôt public, restreint au préfixe `pending/` — pas de garde-fou côté
-- école (elle n'existe pas encore), donc pas de dépôt libre ailleurs dans
-- le bucket : ce préfixe borne le risque d'abus au strict nécessaire pour
-- l'inscription.
drop policy if exists avatars_registration_upload on storage.objects;
create policy avatars_registration_upload
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'pending'
  );

-- ============================================================================
--  VERIFICATION :
--    select id, public from storage.buckets where id = 'avatars';
--    -- attendu : public = true
-- ============================================================================
