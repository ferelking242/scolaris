# Chantier : traduction i18n réelle (🔴 DÉMARRAGE — 158/165 fichiers en français en dur)

## Contexte / pourquoi ce fichier existe
L'utilisateur a remarqué que changer de langue dans le Profil ne change presque rien à
l'affichage. Diagnostic (2026-07-28) : le mécanisme `easy_localization` fonctionne bien
techniquement (le choix persiste en `SharedPreferences`, `context.setLocale()` marche), mais
**quasiment aucun écran n'utilise de clé de traduction**.

Grep `\.tr()` sur tout `d:/scolaris/lib` (165 fichiers `.dart`) → seulement **7 fichiers** l'utilisent :
- `lib/features/auth/presentation/login_screen.dart`
- `lib/shared/desktop_shell/desktop_shell.dart`
- `lib/shared/mobile_shell/curved_drawer.dart`
- `lib/shared/mobile_shell/mobile_shell.dart`
- `lib/shared/widgets/dashboard_scaffold.dart`
- `lib/shared/widgets/placeholder_page.dart`
- `lib/shared/widgets/role_badge.dart`

Tout le reste (les 158 autres fichiers, tout le contenu réel des pages : titres de section,
labels, messages, boutons...) est écrit en texte français **en dur** dans le code Dart. Changer
la langue ne peut donc rien y faire.

## Décision utilisateur
Pas de gros chantier d'un coup. **On traduit petit à petit**, au fur et à mesure qu'on retravaille
un fichier pour une autre raison (feature, bug, redesign...). Ce fichier sert de mémoire du
chantier entre les sessions : état d'avancement, convention à suivre, fichiers déjà faits.

## Convention à suivre pour chaque fichier traduit
1. Repérer les `Text('...')` / `TextSpan` / titres/labels avec du texte français en dur (pas les
   noms de variables, pas les logs, pas les commentaires).
2. Ajouter la clé correspondante dans les **4 fichiers** `assets/translations/{fr,en,sw,ln}.json`
   (structure JSON imbriquée, ex. `"settings": { "title": "..." }` → clé `settings.title`).
   `fr.json` = référence, traduire aussi en/sw/ln (pas juste dupliquer le français).
3. Remplacer le texte en dur par `'clé.imbriquée'.tr()` (import `easy_localization` si absent).
4. Pour les textes avec variable (ex. "Bonjour, {name}") : utiliser `'dashboard.hello'.tr(namedArgs: {'name': name})`.
5. Vérifier `flutter analyze` sur le fichier modifié (zéro erreur/warning nouveau).
6. Cocher le fichier dans la liste ci-dessous avec la date.

⚠️ Le code source réel est dans `d:/scolaris/lib` — ne jamais toucher au dossier dupliqué
`d:/scolaris/scolaris/lib` (voir mémoire `project_path_scolaris`).

⚠️ Le namespace `"settings"` dans les JSON de traduction correspond à l'ancienne `SettingsPage`
**supprimée** (commit `84ec667`, fusionnée dans `AccountPage`/Profil). Ces clés sont orphelines —
soit les réutiliser pour les nouvelles sections du Profil, soit les nettoyer plus tard.

## État d'avancement

### ✅ Déjà fait (avant ce chantier, existant)
- `login_screen.dart`, `desktop_shell.dart`, `mobile_shell.dart`, `curved_drawer.dart`,
  `dashboard_scaffold.dart`, `placeholder_page.dart`, `role_badge.dart` — labels de nav et quelques
  écrans déjà branchés.

