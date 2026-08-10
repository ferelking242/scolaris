import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/bulletin/bulletin_math.dart';
import '../../../core/config/school_format.dart';
import '../../../core/config/school_taxonomy.dart';
import '../../../shared/data/features_catalog.dart' show SchoolLevel;

// ── Entity models ─────────────────────────────────────────────────────────────

/// Une annonce plateforme (Scolaris → écoles) reçue par l'école courante —
/// cf. `SupabaseDbSource.getMyPlatformAnnouncements` / `my_platform_announcements()`.
class SbPlatformAnnouncement {
  final String id;
  final String title;
  final String body;
  final String kind; // 'info' | 'maintenance' | 'feature'
  final DateTime createdAt;
  const SbPlatformAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
  });
}

/// Une décision de fin d'année pour UN élève, à appliquer via
/// [SupabaseDbSource.applyClassPromotion]. `toClassId` n'a de sens que pour
/// 'promoted'/'repeated' ; `reason` surtout pour 'transferred'/'withdrawn'.
class PromotionDecision {
  final String studentId;
  final String? fromClassId;
  final String? fromAcademicYear;
  final String decision; // 'promoted' | 'repeated' | 'transferred' | 'graduated' | 'withdrawn'
  final String? toClassId;
  final double? average;
  final String? reason;

  const PromotionDecision({
    required this.studentId,
    this.fromClassId,
    this.fromAcademicYear,
    required this.decision,
    this.toClassId,
    this.average,
    this.reason,
  });
}

/// Une décision de fin d'année archivée (`student_progressions`) — telle que
/// vue depuis la file d'attente de ré-inscription. `status` gouverne tout :
/// 'proposed' = pas encore appliquée, 'confirmed'/'cancelled' = tranchée.
class SbProgression {
  final String id;
  final String studentId;
  final String studentName;
  final String? fromClassId;
  final String? toClassId;
  final String? fromAcademicYear;
  final String? toAcademicYear;
  final String decision;
  final double? average;
  final String? reason;
  final String status;
  final DateTime decidedAt;

  const SbProgression({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.fromClassId,
    this.toClassId,
    this.fromAcademicYear,
    this.toAcademicYear,
    required this.decision,
    this.average,
    this.reason,
    this.status = 'proposed',
    required this.decidedAt,
  });

  bool get isExit =>
      decision == 'transferred' || decision == 'graduated' || decision == 'withdrawn';

  factory SbProgression.fromJson(Map<String, dynamic> j) {
    final u = j['users'];
    final uMap = u is Map<String, dynamic>
        ? u
        : (u is List && u.isNotEmpty ? u.first as Map<String, dynamic> : null);
    return SbProgression(
      id: j['id'] as String,
      studentId: j['student_id'] as String,
      studentName: uMap?['full_name'] as String? ?? '—',
      fromClassId: j['from_class_id'] as String?,
      toClassId: j['to_class_id'] as String?,
      fromAcademicYear: j['from_academic_year'] as String?,
      toAcademicYear: j['to_academic_year'] as String?,
      decision: j['decision'] as String? ?? 'promoted',
      average: (j['average'] as num?)?.toDouble(),
      reason: j['reason'] as String?,
      status: j['status'] as String? ?? 'proposed',
      decidedAt:
          DateTime.tryParse(j['decided_at'] as String? ?? '') ?? DateTime(2000),
    );
  }
}

/// Une demande de pré-inscription publique (`enrollment_requests`). `payload`
/// suit les clés d'[EnrollmentFields] (`first_name`, `guardian_phone`…) —
/// jsonb libre côté base, non typé colonne par colonne.
class SbEnrollmentRequest {
  final String id;
  final String schoolId;
  final String reference;
  final Map<String, dynamic> payload;
  final String status; // pending | accepted | rejected
  final String? studentId;
  final String? note;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const SbEnrollmentRequest({
    required this.id,
    required this.schoolId,
    required this.reference,
    required this.payload,
    required this.status,
    this.studentId,
    this.note,
    required this.submittedAt,
    this.reviewedAt,
  });

  factory SbEnrollmentRequest.fromJson(Map<String, dynamic> j) =>
      SbEnrollmentRequest(
        id: j['id'] as String,
        schoolId: j['school_id'] as String,
        reference: j['reference'] as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        status: j['status'] as String? ?? 'pending',
        studentId: j['student_id'] as String?,
        note: j['note'] as String?,
        submittedAt: DateTime.parse(j['submitted_at'] as String),
        reviewedAt: j['reviewed_at'] != null
            ? DateTime.parse(j['reviewed_at'] as String)
            : null,
      );

  String _str(String key) => (payload[key] as String?)?.trim() ?? '';
  String get fullName => '${_str('first_name')} ${_str('last_name')}'.trim();
  String get level => _str('level');
  String get guardianName => _str('guardian_name');
  String get guardianPhone => _str('guardian_phone');
  String get guardianEmail => _str('guardian_email');
}

class SbStudent {
  final String id;
  final String nom;
  final String prenom;
  final String? email;
  final String? niveau;
  final String? classe;
  final String? classId;
  final String? matricule;
  final DateTime? dateOfBirth;
  final String? avatarUrl;
  final bool actif;

  /// Statut de scolarité DANS CETTE ÉCOLE (`student_profiles.enrollment_status`)
  /// — distinct de [actif] (`users.status`, le compte/login). 'active' = élève
  /// courant ; les 3 autres = sorti (garde son dossier, hors effectifs actifs).
  final String enrollmentStatus;
  final String? exitReason;
  final DateTime? exitDate;

  /// Enseignant responsable de la classe (`classes.main_teacher_id`) — affiché
  /// sur la fiche élève comme raccourci ("qui contacter en premier").
  final String? mainTeacherId;

  /// Champs médicaux/sociaux structurés — stockés dans `student_profiles.metadata`
  /// (pas de colonnes dédiées : évite une migration pour 3 champs texte).
  final String? bloodGroup;
  final String? allergies;
  final String? vulnerability;

  /// Lieu de naissance — même raison qu'au-dessus : pas de colonne dédiée,
  /// vit dans `metadata`.
  final String? birthPlace;

  /// Suivi de conformité documentaire post-inscription (clé → fourni ou non),
  /// distinct de l'upload fait à la pré-inscription — vit aussi dans `metadata`.
  final Map<String, bool> documents;

  const SbStudent({
    required this.id,
    required this.nom,
    required this.prenom,
    this.email,
    this.niveau,
    this.classe,
    this.classId,
    this.matricule,
    this.dateOfBirth,
    this.avatarUrl,
    this.actif = true,
    this.enrollmentStatus = 'active',
    this.exitReason,
    this.exitDate,
    this.mainTeacherId,
    this.bloodGroup,
    this.allergies,
    this.vulnerability,
    this.birthPlace,
    this.documents = const {},
  });

  String get fullName => '$prenom $nom';
  String get classGroup => classe ?? '';
  String get id_ => matricule ?? id.substring(0, 8).toUpperCase();
  bool get hasExited => enrollmentStatus != 'active';

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
    final meta = sp?['metadata'];
    final metaMap = meta is Map<String, dynamic> ? meta : const <String, dynamic>{};
    final docsRaw = metaMap['documents'];
    final docs = <String, bool>{
      if (docsRaw is Map)
        for (final e in docsRaw.entries) e.key.toString(): e.value == true,
    };
    return SbStudent(
      id: j['id'] as String,
      nom: nom,
      prenom: prenom,
      email: j['email'] as String?,
      niveau: cls?['level'] as String?,
      classe: cls?['name'] as String?,
      classId: sp?['class_id'] as String?,
      matricule: sp?['matricule'] as String?,
      dateOfBirth: sp?['date_of_birth'] != null
          ? DateTime.tryParse(sp!['date_of_birth'] as String)
          : null,
      avatarUrl: j['avatar_url'] as String?,
      actif: (j['status'] as String? ?? 'active') == 'active',
      enrollmentStatus: sp?['enrollment_status'] as String? ?? 'active',
      exitReason: sp?['exit_reason'] as String?,
      exitDate: sp?['exit_date'] != null
          ? DateTime.tryParse(sp!['exit_date'] as String)
          : null,
      mainTeacherId: cls?['main_teacher_id'] as String?,
      bloodGroup: metaMap['blood_group'] as String?,
      allergies: metaMap['allergies'] as String?,
      vulnerability: metaMap['vulnerability'] as String?,
      birthPlace: metaMap['birth_place'] as String?,
      documents: docs,
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
  final String? levelId;
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
    this.levelId,
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
        levelId: j['level_id'] as String?,
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

  /// Dernière écriture. Sert à repérer une correction **postérieure** à la
  /// validation d'une période : si `updatedAt` dépasse la date de validation, le
  /// bulletin figé n'est plus à jour.
  final DateTime? updatedAt;
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
    this.updatedAt,
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
      updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at'] as String) : null,
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

  /// Quand ce snapshot a été (re)calculé. Sert à savoir si une note corrigée
  /// depuis est déjà reportée dans le bulletin officiel, ou non.
  final DateTime? generatedAt;

  /// Les repères du conseil de classe, figés à la génération. Un bulletin est
  /// une photo : on garde le rang et la moyenne de la classe **de ce jour-là**.
  final double? classAverage;
  final double? bestAverage;
  final double? worstAverage;
  final int absencesCount;
  final int lateCount;
  final String? decision;

  /// Les lignes **brutes** (jsonb), avec tout le détail : devoirs, M.C, compo,
  /// total, rang par matière. [lines] n'en garde qu'un résumé (pour les vieux
  /// écrans) ; ceci permet de reconstruire le bulletin complet à l'identique.
  final List<Map<String, dynamic>> rawLines;

  const SbReportCard({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.classId,
    required this.academicYear,
    required this.period,
    this.lines = const [],
    this.rawLines = const [],
    this.generalAverage = 0,
    this.rank,
    this.classSize,
    this.mention,
    this.status = 'draft',
    this.publishedAt,
    this.generatedAt,
    this.classAverage,
    this.bestAverage,
    this.worstAverage,
    this.absencesCount = 0,
    this.lateCount = 0,
    this.decision,
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
      rawLines: [for (final e in list) Map<String, dynamic>.from(e as Map)],
      generalAverage: (j['general_average'] as num?)?.toDouble() ?? 0,
      rank: (j['rank'] as num?)?.toInt(),
      classSize: (j['class_size'] as num?)?.toInt(),
      mention: j['mention'] as String?,
      status: j['status'] as String? ?? 'draft',
      publishedAt: j['published_at'] != null
          ? DateTime.tryParse(j['published_at'] as String)
          : null,
      generatedAt: j['generated_at'] != null
          ? DateTime.tryParse(j['generated_at'] as String)
          : null,
      classAverage: (j['class_average'] as num?)?.toDouble(),
      bestAverage: (j['best_average'] as num?)?.toDouble(),
      worstAverage: (j['worst_average'] as num?)?.toDouble(),
      absencesCount: (j['absences_count'] as num?)?.toInt() ?? 0,
      lateCount: (j['late_count'] as num?)?.toInt() ?? 0,
      decision: j['decision'] as String?,
    );
  }

  /// Le bulletin complet, reconstruit à l'identique depuis la version archivée.
  Bulletin toBulletin() => Bulletin.fromFrozen(
        lines: rawLines,
        average: generalAverage,
        rank: rank,
        classSize: classSize,
        classAverage: classAverage,
        bestAverage: bestAverage,
        worstAverage: worstAverage,
        absences: absencesCount,
        lates: lateCount,
        decision: decision,
      );
}

/// Une ligne de l'historique des modifications (journal immuable `notes_audit`).
/// Qui a changé quoi, quand, de quelle valeur à quelle valeur, et pourquoi.
class SbAuditEntry {
  final String changeType; // note | appreciation | suppression | statut_periode
  final String? field;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final String? studentId;
  final String? subjectId;
  final String actorName;
  final DateTime createdAt;

  const SbAuditEntry({
    required this.changeType,
    this.field,
    this.oldValue,
    this.newValue,
    this.reason,
    this.studentId,
    this.subjectId,
    required this.actorName,
    required this.createdAt,
  });

  factory SbAuditEntry.fromJson(Map<String, dynamic> j) => SbAuditEntry(
        changeType: j['change_type'] as String? ?? '',
        field: j['field'] as String?,
        oldValue: j['old_value'] as String?,
        newValue: j['new_value'] as String?,
        reason: j['reason'] as String?,
        studentId: j['student_id'] as String?,
        subjectId: j['subject_id'] as String?,
        actorName: j['actor_name'] as String? ?? '—',
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime(2000),
      );
}

/// L'état d'une période de notes (classe × trimestre). Ce qui gèle les notes et
/// scelle le bulletin. Cf. 20260746.
class SbGradePeriod {
  final String classId;
  final String period;
  final String status; // 'open' | 'validated' | 'locked'
  final DateTime? validatedAt;
  final DateTime? lockedAt;

  const SbGradePeriod({
    required this.classId,
    required this.period,
    required this.status,
    this.validatedAt,
    this.lockedAt,
  });

  bool get isOpen => status == 'open';
  bool get isValidated => status == 'validated';
  bool get isLocked => status == 'locked';

  /// Les notes se modifient-elles encore librement (période ouverte) ?
  bool get allowsFreeEdit => isOpen;

  factory SbGradePeriod.fromJson(Map<String, dynamic> j) => SbGradePeriod(
        classId: j['class_id'] as String? ?? '',
        period: j['period'] as String? ?? '',
        status: j['status'] as String? ?? 'open',
        validatedAt: j['validated_at'] != null
            ? DateTime.tryParse(j['validated_at'] as String)
            : null,
        lockedAt: j['locked_at'] != null
            ? DateTime.tryParse(j['locked_at'] as String)
            : null,
      );
}

class SbAttendance {
  final String id;
  final String studentId;
  final String? classId;
  final String? teacherId;
  final String? subjectId;
  final DateTime? date;
  final String status;
  final String? arrivalTime;
  final bool justified;

  const SbAttendance({
    required this.id,
    required this.studentId,
    this.classId,
    this.teacherId,
    this.subjectId,
    this.date,
    this.status = 'present',
    this.arrivalTime,
    this.justified = false,
  });

  factory SbAttendance.fromJson(Map<String, dynamic> j) => SbAttendance(
        id: j['id'] as String,
        studentId: j['student_id'] as String? ?? '',
        classId: j['class_id'] as String?,
        teacherId: j['teacher_id'] as String?,
        subjectId: j['subject_id'] as String?,
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

  /// Absence prise par un prof de matière (collège/lycée) : renseigné.
  /// Absence prise par le titulaire (pointage global du jour) : null.
  final String? subjectId;
  final String? subjectName;

  const SbAbsence({
    required this.id,
    required this.studentId,
    this.classId,
    this.absenceDate,
    this.status = 'absent',
    this.justified = false,
    this.reason,
    this.subjectId,
    this.subjectName,
  });

  factory SbAbsence.fromJson(Map<String, dynamic> j) {
    final subj = SbStudent._firstMap(j['subjects']);
    return SbAbsence(
      id: j['id'] as String,
      studentId: j['student_id'] as String? ?? '',
      classId: j['class_id'] as String?,
      absenceDate: j['absence_date'] != null ? DateTime.tryParse(j['absence_date'] as String) : null,
      status: j['status'] as String? ?? 'absent',
      justified: j['justified'] as bool? ?? false,
      reason: j['reason'] as String?,
      subjectId: j['subject_id'] as String?,
      subjectName: subj?['name'] as String?,
    );
  }

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

/// Une échéance de scolarité (mois/trimestre) : libellé + date d'échéance.
/// Élément du calendrier d'un compte, pour afficher « sept payé · déc reste 5K ».
class SbTuitionPeriod {
  final String code;   // '2025-09', '2025-T1'
  final String label;  // 'Scolarité — septembre 2025'
  final DateTime due;
  const SbTuitionPeriod(
      {required this.code, required this.label, required this.due});
}

/// Le COMPTE de scolarité d'un élève : ce qu'il doit sur l'année, ce qu'il a
/// versé, et où il en est PAR RAPPORT À LA DATE DU JOUR.
///
/// Remplace la pile de N factures mensuelles par une seule vérité : un solde
/// qui court. « À jour » ne se lit pas dans un statut, il se CALCULE (versé ≥ dû
/// à ce jour). Les versements descendent en cascade sur les mois les plus
/// anciens — mais ici on n'a besoin que des totaux pour le dire.
class SbTuitionAccount {
  final double monthly;      // mensualité (ou montant par tranche)
  final int periodsCount;    // nb de tranches sur l'année
  final int periodsElapsed;  // tranches déjà échues à ce jour
  final double paid;         // total réellement versé (scolarité mensuelle seule)
  final String currency;
  final List<SbTuitionPeriod> periods;

  /// Frais d'inscription/réinscription dû pour cet élève cette année — `null`
  /// si la classe n'a pas de frais d'inscription configuré (pas de ligne à
  /// afficher). Suivi À PART de la scolarité mensuelle : montant différent,
  /// due date différente, un seul versement en général.
  final double? registrationDue;
  final double registrationPaid;

  const SbTuitionAccount({
    required this.monthly,
    required this.periodsCount,
    required this.periodsElapsed,
    required this.paid,
    required this.currency,
    this.periods = const [],
    this.registrationDue,
    this.registrationPaid = 0,
  });

  /// Reste dû sur l'inscription (jamais négatif). `0` si pas de frais configuré.
  double get registrationOwed {
    final due = registrationDue;
    if (due == null) return 0;
    final o = due - registrationPaid;
    return o < 0 ? 0 : o;
  }

  bool get hasRegistrationFee => registrationDue != null;
  bool get registrationSettled => !hasRegistrationFee || registrationOwed <= 0.01;

  /// Total dû sur l'année entière.
  double get annual => monthly * periodsCount;

  /// Dû à ce jour : ce qui aurait dû être réglé compte tenu des mois écoulés.
  double get dueToDate => monthly * periodsElapsed;

  /// Reste à payer sur l'année (jamais négatif).
  double get balance {
    final b = annual - paid;
    return b < 0 ? 0 : b;
  }

  /// Ce que l'élève doit MAINTENANT (mois échus non couverts). C'est le vrai
  /// « il est en retard de combien ? ».
  double get owedNow {
    final o = dueToDate - paid;
    return o < 0 ? 0 : o;
  }

  /// À jour : le versé couvre au moins le dû à ce jour (tolérance d'un centime).
  bool get isUpToDate => paid >= dueToDate - 0.01;

  /// Solde payé d'avance (couvre des mois pas encore échus).
  double get credit {
    final c = paid - dueToDate;
    return c < 0 ? 0 : c;
  }

  /// Nombre de tranches couvertes par le versé — fractionnaire : 3,5 = trois
  /// mois pleins + un demi. Sert au « couvert jusqu'à mi-décembre ».
  double get periodsCovered => monthly > 0 ? paid / monthly : 0;
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

  /// Cumul déjà encaissé sur cette facture (somme des `payments`). Permet les
  /// paiements PARTIELS : une facture peut être payée en plusieurs fois.
  final double amountPaid;

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
    this.amountPaid = 0,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';
  bool get isTuition => category == 'tuition';

  /// Libellé français du code stocké (`invoices.category`, contraint côté DB à
  /// `tuition | canteen | transport | uniforms | activities | other`) — les
  /// écrans affichent ce libellé plutôt que le code brut anglais.
  String get categoryLabel {
    switch (category) {
      case 'tuition':
        return 'Scolarité';
      case 'canteen':
        return 'Cantine';
      case 'transport':
        return 'Transport';
      case 'uniforms':
        return 'Uniformes';
      case 'activities':
        return 'Activités';
      case 'other':
        return 'Autre';
      default:
        return 'Autre';
    }
  }

  /// Reste dû (jamais négatif).
  double get balance {
    final b = amount - amountPaid;
    return b < 0 ? 0 : b;
  }

  /// Partiellement payée : un acompte reçu, mais pas le solde.
  bool get isPartiallyPaid => !isPaid && amountPaid > 0 && balance > 0;

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
      amountPaid: _sumPayments(j['payments']),
    );
  }

