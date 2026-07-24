-- ============================================================================
--  20260767_fix_user_settings_trigger.sql — create_user_settings() doit être
--  SECURITY DEFINER
--
--  Le trigger `trg_user_settings` (AFTER INSERT ON users) insère une ligne
--  `user_settings` pour CHAQUE nouvel utilisateur créé (élève, personnel...).
--  La fonction s'exécutait avec les droits de l'appelant (l'admin qui inscrit
--  l'élève), pas ceux du système — la policy `user_settings_own`
--  (`user_id = my_user_id()`) refusait donc l'insertion dès qu'on créait un
--  compte pour quelqu'un d'autre que soi-même :
--    "new row violates row-level security policy for table user_settings"
--  Pour un trigger système qui initialise une ligne au nom d'un tiers,
--  SECURITY DEFINER est le bon choix (même logique que les triggers
--  platform_events, cf. 20260764).
--
--  Idempotent. Rejouable.
-- ============================================================================

create or replace function public.create_user_settings()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
  BEGIN
    INSERT INTO user_settings (user_id, school_id) VALUES (NEW.id, NEW.school_id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NULL;
  END;
  $function$;

-- ============================================================================
--  VERIFICATION (connecté en admin d'école, pas en tant que l'élève créé) :
--    insert into public.users (school_id, full_name, email, role, status, permissions)
--    values ('<school_id>', 'Test Trigger', 'test.trigger@example.com', 'student', 'active', '[]')
--    returning id;
--    -- puis : select * from public.user_settings where user_id = '<id ci-dessus>';
--    -- doit renvoyer une ligne, sans erreur RLS.
-- ============================================================================
