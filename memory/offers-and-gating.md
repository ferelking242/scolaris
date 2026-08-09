---
name: offers-and-gating
description: Mécanique exacte du gating par offre — Académique toujours inclus, quota de modules complémentaires, emplacement à la carte, blocage RLS
metadata:
  type: project
---

⚠️ Réécrit le 09/08/2026 — remplace toute version antérieure (l'ancien modèle à 3 offres Simple/Pro/Max avec feature-gating pur, prix 14 900/29 900/59 900, n'a jamais été le modèle final déployé). Voir [[business-model]].

**Deux mécanismes de gating distincts, ne pas confondre :**
1. **`minPlan` dans `features_catalog.dart`** (`AppFeature.minPlan`, `PlanGate`/`planMeetsRequirement` dans `plan_gate.dart`) — gate app-level historique par fonctionnalité (ex. `messaging`, `library` = `minPlan: 'pro'`), hiérarchie `simple(0) < pro(1) < max(2) < entreprise(3)`.
2. **Quota de modules complémentaires** (le vrai mécanisme actif pour Académique/Finances/Présences/Inscriptions) — `plans.max_modules` en base, catalogue "app store" dans `AdminSubscriptionPage` (`_ModulesPanel`), `kAppModules` (3 modules complémentaires — Académique n'y est plus, c'est `kCoreModule`, toujours actif).

**Quotas par offre** (`plans.max_modules`) : Essentiel = 0, Croissance = 1, Complet = 3, Entreprise = 99 (pas de vrai plafond, catalogue actuel n'a que 3 modules). Quota EFFECTIF = `max_modules + subscriptions.extra_module_slots` (emplacements achetés à la carte, 15 000 F/mois, table `subscription_payments.payment_type = 'addon_slot'`).

**Downgrade** : `platform_confirm_subscription_payment` retire automatiquement les modules complémentaires excédentaires de `schools.metadata.modules` quand le nouveau plan a un quota plus bas — priorité de conservation Finances > Présences > Inscriptions.

**Garde-fous serveur** (pas que client-side) :
- `trg_enforce_school_module_quota` sur `schools` : bloque toute écriture de `metadata.modules` qui dépasserait le quota effectif de l'offre en cours.
- `enforce_subscription_active()` + variantes (`_via_fk`, `_submitted`, `_self`) : bloquent INSERT/UPDATE sur ~40 tables (direct `school_id`, jointure à 1 niveau, ou `submitted_by_school_id`) quand `subscription_is_active(school_id)` = false. Lecture jamais bloquée. Bypass `is_platform_admin`. Exclut volontairement `subscriptions`/`subscription_payments` (doivent rester payables même hors règle) et les catalogues globaux plateforme (`plans`, `plan_prices`, `class_levels`, `subject_catalog`, `permission_catalog`, `sub_permission_catalog`, `role_templates`, `role_template_permissions`).

⚠️ **Découverte du 09/08/2026** : `supabase/migrations/20260733_enforce_subscription.sql` décrit un système RLS antérieur, plus élaboré (policies RESTRICTIVE, `school_has_feature()` avec héritage d'offre, blocage des comptes élève/parent en offre Simple via `guard_family_portal`) — **jamais appliqué en base** (absent de `backup/migrations_archive/`, donc jamais exécuté malgré sa présence dans `supabase/migrations/`). Incompatible avec le schéma `plans.features` actuel (clés différentes : `academique_inclus` etc. vs `finance`/`portail_parents`). À NE PAS appliquer tel quel — écraserait `subscription_is_active()` par une version sans grâce de 7 jours, et bloquerait tous les logins élève/parent en offre Essentiel si jamais réactivé sans adaptation. Piège classique "le repo n'est pas la source de vérité" (cf. [[verify-db-before-changing]]).

**Modules complémentaires actuels** (`kAppModules`, chacun 1 emplacement) : `attendance` (Présences), `finance` (Finances), `enrollment` (Inscriptions). Futurs candidats identifiés mais NON construits (décision explicite de ne rien construire de neuf pour l'instant) : Communication (messagerie/liaison/annonces/réunions), Bibliothèque, Évaluations en ligne, Discipline, Documents officiels, module vertical Enseignement Supérieur (ECTS/UE/stages/alumni — condition : `SchoolLevel` universitaire+).

**Paiement** : 100% manuel (Mobile Money, vérification humaine), cf. [[business-model]]. Cycle de vie automatisé par cron (`refresh_subscription_statuses`), read-only serveur réel (voir garde-fous ci-dessus) — ces deux points comblent un trou où le statut affiché à l'école pouvait mentir indéfiniment et où le blocage "lecture seule" n'existait qu'à l'écran.