  // Somme des encaissements embarqués (`payments(amount,status)`). Absent/null
  // → 0, pour rester compatible avec les requêtes qui ne les embarquent pas.
  // Exclut les versements `pending` (référence Mobile Money pas encore
  // vérifiée par l'admin) — un versement en attente ne doit pas faire passer
  // la facture à « payé ».
  static double _sumPayments(dynamic payments) {
    if (payments is! List) return 0;
    var total = 0.0;
    for (final p in payments) {
      if (p is Map<String, dynamic>) {
        final status = p['status'] as String? ?? 'confirmed';
        if (status != 'confirmed') continue;
        total += (p['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }
}

class SbPayment {
  final String id;
  final String? invoiceId;
  final String? studentId;
  final String? studentName;
  final double amount;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? reference;
  final String status; // 'pending' | 'confirmed' | 'rejected'

  /// `'tuition' | 'registration'` — SEULEMENT pour un versement en ligne SANS
  /// facture (cf. [SupabaseDbSource.confirmPayment]), déduit de `notes`
  /// (JSON écrit par l'Edge Function `record-online-payment`). `null` pour un
  /// versement classique (déjà rattaché à une facture via [invoiceId]).
  final String? pendingCategory;
  final String? pendingAcademicYear;

  /// Catégorie/description/période de la facture liée — seulement si le
  /// paiement a été chargé via [SupabaseDbSource.getPaymentsForSchool] (embed
  /// `invoices(...)`). `null` sinon (ex. [getPaymentsForStudent]).
  final String? invoiceCategory;
  final String? invoiceDescription;
  final String? invoicePeriod;

  const SbPayment({
    required this.id,
    this.invoiceId,
    this.studentId,
    this.studentName,
    required this.amount,
    this.paymentDate,
    this.paymentMethod,
    this.reference,
    this.status = 'confirmed',
    this.pendingCategory,
    this.pendingAcademicYear,
    this.invoiceCategory,
    this.invoiceDescription,
    this.invoicePeriod,
  });

  factory SbPayment.fromJson(Map<String, dynamic> j) {
    final u = j['users'];
    final studentMap = u is Map<String, dynamic>
        ? u
        : (u is List && u.isNotEmpty ? u.first as Map<String, dynamic> : null);
    Map<String, dynamic>? meta;
    final notes = j['notes'] as String?;
    if (notes != null && notes.startsWith('{')) {
      try {
        meta = jsonDecode(notes) as Map<String, dynamic>;
      } catch (_) {
        meta = null;
      }
    }
    final inv = j['invoices'];
    final invMap = inv is Map<String, dynamic>
        ? inv
        : (inv is List && inv.isNotEmpty ? inv.first as Map<String, dynamic> : null);
    return SbPayment(
      id: j['id'] as String,
      invoiceId: j['invoice_id'] as String?,
      studentId: j['student_id'] as String?,
      studentName: (studentMap?['full_name'] as String?)?.trim(),
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      paymentDate: j['payment_date'] != null ? DateTime.tryParse(j['payment_date'] as String) : null,
      paymentMethod: j['payment_method'] as String?,
      reference: j['reference'] as String?,
      status: j['status'] as String? ?? 'confirmed',
      pendingCategory: meta?['category'] as String?,
      pendingAcademicYear: meta?['academicYear'] as String?,
      invoiceCategory: invMap?['category'] as String?,
      invoiceDescription: invMap?['description'] as String?,
      invoicePeriod: invMap?['period'] as String?,
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

  /// Statut de scolarité (`student_profiles.enrollment_status`) — SEULEMENT
  /// pour role='student' ; `null` pour le personnel/parents (pas de fiche
  /// élève). Distinct de [status] (compte suspendu/actif, sans rapport).
  final String? enrollmentStatus;
  final String? exitReason;
  final DateTime? exitDate;

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
    this.enrollmentStatus,
    this.exitReason,
    this.exitDate,
  });

  bool get isActive => status == 'active';
  bool get hasExited => enrollmentStatus != null && enrollmentStatus != 'active';

  factory SbUser.fromJson(Map<String, dynamic> j) {
    final sp = j['student_profiles'];
    final spMap = sp is Map<String, dynamic>
        ? sp
        : (sp is List && sp.isNotEmpty ? sp.first as Map<String, dynamic> : null);
    return SbUser(
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
        enrollmentStatus: spMap?['enrollment_status'] as String?,
        exitReason: spMap?['exit_reason'] as String?,
        exitDate: spMap?['exit_date'] != null
            ? DateTime.tryParse(spMap!['exit_date'] as String)
            : null,
      );
  }
}

/// Lien parent↔élève enrichi du contact du parent (`parent_student` + `users`).
/// Sert aux DEUX fiches : les tuteurs d'un élève, et l'inverse via les enfants.
class SbGuardianLink {
  final String parentId;
  final String fullName;
  final String? email;
  final String? phone;
  final String relationship; // « Père », « Mère », « Tuteur »…
  final bool isPrimary;
  final bool hasAccount; // login parent activé (auth_uid non nul)

  const SbGuardianLink({
    required this.parentId,
    required this.fullName,
    this.email,
    this.phone,
    this.relationship = 'Parent',
    this.isPrimary = false,
    this.hasAccount = false,
  });
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
  /// `schools.contact_email` / `contact_phone` — colonnes réelles, déjà en
  /// base mais jamais lues côté client jusqu'ici.
  final String? contactEmail;
  final String? contactPhone;

  /// Types d'établissement choisis à l'inscription (metadata.types) :
  /// garderie, primaire, college, lycee, universite, technique, superieur, special.
  final List<String> types;

  /// Modules choisis à l'inscription (metadata.modules) : academic, attendance,
  /// finance, enrollment. Vide = école créée avant ce choix → tous les modules
  /// restent actifs (cf. `AdminHome._allGroups`, filtrage par `RoleNavEntry.module`).
  final List<String> modules;

  /// Système éducatif choisi à l'inscription (metadata.educational_system) :
  /// francophone, anglophone, arabophone, lmd, grande_ecole.
  /// Attention : ce n'est PAS `class_levels.system_type` — la traduction dépend
  /// aussi du pays, et se fait dans [SchoolTaxonomy].
  final String? educationalSystem;

  /// Devise (ISO 4217) et barème de notation de l'école. Ne jamais coder « FCFA »
  /// ou « /20 » en dur : cf. [SchoolFormat].
  final String currency;
  final String gradingScale;

  /// Surcharges de barème PAR CYCLE (metadata.grading_by_cycle). Clés = valeurs
  /// de l'enum SchoolLevel (`primaire`, `college`, `lycee`, `universite`…),
  /// valeurs = un barème (`numeric_10`, `numeric_20`, `numeric_100`, `letter`).
  /// Vide = tous les cycles suivent `gradingScale` (le défaut de l'école).
  final Map<String, String> gradingByCycle;

  /// Découpage de l'année : `trimester` (T1/T2/T3), `semester` (S1/S2) ou
  /// `monthly`. Défaut de l'école.
  final String periodSystem;

  /// Surcharges de périodicité PAR CYCLE (metadata.period_system_by_cycle).
  /// Mêmes clés que [gradingByCycle] (`primaire`, `college`…). Vide = tous les
  /// cycles suivent [periodSystem]. Sert au primaire noté chaque mois quand le
  /// reste de l'école est en trimestres.
  final Map<String, String> periodSystemByCycle;

  /// La formule du bulletin — elle appartient à l'école, pas au code.
  ///
  /// [bulletinDevoirs] : combien de devoirs par matière (CSBFE : 3, dont le
  /// « D.D »). Leur moyenne forme la « M.C ».
  /// [bulletinCompoWeight] : le poids de la composition. 0.5 → elle pèse autant
  /// que tous les devoirs réunis. Cf. [BulletinRules] et 20260740.
  final int bulletinDevoirs;
  final double bulletinCompoWeight;

  /// Le MODÈLE de mise en page du bulletin (metadata.bulletin_template) :
  /// `standard` (CSBFE, celui d'origine) ou `detailed` (Emma & Bénie, avec
  /// professeurs nommés et synthèse annuelle). Pas de colonne dédiée : une
  /// école de plus qui veut son propre papier ne doit pas coûter une migration.
  final String bulletinTemplate;

  /// Numéros marchands Mobile Money de l'école (metadata.mobile_money.mtn /
  /// .airtel) — affichés aux familles pour le paiement à distance sans
  /// agrégateur : elles envoient l'argent elles-mêmes (USSD) vers ce numéro,
  /// puis saisissent la référence reçue par SMS dans l'app.
  final String? mobileMoneyMtn;
  final String? mobileMoneyAirtel;

  /// Certaines écoles veulent que TOUT (scolarité, inscription, cantine…) se
  /// règle sur place, jamais en ligne — indépendant du plan d'abonnement, qui
  /// n'autorise que la CAPACITÉ technique. Les deux se cumulent : en ligne
  /// visible seulement si le plan le permet ET que l'école l'a activé.
  /// (metadata.online_payment_enabled)
  final bool onlinePaymentEnabled;

  /// Frais d'inscription/réinscription PAR CLASSE (metadata.registration_fees
  /// = { classId: { new: montant, returning: montant } }). `null` = pas de
  /// frais d'inscription configuré pour cette classe (le compte de scolarité
  /// n'affiche alors aucune ligne inscription).
  final Map<String, SbRegistrationFee> registrationFees;

  const SbSchool({
    required this.id,
    required this.name,
    this.code,
    this.country,
    this.city,
    this.logoUrl,
    this.accentColor,
    this.academicYear,
    this.contactEmail,
    this.contactPhone,
    this.types = const [],
    this.modules = const [],
    this.educationalSystem,
    this.currency = 'XAF',
    this.gradingScale = 'numeric_20',
    this.gradingByCycle = const {},
    this.periodSystem = 'trimester',
    this.periodSystemByCycle = const {},
    this.bulletinDevoirs = 3,
    this.bulletinCompoWeight = 0.5,
    this.bulletinTemplate = 'standard',
    this.mobileMoneyMtn,
    this.mobileMoneyAirtel,
    this.onlinePaymentEnabled = false,
    this.registrationFees = const {},
  });

  SchoolFormat get format => SchoolFormat(
        currency: currency,
        gradingScale: gradingScale,
        periodSystem: periodSystem,
        academicYear: academicYear ?? '',
      );

  /// Barème applicable à un [cycle] donné (clé SchoolLevel : `primaire`…).
  /// Surcharge du cycle si définie, sinon le défaut de l'école.
  String gradingScaleForCycle(String? cycle) =>
      (cycle != null ? gradingByCycle[cycle] : null) ?? gradingScale;

  /// Périodicité applicable à un [cycle] donné. Surcharge du cycle si
  /// définie, sinon le défaut de l'école.
  String periodSystemForCycle(String? cycle) =>
      (cycle != null ? periodSystemByCycle[cycle] : null) ?? periodSystem;

  /// [SchoolFormat] résolu pour un cycle : même devise que l'école, mais le
  /// barème ET la périodicité du cycle. `null` → le format par défaut de
  /// l'école.
  SchoolFormat formatForCycle(String? cycle) => SchoolFormat(
        currency: currency,
        gradingScale: gradingScaleForCycle(cycle),
        periodSystem: periodSystemForCycle(cycle),
        academicYear: academicYear ?? '',
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
    final rawModules = meta is Map ? meta['modules'] : null;
    return SbSchool(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      code: j['code'] as String?,
      country: j['country'] as String?,
      educationalSystem:
          meta is Map ? meta['educational_system'] as String? : null,
      currency: j['currency'] as String? ?? 'XAF',
      gradingScale: j['grading_scale'] as String? ?? 'numeric_20',
      gradingByCycle: meta is Map && meta['grading_by_cycle'] is Map
          ? (meta['grading_by_cycle'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      periodSystem: j['period_system'] as String? ?? 'trimester',
      periodSystemByCycle: meta is Map && meta['period_system_by_cycle'] is Map
          ? (meta['period_system_by_cycle'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      bulletinDevoirs: (j['bulletin_devoirs'] as num?)?.toInt() ?? 3,
      bulletinCompoWeight:
          (j['bulletin_compo_weight'] as num?)?.toDouble() ?? 0.5,
      bulletinTemplate:
          meta is Map ? (meta['bulletin_template'] as String? ?? 'standard') : 'standard',
      city: j['city'] as String?,
      logoUrl: j['logo_url'] as String?,
      accentColor: j['accent_color'] as String?,
      academicYear: j['academic_year'] as String?,
      contactEmail: j['contact_email'] as String?,
      contactPhone: j['contact_phone'] as String?,
      types: rawTypes is List
          ? rawTypes.map((e) => e.toString()).toList()
          : const [],
      modules: rawModules is List
          ? rawModules.map((e) => e.toString()).toList()
          : const [],
      mobileMoneyMtn: meta is Map && meta['mobile_money'] is Map
          ? (meta['mobile_money']['mtn'] as String?)
          : null,
      mobileMoneyAirtel: meta is Map && meta['mobile_money'] is Map
          ? (meta['mobile_money']['airtel'] as String?)
          : null,
      onlinePaymentEnabled:
          meta is Map ? (meta['online_payment_enabled'] as bool? ?? false) : false,
      registrationFees: meta is Map && meta['registration_fees'] is Map
          ? (meta['registration_fees'] as Map).map((k, v) => MapEntry(
              k.toString(),
              SbRegistrationFee.fromJson(v is Map ? v : const {}),
            ))
          : const {},
    );
  }
}

/// Frais d'inscription d'une classe : montant nouveau élève / réinscription.
class SbRegistrationFee {
  final double? forNew;
  final double? forReturning;
  const SbRegistrationFee({this.forNew, this.forReturning});

  factory SbRegistrationFee.fromJson(Map j) => SbRegistrationFee(
        forNew: (j['new'] as num?)?.toDouble(),
        forReturning: (j['returning'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {'new': forNew, 'returning': forReturning};
}

/// Numéro de dépôt Mobile Money DE SCOLARIS (pas de l'école) pour un
/// opérateur donné — où les écoles envoient leur versement d'abonnement
/// (`platform_payment_settings`, géré par le super-admin plateforme).
class SbPlatformPaymentSetting {
  final String provider; // 'mtn' | 'airtel'
  final String phoneNumber;
  final String holderName;

  const SbPlatformPaymentSetting({
    required this.provider,
    required this.phoneNumber,
    required this.holderName,
  });

  factory SbPlatformPaymentSetting.fromJson(Map<String, dynamic> j) =>
      SbPlatformPaymentSetting(
        provider: j['provider'] as String,
        phoneNumber: j['phone_number'] as String? ?? '',
        holderName: j['holder_name'] as String? ?? '',
      );
}

class SbPlan {
  final String code;
  final String name;
  final String? tagline;
  final int? maxStudents; // null = illimité
  final List<String> features;
  final int sortOrder;

  /// Franchise d'élèves incluse dans le prix de base, avant supplément de
  /// taille (cf. `plan_size_surcharges`). Distinct de [maxStudents] — qui
  /// n'est plus utilisé comme plafond dur depuis les offres par modules.
  final int? includedStudents;

  /// Nombre de modules (cf. `kAppModules`) inclus dans cette offre.
  final int? maxModules;

  const SbPlan({
    required this.code,
    required this.name,
    this.tagline,
    this.maxStudents,
    this.features = const [],
    this.sortOrder = 0,
    this.includedStudents,
    this.maxModules,
  });

  bool get isUnlimited => maxStudents == null;
  String get limitLabel => includedStudents == null
      ? 'Illimité'
      : 'Jusqu\'à $includedStudents élèves inclus';

  factory SbPlan.fromJson(Map<String, dynamic> j) => SbPlan(
        code: j['code'] as String,
        name: j['name'] as String? ?? '',
        tagline: j['tagline'] as String?,
        maxStudents: j['max_students'] as int?,
        features: (j['features'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        sortOrder: j['sort_order'] as int? ?? 0,
        includedStudents: j['included_students'] as int?,
        maxModules: j['max_modules'] as int?,
      );
}

/// Supplément mensuel selon le nombre réel d'élèves, par tranche — au-delà de
/// la franchise du palier (`SbPlan.includedStudents`). `surcharge == null` =
/// tranche "sur devis" (contacter le support), pas un montant à zéro.
class SbPlanSizeSurcharge {
  final String planCode;
  final int minStudents;
  final int? maxStudents; // null = tranche ouverte
  final double? surcharge; // null = sur devis
  final String currency;

  const SbPlanSizeSurcharge({
    required this.planCode,
    required this.minStudents,
    this.maxStudents,
    this.surcharge,
    required this.currency,
  });

  bool matches(int studentCount) =>
      studentCount >= minStudents && (maxStudents == null || studentCount <= maxStudents!);

  factory SbPlanSizeSurcharge.fromJson(Map<String, dynamic> j) => SbPlanSizeSurcharge(
        planCode: j['plan_code'] as String,
        minStudents: (j['min_students'] as num).toInt(),
        maxStudents: (j['max_students'] as num?)?.toInt(),
        surcharge: (j['surcharge'] as num?)?.toDouble(),
        currency: j['currency'] as String? ?? 'XAF',
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

  /// Métadonnées libres de la référence (ex. `{"exam": "CEPE"}` sur le CM2).
  final Map<String, dynamic> metadata;

  const SbClassLevel({
    required this.id,
    required this.systemType,
    required this.cycle,
    required this.cycleLabel,
    required this.name,
    required this.shortName,
    this.series,
    this.orderNum = 0,
    this.metadata = const {},
  });

  String get fullLabel => '$cycleLabel · $name';

  /// Classe candidate à un examen de fin de cycle (ex. CM2 → CEPE) — pas
  /// codé en dur : lu depuis `class_levels.metadata.exam`.
  bool get isExamLevel => metadata['exam'] != null;

  factory SbClassLevel.fromJson(Map<String, dynamic> j) => SbClassLevel(
        id: j['id'] as String,
        systemType: j['system_type'] as String? ?? '',
        cycle: j['cycle'] as String? ?? '',
        cycleLabel: j['cycle_label'] as String? ?? '',
        name: j['name'] as String? ?? '',
        shortName: j['short_name'] as String? ?? '',
        series: j['series'] as String?,
        orderNum: j['order_num'] as int? ?? 0,
        metadata: j['metadata'] is Map<String, dynamic>
            ? j['metadata'] as Map<String, dynamic>
            : const {},
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
  final String cycle;       // prescolaire | primaire | college | lycee
  final String name;
  final String? shortName;
  final num defaultCoefficient;
  final int orderNum;

  /// Série du lycée à laquelle la matière (et son coefficient) est propre :
  /// `A`, `C`, `D`… `null` = tronc commun (toutes séries du cycle). Sert de
  /// référence pour pré-remplir le coefficient par série dans `class_subjects` ;
  /// la table `subjects` de l'école, elle, reste plate (un seul coef par nom).
  final String? series;

  /// Réserve la matière aux niveaux dont `class_levels.order_num` (même cycle)
  /// est au moins celui-ci — ex. l'anglais qui n'apparaît qu'à partir du CM1
  /// au primaire. `null` = s'applique à tout le cycle (comportement par défaut).
  final int? minOrderNum;

  const SbSubjectCatalog({
    required this.id,
    required this.cycle,
    required this.name,
    this.shortName,
    this.defaultCoefficient = 1,
    this.orderNum = 0,
    this.series,
    this.minOrderNum,
  });

  factory SbSubjectCatalog.fromJson(Map<String, dynamic> j) => SbSubjectCatalog(
        id: j['id'] as String,
        cycle: j['cycle'] as String? ?? '',
        name: j['name'] as String? ?? '',
        shortName: j['short_name'] as String?,
        defaultCoefficient: (j['default_coefficient'] as num?) ?? 1,
        orderNum: j['order_num'] as int? ?? 0,
        series: j['series'] as String?,
        minOrderNum: (j['min_order_num'] as num?)?.toInt(),
      );

  String get cycleLabel => switch (cycle) {
        'prescolaire' => 'Préscolaire',
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

  /// Progression réelle indiquée par le prof (cf. `set_course_chapters_done`)
  /// — distincte de `chapterCount` (nombre total, fixé par l'admin dans le
  /// programme officiel).
  final int chaptersDone;
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
    this.chaptersDone = 0,
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
      chaptersDone: (j['chapters_done'] as num?)?.toInt() ?? 0,
      daysOfWeek: days,
      room: j['room'] as String?,
    );
  }
}

/// Un support de cours (`course_materials`) : PDF, exercice, corrigé… rattaché
/// à une matière. Alimente l'onglet « Ressources » du détail d'un cours.
class SbCourseMaterial {
  final String id;
  final String title;
  final String subject;
  final String? type;      // 'cours' | 'exercice' | 'corrige' | 'td'…
  final String? level;     // niveau/classe visé
  final String? publisher; // qui l'a déposé
  final String? fileUrl;
  final int? sizeKb;
  final DateTime? createdAt;

  const SbCourseMaterial({
    required this.id,
    required this.title,
    required this.subject,
    this.type,
    this.level,
    this.publisher,
    this.fileUrl,
    this.sizeKb,
    this.createdAt,
  });

  factory SbCourseMaterial.fromJson(Map<String, dynamic> j) => SbCourseMaterial(
        id: j['id'] as String,
        title: j['title'] as String? ?? '—',
        subject: j['subject'] as String? ?? '',
        type: j['type'] as String?,
        level: j['level'] as String?,
        publisher: j['publisher'] as String?,
        fileUrl: j['file_url'] as String?,
        sizeKb: (j['size_kb'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
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

    /// Emplacements de modules complémentaires achetés à la carte, en plus
    /// du quota inclus dans l'offre (`plans.max_modules`) — cf.
    /// `backup/migrations_archive/20260809_module_slot_addon.sql`.
    final int extraModuleSlots;

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
      this.extraModuleSlots = 0,
    });

    bool get isTrial  => status == 'trial';
    bool get isActive => status == 'active' || status == 'trial';

    DateTime? get endDate => currentPeriodEnd ?? trialEnd;

    /// Jours restants avant la fin de la période/essai en cours. Plafonné à 0
    /// (jamais négatif) — pour savoir si le délai est VRAIMENT dépassé, cf.
    /// [isReadOnly], pas ce champ (un essai fini depuis 3 jours affiche
    /// toujours 0 ici, pas -3).
    int get daysLeft {
      final end = endDate;
      if (end == null) return 0;
      return end.difference(DateTime.now()).inDays.clamp(0, 999);
    }

    /// Miroir EXACT de `public.subscription_is_active()` (cf.
    /// 20260733_enforce_subscription.sql) — c'est la RLS, pas `status`, qui
    /// décide si l'école peut encore écrire. `status` reste souvent `'trial'`
    /// indéfiniment (rien ne le bascule automatiquement à `'expired'`) : sans
    /// ce getter, l'app continuerait d'afficher un accès normal alors que la
    /// base refuse déjà toute écriture derrière.
    bool get isReadOnly {
      if (status != 'trial' && status != 'active') return true;
      final periodEnd = currentPeriodEnd;
      if (periodEnd != null && !periodEnd.isAfter(DateTime.now())) return true;
      if (status == 'trial') {
        final te = trialEnd;
        if (te != null && !te.isAfter(DateTime.now())) return true;
      }
      return false;
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
          extraModuleSlots: j['extra_module_slots'] as int? ?? 0,
        );
  }

  /// Un versement d'abonnement (école → Scolaris), figé pour le reçu.
  /// `amount` = montant réellement encaissé ; `creditApplied` = crédit
  /// (prorata + report) déduit ; prix plein de l'offre = `amount + creditApplied`.
  class SbSubscriptionPayment {
    final String id;
    final String? subscriptionId;
    final String? schoolId;
    final String? planCode;
    final String? period; // 'monthly' | 'annual'
    final double amount;
    final double creditApplied;
    final String currency;
    final String? method; // mobile_money | card | bank | cash
    final String? provider;
    final String? reference;
    final String status; // pending | success | failed | refunded
    final DateTime? paidAt;
    final DateTime? createdAt;
    /// Offre quittée lors de ce versement, si c'était un changement d'offre
    /// (`subscription_payments.previous_plan_code`) — `null` pour un simple
    /// renouvellement (aucun changement de plan).
    final String? previousPlanCode;

    /// 'plan_change' (défaut, renouvellement/upgrade/downgrade d'offre) ou
    /// 'addon_slot' (achat à la carte d'un emplacement de module — n'écrase
    /// PAS le plan_code de l'école à la confirmation, cf.
    /// `platform_confirm_subscription_payment`).
    final String paymentType;

    /// Nombre d'emplacements achetés — uniquement pertinent si
    /// [paymentType] == 'addon_slot'.
    final int quantity;

    const SbSubscriptionPayment({
      required this.id,
      this.subscriptionId,
      this.schoolId,
      this.planCode,
      this.period,
      this.amount = 0,
      this.creditApplied = 0,
      this.currency = 'XAF',
      this.method,
      this.provider,
      this.reference,
      this.status = 'success',
      this.paidAt,
      this.createdAt,
      this.previousPlanCode,
      this.paymentType = 'plan_change',
      this.quantity = 1,
    });

    double get fullPrice => amount + creditApplied;
    bool get isYearly => period == 'annual';
    DateTime get date => paidAt ?? createdAt ?? DateTime.now();
    bool get isPlanChange =>
        previousPlanCode != null && previousPlanCode != planCode;
    bool get isAddonSlot => paymentType == 'addon_slot';

    factory SbSubscriptionPayment.fromJson(Map<String, dynamic> j) =>
        SbSubscriptionPayment(
          id: j['id'] as String? ?? '',
          subscriptionId: j['subscription_id'] as String?,
          previousPlanCode: j['previous_plan_code'] as String?,
          schoolId: j['school_id'] as String?,
          planCode: j['plan_code'] as String?,
          period: j['period'] as String?,
          amount: (j['amount'] as num?)?.toDouble() ?? 0,
          creditApplied: (j['credit_applied'] as num?)?.toDouble() ?? 0,
          currency: j['currency'] as String? ?? 'XAF',
          method: j['method'] as String?,
          provider: j['provider'] as String?,
          reference: j['reference'] as String?,
          status: j['status'] as String? ?? 'success',
          paidAt: j['paid_at'] != null
              ? DateTime.tryParse(j['paid_at'] as String)
              : null,
          createdAt: j['created_at'] != null
              ? DateTime.tryParse(j['created_at'] as String)
              : null,
          paymentType: j['payment_type'] as String? ?? 'plan_change',
          quantity: j['quantity'] as int? ?? 1,
        );
  }

// ── Data source ───────────────────────────────────────────────────────────────

/// Traduit une écriture Postgrest en message français lisible AVANT qu'elle
/// ne remonte à l'écran — la quasi-totalité des écrans font juste
/// `catch (e) { snackbar('Échec : $e') }` : rendre `e` lisible ICI rend tous
/// ces écrans corrects d'un coup, sans les toucher un par un.
///
/// `.friendly()` s'ajoute en bout de chaîne sur tout `.insert()/.update()
/// /.upsert()/.delete()` — cf. les méthodes de [SupabaseDbSource].
extension PostgrestFriendlyError<T> on PostgrestBuilder<T, T, dynamic> {
  Future<T> friendly() async {
    try {
      return await this;
    } on PostgrestException catch (e) {
      throw Exception(_friendlyPostgrestMessage(e));
    }
  }
}

/// cf. 20260733_enforce_subscription.sql (lecture seule si abonnement pas en
/// règle) et les contraintes Postgres les plus fréquentes du schéma.
String _friendlyPostgrestMessage(PostgrestException e) {
  switch (e.code) {
    case '42501':
      return 'Abonnement en lecture seule — vos données restent visibles, '
          'mais choisissez une offre pour pouvoir enregistrer.';
    case '23505':
      return 'Cette valeur existe déjà (doublon) — vérifiez avant de réessayer.';
    case '23503':
      return 'Impossible : un élément lié est introuvable ou a été supprimé.';
    case '23514':
      return 'Valeur invalide pour ce champ.';
    case '42P01':
      return 'Fonctionnalité indisponible pour le moment (contactez le support).';
    default:
      return e.message.isNotEmpty ? e.message : 'Échec de l\'opération.';
  }
}

class SupabaseDbSource {
  static SupabaseClient get _db => Supabase.instance.client;

  // ── Students ──────────────────────────────────────────────────────────────
  static const String _studentSelect =
      'id, full_name, email, avatar_url, status, '
      'student_profiles(matricule, class_id, enrollment_status, exit_reason, '
      'exit_date, date_of_birth, metadata, classes(name, level, main_teacher_id))';

  /// [includeExited] : par défaut, seuls les élèves ACTIFS (`enrollment_status
  /// = 'active'`) — un transféré/diplômé/radié ne doit pas polluer les listes
  /// de classe, le carnet de notes, etc. `true` pour l'archive dédiée.
  static Future<List<SbStudent>> getStudents({
    String? classe,
    String? schoolId,
    bool includeExited = false,
  }) async {
    var q = _db.from('users').select(_studentSelect).eq('role', 'student');
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('full_name');
    var list = (data as List)
        .map((j) => SbStudent.fromUserRow(j as Map<String, dynamic>))
        .toList();
    if (!includeExited) list = list.where((s) => !s.hasExited).toList();
    if (classe != null) list = list.where((s) => s.classe == classe).toList();
    return list;
  }

  /// Les élèves sortis (transféré/diplômé/radié) — l'archive, avec leur motif
  /// et leur date de sortie. Dossier conservé intact, juste hors effectifs actifs.
  static Future<List<SbStudent>> getExitedStudents(String schoolId) async {
    final all = await getStudents(schoolId: schoolId, includeExited: true);
    return all.where((s) => s.hasExited).toList();
  }

  /// Marque un élève comme SORTI de l'école — jamais une suppression. Son
  /// dossier (notes, bulletins) reste intact ; il quitte juste sa classe et
  /// les effectifs actifs. Trace la décision dans `student_progressions`.
  static Future<void> withdrawStudent({
    required String schoolId,
    required String studentId,
    required String decision, // 'transferred' | 'graduated' | 'withdrawn'
    String? reason,
    String? academicYear,
  }) async {
    final profile = await _db
        .from('student_profiles')
        .select('class_id')
        .eq('user_id', studentId)
        .maybeSingle();
    final fromClassId = profile?['class_id'] as String?;
    final actorId = await _currentUserRowId();

    await _db.from('student_profiles').update({
      'enrollment_status': decision,
      'exit_reason': reason,
      'exit_date': DateTime.now().toIso8601String().substring(0, 10),
      'class_id': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', studentId).friendly();

    await _db.from('student_progressions').insert({
      'school_id': schoolId,
      'student_id': studentId,
      'from_class_id': fromClassId,
      'to_class_id': null,
      'from_academic_year': academicYear,
      'to_academic_year': null,
      'decision': decision,
      'reason': reason,
      'decided_by': actorId,
      'decided_by_name': actorId == null ? null : await _actorName(actorId),
    }).friendly();
  }

  /// Met à jour les champs médicaux structurés (groupe sanguin, allergies,
  /// vulnérabilité) — stockés dans `student_profiles.metadata`, pas de colonnes
  /// dédiées. Lecture-fusion-écriture pour ne pas écraser `metadata.documents`
  /// posé par [setStudentDocumentStatus].
  static Future<void> updateStudentMedical({
    required String studentId,
    String? bloodGroup,
    String? allergies,
    String? vulnerability,
  }) async {
    final row = await _db
        .from('student_profiles')
        .select('metadata')
        .eq('user_id', studentId)
        .maybeSingle();
    final current = row?['metadata'];
    final metadata = <String, dynamic>{
      if (current is Map<String, dynamic>) ...current,
      'blood_group': bloodGroup?.trim().isEmpty == true ? null : bloodGroup?.trim(),
      'allergies': allergies?.trim().isEmpty == true ? null : allergies?.trim(),
      'vulnerability': vulnerability?.trim().isEmpty == true ? null : vulnerability?.trim(),
    };
    await _db
        .from('student_profiles')
        .update({'metadata': metadata})
        .eq('user_id', studentId).friendly();
  }

  /// Coche/décoche un document du suivi de conformité post-inscription (acte
  /// de naissance, carnet de vaccination…) — checklist indépendante des
  /// fichiers déposés à la pré-inscription (`enrollment-documents`), qui suit
  /// simplement si le dossier PAPIER est complet, dans le temps.
  static Future<void> setStudentDocumentStatus({
    required String studentId,
    required String documentKey,
    required bool provided,
  }) async {
    final row = await _db
        .from('student_profiles')
        .select('metadata')
        .eq('user_id', studentId)
        .maybeSingle();
    final current = row?['metadata'];
    final metadata = <String, dynamic>{
      if (current is Map<String, dynamic>) ...current,
    };
    final docs = <String, dynamic>{
      if (metadata['documents'] is Map) ...(metadata['documents'] as Map),
      documentKey: provided,
    };
    metadata['documents'] = docs;
    await _db
        .from('student_profiles')
        .update({'metadata': metadata})
        .eq('user_id', studentId).friendly();
  }

  /// Annule une sortie décidée par erreur : redevient actif dans la classe
  /// donnée. Ne modifie pas l'historique déjà écrit dans `student_progressions`
  /// (une décision se corrige par une nouvelle ligne, pas en place).
  static Future<void> reactivateStudent({
    required String studentId,
    String? classId,
  }) async {
    await _db.from('student_profiles').update({
      'enrollment_status': 'active',
      'exit_reason': null,
      'exit_date': null,
      if (classId != null) 'class_id': classId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', studentId).friendly();
  }

  static Future<String?> _actorName(String userId) async {
    final row = await _db
        .from('users')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();
    return row?['full_name'] as String?;
  }

  /// L'id `users.id` (≠ auth uid) du compte connecté — nécessaire pour toute
  /// colonne qui référence `users(id)` (ex. `decided_by`). `null` si le compte
  /// connecté n'a pas de fiche `users` (ne devrait pas arriver en pratique).
  static Future<String?> _currentUserRowId() async {
    final auth = _db.auth.currentUser;
    if (auth == null) return null;
    final row = await _db
        .from('users')
        .select('id')
        .eq('auth_uid', auth.id)
        .maybeSingle();
    return row?['id'] as String?;
  }

  /// Nom du niveau suivant dans la taxonomie de l'école (ex. "CM2" → "6e"),
  /// via `class_levels.order_num` (cf. SchoolTaxonomy). `null` si [currentLevelName]
  /// est le dernier niveau du système (fin de cycle/école) ou introuvable.
  static Future<String?> getNextLevelName({
    required String systemType,
    required String currentLevelName,
  }) async {
    final rows = await _db
        .from('class_levels')
        .select('name, order_num')
        .eq('system_type', systemType)
        .order('order_num');
    final list = (rows as List).cast<Map<String, dynamic>>();
    final idx = list.indexWhere((r) => r['name'] == currentLevelName);
    if (idx == -1 || idx + 1 >= list.length) return null;
    return list[idx + 1]['name'] as String;
  }

  /// APPLIQUE en bloc les décisions de fin d'année d'une classe : passage
  /// (classe supérieure ou redouble) ou sortie (transfert/diplôme/radiation).
  /// Un seul geste, pas de palier de confirmation séparé : la ligne
  /// `student_progressions` est écrite directement en `status: 'confirmed'`
  /// et `student_profiles` est mis à jour dans la foulée (classe/année, ou
  /// statut de sortie). Pour un redoublant, la classe de destination est
  /// toujours la classe de départ (même niveau, année suivante) — même si
  /// aucune classe n'a été choisie côté UI.
  static Future<void> applyYearEndDecisions({
    required String schoolId,
    required String toAcademicYear,
    required List<PromotionDecision> decisions,
  }) async {
    final actorId = await _currentUserRowId();
    final actorName = actorId == null ? null : await _actorName(actorId);
    final now = DateTime.now();

    for (final d in decisions) {
      final isExit = d.decision == 'transferred' ||
          d.decision == 'graduated' ||
          d.decision == 'withdrawn';
      final effectiveToClassId = isExit
          ? null
          : (d.decision == 'repeated' ? d.fromClassId : d.toClassId);

      await _db.from('student_progressions').insert({
        'school_id': schoolId,
        'student_id': d.studentId,
        'from_class_id': d.fromClassId,
        'to_class_id': effectiveToClassId,
        'from_academic_year': d.fromAcademicYear,
        'to_academic_year': isExit ? null : toAcademicYear,
        'decision': d.decision,
        'average': d.average,
        'reason': d.reason,
        'decided_by': actorId,
        'decided_by_name': actorName,
        'status': 'confirmed',
      }).friendly();

      if (isExit) {
        await _db.from('student_profiles').update({
          'enrollment_status': d.decision,
          'exit_reason': d.reason,
          'exit_date': now.toIso8601String().substring(0, 10),
          'class_id': null,
          'updated_at': now.toIso8601String(),
        }).eq('user_id', d.studentId).friendly();
      } else {
        await _db.from('student_profiles').update({
          'class_id': effectiveToClassId,
          'academic_year': toAcademicYear,
          'updated_at': now.toIso8601String(),
        }).eq('user_id', d.studentId).friendly();
      }
    }
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

  /// Les parents/tuteurs d'un élève, via `parent_student`, enrichis du contact
  /// (`users`). Deux requêtes, même raison que [getChildrenForParent] : ne pas
  /// dépendre du nom de la contrainte FK pour un embed PostgREST.
  static Future<List<SbGuardianLink>> getGuardiansForStudent(
      String studentId) async {
    final links = await _db
        .from('parent_student')
        .select('parent_id, relationship, is_primary')
        .eq('student_id', studentId);

    final rows = (links as List).cast<Map<String, dynamic>>();
    final ids = rows
        .map((r) => r['parent_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];

    final users = await _db
        .from('users')
        .select('id, full_name, email, phone, auth_uid')
        .inFilter('id', ids);
    final byId = <String, Map<String, dynamic>>{
      for (final u in (users as List).cast<Map<String, dynamic>>())
        u['id'] as String: u,
    };

    return rows.map((r) {
      final u = byId[r['parent_id']];
      return SbGuardianLink(
        parentId: r['parent_id'] as String,
        fullName: (u?['full_name'] as String?)?.trim().isNotEmpty == true
            ? u!['full_name'] as String
            : 'Parent',
        email: u?['email'] as String?,
        phone: u?['phone'] as String?,
        relationship: (r['relationship'] as String?)?.isNotEmpty == true
            ? r['relationship'] as String
            : 'Parent',
        isPrimary: r['is_primary'] as bool? ?? false,
        hasAccount: u?['auth_uid'] != null,
      );
    }).toList();
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
        .eq('user_id', userId).friendly();
  }

  /// Retire un élève de sa classe (laisse la fiche, vide juste l'affectation).
  static Future<void> unassignStudentFromClass(String userId) async {
    await _db
        .from('student_profiles')
        .update({'class_id': null})
        .eq('user_id', userId).friendly();
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
  ///
  /// [series] restreint en plus aux matières d'un lot de séries du lycée. La
  /// convention : `series = null` en base = **tronc commun** (toutes séries) —
  /// on le garde TOUJOURS, on ne filtre que les lignes propres à une série. Un
  /// filtre `['C','D']` renvoie donc : le tronc commun + les matières C + D,
  /// mais pas les matières propres à A.
  static Future<List<SbSubjectCatalog>> getSubjectCatalog({
    String system = 'francophone_africa',
    List<String> cycles = const ['prescolaire', 'primaire', 'college', 'lycee'],
    List<String>? series,
  }) async {
    final data = await _db
        .from('subject_catalog')
        .select()
        .eq('system_type', system)
        .inFilter('cycle', cycles)
        .order('order_num');
    var list = (data as List)
        .map((j) => SbSubjectCatalog.fromJson(j as Map<String, dynamic>))
        .toList();
    if (series != null) {
      // Tronc commun (series == null) toujours conservé ; sinon la série doit
      // faire partie du lot demandé.
      list = list
          .where((c) => c.series == null || series.contains(c.series))
          .toList();
    }
    return list;
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
    }).friendly();
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
    await _db.from('subjects').update(patch).eq('id', id).friendly();
  }

  static Future<void> deleteSubject(String id) async {
    await _db.from('subjects').delete().eq('id', id).friendly();
  }

  /// Supprime TOUTES les matières de l'école (bouton « Tout supprimer » de
  /// la page Matières). Les cours qui en dépendaient perdent leur rattachement,
  /// comme une suppression une par une.
  static Future<void> deleteAllSubjects(String schoolId) async {
    await _db.from('subjects').delete().eq('school_id', schoolId).friendly();
  }

  /// Génère le programme par défaut d'une classe à partir du catalogue de
  /// matières types (`subject_catalog`) du cycle (+ séries lycée). Garantit
  /// d'abord que ces matières existent dans le catalogue de l'école (comme
  /// [loadSubjectsFromCatalog]), puis crée un `courses` classe×matière pour
  /// chacune (coefficient par défaut du catalogue, sans enseignant — à
  /// assigner ensuite). Idempotent : rejouable sans doublon.
  ///
  /// [levelOrderNum] est le `class_levels.order_num` du niveau exact de la
  /// classe (ex. CM1) : une entrée du catalogue dont `minOrderNum` dépasse
  /// cette valeur est ignorée (ex. l'anglais réservé à partir du CM1, absent
  /// des classes plus jeunes). `null` = aucune restriction appliquée.
  ///
  /// Renvoie le nombre de cours créés.
  static Future<int> generateDefaultProgramForClass({
    required String schoolId,
    required String classId,
    required String cycle,
    List<String>? series,
    int? levelOrderNum,
  }) async {
    var catalog = await getSubjectCatalog(cycles: [cycle], series: series);
    if (levelOrderNum != null) {
      catalog = catalog
          .where((c) => c.minOrderNum == null || c.minOrderNum! <= levelOrderNum)
          .toList();
    }
    if (catalog.isEmpty) return 0;

    await loadSubjectsFromCatalog(
        schoolId: schoolId, cycles: [cycle], series: series);
    final subjects = await getSubjects(schoolId: schoolId);
    final subjectByName = {
      for (final s in subjects) s.name.trim().toLowerCase(): s,
    };

    final existingCourses = await getCoursesForClass(classId);
    final coveredSubjectIds = existingCourses
        .map((c) => c.subjectId)
        .whereType<String>()
        .toSet();

    final seen = <String>{};
    var created = 0;
    for (final c in catalog) {
      final key = c.name.trim().toLowerCase();
      if (!seen.add(key)) continue;
      final subject = subjectByName[key];
      if (subject == null) continue;
      if (coveredSubjectIds.contains(subject.id)) continue;
      await createCourse(
        schoolId: schoolId,
        classId: classId,
        subjectId: subject.id,
        name: subject.name,
        code: subject.code,
        coefficient: c.defaultCoefficient.round(),
      );
      created++;
    }
    return created;
  }

  /// Charge les matières types du catalogue dans les matières de l'école.
  /// N'ajoute que celles dont le nom n'existe pas déjà (insensible à la casse).
  /// Renvoie le nombre de matières réellement ajoutées.
  static Future<int> loadSubjectsFromCatalog({
    required String schoolId,
    required List<String> cycles,
    List<String>? series,
  }) async {
    final catalog = await getSubjectCatalog(cycles: cycles, series: series);
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
    await _db.from('subjects').insert(rows).friendly();
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
  //
  //  Un pointage est identifié par (élève, jour, PROF, MATIÈRE) depuis
  //  20260731_attendance_per_teacher.sql : au collège/lycée, plusieurs profs
  //  prennent la même classe le même jour, mais jamais dans le même cours —
  //  un seul `teacher_id` ne suffisait pas non plus (un même prof peut donner
  //  deux matières différentes à la même classe le même jour). `subject_id`
  //  est `null` seulement pour le pointage « journée entière » du titulaire
  //  (primaire) ou du staff (supervision), qui ne sont pas liés à un cours.

  static String _isoDate(DateTime d) => d.toIso8601String().split('T').first;

  static Future<List<SbAttendance>> getAttendanceForClass(
    String classId, {
    DateTime? date,
    String? teacherId,
    String? subjectId,
    bool filterBySubject = false,
  }) async {
    var q = _db
        .from('absences')
        .select()
        .eq('class_id', classId)
        .eq('absence_date', _isoDate(date ?? DateTime.now()));
    if (teacherId != null) q = q.eq('teacher_id', teacherId);
    if (filterBySubject) {
      q = subjectId == null
          ? q.isFilter('subject_id', null)
          : q.eq('subject_id', subjectId);
    }
    final data = await q;
    return (data as List).map((j) => SbAttendance.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Absences et retards de toute une classe — pour le bulletin, qui les
  /// compte par élève. On ne lit **que** ce qui fait défaut (`status <> present`) :
  /// une classe de 40 élèves sur un trimestre, c'est des milliers de lignes de
  /// présence dont le bulletin n'a rien à faire.
  ///
  /// Peut renvoyer PLUSIEURS lignes pour le même (élève, jour) désormais —
  /// un jour d'absence complète peut être marqué par plusieurs profs. Les
  /// appelants qui comptent des absences doivent passer par
  /// [dedupeAbsencesByDay] pour ne pas compter 1 jour comme N absences.
  static Future<List<SbAbsence>> getAbsencesForClass(String classId) async {
    final data = await _db
        .from('absences')
        .select('*, subjects(name)')
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
        .select('*, subjects(name)')
        .eq('student_id', studentId)
        .neq('status', 'present')   // l'élève ne lit que ce qui fait défaut
        .order('absence_date', ascending: false);
    return (data as List).map((j) => SbAbsence.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Toutes les absences/retards non justifiés de l'école — pour l'écran de
  /// justification staff (`presences.modifier`).
  static Future<List<SbAbsence>> getPendingJustifications(String schoolId) async {
    final data = await _db
        .from('absences')
        .select()
        .eq('school_id', schoolId)
        .neq('status', 'present')
        .eq('justified', false)
        .order('absence_date', ascending: false);
    return (data as List).map((j) => SbAbsence.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Marque une absence/retard justifié (ou revient en arrière) — l'action
  /// « le mot des parents est arrivé », réservée à `presences.modifier` (RLS).
  static Future<void> justifyAbsence(
    String id, {
    required bool justified,
    String? reason,
  }) async {
    await _db.from('absences').update({
      'justified': justified,
      'reason': reason,
    }).eq('id', id).friendly();
  }

  /// Regroupe des absences/retards par (élève, jour) et garde le pire statut
  /// du jour (absent > retard > le reste) — nécessaire car plusieurs profs
  /// peuvent chacun marquer un même élève absent le même jour (une ligne par
  /// prof) : sans ce regroupement, un jour d'absence complète compterait pour
  /// N absences au lieu d'1 dans le bulletin et les écrans élève/parent.
  static List<SbAbsence> dedupeAbsencesByDay(List<SbAbsence> absences) {
    int rank(String s) => switch (s) {
          'absent' => 2,
          'late' => 1,
          _ => 0,
        };
    final byDay = <String, SbAbsence>{};
    for (final a in absences) {
      final key = '${a.studentId}|${a.absenceDate?.toIso8601String() ?? ''}';
      final cur = byDay[key];
      if (cur == null || rank(a.status) > rank(cur.status)) {
        byDay[key] = a;
      }
    }
    return byDay.values.toList()
      ..sort((a, b) =>
          (b.absenceDate ?? DateTime(0)).compareTo(a.absenceDate ?? DateTime(0)));
  }

  /// Enregistre l'appel pour une date donnée (défaut aujourd'hui). Un élève,
  /// un jour, un PROF, une MATIÈRE (ou aucune, pour un pointage journée
  /// entière) : ce prof se corrige sans écraser le pointage d'un collègue —
  /// ni même son PROPRE pointage d'une autre matière à la même classe le même
  /// jour.
  ///
  /// Écrit en DELETE puis INSERT plutôt qu'un upsert : `subject_id` est
  /// souvent `null` (titulaire/staff), et deux valeurs NULL ne sont jamais
  /// considérées égales par Postgres — un `ON CONFLICT` sur une colonne
  /// nullable ne détecterait donc jamais ces lignes comme un doublon à
  /// corriger, et en créerait une nouvelle à chaque re-saisie.
  static Future<void> saveAttendance(
    List<SbAttendance> records, {
    required String schoolId,
    required String teacherId,
    String? subjectId,
    DateTime? date,
  }) async {
    final day = _isoDate(date ?? DateTime.now());
    final studentIds = records.map((r) => r.studentId).toList();
    if (studentIds.isEmpty) return;

    var del = _db
        .from('absences')
        .delete()
        .eq('absence_date', day)
        .eq('teacher_id', teacherId)
        .inFilter('student_id', studentIds);
    del = subjectId == null
        ? del.isFilter('subject_id', null)
        : del.eq('subject_id', subjectId);
    await del.friendly();

    final rows = records.map((r) => {
      'school_id': schoolId,
      'student_id': r.studentId,
      'class_id': r.classId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'absence_date': day,
      'status': r.status,
      'arrival_time': r.arrivalTime,
    }).toList();
    await _db.from('absences').insert(rows).friendly();
  }

  // ── Invoices ──────────────────────────────────────────────────────────────
  static Future<List<SbInvoice>> getInvoices({String? schoolId}) async {
    var q = _db
        .from('invoices')
        .select('*, users!student_id(full_name), payments(amount,status)');
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
    }).friendly();
  }

  /// Enregistre un encaissement (espèces par défaut). Le statut de la facture est
  /// recalculé à partir du CUMUL encaissé : « paid » si le solde est couvert,
  /// sinon on garde « pending » (paiement partiel — pas de valeur de statut
  /// dédiée pour ne pas dépendre d'un CHECK que le dépôt ne versionne pas).
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
    }).friendly();

    // Recalcule le cumul encaissé vs le montant dû.
    final inv = await _db
        .from('invoices')
        .select('amount')
        .eq('id', invoiceId)
        .maybeSingle();
    final due = (inv?['amount'] as num?)?.toDouble() ?? 0;
    final pays =
        await _db.from('payments').select('amount').eq('invoice_id', invoiceId);
    final paid = (pays as List).fold<double>(
        0, (a, p) => a + (((p as Map)['amount'] as num?)?.toDouble() ?? 0));

    await _db.from('invoices').update({
      // Tolérance d'un centime pour les arrondis.
      'status': paid >= due - 0.01 ? 'paid' : 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', invoiceId).friendly();
  }

  /// Un parent/élève déclare avoir envoyé l'argent (référence Mobile Money
  /// reçue par SMS après un transfert USSD manuel vers le numéro marchand de
  /// l'école — pas d'agrégateur branché). Les familles sont en lecture seule
  /// sur `payments` (sécurité : pas d'auto-déclaration de paiement confirmé)
  /// → l'écriture passe par l'Edge Function `record-online-payment`, qui
  /// vérifie le lien famille↔élève puis écrit `status: 'pending'` côté
  /// serveur. Le solde ne bouge qu'une fois l'admin passé par [confirmPayment].
  static Future<void> recordOnlinePayment({
    required String invoiceId,
    required double amount,
    required String reference,
    String method = 'mobile_money',
  }) async {
    final res = await _db.functions.invoke('record-online-payment', body: {
      'invoiceId': invoiceId,
      'amount': amount,
      'method': method,
      'reference': reference,
    });
    _throwIfFnError(res);
  }

  /// Version SCOLARITÉ/INSCRIPTION du paiement en ligne : pas de facture à
  /// pointer (il n'y en a plus tant qu'aucun encaissement n'a eu lieu), donc
  /// on identifie la cible par élève + catégorie plutôt que par `invoiceId`.
  /// ⚠️ Suppose la version DÉPLOYÉE de l'Edge Function `record-online-payment`
  /// à jour avec ce nouveau payload (cf. `supabase/functions/record-online-payment/index.ts`).
  static Future<void> recordOnlineTuitionPayment({
    required String studentId,
    required String schoolId,
    required String academicYear,
    required String category, // 'tuition' | 'registration'
    required double amount,
    required String reference,
    String method = 'mobile_money',
  }) async {
    final res = await _db.functions.invoke('record-online-payment', body: {
      'studentId': studentId,
      'schoolId': schoolId,
      'academicYear': academicYear,
      'category': category,
      'amount': amount,
      'method': method,
      'reference': reference,
    });
    _throwIfFnError(res);
  }

  /// Supprime une facture (et ses encaissements éventuels).
  static Future<void> deleteInvoice(String invoiceId) async {
    await _db.from('payments').delete().eq('invoice_id', invoiceId).friendly();
    await _db.from('invoices').delete().eq('id', invoiceId).friendly();
  }

  static Future<List<SbInvoice>> getInvoicesForStudent(String studentId) async {
    final data = await _db
        .from('invoices')
        .select('*, payments(amount,status)')
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return (data as List).map((j) => SbInvoice.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Historique des VERSEMENTS individuels d'un élève (table `payments`), le
  /// plus récent d'abord — utile pour un reçu par versement, distinct de la
  /// facture annuelle unique qui, elle, ne montre que le cumul.
  static Future<List<SbPayment>> getPaymentsForStudent(String studentId) async {
    final data = await _db
        .from('payments')
        .select()
        .eq('student_id', studentId)
        .order('payment_date', ascending: false);
    return (data as List).map((j) => SbPayment.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Tous les versements CONFIRMÉS de l'école (cash + en ligne validé), toutes
  /// catégories confondues (scolarité, inscription, autres frais) — la vue
  /// « Historique des paiements » côté admin. `invoices(category, description,
  /// period)` est embedé pour afficher le motif sans requête supplémentaire.
  static Future<List<SbPayment>> getPaymentsForSchool(String schoolId,
      {int limit = 300}) async {
    final data = await _db
        .from('payments')
        .select(
            '*, users!inner(full_name, school_id), invoices(category, description, period)')
        .eq('users.school_id', schoolId)
        .eq('status', 'confirmed')
        .order('payment_date', ascending: false)
        .limit(limit);
    return (data as List).map((j) => SbPayment.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Versements Mobile Money envoyés par une famille (référence saisie) et pas
  /// encore vérifiés par l'admin — la file « Paiements à vérifier ».
  static Future<List<SbPayment>> getPendingPayments(String schoolId) async {
    // Filtre par l'école DE L'ÉLÈVE (`users.school_id`), pas via `invoices` :
    // un versement en ligne de scolarité/inscription n'a plus de facture tant
    // qu'il n'est pas confirmé (`invoice_id` null) — un `invoices!inner`
    // l'aurait exclu silencieusement de la file à vérifier.
    final data = await _db
        .from('payments')
        .select('*, users!inner(full_name, school_id)')
        .eq('status', 'pending')
        .eq('users.school_id', schoolId)
        .order('created_at', ascending: false);
    return (data as List).map((j) => SbPayment.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// L'admin a vérifié sur son relevé marchand que l'argent est bien arrivé :
  /// le versement compte enfin dans le solde de la facture.
  static Future<void> confirmPayment(String paymentId) async {
    final row = await _db
        .from('payments')
        .select('invoice_id, student_id, amount, notes')
        .eq('id', paymentId)
        .single();
    final invoiceId = row['invoice_id'] as String?;

    if (invoiceId != null) {
      // Ancien modèle (facture ponctuelle : « autres frais ») — inchangé, la
      // facture existait déjà, on recalcule juste son cumul.
      await _db.from('payments').update({'status': 'confirmed'}).eq('id', paymentId).friendly();
      final inv = await _db
          .from('invoices')
          .select('amount, payments(amount,status)')
          .eq('id', invoiceId)
          .single();
      final due = (inv['amount'] as num?)?.toDouble() ?? 0;
      final paid = SbInvoice._sumPayments(inv['payments']);
      await _db.from('invoices').update({
        'status': paid >= due - 0.01 ? 'paid' : 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', invoiceId).friendly();
      return;
    }

    // Nouveau modèle (scolarité/inscription payée en ligne) : PAS de facture
    // tant que ce moment précis — la validation admin EST le déclencheur de
    // sa création, exactement comme un encaissement cash. Le contexte
    // (catégorie, année scolaire, école) a été écrit par l'Edge Function
    // `record-online-payment` dans `notes` (JSON), faute de colonnes dédiées.
    final studentId = row['student_id'] as String?;
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final notesRaw = row['notes'] as String?;
    Map<String, dynamic>? meta;
    if (notesRaw != null && notesRaw.startsWith('{')) {
      try {
        meta = jsonDecode(notesRaw) as Map<String, dynamic>;
      } catch (_) {
        meta = null;
      }
    }
    final category = meta?['category'] as String? ?? 'tuition';
    final academicYear = meta?['academicYear'] as String?;
    final schoolId = meta?['schoolId'] as String?;
    if (studentId == null || academicYear == null || schoolId == null) {
      throw Exception(
          'Versement en ligne incomplet (contexte manquant) : impossible de générer le reçu.');
    }

    late final String newInvoiceId;
    if (category == 'registration') {
      final returning = await isReturningStudent(
        studentId: studentId,
        schoolId: schoolId,
        academicYear: academicYear,
      );
      final school = await getSchool(schoolId);
      newInvoiceId = await _createTuitionInvoiceOnly(
        schoolId: schoolId,
        studentId: studentId,
        academicYear: academicYear,
        description:
            returning ? 'Réinscription $academicYear' : 'Inscription $academicYear',
        amount: amount,
        currency: school?.currency ?? 'XAF',
        periodTag: 'INSCRIPTION',
      );
    } else {
      final fee = await _activeFeeFor(
          studentId: studentId, schoolId: schoolId, academicYear: academicYear);
      if (fee == null) {
        throw Exception(
            'Aucune grille de frais pour la classe de cet élève : impossible de générer le reçu.');
      }
      final split = await _tuitionPaymentsThisYear(
        studentId: studentId,
        schoolId: schoolId,
        academicYear: academicYear,
      );
      final plan = await _tuitionReceiptPlan(
        fee: fee,
        alreadyPaidThisYear: split.monthly,
        amount: amount,
      );
      newInvoiceId = await _createTuitionInvoiceOnly(
        schoolId: schoolId,
        studentId: studentId,
        academicYear: academicYear,
        description: plan.description,
        amount: amount,
        currency: fee.currency,
        periodTag: plan.periodTag,
      );
    }

    await _db.from('payments').update({
      'invoice_id': newInvoiceId,
      'status': 'confirmed',
    }).eq('id', paymentId).friendly();
  }

  /// Référence introuvable/invalide sur le relevé marchand : le versement ne
  /// comptera jamais, mais reste tracé (pas de suppression silencieuse).
  static Future<void> rejectPayment(String paymentId) async {
    await _db.from('payments').update({'status': 'rejected'}).eq('id', paymentId).friendly();
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
    }, onConflict: 'class_id,academic_year').friendly();
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

  /// Le COMPTE de scolarité d'un élève (modèle « solde qui court »), calculé à
  /// partir de la grille de sa classe + des REÇUS déjà émis pour l'année en
  /// cours. `null` si l'élève n'a pas de classe ou si sa classe n'a pas de
  /// grille de frais.
  ///
  /// « Payé » = somme des reçus de scolarité de CETTE année scolaire
  /// uniquement (cf. [_tuitionPaymentsThisYear]) — un élève qui a fini de
  /// payer l'an dernier ne doit pas paraître « à jour » cette année sans avoir
  /// rien versé.
  static Future<SbTuitionAccount?> getTuitionAccount({
    required String studentId,
    required String schoolId,
    required String academicYear,
  }) async {
    final student = await getStudentById(studentId);
    final classId = student?.classId;
    if (classId == null || classId.isEmpty) return null;

    final fees = await getFeeStructures(schoolId, academicYear);
    SbFeeStructure? fee;
    for (final f in fees) {
      if (f.classId == classId && f.isActive) {
        fee = f;
        break;
      }
    }
    if (fee == null) return null;

    final split = await _tuitionPaymentsThisYear(
      studentId: studentId,
      schoolId: schoolId,
      academicYear: academicYear,
    );

    double? registrationDue;
    final school = await getSchool(schoolId);
    final regFee = school?.registrationFees[classId];
    if (regFee != null) {
      final returning = await isReturningStudent(
        studentId: studentId,
        schoolId: schoolId,
        academicYear: academicYear,
      );
      registrationDue = returning ? regFee.forReturning : regFee.forNew;
    }

    return tuitionAccountFrom(
      fee,
      split.monthly,
      registrationDue: registrationDue,
      registrationPaid: split.registration,
    );
  }

  /// Calcul PUR du compte à partir de la grille + du cumul versé (aucune
  /// requête). Sert au compte d'un élève ET au calcul en lot d'une liste.
  static SbTuitionAccount tuitionAccountFrom(
    SbFeeStructure fee,
    double paid, {
    double? registrationDue,
    double registrationPaid = 0,
  }) {
    final periods = tuitionPeriods(fee);
    final today = DateTime.now();
    final elapsed = periods.where((p) => !p.due.isAfter(today)).length;
    return SbTuitionAccount(
      monthly: fee.amountPerPeriod,
      periodsCount: fee.periodsCount,
      periodsElapsed: elapsed,
      paid: paid,
      currency: fee.currency,
      registrationDue: registrationDue,
      registrationPaid: registrationPaid,
      periods: [
        for (final p in periods)
          SbTuitionPeriod(code: p.period, label: p.label, due: p.due),
      ],
    );
  }

  /// Un élève est « réinscrit » s'il a au moins un reçu de scolarité d'une
  /// année scolaire ANTÉRIEURE dans cette école — sinon c'est un nouvel
  /// élève. Purement déduit de l'historique, aucune saisie manuelle.
  static Future<bool> isReturningStudent({
    required String studentId,
    required String schoolId,
    required String academicYear,
  }) async {
    final startYear =
        int.tryParse(academicYear.split('-').first) ?? DateTime.now().year;
    final rows = await _db
        .from('invoices')
        .select('period')
        .eq('student_id', studentId)
        .eq('school_id', schoolId)
        .eq('category', 'tuition');
    for (final r in (rows as List)) {
      final period = (r as Map)['period'] as String?;
      if (period == null) continue;
      final yearToken = period.split(':').first.split('-').first;
      final y = int.tryParse(yearToken);
      if (y != null && y < startYear) return true;
    }
    return false;
  }

  /// Somme des reçus de scolarité CONFIRMÉS pour l'année scolaire donnée,
  /// séparant inscription et mensualités (deux comptes distincts, cf.
  /// [SbTuitionAccount]). Reconnaît les deux formats de `period` : l'ancien
  /// (une facture annuelle unique, `period == academicYear`) et le nouveau
  /// (un reçu par versement, `period == '$academicYear:<mois|INSCRIPTION|avance>'`).
  static Future<({double monthly, double registration})>
      _tuitionPaymentsThisYear({
    required String studentId,
    required String schoolId,
    required String academicYear,
  }) async {
    final rows = await _db
        .from('invoices')
        .select('period, payments(amount,status)')
        .eq('student_id', studentId)
        .eq('school_id', schoolId)
        .eq('category', 'tuition');
    double monthly = 0;
    double registration = 0;
    for (final r in (rows as List)) {
      final map = r as Map<String, dynamic>;
      final period = map['period'] as String?;
      if (period == null) continue;
      final isOldWholeYear = period == academicYear;
      final isNewThisYear = period.startsWith('$academicYear:');
      if (!isOldWholeYear && !isNewThisYear) continue;
      final amount = SbInvoice._sumPayments(map['payments']);
      if (isNewThisYear && period.split(':').last == 'INSCRIPTION') {
        registration += amount;
      } else {
        monthly += amount;
      }
    }
    return (monthly: monthly, registration: registration);
  }

  /// Crée UNIQUEMENT la facture d'un reçu (montant exact, statut `paid`) —
  /// sans versement associé. Utilisé par [_createTuitionReceipt] (cash, crée
  /// aussi le versement dans la foulée) ET par [confirmPayment] (en ligne, le
  /// versement existe déjà en `pending` — on le rattache après coup à cette
  /// facture plutôt que d'en créer un second).
  static Future<String> _createTuitionInvoiceOnly({
    required String schoolId,
    required String studentId,
    required String academicYear,
    required String description,
    required double amount,
    required String currency,
    required String periodTag,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await _db.from('invoices').insert({
      'id': id,
      'school_id': schoolId,
      'student_id': studentId,
      'invoice_number':
          'SCO-${now.year}${now.month.toString().padLeft(2, '0')}-${id.substring(0, 6).toUpperCase()}',
      'description': description,
      'amount': amount,
      'currency': currency,
      'category': 'tuition',
      'period': '$academicYear:$periodTag',
      'issued_date': now.toIso8601String().split('T').first,
      // Un reçu correspond TOUJOURS à de l'argent déjà reçu — jamais 'pending'.
      'status': 'paid',
    }).friendly();
    return id;
  }

  /// Crée le reçu d'UN encaissement CASH (montant exact reçu, jamais un solde
  /// qui court) : la facture + son versement, dans la foulée. `periodTag`
  /// identifie ce que couvre le reçu : un mois (`2026-01`), `INSCRIPTION`, ou
  /// `avance` si le versement ne complète aucun mois entier.
  static Future<void> _createTuitionReceipt({
    required String schoolId,
    required String studentId,
    required String academicYear,
    required String description,
    required double amount,
    required String currency,
    required String periodTag,
    String method = 'cash',
    String? reference,
  }) async {
    final invoiceId = await _createTuitionInvoiceOnly(
      schoolId: schoolId,
      studentId: studentId,
      academicYear: academicYear,
      description: description,
      amount: amount,
      currency: currency,
      periodTag: periodTag,
    );
    await _db.from('payments').insert({
      'id': const Uuid().v4(),
      'invoice_id': invoiceId,
      'student_id': studentId,
      'amount': amount,
      'payment_date': DateTime.now().toIso8601String().split('T').first,
      'payment_method': method,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    }).friendly();
  }

  /// Détermine ce qu'un versement de scolarité mensuelle couvre : des MOIS
  /// PLEINS en priorité (le plus ancien dû d'abord) ; le reliquat qui ne
  /// complète pas un mois entier reste un solde payé d'avance visible sur le
  /// compte ([SbTuitionAccount.credit]), jamais réparti au prorata dans le
  /// reçu. Partagé entre l'encaissement cash et la confirmation d'un
  /// versement en ligne — même règle des deux côtés.
  static Future<({String description, String periodTag})> _tuitionReceiptPlan({
    required SbFeeStructure fee,
    required double alreadyPaidThisYear,
    required double amount,
  }) async {
    final periods = tuitionPeriods(fee);
    final monthsAlreadyCovered =
        (alreadyPaidThisYear / fee.amountPerPeriod).floor();
    final monthsCoveredByThis = (amount / fee.amountPerPeriod).floor();

    final coveredLabels = <String>[];
    for (var i = 0; i < monthsCoveredByThis; i++) {
      final idx = monthsAlreadyCovered + i;
      if (idx < periods.length) {
        coveredLabels.add(periods[idx].label.replaceFirst('Scolarité — ', ''));
      }
    }
    final description = coveredLabels.isEmpty
        ? 'Scolarité — avance sur mois futur'
        : 'Scolarité — ${coveredLabels.join(", ")}';
    final periodTag =
        monthsCoveredByThis > 0 && monthsAlreadyCovered < periods.length
            ? periods[monthsAlreadyCovered].period
            : 'avance';
    return (description: description, periodTag: periodTag);
  }

  /// La grille de frais active de la classe d'un élève pour une année, ou
  /// `null` si absente. Lève si l'élève lui-même n'a pas de classe.
  static Future<SbFeeStructure?> _activeFeeFor({
    required String studentId,
    required String schoolId,
    required String academicYear,
  }) async {
    final student = await getStudentById(studentId);
    final classId = student?.classId;
    if (classId == null || classId.isEmpty) {
      throw Exception('Élève sans classe.');
    }
    final fees = await getFeeStructures(schoolId, academicYear);
    for (final f in fees) {
      if (f.classId == classId && f.isActive) return f;
    }
    return null;
  }

  /// Enregistre un encaissement de SCOLARITÉ MENSUELLE : génère son propre
  /// reçu pour le montant exact reçu (pas un pot commun mutable).
  ///
  /// Lève une exception si la classe de l'élève n'a pas de grille de frais.
  static Future<void> recordTuitionPayment({
    required String studentId,
    required String schoolId,
    required String academicYear,
    required double amount,
    String method = 'cash',
    String? reference,
  }) async {
    final SbFeeStructure? fee;
    try {
      fee = await _activeFeeFor(
          studentId: studentId, schoolId: schoolId, academicYear: academicYear);
    } catch (_) {
      throw Exception('Élève sans classe : impossible d\'encaisser la scolarité.');
    }
    if (fee == null) {
      throw Exception(
          'Aucune grille de frais pour la classe de cet élève : impossible d\'encaisser la scolarité.');
    }
    if (fee.amountPerPeriod <= 0) {
      throw Exception('Mensualité invalide dans la grille de frais.');
    }

    final split = await _tuitionPaymentsThisYear(
      studentId: studentId,
      schoolId: schoolId,
      academicYear: academicYear,
    );
    final plan = await _tuitionReceiptPlan(
      fee: fee,
      alreadyPaidThisYear: split.monthly,
      amount: amount,
    );

    await _createTuitionReceipt(
      schoolId: schoolId,
      studentId: studentId,
      academicYear: academicYear,
      description: plan.description,
      amount: amount,
      currency: fee.currency,
      periodTag: plan.periodTag,
      method: method,
      reference: reference,
    );
  }

  /// Enregistre un encaissement d'INSCRIPTION/RÉINSCRIPTION — toujours un
  /// versement SÉPARÉ de la scolarité mensuelle (jamais mélangé dans le même
  /// reçu), même mécanique de reçu individuel. Le montant nouveau/réinscrit
  /// est déterminé par [isReturningStudent], pas saisi à la main.
  static Future<void> recordRegistrationPayment({
    required String studentId,
    required String schoolId,
    required String academicYear,
    required double amount,
    String method = 'cash',
    String? reference,
  }) async {
    final student = await getStudentById(studentId);
    final classId = student?.classId;
    if (classId == null || classId.isEmpty) {
      throw Exception(
          'Élève sans classe : impossible d\'encaisser l\'inscription.');
    }
    final school = await getSchool(schoolId);
    final currency = school?.currency ?? 'XAF';
    final returning = await isReturningStudent(
      studentId: studentId,
      schoolId: schoolId,
      academicYear: academicYear,
    );
    await _createTuitionReceipt(
      schoolId: schoolId,
      studentId: studentId,
      academicYear: academicYear,
      description: returning ? 'Réinscription $academicYear' : 'Inscription $academicYear',
      amount: amount,
      currency: currency,
      periodTag: 'INSCRIPTION',
      method: method,
      reference: reference,
    );
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
        await _db.from('invoices').insert(rows).friendly();
        inserted += rows.length;
      }
    }
    return inserted;
  }

  // ── Bulletins officiels (report_cards) ──────────────────────────────────────

  // La mention et l'appréciation viennent de bulletin_math.dart (mentionOf) —
  // les copies locales, restes de l'ancien calcul, ont été retirées.

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

    // La décision de passage n'a de sens qu'à la DERNIÈRE période de l'année
    // du cycle de CETTE classe (un mois de primaire ≠ un trimestre de lycée).
    final classRow = await _db
        .from('classes')
        .select('level')
        .eq('id', classId)
        .maybeSingle();
    final cycle = SchoolLevel.fromClassName(classRow?['level'] as String?)?.name;
    final isFinalPeriod =
        school?.formatForCycle(cycle).isFinalPeriod(period) ?? true;

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
      isFinalPeriod: isFinalPeriod,
    );

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
        // `generated_at` est pose cote serveur (trigger stamp_report_card_...),
        // pour partager l'horloge de grades.updated_at — cf. 20260749.
        if (createdBy != null) 'created_by': createdBy,
      });
    }

    if (rows.isEmpty) {
      throw const ReportCardEmpty(
          'Aucun élève de cette classe n’a de note pour cette période.');
    }

    await _db
        .from('report_cards')
        .upsert(rows, onConflict: 'student_id,academic_year,period').friendly();
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
        .select('id').friendly();
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

  /// Annonces de la plateforme (Scolaris → écoles) concernant l'école
  /// courante — maintenance, nouveautés, rappels d'essai/impayé. Filtrage
  /// par audience fait côté base (`my_platform_announcements()`), jamais côté
  /// client : on ne reçoit que ce qui nous concerne.
  static Future<List<SbPlatformAnnouncement>> getMyPlatformAnnouncements() async {
    final data = await _db.rpc('my_platform_announcements');
    return (data as List).map((j) {
      final row = j as Map<String, dynamic>;
      return SbPlatformAnnouncement(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        body: row['body'] as String? ?? '',
        kind: row['kind'] as String? ?? 'info',
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  // ── Users ─────────────────────────────────────────────────────────────────
  static Future<List<SbUser>> getUsers({String? schoolId}) async {
    // L'embed `student_profiles` revient vide pour le personnel/parents (pas
    // de fiche élève) — sans effet pour eux, juste utilisé pour les élèves.
    var q = _db
        .from('users')
        .select('*, student_profiles(enrollment_status, exit_reason, exit_date)');
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('full_name');
    return (data as List).map((j) => SbUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Ids `users.id` des super-admins plateforme membres de cette école — sert
  /// à les exclure des listes de personnel (ils n'y sont que pour que la RLS
  /// `is_member_of` les laisse lire leur propre profil, cf.
  /// 20260803_fix_admin_school_members.sql, pas de vrais membres du staff).
  static Future<Set<String>> getPlatformAdminUserIds(String schoolId) async {
    final data = await _db
        .from('users')
        .select('id, platform_admins!inner(user_id)')
        .eq('school_id', schoolId);
    return (data as List).map((j) => j['id'] as String).toSet();
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
        .eq('id', schoolId).friendly();
  }

  /// Enregistre les numéros marchands Mobile Money de l'école — lecture-fusion
  /// -écriture pour ne pas écraser le reste de `metadata` (types, modules…).
  static Future<void> updateSchoolMobileMoneyNumbers({
    required String schoolId,
    String? mtn,
    String? airtel,
  }) async {
    final row = await _db
        .from('schools')
        .select('metadata')
        .eq('id', schoolId)
        .maybeSingle();
    final current = row?['metadata'];
    final metadata = <String, dynamic>{
      if (current is Map<String, dynamic>) ...current,
      'mobile_money': {
        'mtn': mtn?.trim().isEmpty == true ? null : mtn?.trim(),
        'airtel': airtel?.trim().isEmpty == true ? null : airtel?.trim(),
      },
    };
    await _db.from('schools').update({'metadata': metadata}).eq('id', schoolId).friendly();
  }

  /// Active/désactive le paiement en ligne pour TOUTE l'école (scolarité,
  /// inscription, cantine…) — un seul interrupteur, pas un réglage par type
  /// de frais. Se cumule avec le plan d'abonnement (les deux doivent
  /// autoriser pour que le bouton « Payer en ligne » apparaisse).
  static Future<void> updateOnlinePaymentEnabled({
    required String schoolId,
    required bool enabled,
  }) async {
    final row = await _db
        .from('schools')
        .select('metadata')
        .eq('id', schoolId)
        .maybeSingle();
    final current = row?['metadata'];
    final metadata = <String, dynamic>{
      if (current is Map<String, dynamic>) ...current,
      'online_payment_enabled': enabled,
    };
    await _db.from('schools').update({'metadata': metadata}).eq('id', schoolId).friendly();
  }

  /// Fixe les frais d'inscription/réinscription d'UNE classe (lecture-fusion
  /// -écriture, ne touche pas les autres classes ni le reste de `metadata`).
  /// `forNew`/`forReturning` à `null` = pas de frais d'inscription pour cette
  /// classe (le compte de scolarité n'affichera aucune ligne inscription).
  static Future<void> updateRegistrationFee({
    required String schoolId,
    required String classId,
    double? forNew,
    double? forReturning,
  }) async {
    final row = await _db
        .from('schools')
        .select('metadata')
        .eq('id', schoolId)
        .maybeSingle();
    final current = row?['metadata'];
    final existingFees = current is Map<String, dynamic> &&
            current['registration_fees'] is Map
        ? Map<String, dynamic>.from(current['registration_fees'] as Map)
        : <String, dynamic>{};
    existingFees[classId] = {'new': forNew, 'returning': forReturning};
    final metadata = <String, dynamic>{
      if (current is Map<String, dynamic>) ...current,
      'registration_fees': existingFees,
    };
    await _db.from('schools').update({'metadata': metadata}).eq('id', schoolId).friendly();
  }

  static Future<SbSchool?> getFirstSchool() async {
    final data = await _db.from('schools').select().limit(1).maybeSingle();
    return data != null ? SbSchool.fromJson(data) : null;
  }

  // ── Numéros de dépôt Mobile Money (Scolaris → écoles, versements d'abonnement) ──
  /// Configurés par le super-admin plateforme (`platform_payment_settings`),
  /// lus par TOUTES les écoles (lecture ouverte en RLS) — avant, ces numéros
  /// étaient codés en dur dans `admin_subscription_page.dart` (placeholders
  /// jamais remplacés, pas de nom de titulaire).
  static Future<List<SbPlatformPaymentSetting>> getPlatformPaymentSettings() async {
    final data = await _db.from('platform_payment_settings').select().order('provider');
    return (data as List)
        .map((j) => SbPlatformPaymentSetting.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updatePlatformPaymentSetting({
    required String provider, // 'mtn' | 'airtel'
    required String phoneNumber,
    required String holderName,
  }) async {
    await _db.from('platform_payment_settings').update({
      'phone_number': phoneNumber,
      'holder_name': holderName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('provider', provider).friendly();
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

  static Future<List<SbPlanSizeSurcharge>> getPlanSizeSurcharges({String country = 'CG'}) async {
    final data = await _db.from('plan_size_surcharges').select().eq('country', country).eq('is_active', true);
    return (data as List).map((j) => SbPlanSizeSurcharge.fromJson(j as Map<String, dynamic>)).toList();
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
    }).eq('school_id', schoolId).friendly();
  }

  /// Enregistre un versement d'abonnement (école → Scolaris) et renvoie la ligne
  /// créée — la source du reçu imprimable. `amount` = encaissé, `creditApplied`
  /// = crédit déduit. La référence est générée si non fournie (démo).
  static Future<SbSubscriptionPayment> recordSubscriptionPayment({
    required String subscriptionId,
    required String schoolId,
    required String planCode,
    required String period, // 'monthly' | 'annual'
    required double amount,
    required String currency,
    double creditApplied = 0,
    String method = 'mobile_money',
    String? provider,
    String? reference,
    /// L'offre quittée si CE versement correspond à un changement d'offre
    /// (`null` = simple renouvellement de la même offre) — permet au reçu
    /// d'afficher « Changement d'offre : Free → Pro ».
    String? previousPlanCode,
  }) async {
    final now = DateTime.now();
    final ref = (reference != null && reference.trim().isNotEmpty)
        ? reference.trim()
        : 'SCO-${now.year}${now.month.toString().padLeft(2, '0')}'
            '-${subscriptionId.substring(0, 4).toUpperCase()}'
            '${now.millisecondsSinceEpoch.toString().substring(7)}';
    final data = await _db
        .from('subscription_payments')
        .insert({
          'subscription_id': subscriptionId,
          'school_id': schoolId,
          'plan_code': planCode,
          'period': period,
          'amount': amount,
          'credit_applied': creditApplied,
          'currency': currency,
          'method': method,
          'provider': provider,
          'reference': ref,
          'status': 'success',
          'paid_at': now.toIso8601String(),
          if (previousPlanCode != null && previousPlanCode != planCode)
            'previous_plan_code': previousPlanCode,
        })
        .select()
        .single().friendly();
    return SbSubscriptionPayment.fromJson(data);
  }

  /// Pas d'agrégateur branché : l'école envoie elle-même l'argent (USSD) vers
  /// le numéro marchand Mobile Money de Scolaris, puis saisit la référence
  /// reçue par SMS. Insère en `pending` — n'active RIEN sur `subscriptions`.
  /// L'activation n'a lieu qu'à la vérification manuelle du versement (pour
  /// l'instant : côté Supabase, en attendant une file dédiée côté plateforme).
  static Future<void> submitSubscriptionPayment({
    required String subscriptionId,
    required String schoolId,
    required String planCode,
    required String period, // 'monthly' | 'annual'
    required double amount, // prix plein (pas de report de crédit tant que non confirmé)
    required String currency,
    required String reference,
    String? provider, // 'mtn' | 'airtel'
    /// L'offre quittée si ce versement correspond à un changement d'offre
    /// (`null` = renouvellement de la même offre) — affiché sur le reçu une
    /// fois le versement confirmé.
    String? previousPlanCode,
    /// 'plan_change' (défaut) ou 'addon_slot' — un achat d'emplacement
    /// utilise `planCode: 'addon_slot'` (pseudo-offre cachée) et NE
    /// remplace PAS le plan_code de l'école à la confirmation (branché dans
    /// `platform_confirm_subscription_payment`, cf.
    /// 20260809_module_slot_addon.sql).
    String paymentType = 'plan_change',
    int quantity = 1,
  }) async {
    await _db.from('subscription_payments').insert({
      'subscription_id': subscriptionId,
      'school_id': schoolId,
      'plan_code': planCode,
      'period': period,
      'amount': amount,
      'currency': currency,
      'method': 'mobile_money',
      'provider': provider,
      'reference': reference,
      'status': 'pending',
      'payment_type': paymentType,
      'quantity': quantity,
      if (previousPlanCode != null && previousPlanCode != planCode)
        'previous_plan_code': previousPlanCode,
    }).friendly();
  }

  /// Historique des versements d'abonnement de l'école (récent → ancien).
  static Future<List<SbSubscriptionPayment>> getSubscriptionPayments(
      String schoolId) async {
    final data = await _db
        .from('subscription_payments')
        .select()
        .eq('school_id', schoolId)
        .order('paid_at', ascending: false);
    return (data as List)
        .map((j) => SbSubscriptionPayment.fromJson(j as Map<String, dynamic>))
        .toList();
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
    String? birthPlace,
    String? gender,
    String? nationality,
    String? avatarUrl,
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
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl.trim(),
      'role': 'student',
      'status': 'active',
    }).friendly();
    await _db.from('student_profiles').insert({
      'user_id': id,
      'school_id': schoolId,
      if (classId != null) 'class_id': classId,
      'matricule': mat,
      if (birthDate != null && birthDate.isNotEmpty) 'date_of_birth': birthDate,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (nationality != null && nationality.isNotEmpty) 'nationality': nationality,
      // Pas de colonne dédiée (cf. `student_profiles`) : le lieu de naissance
      // rejoint `metadata`, comme groupe sanguin/allergies/vulnérabilité.
      if (birthPlace != null && birthPlace.trim().isNotEmpty)
        'metadata': {'birth_place': birthPlace.trim()},
      'academic_year': academicYear,
    }).friendly();
    // Sans cette ligne, is_member_of() (donc toute la RLS) ne voit jamais cet
    // élève dès qu'il obtient un login — cf. 20260750_fix_new_account_school_members.sql.
    await _db.from('school_members').insert({
      'user_id': id,
      'school_id': schoolId,
      'role': 'student',
      'status': 'active',
    }).friendly();
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
      }).friendly();
      await _db.from('school_members').insert({
        'user_id': id,
        'school_id': schoolId,
        'role': 'parent',
        'status': 'active',
      }).friendly();
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
      }).friendly();
    }
    return parentId;
  }

  // ── Pré-inscription publique (`enrollment_requests`) ────────────────────────
  // cf. supabase/migrations/20260714_public_enrollment.sql — insert public
  // anonyme (gardé par `preregistration_open`), lecture/traitement réservés à
  // l'école via RLS (`is_member_of`).

  /// École publique par slug (annuaire du site) — utilisée par le formulaire
  /// de pré-inscription, AVANT toute authentification (vue `public_schools`,
  /// qui ne filtre que les écoles actives + publiques).
  static Future<Map<String, dynamic>?> getPublicSchoolBySlug(String slug) =>
      _db.from('public_schools').select().eq('slug', slug).maybeSingle();

  /// Dépose une demande de pré-inscription. [apiKey] = `schools.enrollment_api_key`
  /// (vient de `getPublicSchoolBySlug`/`public_schools`, la même clé qu'un site
  /// tiers utiliserait). Refusée côté serveur (trigger `enrollment_requests_guard`,
  /// cf. 20260753_enrollment_api.sql) si l'école n'a pas ouvert sa période, si
  /// la clé ne correspond pas, ou si un champ obligatoire manque — pas
  /// seulement côté RLS, pour renvoyer un message exploitable par l'appelant.
  /// Renvoie la référence de suivi (ex. `SCO-4F2K9A`) à remettre à la famille.
  static Future<String> submitEnrollmentRequest({
    required String schoolId,
    required String apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final row = await _db
        .from('enrollment_requests')
        .insert({'school_id': schoolId, 'api_key': apiKey, 'payload': payload})
        .select('reference')
        .single().friendly();
    return row['reference'] as String;
  }

  /// Régénère la clé API de pré-inscription de l'école — invalide l'ancienne
  /// immédiatement (tout appelant, app ou site tiers, qui l'utilisait encore
  /// se fera refuser par `enrollment_requests_guard`). Générée côté client
  /// avec le même schéma que le défaut posé en base (`sch_live_<64 hex>`).
  static Future<String> regenerateEnrollmentApiKey(String schoolId) async {
    const uuid = Uuid();
    final key = 'sch_live_'
        '${uuid.v4().replaceAll('-', '')}${uuid.v4().replaceAll('-', '')}';
    await _db
        .from('schools')
        .update({'enrollment_api_key': key})
        .eq('id', schoolId).friendly();
    return key;
  }

  /// Suivi d'une demande par une famille sans compte, via sa référence exacte
  /// (fonction `security definer`, ne liste jamais les autres demandes).
  static Future<Map<String, dynamic>?> trackEnrollmentRequest(
      String reference) async {
    final res = await _db
        .rpc('track_enrollment_request', params: {'p_reference': reference});
    final list = res as List;
    return list.isEmpty ? null : (list.first as Map<String, dynamic>);
  }

  static Future<List<SbEnrollmentRequest>> getEnrollmentRequests(
      String schoolId) async {
    final data = await _db
        .from('enrollment_requests')
        .select()
        .eq('school_id', schoolId)
        .order('submitted_at', ascending: false);
    return (data as List)
        .map((j) => SbEnrollmentRequest.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> rejectEnrollmentRequest({
    required String id,
    String? note,
  }) async {
    await _db.from('enrollment_requests').update({
      'status': 'rejected',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', id).friendly();
  }

  /// Accepte une demande : crée la fiche élève (+ tuteur si renseigné) à
  /// partir du `payload` soumis, affecte la demande à la fiche créée. Les
  /// clés du payload suivent [EnrollmentFields] (`first_name`, `guardian_name`…).
  static Future<void> acceptEnrollmentRequest({
    required SbEnrollmentRequest request,
    required String schoolId,
    String? classId,
  }) async {
    final p = request.payload;
    String str(String key) => (p[key] as String?)?.trim() ?? '';

    final studentId = await createStudent(
      schoolId: schoolId,
      fullName: '${str('first_name')} ${str('last_name')}'.trim(),
      email: str('email').isEmpty ? null : str('email'),
      phone: str('phone').isEmpty ? null : str('phone'),
      classId: classId,
      birthDate: _ddmmyyyyToIso(str('birth_date')),
      gender: str('gender').isEmpty ? null : str('gender'),
      nationality: str('nationality').isEmpty ? null : str('nationality'),
    );

    if (str('guardian_name').isNotEmpty) {
      await createOrLinkGuardian(
        schoolId: schoolId,
        studentId: studentId,
        guardianName: str('guardian_name'),
        phone: str('guardian_phone').isEmpty ? null : str('guardian_phone'),
        email: str('guardian_email').isEmpty ? null : str('guardian_email'),
        relationship: str('guardian_relation').isEmpty
            ? 'Parent'
            : str('guardian_relation'),
      );
    }

    await _db.from('enrollment_requests').update({
      'status': 'accepted',
      'student_id': studentId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', request.id).friendly();
  }

  /// Le formulaire pose les dates en `JJ/MM/AAAA` ; `createStudent` attend de
  /// l'ISO (`AAAA-MM-JJ`). Renvoie `null` si vide/mal formée (mieux qu'une
  /// fiche avec une date fausse).
  static String? _ddmmyyyyToIso(String v) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(v.trim());
    if (m == null) return null;
    final d = m.group(1)!.padLeft(2, '0');
    final mo = m.group(2)!.padLeft(2, '0');
    return '${m.group(3)}-$mo-$d';
  }

  /// Dépose un fichier (photo, acte de naissance, diplôme…) du formulaire de
  /// pré/inscription dans le bucket privé `enrollment-documents`. Le chemin
  /// commence par `schoolId/` : c'est ce préfixe que la policy de dépôt
  /// vérifie contre `schools.preregistration_open` (cf.
  /// 20260751_enrollment_documents_storage.sql) — comme pour
  /// `enrollment_requests`, aucune authentification n'est requise pour
  /// écrire, mais seule une école qui a ouvert sa période peut recevoir des
  /// fichiers. [sessionId] regroupe les fichiers d'un même formulaire avant
  /// que la demande n'existe encore en base.
  static Future<String> uploadEnrollmentDocument({
    required String schoolId,
    required String sessionId,
    required String fieldId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$schoolId/$sessionId/$fieldId-$safeName';
    await _db.storage.from('enrollment-documents').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  /// URL signée temporaire (1 h) pour afficher/télécharger un document déposé
  /// à l'inscription. Le bucket est privé : jamais d'URL publique permanente.
  static Future<String> getEnrollmentDocumentUrl(String path) =>
      _db.storage.from('enrollment-documents').createSignedUrl(path, 3600);

  /// Dépose la photo de profil choisie à l'étape 2 (Administrateur) de
  /// l'inscription d'une école, dans le bucket public `avatars`, préfixe
  /// `pending/` (seul autorisé sans authentification — cf.
  /// 20260810_registration_avatar_storage.sql, ni l'école ni le compte auth
  /// n'existent encore à ce stade). [uploadId] est un UUID généré côté
  /// client au chargement de l'étape, PAS le futur school_id.
  /// Retourne l'URL publique, à transmettre telle quelle dans les métadonnées
  /// `avatar_url` de `auth.signUp` (lue par `handle_new_user`).
  static Future<String> uploadRegistrationAvatar({
    required String uploadId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'pending/$uploadId-$safeName';
    await _db.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _db.storage.from('avatars').getPublicUrl(path);
  }

  /// Dépose la photo d'identité d'un élève (champ « Photo » du formulaire
  /// d'inscription, cf. EnrollmentFields), dans le bucket public `avatars`,
  /// préfixe `{schoolId}/` — cf. 20260811_avatars_student_photo.sql.
  /// Contrairement à `uploadEnrollmentDocument` (bucket privé, URL signée à
  /// chaque affichage), l'URL retournée est publique et permanente : c'est
  /// elle qui devient `users.avatar_url`, affichée dans les listes et fiches.
  static Future<String> uploadStudentPhoto({
    required String schoolId,
    required String sessionId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$schoolId/$sessionId-$safeName';
    await _db.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _db.storage.from('avatars').getPublicUrl(path);
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
    }).eq('auth_uid', authUid).friendly();

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
    }).eq('id', id).friendly();
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
    }, onConflict: 'user_id').friendly();
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
    }).eq('id', id).friendly();
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
    await _db.from('users').update(patch).eq('id', id).friendly();
  }

  /// Active / désactive un compte (status active ↔ suspended).
  static Future<void> setUserActive(String id, bool active) async {
    await _db.from('users').update({
      'status': active ? 'active' : 'suspended',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).friendly();
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

  static Future<String> createClass({
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
    final id = const Uuid().v4();
    await _db.from('classes').insert({
      'id': id,
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
    }).friendly();
    return id;
  }

  /// Les classes saisies dans l'ASSISTANT d'inscription. Elles vivent dans
  /// `school_classes` (tables permissives, écrites par le client anonyme avant
  /// connexion) — que le tableau de bord ne lit jamais. On les expose ici pour
  /// pouvoir les reporter dans la vraie table `classes`. Cf. importRegistrationClasses.
  static Future<List<Map<String, dynamic>>> getRegistrationClasses(
      String schoolId) async {
    final data = await _db
        .from('school_classes')
        .select('name, level')
        .eq('school_id', schoolId);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Nom de série (`school_classes.level`, ex. "Terminale", "Junior Secondary")
  /// → cycle du catalogue des niveaux (`class_levels.cycle`), utilisé comme
  /// repli si aucune fiche [SbClassLevel] ne correspond au nom de la classe
  /// (cf. [importRegistrationClasses]). Couvre les catalogues francophone,
  /// anglophone, LMD et filières techniques de [_defaultSeries] côté
  /// inscription (school_registration_screen.dart).
  static const _seriesToCycle = <String, String>{
    'Maternelle': 'prescolaire',
    'Primaire': 'primaire', 'Primary': 'primaire',
    'Collège': 'college', 'Junior Secondary': 'college',
    'Seconde': 'lycee', 'Première': 'lycee', 'Terminale': 'lycee',
    'Senior Secondary': 'lycee',
    'CAP': 'lycee', 'BEP': 'lycee', 'BTS': 'lycee',
    'Licence': 'universite_l', 'Master': 'universite_m', 'Doctorat': 'universite_d',
  };

  /// Filière déduite du dernier mot du nom de classe (ex. "Tle A" → "A"),
  /// pour cibler le bon sous-catalogue de matières (cf. subject_catalog.series)
  /// quand aucune fiche [SbClassLevel] exacte n'a été trouvée.
  static String? _seriesLetterOf(String className) {
    final last = className.trim().split(RegExp(r'\s+')).last;
    return RegExp(r'^[A-H]$').hasMatch(last) ? last : null;
  }

  /// Fait correspondre un nom de classe généré à l'inscription (ex. "2nde A",
  /// "1re C", "Tle D") à sa fiche exacte du catalogue (`class_levels.short_name`,
  /// ex. "2A", "1C", "TleD") — pour hériter de son `id` (`level_id`), son
  /// `order_num` (restrictions par niveau, ex. Anglais à partir du CM1) et sa
  /// filière. Retourne null si rien ne correspond (repli sur [_seriesToCycle]).
  static SbClassLevel? _matchRegistrationClassLevel(
      List<SbClassLevel> levels, String className) {
    final tokens = className.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;
    const prefixMap = {'2nde': '2', '1re': '1', '1ère': '1', 'Tle': 'Tle'};
    final prefix = prefixMap[tokens.first] ?? tokens.first;
    final suffix = tokens.length > 1 ? tokens.sublist(1).join() : '';
    final target = '$prefix$suffix'.toLowerCase();
    for (final l in levels) {
      if (l.shortName.toLowerCase() == target) return l;
    }
    return null;
  }

  /// Reporte les classes de l'inscription (`school_classes`) dans la vraie table
  /// `classes` — ce que l'assistant ne pouvait pas faire lui-même (RLS : il
  /// tournait sous le compte anonyme, avant connexion). Idempotent : on saute
  /// toute classe dont le nom existe déjà. [only] restreint l'import à ces
  /// noms de classe (sélection manuelle dans l'admin) ; null = tout importer.
  /// [system] est le `class_levels.system_type` de l'école (cf.
  /// `SbSchool.levelSystemType`), pour retrouver la bonne fiche de niveau.
  ///
  /// Génère aussi le programme par défaut (matières + cours) de chaque classe
  /// créée, comme la création manuelle — avec les mêmes restrictions par
  /// niveau (ex. Anglais à partir du CM1 seulement) quand la fiche exacte est
  /// trouvée. Une erreur de génération n'annule pas l'import, la classe reste
  /// créée sans programme. Renvoie le nombre de classes importées.
  static Future<int> importRegistrationClasses({
    required String schoolId,
    required String academicYear,
    Set<String>? only,
    String system = 'francophone_africa',
  }) async {
    final reg = await getRegistrationClasses(schoolId);
    if (reg.isEmpty) return 0;

    final existing = await _db
        .from('classes')
        .select('name')
        .eq('school_id', schoolId);
    final taken = <String>{
      for (final e in (existing as List))
        ((e['name'] as String?) ?? '').trim().toLowerCase(),
    };

    // Tout le catalogue de niveaux de l'école, pour matcher chaque classe
    // importée à sa fiche exacte (cf. _matchRegistrationClassLevel).
    final levels = await getClassLevels(system: system, cycles: const [
      'prescolaire', 'primaire', 'college', 'lycee',
      'universite_l', 'universite_m', 'universite_d', 'prepa',
    ]);

    final rows = <Map<String, dynamic>>[];
    final matched = <String, SbClassLevel>{}; // id de classe → fiche niveau
    final seen = <String>{};
    for (final r in reg) {
      final name = ((r['name'] as String?) ?? '').trim();
      if (name.isEmpty) continue;
      if (only != null && !only.contains(name)) continue;
      final key = name.toLowerCase();
      if (taken.contains(key) || !seen.add(key)) continue;
      final id = const Uuid().v4();
      final level = _matchRegistrationClassLevel(levels, name);
      if (level != null) matched[id] = level;
      rows.add({
        'id': id,
        'school_id': schoolId,
        'name': name,
        // Fiche trouvée : `level` suit la convention du reste de l'app
        // (le cycle, pas le libellé de série — cf. createClass) et
        // `level_id` pointe la fiche exacte, comme une classe créée à la
        // main. Sinon repli sur le libellé brut de l'inscription.
        'level': level?.cycle ?? r['level'],
        if (level != null) 'level_id': level.id,
        'max_students': 35,
        'academic_year': academicYear,
        'is_active': true,
      });
    }
    if (rows.isEmpty) return 0;
    await _db.from('classes').insert(rows).friendly();

    for (final row in rows) {
      final id = row['id'] as String;
      final level = matched[id];
      final cycle = level?.cycle ?? _seriesToCycle[row['level'] as String?];
      if (cycle == null) continue;
      final series = level?.series != null
          ? [level!.series!]
          : (() {
              final s = _seriesLetterOf(row['name'] as String);
              return s != null ? [s] : null;
            })();
      try {
        await generateDefaultProgramForClass(
          schoolId: schoolId,
          classId: id,
          cycle: cycle,
          series: series,
          levelOrderNum: level?.orderNum,
        );
      } catch (_) {
        // Le programme est un bonus : une erreur ici ne doit pas faire
        // échouer l'import des classes elles-mêmes.
      }
    }
    return rows.length;
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
    await _db.from('classes').update(patch).eq('id', id).friendly();
  }

  /// Définit (ou retire, si null) le professeur **titulaire** d'une classe.
  /// Le titulaire enseigne toute sa classe (modèle primaire) et voit son
  /// carnet/ses présences pour cette classe.
  ///
  /// Rattache aussi le titulaire comme enseignant des cours de la classe qui
  /// n'ont encore aucun prof (`course_teachers` vide) — au primaire les cours
  /// sont générés sans prof par [generateDefaultProgramForClass] et rien ne
  /// les couvrait ensuite. On ne touche pas aux cours qui ont déjà un ou
  /// plusieurs profs : le co-enseignement (ex. maîtresse d'anglais) reste
  /// intact, on ne fait que combler les trous.
  static Future<void> setClassMainTeacher(
      String classId, String? teacherId) async {
    await _db.from('classes').update({
      'main_teacher_id': (teacherId != null && teacherId.isNotEmpty)
          ? teacherId
          : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', classId).friendly();

    if (teacherId == null || teacherId.isEmpty) return;
    final courses = await getCoursesForClass(classId);
    for (final course in courses) {
      if (course.teachers.isNotEmpty) continue;
      await setCourseTeachers(
        courseId: course.id,
        schoolId: course.schoolId,
        teacherIds: [teacherId],
      );
    }
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
    }).friendly();
  }

  static Future<void> deleteSchedule(String id) async {
    await _db.from('schedules').delete().eq('id', id).friendly();
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
    }).eq('id', id).friendly();
  }

  static Future<void> deleteClass(String id) async {
    await _db.from('classes').delete().eq('id', id).friendly();
  }

  /// Supprime TOUTES les classes de l'école (bouton « Supprimer toutes les
  /// classes » de la page Classes). Les élèves affectés perdent juste leur
  /// affectation (`students.class_id` en base ne bloque pas la suppression),
  /// ils ne sont pas supprimés eux-mêmes.
  static Future<void> deleteAllClasses(String schoolId) async {
    await _db.from('classes').delete().eq('school_id', schoolId).friendly();
  }

  /// Supprime un compte, via l'Edge Function `delete-account` : supprime la
  /// fiche `public.users` (motif transporté jusqu'au trigger d'audit des
  /// notes — la suppression cascade sur `grades` ; une note en période
  /// validée exige un motif) **et** le compte de connexion `auth.users`
  /// associé, découplés dans ce schéma (cf. `users.auth_uid`). [reason]
  /// optionnel si l'élève n'a aucune note gelée.
  static Future<void> deleteUser(String id, {String? reason}) async {
    final res = await _db.functions.invoke('delete-account', body: {
      'userId': id,
      if (reason != null) 'reason': reason,
    });
    _throwIfFnError(res);
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
    ).friendly();
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
    }).eq('id', id).friendly();
  }

  /// Le modèle de bulletin choisi par l'école (`standard` ou `detailed`) —
  /// même schéma que [updateSchoolTaxonomy] : `metadata` n'est pas une colonne
  /// dédiée, donc on relit, on fusionne, on réécrit.
  static Future<void> updateSchoolBulletinTemplate({
    required String id,
    required String template,
  }) async {
    final row = await _db
        .from('schools')
        .select('metadata')
        .eq('id', id)
        .maybeSingle();

    final meta = <String, dynamic>{
      ...?(row?['metadata'] as Map?)?.cast<String, dynamic>(),
      'bulletin_template': template,
    };

    await _db.from('schools').update({
      'metadata': meta,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).friendly();
  }

  /// Les trois réglages « format » de l'école : devise, barème, découpage de
  /// l'année. Ils vivaient sur des valeurs par défaut (XAF / /20 / trimestre)
  /// qu'aucun écran ne permettait de changer — une université ne pouvait pas
  /// passer en semestres, une école hors zone CFA ne pouvait pas changer de
  /// devise. Cet écrit comble ce trou.
  static Future<void> updateSchoolFormat({
    required String id,
    required String currency,
    required String gradingScale,
    required String periodSystem,
    Map<String, String>? gradingByCycle,
    Map<String, String>? periodSystemByCycle,
  }) async {
    final update = <String, dynamic>{
      'currency': currency,
      'grading_scale': gradingScale,
      'period_system': periodSystem,
      'updated_at': DateTime.now().toIso8601String(),
    };
    // Surcharges par cycle : fusionnées dans `metadata` (lecture-fusion-écriture)
    // pour ne pas écraser `types` / `educational_system` déjà présents.
    if (gradingByCycle != null || periodSystemByCycle != null) {
      final row = await _db
          .from('schools')
          .select('metadata')
          .eq('id', id)
          .maybeSingle();
      update['metadata'] = <String, dynamic>{
        ...?(row?['metadata'] as Map?)?.cast<String, dynamic>(),
        if (gradingByCycle != null) 'grading_by_cycle': gradingByCycle,
        if (periodSystemByCycle != null)
          'period_system_by_cycle': periodSystemByCycle,
      };
    }
    await _db.from('schools').update(update).eq('id', id).friendly();
  }

  /// Modules complémentaires installés (Finances/Présences/Inscriptions) —
  /// modifiable après l'inscription, cf. `AdminSubscriptionPage`. « Académique »
  /// n'est plus un module qu'on installe : il est toujours actif et n'est pas
  /// compté dans le quota (`plans.max_modules`). Lecture-fusion-écriture pour
  /// ne pas écraser `types` / `educational_system` déjà présents.
  ///
  /// Vérifie le quota d'emplacements côté client avant d'écrire (message
  /// d'erreur clair) — la base a aussi son propre garde-fou serveur
  /// (`trg_enforce_school_module_quota`) qui refuserait de toute façon un
  /// dépassement, y compris via un autre chemin d'écriture.
  static Future<void> updateSchoolModules(String schoolId, List<String> modules) async {
    final chosenCount = modules.where((m) => m != 'academic').length;
    final sub = await getSubscription(schoolId);
    if (sub?.planCode != null) {
      final plans = await getPlans();
      final plan = plans.where((p) => p.code == sub!.planCode).firstOrNull;
      // Quota EFFECTIF = ce qu'inclut l'offre + les emplacements achetés à la
      // carte (`subscriptions.extra_module_slots`, confirmés par le
      // super-admin) — oublier ce +extra faisait échouer l'installation
      // juste après un achat d'emplacement pourtant confirmé.
      final quota = (plan?.maxModules ?? 0) + (sub?.extraModuleSlots ?? 0);
      if (chosenCount > quota) {
        throw Exception(
            'Quota de modules dépassé : votre offre ${plan?.name ?? sub!.planCode} '
            'autorise $quota module(s) complémentaire(s), $chosenCount sélectionné(s). '
            'Passez à une offre supérieure ou achetez un emplacement pour en installer davantage.');
      }
    }
    final row = await _db.from('schools').select('metadata').eq('id', schoolId).maybeSingle();
    final metadata = <String, dynamic>{
      ...?(row?['metadata'] as Map?)?.cast<String, dynamic>(),
      'modules': modules,
    };
    await _db.from('schools').update({'metadata': metadata}).eq('id', schoolId).friendly();
  }

  /// Slug + statut d'ouverture de la pré-inscription — pour le panneau admin
  /// (lien public + interrupteur). `slug` est posé une fois pour toutes par
  /// la migration 20260714 ; jamais généré côté client (doit rester unique).
  static Future<Map<String, dynamic>?> getSchoolEnrollmentStatus(
      String schoolId) async {
    return _db
        .from('schools')
        .select('slug, preregistration_open, enrollment_api_key')
        .eq('id', schoolId)
        .maybeSingle();
  }

  static Future<void> setSchoolPreregistrationOpen(
      String schoolId, bool open) async {
    await _db
        .from('schools')
        .update({'preregistration_open': open}).eq('id', schoolId).friendly();
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
    String? contactEmail,
    String? contactPhone,
  }) async {
    await _db.from('schools').update({
      'name': name.trim(),
      if (code != null) 'code': code.trim().isEmpty ? null : code.trim(),
      if (city != null) 'city': city.trim().isEmpty ? null : city.trim(),
      if (country != null) 'country': country.trim().isEmpty ? null : country.trim(),
      if (academicYear != null) 'academic_year': academicYear.trim().isEmpty ? null : academicYear.trim(),
      if (accentColor != null) 'accent_color': accentColor,
      if (logoUrl != null) 'logo_url': logoUrl.trim().isEmpty ? null : logoUrl.trim(),
      if (contactEmail != null) 'contact_email': contactEmail.trim().isEmpty ? null : contactEmail.trim(),
      if (contactPhone != null) 'contact_phone': contactPhone.trim().isEmpty ? null : contactPhone.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).friendly();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ÉTAT D'UNE PÉRIODE (workflow du bulletin) — cf. 20260746/47/48
  // Ouverte → Validée → Verrouillée. C'est ce qui gèle les notes et scelle le
  // bulletin. Les transitions passent par des fonctions SECURITY DEFINER qui
  // vérifient le droit et tracent le changement.
  // ══════════════════════════════════════════════════════════════════════════

  /// Lit l'état d'une période. Absente en base = « open » (défaut).
  static Future<SbGradePeriod> getGradePeriod(
      String classId, String period) async {
    final row = await _db
        .from('grade_periods')
        .select()
        .eq('class_id', classId)
        .eq('period', period)
        .maybeSingle();
    return row == null
        ? SbGradePeriod(classId: classId, period: period, status: 'open')
        : SbGradePeriod.fromJson(row);
  }

  /// L'historique des modifications d'une période (classe × trimestre) :
  /// corrections de notes, changements d'état, du plus récent au plus ancien.
  static Future<List<SbAuditEntry>> getPeriodAudit(
      String classId, String period) async {
    final data = await _db
        .from('notes_audit')
        .select()
        .eq('class_id', classId)
        .eq('period', period)
        .order('created_at', ascending: false)
        .limit(500);
    return (data as List)
        .map((j) => SbAuditEntry.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> validatePeriod(String classId, String period) =>
      _db.rpc('validate_period',
          params: {'p_class': classId, 'p_period': period});

  static Future<void> lockPeriod(String classId, String period) =>
      _db.rpc('lock_period', params: {'p_class': classId, 'p_period': period});

  static Future<void> reopenPeriod(String classId, String period,
          {String? reason}) =>
      _db.rpc('reopen_period', params: {
        'p_class': classId,
        'p_period': period,
        if (reason != null) 'p_reason': reason,
      });

  /// Corrige (ou saisit) une note **en transportant le motif** jusqu'au trigger
  /// d'audit — le motif et l'écriture doivent tenir dans la même transaction,
  /// d'où le passage par la fonction SQL plutôt que par un upsert direct.
  /// [reason] est obligatoire côté base dès que la période est validée.
  static Future<void> saveGradeWithReason({
    required String studentId,
    required String classId,
    required String schoolId,
    required String subjectId,
    required double score,
    required double maxScore,
    required String period,
    required String type,
    required int sequence,
    String? reason,
  }) =>
      _db.rpc('save_grade', params: {
        'p_student': studentId,
        'p_class': classId,
        'p_school': schoolId,
        'p_subject': subjectId,
        'p_score': score,
        'p_max': maxScore,
        'p_period': period,
        'p_type': type,
        'p_sequence': sequence,
        if (reason != null) 'p_reason': reason,
      });

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

  /// Supports de cours (`course_materials`) d'une matière — pour l'onglet
  /// Ressources du détail d'un cours. Filtré par nom de matière ; la RLS borne
  /// déjà au tenant. Vide si la matière est vide (pas de requête inutile).
  static Future<List<SbCourseMaterial>> getCourseMaterialsForSubject(
      String subject) async {
    if (subject.trim().isEmpty) return const [];
    final data = await _db
        .from('course_materials')
        .select('id, title, subject, type, level, publisher, file_url, '
            'size_kb, created_at')
        .eq('subject', subject)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => SbCourseMaterial.fromJson(j as Map<String, dynamic>))
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
    }).friendly();
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
      await _db.from('courses').update(patch).eq('id', id).friendly();
    }
  }

  /// Met à jour la progression réelle du prof dans le programme d'un cours
  /// (`chapters_done`) — jamais un UPDATE direct sur `courses` (réservé à
  /// l'admin) : passe par `set_course_chapters_done`, qui vérifie côté base
  /// que l'appelant est bien un enseignant affecté à ce cours.
  static Future<void> setCourseChaptersDone({
    required String courseId,
    required int chaptersDone,
  }) async {
    await _db.rpc('set_course_chapters_done', params: {
      'p_course_id': courseId,
      'p_chapters_done': chaptersDone,
    });
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
    await _db.from('course_teachers').delete().eq('course_id', courseId).friendly();
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
    ]).friendly();
  }

  static Future<void> deleteCourse(String id) async {
    await _db.from('courses').delete().eq('id', id).friendly();
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
    }).friendly();
  }

  static Future<void> deleteLiaisonEntry(String id) async {
    await _db.from('liaison_entries').delete().eq('id', id).friendly();
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
    }).friendly();
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
    }).friendly();
  }

  static Future<void> deleteMeritPoint(String id) async {
    await _db.from('merit_points').delete().eq('id', id).friendly();
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
    }).friendly();
  }

  static Future<void> deleteBadge(String id) async {
    await _db.from('badge_catalog').delete().eq('id', id).friendly();
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
    }).friendly();
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

  // ── Bibliothèque : contribution & modération ───────────────────────────────
  //
  // Les 3 catalogues (`bibliotheque`, `exam_subjects`, `course_materials`)
  // sont UNIVERSELS (pas de school_id) : un item soumis par une école devient
  // visible par toutes les écoles une fois `published`. Tant qu'il est
  // `pending`, seule l'école soumettrice le voit (RLS), le temps qu'un
  // super-admin plateforme le valide ou le rejette (cf.
  // 20260770_library_moderation.sql, 20260772_library_permission.sql).

  /// Dépose le fichier d'une soumission bibliothèque dans le bucket public
  /// `library-content` (le contenu, une fois publié, est censé être diffusé
  /// largement) — même pattern que `uploadEnrollmentDocument`.
  static Future<String> uploadLibraryContent({
    required String category, // 'bibliotheque' | 'exam_subjects' | 'course_materials'
    required String filename,
    required Uint8List bytes,
  }) async {
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$category/${const Uuid().v4()}-$safeName';
    await _db.storage.from('library-content').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _db.storage.from('library-content').getPublicUrl(path);
  }

  static Future<void> submitLibraryBook({
    required String schoolId,
    required String userId,
    required String titre,
    required String auteur,
    required String type,
    required String domaine,
    String? annee,
    String? url,
    String acces = 'libre',
    String? resume,
  }) async {
    await _db.from('bibliotheque').insert({
      'titre': titre,
      'auteur': auteur,
      'type': type,
      'domaine': domaine,
      'annee': annee,
      'url': url,
      'acces': acces,
      'resume': resume,
      'submitted_by_school_id': schoolId,
      'submitted_by_user_id': userId,
    }).friendly();
  }

  static Future<void> submitExamSubject({
    required String schoolId,
    required String userId,
    required String title,
    required String subject,
    required String level,
    required int year,
    String? session,
    bool hasCorrection = false,
    String? url,
    String? correctionUrl,
  }) async {
    await _db.from('exam_subjects').insert({
      'title': title,
      'subject': subject,
      'level': level,
      'session': session,
      'year': year,
      'has_correction': hasCorrection,
      'url': url,
      'correction_url': correctionUrl,
      'submitted_by_school_id': schoolId,
      'submitted_by_user_id': userId,
    }).friendly();
  }

  static Future<void> submitCourseMaterial({
    required String schoolId,
    required String userId,
    required String title,
    required String subject,
    required String type,
    String? level,
    String? publisher,
    int? year,
    String? fileUrl,
    int? sizeKb,
  }) async {
    await _db.from('course_materials').insert({
      'title': title,
      'subject': subject,
      'type': type,
      'level': level,
      'publisher': publisher,
      'year': year,
      'file_url': fileUrl,
      'size_kb': sizeKb,
      'submitted_by_school_id': schoolId,
      'submitted_by_user_id': userId,
    }).friendly();
  }

  static const _librarySubmissionSelect =
      'id, status, rejection_reason, created_at';

  /// Toutes les soumissions d'une école (tous statuts, toutes catégories),
  /// les plus récentes d'abord — pour le suivi « Mes soumissions » côté admin.
  static Future<List<SbLibrarySubmission>> getMyLibrarySubmissions(
      String schoolId) async {
    final out = <SbLibrarySubmission>[];
    final books = await _db
        .from('bibliotheque')
        .select('$_librarySubmissionSelect, titre')
        .eq('submitted_by_school_id', schoolId);
    out.addAll((books as List).map((j) => SbLibrarySubmission.fromJson(
        j as Map<String, dynamic>,
        category: 'bibliotheque',
        titleKey: 'titre')));

    final exams = await _db
        .from('exam_subjects')
        .select('$_librarySubmissionSelect, title')
        .eq('submitted_by_school_id', schoolId);
    out.addAll((exams as List).map((j) => SbLibrarySubmission.fromJson(
        j as Map<String, dynamic>,
        category: 'exam_subjects',
        titleKey: 'title')));

    final materials = await _db
        .from('course_materials')
        .select('$_librarySubmissionSelect, title')
        .eq('submitted_by_school_id', schoolId);
    out.addAll((materials as List).map((j) => SbLibrarySubmission.fromJson(
        j as Map<String, dynamic>,
        category: 'course_materials',
        titleKey: 'title')));

    out.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return out;
  }

  /// Toutes les soumissions `pending` (toutes écoles, toutes catégories) —
  /// file de modération de la console plateforme.
  static Future<List<SbLibrarySubmission>> getPendingLibraryItems() async {
    final out = <SbLibrarySubmission>[];
    const sel = '$_librarySubmissionSelect, submitted_by_school_id, '
        'schools(name)';

    final books = await _db
        .from('bibliotheque')
        .select('$sel, titre')
        .eq('status', 'pending');
    out.addAll((books as List).map((j) => SbLibrarySubmission.fromJson(
        j as Map<String, dynamic>,
        category: 'bibliotheque',
        titleKey: 'titre')));

    final exams = await _db
        .from('exam_subjects')
        .select('$sel, title')
        .eq('status', 'pending');
    out.addAll((exams as List).map((j) => SbLibrarySubmission.fromJson(
        j as Map<String, dynamic>,
        category: 'exam_subjects',
        titleKey: 'title')));

    final materials = await _db
        .from('course_materials')
        .select('$sel, title')
        .eq('status', 'pending');
    out.addAll((materials as List).map((j) => SbLibrarySubmission.fromJson(
        j as Map<String, dynamic>,
        category: 'course_materials',
        titleKey: 'title')));

    out.sort((a, b) => (a.createdAt ?? DateTime(2000))
        .compareTo(b.createdAt ?? DateTime(2000)));
    return out;
  }

  /// Publie une soumission : elle devient visible par TOUTES les écoles.
  static Future<void> approveLibraryItem(
          String category, String id) =>
      _db.from(category).update({'status': 'published'}).eq('id', id).friendly();

  /// Rejette une soumission (motif obligatoire, visible par l'école
  /// soumettrice dans son suivi, invisible ailleurs).
  static Future<void> rejectLibraryItem(
          String category, String id, String reason) =>
      _db
          .from(category)
          .update({'status': 'rejected', 'rejection_reason': reason})
          .eq('id', id).friendly();
}

/// Une soumission au catalogue bibliothèque (livre / annale / support),
/// toutes catégories confondues — pour l'écran « Mes soumissions » (admin
/// école) et la file de modération (console plateforme).
class SbLibrarySubmission {
  final String id;
  final String category; // 'bibliotheque' | 'exam_subjects' | 'course_materials'
  final String title;
  final String status; // 'pending' | 'published' | 'rejected'
  final String? rejectionReason;
  final DateTime? createdAt;
  final String? schoolName;

  const SbLibrarySubmission({
    required this.id,
    required this.category,
    required this.title,
    required this.status,
    this.rejectionReason,
    this.createdAt,
    this.schoolName,
  });

  factory SbLibrarySubmission.fromJson(
    Map<String, dynamic> j, {
    required String category,
    required String titleKey,
  }) =>
      SbLibrarySubmission(
        id: j['id'] as String,
        category: category,
        title: j[titleKey] as String? ?? '—',
        status: j['status'] as String? ?? 'pending',
        rejectionReason: j['rejection_reason'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
        schoolName:
            (j['schools'] as Map<String, dynamic>?)?['name'] as String?,
      );

  String get categoryLabel => switch (category) {
        'bibliotheque' => 'Livre',
        'exam_subjects' => 'Annale',
        'course_materials' => 'Support',
        _ => category,
      };
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
