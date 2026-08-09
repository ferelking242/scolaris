---
name: business-model
description: Modèle économique de Scolaris — SaaS B2B, 4 offres (Essentiel/Croissance/Complet/Entreprise), académique inclus + modules complémentaires
metadata:
  type: project
---

Scolaris est commercialisé en **SaaS B2B** : l'**école paie** l'abonnement (usage inclus pour tous ses élèves/parents). Marché initial : **Congo / Afrique centrale (FCFA/XAF)**, avec objectif d'**expansion multi-pays** (garder les mêmes offres, ne varier que la grille de prix par pays/devise → `prix = f(offre, palier, pays)`).

⚠️ **Modèle refondu le 09/08/2026** (conversation "business plan") — remplace toute version antérieure de ce fichier (l'ancien modèle Simple/Pro/Max à 14 900/29 900/59 900 avec gating par fonctionnalité pure n'a jamais été le modèle final déployé). Voir [[offers-and-gating]].

**Académique (notes, bulletins, emploi du temps, statistiques de classe) est le socle du produit — toujours inclus dans TOUTES les offres**, plus un module qu'on choisit ou compte. Les offres se distinguent par le nombre d'**emplacements de modules complémentaires** (Finances / Présences / Inscriptions) débloqués, façon catalogue "app store" (installer/désinstaller depuis `AdminSubscriptionPage`).

**4 offres** (prix Congo/XAF, mensuel — annuel = ×10, soit 2 mois offerts) :
- **Essentiel** — 15 000 F/mois, 200 élèves inclus, 0 emplacement de module complémentaire.
- **Croissance** — 35 000 F/mois, 500 élèves inclus, 1 emplacement au choix (Finances/Présences/Inscriptions).
- **Complet** — 65 000 F/mois, 1 500 élèves inclus, les 3 emplacements + Rapport Premium.
- **Entreprise** — sur devis (à partir de ~150 000 F/mois, jamais affiché en dur), illimité, multi-établissements, marque blanche, API, support dédié. Pas de paiement en libre-service : bouton "Nous contacter" (WhatsApp) au lieu du flux Mobile Money habituel.

**Achat à la carte d'un emplacement supplémentaire** : 15 000 F/mois (cohérence volontaire avec le prix Essentiel — "un module de plus"), indépendant du plan choisi (même Essentiel peut en acheter, plafonné). N'active PAS un changement d'offre — augmente juste `subscriptions.extra_module_slots`.

**Suppléments de taille** au-delà des élèves inclus : paliers par offre dans `plan_size_surcharges`, purement informatifs pour l'instant (facturation manuelle, pas de prélèvement auto).

**Paiement 100% manuel** (pas d'agrégateur/API) : l'école envoie l'argent via Mobile Money (MTN/Airtel) vers un numéro marchand Scolaris, saisit la référence reçue par SMS, un super-admin vérifie sur le relevé marchand et confirme (`platform_confirm_subscription_payment`) — RIEN ne s'active avant cette vérification. Essai gratuit 14 jours, sans CB.

**Cycle de vie automatisé** (`refresh_subscription_statuses()`, cron horaire pg_cron) : trial→expired à l'échéance, active→past_due à la fin de période, past_due→expired après 7 jours de grâce. Un abonnement hors règle passe en **lecture seule côté serveur** (triggers `enforce_subscription_active*` sur ~40 tables + policies), pas juste à l'affichage.

Toutes les migrations business/pricing de ce chantier : `backup/migrations_archive/20260809_*.sql` (module_marketplace, module_slot_addon, lifecycle_fixes, enforce_subscription_rls[_indirect], new_pricing_entreprise). Détail technique complet dans [[offers-and-gating]].
