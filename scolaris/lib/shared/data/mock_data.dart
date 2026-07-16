/// Centralized mock data for the prototype — to be replaced by Supabase later.
import 'package:flutter/material.dart';

class MockStudent {
  final String id;
  final String name;
  final String classGroup;
  final double avg;
  final double attendance;
  final String guardian;
  const MockStudent({
    required this.id,
    required this.name,
    required this.classGroup,
    required this.avg,
    required this.attendance,
    required this.guardian,
  });
}

class MockGrade {
  final String subject;
  final String term;
  final double value;
  final String teacher;
  final DateTime date;
  const MockGrade({
    required this.subject,
    required this.term,
    required this.value,
    required this.teacher,
    required this.date,
  });
}

class MockCourse {
  final String code;
  final String name;
  final String teacher;
  final int hoursPerWeek;
  final IconData icon;
  final Color color;
  final String classe;
  final String description;
  final int chapters;
  final List<String> objectives;
  final List<String> resources;
  final String importantInfo;
  const MockCourse({
    required this.code,
    required this.name,
    required this.teacher,
    required this.hoursPerWeek,
    required this.icon,
    required this.color,
    required this.classe,
    required this.description,
    required this.chapters,
    required this.objectives,
    required this.resources,
    required this.importantInfo,
  });
}

class MockScheduleSlot {
  final String day;
  final String time;
  final String subject;
  final String room;
  final String teacher;
  const MockScheduleSlot({
    required this.day,
    required this.time,
    required this.subject,
    required this.room,
    required this.teacher,
  });
}

class MockInvoice {
  final String number;
  final String student;
  final String description;
  final double amount;
  final DateTime due;
  final InvoiceStatus status;
  const MockInvoice({
    required this.number,
    required this.student,
    required this.description,
    required this.amount,
    required this.due,
    required this.status,
  });
}

enum InvoiceStatus { paid, pending, overdue }

class MockMessage {
  final String from;
  final String preview;
  final String time;
  final bool unread;
  const MockMessage({
    required this.from,
    required this.preview,
    required this.time,
    required this.unread,
  });
}

class MockClass {
  final String name;
  final String level;
  final String teacher;
  final int students;
  const MockClass({
    required this.name,
    required this.level,
    required this.teacher,
    required this.students,
  });
}

class MockAttendanceEntry {
  final String student;
  final String classGroup;
  final String time;
  final AttendanceStatus status;
  const MockAttendanceEntry({
    required this.student,
    required this.classGroup,
    required this.time,
    required this.status,
  });
}

enum AttendanceStatus { present, late, absent }

class MockUser {
  final String name;
  final String email;
  final String role;
  final bool active;
  final String lastSeen;
  const MockUser({
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.lastSeen,
  });
}

class MockAttendanceStat {
  final String label;
  final double presents;
  final double absents;
  final double retards;
  const MockAttendanceStat({
    required this.label,
    required this.presents,
    required this.absents,
    required this.retards,
  });
}

class MockEvent {
  final String title;
  final String date;
  final String type;
  final Color color;
  const MockEvent({
    required this.title,
    required this.date,
    required this.type,
    required this.color,
  });
}

class MockAnnouncement {
  final String title;
  final String body;
  final String author;
  final String time;
  final IconData icon;
  final Color color;
  const MockAnnouncement({
    required this.title,
    required this.body,
    required this.author,
    required this.time,
    required this.icon,
    required this.color,
  });
}

class MockData {
  static final students = <MockStudent>[
    MockStudent(id: 'AKL-001', name: 'Ada Lovelace',    classGroup: '5e A', avg: 16.2, attendance: .98, guardian: 'Augusta King'),
    MockStudent(id: 'AKL-002', name: 'Ben Kingsley',    classGroup: '5e A', avg: 14.1, attendance: .92, guardian: 'David Kingsley'),
    MockStudent(id: 'AKL-003', name: 'Chloé Martin',    classGroup: '5e B', avg: 13.5, attendance: .89, guardian: 'Sophie Martin'),
    MockStudent(id: 'AKL-004', name: 'Dieudonné Mbo',   classGroup: '4e A', avg: 17.8, attendance: 1.0, guardian: 'Léa Mbo'),
    MockStudent(id: 'AKL-005', name: 'Eunice Otieno',   classGroup: '4e A', avg: 15.0, attendance: .94, guardian: 'James Otieno'),
    MockStudent(id: 'AKL-006', name: 'Fatou Diallo',    classGroup: '4e B', avg: 12.3, attendance: .81, guardian: 'Mariam Diallo'),
    MockStudent(id: 'AKL-007', name: 'Gabriel Ndiaye',  classGroup: '3e A', avg: 14.6, attendance: .96, guardian: 'Aïda Ndiaye'),
    MockStudent(id: 'AKL-008', name: 'Hanae Bouzid',    classGroup: '3e A', avg: 18.2, attendance: 1.0, guardian: 'Karim Bouzid'),
  ];

