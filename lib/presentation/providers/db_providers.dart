import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/school_format.dart';
import '../../data/sources/remote/staff_roles_source.dart';
import '../../data/sources/remote/supabase_db_source.dart';
import '../../shared/data/features_catalog.dart';
import 'auth_providers.dart';

// ── École courante (tenant) ─────────────────────────────────────────────────
/// École active choisie via le sélecteur (Phase B — identité portable).
/// null = école par défaut du compte (`user.schoolId`). Une fois posée par le
/// sélecteur d'école, toutes les requêtes basculent sur cette école.
final activeSchoolIdProvider = StateProvider<String?>((ref) => null);

/// Identifiant de l'école courante. TOUTES les requêtes de données sont filtrées
/// dessus → isolation multi-tenant. Résolution : école **sélectionnée** (parmi
/// les adhésions) sinon l'école du compte. Si null, les providers renvoient une
/// liste vide plutôt que les données globales.
final currentSchoolIdProvider = Provider<String?>((ref) {
  final override = ref.watch(activeSchoolIdProvider);
  if (override != null && override.isNotEmpty) return override;
  return ref.watch(authSessionProvider)?.schoolId;
});

/// Adhésions (écoles) du compte connecté — source du sélecteur d'école.
/// Fail-safe : [] tant que la migration `school_members` n'est pas appliquée
/// (l'app reste alors en mono-école via `currentSchoolIdProvider`).
final myMembershipsProvider = FutureProvider<List<SbMembership>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return SupabaseDbSource.getMyMemberships(session.id);
});

// ── School ────────────────────────────────────────────────────────────────────
final schoolProvider = FutureProvider<SbSchool?>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return null;
  return SupabaseDbSource.getSchool(schoolId);
});

/// Devise et barème de l'école courante.
///
/// À utiliser PARTOUT où l'on affiche un montant ou une note. Ne jamais écrire
/// « FCFA » ni « /20 » en dur : une école nigériane facture en nairas et note
/// sur 100.
///
/// Synchrone à dessein (valeurs par défaut tant que l'école n'est pas chargée) :
/// un montant ne doit pas faire clignoter l'écran en attendant la base.
final schoolFormatProvider = Provider<SchoolFormat>((ref) {
  final school = ref.watch(schoolProvider).asData?.value;
  return school?.format ?? const SchoolFormat();
});

// ── Rôles du personnel (RBAC granulaire) ────────────────────────────────────
/// Vrai si l'école a déjà au moins un rôle de personnel.
///
/// N'est plus utilisé pour bloquer l'accès au tableau de bord (cf. admin_home) :
/// les rôles se créent au fil des invitations. Conservé pour l'affichage.
final staffRolesConfiguredProvider = FutureProvider<bool>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return true;
  final roles = await StaffRolesSource.fetchStaffRoles(schoolId);
  return roles.isNotEmpty;
});

/// Modèles de rôles proposés à l'école.
///
/// Le catalogue ne dépend PLUS du cycle. Un secrétaire est un secrétaire, au
/// primaire comme au lycée — mêmes permissions, ligne pour ligne. Seul le nom du
/// chef changeait (Directeur / Principal / Proviseur / Recteur), et ce n'est que
/// du vocabulaire : son accès vient du drapeau administrateur, pas de son titre.
///
/// Filtrer par cycle avait un coût réel : un complexe scolaire (primaire +
/// collège + lycée, le cas courant) était traité comme un simple lycée, et on
/// lui cachait le Directeur du primaire et le Principal du collège.
///
/// Six rôles, valables partout, tous renommables.
/// Cf. supabase/migrations/20260719_common_role_templates.sql
final roleTemplatesProvider = FutureProvider<List<SbRoleTemplate>>((ref) async {
  return StaffRolesSource.fetchRoleTemplates('commun');
});

/// Rôles réellement créés dans l'école (se remplit au fil des invitations).
final staffRolesProvider = FutureProvider<List<SbStaffRole>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return const [];
  return StaffRolesSource.fetchStaffRoles(schoolId);
});

/// Catalogue global des modules et de leurs actions (référence, pas par école).
/// Sert à traduire un module coché en grants `module.action`.
final permissionCatalogProvider =
    FutureProvider<List<SbPermissionModule>>((ref) async {
  return StaffRolesSource.fetchPermissionCatalog();
});

// ── Students ──────────────────────────────────────────────────────────────────
final studentsProvider = FutureProvider<List<SbStudent>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getStudents(schoolId: schoolId);
});

