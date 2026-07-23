# Déployer l'Edge Function `platform-create-school`

Cette fonction crée une nouvelle école + son compte admin depuis la console
super-admin (page **Écoles**). La clé `service_role` ne vit QUE dans cette
fonction.

## Déploiement — Tableau de bord Supabase (sans CLI)
1. Dashboard → **Edge Functions** → **Create a function**.
2. Nom : `platform-create-school`.
3. Colle le contenu de `index.ts` (ce dossier).
4. **Deploy**.

Les variables `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
sont injectées automatiquement — rien à configurer.

## Prérequis
- La migration `20260756_platform_admins.sql` doit déjà être appliquée
  (fonction `is_platform_admin`).

## Vérifier
Dans l'app, connecté avec le compte super-admin (`kenganiboveldy@gmail.com`) :
- Console plateforme → **Écoles** → **Nouvelle école** → remplir le
  formulaire → **Créer l'école**.
- La fiche de la nouvelle école s'ouvre directement ; elle doit apparaître
  dans la liste avec le statut « Essai ».

## Sécurité
- Seul un appelant `is_platform_admin(auth.uid())` peut créer une école.
- En cas d'échec de la création du compte admin, l'école est retirée
  (rollback) pour ne pas laisser d'enregistrement orphelin.
