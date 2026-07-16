# Travail 2 — Rôles réels, verrous en base, et vocabulaire unique

État au 13 juillet 2026 · branche `feat/unify-student-levels`

Ce document raconte ce qui a été fait, **pourquoi**, et ce qui reste à faire.
Il est écrit pour être lu dans six mois, quand le contexte aura disparu.

---

## Le fil conducteur

Trois défauts de fond revenaient sans cesse, sous des habits différents :

1. **Les permissions étaient décoratives.** Cocher une case ne protégeait rien.
   La base autorisait n'importe quel membre de l'école à tout faire.
2. **Des réglages d'établissement étaient figés dans le code.** La devise, le
   barème, les niveaux, le découpage de l'année : autant de choses qui varient
   d'une école à l'autre et qu'on ne pouvait pas changer sans recompiler.
3. **Le dépôt ne dit pas la vérité sur la base.** Plusieurs tables, colonnes et
   contraintes n'existent que sur le serveur Supabase, posées à la main. On l'a
   découvert trois fois, à chaque fois par un plantage.

---

## 1. Les rôles et permissions — de la décoration au fonctionnement

### Le problème

La page « Rôles & permissions » n'avait jamais fonctionné pour personne. Six bugs
distincts se cachaient derrière un même symptôme (« rien ne bouge, rien ne
marche ») :

- **Un blocage circulaire dans la base.** `has_permission()` cherchait les droits
  d'une personne *à travers son rôle*. Or le fondateur de l'école n'en a pas :
  pour créer le premier rôle, il fallait déjà en avoir un. Toute écriture était
  silencieusement refusée.
- Un organigramme de largeur infinie qui faisait planter la mise en page.
- Un `InteractiveViewer` sans hauteur, qui tuait toute la colonne de gauche —
  d'où « je ne peux rien cliquer ».
- Une course au chargement produisant un `duplicate key` à la sauvegarde.

### Ce qui a été décidé

> **Le droit suit le RÔLE, pas la personne.**

C'est la décision structurante. On ne coche pas des cases pour Rose ; on définit
ce qu'est une Secrétaire, et Rose est Secrétaire. Changer le rôle change tous
ceux qui le portent. Un directeur peut donc décider « chez moi, les surveillants
ne suppriment pas une note » — et ça s'applique à tout le monde, sans toucher au
code.

### Ce que ça a impliqué