  static final catalog = <MockCourse>[
    // ── 6e ──────────────────────────────────────────────────────────────
    MockCourse(
      code: 'MAT-6', name: 'Mathématiques', teacher: 'M. Dupont',
      hoursPerWeek: 5, icon: Icons.calculate_rounded,
      color: const Color(0xFF6D28D9), classe: '6e',
      description: 'Initiation aux opérations fondamentales, fractions, géométrie plane et résolution de problèmes.',
      chapters: 10,
      objectives: ['Maîtriser les fractions', 'Comprendre les figures géométriques', 'Résoudre des équations simples'],
      resources: ['Manuel Maths 6e', 'Cahier d\'exercices', 'Fiches de révision en ligne'],
      importantInfo: 'Calculatrice interdite aux évaluations de T1.',
    ),
    MockCourse(
      code: 'FRA-6', name: 'Français', teacher: 'M. Mbiya',
      hoursPerWeek: 4, icon: Icons.menu_book_rounded,
      color: const Color(0xFFEA580C), classe: '6e',
      description: 'Lecture, expression écrite et orale, grammaire, conjugaison et orthographe.',
      chapters: 9,
      objectives: ['Lire et comprendre des textes variés', 'Rédiger un paragraphe structuré', 'Maîtriser l\'accord du verbe'],
      resources: ['Antologie littéraire 6e', 'Dictionnaire Le Robert Junior'],
      importantInfo: 'Un dictionnaire personnel obligatoire dès la rentrée.',
    ),
    MockCourse(
      code: 'SVT-6', name: 'Sciences de la Vie', teacher: 'Dr. Yao',
      hoursPerWeek: 3, icon: Icons.biotech_rounded,
      color: const Color(0xFF0891B2), classe: '6e',
      description: 'Observation du vivant : cellules, biodiversité, écosystèmes et reproduction.',
      chapters: 8,
      objectives: ['Identifier les grandes familles du vivant', 'Comprendre les écosystèmes', 'Mener une observation scientifique'],
      resources: ['Manuel SVT 6e', 'Microscopes du laboratoire C-105'],
      importantInfo: 'Sortie botanique prévue en avril — autorisation parentale requise.',
    ),
    MockCourse(
      code: 'HIS-6', name: 'Histoire-Géographie', teacher: 'M. Kabamba',
      hoursPerWeek: 3, icon: Icons.public_rounded,
      color: const Color(0xFFDB2777), classe: '6e',
      description: 'Premières civilisations, géographie de l\'Afrique et du monde.',
      chapters: 8,
      objectives: ['Situer les grandes civilisations antiques', 'Lire une carte géographique', 'Analyser un document historique'],
      resources: ['Atlas Jeunesse', 'Manuel Histoire-Géo 6e'],
      importantInfo: 'Exposé de groupe sur une civilisation africaine — T3.',
    ),

    // ── 5e ──────────────────────────────────────────────────────────────
    MockCourse(
      code: 'MAT-5', name: 'Mathématiques', teacher: 'M. Dupont',
      hoursPerWeek: 5, icon: Icons.calculate_rounded,
      color: const Color(0xFF6D28D9), classe: '5e',
      description: 'Nombres relatifs, puissances, proportionnalité, géométrie dans l\'espace.',
      chapters: 12,
      objectives: ['Opérer sur les nombres relatifs', 'Résoudre des problèmes de proportionnalité', 'Calculer volumes et aires'],
      resources: ['Manuel Maths 5e', 'Logiciel GeoGebra', 'Fiches d\'entraînement'],
      importantInfo: 'Calculatrice autorisée à partir du T2.',
    ),
    MockCourse(
      code: 'PHY-5', name: 'Physique-Chimie', teacher: 'Mme Lefèvre',
      hoursPerWeek: 4, icon: Icons.science_rounded,
      color: const Color(0xFF0EA5E9), classe: '5e',
      description: 'Introduction à la physique : lumière, électricité, matière et mélanges.',
      chapters: 10,
      objectives: ['Comprendre les propriétés de la lumière', 'Monter un circuit électrique simple', 'Distinguer corps pur et mélange'],
      resources: ['Manuel Physique-Chimie 5e', 'Kit expérimental laboratoire'],
      importantInfo: 'TP obligatoires chaque vendredi — blouse de laboratoire requise.',
    ),
    MockCourse(
      code: 'ENG-5', name: 'Anglais', teacher: 'Ms. Carter',
      hoursPerWeek: 3, icon: Icons.translate_rounded,
      color: const Color(0xFF16A34A), classe: '5e',
      description: 'Consolidation des bases : vocabulaire, grammaire et expression orale.',
      chapters: 9,
      objectives: ['Comprendre un texte court', 'Tenir une conversation simple', 'Rédiger un paragraphe en anglais'],
      resources: ['Textbook "Bridge to English 5e"', 'Application Duolingo Schools'],
      importantInfo: 'Contrôle oral chaque trimestre — coefficient 2.',
    ),
    MockCourse(
      code: 'FRA-5', name: 'Français', teacher: 'M. Mbiya',
      hoursPerWeek: 4, icon: Icons.menu_book_rounded,
      color: const Color(0xFFEA580C), classe: '5e',
      description: 'Littérature, narration, argumentation et maîtrise de la langue écrite.',
      chapters: 10,
      objectives: ['Analyser un texte narratif', 'Rédiger une lettre formelle', 'Employer les temps du récit'],
      resources: ['Recueil de textes 5e', 'Bescherelle'],
      importantInfo: 'Lecture d\'un roman au choix obligatoire chaque trimestre.',
    ),

    // ── 4e ──────────────────────────────────────────────────────────────
    MockCourse(
      code: 'MAT-4', name: 'Mathématiques', teacher: 'M. Dupont',
      hoursPerWeek: 5, icon: Icons.calculate_rounded,
      color: const Color(0xFF6D28D9), classe: '4e',
      description: 'Algèbre linéaire, équations du 1er degré, fonctions et statistiques.',
      chapters: 14,
      objectives: ['Résoudre une équation du 1er degré', 'Lire et interpréter un graphique', 'Calculer moyenne et médiane'],
      resources: ['Manuel Maths 4e', 'Calculatrice graphique', 'Tableur Excel'],
      importantInfo: 'Devoir surveillé bimensuel — coefficient cumulatif.',
    ),
    MockCourse(
      code: 'INF-4', name: 'Informatique', teacher: 'M. Mukasa',
      hoursPerWeek: 2, icon: Icons.terminal_rounded,
      color: const Color(0xFF111827), classe: '4e',
      description: 'Algorithmique, Scratch, introduction à Python et pensée computationnelle.',
      chapters: 8,
      objectives: ['Écrire un algorithme simple', 'Créer un programme Scratch', 'Déboguer un script Python'],
      resources: ['Salle informatique L-001', 'IDE Thonny (Python)', 'MIT Scratch en ligne'],
      importantInfo: 'Projet final individuel — présentation en T3.',
    ),

    // ── 3e ──────────────────────────────────────────────────────────────
    MockCourse(
      code: 'MAT-3', name: 'Mathématiques', teacher: 'M. Dupont',
      hoursPerWeek: 5, icon: Icons.calculate_rounded,
      color: const Color(0xFF6D28D9), classe: '3e',
      description: 'Préparation au Brevet : fonctions, Pythagore, trigonométrie et probabilités.',
      chapters: 15,
      objectives: ['Maîtriser le théorème de Pythagore', 'Calculer une probabilité', 'Représenter une fonction affine'],
      resources: ['Manuel Brevet Maths', 'Annales officielles', 'Khan Academy'],
      importantInfo: 'Préparation intensive aux épreuves du Brevet dès T2.',
    ),
    MockCourse(
      code: 'PHY-3', name: 'Physique-Chimie', teacher: 'Mme Lefèvre',
      hoursPerWeek: 4, icon: Icons.science_rounded,
      color: const Color(0xFF0EA5E9), classe: '3e',
      description: 'Électricité, réactions chimiques, énergie et optique.',
      chapters: 12,
      objectives: ['Appliquer la loi d\'Ohm', 'Équilibrer une équation chimique', 'Calculer une vitesse'],
      resources: ['Manuel Physique-Chimie 3e', 'Simulateur PhET'],
      importantInfo: 'Coefficient 3 aux épreuves du Brevet.',
    ),
    MockCourse(
      code: 'HIS-3', name: 'Histoire-Géographie', teacher: 'M. Kabamba',
      hoursPerWeek: 3, icon: Icons.public_rounded,
      color: const Color(0xFFDB2777), classe: '3e',
      description: 'XXe siècle, mondialisation, citoyenneté et enjeux géopolitiques contemporains.',
      chapters: 11,
      objectives: ['Analyser les conflits mondiaux', 'Comprendre la mondialisation', 'Rédiger une composition historique'],
      resources: ['Manuel HGc 3e', 'Journaux et revues d\'actualité'],
      importantInfo: 'Épreuve d\'éducation civique incluse au Brevet — coefficient 2.',
    ),
  ];

