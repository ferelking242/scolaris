# Chantier : curseur pointeur sur GestureDetector (✅ TERMINÉ — les 50 fichiers traités)

## Objectif
Faire apparaître le curseur main/pointeur (`SystemMouseCursors.click`) sur tous les éléments
cliquables. Les boutons Material (`ElevatedButton`, `TextButton`, `InkWell`, etc.) l'ont déjà par
défaut. Le trou : les `GestureDetector` bruts (défaut `SystemMouseCursors.basic`).

## Méthode
Envelopper chaque `GestureDetector(` ayant un vrai `onTap` (action réelle : navigation, toggle,
sélection) avec :
```dart
MouseRegion(
  cursor: SystemMouseCursors.click,
  child: GestureDetector(...),
)
```
**Règles de skip** (ne pas envelopper) :
- déjà enveloppé dans un `MouseRegion` avec cursor défini (éviter le double-wrap)
- `GestureDetector` "tap-outside-to-dismiss" (unfocus clavier, fermeture d'overlay/scrim) sans
  affordance cliquable visible
- gesture-only (drag `onPanDown`/`onPanUpdate`, pas de `onTap`)
- plein écran sur du texte sélectionnable (`SelectableText`) où un curseur pointeur permanent
  induirait en erreur

⚠️ Le code source réel est dans `d:/scolaris/lib` — **ne jamais toucher** au dossier dupliqué
`d:/scolaris/scolaris/lib` (voir mémoire `project_path_scolaris`).

## Périmètre
`grep GestureDetector\(` sur `d:/scolaris/lib` → **50 fichiers** trouvés au départ. Travail
délégué à des agents en parallèle par lots de 10 fichiers ("batch 1" à "batch 5").

## État d'avancement

### ✅ Batch 1 — terminé (10 fichiers, 34 wrap / 1 skip)
- `lib/features/enrollment/presentation/public_enrollment_screen.dart` — 1 wrap
- `lib/shared/widgets/page_scaffold.dart` — 0 wrap, 1 skip (ActionButton déjà cursor via MouseRegion imbriqué)
- `lib/features/teacher/presentation/pages/teacher_rewards_page.dart` — 2 wrap
- `lib/shared/widgets/online_payment_sheet.dart` — 1 wrap
- `lib/shared/widgets/dashboard_scaffold.dart` — 2 wrap
- `lib/features/admin/roles/workspace/roles_permissions_workspace.dart` — 4 wrap
- `lib/features/auth/presentation/login_screen.dart` — 14 wrap
- `lib/features/auth/presentation/forgot_password_screen.dart` — 5 wrap
- `lib/features/teacher/presentation/pages/attendance_today_page.dart` — 1 wrap
- `lib/features/student/presentation/student_home.dart` — 4 wrap

### ✅ "3 fichiers" lot A — terminé (3 wrap-sets)
- `lib/shared/pages/enrollment_page.dart` — 6 wrap
- `lib/features/student/presentation/pages/cahier_textes_page.dart` — 1 wrap
- `lib/shared/pages/account_page.dart` — 4 wrap

### ✅ "3 fichiers" lot B — terminé
- `lib/shared/pages/settings_page.dart` — 8 wrap / 2 skip (drag-only HSV picker)
- `lib/shared/pages/search_page.dart` — 7 wrap
- `lib/features/platform/presentation/pages/platform_schools_page.dart` — 1 wrap

### ✅ Batch 3 — terminé (10 fichiers, 22 wrap / 2 skip)
- `lib/features/student/presentation/pages/annales_quiz_page.dart` — 3 wrap
- `lib/features/student/presentation/pages/cahier_liaison_page.dart` — 1 wrap
- `lib/features/admin/presentation/pages/users_page.dart` — 2 wrap
- `lib/features/student/presentation/pages/inscription_ue_page.dart` — 1 wrap
- `lib/features/student/presentation/pages/releve_ects_page.dart` — 1 wrap
- `lib/features/student/presentation/pages/student_payments_page.dart` — 2 wrap
- `lib/features/student/presentation/pages/notifications_page.dart` — 2 wrap
- `lib/shared/mobile_shell/mobile_shell.dart` — 8 wrap / 2 skip (drag horizontal, tap-outside-dismiss)
- `lib/features/student/presentation/pages/student_documents_page.dart` — 1 wrap
- `lib/features/admin/presentation/pages/report_cards_page.dart` — 1 wrap

### ✅ Batch 5 — terminé (10 fichiers, 47 wrap / 3 skip)
- `lib/features/student/presentation/pages/library/books_page.dart` — 5 wrap
- `lib/features/student/presentation/pages/library/exam_subjects_page.dart` — 4 wrap
- `lib/features/admin/presentation/pages/admin_courses_page.dart` — 4 wrap
- `lib/features/student/presentation/pages/library/course_materials_page.dart` — 6 wrap
- `lib/features/student/presentation/pages/library/library_advanced_search_page.dart` — 3 wrap
- `lib/features/teacher/presentation/pages/teacher_liaison_page.dart` — 2 wrap
- `lib/features/student/presentation/pages/library/library_favorites_page.dart` — 4 wrap
- `lib/features/admin/presentation/pages/admin_school_page.dart` — 1 wrap
- `lib/features/student/presentation/pages/library/library_page.dart` — 10 wrap / 1 skip (unfocus clavier)
- `lib/features/student/presentation/pages/library/pdf_reader_page.dart` — 8 wrap / 2 skip (toggle plein écran sur texte sélectionnable, scrim fermeture panneau)

### ✅ Batch 2 — confirmé complet (vérifié après coup)
Le premier message n'avait montré qu'un message de lancement sans détail. Vérification faite sur
les 4 fichiers concernés : tous les `GestureDetector` étaient déjà enveloppés (batch 2 avait bien
fait le travail, juste pas rapporté). Aucune modification nécessaire.
- `lib/features/student/presentation/primary_student_home.dart` — 1/1 déjà wrap
- `lib/shared/pages/notifications_page.dart` — 1/1 déjà wrap
- `lib/shared/pages/features_hub_page.dart` — 3/3 déjà wrap
- `lib/features/platform/presentation/pages/platform_dashboard.dart` — 1/1 déjà wrap

### ✅ Batch 4 — terminé (10 fichiers, 44 wrap / 4 skip déjà couverts)
- `lib/features/school_registration/school_registration_screen.dart` — 24 wrap
- `lib/features/admin/presentation/pages/prereg_queue_page.dart` — 2 wrap
- `lib/features/student/presentation/pages/courses_page.dart` — 5 wrap
- `lib/features/student/presentation/pages/simulateur_moyenne_page.dart` — 4 wrap
- `lib/features/student/presentation/pages/schedule_page.dart` — 1 wrap
- `lib/features/admin/presentation/pages/enrollment_config_page.dart` — 2 wrap
- `lib/features/admin/presentation/pages/admin_grades_page.dart` — 1 wrap
- `lib/shared/desktop_shell/desktop_shell.dart` — 3 wrap / 4 skip (déjà MouseRegion cursor ancêtre)
- `lib/features/admin/presentation/pages/admin_badges_page.dart` — 1 wrap
- `lib/features/admin/presentation/pages/admin_subscription_page.dart` — 1 wrap

⚠️ Ce lot s'est terminé APRÈS la consigne utilisateur "ne modifie plus, arrête" (il tournait déjà en
fond avant cette consigne, non relancé). Aucune action supplémentaire prise suite à sa fin — juste
consigné ici.

