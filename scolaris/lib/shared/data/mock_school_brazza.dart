/// ══════════════════════════════════════════════════════════════════════════════
/// MOCK CENTRAL — Complexe Scolaire Saint-Gabriel de Brazzaville
/// ══════════════════════════════════════════════════════════════════════════════
///
/// Données fictives d'une école congolaise typique.
/// Cycle : Primaire → Collège → Lycée (+ option Université).
/// Devise : Franc CFA (XAF).
///
/// MIGRATION SUPABASE :
///   Remplacer [MockSchoolBrazza.getUser] par une vraie requête Supabase :
///   ```dart
///   final data = await supabase.from('users').select().eq('email', email).single();
///   return AppUser.fromJson(data);
///   ```
///   Remplacer les listes statiques par des StreamProvider Supabase correspondants.
/// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: constant_identifier_names
library mock_school_brazza;

import '../../domain/entities/user_entity.dart';
import '../../core/config/app_config.dart';

// ── Constantes école ──────────────────────────────────────────────────────────
const kSchoolName     = 'Complexe Scolaire Saint-Gabriel';
const kSchoolCity     = 'Brazzaville';
const kSchoolCountry  = 'Congo';
const kSchoolQuartier = 'Quartier Bacongo';
const kSchoolId       = 'cs-saint-gabriel-brazza';
const kSchoolYear     = '2025–2026';
const kCurrency       = 'XAF';
const kSchoolPhone    = '+242 06 900 0000';
const kSchoolEmail    = 'direction@saint-gabriel.cg';

// ── Classes par cycle ─────────────────────────────────────────────────────────
const kClassesPrimaire = [
  'CP A', 'CP B',
  'CE1 A', 'CE1 B',
  'CE2 A', 'CE2 B',
  'CM1 A', 'CM1 B',
  'CM2 A', 'CM2 B',
];

const kClassesCollege = [
  '6e A', '6e B',
  '5e A', '5e B',
  '4e A', '4e B',
  '3e A', '3e B',
];

const kClassesLycee = [
  '2nde A', '2nde C',
  '1ère A', '1ère C',
  'Tle A', 'Tle C', 'Tle D',
];

const kClassesUniv = ['L1', 'L2', 'L3', 'M1', 'M2'];

const kAllClasses = [
  ...kClassesPrimaire,
  ...kClassesCollege,
  ...kClassesLycee,
];

// ── Matières ──────────────────────────────────────────────────────────────────
class MockSubject {
  final String code;
  final String name;
  final int coef;
  const MockSubject({required this.code, required this.name, required this.coef});
}

const kSubjectsPrimaire = [
  MockSubject(code: 'CALC', name: 'Calcul', coef: 3),
  MockSubject(code: 'LECT', name: 'Lecture-Écriture', coef: 3),
  MockSubject(code: 'DICT', name: 'Dictée', coef: 2),
  MockSubject(code: 'EVEX', name: 'Expression écrite', coef: 2),
  MockSubject(code: 'HIST', name: 'Histoire-Géo', coef: 2),
  MockSubject(code: 'SCI',  name: 'Sciences & Vie', coef: 2),
  MockSubject(code: 'EPS',  name: 'Éducation physique', coef: 1),
  MockSubject(code: 'ARTS', name: 'Arts plastiques', coef: 1),
];

const kSubjectsCollege = [
  MockSubject(code: 'MAT',  name: 'Mathématiques', coef: 4),
  MockSubject(code: 'FRA',  name: 'Français', coef: 4),
  MockSubject(code: 'PC',   name: 'Sciences Physiques', coef: 3),
  MockSubject(code: 'SVT',  name: 'Sciences Naturelles', coef: 3),
  MockSubject(code: 'HIST', name: 'Histoire-Géographie', coef: 3),
  MockSubject(code: 'ANG',  name: 'Anglais', coef: 3),
  MockSubject(code: 'INF',  name: 'Informatique', coef: 2),
  MockSubject(code: 'EPS',  name: 'Éducation physique', coef: 1),
  MockSubject(code: 'ARTS', name: 'Arts plastiques', coef: 1),
];

