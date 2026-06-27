-- ============================================================
-- SCOLARIS — Multi-tenancy : isolation des donnees par ecole (RLS)
-- A relire PUIS exécuter dans : Supabase Dashboard > SQL Editor.
--
-- Objectif : chaque ecole (tenant) ne voit/modifie QUE ses propres donnees.
-- Mecanisme : Row Level Security (RLS) + une fonction qui renvoie le school_id
-- de l'utilisateur connecte. Toute requete authentifiee est filtree dessus.
--
-- Le SQL Editor s'execute en role `postgres` (bypass RLS) → le seed reste OK.
-- La cle `service_role` bypasse aussi la RLS (scripts admin). L'app, elle, passe
-- par un utilisateur authentifie → la RLS s'applique.
--
-- ⚠️ Limite assumee (1ʳᵉ couche) : la RLS isole par ECOLE, mais n'impose pas
--    encore les regles intra-ecole (ex: un eleve ne doit pas modifier une note).
--    L'autorisation fine par role viendra dans une couche ulterieure.
-- Idempotent (drop policy if exists). Rejouable sans danger.
-- ============================================================

-- 1) Fonction : school_id de l'utilisateur connecte (via public.users).
--    SECURITY DEFINER => peut lire users sans etre bloquee par la RLS de users.
create or replace function public.current_school_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select school_id from public.users where auth_uid = auth.uid() limit 1;
$$;

grant execute on function public.current_school_id() to anon, authenticated;

-- 2) Tables standard (colonne school_id directe) : policy d'isolation uniforme.
do $$
declare
  t text;
  tables text[] := array[
    'absences','announcement_comments','announcement_likes','announcements',
    'assignments','classes','courses','exams','filieres','grades','invoices',
    'messages','parent_student','resources','school_branches','school_classes',
    'school_founders','school_series','student_profiles','subjects','submissions',
    'teacher_classes','teacher_profiles','user_settings','users'
  ];
begin
  foreach t in array tables loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists tenant_isolation on public.%I', t);
    execute format(
      'create policy tenant_isolation on public.%I for all to authenticated '
      'using (school_id = public.current_school_id()) '
      'with check (school_id = public.current_school_id())', t);
  end loop;
end $$;

-- 3) Tables sans school_id direct : rattachement indirect.

-- schools : l'utilisateur lit/gere SON ecole. (L'INSERT anon d'inscription reste
-- couvert par les policies "Inscription publique - schools" deja en place.)
alter table public.schools enable row level security;
drop policy if exists tenant_isolation on public.schools;
create policy tenant_isolation on public.schools for all to authenticated
  using (id = public.current_school_id())
  with check (id = public.current_school_id());

-- attendance : rattachee via la classe (classes.school_id).
alter table public.attendance enable row level security;
drop policy if exists tenant_isolation on public.attendance;
create policy tenant_isolation on public.attendance for all to authenticated
  using (exists (select 1 from public.classes c
                 where c.id = attendance.class_id
                   and c.school_id = public.current_school_id()))
  with check (exists (select 1 from public.classes c
                      where c.id = attendance.class_id
                        and c.school_id = public.current_school_id()));

-- payments : rattachee via l'eleve (users.school_id).
alter table public.payments enable row level security;
drop policy if exists tenant_isolation on public.payments;
create policy tenant_isolation on public.payments for all to authenticated
  using (exists (select 1 from public.users u
                 where u.id = payments.student_id
                   and u.school_id = public.current_school_id()))
  with check (exists (select 1 from public.users u
                      where u.id = payments.student_id
                        and u.school_id = public.current_school_id()));

-- 4) Contenu partage / reference (pas de cloisonnement par ecole).

-- class_levels : catalogue de reference mondial → deja en "Lecture publique".
--   (rien a changer ; laisse tel quel)

-- bibliotheque : pas de school_id aujourd'hui → traitee comme catalogue partage,
--   lecture pour tout utilisateur connecte. TODO : ajouter school_id pour
--   cloisonner les bibliotheques par ecole, puis basculer sur tenant_isolation.
alter table public.bibliotheque enable row level security;
drop policy if exists shared_read on public.bibliotheque;
create policy shared_read on public.bibliotheque for select to authenticated
  using (true);

-- ============================================================
-- Resultat : 27 tables cloisonnees par ecole + 2 catalogues partages.
-- Verif rapide (connecte en tant qu'admin EAD, via l'app) : ne voir que les
-- donnees de l'ecole EAD. En SQL Editor (role postgres) on voit tout, c'est normal.
-- ============================================================