  static List<MockCourse> get courses => catalog.where((c) => c.classe == '5e').toList();

  static final grades = <MockGrade>[
    MockGrade(subject: 'Mathematics', term: 'T2', value: 17.5, teacher: 'M. Dupont',   date: DateTime(2026, 4, 12)),
    MockGrade(subject: 'Physics',     term: 'T2', value: 14.0, teacher: 'Mme Lefèvre', date: DateTime(2026, 4, 9)),
    MockGrade(subject: 'Français',    term: 'T2', value: 15.5, teacher: 'M. Mbiya',    date: DateTime(2026, 4, 5)),
    MockGrade(subject: 'English',     term: 'T2', value: 16.0, teacher: 'Ms. Carter',  date: DateTime(2026, 3, 28)),
    MockGrade(subject: 'History',     term: 'T2', value: 12.5, teacher: 'M. Kabamba',  date: DateTime(2026, 3, 22)),
    MockGrade(subject: 'Biology',     term: 'T2', value: 18.0, teacher: 'Dr. Yao',     date: DateTime(2026, 3, 18)),
  ];

  static final schedule = <MockScheduleSlot>[
    MockScheduleSlot(day: 'Mon', time: '08:00–09:30', subject: 'Mathematics',     room: 'B-204', teacher: 'M. Dupont'),
    MockScheduleSlot(day: 'Mon', time: '09:45–11:15', subject: 'English',         room: 'A-110', teacher: 'Ms. Carter'),
    MockScheduleSlot(day: 'Mon', time: '13:00–14:30', subject: 'Physics',         room: 'C-301', teacher: 'Mme Lefèvre'),
    MockScheduleSlot(day: 'Tue', time: '08:00–09:30', subject: 'Français',        room: 'A-205', teacher: 'M. Mbiya'),
    MockScheduleSlot(day: 'Tue', time: '09:45–11:15', subject: 'Biology',         room: 'C-105', teacher: 'Dr. Yao'),
    MockScheduleSlot(day: 'Wed', time: '08:00–09:30', subject: 'History',         room: 'B-101', teacher: 'M. Kabamba'),
    MockScheduleSlot(day: 'Wed', time: '13:00–14:30', subject: 'Mathematics',     room: 'B-204', teacher: 'M. Dupont'),
    MockScheduleSlot(day: 'Thu', time: '09:45–11:15', subject: 'Computer Science',room: 'L-001', teacher: 'M. Mukasa'),
    MockScheduleSlot(day: 'Fri', time: '08:00–09:30', subject: 'Physics',         room: 'C-301', teacher: 'Mme Lefèvre'),
    MockScheduleSlot(day: 'Fri', time: '09:45–11:15', subject: 'Français',        room: 'A-205', teacher: 'M. Mbiya'),
  ];