final studentsByClassProvider = FutureProvider.family<List<SbStudent>, String>(
  (ref, classe) async {
    final schoolId = ref.watch(currentSchoolIdProvider);
    if (schoolId == null) return [];
    return SupabaseDbSource.getStudents(classe: classe, schoolId: schoolId);
  },
);

/// Dernières fiches élèves créées — feed d'activité du tableau de bord.
final recentStudentsProvider =
    FutureProvider<List<SbRecentStudent>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getRecentStudents(schoolId: schoolId);
});

// ── Branches (filiales / campus) ──────────────────────────────────────────────
final branchesProvider = FutureProvider<List<SbBranch>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getBranches(schoolId);
});

/// Campus actuellement sélectionné dans le shell (null = tous les campus).
final selectedBranchProvider = StateProvider<SbBranch?>((ref) => null);

final myStudentProfileProvider = FutureProvider<SbStudent?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  return SupabaseDbSource.getStudentByProfileId(session.id);
});

// ── Enfants du parent connecté ───────────────────────────────────────────────
/// Clé de voûte de l'espace parent : sans elle, aucun écran ne sait de quel
/// enfant il parle. Lit `parent_student` — le lien que l'admin écrit déjà à la
/// création d'un élève (`createOrLinkGuardian`) mais que personne ne lisait.
final myChildrenProvider = FutureProvider<List<SbStudent>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return SupabaseDbSource.getChildrenForParent(session.id);
});

/// Fiche d'un élève donné (vue parent — clé : studentId).
final studentByIdProvider =
    FutureProvider.family<SbStudent?, String>((ref, studentId) async {
  return SupabaseDbSource.getStudentById(studentId);
});

// ── Classes ───────────────────────────────────────────────────────────────────
final classesProvider = FutureProvider<List<SbClass>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  final branch = ref.watch(selectedBranchProvider);
  return SupabaseDbSource.getClasses(schoolId: schoolId, branchId: branch?.id);
});

// ── Emploi du temps (par classe) ─────────────────────────────────────────────
final schedulesForClassProvider =
    FutureProvider.family<List<SbSchedule>, String>((ref, classId) async {
  return SupabaseDbSource.getSchedulesForClass(classId);
});

// ── Affectations du prof connecté (scope des classes/matières) ───────────────
/// Ce qu'un enseignant a le droit d'enseigner. **Deux sources, et deux seules** —
/// les mêmes que `teaches_class()` en base, sans quoi l'écran et le verrou
/// diraient des choses différentes :
///
///  1. le **cours** (`course_teachers`) → la matière exacte dans cette classe
///     (cas du spécialiste collège/lycée, et du co-enseignant) ;
///  2. le **titulariat** (`classes.main_teacher_id`) → toute la classe, toutes
///     matières (cas de l'instituteur du primaire).
///
/// L'emploi du temps **n'en est plus une** (cf. 20260739) : il place dans la
/// semaine des cours qui existent déjà. Un prof enseigne donc même dans une
/// école qui n'a jamais saisi sa grille horaire — et c'est le cas le plus
/// courant la première année.
class TeacherAssignments {
  /// Toutes les classes que le prof enseigne (cours ∪ titulariat).
  final Set<String> classIds;
  /// classId → matières (subject_id) qu'il y enseigne, d'après ses cours.
  final Map<String, Set<String>> subjectsByClass;
  /// Classes dont il est titulaire (il y enseigne *toutes* les matières).
  final Set<String> titulaireClassIds;

  const TeacherAssignments({
    required this.classIds,
    required this.subjectsByClass,
    required this.titulaireClassIds,
  });

  static const empty = TeacherAssignments(
      classIds: {}, subjectsByClass: {}, titulaireClassIds: {});

  bool get isEmpty => classIds.isEmpty;
  bool teachesClass(String classId) => classIds.contains(classId);
  bool isTitulaire(String classId) => titulaireClassIds.contains(classId);
  Set<String> subjectsFor(String classId) =>
      subjectsByClass[classId] ?? const <String>{};
}

/// Les classes du prof connecté (celles où il enseigne réellement).
final teacherClassesProvider = FutureProvider<List<SbClass>>((ref) async {
  final assign = await ref.watch(teacherAssignmentsProvider.future);
  final all = await ref.watch(classesProvider.future);
  return all.where((c) => assign.teachesClass(c.id)).toList();
});

/// Emploi du temps complet du prof connecté (tous ses créneaux).
final teacherSchedulesProvider = FutureProvider<List<SbSchedule>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return SupabaseDbSource.getSchedulesForTeacher(session.id);
});

