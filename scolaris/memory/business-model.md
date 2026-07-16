---
name: business-model
description: Modèle économique de Scolaris — SaaS B2B abonnements 3 offres (Simple/Pro/Max)
metadata:
  type: project
---

Scolaris est commercialisé en **SaaS B2B** : l'**école paie** l'abonnement (usage inclus pour tous ses élèves/parents). Marché initial : **Congo / Afrique centrale (FCFA/XAF)**, avec objectif d'**expansion multi-pays** (garder les mêmes offres, ne varier que la grille de prix par pays/devise → `prix = f(offre, palier, pays)`).

**3 offres = différenciation par fonctionnalités** (pas par taille) :
- 🟢 **Simple** : socle pédagogique (élèves, classes, matières, notes/bulletins, présences, emploi du temps, rôles Admin+Enseignant).
- 🔵 **Pro** (offre phare) : Simple + Portail Parents, Messagerie & annonces, Module Finance (factures/paiements/reçus), Bibliothèque, QR, Surveillance, rapports.
- 🟣 **Max** : Pro + multi-établissements, personnalisation/marque blanche, hors-ligne complet, support dédié, export/API, analytics avancées.

**Prix = UN forfait fixe par offre** (modèle simplifié — PLUS de paliers S/M/L). Chaque offre a un prix unique + une limite d'élèves unique (FCFA/mois, Congo, indicatif) :
- Simple : **14 900** — jusqu'à **200** élèves
- Pro : **29 900** — jusqu'à **1 000** élèves
- Max : **59 900** — élèves **illimités**
Annuel = 10 mois payés (2 offerts), + 1 mois d'essai gratuit. (Prix indicatifs, déclinables par pays.)

**Enforcement limite** : au-delà de la limite d'élèves → **passage à l'offre supérieure** (bloquer la création de nouveaux élèves, existants intacts, message d'upsell, +5 % de tolérance possible). Vérif : `nbÉlèves < limiteOffre`, branchée sur le futur module d'abonnement.

Infographie des offres : `docs/offres-scolaris.svg` (+ `.png` généré via Edge headless).

**Placement du choix d'offre** : PAS d'étape "offre" dans le wizard d'inscription (zéro friction). L'inscription crée l'école en **essai gratuit** (`schools.plan_type = 'free'` par défaut — colonne déjà présente). Le directeur **choisit/paie son offre plus tard** dans une **page « Abonnement » du dashboard Admin** (à construire après avoir fini l'inscription à 100 %). Note : l'étape 4 du wizard (base `scolaris` centralisé vs base custom) est en réalité une fonctionnalité d'offre Max — à lier au `plan_type` plus tard.

**Pas d'offre gratuite permanente** (freemium) au lancement : les écoles ont un budget (B2B), le gratuit coûte cher en support/infra, convertit mal et peut dévaloriser. À la place : **essai gratuit 1 mois** (offre **Simple** débloquée — changé de Pro→Simple juin 2026, sans CB) + **offre pilote** pour les 5–10 premières écoles (-50 % la 1ʳᵉ année contre témoignage) + démo accompagnée. Un "Découverte" gratuit très limité (<30 élèves, fonctions Simple) reste envisageable plus tard comme entonnoir d'acquisition, mais pas maintenant.

**Module abonnement (17 juin 2026, en cours)** : `supabase/migrations/20260617_subscriptions.sql` crée `plans` (simple/pro/max, max_students 200/1000/null), `plan_prices` (multi-pays ; Congo XAF mensuel 14900/29900/59900, annuel ×10), `subscriptions` (1/école, statuts trial/active/past_due/canceled/expired), `subscription_payments`. EAD = essai Simple 30 j. Fonctions d'enforcement : `school_student_limit/count/can_add_student` (tolérance +5%). Côté app : modèles `SbPlan`/`SbPlanPrice`/`SbSubscription` + méthodes `getPlans/getPlanPrices/getSubscription/getStudentCount` (`supabase_db_source.dart`), providers `plansProvider/planPricesProvider/subscriptionProvider/studentCountProvider`, page Admin `admin_subscription_page.dart` (bannière statut, barre d'usage X/limite, 3 cartes d'offres) branchée dans `admin_home.dart` (nav `nav.subscription`). ⚠️ **SQL pas encore exécuté**. **Reste : paiement Mobile Money (le bouton "Choisir" est un stub), et le blocage dur à la création d'élève au-delà de la limite (phase 4).** Voir [[backend-state]].