  static final invoices = <MockInvoice>[
    MockInvoice(number: 'INV-26041', student: 'Ada Lovelace',   description: 'Tuition — April', amount: 320.0, due: DateTime(2026, 4, 30), status: InvoiceStatus.paid),
    MockInvoice(number: 'INV-26042', student: 'Ben Kingsley',   description: 'Tuition — April', amount: 320.0, due: DateTime(2026, 4, 30), status: InvoiceStatus.pending),
    MockInvoice(number: 'INV-26043', student: 'Chloé Martin',   description: 'Cantine — April', amount:  85.0, due: DateTime(2026, 4, 30), status: InvoiceStatus.overdue),
    MockInvoice(number: 'INV-26044', student: 'Dieudonné Mbo',  description: 'Tuition — April', amount: 320.0, due: DateTime(2026, 4, 30), status: InvoiceStatus.paid),
    MockInvoice(number: 'INV-26045', student: 'Eunice Otieno',  description: 'Bus — April',     amount:  60.0, due: DateTime(2026, 4, 30), status: InvoiceStatus.paid),
    MockInvoice(number: 'INV-26046', student: 'Fatou Diallo',   description: 'Tuition — April', amount: 320.0, due: DateTime(2026, 4, 30), status: InvoiceStatus.overdue),
    MockInvoice(number: 'INV-26047', student: 'Gabriel Ndiaye', description: 'Tuition — April', amount: 320.0, due: DateTime(2026, 4, 30), status: InvoiceStatus.pending),
  ];

