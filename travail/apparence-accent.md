# Chantier : propagation de l'accent (Apparence) à toute l'app (🔴 DÉMARRAGE — 85 fichiers en couleur figée)

## Contexte / pourquoi ce fichier existe
Le Profil (`account_page.dart`) a un sélecteur "Apparence" qui change la couleur d'accent de
l'app (`ThemeControllerProvider.setAccent`). Diagnostic (2026-07-28) :

1. **La persistance était cassée** — corrigé (2026-07-28) : `ThemeController` sauvegarde
   maintenant l'accent dans `OfflineStorage.settings` (Hive, même box que le reste des réglages
   — `contraste_eleve`, `text_scale`, etc.), rechargé au démarrage. Ne se réinitialise plus au
   F5/redémarrage.
2. **La propagation est très partielle** — reste à faire, objet de ce chantier. `Theme.of(context)
   .colorScheme.primary` suit bien l'accent (branché dans `AppTheme.light(accent:)`), et le
   sidebar/drawer desktop + mobile a été corrigé (commit `84ec667`, 2026-07-28) pour lire l'accent
   au lieu de couleurs figées. **Mais la quasi-totalité des écrans du reste de l'app** utilise des
   couleurs de marque figées en dur (`ScolarisPalette.terracotta`, `_terra`, `ScolarisAccents.*`)
   au lieu de `Theme.of(context).colorScheme.primary` — changer l'accent n'a donc aucun effet
   visible sur ces écrans.

Grep `ScolarisPalette\.|_terra\b` sur `lib/` → **85 fichiers** concernés (liste brute en bas de ce
fichier, `account_page.dart`/`desktop_shell.dart`/`mobile_shell.dart` déjà partiellement traités —
voir note).

## Décision utilisateur
Même approche que la traduction (`traduction-i18n.md`) : **pas de gros chantier d'un coup**, on
traite au fil de l'eau quand on retravaille un fichier pour une autre raison. Ce fichier sert de
mémoire du chantier entre les sessions.

## Convention à suivre pour chaque fichier
1. Repérer les usages de `ScolarisPalette.terracotta`/`.orange`/`.gold`/`.forestGreen`,
   `ScolarisAccents.*`, ou des constantes locales type `_terra`/`_gold`/`_orange` **quand elles
   servent d'accent/couleur de marque interactive** (bouton principal, icône active, badge,
   dégradé de header/logo, élément sélectionné).
2. **Ne PAS toucher** :
   - Les neutres clair/sombre déjà couverts par `context.c*` (`cInk`/`cMuted`/`cBorder`/`cCard`/
     `cPage`/`cSubtle`) — chantier différent, déjà en cours ailleurs (`CLAUDE.md` § dark mode).
   - Les couleurs sémantiques (rouge erreur/danger, vert succès, orange warning) — pas des
     accents de marque, doivent rester fixes quel que soit l'accent choisi (ex. le logout en
     rouge dans `mobile_shell.dart`/`desktop_shell.dart`, volontairement laissé tel quel).
   - Les documents "papier" imprimables (bulletins PDF, reçus PDF — `shared/pdf/*.dart`,
     `bulletin_pdf.dart`) : peuvent rester en terracotta fixe, un document imprimé n'a pas de
     thème utilisateur. À confirmer au cas par cas, pas une règle absolue.
3. Remplacer par `Theme.of(context).colorScheme.primary` (ou `cs.primary` si `cs` déjà extrait).
   Pour un dégradé (logo, avatar, bannière), dériver une 2e teinte avec
   `Color.lerp(accent, Colors.white, .18)` (clair) ou `Color.lerp(Colors.black, accent, .32)`
   (sombre) — pattern déjà utilisé dans `desktop_shell.dart`/`mobile_shell.dart`.
4. Vérifier `flutter analyze` sur le fichier modifié (zéro erreur/warning nouveau).
5. Cocher le fichier dans la liste ci-dessous avec la date.

⚠️ Le code source réel est dans `d:/scolaris/lib` — ne jamais toucher au dossier dupliqué
`d:/scolaris/scolaris/lib`.

## État d'avancement