const kSubjectsLycee = [
  MockSubject(code: 'MAT',  name: 'Mathématiques', coef: 7),
  MockSubject(code: 'PC',   name: 'Sciences Physiques', coef: 6),
  MockSubject(code: 'SVT',  name: 'SVT', coef: 5),
  MockSubject(code: 'FRA',  name: 'Français', coef: 4),
  MockSubject(code: 'PHIL', name: 'Philosophie', coef: 3),
  MockSubject(code: 'HIST', name: 'Histoire-Géographie', coef: 3),
  MockSubject(code: 'ANG',  name: 'Anglais', coef: 3),
  MockSubject(code: 'EPS',  name: 'EPS', coef: 2),
];

// ── Enseignants ───────────────────────────────────────────────────────────────
class MockTeacher {
  final String id;
  final String name;
  final String email;
  final String subject;
  final String cycle;
  final String classe;
  const MockTeacher({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.cycle,
    required this.classe,
  });
}

const kTeachers = [
  MockTeacher(id: 'T001', name: 'M. Ngakosso Jean-Pierre',
      email: 'teacher_secondaire@scolaris.app',
      subject: 'Mathématiques', cycle: 'Lycée', classe: 'Tle C'),
  MockTeacher(id: 'T002', name: 'Mme Mavoungou Cécile',
      email: 'teacher_lycee@scolaris.app',
      subject: 'Français', cycle: 'Lycée', classe: '1ère A'),
  MockTeacher(id: 'T003', name: 'M. Massamba Boris',
      email: 'teacher_pc@scolaris.app',
      subject: 'Sciences Physiques', cycle: 'Lycée', classe: 'Tle D'),
  MockTeacher(id: 'T004', name: 'Mme Nzaba Marie',
      email: 'teacher_svt@scolaris.app',
      subject: 'SVT', cycle: 'Lycée', classe: '1ère C'),
  MockTeacher(id: 'T005', name: 'M. Tsimba Gervais',
      email: 'teacher_hist@scolaris.app',
      subject: 'Histoire-Géographie', cycle: 'Collège', classe: '4e A'),
  MockTeacher(id: 'T006', name: 'Mme Banzouzi Pauline',
      email: 'teacher_ang@scolaris.app',
      subject: 'Anglais', cycle: 'Lycée', classe: '2nde A'),
  MockTeacher(id: 'T007', name: 'M. Mouyabi Rodrigue',
      email: 'teacher_mat_coll@scolaris.app',
      subject: 'Mathématiques', cycle: 'Collège', classe: '3e A'),
  MockTeacher(id: 'T008', name: 'Mme Kikhounga Odette',
      email: 'teacher_fra_coll@scolaris.app',
      subject: 'Français', cycle: 'Collège', classe: '5e B'),
  MockTeacher(id: 'T009', name: 'M. Ondamba Pierre',
      email: 'teacher_eps@scolaris.app',
      subject: 'Éducation Physique', cycle: 'Tous', classe: 'CM2 A'),
  MockTeacher(id: 'T010', name: 'Mme Monianga Sylvie',
      email: 'teacher_primaire@scolaris.app',
      subject: 'Sciences & Vie', cycle: 'Primaire', classe: 'CM1 B'),
  MockTeacher(id: 'T011', name: 'M. Loukia Aristide',
      email: 'teacher_calc@scolaris.app',
      subject: 'Calcul', cycle: 'Primaire', classe: 'CM2 B'),
  MockTeacher(id: 'T012', name: 'Mme Nkouka Sophie',
      email: 'teacher_lect@scolaris.app',
      subject: 'Lecture-Écriture', cycle: 'Primaire', classe: 'CE1 A'),
  MockTeacher(id: 'T013', name: 'M. Mabika Jean-Claude',
      email: 'teacher_info@scolaris.app',
      subject: 'Informatique', cycle: 'Lycée/Collège', classe: '3e B'),
  MockTeacher(id: 'T014', name: 'Mme Makaya Angélique',
      email: 'teacher_arts@scolaris.app',
      subject: 'Arts plastiques', cycle: 'Tous', classe: 'CE2 A'),
  MockTeacher(id: 'T015', name: 'M. Ngandzali Théophile',
      email: 'teacher_philo@scolaris.app',
      subject: 'Philosophie', cycle: 'Terminale', classe: 'Tle A'),
];

