# Scolaris — Feuille de route de construction

> Document de référence unique. On suit les phases **dans l'ordre**, une étape à la fois, chacune testable. Cocher au fur et à mesure.
> Logique détaillée dans la mémoire projet : `memory/offers-and-gating.md`, `accounts-and-access.md`, `distribution-and-whitelabel.md`, `business-model.md`, `backend-state.md`.

---

## ✅ DÉJÀ FAIT (socle)
- [x] Nettoyage base de données (63 → 30 tables) — passes 1/2/3
- [x] Identité unifiée sur `users` (suppression `profiles`/`students`)
- [x] Multi-tenancy : filtrage app + **RLS vérifiée** (isolation par école étanche)
- [x] Module abonnement : tables `plans`/`plan_prices`/`subscriptions`/`subscription_payments` + page « Mon abonnement »
- [x] Essai gratuit = offre **Simple**
- [x] Dialogues lisibles (thème)
- [x] **Logique produit entièrement cadrée** (offres, gating, comptes, white-label, distribution)

---

## PHASE A — Fondations écriture & comptes
*Prérequis de tout le reste. Pose aussi la sécurité.*
- [x] **A1. Couche d'écriture CRUD** — pattern établi : `createStudent` + invalidation des providers (UI se rafraîchit). *(Étape 0)* — méthodes update/delete à étendre par entité au fil des pages.
- [~] **A2. Edge Function « création de comptes »** — ✅ fonction `supabase/functions/create-account` (modes `create` = nouveau compte confirmé via trigger ; `link` = login sur fiche existante via `auth_uid`, sans doublon) · ✅ sécurité (appelant admin/staff, école déduite du profil) · ✅ **clé `service_role` retirée du client** · ✅ B3 (invitation) basculé dessus · ✅ B4 (activer l'accès élève/parent) branché ; ⚠️ **à déployer** (voir `functions/create-account/DEPLOY.md`) avant de tester.
- [ ] **A3. Garde-fou limite d'élèves** — brancher le trigger base `school_can_add_student` (déjà écrit) + vérif côté app.

## PHASE B — Page Utilisateurs *(Étape 1 — la plus centrale)*
*Rôles + restriction de plan + création de comptes.*
- [~] **B1. CRUD fiches élèves** + **limite de plan** — ✅ **créer** (users+student_profiles) · ✅ **modifier** (`updateUser`) · ✅ **désactiver/réactiver** (`setUserActive`, libère un slot) · ✅ **limite plan** (vérif app `canAddStudent`) ; ⏳ garde-fou trigger base (A3) · ⏳ affecter à une classe (dépend de la Phase C)
- [x] **B2. Création élève + parent combinée** — ✅ à l'inscription, si un tuteur est saisi (nom/tél/email/relation), sa fiche parent est créée (ou **réutilisée** si même tél/email dans l'école) et reliée via `parent_student`. `createStudent` renvoie l'id ; `createOrLinkGuardian` gère réutilisation + lien.
- [x] **B3. Comptes profs/staff** — ✅ dialogue « Inviter » fonctionnel : `signUp` (client secondaire, ne casse pas la session admin) + métadonnées {role, school_id, full_name} → trigger `handle_new_user` crée la ligne `public.users`. Rôles : teacher/finance/surveillance/staff_custom/admin (enum `user_role`). ⚠️ Supabase exige confirmation email + refuse certains domaines (ex. `@ead-bzv.cg`) → l'Edge Function (A2) créera des comptes pré-confirmés plus tard.
- [~] **B4. Login élève optionnel** — ✅ via A2 : bouton **clé « Activer l'accès »** sur élève/parent encore en fiche (gated Pro/Max), dialogue email+mot de passe → `enableUserLogin` (lie `auth_uid`). Badge **cadenas vert** = connexion active. ⏳ défaut auto selon niveau + QR ; ⚠️ dépend du déploiement de la fonction.
- [~] **B5. Gating rôles par offre** — ✅ en **Simple** : aucune fiche **parent** créée à l'inscription (gardée Pro/Max via `familyAccountsEnabledProvider`) · invitation limitée à **Enseignant + Direction/Admin** (finance/surveillance/secrétariat = Pro/Max, avec note). ⏳ login élève (dépend de B4) ; ⏳ gating modules/nav = E1.

