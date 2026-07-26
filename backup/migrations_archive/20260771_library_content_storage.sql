-- Bucket de stockage pour les fichiers soumis à la bibliothèque partagée
-- (livres, annales, supports). Public en lecture : une fois publié, le
-- contenu est censé être largement diffusé à toutes les écoles — comme les
-- lignes de catalogue elles-mêmes (pas de school_id).
--
-- Chemin de chaque objet : {category}/{uuid}-{nom} où category ∈
-- {bibliotheque, exam_subjects, course_materials}.

insert into storage.buckets (id, name, public)
values ('library-content', 'library-content', true)
on conflict (id) do nothing;

-- Dépôt réservé à un membre d'école authentifié (n'importe quel rôle staff ;
-- la permission library_contribute filtre déjà l'accès à l'écran de dépôt
-- côté app, la policy Storage ne fait qu'exiger une session valide).
drop policy if exists library_content_upload on storage.objects;
create policy library_content_upload
  on storage.objects for insert to authenticated
  with check (bucket_id = 'library-content');

-- ============================================================================
--  VERIFICATION :
--    select id, public from storage.buckets where id = 'library-content';
--    -- attendu : public = true
-- ============================================================================
