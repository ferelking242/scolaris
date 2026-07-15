# Journal de travail — 13 juillet 2026

Session consacrée aux **écrans élève (primaire)** puis aux **écrans parent**.
Fil conducteur : séparer ce qui est *réellement branché* de ce qui n'est qu'une
maquette, et remettre chaque fonctionnalité chez l'utilisateur qui la consulte
vraiment.

> ⚠️ **Réserve valable pour tout ce document** : rien n'a été exécuté dans
> l'application. Il n'existe pas de compte parent de démo, et le compte de test
> pointe sur une école lycée. Toutes les vérifications sont **statiques**
> (`flutter analyze` + relecture + sondage de l'API Supabase). « Ça compile »
> n'est pas « ça marche ».

---

## 1. Espace élève — primaire

### Diagnostic
- Le **dashboard primaire** était déjà branché sur les vrais providers (la
  mémoire projet disait l'inverse — elle était en retard).
- Les **3 outils primaires** (cahier de liaison, menu cantine, carnet de
  récompenses) sont **100 % mock** : listes `const`, zéro provider, **aucune
  table** en base.
- Tout l'espace primaire **cassait en mode sombre** : palette figée
  (`_ink`, `_muted`, `_bg`, `_border`) + `ScolarisSurface.card()` / `.accent()`,
  dont le fond est construit à partir du **blanc pur**.

### Recadrage produit (décision utilisateur)
Le contenu du compte élève primaire contredisait la règle déjà validée
(« en primaire, le login c'est le parent ; l'élève reste une fiche »).
**Principe retenu : en primaire, l'élève consulte sa scolarité, il ne gère rien
d'administratif.**

**Retiré du compte élève primaire** (uniquement en primaire) :
Paiements, Documents, Messagerie.

**Fuite bouchée au passage** : dans les Notifications, une alerte « facture »
ouvrait encore la page Paiements → les factures ne sont plus agrégées en
primaire, et le filtre « Paiement » disparaît de la barre.

### Mode sombre
- Ajout de `ScolarisSurface.themedAccent()` (le pendant thémé de `.accent()`,
  qui manquait) dans `lib/shared/widgets/surface.dart`.
- Conversion vers `context.c*` de : `primary_student_home.dart`,
  `cahier_liaison_page.dart`, `menu_cantine_page.dart`,
  `carnet_recompenses_page.dart`.
- Constantes conservées et **commentées** là où elles sont légitimes :
  `_white` et `_onGold` = texte posé sur un fond de marque coloré.

---

## 2. Le bulletin sort des espaces élève ET parent

Décision utilisateur : le bulletin n'apparaît plus **ni chez l'élève, ni chez le
parent**. Il reste produit et publié côté **admin**.

Il y avait **quatre** portes d'entrée, toutes fermées :
1. l'entrée « Bulletin » de la navigation élève ;
2. le raccourci « Bulletin » du tableau de bord élève ;
3. la section « Bulletins scolaires » de la page Documents de l'élève ;
4. la tuile « Bulletin » de la fiche enfant (parent).

`BulletinPage` n'est pas supprimée — elle n'est simplement plus atteignable.

---

## 3. Sécurité — la RLS ne cloisonnait personne à l'intérieur d'une école

**Faille trouvée.** La policy `tenant_isolation` (`20260706_school_members.sql`)
disait :

```sql
for all to authenticated using (public.is_member_of(school_id))
```

Elle isole les **écoles** entre elles — mais **personne à l'intérieur** d'une
école. Un parent (ou un élève), étant membre de son école, pouvait **lire tous
les élèves, toutes les notes, toutes les factures** de l'établissement. Et
`for all` + `with check` : potentiellement les **écrire**.

C'est ce qui explique que `children_page` ait pu s'écrire avec « tous les élèves
de l'école » sans que rien ne casse : la base laissait passer.

**Correctif — migration `supabase/migrations/20260713_family_rls.sql`
(exécutée).** Approche : ne pas toucher à `tenant_isolation` (rollback simple,
staff/profs inchangés), mais ajouter des policies **RESTRICTIVE**, qui se
combinent en **ET**.

- Helpers : `my_user_id`, `my_role`, `is_family_account`, `is_my_child`,
  `can_see_student` (tous `SECURITY DEFINER` — sinon récursion sur la policy de
  `users`).
- `grades`, `absences`, `attendance`, `invoices`, `payments`, `report_cards` :
  portée famille + **lecture seule** (un élève ne peut plus modifier sa note).
- `submissions` : seul cas où l'élève écrit légitimement (il dépose son devoir).
- `users` : annuaire cloisonné — un parent ne voit plus les autres élèves ni les
  autres parents, mais garde le personnel (sinon l'UI casse : nom du prof, etc.).
- `parent_student` : liens cloisonnés.
- Blocs **TESTS** et **ROLLBACK** en fin de fichier.

---

## 4. Espace parent — de « rien ne marche » à branché

### Diagnostic
- **Dashboard** : 100 % fictif. Deux enfants inventés (*Amara Keita*,
  *Fatou Keita*), un **faux délai de chargement de 1400 ms** simulant un appel
  réseau inexistant, un bouton « Détails » vide (`onAction: () {}`).
- **Mes enfants** : lisait `studentsProvider` = **tous les élèves de l'école**,
  filtrait avec `s.id.contains(session.id)` (qui n'a aucun sens), puis se
  rabattait sur `students.take(3)` — « les 3 premiers, en démo ».
- **Paiements** : lisait `myInvoicesProvider` = les factures d'un élève portant
  l'id du **parent** → **toujours vide**.
- **Cause racine** : personne ne lisait jamais la table `parent_student`.
  L'admin l'écrit pourtant depuis toujours (`createOrLinkGuardian`).

### Navigation (décision utilisateur : **pas de sélecteur d'enfant global**)
« Mes enfants » → clic sur un enfant → **fiche enfant**, d'où part toute sa
scolarité. L'`studentId` est passé explicitement à chaque page : aucune
ambiguïté sur « de quel enfant parle cet écran ».

### Fait
- **Clé de voûte** : `getChildrenForParent(parentId)` — en 2 requêtes, pas
  d'embed PostgREST (le nom de la contrainte FK n'est pas garanti par le dépôt).
- Providers : `myChildrenProvider`, `studentByIdProvider`,
  `absencesForStudentProvider`, `invoicesForStudentProvider`,
  `myChildrenInvoicesProvider` (fusion de la fratrie).
- **Pages élève rendues paramétrables** (`studentId` optionnel, `null` = moi →
  vue élève inchangée) : `GradesPage`, `AttendancePage`, `BulletinPage`,
  `SchedulePage`.
- **`ChildDetailPage`** (nouvelle) : stats réelles + tuiles Notes / EDT /
  Présences + dernières notes.
- **`children_page`** réécrite : vraies données, clic → fiche, état vide
  explicite (« Aucun enfant rattaché — contactez l'établissement »).
- **`parent_home`** réécrit : dashboard réel (résumé agrégé sur la fratrie,
  cartes enfants, section « ce qui demande votre attention » dérivée des
  impayés et des absences non justifiées). Palette figée supprimée.
- **`parent_payments`** : factures de **tous** les enfants + colonne « Élève »
  (sans elle, un parent de deux enfants ne sait pas qui doit quoi).

### Deux pièges évités de justesse
- `_AttendanceDetail` relisait `myAbsencesProvider` **de son côté** : en vue
  parent, il aurait affiché les absences du **parent** (page vide sous un
  en-tête correct).
- `BulletinPage` se rabattait sur `session.fullName` : elle aurait imprimé le
  **nom du parent** sur le bulletin de l'enfant.

---

## 5. Messagerie — retirée

**Découverte.** `MessagingPage` — utilisée par l'élève, le parent **et**
l'enseignant — ne touchait **jamais** Supabase. Ce n'était même pas un
`ConsumerWidget` : une liste `_conversations` écrite en dur, avec des
conversations inventées. Le `messagesProvider` n'était utilisé que par un
fichier **mort**.

Il n'y avait donc rien à « filtrer » : **la messagerie n'existait pas**. La table
`messages` n'a ni destinataire ni fil de conversation, et aucune méthode
d'écriture.

**Retirée** des trois shells (élève, parent, enseignant) + du raccourci du
tableau de bord élève. Fichiers supprimés : `shared/pages/messaging_page.dart`,
`features/parent/presentation/pages/messages_page.dart`.

Le catalogue la déclarait `status: available` — elle était donc **vendue comme
disponible** dans le hub. Repassée en `planned`.

---

## 6. Ce qui reste fictif (audité)

| Page | Niveau | État |
|---|---|---|
| Cahier de liaison, Menu cantine, Carnet de récompenses | Primaire | mock — **tables créées, à brancher** |
| Prépa Bac | Lycée | mock — 0 provider, à trancher |
| Relevé ECTS, Inscription UE | Université | mock — **mis de côté** (pas de lancement sur ce cycle) |
| Pré-inscription (formulaire public + file d'attente admin) | — | **maquette** : aucune table, `accept()` change un statut en mémoire |

**Conséquence importante** : après le retrait du bulletin, **tout ce qui
distingue un niveau d'un autre est fictif**. Rendre la fiche enfant « sensible au
niveau » aujourd'hui produirait exactement la même fiche pour un CE1 et une
Terminale. C'est un problème de **données**, pas d'écran — d'où l'étape suivante.

---

## 7. Migration en attente d'exécution — les 3 outils du primaire

Fichier : **`supabase/migrations/20260724_primary_tools.sql`**.

**Vérification de la base AVANT écriture** (consigne utilisateur) : sondage de
l'API REST. Toutes les tables candidates → **404**. Et une erreur rattrapée :
j'avais supposé `student_profiles.student_id`, **qui n'existe pas** — la vraie
clé vers `users` est **`user_id`** (la table n'a même pas de colonne `id`). La
migration aurait planté.

**7 tables** : `liaison_entries` + `liaison_acks` · `canteen_menus` +
`canteen_dishes` · `merit_points` + `badge_catalog` + `student_badges`.

- Le cahier de liaison vise une **classe entière** ou un **élève** → l'accusé de
  réception est dans une table à part (un mot à la classe = un accusé **par
  parent**). C'est la signature du cahier papier.
- Le catalogue de badges appartient à **l'école** (chacune a ses traditions).

**3 nouveaux modules de permission** (`liaison`, `cantine`, `recompenses`) plutôt
que de détourner `messages` : un directeur doit pouvoir confier la cantine à sa
secrétaire sans lui ouvrir la communication. Accordés aux modèles de rôles —
**Enseignant** (écrit dans le cahier, attribue les bons points), **Adjoint**,
**Secrétaire** (cantine), **Surveillant** (lecture seule).

**RLS** : reprend les conventions existantes (`is_member_of`, `has_permission`,
`teaches_class`, `is_my_child` **à 2 arguments**). Un prof n'écrit que dans ses
classes ; un parent ne lit que ce qui concerne ses enfants ; la famille n'écrit
jamais dans le cahier — elle accuse réception.

### ⚠️ Deux avertissements
1. **Les profs existants n'auront pas les nouveaux droits.** Les permissions sont
   accordées au **modèle** de rôle ; les `staff_roles` déjà instanciés dans les
   écoles ne les récupèrent pas automatiquement. À corriger **après avoir
   constaté** le comportement réel.
2. **Doublon `is_my_child`** : version à **1 argument** (`20260713_family_rls`) et
   à **2 arguments** (`20260722_lock_grades`) coexistent (surcharge Postgres).
   Rien n'est cassé, mais c'est un piège. À nettoyer.

---

## 8. Prochaines étapes

1. **Exécuter** `20260724_primary_tools.sql` (bloc VÉRIFICATION en fin de
   fichier), puis brancher les 3 écrans primaires — côté **parent**, **élève**
   et **enseignant** (sans l'écriture côté prof, le cahier reste vide).
2. **Tester pour de vrai.** En priorité : se connecter en **admin** et vérifier
   qu'on voit **exactement autant de données qu'avant** — si la nouvelle RLS
   était trop stricte, c'est là que ça se verrait.
3. Trancher le sort de **Prépa Bac** (mock).
4. **Reporté explicitement** : la création du compte parent (pré-inscription →
   acceptation). Deux questions ouvertes — identifiant unique du parent
   (**email ou téléphone** ? beaucoup de parents n'ont pas d'email) et existence
   d'un **annuaire public d'écoles** (il n'y en a pas ; le lien de
   pré-inscription est propre à chaque école).
   ⚠️ Bug connu à corriger le jour venu : `createOrLinkGuardian()` ne déduplique
   le parent que **dans la même école** → un parent accepté dans une 2ᵉ école
   obtiendrait une **2ᵉ identité**, ce que `school_members` visait justement à
   éviter.

---

---

# Journal — 14 juillet 2026

## 9. Les 3 outils du primaire — branchés (migration **pas encore exécutée**)

⚠️ Les 7 tables renvoient toujours **404** : le script `20260724_primary_tools.sql`
n'a pas encore été joué. Le code ci-dessous est écrit **en attente** : il
fonctionnera dès l'exécution, et affiche des états vides propres d'ici là.

**Correction apportée à la migration avant exécution** : la contrainte
`category` de `liaison_entries` ne collait pas au vocabulaire de l'écran
(`info/devoir/comportement/sortie/sante` vs `information/sortie/médicament/
permission/félicitation/avertissement`). Le vocabulaire de l'écran est le bon —
c'est celui d'un vrai cahier de liaison. **La migration a été corrigée, pas
l'écran.**

### Couche données (`supabase_db_source.dart`)
Modèles `SbLiaisonEntry`, `SbCanteenMenu`, `SbCanteenDish`, `SbMeritPoint`,
`SbBadge`. Méthodes : lecture du cahier (par élève **et** par classe), écriture
et suppression d'un mot, accusé de réception, menus de la semaine, bons points,
catalogue de badges fusionné avec les obtentions de l'élève.

> Un badge **non obtenu** reste visible (c'est un objectif) → d'où la fusion
> catalogue + obtentions plutôt qu'une simple liste.

### Providers
`liaisonEntriesForStudentProvider`, `liaisonEntriesForClassProvider`,
`myLiaisonAcksProvider`, `canteenMenusProvider`, `meritPointsForStudentProvider`,
`badgesForStudentProvider`, `teacherClassesProvider`.

Tous paramétrés par `studentId` : ils servent l'élève (« moi ») **et** le parent
(« mon enfant ») sans duplication. La RLS fait le tri en base.

### Écrans réécrits (fini le mock)
- **Cahier de liaison** : mots réels, filtres par catégorie, distinction
  « toute la classe » / « mon enfant », et **signature du parent** (accusé de
  réception — la signature du cahier papier). Seul le parent peut signer.
- **Menu cantine** : semaine réelle, ouverture sur le jour d'aujourd'hui,
  allergènes, note du jour. Pas de `studentId` : le menu appartient à l'école.
- **Carnet de récompenses** : bons points et badges réels, badges non obtenus
  affichés comme objectifs.

### Côté enseignant — **l'écriture** (nouveau)
`TeacherLiaisonPage` : le prof choisit une de **ses** classes, écrit un mot
(catégorie, titre, message), et coche « demander une signature ». C'est la pièce
sans laquelle tout le reste ne sert à rien — *un cahier de liaison où personne
n'écrit reste une boîte vide*.

### Fiche enfant — enfin **sensible au niveau**
`ChildDetailPage` dérive le cycle de la classe de **chaque** enfant
(`SchoolLevel.fromClassName`) : un parent avec un CE1 et un Terminale voit
désormais **deux fiches différentes**. Cahier de liaison, récompenses et cantine
n'apparaissent que sur la fiche du primaire.

> On ne peut pas utiliser `studentSchoolLevelProvider` ici : il décrit
> l'utilisateur connecté — le parent, qui n'a pas de niveau. Le niveau est une
> propriété de l'**enfant**.

## 10. Migration exécutée ✅ + boucle d'écriture complète

**`20260724_primary_tools.sql` a été exécutée.** Vérifié en direct : les 7 tables
répondent **200** (elles étaient à 404).

### Écrans d'écriture ajoutés (la boucle est fermée)
- **`TeacherRewardsPage`** (prof) : choisit une de ses classes, voit ses élèves,
  et attribue un **bon point** (motif, matière, 1–3 étoiles) ou décerne un
  **badge** du catalogue. Ne propose que les badges pas encore obtenus.
- **`AdminBadgesPage`** (direction) : crée le **catalogue de badges de l'école**
  (nom, condition, symbole). Sans lui, le prof n'aurait aucun badge à décerner.
  Gardé par `StaffPermissions.schoolConfig`.

Les badges appartiennent à l'école : chacune a ses traditions, on ne lui impose
pas une liste toute faite.

### ⚠️ 2ᵉ migration à exécuter — `20260725_propagate_primary_perms.sql`

L'avertissement n'était pas une hypothèse : **le schéma le prouve**. Un
`staff_role` ne lit pas son modèle — il en garde une **copie**
(`staff_role_permissions`), faite une fois à sa création, et rien ne les
resynchronise.

⇒ Dans toutes les écoles existantes, l'« Enseignant » **ne peut pas** écrire dans
le cahier ni attribuer de bon point. Il ouvrirait l'écran, taperait son mot, et
la RLS le refuserait.

Le script recopie les permissions des 3 nouveaux modules vers les rôles
instanciés **à partir d'un modèle**. Il ignore les rôles **personnalisés** (leurs
droits ont été choisis à la main par l'école — on ne s'y invite pas) et ne
supprime rien. Blocs VÉRIFICATION + ROLLBACK inclus.

## 11. Cantine — supprimée

Décision utilisateur : « on n'a pas besoin de cela pour l'instant ».
Retirée **du code** (page, provider, méthodes, modèles `SbCanteenMenu` /
`SbCanteenDish`, entrées de nav élève + tuile fiche enfant) **et de la base**
(`20260726_drop_canteen.sql`, exécutée — `canteen_menus` / `canteen_dishes` →
404, module de permission `cantine` supprimé). Les cinq autres tables sont
intactes. Les helpers `my_class_id()` / `has_child_in_class()` sont conservés :
le cahier de liaison s'en sert pour les mots adressés à toute une classe.

## 12. Permissions des profs — le piège du modèle d'origine ✅

`20260725_propagate_primary_perms.sql` : **exécutée**, et elle a failli être
fausse.

Un `staff_role` ne lit pas son modèle — il en garde une **copie** figée à sa
création. Les 4 profs avaient donc `droits_liaison = 0`.

**Le piège** : trois profs venaient du modèle commun (`11111111-…-006`), mais
**Jean Ngoubili venait de `c20390bf-…`** — un ancien modèle par cycle, d'avant
l'unification du 19 juillet. Une propagation « modèle → ses rôles » aurait servi
3 profs sur 4 et laissé Jean sans droits : un bug isolé, silencieux, et
incompréhensible depuis l'interface.

⇒ La migration fait la correspondance **par NOM de rôle**, pas par id de modèle.
Un « Enseignant » est un enseignant, quel que soit le modèle dont il vient.

**Vérifié en base** : `has_permission(..., 'liaison', 'ecrire')` et
`(..., 'recompenses', 'attribuer')` = **`true` pour les quatre**, Jean compris.

---

## 13. Reste à faire

1. **Tester dans l'app** — c'est maintenant la seule chose qui manque, et elle
   n'a **jamais** été faite. La chaîne complète : créer un badge (admin) →
   écrire un mot + donner un bon point (prof) → le lire et le **signer**
   (parent) → le voir apparaître (élève).
2. Toujours en attente : **Prépa Bac** (mock, lycée), la **création du compte
   parent** (pré-inscription = maquette), et le doublon de fonction
   `is_my_child` (1 arg / 2 args).

---

## État de compilation

`flutter analyze lib` → **0 erreur** sur l'ensemble du projet.
(Les ~1500 « issues » restantes sont des `info`/`warning` préexistants :
`withOpacity` déprécié, imports inutilisés, etc.)
