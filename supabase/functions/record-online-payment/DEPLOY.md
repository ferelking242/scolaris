# Déployer l'Edge Function `record-online-payment`

Cette fonction enregistre un **paiement en ligne demandé par une famille**
(élève / parent). Les familles sont en **lecture seule** sur `payments` (policy
`family_readonly_ins`) — sans cette fonction, le bouton « Payer en ligne » côté
élève/parent échoue avec `42501 new row violates row-level security policy`.

À déployer **une fois** ; ensuite le paiement en ligne famille fonctionne (offres
avec paiement en ligne). L'offre simple ne propose pas le paiement en ligne : la
famille règle **à la caisse** et l'admin encaisse (l'écriture staff est autorisée).

## Option A — Tableau de bord Supabase (sans CLI, le plus simple)
1. Dashboard → **Edge Functions** → **Create a function**.
2. Nom : `record-online-payment`.
3. Colle le contenu de `index.ts` (ce dossier).
4. **Deploy**.

Les variables `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
sont **injectées automatiquement** — rien à configurer.

## Option B — CLI
```bash
supabase functions deploy record-online-payment --project-ref iaxwvgqusxyhmyansawi
```

## Vérifier
Dans l'app, connecté en **parent** ou **élève** (école Pro/Max, avec une grille de
frais et au moins un versement déjà enregistré à la caisse) :
- Page **Paiements** → **Payer la scolarité en ligne** → montant → **Payer** →
  plus d'erreur RLS ; le compte se met à jour (payé qui monte, statut « à jour »).

## Sécurité
- L'appelant doit être **authentifié**.
- Il doit être **l'élève lui-même** ou un **parent lié** (`parent_student`) à
  l'élève de la facture — sinon `403`.
- Le versement ne peut pas **dépasser le reste dû** de la facture.

## ⚠️ État actuel — SIMULATION
Tant que l'**agrégateur Mobile Money n'est pas branché**, la fonction écrit le
versement **sur simple demande** (pas de preuve d'encaissement réel). En
production, l'insert ne doit se faire **qu'après confirmation de l'opérateur**
(webhook agrégateur) — voir le `TODO agrégateur` dans `index.ts`. Ne pas
considérer cet endpoint comme un vrai encaissement avant ce branchement.
