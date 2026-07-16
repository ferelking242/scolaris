# Akili School

A SaaS-grade, multi-platform school management system built with Flutter.

> Single codebase → **Web**, **Android**, **iOS**, **Windows**, **macOS**, **Linux**.

## ✨ Features

- **6 distinct roles** — Student, Parent, Teacher, Surveillance, Finance, Admin — each with its own UI and navigation.
- **Adaptive shells**:
  - Desktop / wide web → **Fluent-style** sidebar (collapsible, inner-radius) + topbar + content.
  - Mobile / small web → **Material 3** with a floating, rounded, shadowed bottom dock.
- **Theme system** — light / dark + dynamic accent (per-school branding).
- **Multi-language** — `en`, `fr`, `sw`, `ln` (Lingala). All strings live in `assets/translations/*.json`.
- **RBAC** — central `PermissionService` (no role checks scattered in UI).
- **Auth** — email/password or QR code (mock fallback when Supabase env is absent).
- **Offline-ready** — Hive-backed cache + outbox queue.
- **Charts & data grids** — `fl_chart`, `syncfusion_flutter_datagrid`.
- **Production-ready CI** — every push builds Android (every ABI), iOS, Web, Linux, Windows, macOS.

## 🏛 Architecture

Strict Clean Architecture:

```
UI → Provider → UseCase → Repository → Service
```

```
lib/
├── core/             config · theme · localization · permissions · routing · services
├── data/             models · sources (remote/local) · repository implementations
├── domain/           pure entities · repository interfaces · use cases
├── presentation/     riverpod providers · global widgets
├── features/         auth · student · parent · teacher · surveillance · finance · admin
└── shared/           desktop_shell · mobile_shell · responsive shell · widgets
```

UI **never** contains business logic. Every screen calls a provider; providers call use cases; use cases call repositories.

## 🚀 Run

```bash
flutter pub get
flutter run -d chrome                 # web
flutter run -d linux|windows|macos    # desktop
flutter run -d <device>               # mobile
```

### Supabase

The app falls back to a deterministic mock auth source so you can demo every role without configuring a backend. To plug a real Supabase project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

### Demo accounts (mock auth)

Sign in with any of these (password: `demo1234`) — the role is inferred from the local-part:

- `student@akili.school`
- `parent@akili.school`
- `teacher@akili.school`
- `surveillance@akili.school`
- `finance@akili.school`
- `admin@akili.school`

## 🤖 CI / CD

Two GitHub Actions workflows are wired in `.github/workflows/`:

| Workflow | Triggers | Outputs |
| --- | --- | --- |
| `build-all.yml` | every push, PR, tag, manual | Android (every ABI: armeabi-v7a, arm64-v8a, x86_64) **first**, then iOS, Web, Linux, Windows, macOS |
| `build-android-arm64.yml` | every push, manual | A single `app-arm64-v8a-release.apk` |

Artifacts are uploaded on every run.

## 🌍 Localization

Add a new language by dropping a JSON file in `assets/translations/` and registering its locale in `lib/core/localization/locales.dart`.

## 🔐 Permissions (RBAC)

Always go through the central service — never inline a role check in UI:

```dart
if (PermissionService.I.canEditGrades(user)) { ... }
```

## 📦 Tech stack

`flutter` · `riverpod` · `go_router` · `flex_color_scheme` · `flutter_screenutil` · `responsive_framework` · `fluent_ui` · `bitsdojo_window` · `salomon_bottom_bar` · `animations` · `fl_chart` · `syncfusion_flutter_datagrid` · `lottie` · `flutter_staggered_grid_view` · `mobile_scanner` · `qr_flutter` · `hive` · `easy_localization` · `supabase_flutter`

## 📝 License

MIT
