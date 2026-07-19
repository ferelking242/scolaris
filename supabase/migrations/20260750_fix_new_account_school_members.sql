-- ============================================================================
--  20260750_fix_new_account_school_members.sql — corrige la redirection vers
--  "Étudiant Lycée" des comptes fraîchement invités (prof, staff...).
--
--  ── Le bug ──────────────────────────────────────────────────────────────────
--  20260706_school_members.sql a rendu `is_member_of(school_id)` (donc toute la
--  RLS) dépendante d'une ligne ACTIVE dans `school_members`, en plus de
--  `users.school_id`. Le backfill de cette migration n'a couvert que les
--  comptes DÉJÀ existants à l'époque. Ni `handle_new_user()` (trigger auth), ni
--  les inserts directs de `createStudent`/`createOrLinkGuardian` côté Dart
--  n'ont jamais été mis à jour pour poser cette ligne pour les NOUVEAUX
--  comptes.
--
--  Conséquence : un compte créé depuis le 06/07 a un `users.role` correct
--  ('teacher', etc.) mais est invisible à lui-même (RLS bloque `select` sur sa
--  propre ligne) → `_fetchProfile` (Dart) reçoit `null` et se rabat sur un faux
--  profil `UserRole.student` → redirection vers l'espace Étudiant (Lycée par
--  défaut).
--
--  ── Le correctif ────────────────────────────────────────────────────────────
--    1. `handle_new_user()` pose aussi la ligne `school_members` (comptes créés
--       via Supabase Auth : signup direct, Edge Function create-account).
--    2. Backfill immédiat pour rattraper tous les comptes déjà cassés.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_school uuid;
  v_role   text;
  v_name   text;
begin
  v_school := nullif(new.raw_user_meta_data->>'school_id', '')::uuid;
  v_role   := coalesce(nullif(new.raw_user_meta_data->>'role', ''), 'student');
  v_name   := coalesce(nullif(new.raw_user_meta_data->>'full_name', ''),
                       split_part(new.email, '@', 1));

  if v_school is not null then
    insert into public.users (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
    values (new.id, v_school, new.id, v_name, new.email, v_role::public.user_role, 'active', now(), now())
    on conflict (id) do nothing;

    -- Sans cette ligne, is_member_of() (donc toute la RLS) ne voit jamais ce
    -- compte, quel que soit son `role` — cf. 20260706_school_members.sql.
    insert into public.school_members (user_id, school_id, role, status)
    values (new.id, v_school, v_role, 'active')
    on conflict (user_id, school_id) do nothing;
  end if;

  return new;
end;
$$;

-- Rattrapage : tout compte dont la ligne `users` a un `school_id` mais aucune
-- adhésion active correspondante (créé après le backfill du 06/07, cassé
-- silencieusement depuis).
insert into public.school_members (user_id, school_id, role, status)
select u.id, u.school_id, u.role::text, 'active'
from public.users u
where u.school_id is not null
  and not exists (
    select 1 from public.school_members m
    where m.user_id = u.id and m.school_id = u.school_id
  )
on conflict (user_id, school_id) do nothing;

-- ============================================================================
--  VERIFICATION :
--    -- Combien de comptes étaient cassés (avant le backfill ci-dessus) ?
--    select count(*) from public.users u
--     where u.school_id is not null
--       and not exists (select 1 from public.school_members m
--                        where m.user_id = u.id and m.school_id = u.school_id);
--    -- attendu après migration : 0
-- ============================================================================