### ✅ Déjà fait
- `lib/core/theme/theme_controller.dart` (2026-07-28) — persistance de l'accent via
  `OfflineStorage.settings` (Hive). Ne compte pas dans le grep 85 fichiers (pas de couleur figée,
  c'est la source de vérité de l'accent).
- `lib/shared/desktop_shell/desktop_shell.dart` (2026-07-28) — sidebar/header/popups/avatar/badges
  suivent l'accent. Reste dans la liste 85 fichiers ci-dessous pour un résidu éventuel (à
  revérifier au prochain passage, un `grep _terra` rapide avant de commencer).
- `lib/shared/mobile_shell/mobile_shell.dart` (2026-07-28) — idem desktop (drawer, header, avatar,
  item actif, motif de fond). Logout reste rouge fixe (voulu).
- `lib/shared/pages/account_page.dart` — la page Profil elle-même n'a pas été retravaillée pour
  l'accent (elle utilise encore `_terra` en dur pour ses propres boutons/icônes), sauf la carte de
  profil desktop qui, elle, suit déjà `cs.primary`. À finir à l'occasion.

### ⏳ À faire — backlog brut (84 fichiers restants, grep `ScolarisPalette\.|_terra\b`)
Pas de priorité fixée — traiter au fil des tâches futures sur chacun de ces écrans.

- `lib/features/admin/presentation/admin_home.dart`
- `lib/features/admin/presentation/pages/admin_badges_page.dart`
- `lib/features/admin/presentation/pages/admin_billing_page.dart`
- `lib/features/admin/presentation/pages/admin_class_stats_page.dart`
- `lib/features/admin/presentation/pages/admin_classes_page.dart`
- `lib/features/admin/presentation/pages/admin_courses_page.dart`
- `lib/features/admin/presentation/pages/admin_grades_page.dart`
- `lib/features/admin/presentation/pages/admin_reports_page.dart`
- `lib/features/admin/presentation/pages/admin_school_page.dart`
- `lib/features/admin/presentation/pages/admin_subjects_page.dart`
- `lib/features/admin/presentation/pages/class_promotion_page.dart`
- `lib/features/admin/presentation/pages/enrollment_config_page.dart`
- `lib/features/admin/presentation/pages/library_submission_page.dart`
- `lib/features/admin/presentation/pages/prereg_queue_page.dart`
- `lib/features/admin/presentation/pages/report_cards_page.dart`
- `lib/features/admin/presentation/pages/timetable_page.dart`
- `lib/features/admin/presentation/pages/tuition_accounts_page.dart`
- `lib/features/admin/presentation/pages/tuition_fees_page.dart`
- `lib/features/admin/presentation/pages/tuition_tracking_page.dart`
- `lib/features/admin/presentation/pages/users_page.dart`
- `lib/features/admin/presentation/widgets/bulletin_view.dart`
- `lib/features/admin/presentation/widgets/preregistration_link_panel.dart`
- `lib/features/admin/presentation/widgets/tuition_account.dart`
- `lib/features/admin/roles/workspace/roles_permissions_workspace.dart`
- `lib/features/auth/presentation/forgot_password_screen.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/auth/presentation/splash_screen.dart`
- `lib/features/enrollment/presentation/public_enrollment_screen.dart`
- `lib/features/finance/presentation/pages/finance_students_page.dart`
- `lib/features/finance/presentation/pages/receipts_page.dart`
- `lib/features/parent/presentation/pages/child_detail_page.dart`
- `lib/features/parent/presentation/pages/children_page.dart`
- `lib/features/parent/presentation/parent_home.dart`
- `lib/features/platform/data/platform_announcement.dart`
- `lib/features/platform/data/platform_mock_data.dart`
- `lib/features/platform/presentation/pages/platform_announcements_page.dart`
- `lib/features/platform/presentation/pages/platform_dashboard.dart`
- `lib/features/platform/presentation/pages/platform_library_moderation_page.dart`
- `lib/features/platform/presentation/pages/platform_school_detail.dart`
- `lib/features/platform/presentation/pages/platform_schools_page.dart`
- `lib/features/platform/presentation/pages/platform_settings_page.dart`
- `lib/features/platform/presentation/pages/platform_subscriptions_page.dart`
- `lib/features/platform/presentation/widgets/platform_search.dart`
- `lib/features/school_registration/school_registration_screen.dart`
- `lib/features/student/presentation/pages/annales_quiz_page.dart`
- `lib/features/student/presentation/pages/attendance_page.dart`
- `lib/features/student/presentation/pages/cahier_liaison_page.dart`
- `lib/features/student/presentation/pages/cahier_textes_page.dart`
- `lib/features/student/presentation/pages/carte_etudiante_page.dart`
- `lib/features/student/presentation/pages/courses_page.dart`
- `lib/features/student/presentation/pages/grades_page.dart`
- `lib/features/student/presentation/pages/inscription_ue_page.dart`
- `lib/features/student/presentation/pages/library/books_page.dart`
- `lib/features/student/presentation/pages/library/course_materials_page.dart`
- `lib/features/student/presentation/pages/library/exam_subjects_page.dart`
- `lib/features/student/presentation/pages/library/library_favorites_page.dart`
- `lib/features/student/presentation/pages/library/library_stats_page.dart`
- `lib/features/student/presentation/pages/notifications_page.dart`
- `lib/features/student/presentation/pages/releve_ects_page.dart`
- `lib/features/student/presentation/pages/schedule_page.dart`
- `lib/features/student/presentation/pages/simulateur_moyenne_page.dart`
- `lib/features/student/presentation/pages/student_documents_page.dart`
- `lib/features/student/presentation/pages/student_payments_page.dart`
- `lib/features/student/presentation/primary_student_home.dart`
- `lib/features/student/presentation/student_home.dart`
- `lib/features/teacher/presentation/pages/class_stats_page.dart`
- `lib/features/teacher/presentation/pages/gradebook_page.dart`
- `lib/features/teacher/presentation/pages/teacher_liaison_page.dart`
- `lib/shared/mobile_shell/curved_drawer.dart` (à vérifier — peut recouper le travail déjà fait
  sur `mobile_shell.dart`)
