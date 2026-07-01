# CLAUDE.md — Scolaris

Application **Flutter multi-rôles de gestion scolaire (ENT)**, responsive mobile + desktop,
backend **Supabase** (Auth + Postgres + RLS), offline **Hive**, i18n **easy_localization** (fr/en/ln/sw),
état **Riverpod**, routing **go_router**. Architecture Clean + feature-first.

> Docs détaillées : [docs/STRUCTURE.md](docs/STRUCTURE.md) (arborescence, rôles, stack) et
> [docs/ROADMAP.md](docs/ROADMAP.md) (feuille de route A→H). Mémoire projet dans [memory/](memory/).

## Repères rapides
- Entrée : [lib/main.dart](lib/main.dart) → `app_router.dart` redirige par rôle.
- Rôles applicatifs (4) : `staff` (→ AdminHome), `teacher`, `student`, `parent`. Le staff est piloté
  par des **permissions granulaires** ([lib/core/permissions/staff_permissions.dart](lib/core/permissions/staff_permissions.dart)).
- Accès données : **tout** passe par [lib/data/sources/remote/supabase_db_source.dart](lib/data/sources/remote/supabase_db_source.dart)
  (méthodes statiques), exposé via les providers [lib/presentation/providers/db_providers.dart](lib/presentation/providers/db_providers.dart).
- Thème : [lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart) — clair (FlexColorScheme) + **sombre**
  (palette GitHub-dark surchargée dans le `ColorScheme`).
- Config Supabase : [lib/core/config/app_config.dart](lib/core/config/app_config.dart) — URL + clé `anon`
  publique uniquement. ⚠️ La clé `service_role` a été **retirée du client** (sécurité) ; la création de
  comptes passe par l'Edge Function `supabase/functions/create-account`. Ne jamais réintroduire de secret ici.

## Base de données (vérifiée en direct — 30 juin 2026)
Instance Supabase `iaxwvgqusxyhmyansawi`. Schéma vérifié via l'API REST (clé anon) :
- **25 tables** requêtées par le code existent toutes ✅ ; les tables supprimées (doublons FR `notes`,
  `cours`, `paiements`, `profiles`, `students`…) sont bien absentes ✅ ; **RLS active** (isolation par école).
- ⚠️ **Le dépôt n'est PAS la source de vérité du schéma** : les migrations appliquées sont archivées dans
  [backup/migrations_archive/](backup/migrations_archive/), pas dans `supabase/migrations/`. Un `supabase db reset`
  ne reconstruirait pas l'état réel. La CLI `supabase` n'est pas installée.
- Compte de test `admin@ead-bzv.cg` / `demo1234` : **refusé** au dernier test (seed non joué ou mdp changé).

## Convention thème (IMPORTANT pour tout nouveau code UI)
Ne **jamais** coder en dur les couleurs **neutres** (texte/fond/bordure) — elles cassent en mode sombre.
Utiliser l'extension `context.c*` définie dans [lib/shared/widgets/page_scaffold.dart](lib/shared/widgets/page_scaffold.dart) :

| Rôle | Utiliser | (ancien figé, à bannir) |
|------|----------|--------------------------|
| Texte principal | `context.cInk` | `Color(0xFF1A0A00)` / `ink` |
| Texte secondaire | `context.cMuted` | `Color(0xFF7A5C44)` / `muted` |
| Fond de carte | `context.cCard` | `Colors.white` / `cardBg` |
| Fond de page/Scaffold | `context.cPage` | `Color(0xFFF5EEE6)` / `pageBg` |
| Bordure | `context.cBorder` | `Color(0xFFDDCCBB)` / `border` |
| Surface douce (champ, zébrure) | `context.cSubtle` | `Color(0xFFF7F1E8)` / `subtleBg` |

- Les **accents de marque** (terracotta `0xFF8B1A00`, or `0xFFC17F24`, vert, orange) restent **constants** — OK dans les deux thèmes.
- Le **texte blanc sur fond coloré** (boutons terracotta, bandeaux dégradés) reste `Colors.white` — OK.
- Un **document imprimable** (bulletin) peut rester « papier » (blanc + encre) volontairement.
- Piège Dart : `context.c*` n'est pas `const` → retirer le `const` du `TextStyle`/widget englobant.
  `flutter analyze` signale « Not a constant expression » si oublié.

## Chantier EN COURS — mode sombre des pages admin
Beaucoup de pages codaient les neutres en dur → illisibles en sombre. Conversion en cours vers `context.c*`.

**✅ Fait & vérifié (0 erreur `flutter analyze`) :**
- Infra : extension `context.c*` ajoutée à `page_scaffold.dart`.
- `admin_home.dart` (dashboard, via helper local `_DashColors`), `users_page`, `admin_classes_page`,
  `admin_billing_page`, `admin_subjects_page` (+ `admin_courses_page` = rien à faire),
  `admin_grades_page` (liste + états-vides ; bulletin gardé « papier »), `report_cards_page`,
  `admin_reports_page`, `tuition_fees_page`, `tuition_tracking_page`, `timetable_page`,
  `admin_subscription_page`, `enrollment_config_page`.

**⏳ Reste à convertir :**
- `admin_school_page.dart` — **partiellement fait** (compile). Restent ~L396 (ring blanc logo — à garder
  probablement), L408 `_ink`, L436 `_border`, L441/L444 `_muted` (palette locale `_ink/_muted/_border`).
- `notification_center_page.dart` — **pas commencé** ; a sa **propre palette locale** `_ink/_muted/_border/_white/_bg`
  (import de page_scaffold à ajouter, ou helper local façon `_DashColors`).
- Pages non-admin (élève/prof/parent/shared) : non traitées. `settings_page.dart` (~100 couleurs figées) = gros morceau.

**Méthode :** repérer les neutres figés avec un grep ciblé, remplacer par `context.c*`, retirer les `const`
devenus invalides, puis `flutter analyze <fichier>` (ignorer les infos `withOpacity`/`use_build_context_synchronously` pré-existantes).

## État Git
Sur `main`. Nombreux fichiers modifiés **non commités** (conversion dark + ce fichier). Rien n'a été commité
pendant ce chantier (à faire quand demandé — brancher depuis main d'abord).
