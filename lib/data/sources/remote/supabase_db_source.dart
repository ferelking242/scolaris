import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/bulletin/bulletin_math.dart';
import '../../../core/config/school_format.dart';
import '../../../core/config/school_taxonomy.dart';

// ── Entity models ─────────────────────────────────────────────────────────────

class SbStudent {
  final String id;
  final String nom;
  final String prenom;
  final String? email;
  final String? niveau;
  final String? classe;
  final String? classId;
  final String? matricule;
  final String? avatarUrl;
  final bool actif;

  const SbStudent({
    required this.id,
    required this.nom,
    required this.prenom,
    this.email,
    this.niveau,
    this.classe,
    this.classId,
    this.matricule,
    this.avatarUrl,
    this.actif = true,
  });

  String get fullName => '$prenom $nom';
  String get classGroup => classe ?? '';
  String get id_ => matricule ?? id.substring(0, 8).toUpperCase();

  // Modèle identité unifié (passe 3) : un élève = une ligne `users` (role=student)
  // + sa fiche `student_profiles` (matricule, classe). On dérive prenom/nom du
  // champ unique `full_name` pour garder cette façade stable côté UI.
  factory SbStudent.fromUserRow(Map<String, dynamic> j) {
    final sp  = _firstMap(j['student_profiles']);
    final cls = sp != null ? _firstMap(sp['classes']) : null;
    final full = (j['full_name'] as String? ?? '').trim();
    final sp2  = full.split(RegExp(r'\s+'));
    final prenom = sp2.isNotEmpty ? sp2.first : '';
    final nom    = sp2.length > 1 ? sp2.sublist(1).join(' ') : '';
    return SbStudent(
      id: j['id'] as String,
      nom: nom,
      prenom: prenom,
      email: j['email'] as String?,
      niveau: cls?['level'] as String?,
      classe: cls?['name'] as String?,
      classId: sp?['class_id'] as String?,
      matricule: sp?['matricule'] as String?,
      avatarUrl: j['avatar_url'] as String?,
      actif: (j['status'] as String? ?? 'active') == 'active',
    );
  }

  // Un embed PostgREST to-one peut revenir en Map ou en List selon le cas.
  static Map<String, dynamic>? _firstMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is List && v.isNotEmpty) return v.first as Map<String, dynamic>;
    return null;
  }
}

class SbBranch {
  final String id;
  final String schoolId;
  final String name;
  final String city;
  final String? address;

  const SbBranch({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.city,
    this.address,
  });

  factory SbBranch.fromJson(Map<String, dynamic> j) => SbBranch(
        id: j['id'] as String,
        schoolId: j['school_id'] as String,
        name: j['name'] as String? ?? j['city'] as String,
        city: j['city'] as String,
        address: j['address'] as String?,
      );
}

class SbClass {
  final String id;
  final String? schoolId;
  final String? branchId;
  final String name;
  final String? level;
  final String? section;
  final String? mainTeacherId;
  final String? room;
  final int maxStudents;
  final bool isActive;

  const SbClass({
    required this.id,
    this.schoolId,
    this.branchId,
    required this.name,
    this.level,
    this.section,
    this.mainTeacherId,
    this.room,
    this.maxStudents = 30,
    this.isActive = true,
  });

  factory SbClass.fromJson(Map<String, dynamic> j) => SbClass(
        id: j['id'] as String,
        schoolId: j['school_id'] as String?,
        branchId: j['branch_id'] as String?,
        name: j['name'] as String? ?? '',
        level: j['level'] as String?,
        section: j['section'] as String?,
        mainTeacherId: j['main_teacher_id'] as String?,
        room: j['room'] as String?,
        maxStudents: j['max_students'] as int? ?? 30,
        isActive: j['is_active'] as bool? ?? true,
      );
}

class SbSubject {
  final String id;
  final String name;
  final String? code;
  final int coefficient;
  final String? color;

  const SbSubject({
    required this.id,
    required this.name,
    this.code,
    this.coefficient = 1,
    this.color,
  });

  factory SbSubject.fromJson(Map<String, dynamic> j) => SbSubject(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        code: j['code'] as String?,
        coefficient: j['coefficient'] as int? ?? 1,
        color: j['color'] as String?,
      );
}

/// « Rien à générer » — mais **pourquoi** ?
///
/// L'écran affichait « Aucune note pour ce trimestre » dans trois situations
/// très différentes : classe vide, programme vide, notes absentes. L'admin
/// cherchait des notes qui existaient, alors que le vrai problème était ailleurs.
/// Un message faux coûte une demi-journée.
class ReportCardEmpty implements Exception {
  final String message;
  const ReportCardEmpty(this.message);
  @override
  String toString() => message;
}

class SbGrade {
  final String id;
  final String studentId;
  final String? subjectId;
  final String? subjectName;
  final double score;
  final double maxScore;
  final String? period;
  final String? type;

  /// Rang de la note dans son type : Devoir 1, Devoir 2, D.D → 1, 2, 3.
  ///
  /// Sans elle, la 2e note d'un même type écrasait la 1re : la contrainte
  /// d'unicité portait sur (élève, matière, période, type). Le modèle ne savait
  /// pas compter jusqu'à deux, et un bulletin congolais en demande trois.
  /// Cf. 20260740.
  final int sequence;

  final String? title;
  final String? comment;
  final DateTime? gradedAt;
  final String? teacherId;

  const SbGrade({
    required this.id,
    required this.studentId,
    this.subjectId,
    this.subjectName,
    required this.score,
    this.maxScore = 20,
    this.period,
    this.type,
    this.sequence = 1,
    this.title,
    this.comment,
    this.gradedAt,
    this.teacherId,
  });

  double get outOf20 => maxScore > 0 ? (score / maxScore) * 20 : score;

  factory SbGrade.fromJson(Map<String, dynamic> j) {
    final subjectsMap = j['subjects'] as Map<String, dynamic>?;
    return SbGrade(
      id: j['id'] as String,
      studentId: j['student_id'] as String? ?? '',
      subjectId: j['subject_id'] as String?,
      subjectName: subjectsMap?['name'] as String?,
      score: (j['score'] as num?)?.toDouble() ?? 0,
      maxScore: (j['max_score'] as num?)?.toDouble() ?? 20,
      period: j['period'] as String?,
      type: j['type'] as String?,
      sequence: (j['sequence'] as num?)?.toInt() ?? 1,
      title: j['title'] as String?,
      comment: j['comment'] as String?,
      gradedAt: j['graded_at'] != null ? DateTime.tryParse(j['graded_at'] as String) : null,
      teacherId: j['teacher_id'] as String?,
    );
  }
}

// ── Bulletin officiel (figé à la publication) ───────────────────────────────
class SbReportCardLine {
  final String subject;
  final int coef;
  final double average;        // /20
  final String appreciation;
  const SbReportCardLine({
    required this.subject,
    required this.coef,
    required this.average,
    required this.appreciation,
  });
  factory SbReportCardLine.fromJson(Map<String, dynamic> j) => SbReportCardLine(
        subject: j['subject'] as String? ?? '—',
        coef: (j['coef'] as num?)?.toInt() ?? 1,
        average: (j['average'] as num?)?.toDouble() ?? 0,
        appreciation: j['appreciation'] as String? ?? '',
      );
  Map<String, dynamic> toJson() => {
        'subject': subject,
        'coef': coef,
        'average': average,
        'appreciation': appreciation,
      };
}

class SbReportCard {
  final String id;
  final String studentId;
  final String? studentName;
  final String classId;
  final String academicYear;
  final String period;          // 'T1' | 'T2' | 'T3'
  final List<SbReportCardLine> lines;
  final double generalAverage;
  final int? rank;
  final int? classSize;
  final String? mention;
  final String status;          // 'draft' | 'published'
  final DateTime? publishedAt;

  const SbReportCard({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.classId,
    required this.academicYear,
    required this.period,
    this.lines = const [],
    this.generalAverage = 0,
    this.rank,
    this.classSize,
    this.mention,
    this.status = 'draft',
    this.publishedAt,
  });

  bool get isPublished => status == 'published';

  factory SbReportCard.fromJson(Map<String, dynamic> j) {
    final raw = j['lines'];
    final list = raw is List ? raw : const [];
    return SbReportCard(
      id: j['id'] as String,
      studentId: j['student_id'] as String? ?? '',
      studentName: j['student_name'] as String?,
      classId: j['class_id'] as String? ?? '',
      academicYear: j['academic_year'] as String? ?? '',
      period: j['period'] as String? ?? '',
      lines: list
          .map((e) => SbReportCardLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      generalAverage: (j['general_average'] as num?)?.toDouble() ?? 0,
      rank: (j['rank'] as num?)?.toInt(),
      classSize: (j['class_size'] as num?)?.toInt(),
      mention: j['mention'] as String?,
      status: j['status'] as String? ?? 'draft',
      publishedAt: j['published_at'] != null
          ? DateTime.tryParse(j['published_at'] as String)
          : null,
    );
  }
}

class SbAttendance {
  final String id;
  final String studentId;
  final String? classId;
  final DateTime? date;
  final String status;
  final String? arrivalTime;
  final bool justified;

  const SbAttendance({
    required this.id,
    required this.studentId,
    this.classId,
    this.date,
    this.status = 'present',
    this.arrivalTime,
    this.justified = false,
  });

  factory SbAttendance.fromJson(Map<String, dynamic> j) => SbAttendance(
        id: j['id'] as String,
        studentId: j['student_id'] as String? ?? '',
        classId: j['class_id'] as String?,
        date: j['absence_date'] != null
            ? DateTime.tryParse(j['absence_date'] as String)
            : null,
        status: j['status'] as String? ?? 'present',
        arrivalTime: j['arrival_time'] as String?,
        justified: j['justified'] as bool? ?? false,
      );
}

class SbAbsence {
  final String id;
  final String studentId;
  final String? classId;
  final DateTime? absenceDate;

  /// `present` | `late` | `absent` | `excused` — une vraie colonne.
  /// L'app écrivait auparavant « retard » dans `period`, un champ prévu pour le
  /// trimestre : le statut se devinait alors par comparaison de texte.
  final String status;
  final bool justified;
  final String? reason;

  const SbAbsence({
    required this.id,
    required this.studentId,
    this.classId,
    this.absenceDate,
    this.status = 'absent',
    this.justified = false,
    this.reason,
  });

  factory SbAbsence.fromJson(Map<String, dynamic> j) => SbAbsence(
        id: j['id'] as String,
        studentId: j['student_id'] as String? ?? '',
        classId: j['class_id'] as String?,
        absenceDate: j['absence_date'] != null ? DateTime.tryParse(j['absence_date'] as String) : null,
        status: j['status'] as String? ?? 'absent',
        justified: j['justified'] as bool? ?? false,
        reason: j['reason'] as String?,
      );

  bool get isJustified => justified;
  String? get date {
    if (absenceDate == null) return null;
    const days = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    const months = ['Janvier','Février','Mars','Avril','Mai','Juin',
        'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
    final d = absenceDate!;
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class SbAssignment {
  final String id;
  final String classId;
  final String? subjectId;
  final String? subjectName;
  final String? teacherId;
  final String? teacherName;
  final String title;
  final String? description;
  final double? maxScore;
  final DateTime deadline;
  final bool allowLate;
  final bool isPublished;

  const SbAssignment({
    required this.id,
    required this.classId,
    this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
    required this.title,
    this.description,
    this.maxScore,
    required this.deadline,
    this.allowLate = false,
    this.isPublished = true,
  });

  factory SbAssignment.fromJson(Map<String, dynamic> j) {
    final subj = SbStudent._firstMap(j['subjects']);
    final teacher = SbStudent._firstMap(j['users']);
    return SbAssignment(
      id: j['id'] as String,
      classId: j['class_id'] as String? ?? '',
      subjectId: j['subject_id'] as String?,
      subjectName: subj?['name'] as String?,
      teacherId: j['teacher_id'] as String?,
      teacherName: teacher?['full_name'] as String?,
      title: j['title'] as String? ?? '',
      description: j['description'] as String?,
      maxScore: (j['max_score'] as num?)?.toDouble(),
      deadline: DateTime.tryParse(j['deadline'] as String? ?? '') ?? DateTime.now(),
      allowLate: j['allow_late'] as bool? ?? false,
      isPublished: j['is_published'] as bool? ?? true,
    );
  }
}

class SbSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String status; // pending | submitted | late | graded | returned
  final double? grade;
  final String? feedback;
  final DateTime? submittedAt;
  final bool isLate;

  const SbSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.status = 'pending',
    this.grade,
    this.feedback,
    this.submittedAt,
    this.isLate = false,
  });