### ✅ Traduits dans ce chantier
- `lib/shared/pages/account_page.dart` (2026-07-28) — Profil (mobile + desktop) : titres de
  section, tuiles Coordonnées/Établissement/Paramètres, dialogues mot de passe/modifier profil,
  sheets langue/apparence (titres réutilisent `settings.lang.title`/`settings.appearance`), noms
  des mois (`profile.month.1`..`12`, remplace l'ancienne liste `_months` figée en français).
  Nouveau namespace `"profile"` ajouté aux 4 JSON (`fr`/`en`/`sw`/`ln`), + clé
  `profile.password_security`. `flutter analyze` : 0 erreur (35 infos de style pré-existantes).
  Non traduit volontairement : les noms de palettes d'accent ("Scolaris", "Océan", "Forêt"...)
  dans `_AppearanceSheet` — noms propres façon marque, comme les palettes de `settings_page.dart`
  avant elle. `user.displayRole` (ex. "Administration"/"Enseignant") vient de `user_entity.dart`,
  hors périmètre de ce fichier — reste en français tant que ce fichier n'est pas traité.

### ⏳ À faire
Aucun autre fichier traité pour l'instant. Prochain fichier : à définir au fil des prochaines
tâches (pas de campagne massive sans demande explicite).

## À faire à la reprise
1. Continuer fichier par fichier au fil des prochaines tâches.
2. `lib/domain/entities/user_entity.dart` (`displayRole`) — à traduire un jour pour que le rôle
   affiché sur le Profil suive aussi la langue.
3. Nettoyer le namespace JSON `"settings"` orphelin (ancienne `SettingsPage` supprimée) une fois
   qu'on sait ce qu'on en fait.

## Backlog complet — fichiers restants sans `.tr()` (2026-07-28, grep brut)
Liste brute de `grep -rL "\.tr()" lib` (157 fichiers, `account_page.dart` déjà retiré). **Pas tous
à traduire** : une bonne partie sont des fichiers sans UI (data sources, providers, entités,
permissions, PDF, config) qui n'ont légitimement aucun texte affiché à l'utilisateur — à trier au
cas par cas quand on les ouvre, pas une consigne de tout traduire.

### Vrais écrans UI à traduire (prioritaires — priorité "home" de chaque rôle, puis les pages)
- `lib/features/admin/presentation/admin_home.dart` + tout `admin/presentation/pages/*.dart`
  (admin_attendance_page, admin_badges_page, admin_billing_page, admin_class_stats_page,
  admin_classes_page, admin_courses_page, admin_grades_page, admin_reports_page,
  admin_school_page, admin_subjects_page, admin_subscription_page, bulletin_pdf, class_promotion_page,
  enrollment_config_page, library_submission_page, prereg_queue_page, report_cards_page,
  timetable_page, tuition_accounts_page, tuition_fees_page, tuition_tracking_page, users_page)
  + `admin/presentation/widgets/*.dart` (bulletin_view, preregistration_link_panel, tuition_account)
  + `admin/roles/*.dart` (role_setup_screen, roles_permissions_page, workspace/*)
- `lib/features/teacher/presentation/teacher_home.dart` + `pages/*.dart` (attendance_today_page,
  class_stats_page, classes_page, gradebook_page, teacher_liaison_page)
- `lib/features/student/presentation/student_home.dart`, `primary_student_home.dart` + `pages/*.dart`
  (annales_quiz_page, attendance_page, cahier_liaison_page, cahier_textes_page, carte_etudiante_page,
  course_detail_page, courses_page, grades_page, inscription_ue_page, library/* (8 fichiers),
  notifications_page, releve_ects_page, schedule_page, simulateur_moyenne_page,
  student_documents_page, student_payments_page)
- `lib/features/parent/presentation/parent_home.dart` + `pages/*.dart` (child_detail_page,
  child_payments_page, children_page, parent_payments_page)
- `lib/features/finance/presentation/finance_home.dart` + `pages/*.dart` (billing_page,
  finance_students_page, payments_page, receipts_page, reports_page)
- `lib/features/surveillance/presentation/surveillance_home.dart` + `pages/*.dart`
  (attendance_log_page, students_list_page)
- `lib/features/platform/presentation/platform_home.dart` + `pages/*.dart` (platform_announcements_page,
  platform_dashboard, platform_library_moderation_page, platform_school_detail,
  platform_schools_page, platform_settings_page, platform_subscriptions_page) + `widgets/*.dart`
  (platform_charts, platform_search, platform_widgets)
- `lib/features/auth/presentation/forgot_password_screen.dart`, `splash_screen.dart`
- `lib/features/enrollment/presentation/public_enrollment_screen.dart`
- `lib/features/school_registration/school_registration_screen.dart`
- `lib/shared/pages/enrollment_page.dart`, `features_hub_page.dart`, `notifications_page.dart`,
  `search_page.dart`
- `lib/shared/widgets/online_payment_sheet.dart`, `page_scaffold.dart`, `permission_guard.dart`,
  `plan_gate.dart`, `responsive_role_shell.dart`, `school_switcher.dart`, `skeleton.dart`,
  `stat_card.dart`, `subscription_alert_banner.dart`, `surface.dart`

### Probablement hors périmètre (pas d'UI texte, à vérifier au cas par cas, pas de traduction a priori)
- Data/sources/repositories : `data/repositories/auth_repository_impl.dart`,
  `data/sources/remote/*.dart`, `domain/entities/*.dart`, `domain/repositories/*.dart`,
  `domain/usecases/*.dart`, `features/enrollment/data/*.dart`, `features/platform/data/*.dart`,
  `shared/data/*.dart`
- Config/core sans UI : `core/config/*.dart`, `core/localization/locales.dart`,
  `core/permissions/*.dart`, `core/platform/platform_utils.dart`, `core/routing/app_router.dart`,
  `core/services/*.dart`, `core/theme/*.dart`, `core/bulletin/bulletin_math.dart`
- Providers : `presentation/providers/*.dart`
- Génération PDF (texte du document imprimé, pas de l'UI app — à évaluer séparément si les PDF
  doivent aussi être multilingues) : `shared/pdf/*.dart`, `admin/presentation/pages/bulletin_pdf.dart`
- Print dispatch : `shared/services/print_dispatch_*.dart`, `print_service.dart`
- `lib/main.dart` (bootstrap, pas d'UI directe)
