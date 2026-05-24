# 🗺️ Scolaris — Plan de développement complet

> Dernière mise à jour : Mai 2026
> Ce document est la **source de vérité** du projet Scolaris.
> Toutes les décisions d'architecture, les conventions de code et la roadmap y sont consignées.

---

## 🎯 Vision

**Scolaris** est un logiciel de gestion scolaire africain, multiplateforme (web, Android, iOS, Windows, macOS), pensé pour les établissements du primaire au doctorat.

Il couvre : la gestion pédagogique, administrative, financière, la communication école-famille, et la vie étudiante universitaire.

**Design language :** terracotta africain (`#8B1A00`), typographie bold, palette chaude, hex patterns, animations fluides.

---

## 🏗️ Architecture

```
scolaris/
├── lib/
│   ├── core/
│   │   ├── routing/        → app_router.dart (GoRouter)
│   │   ├── theme/          → app_theme.dart (ScolarisPalette)
│   │   └── providers/      → core providers
│   ├── domain/
│   │   └── entities/       → user_entity.dart (AppUser, UserRole, SchoolLevel)
│   ├── features/
│   │   ├── admin/          → AdminHome + pages admin
│   │   ├── auth/           → Login, Splash, SchoolRegistration
│   │   ├── finance/        → FinanceHome + pages comptable
│   │   ├── parent/         → ParentHome + pages parent
│   │   ├── student/        → StudentHome + pages élève
│   │   ├── surveillance/   → SurveillanceHome + pages
│   │   └── teacher/        → TeacherHome + pages enseignant
│   ├── presentation/
│   │   └── providers/      → auth_providers.dart
│   └── shared/
│       ├── data/
│       │   ├── mock_data.dart          → Données mock (→ Supabase plus tard)
│       │   ├── features_catalog.dart   → Catalogue de toutes les features
│       │   └── enrollment_config.dart  → Config champs d'inscription
│       ├── desktop_shell/  → DesktopShell (sidebar 2 modes)
│       ├── pages/
│       │   ├── settings_page.dart       → Page paramètres universelle
│       │   ├── features_hub_page.dart   → Hub features par rôle
│       │   ├── enrollment_page.dart     → Formulaire d'inscription configurable
│       │   ├── notifications_page.dart  → Notifications
│       │   ├── search_page.dart         → Recherche globale
│       │   └── account_page.dart        → Profil compte
│       └── widgets/
│           ├── responsive_role_shell.dart → Shell mobile (drawer + bottom nav)
│           ├── page_scaffold.dart         → Composants UI partagés
│           ├── dashboard_scaffold.dart    → Layout dashboard avec stats + sections
│           ├── skeleton.dart              → Shimmer loading
│           └── qr_panel.dart              → Scanner QR
├── docs/
│   ├── PLAN.md         ← CE FICHIER
│   └── features.md     → Matrice features complète
└── .github/
    └── workflows/      → CI/CD (build web + deploy GitHub Pages)
```

---

## 👥 Rôles et accès

| Rôle | Enum | Route | Description |
|---|---|---|---|
| Admin / DG / Secrétariat | `UserRole.staff` | `/staff` | Accès total + administration |
| Enseignant | `UserRole.teacher` | `/teacher` | Pédagogie + suivi élèves |
| Élève | `UserRole.student` | `/student` | Dashboard + notes + emploi du temps |
| Parent | `UserRole.parent` | `/parent` | Suivi enfants + paiements |

> Le rôle `staff` regroupe : admin, DG, secrétaire, comptable, surveillant, finance.
> Les permissions granulaires se gèrent dans un futur `PermissionService`.

---

## 📐 Conventions de code

### 1. Palette de couleurs (immuable)
```dart
const _terra  = Color(0xFF8B1A00);  // Principal — tous boutons, accents
const _orange = Color(0xFFD4540A);  // Secondaire — alertes, hover
const _gold   = Color(0xFFC17F24);  // Accent chaud — badges, stats
const _green  = Color(0xFF2D6A4F);  // Succès — paiements, présences
const _sh1    = Color(0xFF1A0A00);  // Très sombre — texte, headers
const _sh2    = Color(0xFF3E1A00);  // Sombre — gradients
const _muted  = Color(0xFF7A5C44);  // Texte secondaire
const _border = Color(0xFFDDCCBB);  // Bordures
const _bg     = Color(0xFFF5EEE6);  // Fond de page
const _white  = Colors.white;
```

### 2. Structure d'une page
```dart
// Toute page suit ce pattern :
class MaPage extends StatelessWidget {
  const MaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(/* ... */),
      ),
    );
  }
}
```

### 3. Composants partagés (page_scaffold.dart)
- `PageScaffold` — wrapper avec titre + actions
- `DataPanel` — carte avec titre + contenu
- `DataTablePanel` — tableau de données
- `StatusPill` — badge de statut coloré
- `SearchInput` — champ de recherche
- `ActionButton` — bouton primaire / secondaire
- `Avatar` — avatar initiales colorées
- `EmptyState` — état vide

