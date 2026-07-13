-- Garde-fou EN BASE de la limite d'élèves (ROADMAP A3).
-- La vérif app-side (`canAddStudent` dans users_page) est une bonne UX mais
-- contournable. Ce trigger garantit côté serveur qu'on ne dépasse jamais la
-- limite de l'offre, quel que soit le chemin d'écriture.
--
-- Ne concerne que les FICHES ÉLÈVES ACTIVES :
--   • INSERT d'un élève actif
--   • UPDATE qui fait passer un user à (role=student, status=active)
-- Les autres rôles (admin/teacher/parent) et les désactivations passent librement.
-- S'appuie sur public.school_can_add_student (corrigé : bloque si pas d'abonnement).

create or replace function public.enforce_student_limit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.role = 'student' and NEW.status = 'active' then
    -- Sur UPDATE : ne vérifier que si on devient réellement élève actif
    -- (évite de bloquer une simple modif de nom sur un élève déjà compté).
    if TG_OP = 'INSERT'
       or OLD.role is distinct from 'student'
       or OLD.status is distinct from 'active' then
      if not public.school_can_add_student(NEW.school_id) then
        raise exception 'Limite d''élèves de l''offre atteinte pour cette école'
          using errcode = 'check_violation';
      end if;
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_enforce_student_limit on public.users;
create trigger trg_enforce_student_limit
  before insert or update on public.users
  for each row execute function public.enforce_student_limit();
