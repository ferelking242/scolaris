# Matières types (admin) — programme réel du Congo + correction du chargement

_Date : 15 juillet 2026 — branche `feat/unify-student-levels`_

## Contexte / problème
La page **Admin → Matières** a un bouton **« Charger les matières types »**. Analyse du circuit :

- UI : [admin_subjects_page.dart](../lib/features/admin/presentation/pages/admin_subjects_page.dart) → dialogue `_LoadCatalogDialog`.
- Backend : `SupabaseDbSource.loadSubjectsFromCatalog` → lit `subject_catalog` → insère dans `subjects`.
- Provider : `subjectCatalogProvider` (filtré par `schoolCyclesProvider`).

**Deux défauts trouvés :**
1. **Table `subject_catalog` VIDE sur l'instance live** (le seed de la migration n'avait jamais été rejoué) → le bouton ajoutait **0 matière**.
2. **Incohérence de filtrage** : le dialogue codait en dur 3 cycles tous cochés, mais l'insertion ne filtrait pas sur les cycles réels de l'école → une école primaire pouvait charger Philosophie/SVT/SES.

De plus, le seed d'origine était trop maigre (8/10/9) et générique, sans notion de **série** du lycée (coef différent en C / D / A).

## Décisions
- Colonne **`series`** ajoutée à `subject_catalog` (`NULL` = tronc commun ; `A`/`C`/`D` = propre à la série). Sert de **référence** pour le coef par série (le vrai coef par classe vit dans `class_subjects`) ; la table `subjects` reste plate.
- Cycles seedés maintenant : **préscolaire + primaire + collège + lycée**. Technique/G et supérieur = plus tard.
- Coefficients lycée (transmis par l'école) :
  - **Série C** : Maths 5 · Physique-Chimie 5 · SVT 4 · Philo 3 · reste 3 · EPS 2
  - **Série D** : Maths 4 · Physique-Chimie 5 · SVT 5 · Philo 3 · reste 3 · EPS 2
  - **Série A** : Philo 5 · (reste provisoire — à préciser)

## Travail réalisé

### Code Dart
- [supabase_db_source.dart](../lib/data/sources/remote/supabase_db_source.dart)
  - `SbSubjectCatalog` : champ `series` + libellé « Préscolaire ».
  - `getSubjectCatalog(...)` : filtre `series` optionnel (tronc commun `null` toujours conservé).
  - `loadSubjectsFromCatalog(...)` : transmet cycles **et** séries.
- [admin_subjects_page.dart](../lib/features/admin/presentation/pages/admin_subjects_page.dart) — dialogue « Charger les matières types » :
  - Cases **dérivées des cycles réels** de l'école (`schoolCyclesProvider`) → **corrige le bug hors-cycle**.
  - **Sélecteur de séries** (A / C / D) affiché seulement si le lycée est retenu.
  - **Prévisualisation** de la liste des matières qui seront ajoutées (dédup + retrait des déjà présentes).

### Migration SQL
- [20260715_subject_catalog_congo.sql](../supabase/migrations/20260715_subject_catalog_congo.sql)
  - Colonne `series`, **index unique** `(system_type, cycle, name, coalesce(series,''))` remplaçant l'ancienne contrainte (sinon « Mathématiques » C **et** D casse).
  - RLS lecture seule.
  - **Seed Congo complet** : préscolaire, primaire, collège (sans techno), lycée (tronc commun + séries C/D + A provisoire).
  - Idempotente (`on conflict do nothing`).

### Vérification
- `flutter analyze` sur les 2 fichiers : **0 erreur** (seul un `info` préexistant hors changements).

## À faire / en attente
- [ ] **Jouer la migration** dans **Supabase → SQL Editor** (la clé `anon` du client est en lecture seule sur cette table → non applicable depuis le code).
- [ ] **Série A** : compléter les coefficients (seul Maths 2 + Philo 5 seedés).
- [ ] **Collège** : coefficients mis « comme ça » pour l'instant — à valider.
- [ ] **Éduc. civique lycée** : mise à 3 (« le reste = 3 ») — souvent 1 ailleurs, à confirmer.
- [ ] **Technique / G et supérieur** : mise à jour ultérieure.
- [ ] Commit du code Dart (non encore commité).
