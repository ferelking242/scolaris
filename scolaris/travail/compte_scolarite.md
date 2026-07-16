# Compte de scolarité (solde qui court + cascade des versements)

Chantier : remplacer la **pile de factures mensuelles** de scolarité par un
**compte unique par élève** — un solde qui court sur l'année, où chaque versement
**descend en cascade** sur les mois les plus anciens impayés.

À ne pas confondre avec les reçus d'abonnement Scolaris (`recus_abonnement_scolaris.md`) :
ici l'**émetteur est l'école** et le **client est l'élève / le parent**.

---

## Le problème de départ

Facture **manuelle** et facture **automatique** (tranches mensuelles) entraient en
**concurrence** : un élève avait déjà ses tranches générées, venait payer à l'école,
l'admin créait une facture manuelle en plus… et on ne savait plus s'il avait payé.
En prime, générer 9 tranches d'avance et les envoyer au parent « paraissait bizarre
et on ne savait même pas s'il avait payé ».

## La règle métier retenue (validée)

- **Scolarité** (mensuel récurrent) → un **compte** annuel unique.
  Si la scolarité est 10K/mois sur 9 mois → l'élève doit **90K à l'année**.
  Chaque mois est une **échéance calculée** (pas une facture pré-générée).
- Un versement de **35K** = **3 mois et demi couverts** → l'élève est « à jour »
  sur cette période ; il reste 35K… non : il reste `90K − 35K` sur l'année, et le
  prochain mois dû réclame d'abord le **demi-mois** restant. C'est la **cascade**.
- **« À jour » ne se lit pas dans un statut, il se CALCULE** : versé ≥ dû à ce jour.
- **Frais ponctuels** (inscription, cantine, transport…) → restent des **factures**
  discrètes.

**Option retenue (A)** : **un seul compte annuel par élève** (une ligne `invoices`
de catégorie `tuition`, montant = total année). Le mensuel est un **échéancier
calculé**, on ne **pré-génère PAS** 9 lignes de facture.

---

## Ce qui a été fait

