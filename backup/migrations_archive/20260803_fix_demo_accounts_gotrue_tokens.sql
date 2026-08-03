-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige : "Échec de la connexion" pour TOUS les comptes démo hand-craftés
-- via SQL (prof1, eleve51, parent1, eleve74, eleve106, admin1), sauf
-- kenganiboveldy@gmail.com (créé normalement via l'app, jamais par SQL).
--
-- Cause : nos migrations `insert into auth.users (...)` ne listaient pas les
-- colonnes token de GoTrue (`confirmation_token`, `recovery_token`,
-- `email_change`, `email_change_token_new/current`, `phone_change`,
-- `phone_change_token`, `reauthentication_token`) — elles restaient donc
-- `NULL`. Sur un compte créé normalement (signup normal), GoTrue les
-- initialise toujours à `''` (chaîne vide), jamais `NULL`. Le serveur GoTrue
-- fait un scan strict de ces colonnes en `string` (pas `sql.NullString`) lors
-- d'un `signInWithPassword` — une valeur `NULL` fait échouer la requête
-- interne, renvoyée au client comme une erreur générique de connexion.
--
-- ⚠️ Pour toute future création manuelle de compte via SQL (pattern déjà
-- utilisé dans 20260803_demo_login_accounts.sql, 20260803_demo_login_college_
-- lycee.sql, 20260803_demo_school_admin.sql) : soit lister ces colonnes
-- explicitement avec '' dans l'INSERT, soit lancer ce correctif juste après.
-- ─────────────────────────────────────────────────────────────────────────────

update auth.users
set confirmation_token         = coalesce(confirmation_token, ''),
    recovery_token             = coalesce(recovery_token, ''),
    email_change               = coalesce(email_change, ''),
    email_change_token_new     = coalesce(email_change_token_new, ''),
    email_change_token_current = coalesce(email_change_token_current, ''),
    phone_change               = coalesce(phone_change, ''),
    phone_change_token         = coalesce(phone_change_token, ''),
    reauthentication_token     = coalesce(reauthentication_token, '')
where email in (
  'prof1@test.local', 'eleve51@test.local', 'parent1@test.local',
  'eleve74@test.local', 'eleve106@test.local', 'admin1@test.local'
);
