-- ============================================================================
--  20260758_reset_platform_admin_password.sql — Mot de passe connu pour le
--  compte super-admin de démonstration
--
--  Le bouton « Super-Admin » de l'écran de connexion (login_screen.dart,
--  _demoQuickRow) pointe vers kenganiboveldy@gmail.com avec un mot de passe
--  dont plus personne ne se souvient. On le réinitialise sur `demo1234` —
--  cohérent avec le reste de la section « Connexion rapide (démo · demo1234) »
--  — au lieu de laisser un bouton qui échoue silencieusement.
--
--  Idempotent. Rejouable.
-- ============================================================================

update auth.users
   set encrypted_password = crypt('demo1234', gen_salt('bf')),
       email_confirmed_at = coalesce(email_confirmed_at, now()),
       updated_at = now()
 where email = 'kenganiboveldy@gmail.com';

-- ============================================================================
--  VERIFICATION :
--    select email, email_confirmed_at is not null as confirmed
--      from auth.users where email = 'kenganiboveldy@gmail.com';
--    -- puis dans l'app : kenganiboveldy@gmail.com / demo1234
-- ============================================================================