/// Nombre total d'élèves dans les classes du prof connecté.
final teacherStudentCountProvider = FutureProvider<int>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return 0;
  final assign = await ref.watch(teacherAssignmentsProvider.future);
  final allClasses = await ref.watch(classesProvider.future);
  final myClasses = allClasses.where((c) => assign.teachesClass(c.id));
  var total = 0;
  for (final c in myClasses) {
    final studs =
        await SupabaseDbSource.getStudents(classe: c.name, schoolId: schoolId);
    total += studs.length;
  }
  return total;
});

final teacherAssignmentsProvider = FutureProvider<TeacherAssignments>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return TeacherAssignments.empty;
  final teacherId = session.id;

  final courses = await SupabaseDbSource.getCoursesForTeacher(teacherId);
  final allClasses = await ref.watch(classesProvider.future);

  final subjectsByClass = <String, Set<String>>{};
  for (final c in courses) {
    final set = subjectsByClass.putIfAbsent(c.classId, () => <String>{});
    if (c.subjectId != null && c.subjectId!.isNotEmpty) set.add(c.subjectId!);
  }
  final titulaire =
      allClasses.where((c) => c.mainTeacherId == teacherId).map((c) => c.id).toSet();
  final classIds = <String>{...subjectsByClass.keys, ...titulaire};

  return TeacherAssignments(
    classIds: classIds,
    subjectsByClass: subjectsByClass,
    titulaireClassIds: titulaire,
  );
});

/// Enseignants de l'école courante (pour affecter un prof à un cours).
final teachersProvider = FutureProvider<List<SbUser>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  final users = await SupabaseDbSource.getUsers(schoolId: schoolId);
  return users.where((u) => u.role == 'teacher').toList();
});

// ── Subjects ──────────────────────────────────────────────────────────────────
/// Le **catalogue de l'école** — pas le programme d'une classe. Pour savoir ce
/// qu'une classe étudie (et avec quel coefficient), voir
/// [coursesForClassProvider].
final subjectsProvider = FutureProvider<List<SbSubject>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getSubjects(schoolId: schoolId);
});

// ── Matières types (subject_catalog) ─────────────────────────────────────────
/// Catalogue de matières types par cycle (référence). Sert de pré-rempli pour
/// le bouton « Charger les matières types ». Filtré par les cycles réels de
/// l'école (fallback : tous les cycles v1 si types non renseignés).
final subjectCatalogProvider =
    FutureProvider<List<SbSubjectCatalog>>((ref) async {
  final cycles = await ref.watch(schoolCyclesProvider.future);
  if (cycles.isEmpty) return SupabaseDbSource.getSubjectCatalog();
  return SupabaseDbSource.getSubjectCatalog(cycles: cycles);
});

// ── Cycles de l'école (déduits des types choisis à l'inscription) ────────────
/// Cycles pédagogiques de l'école (primaire/college/lycee…), dérivés de
/// `metadata.types`. Vide si non renseigné → on retombe sur tous les cycles v1.
final schoolCyclesProvider = FutureProvider<List<String>>((ref) async {
  final school = await ref.watch(schoolProvider.future);
  return school?.cycles ?? const [];
});

// ── Niveau scolaire de l'élève (dynamisme par type d'école) ──────────────────
/// Niveaux scolaires (enum catalogue) couverts par l'école, dérivés des *types*
/// choisis par l'admin à l'inscription (`schools.metadata.types`). Triés du plus
/// bas au plus élevé. Vide → l'école n'a pas renseigné ses types.
final schoolLevelsProvider = FutureProvider<List<SchoolLevel>>((ref) async {
  final school = await ref.watch(schoolProvider.future);
  final levels = <SchoolLevel>{};
  for (final t in school?.types ?? const <String>[]) {
    final l = SchoolLevel.fromSchoolType(t);
    if (l != null) levels.add(l);
  }
  final list = levels.toList()..sort((a, b) => a.index.compareTo(b.index));
  return list;
});

/// Niveau scolaire « actif » de l'élève connecté — **source de vérité unique**
/// pour filtrer les features/sections par niveau (primaire ≠ lycée ≠ fac).
/// Priorité : (1) le cycle réel de sa classe ; (2) le niveau le plus élevé
/// offert par l'école ; (3) lycée en dernier recours.
final studentSchoolLevelProvider = FutureProvider<SchoolLevel>((ref) async {
  final profile = await ref.watch(myStudentProfileProvider.future);
  final fromClass = SchoolLevel.fromClassName(profile?.niveau);
  if (fromClass != null) return fromClass;
  final levels = await ref.watch(schoolLevelsProvider.future);
  if (levels.isNotEmpty) return levels.last;
  return SchoolLevel.lycee;
});