  static final messages = <MockMessage>[
    MockMessage(from: 'M. Dupont',      preview: 'Le nouveau programme de Mai est disponible.',       time: '09:14',     unread: true),
    MockMessage(from: 'Finance Office', preview: 'Rappel : scolarité due avant le 30 avril.',         time: '08:02',     unread: true),
    MockMessage(from: 'Surveillance',   preview: 'Ben Kingsley est arrivé en retard ce matin.',       time: 'Hier',      unread: false),
    MockMessage(from: 'Dr. Yao',        preview: 'Les autorisations de sortie botanique sont prêtes.', time: 'Il y a 2j', unread: false),
  ];

  static final classes = <MockClass>[
    MockClass(name: '5e A', level: 'Collège', teacher: 'M. Dupont',   students: 28),
    MockClass(name: '5e B', level: 'Collège', teacher: 'Mme Lefèvre', students: 26),
    MockClass(name: '4e A', level: 'Collège', teacher: 'M. Mbiya',    students: 30),
    MockClass(name: '4e B', level: 'Collège', teacher: 'Ms. Carter',  students: 27),
    MockClass(name: '3e A', level: 'Collège', teacher: 'M. Kabamba',  students: 24),
    MockClass(name: '3e B', level: 'Collège', teacher: 'Dr. Yao',     students: 25),
  ];

  static final attendance = <MockAttendanceEntry>[
    MockAttendanceEntry(student: 'Ada Lovelace',   classGroup: '5e A', time: '07:48', status: AttendanceStatus.present),
    MockAttendanceEntry(student: 'Ben Kingsley',   classGroup: '5e A', time: '08:12', status: AttendanceStatus.late),
    MockAttendanceEntry(student: 'Chloé Martin',   classGroup: '5e B', time: '07:55', status: AttendanceStatus.present),
    MockAttendanceEntry(student: 'Dieudonné Mbo',  classGroup: '4e A', time: '07:39', status: AttendanceStatus.present),
    MockAttendanceEntry(student: 'Eunice Otieno',  classGroup: '4e A', time: '—',     status: AttendanceStatus.absent),
    MockAttendanceEntry(student: 'Fatou Diallo',   classGroup: '4e B', time: '07:50', status: AttendanceStatus.present),
    MockAttendanceEntry(student: 'Gabriel Ndiaye', classGroup: '3e A', time: '08:25', status: AttendanceStatus.late),
    MockAttendanceEntry(student: 'Hanae Bouzid',   classGroup: '3e A', time: '07:43', status: AttendanceStatus.present),
  ];

