# Reçus d'abonnement Scolaris (SaaS : l'école paie Scolaris)

Chantier : fournir à l'école un **reçu imprimable** à chaque paiement de son
abonnement Scolaris, avec un **historique ré-téléchargeable**.

À ne pas confondre avec la facturation des élèves (frais de scolarité,
`AdminBillingPage`) : ici l'**émetteur est Scolaris** et le **client est l'école**.

---

## Décisions prises

| Sujet | Choix |
|-------|-------|
| Persistance | **Oui** — chaque paiement est archivé en base → reçu ré-imprimable et historisé |
| Émetteur du reçu | **Scolaris** (coordonnées légales à compléter) |
| Livraison | **In-app d'abord** : téléchargement immédiat + historique. E-mail auto = **plus tard** (Edge Function + Resend/SMTP, quand le vrai agrégateur de paiement sera branché) |

---

## Ce qui a été fait

### 1. Base de données
- Constat : la table `subscription_payments` **existe déjà** (migration
  `20260617_subscriptions.sql`, volontairement conservée par
  `20260730_prune_dead_tables.sql` — « fait partie du modèle des abonnements,
  le prochain chantier »). Pas besoin de la créer.
- **Nouvelle migration** : `supabase/migrations/20260715_subscription_receipt.sql`
  — ajoute 3 colonnes pour rendre chaque reçu **auto-porteur** (l'offre peut
  changer ensuite) :
  - `plan_code` (offre payée, figée)
  - `period` (`monthly` | `annual`)
  - `credit_applied` (crédit prorata/report déduit ; prix plein = `amount + credit_applied`)
  - Idempotent (`add column if not exists`).

### 2. Source de données — `lib/data/sources/remote/supabase_db_source.dart`
- Modèle `SbSubscriptionPayment` (+ helpers `fullPrice`, `isYearly`, `date`).
- `recordSubscriptionPayment(...)` — insère le versement (statut `success`,
  `paid_at` = maintenant, référence auto-générée type `SCO-AAAAMM-XXXX…`) et
  renvoie la ligne créée.
- `getSubscriptionPayments(schoolId)` — historique récent → ancien.

### 3. Reçu PDF — `lib/shared/pdf/subscription_receipt_pdf.dart` (nouveau)
- **Design épuré type facture Stripe / Anthropic** (calqué sur le reçu Anthropic
  fourni en référence) : **noir sur blanc, zéro couleur** sauf le wordmark
  « Scolaris » (une seule touche terracotta). Émetteur/client **inversés** vs
  `invoice_pdf.dart` (Scolaris = vendeur, école = client).
- Police **Noto Sans** (accents). Structure :
  - Titre **« Reçu »** + wordmark ; métadonnées (N° de reçu, date de paiement,
    période couverte).
  - Blocs **émetteur (Scolaris)** / **« Facturé à » (école)** en deux colonnes.
  - Montant mis en avant **« X payé le … »**.
  - **Bloc « infos »** (équivalent adapté du texte Anthropic) : mode de paiement
    + « paiements électroniques » + contact support. Emplacement réservé à une
    **mention fiscale** (`_Issuer.legalNote`, **vide par défaut** — on n'imprime
    pas de mention fiscale fausse).
  - **Tableau** Description / Qté / Prix unitaire / Montant ; le **crédit = ligne
    négative** (« Crédit / prorata reporté  − X »), comme le « Unused time » d'Anthropic.
  - Totaux **Sous-total / Total / Montant payé** ; footer « Page 1 sur 1 ».
- Choix retenus vs référence : **un seul** n° (reçu), **pas** de section
  « Historique des paiements » (redondant avec le panneau in-app).
- `Printing.layoutPdf` → boîte système enregistrer/imprimer (téléchargement).
- Document « papier » (blanc), non soumis au mode sombre.
- ⚠️ Coordonnées légales Scolaris (`_Issuer`) = placeholder + `TODO` à compléter.

### 4. Providers — `lib/presentation/providers/db_providers.dart`
- `subscriptionPaymentsProvider` (liste des versements de l'école courante).

### 5. UI — `lib/features/admin/presentation/pages/admin_subscription_page.dart`
- `_pay()` : après activation, **enregistre le versement** puis SnackBar vert
  avec une action **« Reçu »** (télécharge le PDF).
- Nouveau panneau **« Historique de facturation »** : chaque ligne = date,
  offre, période, montant, crédit éventuel + bouton ⬇️ pour **re-télécharger**
  le reçu.

---

## Fichiers touchés

| Fichier | État |
|---------|------|
| `supabase/migrations/20260715_subscription_receipt.sql` | créé |
| `lib/shared/pdf/subscription_receipt_pdf.dart` | créé |
| `lib/data/sources/remote/supabase_db_source.dart` | modifié |
| `lib/presentation/providers/db_providers.dart` | modifié |
| `lib/features/admin/presentation/pages/admin_subscription_page.dart` | modifié |

`flutter analyze` sur les fichiers touchés : **0 erreur** (seul un `info`
pré-existant sans rapport subsiste).

---

## Reste à faire

1. **⚠️ Exécuter la migration** dans Supabase Dashboard → SQL Editor.
   **Sans elle, `recordSubscriptionPayment` échoue** (colonnes absentes) —
   l'activation marche encore, mais pas l'enregistrement/l'historique.
2. **Coordonnées légales Scolaris** dans `_Issuer` (raison sociale, adresse,
   n° fiscal/RCCM) — `TODO` + e-mail placeholder laissés.
3. **E-mail automatique du reçu** : reporté (Edge Function + service d'envoi).
4. **Paiement réel** : le paiement est encore **simulé** (démo, agrégateur non
   branché) ; le jour venu, seule la confirmation opérateur change.

---

## Comment tester

1. Jouer la migration (voir ci-dessus).
2. `flutter run -d windows` (ou `-d chrome`).
3. Se connecter en **admin** (permission `schoolConfig`).
4. Menu **« Mon abonnement »** (icône ⭐) → **Choisir une offre** → régler
   Mensuel/Annuel → **Payer** → SnackBar « Offre activée ! » → action **« Reçu »**.
5. Vérifier le panneau **« Historique de facturation »** + re-téléchargement ⬇️.

Points de contrôle : accents corrects dans le PDF, calcul
*Prix − Crédit = Payé* juste, historique qui se remplit après paiement.