// ── Niveaux de référence (class_levels) ──────────────────────────────────────
/// Niveaux disponibles pour créer des classes, filtrés par les cycles réels de
/// l'école (ex. une école primaire ne voit que CP→CM2). Si l'école n'a pas de
/// types renseignés, on propose tous les cycles v1 (primaire/collège/lycée).
/// Lus dynamiquement depuis `class_levels` — jamais codés en dur.
/// Filtré sur les cycles de l'école ET sur son système éducatif (déduit du
/// système choisi à l'inscription + du pays — cf. [SchoolTaxonomy]).
///
/// Le système était jusqu'ici codé en dur sur `francophone_africa` : une école
/// anglophone ou arabophone recevait donc les niveaux francophones, alors que
/// son propre catalogue existe (Form 1, Primary 1…). Il est maintenant lu.
final classLevelsProvider = FutureProvider<List<SbClassLevel>>((ref) async {
  final school = await ref.watch(schoolProvider.future);
  if (school == null) return const [];

  final cycles = school.cycles;
  // Types non renseignés : on ne sait pas. On retombe sur les cycles scolaires
  // par défaut plutôt que de ne rien proposer — mais on ne devine PAS.
  return SupabaseDbSource.getClassLevels(
    system: school.levelSystemType,
    cycles: cycles.isEmpty ? const ['primaire', 'college', 'lycee'] : cycles,
  );
});

// ── Grades ────────────────────────────────────────────────────────────────────
// (Clés par studentId / classId, qui appartiennent déjà à l'école courante.)
final gradesForStudentProvider = FutureProvider.family<List<SbGrade>, String>(
  (ref, studentId) async => SupabaseDbSource.getGradesForStudent(studentId),
);

final gradesForClassProvider = FutureProvider.family<List<SbGrade>, String>(
  (ref, classId) async => SupabaseDbSource.getGradesForClass(classId),
);

/// Notes pour (classId, subjectId, period) — utilisé par le carnet de notes prof.
/// Clé encodée : "classId|subjectId|period" pour compatibilité family<String>.
final gradesForClassSubjectPeriodProvider =
    FutureProvider.family<List<SbGrade>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 3) return [];
  return SupabaseDbSource.getGradesForClassSubjectPeriod(
      parts[0], parts[1], parts[2]);
});

// ── Bulletins officiels (report_cards) ───────────────────────────────────────
/// Bulletins d'une classe pour une période (vue admin). Clé : "classId|year|period".
///
/// Le bulletin est un document INTERNE : il reste chez l'administration et le
/// personnel autorisé. Ni l'élève ni le parent n'y accèdent — la base le refuse
/// désormais (cf. 20260729_unify_attendance.sql). Il n'y a donc plus de provider
/// « mes bulletins » : il n'aurait rien pu charger.
final reportCardsForClassProvider =
    FutureProvider.family<List<SbReportCard>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 3) return [];
  return SupabaseDbSource.getReportCardsForClass(parts[0], parts[1], parts[2]);
});

// ── Current student grades ────────────────────────────────────────────────────
final myGradesProvider = FutureProvider<List<SbGrade>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  return SupabaseDbSource.getGradesForStudent(session.id);
});

// ── Attendance ────────────────────────────────────────────────────────────────
final attendanceForClassProvider = FutureProvider.family<List<SbAttendance>, String>(
  (ref, classId) async => SupabaseDbSource.getAttendanceForClass(classId),
);

final myAbsencesProvider = FutureProvider<List<SbAbsence>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  return SupabaseDbSource.getAbsencesForStudent(session.id);
});

/// Absences d'un élève donné (vue parent — clé : studentId).
final absencesForStudentProvider =
    FutureProvider.family<List<SbAbsence>, String>((ref, studentId) async {
  return SupabaseDbSource.getAbsencesForStudent(studentId);
});

// ── Frais de scolarité (grille) ──────────────────────────────────────────────
/// Grilles de frais de l'école courante pour l'année académique en cours.
final feeStructuresProvider = FutureProvider<List<SbFeeStructure>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  final school = await ref.watch(schoolProvider.future);
  return SupabaseDbSource.getFeeStructures(schoolId, school?.academicYear ?? '');
});