### 1. Base de données
- **Aucune migration.** Tout tourne sur des colonnes/tables **déjà présentes**
  (vérifié en direct via l'API REST) :
  - `invoices.category` (`tuition`), `invoices.period` (= l'année scolaire),
    `amount`, `status`.
  - table `payments` (`invoice_id`, `amount`) → **paiements partiels**.
  - `fee_structures` (`class_id`, `amount_per_period`, `periods_count`, `is_active`).

### 2. Source de données — `lib/data/sources/remote/supabase_db_source.dart`
- **Paiements partiels** : `SbInvoice` gagne `amountPaid` (somme des `payments`
  embarqués), + getters `balance`, `isPartiallyPaid`. `recordPayment` recalcule le
  cumul et ne passe `paid` que si le solde est couvert.
- **Bug corrigé** : `isLate` (impayé + échéance dépassée) est **calculé** — le
  statut `overdue` n'était **jamais écrit** en base.
- **Modèle compte** : `SbTuitionPeriod` + `SbTuitionAccount` (getters `annual`,
  `dueToDate`, `balance`, `owedNow`, `isUpToDate`, `credit`, `periodsCovered`).
- `getTuitionAccount({studentId, schoolId, academicYear})` → `null` si pas de
  classe / pas de grille ; « payé » = cumul des versements sur les factures de
  scolarité (compte annuel **ou** anciennes tranches → lecture juste en transition).
- `tuitionAccountFrom(fee, paid)` — calcul **pur** (réutilisé par le calcul en lot).
- `_ensureTuitionAccount(...)` — crée/retrouve **une** facture annuelle `tuition`
  (période = année, **pas** de `due_date` : le retard se lit sur `owedNow`).
- `recordTuitionPayment(...)` — garantit le compte puis encaisse ; lève si pas de grille.

### 3. Providers — `lib/presentation/providers/db_providers.dart`
- `tuitionAccountProvider(studentId)` — le compte d'un élève.
- `tuitionAccountsProvider` — **tous** les comptes calculés **en lot** (1 requête
  factures + 1 requête grilles, au lieu d'une par élève).
- `guardiansForStudentProvider`, `childrenOfParentProvider` (fiches famille).

### 4. UI admin
- **`widgets/tuition_account.dart` (nouveau)** — `TuitionAccountCard` (payé/total,
  barre, chip **À jour / Doit X**, dû à ce jour, reste, couvert jusqu'à, crédit) +
  dialogue **« Encaisser un versement »** avec **aperçu d'affectation en direct**
  (« après ce versement → total payé / reste dû / couvert jusqu'à »).
  Carte réutilisable : admin (Encaisser), parent & élève (Payer en ligne).
- **`pages/tuition_accounts_page.dart` (nouveau)** — liste **Comptes scolarité** :
  synthèse (en retard / dû aujourd'hui / à jour), filtres, recherche, retards en
  haut, **Encaisser** par ligne.
- **`admin_billing_page.dart`** — bouton **« Comptes scolarité »** (sous-vue) ;
  buckets basés sur `amountPaid`/`balance`/`isLate` ; pastilles Partiel/Retard ;
  `_CollectDialog` (montant éditable). **Garde-fou** : **« Scolarité » retirée**
  des catégories de facture manuelle (défaut = Inscription) + renvoi vers
  « Comptes scolarité ».
- **`users_page.dart`** — fiche élève : panneau **Compte scolarité** ; vraie
  **fiche parent** + panneau **Famille** (tuteurs/enfants).

### 5. UI famille (la pile → le compte)
- **`parent_payments_page.dart`** — carte **Compte scolarité par enfant** ; le
  tableau ne garde que les **Autres frais** ; **« Payer la scolarité en ligne »**.
- **`student_payments_page.dart`** — bandeau résumé piloté par le **compte** ;
  **échéancier mensuel calculé** (Réglé / Partiel / En retard / À venir) au lieu
  d'une liste de tranches ; rappel « scolarité en retard » prioritaire ; section
  **Autres frais** séparée ; **repli** propre si pas de grille.

### 6. Paiement en ligne — `lib/shared/widgets/online_payment_sheet.dart`
- **Montant éditable** quand une seule facture (scolarité) → régler une tranche,
  un acompte, ou tout le solde ; part en **partiel** qui cascade sur le compte.
- **Défaut malin** = dû à ce jour (`suggestedAmount`).
- **Bug corrigé** : encaisse le **solde restant** (`balance`), plus le montant
  d'origine figé → fini le surpaiement d'une facture déjà entamée.
- Invalidation ciblée (comptes + listes) après paiement.

### 7. Fiche enfant (parent) — `child_detail_page.dart` + `child_payments_page.dart` (nouveau)
- **Bug corrigé** : la carte « Impayés » comptait la facture-compte annuelle
  (« pending » toute l'année) → **1 impayé permanent** même à jour. Remplacée par
  **« Scolarité »** pilotée par le compte : *À jour* / *Doit X* (repli sur le
  nombre d'impayés si pas de grille).
- **Nouvelle porte d'entrée** : tuile **« Scolarité & paiements »** (statut en
  sous-titre) → `ChildPaymentsPage` : le compte de l'enfant (+ payer en ligne) et
  ses autres frais. Avant, la fiche « porte d'entrée unique » ne liait à AUCUNE
  finance.

### 8. Paiement SERVEUR — Edge Function `record-online-payment` (nouveau)
- **Problème** : les familles sont en **lecture seule** sur `payments` (policy
  `family_readonly_ins`) → le paiement en ligne famille échouait
  (`42501 violates row-level security`). Normal : un parent ne doit pas pouvoir
  se déclarer « payé » sans payer.
- **`supabase/functions/record-online-payment/index.ts`** : vérifie que
  l'appelant est **l'élève ou un parent lié** (`parent_student`), contrôle le
  reste dû, puis **écrit le paiement côté serveur** (`service_role`) et met à jour
  le statut. + `DEPLOY.md`.
- Côté app : `recordOnlinePayment(...)` (appel de la fonction) ; la feuille
  Mobile Money **famille** l'utilise. L'**admin (caisse)** garde l'écriture
  directe (staff autorisé).
- Règle : **offre avec paiement en ligne → serveur** ; **offre simple → caisse**.
- ⚠️ **À DÉPLOYER une fois** (Dashboard → Edge Functions). Toujours **simulé**
  tant que l'agrégateur n'est pas branché (`TODO agrégateur` dans `index.ts`).

### 9. Liste des factures sur sa propre page — `admin_billing_page.dart`
- L'aperçu ne montre plus la grosse table : **stats (frais ponctuels)** + une
  **entrée cliquable** → sous-vue **« Factures ponctuelles »** (Encaisser /
  Supprimer / Nouvelle facture).
- **Scolarité exclue** de cette liste ET des stats (elle vit dans « Comptes
  scolarité ») → fini la ligne annuelle géante et l'« En attente » gonflé.

---

## Fichiers touchés

| Fichier | État |
|---------|------|
| `lib/features/admin/presentation/widgets/tuition_account.dart` | créé (+ titre/onPayOnline) |
| `lib/features/admin/presentation/pages/tuition_accounts_page.dart` | créé |
| `lib/features/parent/presentation/pages/child_payments_page.dart` | créé |
| `supabase/functions/record-online-payment/index.ts` (+ `DEPLOY.md`) | créé |
| `lib/data/sources/remote/supabase_db_source.dart` | modifié (+ `recordOnlinePayment`) |
| `lib/presentation/providers/db_providers.dart` | modifié |
| `lib/features/admin/presentation/pages/admin_billing_page.dart` | modifié (liste sur sa page) |
| `lib/features/admin/presentation/pages/users_page.dart` | modifié |
| `lib/features/parent/presentation/pages/parent_payments_page.dart` | modifié |
| `lib/features/parent/presentation/pages/child_detail_page.dart` | modifié (stat + tuile) |
| `lib/features/student/presentation/pages/student_payments_page.dart` | modifié |
| `lib/shared/widgets/online_payment_sheet.dart` | modifié (montant éditable + serveur) |
| `lib/shared/pdf/invoice_pdf.dart` | créé (reçu/facture PDF) |

`flutter analyze` sur les fichiers touchés : **0 erreur, 0 warning** (seuls des
`info` de style pré-existants — `withOpacity`, `prefer_const` — subsistent).

---

## À DÉPLOYER (sinon le paiement famille échoue)

**Edge Function `record-online-payment`** — Dashboard → Edge Functions → *Create*
→ nom `record-online-payment` → coller `index.ts` → Deploy. Détails dans son
`DEPLOY.md`.

## Reste à faire (reporté : « on commence petit / maj plus tard »)

1. **Créer le compte à la volée au paiement en ligne** — aujourd'hui le bouton
   « Payer en ligne » n'apparaît que si une facture-compte existe déjà (créée au
   1ᵉʳ versement, souvent à la caisse). Un élève jamais encaissé passe par la
   caisse en attendant.
2. **Générer la facture d'inscription** automatiquement depuis la grille.
3. **Cantine / transport** — laissés de côté volontairement.
4. **Agrégateur Mobile Money réel** — le paiement serveur existe mais **simule**
   encore (pas de confirmation opérateur ; `TODO agrégateur` dans la fonction).
5. **Supérieur** — si les étudiants n'ont pas de classe avec grille
   (fac par semestre/UE), le compte tombe en repli. Sujet **données**, pas code.

---

## Comment tester (bout en bout)

1. Une **école avec une grille de frais** (Facturation → Frais de scolarité) sur
   la classe d'un élève.
2. **Admin** → fiche de l'élève **ou** Facturation → **Comptes scolarité** :
   le compte s'affiche (payé / dû à ce jour / à jour).
3. **Encaisser** un versement partiel (ex. 35K) → le payé monte, le statut passe
   « à jour », l'échéancier se colore, un reçu est dispo.
4. **Parent / Élève** → page Paiements : voir la **carte compte** + l'**échéancier
   mensuel** ; si paiement en ligne actif, **Payer** avec **montant éditable**.

Points de contrôle : la cascade (35K ⇒ ~3,5 mois couverts), « à jour » calculé et
non stocké, aucune facture « Scolarité » manuelle possible, pas de surpaiement.
