-- ============================================================================
--  20260810b_handle_new_user_avatar.sql — `handle_new_user` reprend aussi
--  `avatar_url` depuis les métadonnées auth (posé par le client à la
--  soumission de l'inscription, cf. school_registration_screen.dart), au
--  même titre que `full_name`/`role`/`school_id` déjà lus ici.
--
--  Sans ce changement, la photo est bien uploadée dans le bucket `avatars`
--  mais son URL n'atterrit jamais sur la ligne `users` créée par ce trigger.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_school uuid;
  v_role   text;
  v_name   text;
  v_avatar text;
begin
  v_school := nullif(new.raw_user_meta_data->>'school_id', '')::uuid;
  v_role   := coalesce(nullif(new.raw_user_meta_data->>'role', ''), 'student');
  v_name   := coalesce(nullif(new.raw_user_meta_data->>'full_name', ''),
                       split_part(new.email, '@', 1));
  v_avatar := nullif(new.raw_user_meta_data->>'avatar_url', '');

  if v_school is not null then
    insert into public.users (id, school_id, auth_uid, full_name, email, role, avatar_url, status, created_at, updated_at)
    values (new.id, v_school, new.id, v_name, new.email, v_role::public.user_role, v_avatar, 'active', now(), now())
    on conflict (id) do nothing;

    -- Sans cette ligne, is_member_of() (donc toute la RLS) ne voit jamais ce
    -- compte, quel que soit son `role` — cf. 20260706_school_members.sql.
    insert into public.school_members (user_id, school_id, role, status)
    values (new.id, v_school, v_role, 'active')
    on conflict (user_id, school_id) do nothing;
  end if;

  return new;
end;
$function$;

-- ============================================================================
--  VERIFICATION :
--    select pg_get_functiondef(oid) from pg_proc where proname = 'handle_new_user';
--    -- attendu : la fonction lit désormais `avatar_url` et l'écrit sur `users`
-- ============================================================================