### 4. Navigation
- Toute nouvelle page : `RoleNavEntry(icon, activeIcon, labelKey, page: MaPage())`
- Pages dans groupes : `RoleNavGroup(labelKey: 'sections.xxx', entries: [...])`
- Labels localisés dans `assets/translations/`

### 5. Données (mock → Supabase)
- Toutes les données viennent de `lib/shared/data/mock_data.dart`
- Les modèles commencent par `Mock` : `MockStudent`, `MockInvoice`, etc.
- La migration Supabase remplacera uniquement les appels à `MockData.xxx`

### 6. Impression
- Utiliser `_PrintService.printHtml(html)` dans `lib/shared/services/print_service.dart`
- Génère un HTML formaté et déclenche `window.print()` (dialogue OS natif)
- Compatible : WiFi, Bluetooth, USB/câble — tout ce que l'OS reconnaît

---

## 🔌 Intégrations prévues

| Service | Usage | Priorité |
|---|---|---|
| **Supabase** | Auth + DB + Storage + Realtime | P0 — Phase 5 |
| **Stripe / Wave / Orange Money** | Paiements en ligne | P1 |
| **Firebase FCM** | Notifications push mobile | P1 |
| **Google Drive / OneDrive** | Backup documents | P2 |
| **Twilio / Africa's Talking** | SMS relances paiements | P2 |

---

## 📋 Tâches en cours et à faire

### ✅ Terminé
- [x] Shell desktop (sidebar 2 modes : full/icons)
- [x] Shell mobile (drawer + bottom nav adaptatif)
- [x] Auth routing (GoRouter + Riverpod)
- [x] Page paramètres (5 sections, avatar 3D DiceBear)
- [x] Dashboard admin, enseignant, élève, parent, finance
- [x] Liste utilisateurs (admin)
- [x] Features catalog (Dart data model)
- [x] Features hub page (par rôle + niveau + catégorie)
- [x] docs/features.md (matrice complète)

### 🔄 En cours (session actuelle)
- [ ] **Rôle comptable** : liste élèves + gestion factures + impression reçus
- [ ] **Page inscription** : formulaire configurable par admin
- [ ] **Config inscription** : page admin pour personnaliser les champs

### 🔜 Prochain sprint
- [ ] Appel numérique (enseignant) avec mode hors-ligne
- [ ] Saisie notes en masse + bulletins PDF
- [ ] Messagerie interne temps réel
- [ ] Dashboard surveillance avec map présences

### 🔜 Phase Supabase
- [ ] Migration `mock_data.dart` → appels Supabase
- [ ] Auth réel (email + magic link)
- [ ] RLS par rôle et par école
- [ ] Storage photos + documents

---

## 🖨️ Impression (implémentation)

### Comment ça fonctionne
Scolaris utilise l'API `window.print()` du navigateur via `dart:html`.
Le service génère un document HTML stylisé avec CSS d'impression, puis ouvre le dialogue natif d'impression de l'OS.

**Avantages :**
- Zéro dépendance externe
- Compatible WiFi, Bluetooth, USB/câble (tout ce que l'OS reconnaît)
- Fonctionne sur Chrome, Firefox, Edge, Safari
- Prévisualisation avant impression

**Architecture :**
```dart
// lib/shared/services/print_service.dart
class PrintService {
  static void printReceipt(PrintableReceipt receipt) { ... }
  static void printStudentList(List<MockStudent> students) { ... }
  static void printBulletin(MockStudent student) { ... }
}
```

---

## 📱 Responsive design

| Breakpoint | Shell utilisé | Comportement |
|---|---|---|
| `< 600px` | Mobile bottom nav | Drawer + BottomNavigationBar |
| `600–1024px` | Tablet | Drawer + contenus adaptés |
| `> 1024px` | Desktop | Sidebar 2 modes (full/icons) |

---

## 🚀 Déploiement

- **Web** : GitHub Pages via `.github/workflows/build-web.yml`
- **URL** : https://ferelking242.github.io/scolaris
- **Android** : Build APK via `.github/workflows/build-android.yml`
- **Windows** : Build EXE via `.github/workflows/build-windows.yml`
- **iOS / macOS** : À configurer (requiert certificats Apple)

---

## 📝 Notes importantes

1. **Pas de `const` avec des pages qui utilisent `ConsumerWidget`** — uniquement sur les widgets stateless purs.
2. **Le `UserRole` enum a 4 valeurs** : `staff`, `teacher`, `student`, `parent`. Pas plus.
3. **Le staff** inclut : admin, DG, secrétaire, surveillant, comptable, finance — même rôle, permissions granulaires à venir.
4. **Les imports flutter_popup** : version `^3.3.9` uniquement.
5. **Ne pas utiliser `dart:html` directement dans les widgets** — passer par `PrintService`.
