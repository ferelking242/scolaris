-- Le statut (pending/published/rejected) ne peut être changé que par un
-- super-admin plateforme — c'est la modération elle-même.
drop policy if exists bibliotheque_moderate on bibliotheque;
create policy bibliotheque_moderate on bibliotheque for update
  using (is_platform_admin(auth.uid()))
  with check (is_platform_admin(auth.uid()));

drop policy if exists exam_subjects_moderate on exam_subjects;
create policy exam_subjects_moderate on exam_subjects for update
  using (is_platform_admin(auth.uid()))
  with check (is_platform_admin(auth.uid()));

drop policy if exists course_materials_moderate on course_materials;
create policy course_materials_moderate on course_materials for update
  using (is_platform_admin(auth.uid()))
  with check (is_platform_admin(auth.uid()));