  static final users = <MockUser>[
    MockUser(name: 'Sarah Mukasa',   email: 'sarah.m@scolaris.app',  role: 'admin',        active: true,  lastSeen: 'Il y a 2 min'),
    MockUser(name: 'M. Dupont',      email: 'dupont@scolaris.app',   role: 'teacher',      active: true,  lastSeen: 'Il y a 8 min'),
    MockUser(name: 'Mme Lefèvre',    email: 'lefevre@scolaris.app',  role: 'teacher',      active: true,  lastSeen: 'Il y a 15 min'),
    MockUser(name: 'Jean Tshibangu', email: 'jt@scolaris.app',       role: 'finance',      active: true,  lastSeen: 'Il y a 1h'),
    MockUser(name: 'Pierre Olongo',  email: 'olongo@scolaris.app',   role: 'surveillance', active: true,  lastSeen: 'Il y a 3h'),
    MockUser(name: 'Ada Lovelace',   email: 'ada.l@scolaris.app',    role: 'student',      active: true,  lastSeen: 'Hier'),
    MockUser(name: 'Ben Kingsley',   email: 'ben.k@scolaris.app',    role: 'student',      active: true,  lastSeen: 'Hier'),
    MockUser(name: 'Marc Diallo',    email: 'm.diallo@scolaris.app', role: 'parent',       active: false, lastSeen: 'Il y a 5j'),
  ];

  /// Statistiques de présence par semaine (T2).
  static final weeklyAttendance = <MockAttendanceStat>[
    MockAttendanceStat(label: 'S1', presents: 5, absents: 0, retards: 0),
    MockAttendanceStat(label: 'S2', presents: 4, absents: 1, retards: 0),
    MockAttendanceStat(label: 'S3', presents: 5, absents: 0, retards: 0),
    MockAttendanceStat(label: 'S4', presents: 4, absents: 0, retards: 1),
    MockAttendanceStat(label: 'S5', presents: 3, absents: 2, retards: 0),
    MockAttendanceStat(label: 'S6', presents: 5, absents: 0, retards: 0),
    MockAttendanceStat(label: 'S7', presents: 4, absents: 0, retards: 1),
    MockAttendanceStat(label: 'S8', presents: 5, absents: 0, retards: 0),
  ];

  /// Résumé global de présence (T2).
  static const attendanceSummary = (
    joursTotal: 40,
    presents: 36,
    absents: 3,
    retards: 1,
    tauxPresence: 90.0,
    tauxAbsence: 7.5,
  );

  static final events = <MockEvent>[
    MockEvent(title: 'Conseil de classe T2', date: '12 Juin 2026', type: 'Académique', color: Color(0xFF6D28D9)),
    MockEvent(title: 'Sortie botanique SVT', date: '18 Juin 2026', type: 'Sortie',    color: Color(0xFF0891B2)),
    MockEvent(title: 'Examens fin T2',       date: '25 Juin 2026', type: 'Examen',    color: Color(0xFF8B1A00)),
    MockEvent(title: 'Journée portes ouvertes', date: '5 Juil 2026', type: 'École',   color: Color(0xFFC17F24)),
  ];

  static final announcements = <MockAnnouncement>[
    MockAnnouncement(
      title: 'Examens de fin de trimestre',
      body: 'Les examens du T2 auront lieu du 23 au 27 juin. Les révisions intensives démarrent dès lundi.',
      author: 'Direction', time: 'Il y a 2h',
      icon: Icons.event_note_rounded, color: Color(0xFF8B1A00),
    ),
    MockAnnouncement(
      title: 'Nouveau programme de mathématiques',
      body: 'Le chapitre 9 sur les probabilités est maintenant disponible sur la plateforme.',
      author: 'M. Dupont', time: 'Il y a 5h',
      icon: Icons.calculate_rounded, color: Color(0xFF6D28D9),
    ),
    MockAnnouncement(
      title: 'Sortie botanique en SVT',
      body: 'Les autorisations parentales doivent être remises avant le 15 juin.',
      author: 'Dr. Yao', time: 'Hier',
      icon: Icons.park_rounded, color: Color(0xFF0891B2),
    ),
  ];

  static double totalCollected() =>
      invoices.where((i) => i.status == InvoiceStatus.paid).fold(0.0, (a, b) => a + b.amount);
  static double totalPending() =>
      invoices.where((i) => i.status == InvoiceStatus.pending).fold(0.0, (a, b) => a + b.amount);
  static double totalOverdue() =>
      invoices.where((i) => i.status == InvoiceStatus.overdue).fold(0.0, (a, b) => a + b.amount);
}
