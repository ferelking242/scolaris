-- Fix bug réel (10/08/2026) : l'inscription publique d'une école échouait
-- systématiquement (pas seulement en "Formation professionnelle") avec
-- "Accès refusé par la base de données (permissions)" côté app, message
-- Postgrest réel : 42501 new row violates row-level security policy for
-- table "subscriptions".
--
-- Cause : le trigger AFTER INSERT ON schools -> handle_new_school_trial()
-- (créé par 20260809_signup_chosen_plan.sql) insère une ligne dans
-- public.subscriptions pour démarrer l'essai 14 jours. Cette fonction
-- n'était PAS SECURITY DEFINER, donc elle s'exécutait avec les droits du
-- rôle appelant (anon, lors de l'inscription publique school_registration_
-- screen.dart) — or `subscriptions` n'a aucune policy RLS autorisant un
-- anon (ni un authenticated pas encore membre de l'école) à y écrire.
--
-- Les fonctions sœurs du même flux (handle_new_user, log_school_created)
-- sont bien SECURITY DEFINER avec search_path=public fixé — cette fonction
-- avait été créée sans ce pattern. Alignement :

alter function public.handle_new_school_trial() security definer;
alter function public.handle_new_school_trial() set search_path = public;

-- Appliqué en direct sur l'instance iaxwvgqusxyhmyansawi le 10/08/2026.