// ── Élèves ────────────────────────────────────────────────────────────────────
class MockStudentBrazza {
  final String id;
  final String name;
  final String classe;
  final String cycle;
  final double avg;
  final double attendance;
  final String parentName;
  final String parentEmail;
  const MockStudentBrazza({
    required this.id,
    required this.name,
    required this.classe,
    required this.cycle,
    required this.avg,
    required this.attendance,
    required this.parentName,
    required this.parentEmail,
  });
}

const kStudents = [
  // ── Primaire ────────────────────────────────────────────────────────────────
  MockStudentBrazza(id: 'SG-PRI-001', name: 'Kevin Ndzembo',
      classe: 'CM1 B', cycle: 'Primaire',
      avg: 14.5, attendance: .96,
      parentName: 'M. Ndzembo Théodore', parentEmail: 'parent_college@scolaris.app'),
  MockStudentBrazza(id: 'SG-PRI-002', name: 'Princess Matingou',
      classe: 'CM2 B', cycle: 'Primaire',
      avg: 16.2, attendance: .98,
      parentName: 'Mme Matingou Rose', parentEmail: 'parent_college@scolaris.app'),
  MockStudentBrazza(id: 'SG-PRI-003', name: 'Joëlle Mavoungou',
      classe: 'CM2 A', cycle: 'Primaire',
      avg: 17.0, attendance: 1.0,
      parentName: 'M. Mavoungou Albert', parentEmail: 'parent_primaire@scolaris.app'),
  MockStudentBrazza(id: 'SG-PRI-004', name: 'Franck Yombi',
      classe: 'CE2 A', cycle: 'Primaire',
      avg: 13.1, attendance: .90,
      parentName: 'Mme Yombi Claudine', parentEmail: 'parent_primaire@scolaris.app'),

  // ── Collège ─────────────────────────────────────────────────────────────────
  MockStudentBrazza(id: 'SG-COL-001', name: 'Gloire Nzaba',
      classe: '5e A', cycle: 'Collège',
      avg: 15.7, attendance: .94,
      parentName: 'M. Nzaba Constant', parentEmail: 'parent_college@scolaris.app'),
  MockStudentBrazza(id: 'SG-COL-002', name: 'Brice Mboungou',
      classe: '4e B', cycle: 'Collège',
      avg: 12.4, attendance: .87,
      parentName: 'Mme Mboungou Céline', parentEmail: 'parent_college@scolaris.app'),
  MockStudentBrazza(id: 'SG-COL-003', name: 'Christelle Moukassa',
      classe: '3e A', cycle: 'Collège',
      avg: 17.5, attendance: .99,
      parentName: 'M. Moukassa Évariste', parentEmail: 'parent_lycee@scolaris.app'),
  MockStudentBrazza(id: 'SG-COL-004', name: 'Merveille Ngandou',
      classe: '6e B', cycle: 'Collège',
      avg: 14.0, attendance: .92,
      parentName: 'Mme Ngandou Félicité', parentEmail: 'parent_college@scolaris.app'),
  MockStudentBrazza(id: 'SG-COL-005', name: 'Darlin Mpassi',
      classe: '4e A', cycle: 'Collège',
      avg: 13.8, attendance: .93,
      parentName: 'M. Mpassi Gaston', parentEmail: 'parent_college@scolaris.app'),

  // ── Lycée ────────────────────────────────────────────────────────────────────
  MockStudentBrazza(id: 'SG-LYC-001', name: 'Junior Mafoua',
      classe: 'Tle C', cycle: 'Lycée',
      avg: 16.4, attendance: .97,
      parentName: 'M. Mafoua Placide', parentEmail: 'parent_lycee@scolaris.app'),
  MockStudentBrazza(id: 'SG-LYC-002', name: 'Adèle Makiesse',
      classe: 'Tle A', cycle: 'Lycée',
      avg: 14.8, attendance: .91,
      parentName: 'Mme Makiesse Louise', parentEmail: 'parent_lycee@scolaris.app'),
  MockStudentBrazza(id: 'SG-LYC-003', name: 'Roméo Nsianganga',
      classe: '1ère C', cycle: 'Lycée',
      avg: 15.9, attendance: .95,
      parentName: 'M. Nsianganga Fidèle', parentEmail: 'parent_lycee@scolaris.app'),
  MockStudentBrazza(id: 'SG-LYC-004', name: 'Cynthia Ngakosso',
      classe: '2nde A', cycle: 'Lycée',
      avg: 13.5, attendance: .89,
      parentName: 'Mme Ngakosso Brigitte', parentEmail: 'parent_lycee@scolaris.app'),
  MockStudentBrazza(id: 'SG-LYC-005', name: 'Régis Bouboutou',
      classe: 'Tle D', cycle: 'Lycée',
      avg: 11.2, attendance: .82,
      parentName: 'M. Bouboutou Narcisse', parentEmail: 'parent_lycee@scolaris.app'),
  MockStudentBrazza(id: 'SG-LYC-006', name: 'Stéphanie Loemba',
      classe: '1ère A', cycle: 'Lycée',
      avg: 16.1, attendance: .96,
      parentName: 'Mme Loemba Thérèse', parentEmail: 'parent_lycee@scolaris.app'),
];