## PHASE C — Structure académique *(Étape 2)*
- [~] **C1. CRUD Classes** — ✅ **créer** (niveau choisi depuis `class_levels` francophone primaire/collège/lycée — jamais en dur, **`level_id` stocké** → série + classe d'examen connues) · ✅ **modifier** ; ⏳ archiver/supprimer
- [~] **C2. CRUD Matières** — ✅ page/nav Matières · ✅ **créer/modifier/supprimer** · ✅ **« Charger les matières types »** (catalogue `subject_catalog` par cycle, pré-rempli) ; ⏳ coefficients par série → reportés aux bulletins (table `class_subjects` à recréer alors)
- [~] **C3. Affectations** — ✅ **élèves↔classes** (gestionnaire d'effectif via bouton 👥 : ajouter/retirer, un élève = une classe) ; ⏳ profs↔classes/matières (avec `class_subjects`, au moment des bulletins)

## PHASE D — Vie scolaire & contenus *(Étapes 3→7)*
- [~] **D1. Tableau de bord réel** — ✅ KPI réels (élèves/classes/profs/matières) · ✅ feed « dernières inscriptions » réel · ✅ **actions rapides qui naviguent** (via `navIntentProvider` écouté par les 2 shells) ; ⏳ agenda « Aujourd'hui » (dépend de D5 emploi du temps)
- [ ] **D2. Notes & bulletins** (carnet de notes prof → bulletins)
- [ ] **D3. Présences / absences** réelles
- [~] **D4. Notifications / Annonces** — ✅ **publier** une annonce réelle (table `announcements` : priorité normal/important/urgent, cible tous/élèves/profs/parents/par classe avec vraies classes) · ✅ **historique réel** (auteur, date, suppression) ; ⏳ push natif (Phase G4) · ⏳ gating Pro+
- [~] **D5. Emploi du temps** — ✅ table `schedules` recréée (RLS) · ✅ page admin réelle (sélecteur de classe → cours par jour : matière + prof + horaire + salle, ajout/suppression) ; ⚠️ migration `20260617_schedules.sql` à lancer · ⏳ vue élève (`student/.../schedule_page.dart`) encore mock
- [~] **D6. Inscriptions (config)** — ✅ persistée en base (`schools.enrollment_config` jsonb : la page charge au démarrage + sauvegarde réelle) ; ⚠️ nécessite la migration `20260617_enrollment_config.sql`
- [~] **D-Facturation (scolarité)** — ✅ lecture réelle (encaissé/attente/retard) · ✅ **créer une facture** (par élève, catégorie, montant) · ✅ **encaisser** (paiement espèces → facture payée) · ✅ supprimer ; ⏳ paiement en ligne (Mobile Money) = simulation en attendant les agrégateurs · ⏳ barème par classe (génération en masse)
- [~] **D7. Rapports basiques + exports** — ✅ rapports réels (indicateurs clés, finances/recouvrement, **effectifs par classe** avec barre de remplissage, élèves sans classe) · ✅ **export CSV** (copie presse-papier, collable Excel/Sheets) ; ⏳ vrai fichier PDF/Excel (nécessite un package : `pdf`/`csv`/`share_plus`) *(Pro)*

## PHASE E — Monétisation & offres
- [ ] **E1. Verrouillage par offre** — tag `minPlan` dans `features_catalog.dart` + brancher nav / hub / création de comptes *(Étape 8)*
- [ ] **E2. White-label dynamique** — charger `schools.accent_color`/`logo_url` par école (corriger `_fetchProfile`)
- [~] **E3. Paiement Mobile Money** — ✅ bouton « Choisir une offre » branché : dialogue mensuel/annuel (2 mois offerts) + paiement **SIMULÉ** → `activateSubscription` passe l'abo en `active` (rafraîchit usage + gating paiement en ligne) ; ⏳ remplacer la simulation par le vrai agrégateur (MTN MoMo / Airtel)
- [ ] **E4. Cycle de vie abonnement** — essai → expiration (blocage/lecture seule) → renouvellement

## PHASE F — Sécurité & rôles fins
- [ ] **F1. Permissions intra-école par rôle** (RLS niveau 2 + `PermissionService` — ex. élève ne modifie pas une note) *(Étape 9)*
- [ ] **F2. Audit sécurité final** (service_role retiré, RLS complète, inscription durcie) *(Étape 10)*

## PHASE G — Distribution & lancement
- [ ] **G1. Déploiement Web app** (admin + profs + inscription) — canal principal
- [ ] **G2. PWA mobile** (parents/élèves, installable sans store)
- [ ] **G3. Mini site vitrine** (offres + bouton S'inscrire) *(reporté)*
- [ ] **G4. Apps natives** Play Store / App Store *(plus tard ; push natif)*

## PHASE H — Premium Max *(plus tard, sur demande client)*
- [ ] **H1. Multi-établissement** (couche « groupe scolaire » + sélecteur) — brique de base déjà là
      (`school_members` en base, `SchoolSwitcher` fonctionnel mais un-à-la-fois, visible seulement dans
      `teacher_home.dart`). Reste à faire : (1) RLS/RPC dédiée pour qu'un fondateur lise les données de
      *ses* écoles uniquement (sur le modèle de `platform_admin_read_*`, mais scopée à `school_members`/
      `school_founders` au lieu de « toutes les écoles ») ; (2) écran dashboard consolidé (effectifs,
      abonnements, stats sommés) réutilisant la logique d'agrégation de `PlatformRepository.getSchools()`
      sans le réserver au super-admin interne ; (3) détecter le fondateur multi-écoles (>1 ligne
      `school_members`) pour afficher l'entrée de menu. Ne pas confondre avec `lib/features/platform/` =
      console interne Scolaris (accès par email whitelist `platform_admins`), pas un module client.
- [ ] **H2. Base dédiée** (provisioning manuel, routage via `db_mode`/`db_config`)
- [ ] **H3. Accès API** (clés par école, doc)
- [ ] **H4. Mode hors-ligne** (cache local + synchro)
- [ ] **H5. Analytics avancées** (tendances, comparaisons multi-écoles)
- [ ] **H6. White-label avancé** (sous-domaine brandé, PWA à leur nom, app native bespoke)

---

### Ordre d'attaque
On suit A → B → C → … On commence par **Phase A**, puis **Phase B**. Les Phases E/F se font une fois les pages en place. Phase G = quand le produit est utilisable. Phase H = sur demande, après le lancement.
