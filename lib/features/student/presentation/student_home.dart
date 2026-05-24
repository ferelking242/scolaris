import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/skeleton.dart';
import 'pages/bulletin_page.dart';
import 'pages/courses_page.dart';
import 'pages/grades_page.dart';
import 'pages/homework_student_page.dart';
import 'pages/schedule_page.dart';

const _terra   = ScolarisPalette.terracotta;
const _orange  = ScolarisPalette.orange;
const _gold    = ScolarisPalette.gold;
const _green   = ScolarisPalette.forestGreen;
const _cream   = ScolarisPalette.cream;
const _ink     = Color(0xFF1A0A00);
const _muted   = Color(0xFF7A5C44);
const _white   = Colors.white;
const _bg      = Color(0xFFF5EEE6);

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.student,
      title: 'Scolaris',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(icon: Icons.home_rounded, activeIcon: Icons.home_rounded,
              labelKey: 'nav.dashboard', page: _StudentDashboard()),
          RoleNavEntry(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded,
              labelKey: 'nav.courses', page: CoursesPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(icon: Icons.grading_outlined, activeIcon: Icons.grading_rounded,
              labelKey: 'nav.grades', page: GradesPage()),
          RoleNavEntry(icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              labelKey: 'nav.schedule', page: SchedulePage()),
          RoleNavEntry(icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              labelKey: 'nav.homework', page: HomeworkStudentPage()),
          RoleNavEntry(icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              labelKey: 'nav.bulletin', page: BulletinPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(icon: Icons.chat_outlined, activeIcon: Icons.chat_rounded,
              labelKey: 'nav.messages', page: MessagingPage()),
          RoleNavEntry(icon: Icons.apps_outlined, activeIcon: Icons.apps_rounded,
              labelKey: 'nav.features', page: FeaturesHubPage()),
        ]),
      ],
    );
  }
}

class _StudentDashboard extends ConsumerStatefulWidget {
  const _StudentDashboard();
  @override
  ConsumerState<_StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<_StudentDashboard> {
  bool _loading = true;

  // Simulated async data
  int? _daysLeft;
  double? _avgGrade;
  int? _attendancePct;
  int? _upcomingTasks;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _loading      = false;
          _daysLeft     = 47;
          _avgGrade     = 15.4;
          _attendancePct = 96;
          _upcomingTasks = 3;
        });
      }
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider);
    final firstName = user?.fullName.split(' ').first ?? 'Étudiant';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting banner ─────────────────────────────────────
            _GreetingBanner(
              greeting: _greeting,
              name: firstName,
              subtitle: _loading
                  ? null
                  : 'Il vous reste $_daysLeft jours avant les examens',
              daysLeft: _daysLeft,
              loading: _loading,
            ),
            const SizedBox(height: 20),

            // ── Stats row ───────────────────────────────────────────
            Row(children: [
              Expanded(child: _StatPill(
                icon: Icons.grading_rounded,
                label: 'Moyenne',
                value: _loading ? null : '${_avgGrade!.toStringAsFixed(1)}/20',
                color: _gold,
                loading: _loading,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatPill(
                icon: Icons.check_circle_outline_rounded,
                label: 'Présence',
                value: _loading ? null : '$_attendancePct%',
                color: _green,
                loading: _loading,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatPill(
                icon: Icons.assignment_late_outlined,
                label: 'Tâches',
                value: _loading ? null : '$_upcomingTasks',
                color: _terra,
                loading: _loading,
              )),
            ]),
            const SizedBox(height: 22),

            // ── Today's schedule ─────────────────────────────────────
            _SectionHeader(title: 'Emploi du temps du jour',
                action: 'Voir tout', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading) ...[
              const SkeletonListRow(),
              const SizedBox(height: 8),
              const SkeletonListRow(),
              const SizedBox(height: 8),
              const SkeletonListRow(),
            ] else ...[
              _ScheduleCard(time: '08:00', subject: 'Mathématiques',
                  room: 'Salle A12', teacher: 'M. Diallo', isNext: true, color: _terra),
              const SizedBox(height: 8),
              _ScheduleCard(time: '10:00', subject: 'Français',
                  room: 'Salle B04', teacher: 'Mme Ndiaye', isNext: false, color: _gold),
              const SizedBox(height: 8),
              _ScheduleCard(time: '14:00', subject: 'Sciences',
                  room: 'Labo 1', teacher: 'M. Ouédraogo', isNext: false, color: _green),
            ],
            const SizedBox(height: 22),

            // ── Recent grades ──────────────────────────────────────
            _SectionHeader(title: 'Dernières notes',
                action: 'Voir tout', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading) ...[
              const SkeletonListRow(),
              const SizedBox(height: 8),
              const SkeletonListRow(),
            ] else ...[
              _GradeRow(subject: 'Mathématiques', grade: 17.5, max: 20,
                  date: '28 Avr', color: _green),
              const SizedBox(height: 8),
              _GradeRow(subject: 'Physique', grade: 13.0, max: 20,
                  date: '25 Avr', color: _gold),
              const SizedBox(height: 8),
              _GradeRow(subject: 'Histoire', grade: 15.5, max: 20,
                  date: '22 Avr', color: _terra),
            ],
            const SizedBox(height: 22),

            // ── Motivational banner ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3E1A00), _terra],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('"Le savoir est une lumière\nque nul ne peut éteindre."',
                        style: TextStyle(color: _white, fontSize: 13, height: 1.5,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text('— Proverbe africain',
                        style: TextStyle(color: _gold.withOpacity(.9),
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.lightbulb_outline_rounded, color: _gold.withOpacity(.8), size: 36),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Greeting Banner ────────────────────────────────────────────────────────
class _GreetingBanner extends StatelessWidget {
  final String greeting;
  final String name;
  final String? subtitle;
  final int? daysLeft;
  final bool loading;
  const _GreetingBanner({
    required this.greeting, required this.name,
    required this.subtitle, required this.daysLeft, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x12000000),
            blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greeting, $name 👋',
              style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (loading)
            Row(children: [
              const Text('Il vous reste ', style: TextStyle(color: _muted, fontSize: 13)),
              const SkeletonBox(width: 24, height: 14, radius: 4),
              const Text(' jours avant les examens',
                  style: TextStyle(color: _muted, fontSize: 13)),
            ])
          else
            RichText(text: TextSpan(
              style: const TextStyle(color: _muted, fontSize: 13),
              children: [
                const TextSpan(text: 'Il vous reste '),
                TextSpan(text: '$daysLeft',
                    style: const TextStyle(color: _terra,
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const TextSpan(text: ' jours avant les examens'),
              ],
            )),
        ])),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_terra, _orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school_rounded, color: _white, size: 28),
        ),
      ]),
    );
  }
}