  bool get isSubmitted =>
      status == 'submitted' || status == 'late' ||
      status == 'graded' || status == 'returned' || submittedAt != null;
  bool get isGraded => grade != null || status == 'graded';

  factory SbSubmission.fromJson(Map<String, dynamic> j) => SbSubmission(
        id: j['id'] as String,
        assignmentId: j['assignment_id'] as String? ?? '',
        studentId: j['student_id'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        grade: (j['grade'] as num?)?.toDouble(),
        feedback: j['feedback'] as String?,
        submittedAt: j['submitted_at'] != null
            ? DateTime.tryParse(j['submitted_at'] as String)
            : null,
        isLate: j['is_late'] as bool? ?? false,
      );
}

class SbFeeStructure {
  final String id;
  final String classId;
  final String academicYear;
  final String rhythm;          // 'monthly' | 'term'
  final int periodsCount;
  final double amountPerPeriod;
  final int startMonth;         // 1-12
  final int dueDay;             // 1-28
  final String currency;
  final bool isActive;

  const SbFeeStructure({
    required this.id,
    required this.classId,
    required this.academicYear,
    this.rhythm = 'monthly',
    this.periodsCount = 10,
    required this.amountPerPeriod,
    this.startMonth = 9,
    this.dueDay = 5,
    this.currency = 'XAF',
    this.isActive = true,
  });

  factory SbFeeStructure.fromJson(Map<String, dynamic> j) => SbFeeStructure(
        id: j['id'] as String,
        classId: j['class_id'] as String? ?? '',
        academicYear: j['academic_year'] as String? ?? '',
        rhythm: j['rhythm'] as String? ?? 'monthly',
        periodsCount: j['periods_count'] as int? ?? 10,
        amountPerPeriod: (j['amount_per_period'] as num?)?.toDouble() ?? 0,
        startMonth: j['start_month'] as int? ?? 9,
        dueDay: j['due_day'] as int? ?? 5,
        currency: j['currency'] as String? ?? 'XAF',
        isActive: j['is_active'] as bool? ?? true,
      );
}

class SbInvoice {
  final String id;
  final String? studentId;
  final String? studentName;
  final String? invoiceNumber;
  final String? description;
  final double amount;
  final String currency;
  final DateTime? dueDate;
  final String status;
  final String? period;     // ex. '2025-09' ou '2025-T1' (scolarité)
  final String? category;   // ex. 'tuition'