- `users.permissions` (l'ancien modèle, une liste plate) devient une **copie
  dérivée** des droits du rôle, maintenue par des déclencheurs en base. Les deux
  modèles coexistent sans se contredire.
- **Les enseignants portent eux aussi un rôle.** Ils n'en avaient aucun : leurs
  accès étaient écrits en dur. Il y avait deux façons d'être enseignant dans le
  même système ; il n'en reste qu'une.
  - `users.role = 'teacher'` dit **quel espace il voit** (son tableau de bord).
  - Son rôle du personnel dit **ce qu'il a le droit de faire**.
  - Deux questions différentes, deux mécanismes.
- **Les rôles ne dépendent plus du cycle.** Un directeur de primaire et un
  proviseur de lycée font le même métier : ils partagent un rôle commun
  renommable (« Chef d'établissement »). Les pages admin sont uniformes ; seuls
  les *classes* et les *matières* changent d'un cycle à l'autre.
- L'invitation d'un membre attribue un rôle, et le formulaire du personnel a été
  complété (téléphone, matricule, identité, contrat) — « email + mot de passe »
  ne suffisait pas.

---

## 2. Les verrous réels — les notes

### Ce qu'on a trouvé

La table `grades` n'avait **qu'une seule règle** :

    grades   ALL   tenant_isolation   is_member_of(school_id)

Traduction : tout membre de l'école peut lire, créer, modifier et supprimer
n'importe quelle note. **Un élève est membre de son école.** Il pouvait donc
modifier ses propres notes — pas en trichant, pas en piratant : la base l'y
autorisait. Il suffisait d'appeler l'API au lieu de passer par l'application.

Cette règle faisait de l'**isolation** entre écoles (l'école A ne voit pas
l'école B), et ça marchait. Mais **aucune autorisation à l'intérieur** d'une
école. C'est le vrai sens de « les permissions sont décoratives ».

### Ce qui a été posé

- **Lecture** cadrée : l'élève voit ses notes, le parent celles de ses enfants,
  le prof celles de ses classes, le personnel autorisé celles de l'école.
- **Saisie et modification** : exigent la permission *et* le périmètre. Un prof
  ne note que dans ses propres classes.
- **Suppression** : volontairement plus stricte. Ni l'enseignant ni le
  surveillant ne l'ont dans les modèles — effacer une note reste un acte de
  direction.

Savoir qu'un prof enseigne dans une classe passe par **trois sources**, dont
aucune n'est fiable seule : l'affectation explicite, le statut de titulaire
(l'instituteur du primaire, souvent sans affectation par matière), et l'emploi du
temps (le spécialiste du secondaire).

---

## 3. Le vocabulaire unique — devise, barème, niveaux, périodes

### La devise et le barème

« FCFA » était écrit en dur dans onze fichiers, et « /20 » dans une dizaine. Une
école nigériane aurait vu ses frais en francs CFA et ses bulletins notés sur 20 —
deux choses qui ne veulent rien dire là-bas. Ces réglages appartiennent
désormais à l'école (`schools.currency`, `schools.grading_scale`), lus partout
via `SchoolFormat`.

Au passage, une mine : `invoices.currency` avait pour défaut `'CDF'` (franc
congolais) tandis que `fee_structures.currency` avait `'XAF'` (franc CFA). Une
facture écrite sans devise explicite ne parlait pas la même langue que la grille
de frais dont elle découlait. Les deux défauts ont été retirés : l'appelant doit
fournir la devise, et un oubli échoue franchement.

### Les périodes de l'année — le bug le plus vicieux

L'application parlait **deux langues** pour la même chose :

| Écran | Envoyait / lisait |
|---|---|
| Saisie des notes (carnet du prof, page admin) | `S1 / S2 / S3` — « Semestre » |
| Bulletin, espace élève | `T1 / T2 / T3` — « trimestre » |

La base n'accepte que les trimestres : **toute saisie de note était rejetée**.
C'est une chance. Sans cette contrainte, la note aurait été enregistrée — dans
une période que le bulletin ne relit jamais. Des profs saisissant
consciencieusement leurs notes, et des bulletins vides, sans le moindre message
d'erreur. Le plantage nous a protégés d'un bug silencieux.

La correction de fond : **le découpage de l'année appartient à l'école**
(`schools.period_system`). Un lycée congolais est en trimestres, une université
en semestres. Les quatre écrans lisent maintenant **la même liste** ; ils ne
peuvent plus diverger.

### Le barème d'une évaluation

Le carnet écrasait toute note à 20 (`score.clamp(0, 20)`) et enregistrait
`max_score = 20` quoi qu'il arrive. Une note de 8 sur 10 était donc stockée comme
8 **sur 20** — la moitié de sa vraie valeur.

Bonne nouvelle : chaque note portait déjà son propre maximum en base, et les
moyennes divisent par ce maximum avant de comparer. **Un 8/10 et un 16/20 pèsent
exactement pareil.** Le mécanisme existait, il n'était pas accessible. Le prof
choisit maintenant le barème de sa série (10, 20 ou 100), celui de l'école par
défaut.

---

## 4. Le dépôt ne reconstruit pas la base

Le point le plus inquiétant, et il n'est pas clos.

Des pans entiers du schéma n'existaient **que sur le serveur** : les six tables du
système de rôles, six colonnes de `courses`, et les contraintes sur `grades`
(`grades_period_check`, `grades_type_check`). Un `supabase db reset` n'aurait pas
reconstruit l'état réel.

On les a rapatriées dans `supabase/migrations/` au fur et à mesure — mais toujours
**après un plantage**, jamais avant. Il faudrait un jour comparer
systématiquement le dépôt à la base.

---

## Migrations produites (dans l'ordre)

| Fichier | Ce qu'elle fait |
|---|---|
| `20260713_staff_rbac.sql` | Reconstruit les 6 tables du système de rôles + le catalogue et les 20 modèles |
| `20260714_schema_reconcile.sql` | Corrige l'ordre de rejeu et les colonnes de `courses` ajoutées à la main |
| `20260715_last_admin_guard.sql` | Empêche de supprimer le dernier rôle admin d'une école |
| `20260716_fix_rbac_admin_bypass.sql` | **Débloque tout** : le fondateur est reconnu sans rôle préalable |
| `20260717_sync_user_permissions.sql` | Changer un rôle met à jour tous ceux qui le portent |
| `20260718_staff_profiles.sql` | Fiche du personnel (matricule, identité, contrat) |
| `20260719_common_role_templates.sql` | Six rôles communs, indépendants du cycle |
| `20260720_school_currency_grading.sql` | Devise + barème de l'école ; retire le défaut CDF/XAF |
| `20260721_teachers_get_a_role.sql` | Les enseignants reçoivent le rôle « Enseignant » |
| `20260722_lock_grades.sql` | **Le verrou sur les notes** |
| `20260723_school_periods.sql` | Trimestres ou semestres, au choix de l'école |

---

## À faire

### À exécuter sur Supabase (ordre impératif)

1. `20260721_teachers_get_a_role.sql`
2. `20260722_lock_grades.sql` — **dans cet ordre**, sinon les profs ne peuvent
   plus saisir une seule note
3. `20260723_school_periods.sql` — indépendant, avant ou après

Puis vérifier qu'un prof peut noter, et surtout que **la note apparaît dans le
bulletin** (pas seulement qu'il n'y a plus d'erreur).

### En attente d'une information

`grades_type_check` refuse toujours la saisie. La contrainte n'est pas dans le
dépôt ; il faut lire sa définition sur le serveur :

```sql
select conname, pg_get_constraintdef(oid)
  from pg_constraint
 where conrelid = 'public.grades'::regclass and contype = 'c';

select type, count(*) from public.grades group by type order by 2 desc;
```

L'application envoie `interro1`, `interro2`, `examen`.

### Les verrous restants — par ordre de gravité

Toutes ces tables sont encore en `tenant_isolation ALL`, c'est-à-dire ouvertes à
tout membre de l'école :

1. **Les utilisateurs** (`users`, `student_profiles`) — **un élève peut se
   promouvoir administrateur.** C'est le pire de tous.
2. **L'argent** (`invoices`, `payments`, `fee_structures`) — un élève peut
   marquer sa facture de scolarité comme payée.
3. `attendance`, `report_cards`.

### Les abonnements

Le filtrage par offre (Simple / Pro / Max) est **purement côté application**
(`plan_gate.dart`). Seule la limite d'élèves est réellement tenue par la base. Un
appel direct à l'API contourne l'offre.

### Divers

- Date de fin d'accès pour les prestataires (reporté).
- Une trentaine de commits locaux jamais poussés sur GitHub.
