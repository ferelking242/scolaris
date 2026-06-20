-- ============================================================
-- SCOLARIS — Trigger : création auto du profil à l'inscription
-- À exécuter dans : Supabase Dashboard > SQL Editor
--
-- Quand un compte auth est créé (signUp), ce trigger crée automatiquement
-- la ligne users + profiles correspondante, en lisant les métadonnées passées
-- au signUp : { full_name, role, school_id }.
--
-- Utilisé par l'inscription d'école : le fondateur signUp avec role='admin'
-- + school_id, et devient admin de SON école sans insertion côté client.
--
-- Sécurité : ne crée le profil QUE si school_id est fourni (parcours école).
-- Les autres signups éventuels ne déclenchent rien (pas de profil orphelin).
-- ============================================================

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
  v_entity text;
begin
  v_school := nullif(new.raw_user_meta_data->>'school_id', '')::uuid;
  v_role   := coalesce(nullif(new.raw_user_meta_data->>'role', ''), 'student');
  v_name   := coalesce(nullif(new.raw_user_meta_data->>'full_name', ''),
                       split_part(new.email, '@', 1));

  -- entity_type pour profiles : on regroupe les métiers staff
  v_entity := case
                when v_role in ('admin','finance','surveillance','staff_custom') then 'staff'
                else v_role
              end;

  -- On ne crée le profil que pour un parcours rattaché à une école
  if v_school is not null then
    insert into public.users (id, school_id, auth_uid, full_name, email, role, status, created_at, updated_at)
    values (new.id, v_school, new.id, v_name, new.email, v_role::public.user_role, 'active', now(), now())
    on conflict (id) do nothing;

    insert into public.profiles (id, school_id, entity_type, full_name, email, active, created_at, updated_at)
    values (new.id, v_school, v_entity, v_name, new.email, true, now(), now())
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
