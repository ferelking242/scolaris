/// Lightweight domain entities used by the MVP shells.
/// These are kept pure (no Flutter / Supabase imports).

class SchoolClass {
  final String id;
  final String name;
  final int studentCount;
  const SchoolClass({required this.id, required this.name, required this.studentCount});
}

class Grade {
  final String id;
  final String subject;
  final double score;
  final double max;
  const Grade({
    required this.id,
    required this.subject,
    required this.score,
    required this.max,
  });

  double get ratio => max == 0 ? 0 : score / max;
}

class AttendanceRecord {
  final String id;
  final DateTime date;
  final bool present;
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.present,
  });
}

class Payment {
  final String id;
  final String label;
  final double amount;
  final DateTime due;
  final bool paid;
  const Payment({
    required this.id,
    required this.label,
    required this.amount,
    required this.due,
    required this.paid,
  });
}

class Child {
  final String id;
  final String name;
  final String className;
  final double averageGrade;
  final double attendanceRate;
  const Child({
    required this.id,
    required this.name,
    required this.className,
    required this.averageGrade,
    required this.attendanceRate,
  });
}
