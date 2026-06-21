# Déployer l'Edge Function `create-account`

Cette fonction crée les comptes côté serveur (la clé `service_role` n'est plus
dans l'app). À déployer **une fois** ; ensuite l'invitation de membres et
l'activation d'accès élève/parent fonctionnent.

## Option A — Tableau de bord Supabase (sans CLI, le plus simple)
1. Dashboard → **Edge Functions** → **Create a function**.
2. Nom : `create-account`.
3. Colle le contenu de `index.ts` (ce dossier).
4. **Deploy**.

Les variables `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
sont **injectées automatiquement** — rien à configurer.

## Option B — CLI
```bash
supabase functions deploy create-account --project-ref iaxwvgqusxyhmyansawi
```

## Vérifier
Dans l'app (connecté en admin) :
- **Utilisateurs → Inviter** un enseignant → le compte est créé immédiatement
  (sans email à confirmer) et apparaît dans la liste.
- Sur une fiche élève/parent (Pro/Max) → bouton **clé** « Activer l'accès » →
  saisir email + mot de passe → la personne peut se connecter.

## Sécurité
- Seul un appelant **admin / staff_custom** peut créer des comptes.
- L'école est déduite du profil appelant (jamais transmise par le client).
- En cas d'échec du lien (mode `link`), le compte auth créé est supprimé (rollback).