// ── Devoirs (assignments + submissions) ──────────────────────────────────────
/// Devoirs publiés de la classe de l'élève connecté (vide si pas de classe).
final myAssignmentsProvider = FutureProvider<List<SbAssignment>>((ref) async {
  final profile = await ref.watch(myStudentProfileProvider.future);
  final classId = profile?.classId;
  if (classId == null || classId.isEmpty) return [];
  return SupabaseDbSource.getAssignmentsForClass(classId);
});

/// Remises de l'élève connecté (statut + note), à croiser par assignment_id.
final mySubmissionsProvider = FutureProvider<List<SbSubmission>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  return SupabaseDbSource.getSubmissionsForStudent(session.id);
});

// ── Invoices ──────────────────────────────────────────────────────────────────
final invoicesProvider = FutureProvider<List<SbInvoice>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getInvoices(schoolId: schoolId);
});

final myInvoicesProvider = FutureProvider<List<SbInvoice>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  return SupabaseDbSource.getInvoicesForStudent(session.id);
});

/// Factures d'un élève donné (vue parent — clé : studentId).
final invoicesForStudentProvider =
    FutureProvider.family<List<SbInvoice>, String>((ref, studentId) async {
  return SupabaseDbSource.getInvoicesForStudent(studentId);
});

/// Toutes les factures de TOUS les enfants du parent connecté, fusionnées.
/// (`myInvoicesProvider` cherchait les factures d'un élève portant l'id du
/// parent — il ne remontait donc jamais rien pour un parent.)
final myChildrenInvoicesProvider =
    FutureProvider<List<SbInvoice>>((ref) async {
  final children = await ref.watch(myChildrenProvider.future);
  final out = <SbInvoice>[];
  for (final c in children) {
    out.addAll(await ref.watch(invoicesForStudentProvider(c.id).future));
  }
  out.sort((a, b) => (b.dueDate ?? DateTime(2000))
      .compareTo(a.dueDate ?? DateTime(2000)));
  return out;
});

// ── Users ─────────────────────────────────────────────────────────────────────
final usersProvider = FutureProvider<List<SbUser>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getUsers(schoolId: schoolId);
});

// ── Config du formulaire d'inscription (par école) ──────────────────────────
/// JSON brut stocké sur `schools.enrollment_config` (null si jamais sauvegardé).
final enrollmentConfigProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return null;
  return SupabaseDbSource.getEnrollmentConfig(schoolId);
});

// ── Abonnement (SaaS) ───────────────────────────────────────────────────────
/// Les 3 offres (catalogue global).
final plansProvider = FutureProvider<List<SbPlan>>((ref) async {
  return SupabaseDbSource.getPlans();
});

/// Grille de prix du pays de l'école courante (défaut Congo).
final planPricesProvider = FutureProvider<List<SbPlanPrice>>((ref) async {
  return SupabaseDbSource.getPlanPrices();
});

/// L'abonnement de l'école courante (null si aucun).
final subscriptionProvider = FutureProvider<SbSubscription?>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return null;
  return SupabaseDbSource.getSubscription(schoolId);
});

/// Code de l'offre courante (simple/pro/max), null si aucun abonnement.
final currentPlanCodeProvider = FutureProvider<String?>((ref) async {
  final sub = await ref.watch(subscriptionProvider.future);
  return sub?.planCode;
});

/// Les comptes « familles » (parents + login élève) et le staff étendu
/// (finance, surveillance, secrétariat) sont réservés à Pro/Max.
/// En **Simple**, seuls Admin + Enseignants existent (cf. offers-and-gating).
final familyAccountsEnabledProvider = FutureProvider<bool>((ref) async {
  final code = await ref.watch(currentPlanCodeProvider.future);
  return code == 'pro' || code == 'max';
});

/// Le paiement en ligne (Mobile Money) est réservé aux offres Pro et Max :
/// en Simple, aucune famille n'a de compte pour payer dans l'app → manuel only.
final onlinePaymentEnabledProvider = FutureProvider<bool>((ref) async {
  final code = await ref.watch(currentPlanCodeProvider.future);
  return code == 'pro' || code == 'max';
});

/// Nombre d'élèves de l'école courante (usage vs limite).
final studentCountProvider = FutureProvider<int>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return 0;
  return SupabaseDbSource.getStudentCount(schoolId);
});

