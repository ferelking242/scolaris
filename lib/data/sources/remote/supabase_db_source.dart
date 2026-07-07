import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

class SbGrade {
  final String id;
  final String studentId;
  final String? subjectId;
  final String? subjectName;
  final double score;
  final double maxScore;
  final String? period;
  final String? type;
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
        date: j['date'] != null ? DateTime.tryParse(j['date'] as String) : null,
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
  final String? period;
  final bool justified;
  final String? reason;

  const SbAbsence({
    required this.id,
    required this.studentId,
    this.classId,
    this.absenceDate,
    this.period,
    this.justified = false,
    this.reason,
  });

  factory SbAbsence.fromJson(Map<String, dynamic> j) => SbAbsence(
        id: j['id'] as String,
        studentId: j['student_id'] as String? ?? '',
        classId: j['class_id'] as String?,
        absenceDate: j['absence_date'] != null ? DateTime.tryParse(j['absence_date'] as String) : null,
        period: j['period'] as String?,
        justified: j['justified'] as bool? ?? false,
        reason: j['reason'] as String?,
      );

  bool get isJustified => justified;
  String get status => period?.toLowerCase() == 'retard' ? 'late' : 'absent';
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

class SbMessage {
  final String id;
  final String? senderId;
  final String? senderName;
  final String? content;
  final DateTime? createdAt;
  final bool isRead;
  final String? messageType;

  const SbMessage({
    required this.id,
    this.senderId,
    this.senderName,
    this.content,
    this.createdAt,
    this.isRead = false,
    this.messageType,
  });

  factory SbMessage.fromJson(Map<String, dynamic> j) {
    final senderMap = j['users'] as Map<String, dynamic>?;
    return SbMessage(
      id: j['id'] as String,
      senderId: j['sender_id'] as String?,
      senderName: senderMap?['full_name'] as String?,
      content: j['content'] as String?,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
      isRead: (j['read_by'] as List?)?.isNotEmpty ?? false,
      messageType: j['message_type'] as String?,
    );
  }
}

class SbAnnouncement {
  final String id;
  final String title;
  final String? content;
  final String? authorName;
  final String? targetRole;
  final String? priority;
  final String? targetClassId;
  final bool isPinned;
  final int likesCount;
  final DateTime? createdAt;

  const SbAnnouncement({
    required this.id,
    required this.title,
    this.content,
    this.authorName,
    this.targetRole,
    this.priority,
    this.targetClassId,
    this.isPinned = false,
    this.likesCount = 0,
    this.createdAt,
  });

