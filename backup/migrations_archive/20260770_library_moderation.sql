-- Bibliothèque : contribution modérée, catalogue universel.
-- Ajoute un statut de modération + traçabilité de la soumission sur les 3
-- tables du catalogue partagé (pas de school_id : universel une fois publié).

alter table bibliotheque
  add column if not exists status text not null default 'pending',
  add column if not exists submitted_by_school_id uuid references schools(id),
  add column if not exists submitted_by_user_id uuid references users(id),
  add column if not exists rejection_reason text;

alter table bibliotheque
  drop constraint if exists bibliotheque_status_check;
alter table bibliotheque
  add constraint bibliotheque_status_check check (status in ('pending','published','rejected'));

alter table exam_subjects
  add column if not exists status text not null default 'pending',
  add column if not exists submitted_by_school_id uuid references schools(id),
  add column if not exists submitted_by_user_id uuid references users(id),
  add column if not exists rejection_reason text;

alter table exam_subjects
  drop constraint if exists exam_subjects_status_check;
alter table exam_subjects
  add constraint exam_subjects_status_check check (status in ('pending','published','rejected'));

alter table course_materials
  add column if not exists status text not null default 'pending',
  add column if not exists submitted_by_school_id uuid references schools(id),
  add column if not exists submitted_by_user_id uuid references users(id),
  add column if not exists rejection_reason text;

alter table course_materials
  drop constraint if exists course_materials_status_check;
alter table course_materials
  add constraint course_materials_status_check check (status in ('pending','published','rejected'));

-- Le contenu déjà en place (injecté à la main par la plateforme) est réputé
-- publié : sans ça, tout le catalogue existant disparaîtrait côté élève.
update bibliotheque set status = 'published' where status = 'pending';
update exam_subjects set status = 'published' where status = 'pending';
update course_materials set status = 'published' where status = 'pending';

-- RLS : lecture publique du contenu publié, + lecture par l'école
-- soumettrice de ses propres items en attente/rejetés (suivi de soumission).
-- Écriture (insert) réservée à un utilisateur authentifié d'une école.
-- Le update du statut (modération) reste réservé au service_role (utilisé
-- exclusivement par la console plateforme via une Edge Function dédiée).

alter table bibliotheque enable row level security;
alter table exam_subjects enable row level security;
alter table course_materials enable row level security;

-- Remplace l'ancienne policy « shared_read » (qual: true, accès total) qui
-- exposerait sinon les items pending/rejected à tout le monde en plus de la
-- nouvelle policy restreinte (les policies SELECT s'additionnent en OR).
drop policy if exists shared_read on bibliotheque;
drop policy if exists shared_read on exam_subjects;
drop policy if exists shared_read on course_materials;

drop policy if exists bibliotheque_read on bibliotheque;
create policy bibliotheque_read on bibliotheque for select
  using (
    status = 'published'
    or (submitted_by_school_id is not null and is_member_of(submitted_by_school_id))
  );

drop policy if exists bibliotheque_insert on bibliotheque;
create policy bibliotheque_insert on bibliotheque for insert
  with check (auth.uid() is not null);

drop policy if exists exam_subjects_read on exam_subjects;
create policy exam_subjects_read on exam_subjects for select
  using (
    status = 'published'
    or (submitted_by_school_id is not null and is_member_of(submitted_by_school_id))
  );

drop policy if exists exam_subjects_insert on exam_subjects;
create policy exam_subjects_insert on exam_subjects for insert
  with check (auth.uid() is not null);

drop policy if exists course_materials_read on course_materials;
create policy course_materials_read on course_materials for select
  using (
    status = 'published'
    or (submitted_by_school_id is not null and is_member_of(submitted_by_school_id))
  );

drop policy if exists course_materials_insert on course_materials;
create policy course_materials_insert on course_materials for insert
  with check (auth.uid() is not null);
