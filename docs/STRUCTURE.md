# 🏛️ Structure du projet — Scolaris

> **Scolaris** — *« Savoir, Héritage, Avenir »*
> Application Flutter de **gestion scolaire multi-rôles** (ENT), responsive **mobile + desktop**,
> backend **Supabase**, mode **offline** (Hive), localisation (`easy_localization`) et thème dynamique.

Architecture : **Clean Architecture** + **feature-first**, état **Riverpod**, routing **go_router**.

---

## 📂 Arborescence de `lib/`

```
lib/
├── main.dart                    ← point d'entrée (init Supabase, Hive, i18n, thème)
│
├── core/                        ← socle technique transverse
│   ├── config/      app_config.dart      (clés Supabase, constantes, accents)
│   ├── localization/ locales.dart        (langues supportées)
│   ├── permissions/ permissions.dart     (permissions granulaires du staff)
│   ├── platform/    platform_utils.dart  (détection desktop/mobile)
│   ├── routing/     app_router.dart       ← go_router + redirection par rôle
│   ├── services/    notifications, offline_storage (Hive), settings
│   └── theme/       app_theme.dart + theme_controller.dart (accent, dark/AMOLED)
│
├── domain/                      ← cœur métier pur (sans Flutter)
│   ├── entities/    user_entity.dart (AppUser, UserRole), entities.dart
│   ├── repositories/ auth_repository.dart (interfaces)
│   └── usecases/    sign_in_usecase.dart
│
├── data/                        ← implémentations / accès données
│   ├── repositories/ auth_repository_impl.dart
│   └── sources/remote/ supabase_auth_source.dart, supabase_db_source.dart
│
├── presentation/providers/      ← providers Riverpod globaux
│   ├── auth_providers.dart  (session, sign-in/out, QR login)
│   └── db_providers.dart
│
├── features/                    ← une feature par rôle/domaine
│   ├── auth/        splash, login, forgot_password
│   ├── school_registration/  inscription d'une école
│   ├── student/     student_home + primary_student_home + pages/ (+library/)
│   ├── teacher/     teacher_home + pages/
│   ├── parent/      parent_home + pages/
│   ├── finance/     finance_home + pages/
│   ├── surveillance/ surveillance_home + pages/
│   └── admin/       admin_home + pages/
│
└── shared/                      ← UI & data réutilisables entre rôles
    ├── desktop_shell/  desktop_shell.dart  (sidebar + header desktop)
    ├── mobile_shell/   mobile_shell.dart + curved_drawer.dart
    ├── pages/          settings, account, notifications, messaging, search…
    ├── widgets/        responsive_role_shell, scaffolds, stat_card, skeleton…
    ├── data/           mock_data, mock_library_data, timetable_data, features_catalog…
    └── services/       print_service.dart
```

---

## 👥 Les rôles

Définis dans `lib/domain/entities/user_entity.dart` — **4 rôles**, le staff étant unifié :

| Rôle      | Regroupe                                          | Route home                        |
|-----------|---------------------------------------------------|-----------------------------------|
| `staff`   | admin, secrétaire, DG, surveillant, comptable…    | `/staff` → `AdminHome`            |
| `teacher` | prof, enseignant                                  | `/teacher` → `TeacherHome`        |
| `student` | élève (+ variante `primaire`)                     | `/student` ou `/student-primary`  |
| `parent`  | parent, tuteur                                    | `/parent` → `ParentHome`          |

Les sous-rôles du staff (finance, surveillance…) existent comme *features* mais passent
tous par le rôle `staff` avec des **permissions granulaires** (`core/permissions/permissions.dart`).

---

## 🧭 Flux de navigation

1. **`main.dart`** initialise Hive, Supabase, i18n, puis lance `AkiliApp` (`MaterialApp.router`).
2. **`core/routing/app_router.dart`** redirige selon la session :
   - pas connecté → `/login`
   - connecté → `roleHome(user)` selon le rôle
3. Chaque *home* de rôle construit un **`ResponsiveRoleShell`**
   (`shared/widgets/responsive_role_shell.dart`) avec ses groupes de navigation.
4. Ce shell choisit automatiquement :
   - **Desktop / tablette large** → `DesktopShell` (sidebar repliable + header)
   - **Mobile** → `MobileShell` (dock courbé + drawer)

> Pattern central : **une page est déclarée une fois** (`RoleNavEntry`) et s'affiche
> correctement sur les deux form factors.

---

## 📄 Pages par rôle

- **Élève** (le plus riche) : dashboard, cours, notes, bulletin, emploi du temps, devoirs,
  présences, documents, paiements + une **bibliothèque** complète (`library/`) :
  livres, sujets d'examen, supports de cours, favoris, stats, lecteur PDF, recherche avancée.
- **Enseignant** : classes, cahier de notes (gradebook), devoirs, appel du jour, stats de classe.
- **Parent** : enfants, messages, paiements.
- **Finance** : facturation, élèves, paiements, reçus, rapports.
- **Surveillance** : liste élèves, journal de présences.
- **Admin / Staff** : utilisateurs, classes, facturation, rapports, emploi du temps,
  centre de notifications, config des inscriptions.
- **Partagées** : paramètres, compte, notifications, messagerie, recherche, hub de fonctionnalités.

---

## ⚙️ Stack technique

| Domaine     | Choix                                                        |
|-------------|-------------------------------------------------------------|
| État        | Riverpod (`flutter_riverpod` + `riverpod_generator`)        |
| Routing     | `go_router` (redirection réactive sur session)              |
| Backend     | **Supabase** (auth + Postgres)                              |
| Offline     | **Hive** (cache + outbox d'actions)                         |
| Thème       | `flex_color_scheme` + accent dynamique par école            |
| Responsive  | `responsive_framework` + `flutter_screenutil`               |
| i18n        | `easy_localization` (`assets/translations/`)                |
| Data viz    | `fl_chart`, `syncfusion_flutter_datagrid`                   |
| Divers      | QR scan (login élève), Lottie, skeletonizer                 |

---

## ⚠️ Point de sécurité

`lib/core/config/app_config.dart` contient en dur la **`supabaseServiceKey`** (clé `service_role`)
dans le code client. Cette clé contourne toute la sécurité RLS — elle ne devrait **jamais**
être embarquée dans une app distribuée. À corriger.