// ── Stat Pill ──────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color color;
  final bool loading;
  const _StatPill({required this.icon, required this.label,
      required this.value, required this.color, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0C000000),
            blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _muted, fontSize: 10,
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        if (loading)
          const SkeletonBox(width: 40, height: 16, radius: 4)
        else
          Text(value!, style: TextStyle(color: color, fontSize: 15,
              fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.action,
      required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 15,
          fontWeight: FontWeight.w700)),
      const Spacer(),
      GestureDetector(
        onTap: onAction,
        child: Text(action, style: const TextStyle(color: _terra, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

// ── Schedule Card ──────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final String time;
  final String subject;
  final String room;
  final String teacher;
  final bool isNext;
  final Color color;
  const _ScheduleCard({required this.time, required this.subject,
      required this.room, required this.teacher,
      required this.isNext, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? color.withOpacity(.08) : _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isNext ? color.withOpacity(.3) : const Color(0xFFEEE5D8)),
      ),
      child: Row(children: [
        Container(
          width: 4, height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(subject, style: const TextStyle(color: _ink, fontSize: 13,
                  fontWeight: FontWeight.w700)),
              if (isNext) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Prochain', style: TextStyle(color: _white,
                      fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text('$teacher · $room',
                style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        )),
        Text(time, style: TextStyle(color: color, fontSize: 13,
            fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Grade Row ──────────────────────────────────────────────────────────────
class _GradeRow extends StatelessWidget {
  final String subject;
  final double grade;
  final double max;
  final String date;
  final Color color;
  const _GradeRow({required this.subject, required this.grade,
      required this.max, required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = grade / max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEE5D8)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text('${grade.toStringAsFixed(0)}',
                style: TextStyle(color: color, fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject, style: const TextStyle(color: _ink, fontSize: 13,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: color.withOpacity(.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        )),
        const SizedBox(width: 12),
        Text(date, style: const TextStyle(color: _muted, fontSize: 11)),
      ]),
    );
  }
}