// ── Notes mock ─────────────────────────────────────────────────────────────────
class MockNoteBrazza {
  final String matiere;
  final String semestre;
  final double note;
  final String enseignant;
  final DateTime date;
  const MockNoteBrazza({
    required this.matiere,
    required this.semestre,
    required this.note,
    required this.enseignant,
    required this.date,
  });
}

final kNotesPrimaire = [
  MockNoteBrazza(matiere: 'Calcul', semestre: 'S2', note: 15.5,
      enseignant: 'M. Loukia Aristide', date: DateTime(2026, 4, 15)),
  MockNoteBrazza(matiere: 'Lecture-Écriture', semestre: 'S2', note: 14.0,
      enseignant: 'Mme Nkouka Sophie', date: DateTime(2026, 4, 12)),
  MockNoteBrazza(matiere: 'Dictée', semestre: 'S2', note: 13.5,
      enseignant: 'Mme Nkouka Sophie', date: DateTime(2026, 4, 8)),
  MockNoteBrazza(matiere: 'Sciences & Vie', semestre: 'S2', note: 16.0,
      enseignant: 'Mme Monianga Sylvie', date: DateTime(2026, 4, 5)),
  MockNoteBrazza(matiere: 'Histoire-Géo', semestre: 'S2', note: 14.5,
      enseignant: 'M. Tsimba Gervais', date: DateTime(2026, 3, 28)),
  MockNoteBrazza(matiere: 'Éducation physique', semestre: 'S2', note: 17.0,
      enseignant: 'M. Ondamba Pierre', date: DateTime(2026, 3, 22)),
];

final kNotesCollege = [
  MockNoteBrazza(matiere: 'Mathématiques', semestre: 'S2', note: 14.5,
      enseignant: 'M. Mouyabi Rodrigue', date: DateTime(2026, 4, 18)),
  MockNoteBrazza(matiere: 'Français', semestre: 'S2', note: 13.0,
      enseignant: 'Mme Kikhounga Odette', date: DateTime(2026, 4, 15)),
  MockNoteBrazza(matiere: 'Sciences Physiques', semestre: 'S2', note: 15.5,
      enseignant: 'M. Massamba Boris', date: DateTime(2026, 4, 10)),
  MockNoteBrazza(matiere: 'Sciences Naturelles', semestre: 'S2', note: 16.0,
      enseignant: 'Mme Nzaba Marie', date: DateTime(2026, 4, 8)),
  MockNoteBrazza(matiere: 'Histoire-Géographie', semestre: 'S2', note: 14.0,
      enseignant: 'M. Tsimba Gervais', date: DateTime(2026, 4, 2)),
  MockNoteBrazza(matiere: 'Anglais', semestre: 'S2', note: 12.5,
      enseignant: 'Mme Banzouzi Pauline', date: DateTime(2026, 3, 28)),
  MockNoteBrazza(matiere: 'Informatique', semestre: 'S2', note: 18.0,
      enseignant: 'M. Mabika Jean-Claude', date: DateTime(2026, 3, 22)),
];

