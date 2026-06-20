---
name: accounts-and-access
description: Logique de création des comptes et d'accès de connexion par rôle (élève/parent/prof/staff)
metadata:
  type: project
---

Logique décidée (juin 2026). Voir [[offers-and-gating]], [[backend-state]], [[admin-build-roadmap]].

**Principe central : séparer « fiche » et « accès ».**
1. **Créer une personne** = une ligne dans `public.users` (identité/fiche). Toujours.
2. **Donner un accès** = des identifiants de connexion (auth). **Optionnel**, 2ᵉ étape.
Une école peut enregistrer 500 élèves (fiches) sans donner un login à chacun.

**Accès par rôle** :
- **Admin/Staff** : le fondateur s'inscrit lui-même (déjà fait). Il **invite** les autres staff par email.
- **Enseignant** : créé par l'admin → **invitation par email** (le prof choisit son mot de passe).
- **Élève** : login **optionnel**. Défaut intelligent selon le niveau de l'école (**primaire → pas de login** par défaut ; **lycée/univ → login**) + **case à cocher manuelle** par l'admin (décision validée). Sans email : **badge QR** (l'app a déjà `signInWithQrToken`) ou matricule+mot de passe. ⚠️ En **offre Simple, AUCUN login élève** (Simple = staff only, voir [[offers-and-gating]]).
- **Parent** (Pro+ seulement) : créé par l'admin → invitation, ou self-inscription avec un **code rattaché à l'enfant**.

**Élève + Parent = profils DISTINCTS** (rôles/vues différents, parent peut avoir plusieurs enfants), mais **création en une seule fois** : le formulaire « Ajouter un élève » propose d'ajouter/relier son parent dans la foulée (lien `parent_student` auto, parent **réutilisé** s'il existe déjà). Pas de compte fusionné élève+parent. En primaire : souvent **1 seul login = le parent**, l'élève reste une fiche.

**Point technique clé** : pour qu'un admin crée des comptes connectables pour d'AUTRES, on ne peut pas utiliser `signUp` (il connecterait l'admin à la place). Il faut une **Edge Function Supabase** (création côté serveur via admin API). 🎁 Bonus : cette Edge Function utilise `service_role` **côté serveur** → permet de **retirer la clé `service_role` du client** (`app_config.dart`) = règle la faille de sécurité connue d'un coup. À introduire à l'étape Utilisateurs.

**MODÈLE DE PERMISSIONS DU PERSONNEL (RBAC granulaire — décidé/implémenté juin 2026).** Décision user : PAS de rôles staff figés ; à la place, l'admin crée un membre et **coche/décoche des capacités**. Mécanisme :
- Colonne `public.users.permissions` (jsonb, array de clés) + `public.users.role_title` (titre affiché propre, ex. « Secrétaire ») — migration `20260618_staff_permissions.sql`. La clé spéciale **`"*"` = accès total**.
- ⚠️ `users.role` est un **enum `user_role`** = `('student','parent','teacher','admin','staff_custom','surveillance','finance')` — PAS de valeur `'staff'`. Donc tout personnel personnalisé est stocké `role='staff_custom'` + permissions ; le fondateur reste `role='admin'`. `lower(role::text)` obligatoire en SQL (enum).
- Source de vérité des permissions : `lib/core/permissions/staff_permissions.dart` (11 clés : students, classes, grades, attendance, discipline, finance, reports, timetable, communication, staff_manage, school_config) + presets (Secrétaire/Comptable/Surveillant/Co-Directeur/Personnalisé). Tout coché → stocké `['*']`.
- `AppUser.permissions` + `.can(key)` + `.hasFullAccess`. Chargé dans `supabase_auth_source._fetchProfile` (role 'admin'/'direction' → toujours `{'*'}`). `PermissionService.has(user,key)` (`lib/core/permissions/permissions.dart`) gate finance/staff_manage/grades/attendance.
- **Menu dynamique** : `RoleNavEntry.permission` + filtrage dans `AdminHome` (ConsumerWidget) ; groupes vides retirés. **Garde par page** : `PermissionGuard(permission, child)` (`lib/shared/widgets/permission_guard.dart`) enveloppe chaque page taguée dans `AdminHome`.
- Écran de gestion : `_InviteMemberDialog` (Enseignant vs Personnel + presets + FilterChips) et `_EditUserDialog` (édite permissions/titre du staff restreignable = staff_custom/finance/surveillance, PAS le fondateur 'admin') dans `users_page.dart`. Backend `createMemberAccount(+permissions,+title)` (update post-Edge-Function par `auth_uid`) et `updateStaffAccess(id,permissions,title)`.
- **Rétro-compat** : la migration backfill tout le personnel existant à `['*']` (accès total préservé). **Lien offres** : créer du personnel personnalisé = Pro/Max (gate `familyAccountsEnabledProvider`) ; en Simple, seuls fondateur + enseignants.
- ⏳ Reste possible : RLS base par capacité (le gating actuel est app-level, comme les features — la RLS isole déjà par école).
