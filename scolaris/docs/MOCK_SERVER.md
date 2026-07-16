# Mock Server — Complexe Scolaire Saint-Gabriel de Brazzaville

## Vue d'ensemble

Le mock server central simule un établissement scolaire congolais typique.  
Il est **entièrement en mémoire** (pas de réseau requis) et conçu pour être remplacé par Supabase en production.

---

## École simulée

| Champ       | Valeur                                      |
|-------------|---------------------------------------------|
| Nom         | Complexe Scolaire Saint-Gabriel             |
| Ville       | Brazzaville, Congo                          |
| Quartier    | Bacongo                                     |
| Identifiant | `cs-saint-gabriel-brazza`                   |
| Année       | 2025–2026                                   |
| Devise      | XAF (Franc CFA BEAC)                        |

---

## Cycles & Classes

### Primaire
CP A · CP B · CE1 A · CE1 B · CE2 A · CE2 B · CM1 A · CM1 B · CM2 A · CM2 B

### Collège
6e A · 6e B · 5e A · 5e B · 4e A · 4e B · 3e A · 3e B

### Lycée
2nde A · 2nde C · 1ère A · 1ère C · Tle A · Tle C · Tle D

---

## Comptes démo — Login rapide

### Élèves (`student_*`)

| Email                              | Nom               | Classe  | Cycle   |
|------------------------------------|-------------------|---------|---------|
| `student_primaire@scolaris.app`    | Kevin Ndzembo     | CM1 B   | Primaire |
| `student_college@scolaris.app`     | Christelle Moukassa | 3e A  | Collège  |
| `student_lycee@scolaris.app`       | Junior Mafoua     | Tle C   | Lycée   |
| `student_univ@scolaris.app`        | Exaucé Nkounkou   | L2 Droit | Université |

### Enseignants (`teacher_*`)

| Email                              | Nom                    | Matière         | Cycle    |
|------------------------------------|------------------------|-----------------|----------|
| `teacher_primaire@scolaris.app`    | Mme Monianga Sylvie    | Sciences & Vie  | Primaire |
| `teacher_secondaire@scolaris.app`  | M. Ngakosso Jean-Pierre | Mathématiques  | Lycée    |
| `teacher_lycee@scolaris.app`       | Mme Mavoungou Cécile   | Français        | Lycée    |

### Parents (`parent_*`)

| Email                              | Lien                            |
|------------------------------------|---------------------------------|
| `parent_primaire@scolaris.app`     | Parent d'élève en Primaire      |
| `parent_college@scolaris.app`      | Parent d'élève en Collège       |
| `parent_lycee@scolaris.app`        | Parent d'élève en Lycée         |

### Staff (`admin_*` / `finance_*` / `surveillance_*`)

| Email                              | Nom                    | Fonction               |
|------------------------------------|------------------------|------------------------|
| `admin_directeur@scolaris.app`     | M. Mbemba-Ndzaba Simon | Directeur              |
| `admin_secretaire@scolaris.app`    | Mme Bouanga Henriette  | Secrétariat            |
| `admin_dg@scolaris.app`            | M. Ossomba Patrick     | Directeur Général      |
| `finance_comptable@scolaris.app`   | Mme Malonga Yvette     | Comptable Principal    |
| `finance_caissier@scolaris.app`    | M. Ngoma Cédric        | Caissier               |
| `surveillance_sg@scolaris.app`     | M. Itoua Marcel        | Surveillant Général    |

**Mot de passe universel : `demo1234`**

---

## Architecture du mock

```
lib/
├── shared/data/
│   ├── mock_data.dart              # Structures de données génériques
│   └── mock_school_brazza.dart     # Données École Saint-Gabriel (CENTRAL)
├── data/sources/remote/
│   └── supabase_auth_source.dart   # Auth mock → lookup MockSchoolBrazza
└── domain/entities/
    └── user_entity.dart            # AppUser, UserRole
```

### Flux d'authentification (mock)

```
LoginScreen → signInWithEmail(email, password)
    → AuthRepositoryImpl.signInWithEmail()
        → SupabaseAuthSource.signInWithEmail()
            → SupabaseAuthSource._mockSignIn(email)
                1. MockSchoolBrazza.getUser(email)  ← lookup école
                2. Fallback: dériver rôle depuis email
                → AppUser émis dans Stream
```

---

## Migration vers Supabase

### Étape 1 — Variables d'environnement

```bash
# .env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
```

### Étape 2 — Activer le vrai client Supabase

Dans `lib/core/config/app_config.dart`, définir `hasSupabaseConfig = true` ou
passer les variables depuis l'environnement.

### Étape 3 — Remplacer `SupabaseAuthSource`

```dart
// supabase_auth_source.dart
Future<AppUser> signInWithEmail(String email, String password) async {
  final res = await Supabase.instance.client.auth
      .signInWithPassword(email: email, password: password);
  return _fromSupabase(res.user!);
}
```

### Étape 4 — Tables Supabase recommandées

```sql
-- Profils utilisateurs
create table profiles (
  id          uuid primary key references auth.users,
  full_name   text,
  role        text check (role in ('staff','teacher','student','parent')),
  role_title  text,
  school_id   text,
  avatar_url  text,
  created_at  timestamptz default now()
);

-- Élèves
create table students (
  id          uuid primary key,
  profile_id  uuid references profiles,
  classe      text,
  cycle       text,
  school_id   text,
  avg_grade   numeric,
  attendance  numeric
);

-- Enseignants
create table teachers (
  id          uuid primary key,
  profile_id  uuid references profiles,
  subject     text,
  cycle       text,
  school_id   text
);

-- Notes
create table grades (
  id          uuid primary key,
  student_id  uuid references students,
  subject     text,
  semester    text,
  value       numeric,
  teacher_id  uuid references teachers,
  created_at  timestamptz default now()
);

-- Factures (XAF)
create table invoices (
  id          uuid primary key,
  student_id  uuid references students,
  description text,
  amount_xaf  integer,
  due_date    date,
  status      text check (status in ('payé','en attente','en retard'))
);
```

### Étape 5 — Row Level Security (RLS)

```sql
-- Les élèves ne voient que leurs propres notes
alter table grades enable row level security;
create policy "student_own_grades" on grades
  for select using (student_id = auth.uid());

-- Les admins voient tout
create policy "staff_all" on grades
  for all using (
    exists (select 1 from profiles where id = auth.uid() and role = 'staff')
  );
```

---

## Providers Riverpod à migrer

| Provider actuel (mock)            | Provider Supabase cible                         |
|-----------------------------------|-------------------------------------------------|
| `MockData.students`               | `StreamProvider` → `supabase.from('students').stream()` |
| `MockData.grades`                 | `FutureProvider` → `supabase.from('grades').select()` |
| `MockData.invoices`               | `StreamProvider` → `supabase.from('invoices').stream()` |
| `MockSchoolBrazza.getUser(email)` | `supabase.auth.signIn()` + `profiles` table     |

---

## Données de seed (pour Supabase)

Un script de seed est prévu dans `scripts/seed_supabase.dart`.  
Il insère les données de `mock_school_brazza.dart` dans les tables Supabase.

```bash
dart run scripts/seed_supabase.dart
```

---

*Mis à jour : mai 2026 — Scolaris v2.0*
