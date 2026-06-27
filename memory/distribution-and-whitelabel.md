---
name: distribution-and-whitelabel
description: Stratégie de distribution (web/mobile/stores) et fonctionnement du white-label par école
metadata:
  type: project
---

Décidé juin 2026. Voir [[offers-and-gating]], [[business-model]].

**Distribution** : Scolaris est en **Flutter = un seul code** pour Web/Android/iOS/Desktop. **UNE seule app**, interfaces différentes selon le rôle (admin/prof/élève/parent ont déjà chacun leur écran). On ne publie pas 4 apps.
- **Admin/Staff/Profs** → **Web app** (beaucoup de saisie, pas de store, MAJ instantanées). Canal principal pour vendre aux écoles.
- **Parents/Élèves** (Pro) → **app mobile**, mais c'est la même app Scolaris (login → leur interface).
- Ordre de déploiement recommandé : **(1)** Web app en ligne (admin+profs+inscription) → **(2)** mini site vitrine [reporté pour l'instant] → **(3)** PWA mobile parents (installable, sans store) → **(4)** apps natives Play Store (~25$ une fois) / App Store (~99$/an). Vendre dès (1). Push natif (engagement parent) = plus tard.

**Trajet d'inscription** : (site vitrine →) **web app → formulaire d'inscription déjà codé** (`school_registration_screen.dart`) → école créée + admin connecté → invite profs, crée élèves (fiches) → (Pro) parents/élèves prennent l'app mobile. Le formulaire EST dans l'app : un site vitrine n'est pas obligatoire techniquement (juste recommandé pour vendre, avec l'infographie `offres-scolaris.svg`).

**White-label = thème DYNAMIQUE, pas de rebuild** : l'app unique se « teinte » selon l'école de l'utilisateur connecté. Login → lit `school_id` → charge `schools.accent_color` / `logo_url` / nom → applique au runtime. Déjà à moitié branché (`AppUser.schoolAccentArgb`, `AppTheme.light(accent:)`). ⚠️ **Manque à corriger** : `_fetchProfile` (supabase_auth_source.dart) charge la couleur PAR DÉFAUT au lieu de `schools.accent_color` → petite correction pour que chaque école ait vraiment ses couleurs (vaut pour toutes les offres, après connexion).

**Niveaux white-label par offre** : après connexion, **toutes** les offres ont le thème de l'école. Le **Max** ajoute l'entrée **brandée AVANT login** (sous-domaine `ecole-x.scolaris.cg` et/ou **PWA à leur nom/icône**, installable sans store) + masquage de la marque « Scolaris ». **App native à leur nom sur les stores** = ⚠️ risque de rejet Apple (règle 4.3 « clones ») → réservée à du **bespoke** gros client (sous LEUR compte dev), pas en self-serve ; la **PWA brandée** couvre 95% des cas. « Site vitrine public de l'école » = service, PAS une feature produit.