final kNotesLycee = [
  MockNoteBrazza(matiere: 'Mathématiques', semestre: 'S2', note: 16.5,
      enseignant: 'M. Ngakosso Jean-Pierre', date: DateTime(2026, 4, 20)),
  MockNoteBrazza(matiere: 'Sciences Physiques', semestre: 'S2', note: 15.0,
      enseignant: 'M. Massamba Boris', date: DateTime(2026, 4, 16)),
  MockNoteBrazza(matiere: 'SVT', semestre: 'S2', note: 14.5,
      enseignant: 'Mme Nzaba Marie', date: DateTime(2026, 4, 12)),
  MockNoteBrazza(matiere: 'Français', semestre: 'S2', note: 13.5,
      enseignant: 'Mme Mavoungou Cécile', date: DateTime(2026, 4, 9)),
  MockNoteBrazza(matiere: 'Philosophie', semestre: 'S2', note: 15.0,
      enseignant: 'M. Ngandzali Théophile', date: DateTime(2026, 4, 4)),
  MockNoteBrazza(matiere: 'Histoire-Géographie', semestre: 'S2', note: 16.0,
      enseignant: 'M. Tsimba Gervais', date: DateTime(2026, 3, 30)),
  MockNoteBrazza(matiere: 'Anglais', semestre: 'S2', note: 14.0,
      enseignant: 'Mme Banzouzi Pauline', date: DateTime(2026, 3, 24)),
];

// ── Factures (XAF) ─────────────────────────────────────────────────────────────
class MockInvoiceBrazza {
  final String numero;
  final String eleve;
  final String description;
  final int montant;
  final DateTime echeance;
  final String statut;
  const MockInvoiceBrazza({
    required this.numero,
    required this.eleve,
    required this.description,
    required this.montant,
    required this.echeance,
    required this.statut,
  });
}

final kInvoices = [
  MockInvoiceBrazza(numero: 'FAC-2026-001', eleve: 'Junior Mafoua',
      description: 'Frais de scolarité — Semestre 2',
      montant: 85000, echeance: DateTime(2026, 5, 31), statut: 'payé'),
  MockInvoiceBrazza(numero: 'FAC-2026-002', eleve: 'Adèle Makiesse',
      description: 'Frais de scolarité — Semestre 2',
      montant: 85000, echeance: DateTime(2026, 5, 31), statut: 'en attente'),
  MockInvoiceBrazza(numero: 'FAC-2026-003', eleve: 'Gloire Nzaba',
      description: 'Frais de scolarité — Semestre 2',
      montant: 65000, echeance: DateTime(2026, 5, 31), statut: 'payé'),
  MockInvoiceBrazza(numero: 'FAC-2026-004', eleve: 'Kevin Ndzembo',
      description: 'Frais de scolarité — Semestre 2',
      montant: 45000, echeance: DateTime(2026, 5, 31), statut: 'en attente'),
  MockInvoiceBrazza(numero: 'FAC-2026-005', eleve: 'Christelle Moukassa',
      description: 'Frais de scolarité — Semestre 2',
      montant: 65000, echeance: DateTime(2026, 5, 31), statut: 'en retard'),
  MockInvoiceBrazza(numero: 'FAC-2026-006', eleve: 'Roméo Nsianganga',
      description: 'Cantine scolaire — Semestre 2',
      montant: 25000, echeance: DateTime(2026, 5, 31), statut: 'payé'),
  MockInvoiceBrazza(numero: 'FAC-2026-007', eleve: 'Brice Mboungou',
      description: 'Transport scolaire — Semestre 2',
      montant: 18000, echeance: DateTime(2026, 5, 31), statut: 'en retard'),
];

