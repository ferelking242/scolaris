import 'package:supabase_flutter/supabase_flutter.dart';

// ── Entity models ─────────────────────────────────────────────────────────────

class SbStudent {
  final String id;
  final String nom;
  final String prenom;
  final String? email;
  final String? niveau;
  final String? classe;
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
    this.matricule,
    this.avatarUrl,
    this.actif = true,
  });

  String get fullName => '$prenom $nom';
  String get classGroup => classe ?? '';
  String get id_ => matricule ?? id.substring(0, 8).toUpperCase();

  factory SbStudent.fromJson(Map<String, dynamic> j) => SbStudent(
        id: j['id'] as String,
        nom: j['nom'] as String? ?? '',
        prenom: j['prenom'] as String? ?? '',
        email: j['email'] as String?,
        niveau: j['niveau'] as String?,
        classe: j['classe'] as String?,
        matricule: j['matricule'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        actif: j['actif'] as bool? ?? true,
      );
}

class SbClass {
  final String id;
  final String? schoolId;
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
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';

  factory SbInvoice.fromJson(Map<String, dynamic> j) {
    final studentMap = j['students'] as Map<String, dynamic>?;
    return SbInvoice(
      id: j['id'] as String,
      studentId: j['student_id'] as String?,
      studentName: studentMap != null
          ? '${studentMap['prenom'] ?? ''} ${studentMap['nom'] ?? ''}'.trim()
          : null,
      invoiceNumber: j['invoice_number'] as String?,
      description: j['description'] as String?,
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      currency: j['currency'] as String? ?? 'XAF',
      dueDate: j['due_date'] != null ? DateTime.tryParse(j['due_date'] as String) : null,
      status: j['status'] as String? ?? 'pending',
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
  final bool isPinned;
  final int likesCount;
  final DateTime? createdAt;

  const SbAnnouncement({
    required this.id,
    required this.title,
    this.content,
    this.authorName,
    this.targetRole,
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

  const SbSchool({
    required this.id,
    required this.name,
    this.code,
    this.country,
    this.city,
    this.logoUrl,
    this.accentColor,
    this.academicYear,
  });

  factory SbSchool.fromJson(Map<String, dynamic> j) => SbSchool(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        code: j['code'] as String?,
        country: j['country'] as String?,
        city: j['city'] as String?,
        logoUrl: j['logo_url'] as String?,
        accentColor: j['accent_color'] as String?,
        academicYear: j['academic_year'] as String?,
      );
}


  // ── Subscription / Plan types ─────────────────────────────────────────────────

  class SbPlan {
    final String id;
    final String code;   // 'simple' | 'pro' | 'max'
    final String name;
    final int? maxStudents; // null = illimité
    final List<String> features;
    final String? description;

    const SbPlan({
      required this.id,
      required this.code,
      required this.name,
      this.maxStudents,
      this.features = const [],
      this.description,
    });

    String get limitLabel =>
        maxStudents == null ? 'Élèves illimités' : 'Jusqu\'à $maxStudents élèves';

    factory SbPlan.fromJson(Map<String, dynamic> j) => SbPlan(
          id: j['id'] as String? ?? '',
          code: j['code'] as String? ?? '',
          name: j['name'] as String? ?? '',
          maxStudents: j['max_students'] as int?,
          features: (j['features'] as List?)?.map((e) => e.toString()).toList() ?? const [],
          description: j['description'] as String?,
        );
  }

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
  static Future<List<SbStudent>> getStudents({String? classe}) async {
    var q = _db.from('students').select().eq('actif', true);
    if (classe != null) q = q.eq('classe', classe);
    final data = await q.order('nom');
    return (data as List).map((j) => SbStudent.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<SbStudent?> getStudentByProfileId(String profileId) async {
    final data = await _db
        .from('students')
        .select()
        .eq('id', profileId)
        .maybeSingle();
    return data != null ? SbStudent.fromJson(data) : null;
  }

  // ── Classes ───────────────────────────────────────────────────────────────
  static Future<List<SbClass>> getClasses({String? schoolId}) async {
    var q = _db.from('classes').select().eq('is_active', true);
    if (schoolId != null) q = q.eq('school_id', schoolId);
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
    var q = _db.from('invoices').select('*, students(nom, prenom)');
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final data = await q.order('created_at', ascending: false);
    return (data as List).map((j) => SbInvoice.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<List<SbInvoice>> getInvoicesForStudent(String studentId) async {
    final data = await _db
        .from('invoices')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return (data as List).map((j) => SbInvoice.fromJson(j as Map<String, dynamic>)).toList();
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

  static Future<SbSchool?> getFirstSchool() async {
    final data = await _db.from('schools').select().limit(1).maybeSingle();
    return data != null ? SbSchool.fromJson(data) : null;
  }

    // ── Plans & Subscription ──────────────────────────────────────────────────

    static Future<List<SbPlan>> getPlans() async {
      final data = await _db.from('plans').select().order('sort_order', ascending: true);
      return (data as List).map((j) => SbPlan.fromJson(j as Map<String, dynamic>)).toList();
    }

    static Future<List<SbPlanPrice>> getPlanPrices() async {
      final data = await _db.from('plan_prices').select().order('price');
      return (data as List).map((j) => SbPlanPrice.fromJson(j as Map<String, dynamic>)).toList();
    }

    static Future<SbSubscription?> getSubscription(String schoolId) async {
      final data = await _db
          .from('subscriptions')
          .select()
          .eq('school_id', schoolId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data != null ? SbSubscription.fromJson(data) : null;
    }

    static Future<int> getStudentCount({String? schoolId}) async {
      dynamic q = _db.from('students').select('id', const FetchOptions(count: CountOption.exact, head: true));
      if (schoolId != null) q = q.eq('school_id', schoolId);
      q = q.eq('actif', true);
      final resp = await q;
      return resp.count ?? 0;
    }

    static Future<void> activateSubscription({
      required String schoolId,
      required String planCode,
      required String period,
      required double price,
      required String currency,
      double creditBalance = 0,
    }) async {
      final now = DateTime.now();
      final end = period == 'annual'
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 30));
      await _db.from('subscriptions').upsert({
        'school_id':          schoolId,
        'plan_code':          planCode,
        'status':             'active',
        'billing_period':     period,
        'price':              price,
        'currency':           currency,
        'credit_balance':     creditBalance,
        'current_period_end': end.toIso8601String(),
        'updated_at':         now.toIso8601String(),
      }, onConflict: 'school_id');
    }

    // ── School update ─────────────────────────────────────────────────────────

    static Future<void> updateSchool({
      required String id,
      String? name,
      String? code,
      String? city,
      String? country,
      String? academicYear,
      String? accentColor,
      String? logoUrl,
    }) async {
      final payload = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name        != null) payload['name']          = name;
      if (code        != null) payload['code']          = code;
      if (city        != null) payload['city']          = city;
      if (country     != null) payload['country']       = country;
      if (academicYear!= null) payload['academic_year'] = academicYear;
      if (accentColor != null) payload['accent_color']  = accentColor;
      if (logoUrl     != null) payload['logo_url']      = logoUrl;
      await _db.from('schools').update(payload).eq('id', id);
    }
  
}