  const SbInvoice({
    required this.id,
    this.studentId,
    this.studentName,
    this.invoiceNumber,
    this.description,
    required this.amount,
    this.currency = 'XAF',
    this.dueDate,
    this.status = 'pending',
    this.period,
    this.category,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';
  bool get isTuition => category == 'tuition';

  /// En retard « réel » : non payé et échéance dépassée (le statut reste
  /// souvent 'pending' même après l'échéance).
  bool get isLate {
    if (isPaid || status == 'cancelled') return false;
    final d = dueDate;
    if (d == null) return isOverdue;
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }

  factory SbInvoice.fromJson(Map<String, dynamic> j) {
    final u = j['users'];
    final studentMap = u is Map<String, dynamic>
        ? u
        : (u is List && u.isNotEmpty ? u.first as Map<String, dynamic> : null);
    return SbInvoice(
      id: j['id'] as String,
      studentId: j['student_id'] as String?,
      studentName: (studentMap?['full_name'] as String?)?.trim(),
      invoiceNumber: j['invoice_number'] as String?,
      description: j['description'] as String?,
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      currency: j['currency'] as String? ?? 'XAF',
      dueDate: j['due_date'] != null ? DateTime.tryParse(j['due_date'] as String) : null,
      status: j['status'] as String? ?? 'pending',
      period: j['period'] as String?,
      category: j['category'] as String?,
    );
  }
}

class SbPayment {
  final String id;
  final String? invoiceId;
  final String? studentId;
  final double amount;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? reference;

  const SbPayment({
    required this.id,
    this.invoiceId,
    this.studentId,
    required this.amount,
    this.paymentDate,
    this.paymentMethod,
    this.reference,
  });

  factory SbPayment.fromJson(Map<String, dynamic> j) => SbPayment(
        id: j['id'] as String,
        invoiceId: j['invoice_id'] as String?,
        studentId: j['student_id'] as String?,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        paymentDate: j['payment_date'] != null ? DateTime.tryParse(j['payment_date'] as String) : null,
        paymentMethod: j['payment_method'] as String?,
        reference: j['reference'] as String?,
      );
}

class SbUser {
  final String id;
  final String? schoolId;
  final String? authUid;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String role;
  final String status;
  final DateTime? lastSeenAt;
  /// Projection plate des droits du rôle (cf. RbacMapping). Dérivée, pas saisie :
  /// la source de vérité est [staffRoleId] → `staff_role_permissions`.
  final List<String> permissions;
  final String? roleTitle;

  /// Rôle du personnel porté par cet employé (`staff_roles.id`). Null pour les
  /// élèves, parents, et les comptes staff créés avant la bascule RBAC.
  final String? staffRoleId;

  /// La colonne existait en base et servait déjà aux élèves/parents ; elle
  /// n'était simplement jamais lue ni demandée pour le personnel.
  final String? phone;

  const SbUser({
    required this.id,
    this.schoolId,
    this.authUid,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.role,
    this.status = 'active',
    this.lastSeenAt,
    this.permissions = const [],
    this.roleTitle,
    this.staffRoleId,
    this.phone,
  });

  bool get isActive => status == 'active';

  factory SbUser.fromJson(Map<String, dynamic> j) => SbUser(
        id: j['id'] as String,
        schoolId: j['school_id'] as String?,
        authUid: j['auth_uid'] as String?,
        fullName: j['full_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String?,
        role: j['role'] as String? ?? 'student',
        status: j['status'] as String? ?? 'active',
        lastSeenAt: j['last_seen_at'] != null ? DateTime.tryParse(j['last_seen_at'] as String) : null,
        permissions: j['permissions'] is List
            ? (j['permissions'] as List).map((e) => e.toString()).toList()
            : const [],
        roleTitle: j['role_title'] as String?,
        staffRoleId: j['staff_role_id'] as String?,
        phone: j['phone'] as String?,
      );
}

/// Fiche du personnel (table `staff_profiles`).
///
/// Pendant de `teacher_profiles` pour le personnel non enseignant, qui n'avait
/// aucune fiche jusqu'ici. Le téléphone vit sur `users.phone` (colonne commune à
/// tous les rôles), pas ici.
class SbStaffProfile {
  final String userId;
  final String schoolId;
  final String? employeeId;
  final String? gender;
  final DateTime? dateOfBirth;
  final DateTime? joinDate;

  /// 'permanent' | 'vacataire' | 'prestataire'
  final String contractType;

  const SbStaffProfile({
    required this.userId,
    required this.schoolId,
    this.employeeId,
    this.gender,
    this.dateOfBirth,
    this.joinDate,
    this.contractType = 'permanent',
  });

  factory SbStaffProfile.fromJson(Map<String, dynamic> j) => SbStaffProfile(
        userId: j['user_id'] as String,
        schoolId: j['school_id'] as String,
        employeeId: j['employee_id'] as String?,
        gender: j['gender'] as String?,
        dateOfBirth: j['date_of_birth'] != null
            ? DateTime.tryParse(j['date_of_birth'] as String)
            : null,
        joinDate: j['join_date'] != null
            ? DateTime.tryParse(j['join_date'] as String)
            : null,
        contractType: j['contract_type'] as String? ?? 'permanent',
      );
}

class SbSchool {
  final String id;
  final String name;
  final String? code;
  final String? country;
  final String? city;
  final String? logoUrl;
  final String? accentColor;
  final String? academicYear;

  /// Types d'établissement choisis à l'inscription (metadata.types) :
  /// garderie, primaire, college, lycee, universite, technique, superieur, special.
  final List<String> types;

  /// Système éducatif choisi à l'inscription (metadata.educational_system) :
  /// francophone, anglophone, arabophone, lmd, grande_ecole.
  /// Attention : ce n'est PAS `class_levels.system_type` — la traduction dépend
  /// aussi du pays, et se fait dans [SchoolTaxonomy].
  final String? educationalSystem;

  /// Devise (ISO 4217) et barème de notation de l'école. Ne jamais coder « FCFA »
  /// ou « /20 » en dur : cf. [SchoolFormat].
  final String currency;
  final String gradingScale;

  /// Découpage de l'année : `trimester` (T1/T2/T3) ou `semester` (S1/S2).
  final String periodSystem;

  /// La formule du bulletin — elle appartient à l'école, pas au code.
  ///
  /// [bulletinDevoirs] : combien de devoirs par matière (CSBFE : 3, dont le
  /// « D.D »). Leur moyenne forme la « M.C ».
  /// [bulletinCompoWeight] : le poids de la composition. 0.5 → elle pèse autant
  /// que tous les devoirs réunis. Cf. [BulletinRules] et 20260740.
  final int bulletinDevoirs;
  final double bulletinCompoWeight;

  const SbSchool({
    required this.id,
    required this.name,
    this.code,
    this.country,
    this.city,
    this.logoUrl,
    this.accentColor,
    this.academicYear,
    this.types = const [],
    this.educationalSystem,
    this.currency = 'XAF',
    this.gradingScale = 'numeric_20',
    this.periodSystem = 'trimester',
    this.bulletinDevoirs = 3,
    this.bulletinCompoWeight = 0.5,
  });

  SchoolFormat get format => SchoolFormat(
        currency: currency,
        gradingScale: gradingScale,
        periodSystem: periodSystem,
      );

  /// Cycles du catalogue des niveaux correspondant aux types de l'école.
  /// Un complexe scolaire en a plusieurs. Vide = types non renseignés.
  List<String> get cycles => SchoolTaxonomy.cyclesOf(types);

  /// `class_levels.system_type` de cette école (système + pays + types).
  ///
  /// Les types comptent : une université ne cherche pas ses niveaux dans le même
  /// catalogue qu'un lycée, même à système et pays identiques.
  String get levelSystemType => SchoolTaxonomy.systemTypeOf(
        system: educationalSystem,
        country: country,
        types: types,
      );

  factory SbSchool.fromJson(Map<String, dynamic> j) {
    final meta = j['metadata'];
    final rawTypes = meta is Map ? meta['types'] : null;
    return SbSchool(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      code: j['code'] as String?,
      country: j['country'] as String?,
      educationalSystem:
          meta is Map ? meta['educational_system'] as String? : null,
      currency: j['currency'] as String? ?? 'XAF',
      gradingScale: j['grading_scale'] as String? ?? 'numeric_20',
      periodSystem: j['period_system'] as String? ?? 'trimester',
      bulletinDevoirs: (j['bulletin_devoirs'] as num?)?.toInt() ?? 3,
      bulletinCompoWeight:
          (j['bulletin_compo_weight'] as num?)?.toDouble() ?? 0.5,
      city: j['city'] as String?,
      logoUrl: j['logo_url'] as String?,
      accentColor: j['accent_color'] as String?,
      academicYear: j['academic_year'] as String?,
      types: rawTypes is List
          ? rawTypes.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class SbPlan {
  final String code;
  final String name;
  final String? tagline;
  final int? maxStudents; // null = illimité
  final List<String> features;
  final int sortOrder;

  const SbPlan({
    required this.code,
    required this.name,
    this.tagline,
    this.maxStudents,
    this.features = const [],
    this.sortOrder = 0,
  });

  bool get isUnlimited => maxStudents == null;
  String get limitLabel => maxStudents == null ? 'Illimité' : 'Jusqu\'à $maxStudents élèves';

  factory SbPlan.fromJson(Map<String, dynamic> j) => SbPlan(
        code: j['code'] as String,
        name: j['name'] as String? ?? '',
        tagline: j['tagline'] as String?,
        maxStudents: j['max_students'] as int?,
        features: (j['features'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        sortOrder: j['sort_order'] as int? ?? 0,
      );
}

/// Niveau scolaire de référence (table `class_levels`). Lu dynamiquement selon
/// le système de l'école — JAMAIS codé en dur (cf. memory/admin-build-roadmap).
class SbClassLevel {
  final String id;
  final String systemType;
  final String cycle;       // prescolaire | primaire | college | lycee | ...
  final String cycleLabel;  // "Collège", "Lycée"…
  final String name;        // "6ème", "CP1", "2nde"…
  final String shortName;
  final String? series;     // filière lycée (A, C, D…) si applicable
  final int orderNum;

  const SbClassLevel({
    required this.id,
    required this.systemType,
    required this.cycle,
    required this.cycleLabel,
    required this.name,
    required this.shortName,
    this.series,
    this.orderNum = 0,
  });

  String get fullLabel => '$cycleLabel · $name';

  factory SbClassLevel.fromJson(Map<String, dynamic> j) => SbClassLevel(
        id: j['id'] as String,
        systemType: j['system_type'] as String? ?? '',
        cycle: j['cycle'] as String? ?? '',
        cycleLabel: j['cycle_label'] as String? ?? '',
        name: j['name'] as String? ?? '',
        shortName: j['short_name'] as String? ?? '',
        series: j['series'] as String?,
        orderNum: j['order_num'] as int? ?? 0,
      );
}

/// Ligne légère pour le feed d'activité « dernières inscriptions » du dashboard.
class SbRecentStudent {
  final String id;
  final String fullName;
  final String? className;
  final DateTime? createdAt;

  const SbRecentStudent({
    required this.id,
    required this.fullName,
    this.className,
    this.createdAt,
  });

  factory SbRecentStudent.fromJson(Map<String, dynamic> j) {
    final sp = SbStudent._firstMap(j['student_profiles']);
    final cls = sp != null ? SbStudent._firstMap(sp['classes']) : null;
    return SbRecentStudent(
      id: j['id'] as String,
      fullName: (j['full_name'] as String? ?? '').trim(),
      className: cls?['name'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
    );
  }
}

/// Un cours hebdomadaire dans l'emploi du temps d'une classe.
class SbSchedule {
  final String id;
  final String classId;
  final String? subjectId;
  final String? subjectName;
  final String? teacherId;
  final String? teacherName;
  final int dayOfWeek; // 1 = lundi … 6 = samedi
  final String startTime; // 'HH:mm'
  final String endTime;
  final String? room;

  const SbSchedule({
    required this.id,
    required this.classId,
    this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
  });

  static String _hhmm(String? t) =>
      (t == null || t.length < 5) ? (t ?? '') : t.substring(0, 5);

  factory SbSchedule.fromJson(Map<String, dynamic> j) {
    final subj = SbStudent._firstMap(j['subjects']);
    final teacher = SbStudent._firstMap(j['users']);
    return SbSchedule(
      id: j['id'] as String,
      classId: j['class_id'] as String,
      subjectId: j['subject_id'] as String?,
      subjectName: subj?['name'] as String?,
      teacherId: j['teacher_id'] as String?,
      teacherName: teacher?['full_name'] as String?,
      dayOfWeek: (j['day_of_week'] as num?)?.toInt() ?? 1,
      startTime: _hhmm(j['start_time'] as String?),
      endTime: _hhmm(j['end_time'] as String?),
      room: j['room'] as String?,
    );
  }
}

/// Matière « type » du catalogue de référence (par cycle). Sert de pré-rempli :
/// l'admin la charge dans ses matières au lieu de tout saisir.
class SbSubjectCatalog {
  final String id;
  final String cycle;       // primaire | college | lycee
  final String name;
  final String? shortName;
  final num defaultCoefficient;
  final int orderNum;

  const SbSubjectCatalog({
    required this.id,
    required this.cycle,
    required this.name,
    this.shortName,
    this.defaultCoefficient = 1,
    this.orderNum = 0,
  });

  factory SbSubjectCatalog.fromJson(Map<String, dynamic> j) => SbSubjectCatalog(
        id: j['id'] as String,
        cycle: j['cycle'] as String? ?? '',
        name: j['name'] as String? ?? '',
        shortName: j['short_name'] as String?,
        defaultCoefficient: (j['default_coefficient'] as num?) ?? 1,
        orderNum: j['order_num'] as int? ?? 0,
      );

  String get cycleLabel => switch (cycle) {
        'primaire' => 'Primaire',
        'college' => 'Collège',
        'lycee' => 'Lycée',
        _ => cycle,
      };
}

// ── Course (cours par classe) ─────────────────────────────────────────────────
/// Représente un cours créé par l'admin pour une classe donnée.
/// Lié à une matière (subject) + un enseignant + une classe.
/// Adhésion d'un compte à une école (Phase B — identité portable).
class SbMembership {
  final String id;
  final String userId;
  final String schoolId;
  final String? schoolName;
  final String? role;
  final String status; // active | pending | revoked
  const SbMembership({
    required this.id,
    required this.userId,
    required this.schoolId,
    this.schoolName,
    this.role,
    this.status = 'active',
  });

  factory SbMembership.fromJson(Map<String, dynamic> j) {
    final school = SbStudent._firstMap(j['schools']);
    return SbMembership(
      id: j['id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      schoolId: j['school_id'] as String? ?? '',
      schoolName: school?['name'] as String?,
      role: j['role'] as String?,
      status: j['status'] as String? ?? 'active',
    );
  }
}

class SbCourse {
  final String id;
  final String schoolId;
  final String classId;

  /// La MATIÈRE dont ce cours est le programme.
  ///
  /// Un cours n'avait qu'un `name` : il n'était relié à aucune matière, donc à
  /// rien du tout — ni aux notes, ni aux bulletins, ni à l'emploi du temps. Son
  /// coefficient n'était même pas lu. Cf. 20260738.
  final String? subjectId;

  final String name;
  final String? code;

  /// Les enseignants de ce cours — **plusieurs** possibles.
  ///
  /// Le co-enseignement est la règle au primaire (le maître fait français et
  /// maths, la maîtresse éveil et anglais) et arrive ailleurs. Tous ont les
  /// mêmes droits : noter, faire l'appel. Cf. 20260739.
  ///
  /// C'est la source **unique** des droits d'un prof sur une classe, avec le
  /// titulariat. L'emploi du temps n'en est plus une : il ne fait que placer
  /// ces cours dans la semaine.
  final List<SbCourseTeacher> teachers;

  /// Poids de la matière **dans cette classe** : au lycée, les maths pèsent 5
  /// en série C et 2 en série A. Hérite du coefficient de la matière.
  final int coefficient;

  final int? hoursWeek;
  final String? description;
  final String? color;
  final String? icon;
  final String? programSummary;
  final int? chapterCount;
  final List<String> daysOfWeek;
  final String? room;

  const SbCourse({
    required this.id,
    required this.schoolId,
    required this.classId,
    this.subjectId,
    required this.name,
    this.code,
    this.teachers = const [],
    this.coefficient = 1,
    this.hoursWeek,
    this.description,
    this.color,
    this.icon,
    this.programSummary,
    this.chapterCount,
    this.daysOfWeek = const [],
    this.room,
  });

  /// Les noms des enseignants, prêts à afficher. Vide = personne n'enseigne
  /// cette matière dans cette classe — l'admin doit s'en apercevoir.
  String get teacherNames => teachers.map((t) => t.fullName).join(', ');

  /// Idem, mais `null` quand il n'y a personne : pour les écrans qui masquent
  /// la ligne « Enseignant » plutôt que d'afficher un vide.
  String? get teacherName => teachers.isEmpty ? null : teacherNames;

  bool isTaughtBy(String teacherId) =>
      teachers.any((t) => t.teacherId == teacherId);

  factory SbCourse.fromJson(Map<String, dynamic> j) {
    final rawDays = j['days_of_week'];
    final days = rawDays is List ? rawDays.cast<String>() : <String>[];
    final rawTeachers = j['course_teachers'];
    return SbCourse(
      id: j['id'] as String,
      schoolId: j['school_id'] as String? ?? '',
      classId: j['class_id'] as String? ?? '',
      subjectId: j['subject_id'] as String?,
      name: j['name'] as String? ?? '',
      code: j['code'] as String?,
      teachers: rawTeachers is List
          ? rawTeachers
              .map((t) => SbCourseTeacher.fromJson(t as Map<String, dynamic>))
              .toList()
          : const [],
      coefficient: (j['coef'] as num?)?.toInt() ?? 1,
      hoursWeek: (j['hours_week'] as num?)?.toInt(),
      description: j['description'] as String?,
      color: j['color'] as String?,
      icon: j['icon'] as String?,
      programSummary: j['program_summary'] as String?,
      chapterCount: (j['chapter_count'] as num?)?.toInt(),
      daysOfWeek: days,
      room: j['room'] as String?,
    );
  }
}

/// Un enseignant rattaché à un cours.
///
/// `role` n'est qu'un **affichage** : « principal » et « co » ont exactement
/// les mêmes droits. Ne jamais s'en servir pour décider d'une autorisation.
class SbCourseTeacher {
  final String id;
  final String teacherId;
  final String fullName;
  final String role; // 'principal' | 'co'

  const SbCourseTeacher({
    required this.id,
    required this.teacherId,
    required this.fullName,
    this.role = 'principal',
  });

  bool get isLead => role == 'principal';

  factory SbCourseTeacher.fromJson(Map<String, dynamic> j) {
    final user = j['users'] as Map<String, dynamic>?;
    return SbCourseTeacher(
      id: j['id'] as String? ?? '',
      teacherId: j['teacher_id'] as String? ?? '',
      fullName: user?['full_name'] as String? ?? '—',
      role: j['role'] as String? ?? 'principal',
    );
  }
}

  // ── Subscription / Plan types ─────────────────────────────────────────────────

  class SbPlanPrice {
    final String id;
    final String planCode;
    final String period; // 'monthly' | 'annual'
    final double price;
    final String currency;

    const SbPlanPrice({
      required this.id,
      required this.planCode,
      required this.period,
      required this.price,
      required this.currency,
    });

    factory SbPlanPrice.fromJson(Map<String, dynamic> j) => SbPlanPrice(
          id: j['id'] as String? ?? '',
          planCode: j['plan_code'] as String? ?? '',
          period: j['period'] as String? ?? 'monthly',
          price: (j['price'] as num?)?.toDouble() ?? 0,
          currency: j['currency'] as String? ?? 'XAF',
        );
  }

  class SbSubscription {
    final String id;
    final String? schoolId;
    final String? planCode;
    final String status; // 'trial'|'active'|'past_due'|'expired'|'canceled'
    final String? billingPeriod; // 'monthly' | 'annual'
    final double? price;
    final String currency;
    final double creditBalance;
    final DateTime? currentPeriodEnd;
    final DateTime? trialEnd;

    const SbSubscription({
      required this.id,
      this.schoolId,
      this.planCode,
      this.status = 'trial',
      this.billingPeriod,
      this.price,
      this.currency = 'XAF',
      this.creditBalance = 0,
      this.currentPeriodEnd,
      this.trialEnd,
    });

    bool get isTrial  => status == 'trial';
    bool get isActive => status == 'active' || status == 'trial';

    DateTime? get endDate => currentPeriodEnd ?? trialEnd;

    int get daysLeft {
      final end = endDate;
      if (end == null) return 0;
      return end.difference(DateTime.now()).inDays.clamp(0, 999);
    }

    factory SbSubscription.fromJson(Map<String, dynamic> j) => SbSubscription(
          id: j['id'] as String? ?? '',
          schoolId: j['school_id'] as String?,
          planCode: j['plan_code'] as String?,
          status: j['status'] as String? ?? 'trial',
          billingPeriod: j['billing_period'] as String?,
          price: (j['price'] as num?)?.toDouble(),
          currency: j['currency'] as String? ?? 'XAF',
          creditBalance: (j['credit_balance'] as num?)?.toDouble() ?? 0,
          currentPeriodEnd: j['current_period_end'] != null
              ? DateTime.tryParse(j['current_period_end'] as String)
              : null,
          trialEnd: j['trial_end'] != null
              ? DateTime.tryParse(j['trial_end'] as String)
              : null,
        );
  }

// ── Data source ───────────────────────────────────────────────────────────────

class SupabaseDbSource {
  static SupabaseClient get _db => Supabase.instance.client;

  // ── Students ──────────────────────────────────────────────────────────────
  static const String _studentSelect =
      'id, full_name, email, avatar_url, status, '
      'student_profiles(matricule, class_id, classes(name, level))';

  static Future<List<SbStudent>> getStudents({String? classe, String? schoolId}) async {
    var q = _db.from('users').select(_studentSelect).eq('role', 'student');
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('full_name');
    var list = (data as List)
        .map((j) => SbStudent.fromUserRow(j as Map<String, dynamic>))
        .toList();
    if (classe != null) list = list.where((s) => s.classe == classe).toList();
    return list;
  }

  static Future<SbStudent?> getStudentById(String userId) async {
    final data = await _db
        .from('users')
        .select(_studentSelect)
        .eq('id', userId)
        .maybeSingle();
    return data != null ? SbStudent.fromUserRow(data) : null;
  }

  /// Fiche élève à partir de l'id de profil/compte connecté. Dans ce schéma,
  /// l'élève EST un `users` (role='student'), donc l'id de session = users.id.
  static Future<SbStudent?> getStudentByProfileId(String profileId) =>
      getStudentById(profileId);

  /// Les enfants d'un parent, via la table de liaison `parent_student`.
  ///
  /// En deux requêtes plutôt qu'une jointure imbriquée : l'embed PostgREST
  /// dépendrait du nom exact de la contrainte FK, qui n'est pas garanti par le
  /// dépôt (cf. CLAUDE.md — le schéma réel n'y est pas versionné). Un parent a
  /// une poignée d'enfants, le second aller-retour est sans conséquence.
  static Future<List<SbStudent>> getChildrenForParent(String parentId) async {
    final links = await _db
        .from('parent_student')
        .select('student_id')
        .eq('parent_id', parentId);

    final ids = (links as List)
        .map((j) => (j as Map<String, dynamic>)['student_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];

    final data = await _db
        .from('users')
        .select(_studentSelect)
        .inFilter('id', ids)
        .order('full_name');

    return (data as List)
        .map((j) => SbStudent.fromUserRow(j as Map<String, dynamic>))
        .toList();
  }

  /// Dernières fiches élèves créées (pour le feed d'activité du tableau de bord).
  /// Renvoie nom + classe + date de création, triées du plus récent au plus ancien.
  static Future<List<SbRecentStudent>> getRecentStudents({
    required String schoolId,
    int limit = 6,
  }) async {
    final data = await _db
        .from('users')
        .select('id, full_name, created_at, '
            'student_profiles(classes(name))')
        .eq('role', 'student')
        .eq('school_id', schoolId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((j) => SbRecentStudent.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Affecte un élève à une classe (ou la change). Met à jour `class_id` sur
  /// sa fiche `student_profiles`.
  static Future<void> assignStudentToClass({
    required String userId,
    required String classId,
  }) async {
    await _db
        .from('student_profiles')
        .update({'class_id': classId})
        .eq('user_id', userId);
  }

  /// Retire un élève de sa classe (laisse la fiche, vide juste l'affectation).
  static Future<void> unassignStudentFromClass(String userId) async {
    await _db
        .from('student_profiles')
        .update({'class_id': null})
        .eq('user_id', userId);
  }

  // ── Classes ───────────────────────────────────────────────────────────────
  static Future<List<SbBranch>> getBranches(String schoolId) async {
    final data = await _db
        .from('school_branches')
        .select()
        .eq('school_id', schoolId)
        .order('city');
    return (data as List).map((j) => SbBranch.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<List<SbClass>> getClasses({String? schoolId, String? branchId}) async {
    var q = _db.from('classes').select().eq('is_active', true);
    if (schoolId != null) q = q.eq('school_id', schoolId);
    if (branchId != null) q = q.eq('branch_id', branchId);
    final data = await q.order('name');
    return (data as List).map((j) => SbClass.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── Subjects ──────────────────────────────────────────────────────────────
  static Future<List<SbSubject>> getSubjects({String? schoolId}) async {
    var q = _db.from('subjects').select();
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('name');
    return (data as List).map((j) => SbSubject.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Catalogue de matières types (référence, lecture seule). Filtré par cycles.
  static Future<List<SbSubjectCatalog>> getSubjectCatalog({
    String system = 'francophone_africa',
    List<String> cycles = const ['primaire', 'college', 'lycee'],
  }) async {
    final data = await _db
        .from('subject_catalog')
        .select()
        .eq('system_type', system)
        .inFilter('cycle', cycles)
        .order('order_num');
    return (data as List)
        .map((j) => SbSubjectCatalog.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createSubject({
    required String schoolId,
    required String name,
    String? code,
    num coefficient = 1,
    String? color,
  }) async {
    await _db.from('subjects').insert({
      'id': const Uuid().v4(),
      'school_id': schoolId,
      'name': name.trim(),
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      'coefficient': coefficient,
      if (color != null && color.isNotEmpty) 'color': color,
      'is_active': true,
    });
  }

  static Future<void> updateSubject({
    required String id,
    String? name,
    String? code,
    num? coefficient,
  }) async {
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name.trim();
    if (code != null) patch['code'] = code.trim();
    if (coefficient != null) patch['coefficient'] = coefficient;
    if (patch.isEmpty) return;
    await _db.from('subjects').update(patch).eq('id', id);
  }

  static Future<void> deleteSubject(String id) async {
    await _db.from('subjects').delete().eq('id', id);
  }

  /// Charge les matières types du catalogue dans les matières de l'école.
  /// N'ajoute que celles dont le nom n'existe pas déjà (insensible à la casse).
  /// Renvoie le nombre de matières réellement ajoutées.
  static Future<int> loadSubjectsFromCatalog({
    required String schoolId,
    required List<String> cycles,
  }) async {
    final catalog = await getSubjectCatalog(cycles: cycles);
    final existing = await getSubjects(schoolId: schoolId);
    final existingNames =
        existing.map((s) => s.name.trim().toLowerCase()).toSet();

    // Dédoublonne le catalogue par nom (une matière partagée entre cycles
    // n'est ajoutée qu'une fois) et ignore celles déjà présentes.
    final toAdd = <String, SbSubjectCatalog>{};
    for (final c in catalog) {
      final key = c.name.trim().toLowerCase();
      if (existingNames.contains(key) || toAdd.containsKey(key)) continue;
      toAdd[key] = c;
    }
    if (toAdd.isEmpty) return 0;

    final rows = [
      for (final c in toAdd.values)
        {
          'id': const Uuid().v4(),
          'school_id': schoolId,
          'name': c.name,
          if (c.shortName != null) 'code': c.shortName,
          'coefficient': c.defaultCoefficient,
          'is_active': true,
        }
    ];
    await _db.from('subjects').insert(rows);
    return rows.length;
  }

  // ── Grades ────────────────────────────────────────────────────────────────
  static Future<List<SbGrade>> getGradesForStudent(String studentId) async {
    final data = await _db
        .from('grades')
        .select('*, subjects(name, code)')
        .eq('student_id', studentId)
        .order('graded_at', ascending: false);
    return (data as List).map((j) => SbGrade.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<List<SbGrade>> getGradesForClass(String classId) async {
    final data = await _db
        .from('grades')
        .select('*, subjects(name, code)')
        .eq('class_id', classId)
        .order('graded_at', ascending: false);
    return (data as List).map((j) => SbGrade.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── Présences ─────────────────────────────────────────────────────────────
  //  UNE seule table : `absences`. Il y en avait deux — le prof faisait l'appel
  //  dans `attendance`, la famille lisait `absences`, et les deux ne se
  //  parlaient pas : une absence marquée n'apparaissait nulle part.
  //  Cf. supabase/migrations/20260729_unify_attendance.sql.

  static Future<List<SbAttendance>> getAttendanceForClass(String classId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final data = await _db
        .from('absences')
        .select()
        .eq('class_id', classId)
        .eq('absence_date', today);
    return (data as List).map((j) => SbAttendance.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Absences et retards de toute une classe — pour le bulletin, qui les
  /// compte par élève. On ne lit **que** ce qui fait défaut (`status <> present`) :
  /// une classe de 40 élèves sur un trimestre, c'est des milliers de lignes de
  /// présence dont le bulletin n'a rien à faire.
  static Future<List<SbAbsence>> getAbsencesForClass(String classId) async {
    final data = await _db
        .from('absences')
        .select()
        .eq('class_id', classId)
        .neq('status', 'present')
        .order('absence_date', ascending: false);
    return (data as List)
        .map((j) => SbAbsence.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<List<SbAbsence>> getAbsencesForStudent(String studentId) async {
    final data = await _db
        .from('absences')
        .select()
        .eq('student_id', studentId)
        .neq('status', 'present')   // l'élève ne lit que ce qui fait défaut
        .order('absence_date', ascending: false);
    return (data as List).map((j) => SbAbsence.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Enregistre l'appel du jour. Un élève, un jour, une ligne : on se corrige
  /// (upsert) au lieu d'empiler des présences contradictoires.
  static Future<void> saveAttendance(
    List<SbAttendance> records, {
    required String schoolId,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = records.map((r) => {
      'school_id': schoolId,
      'student_id': r.studentId,
      'class_id': r.classId,
      'absence_date': today,
      'status': r.status,
      'arrival_time': r.arrivalTime,
    }).toList();
    await _db
        .from('absences')
        .upsert(rows, onConflict: 'student_id,absence_date');
  }

  // ── Invoices ──────────────────────────────────────────────────────────────
  static Future<List<SbInvoice>> getInvoices({String? schoolId}) async {
    var q = _db.from('invoices').select('*, users!student_id(full_name)');
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('created_at', ascending: false);
    return (data as List).map((j) => SbInvoice.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Crée une facture (frais de scolarité) pour un élève. Statut « pending ».
  static Future<void> createInvoice({
    required String schoolId,
    required String studentId,
    required String description,
    required double amount,
    String? category,
    String? dueDate, // ISO yyyy-MM-dd
    // La devise vient de l'ECOLE (schools.currency), jamais d'un defaut code
    // en dur : une ecole nigeriane facture en nairas. Cf. SchoolFormat.
    required String currency,
  }) async {
    final now = DateTime.now();
    final number =
        'F-${now.year}${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    await _db.from('invoices').insert({
      'id': const Uuid().v4(),
      'school_id': schoolId,
      'student_id': studentId,
      'invoice_number': number,
      'description': description.trim(),
      'amount': amount,
      'currency': currency,
      if (category != null && category.isNotEmpty) 'category': category,
      'issued_date': now.toIso8601String().split('T').first,
      if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
      'status': 'pending',
    });
  }

  /// Enregistre un encaissement (espèces par défaut) et marque la facture payée.
  static Future<void> recordPayment({
    required String invoiceId,
    required String studentId,
    required double amount,
    String method = 'cash',
    String? reference,
  }) async {
    await _db.from('payments').insert({
      'id': const Uuid().v4(),
      'invoice_id': invoiceId,
      'student_id': studentId,
      'amount': amount,
      'payment_date': DateTime.now().toIso8601String().split('T').first,
      'payment_method': method,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    });
    await _db.from('invoices').update({
      'status': 'paid',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', invoiceId);
  }

  /// Supprime une facture (et ses encaissements éventuels).
  static Future<void> deleteInvoice(String invoiceId) async {
    await _db.from('payments').delete().eq('invoice_id', invoiceId);
    await _db.from('invoices').delete().eq('id', invoiceId);
  }

  static Future<List<SbInvoice>> getInvoicesForStudent(String studentId) async {
    final data = await _db
        .from('invoices')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return (data as List).map((j) => SbInvoice.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── Frais de scolarité (grille + génération de l'échéancier) ────────────────
  /// Grilles de frais de l'école pour une année (une par classe).
  static Future<List<SbFeeStructure>> getFeeStructures(
      String schoolId, String academicYear) async {
    final data = await _db
        .from('fee_structures')
        .select()
        .eq('school_id', schoolId)
        .eq('academic_year', academicYear);
    return (data as List)
        .map((j) => SbFeeStructure.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Crée ou met à jour la grille d'une classe (unique par classe+année).
  static Future<void> upsertFeeStructure({
    required String schoolId,
    required String classId,
    required String academicYear,
    required String rhythm,
    required int periodsCount,
    required double amountPerPeriod,
    required int startMonth,
    required int dueDay,
    // La devise vient de l'ECOLE (schools.currency), jamais d'un defaut code
    // en dur : une ecole nigeriane facture en nairas. Cf. SchoolFormat.
    required String currency,
  }) async {
    await _db.from('fee_structures').upsert({
      'school_id': schoolId,
      'class_id': classId,
      'academic_year': academicYear,
      'rhythm': rhythm,
      'periods_count': periodsCount,
      'amount_per_period': amountPerPeriod,
      'start_month': startMonth,
      'due_day': dueDay,
      'currency': currency,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'class_id,academic_year');
  }

  /// Périodes (libellé + échéance) déduites d'une grille.
  static List<({String period, DateTime due, String label})> tuitionPeriods(
      SbFeeStructure fee) {
    final startYear =
        int.tryParse(fee.academicYear.split('-').first) ?? DateTime.now().year;
    const moisFr = [
      'janvier','février','mars','avril','mai','juin',
      'juillet','août','septembre','octobre','novembre','décembre'
    ];
    final out = <({String period, DateTime due, String label})>[];
    final step = fee.rhythm == 'term' ? 3 : 1;
    for (int i = 0; i < fee.periodsCount; i++) {
      final m0 = fee.startMonth + i * step; // 1-based, peut dépasser 12
      final year = startYear + ((m0 - 1) ~/ 12);
      final month = ((m0 - 1) % 12) + 1;
      final due = DateTime(year, month, fee.dueDay);
      if (fee.rhythm == 'term') {
        out.add((
          period: '$startYear-T${i + 1}',
          due: due,
          label: 'Scolarité — ${i + 1}ᵉ tranche',
        ));
      } else {
        out.add((
          period: '$year-${month.toString().padLeft(2, '0')}',
          due: due,
          label: 'Scolarité — ${moisFr[month - 1]} $year',
        ));
      }
    }
    return out;
  }

  /// Génère l'échéancier annuel pour TOUS les élèves des classes ayant une
  /// grille. Idempotent : les échéances déjà créées (même élève + période) sont
  /// ignorées → ré-exécutable (rattrape les nouveaux élèves). Renvoie le nombre
  /// d'échéances créées.
  static Future<int> generateTuitionSchedule({
    required String schoolId,
    required String academicYear,
    String? createdBy,
  }) async {
    final fees = await getFeeStructures(schoolId, academicYear);
    final today = DateTime.now().toIso8601String().split('T').first;
    int inserted = 0;

    for (final fee in fees) {
      if (!fee.isActive) continue;
      final profs = await _db
          .from('student_profiles')
          .select('user_id')
          .eq('class_id', fee.classId);
      final studentIds =
          (profs as List).map((e) => e['user_id'] as String).toList();
      if (studentIds.isEmpty) continue;

      final periods = tuitionPeriods(fee);
      final periodLabels = periods.map((p) => p.period).toList();

      // Échéances déjà existantes pour ces périodes (anti-doublon).
      final existing = await _db
          .from('invoices')
          .select('student_id, period')
          .eq('school_id', schoolId)
          .eq('category', 'tuition')
          .inFilter('period', periodLabels);
      final existingSet = <String>{
        for (final e in existing as List) '${e['student_id']}|${e['period']}'
      };

      final rows = <Map<String, dynamic>>[];
      for (final sid in studentIds) {
        for (final p in periods) {
          if (existingSet.contains('$sid|${p.period}')) continue;
          rows.add({
            'school_id': schoolId,
            'student_id': sid,
            'description': p.label,
            'amount': fee.amountPerPeriod,
            'currency': fee.currency,
            'due_date': p.due.toIso8601String().split('T').first,
            'issued_date': today,
            'status': 'pending',
            'category': 'tuition',
            'period': p.period,
            if (createdBy != null) 'created_by': createdBy,
          });
        }
      }
      if (rows.isNotEmpty) {
        await _db.from('invoices').insert(rows);
        inserted += rows.length;
      }
    }
    return inserted;
  }

  // ── Bulletins officiels (report_cards) ──────────────────────────────────────

  static String _mentionFor(double avg) {
    if (avg >= 16) return 'Très Bien';
    if (avg >= 14) return 'Bien';
    if (avg >= 12) return 'Assez Bien';
    if (avg >= 10) return 'Passable';
    return 'Insuffisant';
  }

  static String _appreciationFor(double avg) {
    if (avg >= 16) return 'Excellent travail, continuez sur cette lancée.';
    if (avg >= 14) return 'Très bon résultat ce trimestre.';
    if (avg >= 12) return 'Bon niveau, peut encore progresser.';
    if (avg >= 10) return 'Résultat passable, des efforts sont nécessaires.';
    return 'Résultat insuffisant, un travail important est requis.';
  }

  /// Bulletins d'une classe pour un trimestre (tous statuts) — vue admin.
  static Future<List<SbReportCard>> getReportCardsForClass(
      String classId, String academicYear, String period) async {
    final data = await _db
        .from('report_cards')
        .select()
        .eq('class_id', classId)
        .eq('academic_year', academicYear)
        .eq('period', period)
        .order('rank');
    return (data as List)
        .map((j) => SbReportCard.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Bulletins d'un élève — vue INTERNE (administration, personnel autorisé).
  ///
  /// Aucun écran famille ne l'appelle : le bulletin ne se consulte pas en
  /// libre-service. La base l'interdit de toute façon (`report_cards` exige
  /// `notes.voir`), donc un appel depuis un compte élève ou parent reviendrait
  /// vide — pas en erreur, VIDE. C'est le genre de silence qui fait perdre une
  /// journée : ne rebranchez pas ceci côté famille.
  static Future<List<SbReportCard>> getReportCardsForStudent(
      String studentId) async {
    final data = await _db
        .from('report_cards')
        .select()
        .eq('student_id', studentId)
        .order('period');
    return (data as List)
        .map((j) => SbReportCard.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Génère (statut 'draft') les bulletins de TOUS les élèves d'une classe.
  ///
  /// Le calcul est celui de [buildBulletins] — **le seul**. Cette méthode avait
  /// le sien : une moyenne arithmétique de toutes les notes, sur le catalogue de
  /// matières de l'ÉCOLE et non sur le programme de la classe. C'était le
  /// troisième calcul de moyenne du projet, et le troisième à donner un chiffre
  /// différent des deux autres. Un bulletin figé faux, c'est un élève qui
  /// redouble à tort — et le document est archivé, donc l'erreur survit.
  ///
  /// Le bulletin est une PHOTO : on fige les lignes, le rang, les repères de la
  /// classe. Il doit rester lisible dans dix ans, même si l'école a changé ses
  /// coefficients depuis.
  ///
  /// Jette [ReportCardEmpty] plutôt que de renvoyer 0 : « rien à générer » a
  /// deux causes très différentes — pas d'élèves, ou pas de notes — et l'admin
  /// doit savoir laquelle.
  static Future<int> generateReportCards({
    required String schoolId,
    required String classId,
    required String academicYear,
    required String period,
    String? createdBy,
  }) async {
    final students = (await getStudents(schoolId: schoolId))
        .where((s) => s.classId == classId)
        .toList();
    if (students.isEmpty) {
      throw const ReportCardEmpty('Cette classe n’a aucun élève.');
    }

    final programme = await getCoursesForClass(classId);
    if (programme.every((c) => c.subjectId == null)) {
      throw const ReportCardEmpty(
          'Cette classe n’a aucune matière à son programme. '
          'Ajoutez-les dans « Cours ».');
    }

    final school = await getSchool(schoolId);
    final grades = (await getGradesForClass(classId))
        .where((g) => g.period == period)
        .toList();
    if (grades.isEmpty) {
      throw const ReportCardEmpty(
          'Aucune note saisie pour cette période dans cette classe.');
    }

    final absences = await getAbsencesForClass(classId);
    final attendance = <String, ({int absences, int lates})>{};
    for (final a in absences) {
      final cur = attendance[a.studentId] ?? (absences: 0, lates: 0);
      attendance[a.studentId] = a.status == 'late'
          ? (absences: cur.absences, lates: cur.lates + 1)
          : (absences: cur.absences + 1, lates: cur.lates);
    }

    final bulletins = buildBulletins(
      studentIds: students.map((s) => s.id).toList(),
      programme: programme,
      grades: grades,
      rules: BulletinRules.fromSchool(school),
      attendance: attendance,
    );

    final now = DateTime.now().toIso8601String();
    final rows = <Map<String, dynamic>>[];
    for (final st in students) {
      final b = bulletins[st.id];
      if (b == null || b.isEmpty) continue; // un élève sans note n'a pas de bulletin
      rows.add({
        'school_id': schoolId,
        'student_id': st.id,
        'student_name': st.fullName,
        'class_id': classId,
        'academic_year': academicYear,
        'period': period,
        'lines': b.lines.map((l) => l.toJson()).toList(),
        'general_average': b.average,
        'rank': b.rank,
        'class_size': b.classSize,
        'class_average': b.classAverage,
        'best_average': b.bestAverage,
        'worst_average': b.worstAverage,
        'absences_count': b.absences,
        'late_count': b.lates,
        'mention': b.mention,
        'decision': b.decision,
        'status': 'draft',
        'generated_at': now,
        if (createdBy != null) 'created_by': createdBy,
      });
    }

    if (rows.isEmpty) {
      throw const ReportCardEmpty(
          'Aucun élève de cette classe n’a de note pour cette période.');
    }

    await _db
        .from('report_cards')
        .upsert(rows, onConflict: 'student_id,academic_year,period');
    return rows.length;
  }

  /// Publie les bulletins (draft → published) d'une classe pour un trimestre.
  /// Renvoie le nombre de bulletins publiés.
  static Future<int> publishReportCards({
    required String classId,
    required String academicYear,
    required String period,
  }) async {
    final updated = await _db
        .from('report_cards')
        .update({
          'status': 'published',
          'published_at': DateTime.now().toIso8601String(),
        })
        .eq('class_id', classId)
        .eq('academic_year', academicYear)
        .eq('period', period)
        .eq('status', 'draft')
        .select('id');
    return (updated as List).length;
  }

  // ── Devoirs (assignments + submissions) ─────────────────────────────────────
  /// Devoirs publiés d'une classe (matière + enseignant joints).
  static Future<List<SbAssignment>> getAssignmentsForClass(String classId) async {
    final data = await _db
        .from('assignments')
        .select('*, subjects(name), users!teacher_id(full_name)')
        .eq('class_id', classId)
        .eq('is_published', true)
        .order('deadline', ascending: false);
    return (data as List)
        .map((j) => SbAssignment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Remises (et notes) de l'élève — à croiser avec les devoirs par assignment_id.
  static Future<List<SbSubmission>> getSubmissionsForStudent(String studentId) async {
    final data = await _db
        .from('submissions')
        .select()
        .eq('student_id', studentId);
    return (data as List)
        .map((j) => SbSubmission.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── Droits réels de la personne connectée ─────────────────────────────────

  /// Les droits FINS du membre connecté : `module.action` (« notes.modifier »).
  ///
  /// `users.permissions` ne porte que 11 clés plates (« grades ») : elle dit si
  /// on touche aux notes, pas si on a le droit de les MODIFIER. L'interface s'en
  /// contentait — d'où des boutons « Supprimer » offerts à quelqu'un que la base
  /// refuse ensuite. On lit donc les grants du rôle, les mêmes que ceux que
  /// `has_permission()` consulte en base.
  ///
  /// `{'*'}` = accès total (fondateur / rôle administrateur).
  static Future<Set<String>> getMyGrants() async {
    final auth = _db.auth.currentUser;
    if (auth == null) return const {};

    final row = await _db
        .from('users')
        .select('role, staff_role_id, permissions')
        .eq('auth_uid', auth.id)
        .maybeSingle();
    if (row == null) return const {};

    // Le FONDATEUR n'a ni rôle du personnel ni permissions : il est reconnu à
    // son `users.role`. C'est ainsi que la base le voit (cf. has_permission,
    // 20260716) et c'est ce qui débloque la première configuration — sans quoi
    // il faudrait déjà un rôle pour créer le premier rôle.
    // Même liste que supabase_auth_source.dart : garder les trois alignées.
    const founders = {'admin', 'direction', 'directeur', 'dg'};
    if (founders.contains((row['role'] as String?)?.toLowerCase())) {
      return const {'*'};
    }

    final legacy = (row['permissions'] as List?)?.cast<String>() ?? const [];
    if (legacy.contains('*')) return const {'*'};

    final roleId = row['staff_role_id'] as String?;
    if (roleId == null) return const {};

    final perms = await _db
        .from('staff_role_permissions')
        .select('permission_key, sub_permission_key')
        .eq('staff_role_id', roleId);

    return (perms as List)
        .map((p) => '${p['permission_key']}.${p['sub_permission_key']}')
        .toSet();
  }

  // ── Users ─────────────────────────────────────────────────────────────────
  static Future<List<SbUser>> getUsers({String? schoolId}) async {
    var q = _db.from('users').select();
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('full_name');
    return (data as List).map((j) => SbUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── School ────────────────────────────────────────────────────────────────
  static Future<SbSchool?> getSchool(String schoolId) async {
    final data = await _db
        .from('schools')
        .select()
        .eq('id', schoolId)
        .maybeSingle();
    return data != null ? SbSchool.fromJson(data) : null;
  }

  /// Lit la config du formulaire d'inscription de l'école (jsonb), ou null.
  static Future<Map<String, dynamic>?> getEnrollmentConfig(
      String schoolId) async {
    final data = await _db
        .from('schools')
        .select('enrollment_config')
        .eq('id', schoolId)
        .maybeSingle();
    final cfg = data?['enrollment_config'];
    return cfg is Map<String, dynamic> ? cfg : null;
  }

  /// Persiste la config du formulaire d'inscription sur l'école.
  static Future<void> saveEnrollmentConfig(
      String schoolId, Map<String, dynamic> config) async {
    await _db
        .from('schools')
        .update({'enrollment_config': config})
        .eq('id', schoolId);
  }

  static Future<SbSchool?> getFirstSchool() async {
    final data = await _db.from('schools').select().limit(1).maybeSingle();
    return data != null ? SbSchool.fromJson(data) : null;
  }

  // ── Subscription / Plans ────────────────────────────────────────────────────
  static Future<List<SbPlan>> getPlans() async {
    final data = await _db.from('plans').select().eq('is_active', true).order('sort_order');
    return (data as List).map((j) => SbPlan.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<List<SbPlanPrice>> getPlanPrices({String country = 'CG'}) async {
    final data = await _db.from('plan_prices').select().eq('country', country).eq('is_active', true);
    return (data as List).map((j) => SbPlanPrice.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<SbSubscription?> getSubscription(String schoolId) async {
    final data = await _db
        .from('subscriptions')
        .select()
        .eq('school_id', schoolId)
        .maybeSingle();
    return data != null ? SbSubscription.fromJson(data) : null;
  }

  /// Active (ou change) l'offre de l'école. SIMULATION du paiement tant que les
  /// agrégateurs ne sont pas branchés : on passe l'abonnement en `active` avec
  /// la nouvelle offre et une fin de période (mensuelle ou annuelle).
  static Future<void> activateSubscription({
    required String schoolId,
    required String planCode,
    required String period, // 'monthly' | 'annual'
    required double price,
    // La devise vient de l'ECOLE (schools.currency), jamais d'un defaut code
    // en dur : une ecole nigeriane facture en nairas. Cf. SchoolFormat.
    required String currency,
    double creditBalance = 0, // crédit prorata à reporter sur les prochains cycles
  }) async {
    final now = DateTime.now();
    final end = period == 'annual'
        ? DateTime(now.year + 1, now.month, now.day)
        : DateTime(now.year, now.month + 1, now.day);
    await _db.from('subscriptions').update({
      'plan_code': planCode,
      'status': 'active',
      'billing_period': period,
      'price': price,
      'currency': currency,
      'credit_balance': creditBalance,
      'current_period_end': end.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }).eq('school_id', schoolId);
  }

  /// Nombre d'élèves actifs de l'école (pour l'usage vs limite de l'offre).
  static Future<int> getStudentCount(String schoolId) async {
    final data = await _db
        .from('users')
        .select('id')
        .eq('school_id', schoolId)
        .eq('role', 'student')
        .eq('status', 'active');
    return (data as List).length;
  }

  // ── Mutations — Élèves (Phase A1/B1) ────────────────────────────────────────
  /// Peut-on encore ajouter un élève ? (limite de l'offre + tolérance, côté base)
  static Future<bool> canAddStudent(String schoolId) async {
    final res = await _db.rpc('school_can_add_student', params: {'p_school': schoolId});
    return res == true;
  }

  /// Crée une FICHE élève (users role=student + student_profiles), SANS login
  /// (auth_uid null). Le login éventuel est une étape séparée (cf. accounts-and-access).
  /// Crée une fiche élève et renvoie son `user_id`.
  static Future<String> createStudent({
    required String schoolId,
    required String fullName,
    String? email,
    String? phone,
    String? classId,
    String? matricule,
    String? birthDate, // ISO yyyy-MM-dd
    String? gender,
    String? nationality,
    String academicYear = '2025-2026',
  }) async {
    final id = const Uuid().v4();
    final mat = (matricule != null && matricule.trim().isNotEmpty)
        ? matricule.trim()
        : 'MAT-${DateTime.now().year}-${id.substring(0, 4).toUpperCase()}';
    // users.email est NOT NULL : si l'élève n'a pas d'email, on en synthétise un
    // unique (fiche sans connexion). À remplacer si un vrai email est ajouté.
    final mail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : 'eleve.${id.substring(0, 8)}@eleve.scolaris.local';

    await _db.from('users').insert({
      'id': id,
      'school_id': schoolId,
      'full_name': fullName,
      'email': mail,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'role': 'student',
      'status': 'active',
    });
    await _db.from('student_profiles').insert({
      'user_id': id,
      'school_id': schoolId,
      if (classId != null) 'class_id': classId,
      'matricule': mat,
      if (birthDate != null && birthDate.isNotEmpty) 'date_of_birth': birthDate,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (nationality != null && nationality.isNotEmpty) 'nationality': nationality,
      'academic_year': academicYear,
    });
    return id;
  }

  /// Crée (ou réutilise) un parent et le relie à un élève via `parent_student`.
  /// Réutilise un parent existant de la même école si le téléphone ou l'email
  /// correspond (évite les doublons quand plusieurs enfants ont le même parent).
  /// Renvoie le `user_id` du parent.
  static Future<String> createOrLinkGuardian({
    required String schoolId,
    required String studentId,
    required String guardianName,
    String? phone,
    String? email,
    String relationship = 'Parent',
  }) async {
    String? parentId;

    // 1. Réutilisation : chercher un parent existant par téléphone puis email.
    final cleanPhone = phone?.trim();
    final cleanEmail = email?.trim();
    if (cleanPhone != null && cleanPhone.isNotEmpty) {
      final m = await _db
          .from('users')
          .select('id')
          .eq('school_id', schoolId)
          .eq('role', 'parent')
          .eq('phone', cleanPhone)
          .limit(1)
          .maybeSingle();
      parentId = m?['id'] as String?;
    }
    if (parentId == null && cleanEmail != null && cleanEmail.isNotEmpty) {
      final m = await _db
          .from('users')
          .select('id')
          .eq('school_id', schoolId)
          .eq('role', 'parent')
          .eq('email', cleanEmail)
          .limit(1)
          .maybeSingle();
      parentId = m?['id'] as String?;
    }

    // 2. Sinon, créer la fiche parent (sans login : auth_uid null).
    if (parentId == null) {
      final id = const Uuid().v4();
      final mail = (cleanEmail != null && cleanEmail.isNotEmpty)
          ? cleanEmail
          : 'parent.${id.substring(0, 8)}@parent.scolaris.local';
      await _db.from('users').insert({
        'id': id,
        'school_id': schoolId,
        'full_name': guardianName.trim(),
        'email': mail,
        if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
        'role': 'parent',
        'status': 'active',
      });
      parentId = id;
    }

    // 3. Lier parent ↔ élève (éviter le doublon de lien).
    final existing = await _db
        .from('parent_student')
        .select('id')
        .eq('parent_id', parentId)
        .eq('student_id', studentId)
        .limit(1)
        .maybeSingle();
    if (existing == null) {
      await _db.from('parent_student').insert({
        'id': const Uuid().v4(),
        'school_id': schoolId,
        'parent_id': parentId,
        'student_id': studentId,
        'relationship': relationship,
        'is_primary': true,
      });
    }
    return parentId;
  }

  // ── Création de comptes (via Edge Function `create-account`) ────────────────
  /// Crée un nouveau compte (prof / staff) côté serveur, déjà confirmé.
  /// L'école est déduite du compte appelant (jamais transmise par le client).
  /// [staffRoleId] rattache l'employé à un rôle de l'école (source de vérité) ;
  /// [permissions] en est la projection plate, dérivée via `RbacMapping` par
  /// l'appelant. Les deux sont écrites ensemble pour que le menu et les gardes
  /// existants continuent de fonctionner sans modification.
  /// Renvoie l'id de la ligne `users` créée (≠ auth_uid), pour pouvoir y
  /// rattacher une fiche du personnel dans la foulée.
  static Future<String?> createMemberAccount({
    required String email,
    required String password,
    required String fullName,
    required String role,
    List<String> permissions = const [],
    String? title,
    String? staffRoleId,
    String? phone,
  }) async {
    final res = await _db.functions.invoke('create-account', body: {
      'mode': 'create',
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'role': role,
    });
    _throwIfFnError(res);

    // Le compte est créé par l'Edge Function (auth + ligne users via trigger).
    // On pose ensuite le rôle + les permissions + le titre (RLS admin).
    final data = res.data;
    final authUid = (data is Map) ? data['userId'] as String? : null;
    if (authUid == null) return null;

    await _db.from('users').update({
      if (permissions.isNotEmpty) 'permissions': permissions,
      if (title != null && title.isNotEmpty) 'role_title': title.trim(),
      if (staffRoleId != null) 'staff_role_id': staffRoleId,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('auth_uid', authUid);

    final row = await _db
        .from('users')
        .select('id')
        .eq('auth_uid', authUid)
        .maybeSingle();
    return row?['id'] as String?;
  }

  // ── Fiche du personnel (staff_profiles) ────────────────────────────────────

  static Future<void> updateUserPhone({
    required String id,
    required String phone,
  }) async {
    final v = phone.trim();
    await _db.from('users').update({
      'phone': v.isEmpty ? null : v,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<SbStaffProfile?> getStaffProfile(String userId) async {
    final row = await _db
        .from('staff_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : SbStaffProfile.fromJson(row);
  }

  static Future<void> upsertStaffProfile({
    required String userId,
    required String schoolId,
    String? employeeId,
    String? gender,
    DateTime? dateOfBirth,
    DateTime? joinDate,
    String contractType = 'permanent',
  }) async {
    String? d(DateTime? v) =>
        v == null ? null : v.toIso8601String().split('T').first;

    await _db.from('staff_profiles').upsert({
      'user_id': userId,
      'school_id': schoolId,
      'employee_id': (employeeId?.trim().isEmpty ?? true) ? null : employeeId!.trim(),
      'gender': gender,
      'date_of_birth': d(dateOfBirth),
      'join_date': d(joinDate),
      'contract_type': contractType,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Met à jour le rôle, les permissions et le titre d'un membre existant.
  ///
  /// [staffRoleId] : passer une valeur pour (re)rattacher à un rôle. Omettre le
  /// paramètre laisse le rattachement inchangé — pour le détacher explicitement,
  /// passer [clearStaffRole] à true.
  static Future<void> updateStaffAccess({
    required String id,
    required List<String> permissions,
    String? title,
    String? staffRoleId,
    bool clearStaffRole = false,
  }) async {
    await _db.from('users').update({
      'permissions': permissions,
      if (title != null) 'role_title': title.trim().isEmpty ? null : title.trim(),
      if (clearStaffRole) 'staff_role_id': null
      else if (staffRoleId != null) 'staff_role_id': staffRoleId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Donne un login à une fiche existante (élève/parent) sans la dupliquer.
  static Future<void> enableUserLogin({
    required String userId,
    required String email,
    required String password,
    String fullName = '',
  }) async {
    final res = await _db.functions.invoke('create-account', body: {
      'mode': 'link',
      'linkUserId': userId,
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
    });
    _throwIfFnError(res);
  }

  static void _throwIfFnError(FunctionResponse res) {
    if (res.status >= 400) {
      final data = res.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Erreur serveur (${res.status})';
      throw Exception(msg);
    }
  }

  // ── Mutations — Utilisateurs (tous rôles) ───────────────────────────────────
  /// Met à jour les champs de base d'un utilisateur (nom, email, téléphone).
  static Future<void> updateUser({
    required String id,
    String? fullName,
    String? email,
    String? phone,
  }) async {
    final patch = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (fullName != null) patch['full_name'] = fullName.trim();
    if (email != null && email.trim().isNotEmpty) patch['email'] = email.trim();
    if (phone != null) patch['phone'] = phone.trim();
    await _db.from('users').update(patch).eq('id', id);
  }

  /// Active / désactive un compte (status active ↔ suspended).
  static Future<void> setUserActive(String id, bool active) async {
    await _db.from('users').update({
      'status': active ? 'active' : 'suspended',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Niveaux de référence + Mutations Classes (Phase C) ──────────────────────
  /// Niveaux de référence d'un système (défaut : francophone Afrique, cycles
  /// primaire/collège/lycée pour la v1). Lus depuis `class_levels`, jamais en dur.
  static Future<List<SbClassLevel>> getClassLevels({
    String system = 'francophone_africa',
    List<String> cycles = const ['primaire', 'college', 'lycee'],
  }) async {
    final data = await _db
        .from('class_levels')
        .select()
        .eq('system_type', system)
        .inFilter('cycle', cycles)
        .order('order_num');
    return (data as List).map((j) => SbClassLevel.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<void> createClass({
    required String schoolId,
    required String name,
    String? level,
    String? levelId,
    String? section,
    String? room,
    String? branchId,
    String? mainTeacherId,
    int maxStudents = 35,
    String academicYear = '2025-2026',
  }) async {
    await _db.from('classes').insert({
      'id': const Uuid().v4(),
      'school_id': schoolId,
      'name': name,
      if (level != null) 'level': level,
      if (levelId != null) 'level_id': levelId,
      if (section != null && section.isNotEmpty) 'section': section,
      if (room != null && room.isNotEmpty) 'room': room,
      if (branchId != null) 'branch_id': branchId,
      if (mainTeacherId != null && mainTeacherId.isNotEmpty)
        'main_teacher_id': mainTeacherId,
      'max_students': maxStudents,
      'academic_year': academicYear,
      'is_active': true,
    });
  }

  static Future<void> updateClass({
    required String id,
    String? name,
    String? section,
    String? room,
    int? maxStudents,
  }) async {
    final patch = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (name != null) patch['name'] = name.trim();
    if (section != null) patch['section'] = section.trim();
    if (room != null) patch['room'] = room.trim();
    if (maxStudents != null) patch['max_students'] = maxStudents;
    await _db.from('classes').update(patch).eq('id', id);
  }

  /// Définit (ou retire, si null) le professeur **titulaire** d'une classe.
  /// Le titulaire enseigne toute sa classe (modèle primaire) et voit son
  /// carnet/ses présences pour cette classe.
  static Future<void> setClassMainTeacher(
      String classId, String? teacherId) async {
    await _db.from('classes').update({
      'main_teacher_id': (teacherId != null && teacherId.isNotEmpty)
          ? teacherId
          : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', classId);
  }

  // ── Emploi du temps (schedules) ─────────────────────────────────────────────
  static Future<List<SbSchedule>> getSchedulesForClass(String classId) async {
    final data = await _db
        .from('schedules')
        .select('*, subjects(name), users!teacher_id(full_name)')
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('day_of_week')
        .order('start_time');
    return (data as List)
        .map((j) => SbSchedule.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Créneaux d'un enseignant (toutes classes) — source des *affectations*
  /// réelles d'un prof : chaque ligne porte (class_id, subject_id) avec le vrai
  /// subject_id (celui des notes). Sert à scoper le carnet/les présences aux
  /// seules classes + matières qu'il enseigne.
  static Future<List<SbSchedule>> getSchedulesForTeacher(String teacherId) async {
    final data = await _db
        .from('schedules')
        .select('*, subjects(name), users!teacher_id(full_name)')
        .eq('teacher_id', teacherId)
        .eq('is_active', true)
        .order('day_of_week')
        .order('start_time');
    return (data as List)
        .map((j) => SbSchedule.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Adhésions (écoles) du compte connecté — identité portable (Phase B).
  /// Fail-safe : si la table `school_members` n'existe pas encore (migration
  /// non appliquée), renvoie [] → l'app retombe sur l'école unique du compte.
  static Future<List<SbMembership>> getMyMemberships(String userId) async {
    try {
      final data = await _db
          .from('school_members')
          .select('*, schools(name)')
          .eq('user_id', userId)
          .eq('status', 'active');
      return (data as List)
          .map((j) => SbMembership.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> createSchedule({
    required String schoolId,
    required String classId,
    String? subjectId,
    String? teacherId,
    required int dayOfWeek,
    required String startTime, // 'HH:mm'
    required String endTime,
    String? room,
    String academicYear = '2025-2026',
  }) async {
    await _db.from('schedules').insert({
      'id': const Uuid().v4(),
      'school_id': schoolId,
      'class_id': classId,
      if (subjectId != null) 'subject_id': subjectId,
      if (teacherId != null) 'teacher_id': teacherId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      if (room != null && room.isNotEmpty) 'room': room,
      'academic_year': academicYear,
      'is_active': true,
    });
  }

  static Future<void> deleteSchedule(String id) async {
    await _db.from('schedules').delete().eq('id', id);
  }

  static Future<void> updateSchedule({
    required String id,
    required String? subjectId,
    required String? teacherId,
    required String startTime,
    required String endTime,
    required String? room,
  }) async {
    await _db.from('schedules').update({
      if (subjectId != null) 'subject_id': subjectId,
      'teacher_id': teacherId,
      'start_time': startTime,
      'end_time': endTime,
      'room': (room == null || room.isEmpty) ? null : room,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> deleteClass(String id) async {
    await _db.from('classes').delete().eq('id', id);
  }

  static Future<void> deleteUser(String id) async {
    await _db.from('users').delete().eq('id', id);
  }

  // ── Grades write ─────────────────────────────────────────────────────────────

  /// Charge les notes d'une classe pour une matière et une période données.
  static Future<List<SbGrade>> getGradesForClassSubjectPeriod(
      String classId, String subjectId, String period) async {
    final data = await _db
        .from('grades')
        .select('*, subjects(name, code)')
        .eq('class_id', classId)
        .eq('subject_id', subjectId)
        .eq('period', period);
    return (data as List)
        .map((j) => SbGrade.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Crée ou met à jour une note.
  ///
  /// [sequence] distingue le Devoir 1 du Devoir 2 : sans elle, l'unicité portait
  /// sur (élève, matière, période, type) et le second devoir **écrasait** le
  /// premier. Un bulletin congolais en demande trois. Cf. 20260740.
  static Future<void> upsertGrade({
    required String studentId,
    required String classId,
    required String schoolId,
    required String subjectId,
    required double score,
    double maxScore = 20,
    required String period,
    required String type,
    int sequence = 1,
    String? teacherId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.from('grades').upsert(
      {
        'student_id': studentId,
        'class_id': classId,
        'school_id': schoolId,
        'subject_id': subjectId,
        'score': score,
        'max_score': maxScore,
        'period': period,
        'type': type,
        'sequence': sequence,
        if (teacherId != null) 'teacher_id': teacherId,
        'graded_at': now,
        'created_at': now,
        'updated_at': now,
      },
      onConflict: 'student_id,subject_id,period,type,sequence',
    );
  }

  /// Met à jour les types d'établissement et le système éducatif.
  ///
  /// `metadata` porte aussi d'autres clés (motto, year_founded…) : on FUSIONNE,
  /// on n'écrase pas. Une écriture brutale du jsonb perdrait le reste.
  static Future<void> updateSchoolTaxonomy({
    required String id,
    required List<String> types,
    required String educationalSystem,
  }) async {
    final row = await _db
        .from('schools')
        .select('metadata')
        .eq('id', id)
        .maybeSingle();

    final meta = <String, dynamic>{
      ...?(row?['metadata'] as Map?)?.cast<String, dynamic>(),
      'types': types,
      'educational_system': educationalSystem,
    };

    await _db.from('schools').update({
      'metadata': meta,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> updateSchool({
    required String id,
    required String name,
    String? code,
    String? city,
    String? country,
    String? academicYear,
    String? accentColor,
    String? logoUrl,
  }) async {
    await _db.from('schools').update({
      'name': name.trim(),
      if (code != null) 'code': code.trim().isEmpty ? null : code.trim(),
      if (city != null) 'city': city.trim().isEmpty ? null : city.trim(),
      if (country != null) 'country': country.trim().isEmpty ? null : country.trim(),
      if (academicYear != null) 'academic_year': academicYear.trim().isEmpty ? null : academicYear.trim(),
      if (accentColor != null) 'accent_color': accentColor,
      if (logoUrl != null) 'logo_url': logoUrl.trim().isEmpty ? null : logoUrl.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Cours = le PROGRAMME d'une classe ─────────────────────────────────────
  //  « Cette classe étudie cette matière, avec ce coefficient, enseignée par
  //  ces professeurs. » C'est le pilier : les droits d'un prof en découlent
  //  (avec le titulariat), et l'emploi du temps ne fait que placer ces cours
  //  dans la semaine. Cf. 20260739.

  /// Les colonnes du cours + ses enseignants. On lit **toujours** avec les
  /// enseignants : un cours sans prof est une anomalie qu'il faut voir.
  static const _courseSelect =
      '*, course_teachers(id, teacher_id, role, users(full_name))';

  static Future<List<SbCourse>> getCoursesForClass(String classId) async {
    final data = await _db
        .from('courses')
        .select(_courseSelect)
        .eq('class_id', classId)
        .order('name');
    return (data as List)
        .map((j) => SbCourse.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<List<SbCourse>> getCoursesForSchool(String schoolId) async {
    final data = await _db
        .from('courses')
        .select(_courseSelect)
        .eq('school_id', schoolId)
        .order('name');
    return (data as List)
        .map((j) => SbCourse.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Les cours d'un enseignant — **la** source de ses affectations.
  ///
  /// Remplace `getSchedulesForTeacher` dans ce rôle : un prof enseigne même
  /// sans emploi du temps saisi (beaucoup d'écoles ne le remplissent jamais).
  static Future<List<SbCourse>> getCoursesForTeacher(String teacherId) async {
    final data = await _db
        .from('course_teachers')
        .select('courses($_courseSelect)')
        .eq('teacher_id', teacherId);
    return (data as List)
        .map((j) => (j as Map<String, dynamic>)['courses'])
        .whereType<Map<String, dynamic>>()
        .map(SbCourse.fromJson)
        .toList();
  }

  /// Crée le cours **et** rattache ses enseignants. Renvoie son id.
  static Future<String> createCourse({
    required String schoolId,
    required String classId,
    String? subjectId,
    required String name,
    String? code,
    List<String> teacherIds = const [],
    int coefficient = 1,
    int? hoursWeek,
    String? description,
    String? color,
    String? programSummary,
    int? chapterCount,
    List<String> daysOfWeek = const [],
    String? room,
  }) async {
    final id = const Uuid().v4();
    await _db.from('courses').insert({
      'id': id,
      'school_id': schoolId,
      'class_id': classId,
      'subject_id': subjectId,
      'name': name.trim(),
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      'coef': coefficient,
      if (hoursWeek != null) 'hours_week': hoursWeek,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (color != null && color.isNotEmpty) 'color': color,
      if (programSummary != null && programSummary.trim().isNotEmpty)
        'program_summary': programSummary.trim(),
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (daysOfWeek.isNotEmpty) 'days_of_week': daysOfWeek,
      if (room != null && room.trim().isNotEmpty) 'room': room.trim(),
    });
    await setCourseTeachers(
        courseId: id, schoolId: schoolId, teacherIds: teacherIds);
    return id;
  }

  static Future<void> updateCourse({
    required String id,
    String? subjectId,
    String? name,
    String? code,
    int? coefficient,
    int? hoursWeek,
    String? description,
    String? color,
    String? programSummary,
    int? chapterCount,
    List<String>? daysOfWeek,
    String? room,
  }) async {
    final patch = <String, dynamic>{};
    if (subjectId != null) patch['subject_id'] = subjectId;
    if (name != null) patch['name'] = name.trim();
    if (code != null) patch['code'] = code.trim().isEmpty ? null : code.trim();
    if (coefficient != null) patch['coef'] = coefficient;
    if (hoursWeek != null) patch['hours_week'] = hoursWeek;
    if (description != null) {
      patch['description'] = description.trim().isEmpty ? null : description.trim();
    }
    if (color != null) patch['color'] = color;
    if (programSummary != null) {
      patch['program_summary'] =
          programSummary.trim().isEmpty ? null : programSummary.trim();
    }
    if (chapterCount != null) patch['chapter_count'] = chapterCount;
    if (daysOfWeek != null) patch['days_of_week'] = daysOfWeek;
    if (room != null) patch['room'] = room.trim().isEmpty ? null : room.trim();
    if (patch.isNotEmpty) {
      await _db.from('courses').update(patch).eq('id', id);
    }
  }

  /// Fixe la liste des enseignants d'un cours. Le **premier** est le principal,
  /// les suivants co-enseignants — mais les deux ont les mêmes droits : le rôle
  /// n'est qu'un affichage.
  ///
  /// On efface puis on réécrit : la liste que voit l'admin est celle qui vaut.
  static Future<void> setCourseTeachers({
    required String courseId,
    required String schoolId,
    required List<String> teacherIds,
  }) async {
    await _db.from('course_teachers').delete().eq('course_id', courseId);
    if (teacherIds.isEmpty) return;
    await _db.from('course_teachers').insert([
      for (var i = 0; i < teacherIds.length; i++)
        {
          'id': const Uuid().v4(),
          'school_id': schoolId,
          'course_id': courseId,
          'teacher_id': teacherIds[i],
          'role': i == 0 ? 'principal' : 'co',
        }
    ]);
  }

  static Future<void> deleteCourse(String id) async {
    await _db.from('courses').delete().eq('id', id);
  }

  static Future<List<SbCourse>> getMyCoursesForStudent(String classId) async {
    return getCoursesForClass(classId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OUTILS DU PRIMAIRE — cahier de liaison, récompenses
  // Tables créées par `supabase/migrations/20260724_primary_tools.sql`.
  // La RLS fait déjà le tri (élève → lui, parent → ses enfants, prof → ses
  // classes) : ces requêtes n'ont donc PAS à refiltrer côté client.
  // ══════════════════════════════════════════════════════════════════════════

  // ── Cahier de liaison ─────────────────────────────────────────────────────
  static const String _liaisonSelect =
      'id, school_id, class_id, student_id, author_id, category, title, body, '
      'requires_ack, created_at, users!author_id(full_name)';

  /// Mots du cahier destinés à un élève : ceux qui le visent nommément **et**
  /// ceux adressés à sa classe. Les deux comptent — un mot à la classe est
  /// aussi un mot pour lui.
  static Future<List<SbLiaisonEntry>> getLiaisonEntriesForStudent(
      String studentId, {String? classId}) async {
    final filter = (classId != null && classId.isNotEmpty)
        ? 'student_id.eq.$studentId,class_id.eq.$classId'
        : 'student_id.eq.$studentId';
    final data = await _db
        .from('liaison_entries')
        .select(_liaisonSelect)
        .or(filter)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => SbLiaisonEntry.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Mots écrits pour une classe (vue enseignant).
  static Future<List<SbLiaisonEntry>> getLiaisonEntriesForClass(
      String classId) async {
    final data = await _db
        .from('liaison_entries')
        .select(_liaisonSelect)
        .eq('class_id', classId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => SbLiaisonEntry.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Écrit un mot. `studentId` null = le mot s'adresse à toute la classe.
  static Future<void> createLiaisonEntry({
    required String schoolId,
    required String authorId,
    required String title,
    required String body,
    required String category,
    String? classId,
    String? studentId,
    bool requiresAck = false,
  }) async {
    await _db.from('liaison_entries').insert({
      'school_id': schoolId,
      'author_id': authorId,
      'class_id': classId,
      'student_id': studentId,
      'category': category,
      'title': title,
      'body': body,
      'requires_ack': requiresAck,
    });
  }

  static Future<void> deleteLiaisonEntry(String id) async {
    await _db.from('liaison_entries').delete().eq('id', id);
  }

  /// Les accusés de réception du parent connecté (pour savoir ce qu'il a signé).
  static Future<Set<String>> getMyLiaisonAcks(String parentId) async {
    final data = await _db
        .from('liaison_acks')
        .select('entry_id')
        .eq('parent_id', parentId);
    return (data as List)
        .map((j) => (j as Map<String, dynamic>)['entry_id'] as String)
        .toSet();
  }

  /// Le parent accuse réception — c'est la signature du cahier papier.
  static Future<void> ackLiaisonEntry({
    required String entryId,
    required String parentId,
  }) async {
    await _db.from('liaison_acks').insert({
      'entry_id': entryId,
      'parent_id': parentId,
    });
  }

  // ── Récompenses ───────────────────────────────────────────────────────────
  static Future<List<SbMeritPoint>> getMeritPointsForStudent(
      String studentId) async {
    final data = await _db
        .from('merit_points')
        .select('id, student_id, subject, reason, stars, awarded_at, '
            'users!awarded_by(full_name)')
        .eq('student_id', studentId)
        .order('awarded_at', ascending: false);
    return (data as List)
        .map((j) => SbMeritPoint.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> awardMeritPoint({
    required String schoolId,
    required String studentId,
    required String awardedBy,
    required String reason,
    String? subject,
    int stars = 1,
  }) async {
    await _db.from('merit_points').insert({
      'school_id': schoolId,
      'student_id': studentId,
      'awarded_by': awardedBy,
      'reason': reason,
      'subject': subject,
      'stars': stars,
    });
  }

  static Future<void> deleteMeritPoint(String id) async {
    await _db.from('merit_points').delete().eq('id', id);
  }

  /// Le catalogue de badges de l'école (vue admin — sans les obtentions).
  static Future<List<SbBadge>> getBadgeCatalog(String schoolId) async {
    final data = await _db
        .from('badge_catalog')
        .select('id, key, title, description, emoji, order_num')
        .eq('school_id', schoolId)
        .order('order_num');
    return (data as List).map((j) {
      final m = j as Map<String, dynamic>;
      return SbBadge(
        id: m['id'] as String,
        key: m['key'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String?,
        emoji: m['emoji'] as String?,
      );
    }).toList();
  }

  static Future<void> createBadge({
    required String schoolId,
    required String key,
    required String title,
    String? description,
    String? emoji,
    int orderNum = 0,
  }) async {
    await _db.from('badge_catalog').insert({
      'school_id': schoolId,
      'key': key,
      'title': title,
      'description': description,
      'emoji': emoji,
      'order_num': orderNum,
    });
  }

  static Future<void> deleteBadge(String id) async {
    await _db.from('badge_catalog').delete().eq('id', id);
  }

  /// Décerne un badge à un élève. La contrainte `unique(student_id, badge_id)`
  /// garantit qu'un badge ne s'obtient qu'une fois — un second appel échoue.
  static Future<void> awardBadgeToStudent({
    required String schoolId,
    required String studentId,
    required String badgeId,
    required String awardedBy,
  }) async {
    await _db.from('student_badges').insert({
      'school_id': schoolId,
      'student_id': studentId,
      'badge_id': badgeId,
      'awarded_by': awardedBy,
    });
  }

  /// Le catalogue de badges de l'école, et — pour l'élève visé — ceux qu'il a
  /// déjà obtenus. Un badge non obtenu reste visible (c'est un objectif), d'où
  /// la fusion catalogue + obtentions plutôt qu'une simple liste.
  static Future<List<SbBadge>> getBadgesForStudent({
    required String schoolId,
    required String studentId,
  }) async {
    final catalog = await _db
        .from('badge_catalog')
        .select('id, key, title, description, emoji, order_num')
        .eq('school_id', schoolId)
        .order('order_num');

    final earned = await _db
        .from('student_badges')
        .select('badge_id, awarded_at')
        .eq('student_id', studentId);

    final earnedAt = <String, DateTime?>{};
    for (final e in (earned as List)) {
      final m = e as Map<String, dynamic>;
      earnedAt[m['badge_id'] as String] = m['awarded_at'] != null
          ? DateTime.tryParse(m['awarded_at'] as String)
          : null;
    }

    return (catalog as List).map((j) {
      final m = j as Map<String, dynamic>;
      final id = m['id'] as String;
      return SbBadge(
        id: id,
        key: m['key'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String?,
        emoji: m['emoji'] as String?,
        earnedAt: earnedAt[id],
        earned: earnedAt.containsKey(id),
      );
    }).toList();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Modèles — outils du primaire
// ══════════════════════════════════════════════════════════════════════════

/// Un mot du cahier de liaison. `studentId` null ⇒ adressé à toute la classe.
class SbLiaisonEntry {
  final String id;
  final String schoolId;
  final String? classId;
  final String? studentId;
  final String? authorName;
  final String category;
  final String title;
  final String body;
  final bool requiresAck;
  final DateTime? createdAt;

  const SbLiaisonEntry({
    required this.id,
    required this.schoolId,
    required this.category,
    required this.title,
    required this.body,
    this.classId,
    this.studentId,
    this.authorName,
    this.requiresAck = false,
    this.createdAt,
  });

  factory SbLiaisonEntry.fromJson(Map<String, dynamic> j) => SbLiaisonEntry(
        id: j['id'] as String,
        schoolId: j['school_id'] as String? ?? '',
        classId: j['class_id'] as String?,
        studentId: j['student_id'] as String?,
        authorName: (j['users'] as Map<String, dynamic>?)?['full_name'] as String?,
        category: j['category'] as String? ?? 'info',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        requiresAck: j['requires_ack'] as bool? ?? false,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  /// Un mot sans `student_id` s'adresse à la classe entière.
  bool get isForWholeClass => studentId == null;
}

/// Un bon point : nominatif, daté, avec 1 à 3 étoiles.
class SbMeritPoint {
  final String id;
  final String studentId;
  final String? subject;
  final String reason;
  final int stars;
  final String? awardedByName;
  final DateTime? awardedAt;

  const SbMeritPoint({
    required this.id,
    required this.studentId,
    required this.reason,
    this.stars = 1,
    this.subject,
    this.awardedByName,
    this.awardedAt,
  });

  factory SbMeritPoint.fromJson(Map<String, dynamic> j) => SbMeritPoint(
        id: j['id'] as String,
        studentId: j['student_id'] as String? ?? '',
        subject: j['subject'] as String?,
        reason: j['reason'] as String? ?? '',
        stars: (j['stars'] as num?)?.toInt() ?? 1,
        awardedByName:
            (j['users'] as Map<String, dynamic>?)?['full_name'] as String?,
        awardedAt: j['awarded_at'] != null
            ? DateTime.tryParse(j['awarded_at'] as String)
            : null,
      );
}

/// Un badge du catalogue de l'école, obtenu ou non par l'élève visé.
class SbBadge {
  final String id;
  final String key;
  final String title;
  final String? description;
  final String? emoji;
  final bool earned;
  final DateTime? earnedAt;

  const SbBadge({
    required this.id,
    required this.key,
    required this.title,
    this.description,
    this.emoji,
    this.earned = false,
    this.earnedAt,
  });
}
