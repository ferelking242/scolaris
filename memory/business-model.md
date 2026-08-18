---
name: business-model
description: Modèle économique de Scolaris — SaaS B2B, 3 offres actives (Essentiel/Croissance/Complet) + Entreprise désactivée depuis le 18/08/2026, académique inclus + modules complémentaires
metadata:
  type: project
---

Scolaris est commercialisé en **SaaS B2B** : l'**école paie** l'abonnement (usage inclus pour tous ses élèves/parents). Marché initial : **Congo / Afrique centrale (FCFA/XAF)**, avec objectif d'**expansion multi-pays** (garder les mêmes offres, ne varier que la grille de prix par pays/devise → `prix = f(offre, palier, pays)`).

⚠️ **Modèle refondu le 09/08/2026** (conversation "business plan") — remplace toute version antérieure de ce fichier (l'ancien modèle Simple/Pro/Max à 14 900/29 900/59 900 avec gating par fonctionnalité pure n'a jamais été le modèle final déployé). Voir [[offers-and-gating]].

**Académique (notes, bulletins, emploi du temps, statistiques de classe) est le socle du produit — toujours inclus dans TOUTES les offres**, plus un module qu'on choisit ou compte. Les offres se distinguent par le nombre d'**emplacements de modules complémentaires** (Finances / Présences / Inscriptions) débloqués, façon catalogue "app store" (installer/désinstaller depuis `AdminSubscriptionPage`).

**3 offres actives** + Entreprise désactivée (prix Congo/XAF, mensuel — annuel = ×9, soit 3 mois offerts depuis le 10/08/2026, ancien taux ×10/2 mois) :
- **Essentiel** — 15 000 F/mois, 200 élèves inclus, 0 emplacement de module complémentaire.
- **Croissance** — 35 000 F/mois, 500 élèves inclus, 1 emplacement au choix (Finances/Présences/Inscriptions).
- **Complet** — 65 000 F/mois, 1 500 élèves inclus, les 3 emplacements + Rapport Premium.
- **Entreprise** — ⚠️ **désactivée depuis le 18/08/2026** (décision utilisateur) : n'est plus une offre active/vendable. Le code garde encore des traces (mapping `'entreprise': 'Entreprise'` dans [admin_subscription_page.dart](../lib/features/admin/presentation/pages/admin_subscription_page.dart), dialogue "sur devis") mais elle ne doit plus être proposée en pratique. Elle promettait sur devis (~150 000 F/mois), illimité, multi-établissements, marque blanche, API, support dédié — **ces items (API publique, domaine/marque blanche) sont désormais sans palier d'accueil** tant qu'Entreprise reste désactivée ; à réassigner dans Complet ou une offre future si on veut continuer à les vendre. À réactiver si besoin plutôt qu'à resupprimer le code.

**Achat à la carte d'un emplacement supplémentaire** : 15 000 F/mois (cohérence volontaire avec le prix Essentiel — "un module de plus"), indépendant du plan choisi (même Essentiel peut en acheter, plafonné). N'active PAS un changement d'offre — augmente juste `subscriptions.extra_module_slots`.

**Gating des modules complémentaires — vérifié le 18/08/2026, PAS un bug** : le menu (`admin_home.dart`, `RoleNavEntry.module` + filtre L212) restreint déjà correctement l'accès à Inscriptions/Finances/Présences via `school.modules`. Une école créée après le 09/08/2026 a toujours `modules` non-vide (`['academic']` minimum, écrit à l'inscription) donc le filtre s'applique normalement. Seules les écoles créées **avant** le 09/08 (`modules` vide) sont grandfatherées avec tout actif — comportement voulu ("pas de régression"), documenté aussi dans le modèle `SbSchool.modules` (supabase_db_source.dart:1336). Ne pas retenter de "corriger" ce fallback sans revoir tout le système à la fois (menu + catalogue `admin_modules_page.dart` en dépendent tous les deux de la même sémantique vide=tout-actif).

**Mini-site école (nouveau chantier, décidé le 18/08/2026)** : le lien public de pré-inscription seul (déjà existant, `PreRegistrationLinkPanel` + `enrollment_api_key`) n'est pas jugé assez crédible envoyé nu (WhatsApp/affiche) — il faut une vraie page vitrine derrière. Placement tarifaire tranché :
- **Croissance** — mini-site basique (1 page, logo/couleurs/texte, sous-domaine `*.scolaris.app`), bouton d'inscription qui pointe vers le flux `enrollment_requests` existant.
- **Complet** — plus de pages, plus de photos, plusieurs modèles de site au choix, domaine personnalisé.
- Rien côté Essentiel : le lien public brut reste inclus (existant) mais pas de mini-site.
- Indexation/SEO (sitemap, meta tags, structured data schema.org School) : reporté, à traiter après — mais le template doit être écrit HTML sémantique / non JS-only dès le départ pour ne pas devoir tout regénérer plus tard.
- API publique/marque blanche : en attente, Entreprise désactivée (voir plus haut).

**Suppléments de taille** au-delà des élèves inclus : paliers par offre dans `plan_size_surcharges`, purement informatifs pour l'instant (facturation manuelle, pas de prélèvement auto).

**Paiement 100% manuel** (pas d'agrégateur/API) : l'école envoie l'argent via Mobile Money (MTN/Airtel) vers un numéro marchand Scolaris, saisit la référence reçue par SMS, un super-admin vérifie sur le relevé marchand et confirme (`platform_confirm_subscription_payment`) — RIEN ne s'active avant cette vérification. Essai gratuit 14 jours, sans CB.

**Cycle de vie automatisé** (`refresh_subscription_statuses()`, cron horaire pg_cron) : trial→expired à l'échéance, active→past_due à la fin de période, past_due→expired après 7 jours de grâce. Un abonnement hors règle passe en **lecture seule côté serveur** (triggers `enforce_subscription_active*` sur ~40 tables + policies), pas juste à l'affichage.

Toutes les migrations business/pricing de ce chantier : `backup/migrations_archive/20260809_*.sql` (module_marketplace, module_slot_addon, lifecycle_fixes, enforce_subscription_rls[_indirect], new_pricing_entreprise) + `20260810_annual_3mois_offerts.sql` (annuel ×9). Détail technique complet dans [[offers-and-gating]].

**Site vitrine réel = un repo GitHub SÉPARÉ, PAS dans `d:\scolaris`** — ⚠️ piège découvert le 18/08/2026 : il existait un dossier `site_saas/` ici (dans le repo `ferelking242/scolaris`) qui n'était qu'une COPIE de brouillon, jamais déployée. Le repo réellement publié sur GitHub Pages (`boveldy.github.io/scolaris-site/`) est un clone local à part, `C:\Users\DELL\scolaris-site` (remote `boveldy/scolaris-site`). `site_saas/` a été supprimé de `d:\scolaris` le 18/08/2026 pour éviter la confusion — désormais TOUTE modification du site vitrine (index.html, ecoles.html, ecole.html, scolaris-config.js…) doit se faire directement dans `C:\Users\DELL\scolaris-site`, avec son propre commit/push vers `boveldy/scolaris-site`. PAS le dossier `site/` non plus (mockup Next.js séparé, prix périmés jamais mis à jour, non branché à l'inscription réelle). Le formulaire d'inscription réel redirige vers l'app (`#/register-school`), pas de choix mensuel/annuel à l'inscription — le choix d'offre/période se fait après coup dans `admin_subscription_page.dart`.