  factory SbAnnouncement.fromJson(Map<String, dynamic> j) {
    final authorMap = j['users'] as Map<String, dynamic>?;
    return SbAnnouncement(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      content: j['content'] as String?,
      authorName: authorMap?['full_name'] as String?,
      targetRole: j['target_role'] as String?,
      priority: j['priority'] as String?,
      targetClassId: j['target_class_id'] as String?,
      isPinned: j['is_pinned'] as bool? ?? false,
      likesCount: j['likes_count'] as int? ?? 0,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
    );
  }
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
  final List<String> permissions;
  final String? roleTitle;

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
  });

  /// Cycles pédagogiques déduits des types (pour filtrer class_levels/matières).
  /// Mapping type → cycle ; les types sans cycle v1 (université…) sont ignorés ici.
  static const _typeToCycle = {
    'garderie': 'prescolaire',
    'primaire': 'primaire',
    'college': 'college',
    'lycee': 'lycee',
  };
  List<String> get cycles =>
      types.map((t) => _typeToCycle[t]).whereType<String>().toList();

  factory SbSchool.fromJson(Map<String, dynamic> j) {
    final meta = j['metadata'];
    final rawTypes = meta is Map ? meta['types'] : null;
    return SbSchool(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      code: j['code'] as String?,
      country: j['country'] as String?,
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
  final String name;
  final String? code;
  final String? teacherId;
  final String? teacherName;
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
    required this.name,
    this.code,
    this.teacherId,
    this.teacherName,
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

  factory SbCourse.fromJson(Map<String, dynamic> j) {
    final rawDays = j['days_of_week'];
    final days = rawDays is List ? rawDays.cast<String>() : <String>[];
    final teacher = j['users'] as Map<String, dynamic>?;
    return SbCourse(
      id: j['id'] as String,
      schoolId: j['school_id'] as String? ?? '',
      classId: j['class_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      code: j['code'] as String?,
      teacherId: j['teacher_id'] as String?,
      teacherName: teacher?['full_name'] as String?,
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

  // ── Attendance ────────────────────────────────────────────────────────────
  static Future<List<SbAttendance>> getAttendanceForClass(String classId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final data = await _db
        .from('attendance')
        .select()
        .eq('class_id', classId)
        .eq('date', today);
    return (data as List).map((j) => SbAttendance.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<List<SbAbsence>> getAbsencesForStudent(String studentId) async {
    final data = await _db
        .from('absences')
        .select()
        .eq('student_id', studentId)
        .order('absence_date', ascending: false);
    return (data as List).map((j) => SbAbsence.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<void> saveAttendance(List<SbAttendance> records) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = records.map((r) => {
      'student_id': r.studentId,
      'class_id': r.classId,
      'date': today,
      'status': r.status,
      'arrival_time': r.arrivalTime,
    }).toList();
    await _db.from('attendance').upsert(rows);
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
    String currency = 'XAF',
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
    String currency = 'XAF',
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

  /// Bulletins PUBLIÉS d'un élève (élève / parent) — triés du plus récent.
  static Future<List<SbReportCard>> getReportCardsForStudent(
      String studentId) async {
    final data = await _db
        .from('report_cards')
        .select()
        .eq('student_id', studentId)
        .eq('status', 'published')
        .order('period');
    return (data as List)
        .map((j) => SbReportCard.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Génère (statut 'draft') les bulletins de TOUS les élèves de la classe pour
  /// un trimestre : moyenne par matière (moyenne simple des notes /20), moyenne
  /// générale pondérée par coefficient, rang dans la classe, mention. Recalcule
  /// et écrase les bulletins existants de la période (repassés en 'draft' →
  /// à republier). Renvoie le nombre de bulletins générés.
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
    if (students.isEmpty) return 0;
    final subjects = await getSubjects(schoolId: schoolId);
    final allGrades = await getGradesForClass(classId);
    final periodGrades = allGrades
        .where((g) => g.period == period && g.subjectId != null)
        .toList();

    // Calcul par élève.
    final computed = <({
      String studentId,
      String name,
      List<SbReportCardLine> lines,
      double general,
    })>[];
    for (final st in students) {
      final bySubject = <String, List<SbGrade>>{};
      for (final g in periodGrades.where((g) => g.studentId == st.id)) {
        (bySubject[g.subjectId!] ??= []).add(g);
      }
      final lines = <SbReportCardLine>[];
      double totalPts = 0;
      int totalCoef = 0;
      for (final subj in subjects) {
        final gs = bySubject[subj.id];
        if (gs == null || gs.isEmpty) continue;
        final avg = gs.fold(0.0, (a, g) => a + g.outOf20) / gs.length;
        final comment = gs
            .where((g) => g.comment != null && g.comment!.isNotEmpty)
            .lastOrNull
            ?.comment;
        lines.add(SbReportCardLine(
          subject: subj.name,
          coef: subj.coefficient,
          average: double.parse(avg.toStringAsFixed(2)),
          appreciation: comment ?? _appreciationFor(avg),
        ));
        totalPts += avg * subj.coefficient;
        totalCoef += subj.coefficient;
      }
      final general = totalCoef > 0 ? totalPts / totalCoef : 0.0;
      computed.add((
        studentId: st.id,
        name: '${st.prenom} ${st.nom}'.trim(),
        lines: lines,
        general: general,
      ));
    }

    // Rang (seuls les élèves ayant au moins une note sont classés).
    final ranked = computed.where((c) => c.lines.isNotEmpty).toList()
      ..sort((a, b) => b.general.compareTo(a.general));
    final rankOf = <String, int>{};
    for (int i = 0; i < ranked.length; i++) {
      rankOf[ranked[i].studentId] = i + 1;
    }
    final classSize = ranked.length;

    final rows = <Map<String, dynamic>>[];
    final now = DateTime.now().toIso8601String();
    for (final c in ranked) {
      final general = double.parse(c.general.toStringAsFixed(2));
      rows.add({
        'school_id': schoolId,
        'student_id': c.studentId,
        'student_name': c.name,
        'class_id': classId,
        'academic_year': academicYear,
        'period': period,
        'lines': c.lines.map((l) => l.toJson()).toList(),
        'general_average': general,
        'rank': rankOf[c.studentId],
        'class_size': classSize,
        'mention': _mentionFor(general),
        'status': 'draft',
        'generated_at': now,
        if (createdBy != null) 'created_by': createdBy,
      });
    }
    if (rows.isNotEmpty) {
      await _db
          .from('report_cards')
          .upsert(rows, onConflict: 'student_id,academic_year,period');
    }
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

  // ── Messages ──────────────────────────────────────────────────────────────
  static Future<List<SbMessage>> getMessages({String? schoolId}) async {
    var q = _db
        .from('messages')
        .select('*, users!sender_id(full_name)');
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('created_at', ascending: false).limit(50);
    return (data as List).map((j) => SbMessage.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── Announcements ─────────────────────────────────────────────────────────
  static Future<List<SbAnnouncement>> getAnnouncements({String? schoolId}) async {
    var q = _db
        .from('announcements')
        .select('*, users!author_id(full_name)')
        .eq('is_published', true);
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('is_pinned', ascending: false).order('created_at', ascending: false);
    return (data as List).map((j) => SbAnnouncement.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Publie une annonce. `targetRole` ∈ all/students/parents/teachers/admin,
  /// `priority` ∈ normal/important/urgent. `targetClassId` cible une classe.
  static Future<void> createAnnouncement({
    required String schoolId,
    required String authorId,
    required String title,
    required String content,
    String targetRole = 'all',
    String priority = 'normal',
    String? targetClassId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.from('announcements').insert({
      'id': const Uuid().v4(),
      'school_id': schoolId,
      'author_id': authorId,
      'title': title.trim(),
      'content': content.trim(),
      'target_role': targetRole,
      'priority': priority,
      if (targetClassId != null) 'target_class_id': targetClassId,
      'is_published': true,
      'published_at': now,
    });
  }

  static Future<void> deleteAnnouncement(String id) async {
    await _db.from('announcements').delete().eq('id', id);
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
    String currency = 'XAF',
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
  static Future<void> createMemberAccount({
    required String email,
    required String password,
    required String fullName,
    required String role,
    List<String> permissions = const [],
    String? title,
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
    // On pose ensuite les permissions + le titre sur la ligne (RLS admin).
    final data = res.data;
    final authUid = (data is Map) ? data['userId'] as String? : null;
    if (authUid != null && (permissions.isNotEmpty || (title != null && title.isNotEmpty))) {
      await _db.from('users').update({
        if (permissions.isNotEmpty) 'permissions': permissions,
        if (title != null && title.isNotEmpty) 'role_title': title.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('auth_uid', authUid);
    }
  }

  /// Met à jour les permissions et le titre d'un membre du personnel existant.
  static Future<void> updateStaffAccess({
    required String id,
    required List<String> permissions,
    String? title,
  }) async {
    await _db.from('users').update({
      'permissions': permissions,
      if (title != null) 'role_title': title.trim().isEmpty ? null : title.trim(),
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

  /// Crée ou met à jour une note (upsert sur student+subject+period+type).
  static Future<void> upsertGrade({
    required String studentId,
    required String classId,
    required String schoolId,
    required String subjectId,
    required double score,
    double maxScore = 20,
    required String period,
    required String type,
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
        if (teacherId != null) 'teacher_id': teacherId,
        'graded_at': now,
        'created_at': now,
        'updated_at': now,
      },
      onConflict: 'student_id,subject_id,period,type',
    );
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

  // ── Courses ───────────────────────────────────────────────────────────────
  static Future<List<SbCourse>> getCoursesForClass(String classId) async {
    final data = await _db
        .from('courses')
        .select('*, users!teacher_id(full_name)')
        .eq('class_id', classId)
        .order('name');
    return (data as List)
        .map((j) => SbCourse.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<List<SbCourse>> getCoursesForSchool(String schoolId) async {
    final data = await _db
        .from('courses')
        .select('*, users!teacher_id(full_name)')
        .eq('school_id', schoolId)
        .order('name');
    return (data as List)
        .map((j) => SbCourse.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createCourse({
    required String schoolId,
    required String classId,
    required String name,
    String? code,
    String? teacherId,
    int coefficient = 1,
    int? hoursWeek,
    String? description,
    String? color,
    String? programSummary,
    int? chapterCount,
    List<String> daysOfWeek = const [],
    String? room,
  }) async {
    await _db.from('courses').insert({
      'id': const Uuid().v4(),
      'school_id': schoolId,
      'class_id': classId,
      'name': name.trim(),
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      if (teacherId != null) 'teacher_id': teacherId,
      'coef': coefficient,
      if (hoursWeek != null) 'hours_week': hoursWeek,
    });
    // Extra columns — safe update (columns already migrated)
    try {
      final extra = <String, dynamic>{};
      if (description != null && description.trim().isNotEmpty) extra['description'] = description.trim();
      if (color != null && color.isNotEmpty) extra['color'] = color;
      if (programSummary != null && programSummary.trim().isNotEmpty) extra['program_summary'] = programSummary.trim();
      if (chapterCount != null) extra['chapter_count'] = chapterCount;
      if (daysOfWeek.isNotEmpty) extra['days_of_week'] = daysOfWeek;
      if (room != null && room.trim().isNotEmpty) extra['room'] = room.trim();
      if (extra.isNotEmpty) {
        await _db.from('courses').update(extra).eq('name', name.trim()).eq('school_id', schoolId);
      }
    } catch (_) { /* safe to ignore on schema mismatch */ }
  }

  static Future<void> updateCourse({
    required String id,
    String? name,
    String? code,
    String? teacherId,
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
    if (name != null) patch['name'] = name.trim();
    if (code != null) patch['code'] = code.trim().isEmpty ? null : code.trim();
    if (teacherId != null) patch['teacher_id'] = teacherId;
    if (coefficient != null) patch['coef'] = coefficient;
    if (hoursWeek != null) patch['hours_week'] = hoursWeek;
    if (patch.isNotEmpty) {
      await _db.from('courses').update(patch).eq('id', id);
    }
    // Extra columns
    try {
      final extra = <String, dynamic>{};
      if (description != null) extra['description'] = description.trim().isEmpty ? null : description.trim();
      if (color != null) extra['color'] = color;
      if (programSummary != null) extra['program_summary'] = programSummary.trim().isEmpty ? null : programSummary.trim();
      if (chapterCount != null) extra['chapter_count'] = chapterCount;
      if (daysOfWeek != null) extra['days_of_week'] = daysOfWeek;
      if (room != null) extra['room'] = room.trim().isEmpty ? null : room.trim();
      if (extra.isNotEmpty) await _db.from('courses').update(extra).eq('id', id);
    } catch (_) { /* safe to ignore on schema mismatch */ }
  }

  static Future<void> deleteCourse(String id) async {
    await _db.from('courses').delete().eq('id', id);
  }

  static Future<List<SbCourse>> getMyCoursesForStudent(String classId) async {
    return getCoursesForClass(classId);
  }
}
