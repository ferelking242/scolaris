-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige : connexion admin (kenganiboveldy@gmail.com) qui échouait toujours
-- après le grand nettoyage du 2026-08-03.
--
-- Cause : `is_member_of()` (utilisée par la quasi-totalité des RLS, dont
-- `users_read`) exige une ligne active dans `school_members`. Pour tous les
-- comptes démo créés via un nouvel `insert into auth.users`, le trigger
-- `on_auth_user_created` (fonction `handle_new_user`) crée automatiquement
-- cette ligne. Mais le compte admin a été RECRÉÉ en réutilisant son
-- `auth.users` existant (pas de nouvel INSERT dedans, pour préserver son mot
-- de passe) — le trigger ne s'est donc jamais déclenché pour lui, et son
-- ancienne ligne `school_members` (pointant vers l'école supprimée) a été
-- perdue avec la cascade. Résultat : `_fetchProfile` (supabase_auth_source.dart)
-- ne trouvait aucune ligne `users` lisible → l'app affichait "Échec de la
-- connexion" en boucle malgré une authentification Supabase réussie.
-- ─────────────────────────────────────────────────────────────────────────────

insert into public.school_members (user_id, school_id, role, status)
values (
  'd48d4f14-aeee-49c6-9499-bc553437923d', -- kenganiboveldy@gmail.com
  'd893fffa-6ae1-4e94-a89f-8d6c400a7189', -- École Test Scolaris
  'admin', 'active'
)
on conflict (user_id, school_id) do nothing;