// ── Lookup utilisateur mock ────────────────────────────────────────────────────
/// Retourne un [AppUser] complet selon l'email, ou null si inconnu.
/// L'email suit le pattern : `{role}_{subtype}@scolaris.app`
/// Ex: `student_lycee@scolaris.app`, `teacher_primaire@scolaris.app`
class MockSchoolBrazza {
  static AppUser? getUser(String email) {
    final local = email.split('@').first.toLowerCase();

    // Enseignants
    for (final t in kTeachers) {
      if (t.email.split('@').first == local) {
        return AppUser(
          id: t.id,
          email: email,
          fullName: t.name,
          role: UserRole.teacher,
          schoolId: kSchoolId,
          schoolAccentArgb: AppConfig.defaultAccentArgb,
          roleTitle: '${t.cycle} — ${t.subject}',
        );
      }
    }

    // Élèves — pattern student_{cycle}
    if (local.startsWith('student_')) {
      final sub = local.replaceFirst('student_', '');
      final student = _studentForSubtype(sub);
      if (student != null) {
        return AppUser(
          id: student.id,
          email: email,
          fullName: student.name,
          role: UserRole.student,
          schoolId: kSchoolId,
          schoolAccentArgb: AppConfig.defaultAccentArgb,
          roleTitle: '${student.cycle} — ${student.classe}',
        );
      }
    }

    // Parents — pattern parent_{cycle}
    if (local.startsWith('parent_')) {
      final sub = local.replaceFirst('parent_', '');
      final student = _studentForSubtype(sub);
      if (student != null) {
        return AppUser(
          id: 'PAR-${student.id}',
          email: email,
          fullName: student.parentName,
          role: UserRole.parent,
          schoolId: kSchoolId,
          schoolAccentArgb: AppConfig.defaultAccentArgb,
          roleTitle: 'Parent · ${student.classe}',
        );
      }
    }

    // Staff — pattern admin_{subtype}
    if (local.startsWith('admin_') || local == 'admin') {
      final sub = local.replaceFirst('admin_', '');
      return _staffUser(email: email, sub: sub);
    }

    if (local.startsWith('finance_') || local == 'finance') {
      final sub = local.replaceFirst('finance_', '');
      return _staffUser(email: email, sub: sub, role: 'finance');
    }

    if (local.startsWith('surveillance_') || local == 'surveillance') {
      final sub = local.replaceFirst('surveillance_', '');
      return _staffUser(email: email, sub: sub, role: 'surveillance');
    }

    return null;
  }

  static MockStudentBrazza? _studentForSubtype(String sub) {
    switch (sub) {
      case 'primaire':
        return kStudents.firstWhere((s) => s.cycle == 'Primaire',
            orElse: () => kStudents.first);
      case 'college':
        return kStudents.firstWhere((s) => s.cycle == 'Collège',
            orElse: () => kStudents.first);
      case 'lycee':
        return kStudents.firstWhere((s) => s.cycle == 'Lycée',
            orElse: () => kStudents.last);
      case 'univ':
        return MockStudentBrazza(
          id: 'SG-UNV-001', name: 'Exaucé Nkounkou',
          classe: 'L2 Droit', cycle: 'Université',
          avg: 13.8, attendance: .88,
          parentName: 'M. Nkounkou Prosper',
          parentEmail: 'parent_lycee@scolaris.app',
        );
      default:
        return kStudents.firstWhere((s) => s.cycle == 'Lycée',
            orElse: () => kStudents.last);
    }
  }

  static AppUser _staffUser({
    required String email,
    String sub = '',
    String role = 'admin',
  }) {
    final map = <String, (String, String)>{
      'directeur':  ('M. Mbemba-Ndzaba Simon', 'Directeur'),
      'secretaire': ('Mme Bouanga Henriette',  'Secrétariat'),
      'dg':         ('M. Ossomba Patrick',     'Directeur Général'),
      'comptable':  ('Mme Malonga Yvette',     'Comptable Principal'),
      'caissier':   ('M. Ngoma Cédric',        'Caissier'),
      'sg':         ('M. Itoua Marcel',        'Surveillant Général'),
      'aux':        ('Mme Banzouzi Ginette',   'Auxiliaire de surveillance'),
    };
    final roleLabel = role == 'finance'
        ? 'Comptable Principal'
        : role == 'surveillance'
            ? 'Surveillant Général'
            : 'Administrateur';
    final info = map[sub] ?? map['directeur']!;
    return AppUser(
      id: 'STAFF-${sub.hashCode.abs()}',
      email: email,
      fullName: info.$1,
      role: UserRole.staff,
      schoolId: kSchoolId,
      schoolAccentArgb: AppConfig.defaultAccentArgb,
      roleTitle: info.$2,
    );
  }
}
