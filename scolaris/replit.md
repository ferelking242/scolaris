# Scolaris

Plateforme SaaS multi-rôles de gestion scolaire pour l'Afrique (web, mobile, desktop) — Flutter + Supabase.

## Run & Operate

```bash
# Build Flutter web
export PATH="/home/runner/flutter/bin:$PATH"
flutter build web --release --base-href "/"

# Serve the built app (port 5000)
node serve.js
```

**Workflow "Start application"** : `node serve.js` (sert `build/web/` sur le port 5000)

**Env vars** : Supabase URL et anon key sont codés dans `lib/core/config/app_config.dart`.

## Stack

- Flutter 3.27.x · Dart >=3.5.0
- Supabase (URL: https://iaxwvgqusxyhmyansawi.supabase.co)
- go_router · flutter_riverpod · easy_localization
- flex_color_scheme · flutter_screenutil · responsive_framework
- supabase_flutter · uuid · hive

## Where things live

```
lib/
├── core/           config · theme · routing · localization · services
├── data/           repositories · sources (supabase)
├── domain/         entities · usecases · repositories interfaces
├── presentation/   providers · global auth state
├── features/
│   ├── auth/           login + forgot password screens
│   ├── school_registration/  wizard 7 étapes d'inscription école
│   ├── admin/          espace admin
│   ├── student/        espace étudiant
│   ├── teacher/        espace enseignant
│   ├── parent/         espace parent
│   ├── finance/        espace finance
│   └── surveillance/   espace surveillance
└── shared/         shells desktop/mobile · widgets communs
```

DB Schema: → Supabase project `iaxwvgqusxyhmyansawi`  
Tables: `schools`, `school_branches`, `school_founders`, `school_series`, `school_classes`

## Architecture decisions

- **Clean Architecture stricte** : UI → Provider → UseCase → Repository → Source
- **Mock auth** : fallback automatique si Supabase non disponible (pour démo)
- **Rôles dynamiques** : pas de super admin figé — le fondateur a accès total, permissions modifiables
- **Multi-systèmes éducatifs** : francophone, anglophone, LMD, technique, personnalisé
- **Serve.js** : sert le build Flutter web statique depuis `build/web/` sur le port 5000

## Product

- **Login** : e-mail/mot de passe + QR code carte étudiant + 6 rôles démo
- **Inscription école** (6 étapes) : infos école · admin fondateur · système éducatif · séries/classes · base de données · récap
- **Espaces rôles** : étudiant · parent · enseignant · surveillance · finance · admin
- **Multi-filiales** : gestion multi-campus par école
- **Personnalisation** : couleurs, slug, logo par école

## User preferences

- Design premium SaaS niveau africain (couleurs : terracotta #8B1A00, or #C17F24, vert #1B5E20)
- Tous les textes en **français**
- Inscription école = wizard **6 étapes** (Design step supprimé) avec stepper latéral (desktop) ou header (mobile)
- Types école = multi-select cards (Garderie, Primaire, Collège, Lycée, Université, Formation Pro, Grandes Écoles, Éducation Spéc.)
- Téléphone = sélecteur indicatif pays (bottom sheet) + champ numéro
- Filiales = infos complètes (pays+drapeau, indicatif, tél, ville, adresse, Maps link)
- Admin step = style Facebook (bannière gradient+hexagones + photo de profil)
- Login = animations Lottie fixées (ColorFiltered BlendMode.multiply élimine fond blanc)

## Gotchas

- Toujours `flutter build web --release` avant de redémarrer `node serve.js`
- Le `serve.js` sert `build/web/` (racine du projet) — pas `scolaris/build/web`
- La route `/register-school` est publique (pas de redirect auth)
- Les clés Supabase sont hardcodées dans `app_config.dart` (dev only)

## Pointers

- Skill workflows : `.local/skills/workflows/SKILL.md`
- Skill packages : `.local/skills/package-management/SKILL.md`