### Fichiers du grep initial NON confirmés traités (à vérifier à la reprise — probablement batch 2 et/ou 4)
- `lib/features/admin/presentation/pages/prereg_queue_page.dart`
- `lib/features/school_registration/school_registration_screen.dart`
- `lib/features/student/presentation/primary_student_home.dart`
- `lib/features/student/presentation/pages/simulateur_moyenne_page.dart`
- `lib/features/student/presentation/pages/courses_page.dart`
- `lib/features/admin/presentation/pages/admin_subscription_page.dart`
- `lib/shared/pages/notifications_page.dart` (⚠️ distinct de `student/.../notifications_page.dart`, déjà fait)
- `lib/shared/desktop_shell/desktop_shell.dart`
- `lib/features/student/presentation/pages/schedule_page.dart`
- `lib/features/admin/presentation/pages/admin_grades_page.dart`
- `lib/features/admin/presentation/pages/admin_badges_page.dart`
- `lib/shared/pages/features_hub_page.dart`
- `lib/features/admin/presentation/pages/enrollment_config_page.dart`
- `lib/features/platform/presentation/pages/platform_dashboard.dart`

## À faire à la reprise
1. Lancer `flutter analyze` global sur `d:/scolaris` (pas `d:/scolaris/scolaris`) pour confirmer
   zéro erreur introduite sur l'ensemble (chaque lot a été vérifié fichier par fichier, mais pas
   en un seul passage global).
2. Tester visuellement quelques écrans (survol souris en mode desktop/web) pour confirmer le
   comportement.
3. Ne rien committer avant validation explicite de l'utilisateur (aucun commit n'a été fait sur ce
   chantier à ce stade).