- `lib/shared/pages/account_page.dart` (le Profil lui-même, boutons/icônes restants)
- `lib/shared/pages/enrollment_page.dart`
- `lib/shared/pages/features_hub_page.dart`
- `lib/shared/pages/notifications_page.dart`
- `lib/shared/pages/search_page.dart`
- `lib/shared/pdf/invoice_pdf.dart` (document imprimable — à confirmer si dans le périmètre)
- `lib/shared/pdf/reports_pdf.dart` (document imprimable — à confirmer si dans le périmètre)
- `lib/shared/widgets/dashboard_scaffold.dart`
- `lib/shared/widgets/online_payment_sheet.dart`
- `lib/shared/widgets/page_scaffold.dart` (widgets partagés `ActionButton`/`DataPanel`/etc. — fort
  impact si traité, utilisé par énormément de pages)
- `lib/shared/widgets/permission_guard.dart`
- `lib/shared/widgets/plan_gate.dart`
- `lib/shared/widgets/surface.dart`
- `lib/core/theme/app_theme.dart` (définit `ScolarisPalette`/`ScolarisAccents` eux-mêmes — pas à
  "traduire", juste la source des constantes ; à ne pas casser)

## À faire à la reprise
1. Continuer fichier par fichier au fil des prochaines tâches (comme la traduction).
2. Prioriser `lib/shared/widgets/page_scaffold.dart` en premier si on veut un gros effet pour peu
   d'effort : `ActionButton`, `DataPanel`, `StatusPill`, etc. sont réutilisés par la majorité des
   pages admin/platform — les corriger là remonte l'effet sur des dizaines d'écrans d'un coup.
3. Revérifier `mobile_shell/curved_drawer.dart` — peut-être déjà couvert indirectement par le
   passage sur `mobile_shell.dart`, à confirmer avant de retravailler.
4. Trancher le cas des PDF imprimables (`shared/pdf/*.dart`, `bulletin_pdf.dart`) : accent
   dynamique ou volontairement figés en terracotta (documents "papier") ?