// ══════════════════════════════════════════════════════════════════════════
// Outils du PRIMAIRE — cahier de liaison, récompenses
//
// Tous sont paramétrés par `studentId` : ils servent aussi bien à l'élève
// (« moi ») qu'au parent (« mon enfant »), sans duplication. La RLS fait le
// tri en base — voir `20260724_primary_tools.sql`.
//
// ⚠️ `autoDispose` n'est pas une coquetterie ici. Ce sont des flux VIVANTS :
// l'enseignant écrit pendant que la famille a l'app ouverte. Sans autoDispose,
// un FutureProvider charge une fois et garde son résultat pour toute la
// session — un parent qui ouvre le cahier avant que le maître n'écrive verrait
// une page vide jusqu'au redémarrage de l'application. Avec autoDispose, le
// provider est jeté quand la page se ferme et rechargé à la réouverture.
// ══════════════════════════════════════════════════════════════════════════

/// Mots du cahier de liaison concernant un élève : ceux qui le visent
/// nommément ET ceux adressés à sa classe.
final liaisonEntriesForStudentProvider = FutureProvider.autoDispose
    .family<List<SbLiaisonEntry>, String>((ref, studentId) async {
  final student = await ref.watch(studentByIdProvider(studentId).future);
  return SupabaseDbSource.getLiaisonEntriesForStudent(
    studentId,
    classId: student?.classId,
  );
});

/// Mots écrits pour une classe (vue enseignant).
final liaisonEntriesForClassProvider = FutureProvider.autoDispose
    .family<List<SbLiaisonEntry>, String>((ref, classId) async {
  return SupabaseDbSource.getLiaisonEntriesForClass(classId);
});

/// Les accusés de réception déjà signés par le parent connecté.
/// Vide pour un élève : accuser réception est un acte de parent.
final myLiaisonAcksProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const {};
  return SupabaseDbSource.getMyLiaisonAcks(session.id);
});

/// Bons points d'un élève.
final meritPointsForStudentProvider = FutureProvider.autoDispose
    .family<List<SbMeritPoint>, String>((ref, studentId) async {
  return SupabaseDbSource.getMeritPointsForStudent(studentId);
});

/// Catalogue de badges de l'école (vue admin — sans les obtentions).
final badgeCatalogProvider =
    FutureProvider.autoDispose<List<SbBadge>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return const [];
  return SupabaseDbSource.getBadgeCatalog(schoolId);
});

/// Badges de l'école, marqués obtenus/non obtenus pour l'élève visé.
final badgesForStudentProvider = FutureProvider.autoDispose
    .family<List<SbBadge>, String>((ref, studentId) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return const [];
  return SupabaseDbSource.getBadgesForStudent(
    schoolId: schoolId,
    studentId: studentId,
  );
});

// ── Courses ────────────────────────────────────────────────────────────────
/// Cours d'une classe spécifique (admin : gestion par classe).
final coursesForClassProvider =
    FutureProvider.family<List<SbCourse>, String>((ref, classId) async {
  return SupabaseDbSource.getCoursesForClass(classId);
});

/// Tous les cours de l'école (vue admin globale).
final coursesForSchoolProvider =
    FutureProvider<List<SbCourse>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getCoursesForSchool(schoolId);
});

/// Les enseignants qui n'ont **aucune classe** : ni titulariat, ni cours.
///
/// Ils se connectent et ne peuvent rien faire — ni carnet, ni appel. Rien ne le
/// signalait à l'administration : on pouvait inviter un prof et l'oublier. C'est
/// à lui qu'il revenait de s'en plaindre. Cf. `teacherAssignmentsProvider` pour
/// les deux (et seules) sources d'affectation.
final teachersWithoutClassProvider = FutureProvider<Set<String>>((ref) async {
  final teachers = await ref.watch(teachersProvider.future);
  final courses = await ref.watch(coursesForSchoolProvider.future);
  final classes = await ref.watch(classesProvider.future);

  final assigned = <String>{
    for (final c in courses) ...c.teachers.map((t) => t.teacherId),
    for (final c in classes)
      if (c.mainTeacherId != null) c.mainTeacherId!,
  };

  return teachers
      .where((t) => !assigned.contains(t.id))
      .map((t) => t.id)
      .toSet();
});

/// Cours de l'élève connecté (déduit de sa classe via son profil).
final myCoursesProvider = FutureProvider<List<SbCourse>>((ref) async {
  final profile = await ref.watch(myStudentProfileProvider.future);
  final classId = profile?.classId;
  if (classId == null || classId.isEmpty) return [];
  return SupabaseDbSource.getCoursesForClass(classId);
});
  