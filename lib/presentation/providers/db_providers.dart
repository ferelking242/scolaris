import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/remote/supabase_db_source.dart';
import 'auth_providers.dart';

// ── School ────────────────────────────────────────────────────────────────────
final schoolProvider = FutureProvider<SbSchool?>((ref) async {
  return SupabaseDbSource.getFirstSchool();
});

// ── Students ──────────────────────────────────────────────────────────────────
final studentsProvider = FutureProvider<List<SbStudent>>((ref) async {
  return SupabaseDbSource.getStudents();
});

final studentsByClassProvider = FutureProvider.family<List<SbStudent>, String>(
  (ref, classe) async => SupabaseDbSource.getStudents(classe: classe),
);

final myStudentProfileProvider = FutureProvider<SbStudent?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  return SupabaseDbSource.getStudentByProfileId(session.id);
});

// ── Classes ───────────────────────────────────────────────────────────────────
final classesProvider = FutureProvider<List<SbClass>>((ref) async {
  return SupabaseDbSource.getClasses();
});

// ── Subjects ──────────────────────────────────────────────────────────────────
final subjectsProvider = FutureProvider<List<SbSubject>>((ref) async {
  return SupabaseDbSource.getSubjects();
});

// ── Grades ────────────────────────────────────────────────────────────────────
final gradesForStudentProvider = FutureProvider.family<List<SbGrade>, String>(
  (ref, studentId) async => SupabaseDbSource.getGradesForStudent(studentId),
);

final gradesForClassProvider = FutureProvider.family<List<SbGrade>, String>(
  (ref, classId) async => SupabaseDbSource.getGradesForClass(classId),
);

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

// ── Invoices ──────────────────────────────────────────────────────────────────
final invoicesProvider = FutureProvider<List<SbInvoice>>((ref) async {
  return SupabaseDbSource.getInvoices();
});

final myInvoicesProvider = FutureProvider<List<SbInvoice>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return [];
  return SupabaseDbSource.getInvoicesForStudent(session.id);
});

// ── Messages ──────────────────────────────────────────────────────────────────
final messagesProvider = FutureProvider<List<SbMessage>>((ref) async {
  return SupabaseDbSource.getMessages();
});

// ── Announcements ─────────────────────────────────────────────────────────────
final announcementsProvider = FutureProvider<List<SbAnnouncement>>((ref) async {
  return SupabaseDbSource.getAnnouncements();
});

// ── Users ─────────────────────────────────────────────────────────────────────
final usersProvider = FutureProvider<List<SbUser>>((ref) async {
  return SupabaseDbSource.getUsers();
});
