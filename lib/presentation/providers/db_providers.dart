import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/remote/supabase_db_source.dart';
import '../../shared/data/features_catalog.dart';
import 'auth_providers.dart';

// ── École courante (tenant) ─────────────────────────────────────────────────
/// Identifiant de l'école de l'utilisateur connecté. TOUTES les requêtes de
/// données sont filtrées par cette valeur → isolation multi-tenant (chaque
/// école ne voit que ses propres données). Si null (pas connecté / pas d'école),
/// les providers renvoient une liste vide plutôt que les données globales.
final currentSchoolIdProvider = Provider<String?>((ref) {
  return ref.watch(authSessionProvider)?.schoolId;
});

// ── School ────────────────────────────────────────────────────────────────────
final schoolProvider = FutureProvider<SbSchool?>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return null;
  return SupabaseDbSource.getSchool(schoolId);
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

/// Enseignants de l'école courante (pour affecter un prof à un cours).
final teachersProvider = FutureProvider<List<SbUser>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  final users = await SupabaseDbSource.getUsers(schoolId: schoolId);
  return users.where((u) => u.role == 'teacher').toList();
});

// ── Subjects ──────────────────────────────────────────────────────────────────
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
final classLevelsProvider = FutureProvider<List<SbClassLevel>>((ref) async {
  final cycles = await ref.watch(schoolCyclesProvider.future);
  if (cycles.isEmpty) return SupabaseDbSource.getClassLevels();
  return SupabaseDbSource.getClassLevels(cycles: cycles);
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

// ── Current student grades ────────────────────────────────────────────────────
final myGradesProvider = FutureProvider<List<SbGrade>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  return SupabaseDbSource.getGradesForStudent(session.id);
});

/// Fiche élève de l'utilisateur connecté (matricule, classe…).
final myStudentProfileProvider = FutureProvider<SbStudent?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  return SupabaseDbSource.getStudentById(session.id);
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

// ── Messages ──────────────────────────────────────────────────────────────────
final messagesProvider = FutureProvider<List<SbMessage>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getMessages(schoolId: schoolId);
});

// ── Announcements ─────────────────────────────────────────────────────────────
final announcementsProvider = FutureProvider<List<SbAnnouncement>>((ref) async {
  final schoolId = ref.watch(currentSchoolIdProvider);
  if (schoolId == null) return [];
  return SupabaseDbSource.getAnnouncements(schoolId: schoolId);
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
