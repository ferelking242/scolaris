---
name: admin-build-roadmap
description: Feuille de route de construction pour rendre l'admin fonctionnel (étapes 0→10), à résoudre une par une
metadata:
  type: project
---

Plan validé juin 2026 : « tout gérer proprement, mais petit à petit ». À résoudre **étape par étape**, chacune testable. **Checklist maître à jour = `docs/ROADMAP.md`** (phases A→H avec cases à cocher) — s'y référer en priorité. Voir [[offers-and-gating]], [[accounts-and-access]], [[distribution-and-whitelabel]].

**Constat de départ** : les pages admin LISENT la base mais ne savent pas ÉCRIRE (le data source n'a quasi que des méthodes de lecture). 10 pages admin (Dashboard, Utilisateurs, Classes, Inscriptions, Facturation, Mon abonnement✅, Rapports, Emploi du temps, Notifications, Hub). Rôles : 7 en base (`student/parent/teacher/admin/staff_custom/surveillance/finance`), regroupés en 4 buckets app (`UserRole`: staff/teacher/student/parent), le staff piloté par `PermissionService`. Types d'école (8) + systèmes (5) captés à l'inscription + catalogue `class_levels` (302 niveaux) **pas encore exploité** hors inscription.

**Fondation**
- **Étape 0 — Couche d'écriture** : socle CRUD (insert/update/delete dans SupabaseDbSource) + invalidation des providers pour rafraîchir l'UI. Prérequis de tout.

**Pages, une par une**
- **Étape 1 — Utilisateurs** (la plus centrale) : CRUD élèves/profs/parents/staff. Y vivent **les rôles** ET **la restriction de plan** (limite élèves : UI + trigger base). Y intégrer la logique [[accounts-and-access]] (fiche vs accès, login élève optionnel, création élève+parent combinée) et l'**Edge Function** de création serveur (qui retire `service_role` du client). Gating : pas de parents/login-élève en Simple.
- **Étape 2 — Classes & Matières** : CRUD, **type-aware** (piocher dans `class_levels` selon le système de l'école). Liens élèves↔classes, profs↔classes.
- **Étape 3 — Tableau de bord** : vrais chiffres (effectifs, activité) au lieu du mock.
- **Étape 4 — Inscriptions (config)** : persistance réelle en base.
- **Étape 5 — Notifications / Annonces** : vraies annonces (table `announcements`). [Pro+]
- **Étape 6 — Emploi du temps** : ⚠️ nécessite de recréer une table propre (`schedules` avait été supprimée au nettoyage).
- **Étape 7 — Rapports / Bulletins** : agrégations réelles, bulletins adaptés au type d'école. (Rapports basiques = Pro.)

**Couches transversales (après les pages)**
- **Étape 8 — Verrouillage par offre** : tagger les features (`minPlan`) dans `features_catalog.dart`, brancher nav + hub + création de comptes. Voir [[offers-and-gating]].
- **Étape 9 — Permissions par rôle** : autorisation intra-école (RLS niveau 2 + `PermissionService`) — ex. élève ne modifie pas une note.
- **Étape 10 — Sécurité** : retirer la clé `service_role` du client (réglé en partie par l'Edge Function de l'étape 1). + corriger le thème white-label (`schools.accent_color`, voir [[distribution-and-whitelabel]]).

**Plus tard** : Paiement Mobile Money (le bouton « Choisir une offre » est un stub) ; features 🟧 infra (multi-établissement, base dédiée, API, hors-ligne) ; apps natives stores.

---

## ÉTAT au 19 juin 2026 (fin de session)

**MIGRATIONS SQL — ✅ TOUTES APPLIQUÉES (vérifié le 19 juin 2026 via diagnostic information_schema/pg_constraint/pg_trigger)** : credit_balance, school_classes.branch_id, grades.id default + grades_unique, trg_enforce_student_limit, users.permissions, users.role_title. Les 6 fichiers `20260618_*.sql` sont en base. Rien à relancer.

**FAIT cette session :**
- **Inscription** (`school_registration_screen.dart`) : université / formation pro / grandes écoles / éducation spéc. → grisés « Bientôt » (non sélectionnables) ; option « Base personnalisée » → « Bientôt » (code mort `_TypeChip`/`_testDbConn` supprimé). Seuls primaire/collège/lycée actifs.
- **Gating par offre — complet** : `currentPlanCodeProvider`, bannières `PlanGate`/`PlanGateBanner` sur users/billing/notifications/reports ; `minPlan` ajouté à `AppFeature` + badges 🔒 dans Features Hub ; page abonnement liste les features par offre + barre d'usage corrigée ; **bannière d'expiration globale** `SubscriptionAlertBanner` (2 shells, gate admin sur mobile) ; limite d'élèves : vérif app à l'ouverture ET au save + trigger base.
- **Type d'école → cycles** : `SbSchool.cycles` (depuis metadata.types), `schoolCyclesProvider` filtre `classLevelsProvider` + `subjectCatalogProvider`. Le comportement par cycle (bulletin /10 vs moyennes+coef, séries lycée) se décide **par classe**, en aval (côté élève/parent surtout) — PAS encore fait.
- **Notes & Bulletins ADMIN** : nouvelle page `admin_grades_page.dart` (supervision toutes classes : moyennes/mentions par élève + bulletin détaillé imprimable via `PrintService`). Branchée nav (`nav.grades`). Réutilise gradebook prof + bulletin élève.
- **RBAC personnel (étapes 1-7 du chantier rôles)** : modèle par capacités complet — voir [[accounts-and-access]] (détails techniques). Menu dynamique + écran de gestion (presets + cases) + gardes par page.

**RESTE À FAIRE (pistes pour la prochaine session) :**
- **Bulletins/moyennes par cycle** côté **élève/parent** (le type d'école prend son sens là) — primaire (notes/10, appréciations) vs collège/lycée (moyennes+coefficients+séries).
- `student_payments_page.dart` = encore **100% mock** → brancher sur les vraies factures (comme `parent_payments_page` qui utilise `online_payment_sheet`).
- Module `finance/` (`FinanceHome`) existe mais **non routé** — à supprimer ou intégrer (redondant avec le RBAC : un staff `finance` voit déjà Facturation).
- Paiement Mobile Money réel (aujourd'hui simulation, bandeau « Démo », ref `SIM-*`).
- Optionnel : RLS base par capacité (le gating staff est app-level, comme les features).
- **Tester le RBAC de bout en bout** après migration : créer un « Comptable » (Finances+Rapports), se connecter, vérifier menu réduit + garde.

**On démarre par Étape 0 + Étape 1 (Utilisateurs).** *(Étapes 1, 7, 8 du plan d'origine désormais largement couvertes.)*
