import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/sources/remote/supabase_db_source.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../presentation/providers/nav_providers.dart';
import '../../../shared/data/features_catalog.dart';
import '../../../shared/data/timetable_data.dart' show getSubjectMeta;
import '../../../shared/pages/settings_page.dart';
import '../../../shared/widgets/plan_gate.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/surface.dart';
import 'primary_student_home.dart' show PrimaryDashboard;
import 'pages/attendance_page.dart';
import 'pages/cahier_liaison_page.dart';
import 'pages/carte_etudiante_page.dart';
import 'pages/courses_page.dart';
import 'pages/grades_page.dart';
import 'pages/inscription_ue_page.dart';
import 'pages/library/library_page.dart';
import 'pages/notifications_page.dart';
import 'pages/releve_ects_page.dart';
import 'pages/schedule_page.dart';
import 'pages/simulateur_moyenne_page.dart';
import 'pages/student_documents_page.dart';
import 'pages/student_payments_page.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _cyan   = Color(0xFF0891B2);
const _violet = Color(0xFF6D28D9);
const _pink   = Color(0xFFDB2777);

const _gatedLibraryPage = PlanGate(
  minPlan: 'pro',
  featureLabel: 'Bibliothèque',
  description: 'Catalogue, manuels et bibliothèque numérique.',
  child: LibraryPage(),
);

// ══════════════════════════════════════════════════════════════════════════════
// Shell navigation
// ══════════════════════════════════════════════════════════════════════════════
class StudentHome extends ConsumerWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(studentSchoolLevelProvider).valueOrNull
        ?? SchoolLevel.lycee;
    return ResponsiveRoleShell(
      role: UserRole.student,
      title: 'Scolaris',
      groups: _groups(level: level),
    );
  }

  List<RoleNavGroup> _groups({required SchoolLevel level}) {
    final isPrimaire = level == SchoolLevel.primaire;
    final isUniv     = level == SchoolLevel.universite ||
                       level == SchoolLevel.master     ||
                       level == SchoolLevel.doctorat;
    final Widget dashboard =
        isPrimaire ? const PrimaryDashboard() : const _StudentDashboard();

    return [
      RoleNavGroup(labelKey: 'sections.setup', entries: [
        RoleNavEntry(icon: Icons.home_rounded, activeIcon: Icons.home_rounded,
            labelKey: 'nav.dashboard', page: dashboard),
        const RoleNavEntry(icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book_rounded,
            labelKey: 'nav.courses', page: CoursesPage()),
      ]),
      RoleNavGroup(labelKey: 'sections.activity', entries: [
        const RoleNavEntry(icon: Icons.grading_outlined,
            activeIcon: Icons.grading_rounded,
            labelKey: 'nav.grades', page: GradesPage()),
        const RoleNavEntry(icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            labelKey: 'nav.schedule', page: SchedulePage()),
        const RoleNavEntry(icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check_rounded,
            labelKey: 'nav.attendance', page: AttendancePage()),
        const RoleNavEntry(icon: Icons.local_library_outlined,
            activeIcon: Icons.local_library_rounded,
            labelKey: 'nav.library', page: _gatedLibraryPage),
      ]),
      if (isPrimaire)
        const RoleNavGroup(labelKey: 'sections.primary_tools', entries: [
          RoleNavEntry(icon: Icons.import_contacts_outlined,
              activeIcon: Icons.import_contacts_rounded,
              labelKey: 'nav.cahier_liaison', page: CahierLiaisonPage()),
        ]),
      if (isUniv)
        const RoleNavGroup(labelKey: 'sections.university', entries: [
          RoleNavEntry(icon: Icons.workspace_premium_outlined,
              activeIcon: Icons.workspace_premium_rounded,
              labelKey: 'nav.releve_ects', page: ReleveEctsPage()),
          RoleNavEntry(icon: Icons.app_registration_outlined,
              activeIcon: Icons.app_registration_rounded,
              labelKey: 'nav.inscription_ue', page: InscriptionUEPage()),
          RoleNavEntry(icon: Icons.credit_card_outlined,
              activeIcon: Icons.credit_card_rounded,
              labelKey: 'nav.carte_etudiante', page: CarteEtudiantePage()),
        ]),
      if (!isPrimaire)
        const RoleNavGroup(labelKey: 'sections.finance', entries: [
          RoleNavEntry(icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              labelKey: 'nav.my_payments', page: StudentPaymentsPage()),
          RoleNavEntry(icon: Icons.folder_outlined,
              activeIcon: Icons.folder_rounded,
              labelKey: 'nav.documents', page: StudentDocumentsPage()),
        ]),
      RoleNavGroup(labelKey: 'sections.account', entries: [
        const RoleNavEntry(icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications_rounded,
            labelKey: 'nav.notifications', page: NotificationsPage()),
        const RoleNavEntry(icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            labelKey: 'nav.settings', page: SettingsPage()),
      ]),
    ];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Background subtle pattern painter
// ══════════════════════════════════════════════════════════════════════════════
class _SubtleGridPainter extends CustomPainter {
  final Color color;
  const _SubtleGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // Points aux intersections
    final dot = Paint()..color = color.withOpacity(1.6 * color.opacity);
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleGridPainter old) => old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// Dashboard lycée
// ══════════════════════════════════════════════════════════════════════════════
class _StudentDashboard extends ConsumerStatefulWidget {
  const _StudentDashboard();
  @override
  ConsumerState<_StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<_StudentDashboard> {
  bool _refreshing = false;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  void _nav(String key) =>
      ref.read(navIntentProvider.notifier).state = key;
  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      ref.invalidate(myGradesProvider);
      ref.invalidate(myAbsencesProvider);
      ref.invalidate(myStudentProfileProvider);
      ref.invalidate(myAssignmentsProvider);
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final user    = ref.watch(authSessionProvider);
    final name    = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);

    final level   = ref.watch(studentSchoolLevelProvider).valueOrNull ?? SchoolLevel.lycee;
    final profile = ref.watch(myStudentProfileProvider).valueOrNull;

    final gradesAsync     = ref.watch(myGradesProvider);
    final grades          = gradesAsync.valueOrNull ?? const <SbGrade>[];
    final absences        = ref.watch(myAbsencesProvider).valueOrNull ?? const <SbAbsence>[];
    final assignmentsAsync = ref.watch(myAssignmentsProvider);
    final assignments     = assignmentsAsync.valueOrNull ?? const <SbAssignment>[];

    final classId = profile?.classId;
    final scheduleAsync = (classId != null && classId.isNotEmpty)
        ? ref.watch(schedulesForClassProvider(classId))
        : const AsyncValue<List<SbSchedule>>.data([]);
    final schedules = scheduleAsync.valueOrNull ?? const <SbSchedule>[];

    final loading = gradesAsync.isLoading || scheduleAsync.isLoading;

    final fmt      = ref.watch(studentFormatProvider);
    final k        = fmt.maxScore / 20;
    final isLetter = fmt.gradingScale == 'letter';

    final avg20 = grades.isEmpty ? null
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;
    final avgScore  = avg20 == null ? null : avg20 * k;
    final avgRatio  = avg20 == null ? null : (avg20 / 20).clamp(0.0, 1.0);
    final avgText   = avg20 == null ? null
        : isLetter ? fmt.grade(avgScore) : avgScore!.toStringAsFixed(1);
    final unit = isLetter ? '' : '/${fmt.maxScore.toStringAsFixed(0)}';

    final todayDay = DateTime.now().weekday;
    final edt = (schedules.where((s) => s.dayOfWeek == todayDay).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime)))
        .map((s) => (
              h: s.startTime, sub: s.subjectName ?? 'Cours',
              room: s.room ?? '',
              c: getSubjectMeta(s.subjectName ?? '').color,
            ))
        .toList();

    final graded = ([...grades]..sort((a, b) =>
        (a.gradedAt ?? DateTime(2000)).compareTo(b.gradedAt ?? DateTime(2000))));

    final recent = ([...grades]..sort((a, b) =>
            (b.gradedAt ?? DateTime(2000)).compareTo(a.gradedAt ?? DateTime(2000))))
        .take(4).toList();

    // Bar chart : moyennes par matière
    final bySubject = <String, List<double>>{};
    for (final g in grades) {
      (bySubject[g.subjectName ?? '—'] ??= []).add(g.outOf20 * k);
    }
    final chartData = (bySubject.entries
        .map((e) => (
              name: e.key,
              avg: e.value.reduce((a, b) => a + b) / e.value.length,
              color: getSubjectMeta(e.key).color,
            ))
        .toList()
      ..sort((a, b) => b.avg.compareTo(a.avg)))
        .take(7).toList();

    // Devoirs à venir (dans les 7 prochains jours)
    final now = DateTime.now();
    final upcomingDue = assignments
        .where((a) => a.deadline.isAfter(now) &&
            a.deadline.isBefore(now.add(const Duration(days: 7))))
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    final shimmer = ShimmerEffect(
      baseColor: cs.surfaceContainer,
      highlightColor: cs.surface,
      duration: const Duration(milliseconds: 1300),
    );

    // Couleur pattern bg
    final patternColor = isDark
        ? Colors.white.withOpacity(.025)
        : Colors.black.withOpacity(.028);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _terra,
      backgroundColor: cs.surface,
      displacement: 40,
      strokeWidth: 2.5,
      child: CustomPaint(
        painter: _SubtleGridPainter(patternColor),
        child: Container(
          color: Colors.transparent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: LayoutBuilder(builder: (_, constraints) {
              final w      = constraints.maxWidth;
              final isWide = w > 860;
              final isMed  = w > 540;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── 1. Hero — full width toujours ─────────────────────────
                  _HeroBanner(
                    greeting: _greeting, name: name, initials: initials,
                    loading: loading, classLabel: profile?.classe,
                    levelLabel: level.label,
                    avg20: avg20, unit: unit, avgText: avgText,
                    grades: grades.length, absences: absences.length,
                    onGrades: () => _nav('nav.grades'),
                    onAttendance: () => _nav('nav.attendance'),
                  ),
                  const SizedBox(height: 14),

                  // ── 2. Bannière paiement ──────────────────────────────────
                  _PaymentBanner(onTap: () => _nav('nav.my_payments')),

                  // ── 3. Bento row : Moyenne + EDT du jour ──────────────────
                  if (isWide)
                    _BentoRow(gap: 14, children: [
                      _BentoCell(flex: 2, child: _MoyenneCard(
                        loading: loading, shimmer: shimmer,
                        avgText: avgText, unit: unit,
                        avgRatio: avgRatio ?? 0,
                        onTap: () => _nav('nav.grades'),
                      )),
                      _BentoCell(flex: 3, child: _EdtCard(
                        edt: loading ? _edtSkeleton : edt,
                        loading: loading, shimmer: shimmer,
                        onMore: () => _nav('nav.schedule'),
                      )),
                    ])
                  else ...[
                    _QuickStatRow(
                      loading: loading, shimmer: shimmer,
                      avgText: avgText, unit: unit,
                      absences: absences.length, notes: grades.length,
                      onMoyenne: () => _nav('nav.grades'),
                      onAbsences: () => _nav('nav.attendance'),
                      onNotes: () => _nav('nav.grades'),
                    ),
                    const SizedBox(height: 14),
                    _EdtCard(
                      edt: loading ? _edtSkeleton : edt,
                      loading: loading, shimmer: shimmer,
                      onMore: () => _nav('nav.schedule'),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ── 4. Bento row : Bar chart + Stats grid ─────────────────
                  if (isWide)
                    _BentoRow(gap: 14, children: [
                      _BentoCell(flex: 3, child: _SubjectBarChartCard(
                        loading: loading, shimmer: shimmer,
                        chartData: loading ? _skeletonChart : chartData,
                        maxScore: fmt.maxScore,
                      )),
                      _BentoCell(flex: 2, child: _StatsColumn(
                        loading: loading, shimmer: shimmer,
                        grades: loading ? _skeletonGrades : grades,
                        graded: loading ? _skeletonGrades : graded,
                        absences: absences.length,
                        maxScore: fmt.maxScore, k: k,
                        onGrades: () => _nav('nav.grades'),
                        onAttendance: () => _nav('nav.attendance'),
                      )),
                    ])
                  else ...[
                    _DashSectionHeader(icon: Icons.bar_chart_rounded,
                        title: 'Notes par matière', accentColor: _cyan),
                    const SizedBox(height: 10),
                    _SubjectBarChartCard(
                      loading: loading, shimmer: shimmer,
                      chartData: loading ? _skeletonChart : chartData,
                      maxScore: fmt.maxScore,
                    ),
                    const SizedBox(height: 14),
                    _DashSectionHeader(icon: Icons.insights_rounded,
                        title: 'Statistiques', accentColor: _violet),
                    const SizedBox(height: 10),
                    _StatsColumn(
                      loading: loading, shimmer: shimmer,
                      grades: loading ? _skeletonGrades : grades,
                      graded: loading ? _skeletonGrades : graded,
                      absences: absences.length,
                      maxScore: fmt.maxScore, k: k,
                      onGrades: () => _nav('nav.grades'),
                      onAttendance: () => _nav('nav.attendance'),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ── 5. Bento row : Devoirs + Dernières notes ──────────────
                  if (isWide)
                    _BentoRow(gap: 14, children: [
                      _BentoCell(flex: 2, child: _DevoirsCard(
                        assignments: upcomingDue,
                        loading: assignmentsAsync.isLoading,
                        shimmer: shimmer,
                        onTap: () => _nav('nav.courses'),
                      )),
                      _BentoCell(flex: 3, child: _RecentNotesCard(
                        notes: loading ? _skeletonGrades : recent,
                        maxScore: fmt.maxScore, k: k,
                        onTap: () => _nav('nav.grades'),
                        loading: loading, shimmer: shimmer,
                      )),
                    ])
                  else ...[
                    _DashSectionHeader(icon: Icons.assignment_rounded,
                        title: 'Devoirs à rendre', accentColor: _pink,
                        action: 'Tous', onAction: () => _nav('nav.courses')),
                    const SizedBox(height: 10),
                    _DevoirsCard(
                      assignments: upcomingDue,
                      loading: assignmentsAsync.isLoading,
                      shimmer: shimmer,
                      onTap: () => _nav('nav.courses'),
                    ),
                    const SizedBox(height: 14),
                    _DashSectionHeader(icon: Icons.grading_rounded,
                        title: 'Dernières notes', accentColor: _gold,
                        action: 'Toutes', onAction: () => _nav('nav.grades')),
                    const SizedBox(height: 10),
                    _RecentNotesCard(
                      notes: loading ? _skeletonGrades : recent,
                      maxScore: fmt.maxScore, k: k,
                      onTap: () => _nav('nav.grades'),
                      loading: loading, shimmer: shimmer,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ── 6. Tendance (line chart, si assez de données) ─────────
                  if (graded.length >= 3) ...[
                    _DashSectionHeader(icon: Icons.trending_up_rounded,
                        title: 'Évolution des notes', accentColor: _green,
                        action: 'Voir tout', onAction: () => _nav('nav.grades')),
                    const SizedBox(height: 10),
                    _TrendLineCard(
                      graded: loading ? _skeletonGrades : graded,
                      maxScore: fmt.maxScore, k: k,
                      loading: loading, shimmer: shimmer,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── 7. Accès rapide — grille adaptative ───────────────────
                  _DashSectionHeader(icon: Icons.apps_rounded,
                      title: 'Accès rapide', accentColor: _terra),
                  const SizedBox(height: 10),
                  _ShortcutsGrid(
                    isWide: isWide, isMed: isMed,
                    onTap: {
                      'notes':         () => _nav('nav.grades'),
                      'edt':           () => _nav('nav.schedule'),
                      'presences':     () => _nav('nav.attendance'),
                      'cours':         () => _nav('nav.courses'),
                      'paiements':     () => _nav('nav.my_payments'),
                      'bibliotheque':  () => _push(_gatedLibraryPage),
                      'notifications': () => _nav('nav.notifications'),
                      'simulateur':    () => _push(const SimulateurMoyennePage()),
                      'documents':     () => _push(const StudentDocumentsPage()),
                    },
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  static const _edtSkeleton = [
    (h: '08:00', sub: 'Mathématiques', room: 'A1', c: _terra),
    (h: '10:00', sub: 'Français',      room: 'B2', c: _gold),
    (h: '14:00', sub: 'Sciences',      room: 'C3', c: _green),
  ];

  static final _skeletonGrades = [
    SbGrade(id: '1', studentId: '', subjectName: 'Mathématiques', score: 15, maxScore: 20),
    SbGrade(id: '2', studentId: '', subjectName: 'Français',      score: 13, maxScore: 20),
    SbGrade(id: '3', studentId: '', subjectName: 'Sciences',      score: 16, maxScore: 20),
    SbGrade(id: '4', studentId: '', subjectName: 'Histoire',      score: 12, maxScore: 20),
  ];

  static final _skeletonChart = [
    (name: 'Maths',    avg: 14.0, color: _terra),
    (name: 'Français', avg: 12.0, color: _gold),
    (name: 'Sciences', avg: 15.0, color: _green),
    (name: 'Histoire', avg: 11.0, color: _cyan),
  ];

  static String _initials(String name) {
    final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return 'E';
    if (p.length == 1) return p[0][0].toUpperCase();
    return (p[0][0] + p[1][0]).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bento helpers
// ══════════════════════════════════════════════════════════════════════════════
class _BentoRow extends StatelessWidget {
  final List<_BentoCell> children;
  final double gap;
  const _BentoRow({required this.children, this.gap = 14});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < children.length; i++) ...[
        Expanded(flex: children[i].flex, child: children[i].child),
        if (i < children.length - 1) SizedBox(width: gap),
      ],
    ],
  );
}

class _BentoCell {
  final int flex; final Widget child;
  const _BentoCell({required this.flex, required this.child});
}

// ══════════════════════════════════════════════════════════════════════════════
// Section header
// ══════════════════════════════════════════════════════════════════════════════
class _DashSectionHeader extends StatelessWidget {
  final IconData icon; final String title; final Color accentColor;
  final String? action; final VoidCallback? onAction;
  const _DashSectionHeader({
    required this.icon, required this.title, required this.accentColor,
    this.action, this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(.22)),
        ),
        child: Icon(icon, color: accentColor, size: 16)),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: TextStyle(
          fontSize: 14.5, color: cs.onSurface,
          fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (action != null)
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(.08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accentColor.withOpacity(.18)),
              ),
              child: Text(action!, style: TextStyle(
                  color: accentColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hero Banner — FULL WIDTH avec stats inline
// ══════════════════════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  final String greeting, name, initials;
  final bool loading;
  final String? classLabel, levelLabel, avgText, unit;
  final double? avg20;
  final int grades, absences;
  final VoidCallback onGrades, onAttendance;

  const _HeroBanner({
    required this.greeting, required this.name, required this.initials,
    required this.loading, this.classLabel, this.levelLabel,
    this.avgText, this.unit, this.avg20,
    required this.grades, required this.absences,
    required this.onGrades, required this.onAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = avg20 == null ? 0.0 : (avg20! / 20).clamp(0.0, 1.0);
    final rankColor = ratio >= 0.7 ? _green : ratio >= 0.5 ? _gold : _terra;

    // Fond : dégradé professionnel sombre
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F0500), Color(0xFF2A0D00), Color(0xFF5C1A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(
          color: const Color(0xFF5C1A00).withOpacity(.35),
          blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -4,
        )],
      ),
      child: Stack(children: [
        // Cercles décoratifs flottants
        Positioned(right: -20, top: -30, child: Container(width: 130, height: 130,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(.03)))),
        Positioned(right: 80, bottom: -25, child: Container(width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _gold.withOpacity(.05)))),
        Positioned(left: -10, bottom: -20, child: Container(width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _orange.withOpacity(.04)))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ligne 1 : avatar + nom + niveau
          Row(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rankColor.withOpacity(.6), rankColor.withOpacity(.3)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.35), width: 2),
              ),
              child: Center(child: Text(initials, style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting, style: TextStyle(
                  color: Colors.white.withOpacity(.55), fontSize: 12, height: 1)),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (classLabel?.isNotEmpty == true || levelLabel != null) ...[
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (classLabel?.isNotEmpty == true)
                    _HeroBadge(label: classLabel!, color: _gold),
                  if (levelLabel != null)
                    _HeroBadge(label: levelLabel!, color: Colors.white.withOpacity(.55)),
                ]),
              ],
            ])),
            // Indicateur circulaire de la moyenne
            if (!loading && avg20 != null)
              SizedBox(width: 52, height: 52,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(width: 52, height: 52,
                    child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withOpacity(.12),
                      valueColor: AlwaysStoppedAnimation(rankColor),
                    )),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(avgText ?? '—', style: TextStyle(
                        color: rankColor, fontSize: 13,
                        fontWeight: FontWeight.w900, height: 1)),
                    Text(unit ?? '', style: const TextStyle(
                        color: Colors.white54, fontSize: 8)),
                  ]),
                ])),
          ]),
          const SizedBox(height: 16),
          // Ligne 2 : 3 mini stats en bas du hero
          Row(children: [
            Expanded(child: _HeroStatChip(
              icon: Icons.star_rounded, color: rankColor,
              label: avg20 == null ? '—' : (avgText ?? '—'),
              sub: avg20 == null ? 'Moyenne' : 'Moyenne$unit',
              onTap: onGrades)),
            const SizedBox(width: 8),
            Expanded(child: _HeroStatChip(
              icon: Icons.grading_rounded, color: _orange,
              label: '$grades', sub: 'Notes reçues', onTap: onGrades)),
            const SizedBox(width: 8),
            Expanded(child: _HeroStatChip(
              icon: Icons.event_busy_rounded,
              color: absences == 0 ? _green : _orange,
              label: '$absences',
              sub: absences > 1 ? 'Absences' : 'Absence',
              onTap: onAttendance)),
          ]),
        ]),
      ]),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label; final Color color;
  const _HeroBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(.35)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w700)));
}

class _HeroStatChip extends StatelessWidget {
  final IconData icon; final Color color;
  final String label, sub; final VoidCallback onTap;
  const _HeroStatChip({required this.icon, required this.color,
      required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w900,
                height: 1.1),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(sub, style: TextStyle(
                color: Colors.white.withOpacity(.45), fontSize: 9,
                fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Carte Moyenne (bento wide)
// ══════════════════════════════════════════════════════════════════════════════
class _MoyenneCard extends StatelessWidget {
  final bool loading; final ShimmerEffect shimmer;
  final String? avgText, unit;
  final double avgRatio;
  final VoidCallback onTap;

  const _MoyenneCard({required this.loading, required this.shimmer,
      required this.avgText, required this.unit,
      required this.avgRatio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = avgRatio.clamp(0.0, 1.0);
    final rc = ratio >= 0.7 ? _green : ratio >= 0.5 ? _gold : _terra;
    final mention = ratio >= 0.8 ? 'Très bien' : ratio >= 0.7 ? 'Bien'
        : ratio >= 0.5 ? 'Passable' : 'À améliorer';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              rc.withOpacity(.15), cs.surfaceContainer,
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rc.withOpacity(.3)),
            boxShadow: [BoxShadow(color: rc.withOpacity(.10),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Moyenne générale', style: TextStyle(
                color: cs.onSurface.withOpacity(.55),
                fontSize: 11.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(width: 100, height: 100,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 100, height: 100,
                  child: CircularProgressIndicator(
                    value: loading ? 0.0 : ratio, strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: rc.withOpacity(.12),
                    valueColor: AlwaysStoppedAnimation(rc))),
                Skeletonizer(enabled: loading, effect: shimmer,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(loading ? '——' : (avgText ?? '—'), style: TextStyle(
                        color: rc, fontSize: 26, fontWeight: FontWeight.w900,
                        height: 1.1)),
                    Text(unit ?? '', style: TextStyle(
                        color: cs.onSurface.withOpacity(.45), fontSize: 10)),
                  ])),
              ])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: rc.withOpacity(.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: rc.withOpacity(.25)),
              ),
              child: Text(mention, style: TextStyle(
                  color: rc, fontSize: 12, fontWeight: FontWeight.w800))),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EDT Card — TOUJOURS VISIBLE, état vide géré proprement
// ══════════════════════════════════════════════════════════════════════════════
class _EdtCard extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> edt;
  final bool loading; final ShimmerEffect shimmer;
  final VoidCallback onMore;
  const _EdtCard({required this.edt, required this.loading,
      required this.shimmer, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              color: _terra.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _terra.withOpacity(.22)),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: _terra, size: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Emploi du temps", style: TextStyle(
                color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(_dayLabel(), style: TextStyle(
                color: cs.onSurface.withOpacity(.45),
                fontSize: 10, fontWeight: FontWeight.w600)),
          ])),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onMore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _terra.withOpacity(.08),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _terra.withOpacity(.18)),
                ),
                child: const Text('Voir tout', style: TextStyle(
                    color: _terra, fontSize: 11, fontWeight: FontWeight.w700))),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Corps — toujours présent
        if (loading)
          Skeletonizer(enabled: true, effect: shimmer,
              child: _EdtTimeline(slots: [
                (h: '08:00', sub: 'Mathématiques', room: 'A1', c: _terra),
                (h: '10:00', sub: 'Français', room: 'B2', c: _gold),
              ]))
        else if (edt.isEmpty)
          _EdtEmpty(onMore: onMore)
        else
          _EdtTimeline(slots: edt),
      ]),
    );
  }

  static String _dayLabel() {
    const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi',
                   'Vendredi', 'Samedi', 'Dimanche'];
    const mois  = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
                   'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    final d = DateTime.now();
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
  }
}

class _EdtEmpty extends StatelessWidget {
  final VoidCallback onMore;
  const _EdtEmpty({required this.onMore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: _terra.withOpacity(.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _terra.withOpacity(.12),
            style: BorderStyle.solid),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: _terra.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.event_available_rounded,
              color: _terra, size: 22)),
        const SizedBox(height: 10),
        Text("Pas de cours aujourd'hui", style: TextStyle(
            color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text("Profite de ta journée libre 🎉", style: TextStyle(
            color: cs.onSurface.withOpacity(.45),
            fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onMore,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _terra.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _terra.withOpacity(.25)),
              ),
              child: const Text('Voir la semaine', style: TextStyle(
                  color: _terra, fontSize: 11, fontWeight: FontWeight.w700))),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EDT Timeline
// ══════════════════════════════════════════════════════════════════════════════
class _EdtTimeline extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> slots;
  const _EdtTimeline({required this.slots});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      const gap   = 10.0;
      final cardW = math.min(
          (constraints.maxWidth - gap * 2) / 2.6,
          180.0);
      const cardH = 140.0;

      return SizedBox(
        height: cardH,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: slots.length,
          separatorBuilder: (_, __) => const SizedBox(width: gap),
          itemBuilder: (_, i) {
            final s = slots[i];
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: cardW,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [s.c, s.c.withOpacity(.70)]),
                  boxShadow: [BoxShadow(color: s.c.withOpacity(.25),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Stack(children: [
                  Positioned(right: -12, top: -12, child: Container(
                      width: 62, height: 62, decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(.06)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Container(width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.20),
                            borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.school_rounded,
                              size: 15, color: Colors.white)),
                        if (i == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.22),
                              borderRadius: BorderRadius.circular(6)),
                            child: const Text('En cours',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 8, fontWeight: FontWeight.w900))),
                      ]),
                      const Spacer(),
                      Text(s.sub, style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w900, height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.access_time_rounded,
                            size: 10, color: Color(0xCCFFFFFF)),
                        const SizedBox(width: 3),
                        Text(s.h, style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 10, fontWeight: FontWeight.w700)),
                        if (s.room.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.room_outlined,
                              size: 10, color: Color(0xAAFFFFFF)),
                          const SizedBox(width: 2),
                          Flexible(child: Text(s.room, style: const TextStyle(
                              color: Color(0xAAFFFFFF), fontSize: 9),
                              overflow: TextOverflow.ellipsis)),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick stat row (mobile)
// ══════════════════════════════════════════════════════════════════════════════
class _QuickStatRow extends StatelessWidget {
  final bool loading; final ShimmerEffect shimmer;
  final String? avgText, unit;
  final int absences, notes;
  final VoidCallback? onMoyenne, onAbsences, onNotes;

  const _QuickStatRow({required this.loading, required this.shimmer,
      required this.avgText, required this.unit,
      required this.absences, required this.notes,
      this.onMoyenne, this.onAbsences, this.onNotes});

  @override
  Widget build(BuildContext context) {
    final data = [
      (icon: Icons.star_rounded, label: 'Moyenne',
       val: avgText ?? '—', sub: unit ?? '', c: _gold, onTap: onMoyenne),
      (icon: Icons.event_busy_rounded, label: 'Absences',
       val: '$absences', sub: absences > 1 ? ' j' : ' j',
       c: absences == 0 ? _green : _terra, onTap: onAbsences),
      (icon: Icons.grading_rounded, label: 'Notes',
       val: '$notes', sub: '', c: _orange, onTap: onNotes),
    ];
    return Row(children: [
      for (int i = 0; i < data.length; i++) ...[
        Expanded(child: _QuickPill(d: data[i], loading: loading, shimmer: shimmer)),
        if (i < data.length - 1) const SizedBox(width: 8),
      ],
    ]);
  }
}

class _QuickPill extends StatelessWidget {
  final ({IconData icon, String label, String val, String sub, Color c, VoidCallback? onTap}) d;
  final bool loading; final ShimmerEffect shimmer;
  const _QuickPill({required this.d, required this.loading, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: d.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: d.c.withOpacity(.22)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(width: 28, height: 28,
                decoration: BoxDecoration(color: d.c.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(d.icon, color: d.c, size: 14)),
              Icon(Icons.chevron_right_rounded,
                  size: 13, color: cs.onSurface.withOpacity(.22)),
            ]),
            const SizedBox(height: 8),
            Text(d.label, style: TextStyle(
                color: cs.onSurface.withOpacity(.5),
                fontSize: 9.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Skeletonizer(enabled: loading, effect: shimmer,
              child: RichText(text: TextSpan(children: [
                TextSpan(text: loading ? '——' : d.val, style: TextStyle(
                    color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
                TextSpan(text: d.sub, style: TextStyle(
                    color: cs.onSurface.withOpacity(.45), fontSize: 10)),
              ]))),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Stats column (bento wide)
// ══════════════════════════════════════════════════════════════════════════════
class _StatsColumn extends StatelessWidget {
  final bool loading; final ShimmerEffect shimmer;
  final List<SbGrade> grades, graded;
  final int absences;
  final double maxScore, k;
  final VoidCallback onGrades, onAttendance;

  const _StatsColumn({required this.loading, required this.shimmer,
      required this.grades, required this.graded,
      required this.absences, required this.maxScore, required this.k,
      required this.onGrades, required this.onAttendance});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEmpty = grades.isEmpty;
    final avg20 = isEmpty ? 0.0
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;

    // Tendance
    String tLabel = '—'; Color tColor = _gold; IconData tIcon = Icons.trending_flat_rounded;
    if (graded.length >= 4) {
      final half = graded.length ~/ 2;
      final rAvg = graded.sublist(graded.length - half)
          .fold<double>(0, (s, g) => s + g.outOf20) / half;
      final oAvg = graded.sublist(0, half)
          .fold<double>(0, (s, g) => s + g.outOf20) / half;
      final diff = rAvg - oAvg;
      if (diff > 0.3) { tLabel = '+${(diff*k).toStringAsFixed(1)} pts'; tColor = _green; tIcon = Icons.trending_up_rounded; }
      else if (diff < -0.3) { tLabel = '${(diff*k).toStringAsFixed(1)} pts'; tColor = _terra; tIcon = Icons.trending_down_rounded; }
      else { tLabel = 'Stable'; }
    }

    final items = [
      _StatTileData(icon: Icons.star_rounded, color: _gold,
        label: 'Moyenne générale',
        value: isEmpty ? '—' : '${(avg20*k).toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
        onTap: onGrades),
      _StatTileData(icon: tIcon, color: tColor, label: 'Tendance',
        value: tLabel, onTap: onGrades),
      _StatTileData(icon: Icons.event_busy_rounded,
        color: absences == 0 ? _green : _orange,
        label: 'Absences', value: '$absences jour${absences > 1 ? "s" : ""}',
        onTap: onAttendance),
      _StatTileData(icon: Icons.grading_rounded, color: _cyan,
        label: 'Notes reçues', value: '${grades.length}', onTap: onGrades),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DashSectionHeader(icon: Icons.insights_rounded,
          title: 'Statistiques', accentColor: _violet),
      const SizedBox(height: 10),
      ...items.map((it) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Skeletonizer(enabled: loading, effect: shimmer,
            child: _StatTile(data: it)),
      )),
    ]);
  }
}

class _StatTileData {
  final IconData icon; final Color color;
  final String label, value; final VoidCallback onTap;
  const _StatTileData({required this.icon, required this.color,
      required this.label, required this.value, required this.onTap});
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              data.color.withOpacity(.09), cs.surfaceContainer,
            ]),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: data.color.withOpacity(.22)),
          ),
          child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: data.color.withOpacity(.16),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(data.icon, color: data.color, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(data.label, style: TextStyle(
                color: cs.onSurface.withOpacity(.58),
                fontSize: 11, fontWeight: FontWeight.w700))),
            Text(data.value, style: TextStyle(
                color: data.color, fontSize: 13, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bar chart — moyennes par matière
// ══════════════════════════════════════════════════════════════════════════════
class _SubjectBarChartCard extends StatelessWidget {
  final bool loading; final ShimmerEffect shimmer;
  final List<({String name, double avg, Color color})> chartData;
  final double maxScore;

  const _SubjectBarChartCard({required this.loading, required this.shimmer,
      required this.chartData, required this.maxScore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(color: _cyan.withOpacity(.12),
                borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.bar_chart_rounded, color: _cyan, size: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text('Moyennes par matière', style: TextStyle(
              color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _cyan.withOpacity(.08),
                borderRadius: BorderRadius.circular(7)),
            child: Text('/${maxScore.toStringAsFixed(0)}',
                style: const TextStyle(color: _cyan,
                    fontSize: 10, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        if (chartData.isEmpty)
          SizedBox(height: 160, child: Center(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart_rounded,
                  color: cs.onSurface.withOpacity(.2), size: 36),
              const SizedBox(height: 8),
              Text('Aucune note pour l\'instant', style: TextStyle(
                  color: cs.onSurface.withOpacity(.4), fontSize: 12)),
            ])))
        else
          Skeletonizer(
            enabled: loading, effect: shimmer,
            child: SizedBox(
              height: 170,
              child: BarChart(BarChartData(
                maxY: maxScore, minY: 0,
                gridData: FlGridData(
                  show: true, horizontalInterval: maxScore / 4,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: cs.outline.withOpacity(.18), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 26,
                    getTitlesWidget: (v, _) {
                      if (v == 0 || v == maxScore / 2 || v == maxScore) {
                        return Text(v.toStringAsFixed(0), style: TextStyle(
                            color: cs.onSurface.withOpacity(.4), fontSize: 9));
                      }
                      return const SizedBox();
                    },
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= chartData.length) return const SizedBox();
                      final n = chartData[i].name;
                      final s = n.length > 5 ? n.substring(0, 4) : n;
                      return Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(s, style: TextStyle(
                            color: cs.onSurface.withOpacity(.5),
                            fontSize: 9, fontWeight: FontWeight.w600)));
                    },
                  )),
                ),
                barGroups: [
                  for (int i = 0; i < chartData.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: chartData[i].avg.clamp(0, maxScore),
                        width: 18, borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        gradient: LinearGradient(
                          colors: [chartData[i].color, chartData[i].color.withOpacity(.5)],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      ),
                    ]),
                ],
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipColor: (_) => cs.surfaceContainerHighest,
                    getTooltipItem: (g, _, r, __) => BarTooltipItem(
                      '${chartData[g.x].name}\n${r.toY.toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
                      TextStyle(color: cs.onSurface, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  ),
                ),
              )),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Devoirs à venir
// ══════════════════════════════════════════════════════════════════════════════
class _DevoirsCard extends StatelessWidget {
  final List<SbAssignment> assignments;
  final bool loading; final ShimmerEffect shimmer;
  final VoidCallback onTap;

  const _DevoirsCard({required this.assignments, required this.loading,
      required this.shimmer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(color: _pink.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _pink.withOpacity(.22))),
            child: const Icon(Icons.assignment_rounded, color: _pink, size: 15)),
          const SizedBox(width: 8),
          Expanded(child: Text('Devoirs à rendre', style: TextStyle(
              color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w800))),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _pink.withOpacity(.08),
                    borderRadius: BorderRadius.circular(7)),
                child: const Text('Voir', style: TextStyle(
                    color: _pink, fontSize: 10, fontWeight: FontWeight.w700))),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (loading)
          ...List.generate(2, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Skeletonizer(enabled: true, effect: shimmer,
              child: _DevoirRow(
                title: 'Exercice de mathématiques',
                subject: 'Mathématiques',
                deadline: DateTime.now().add(const Duration(days: 2)),
                color: _terra)),
          ))
        else if (assignments.isEmpty)
          _NoDevoirs()
        else
          ...assignments.take(3).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DevoirRow(
              title: a.title,
              subject: a.subjectName ?? 'Cours',
              deadline: a.deadline,
              color: getSubjectMeta(a.subjectName ?? '').color,
            ),
          )),
      ]),
    );
  }
}

class _NoDevoirs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_rounded, color: _green, size: 18),
        const SizedBox(width: 8),
        Text('Aucun devoir pour les 7 prochains jours', style: TextStyle(
            color: cs.onSurface.withOpacity(.5),
            fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DevoirRow extends StatelessWidget {
  final String title, subject;
  final DateTime deadline;
  final Color color;
  const _DevoirRow({required this.title, required this.subject,
      required this.deadline, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final now  = DateTime.now();
    final diff = deadline.difference(now).inDays;
    final isUrgent = diff <= 1;
    final urgColor = isUrgent ? _terra : _gold;
    final label = diff == 0 ? "Aujourd'hui" : diff == 1 ? 'Demain' : 'Dans $diff j';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: cs.onSurface,
              fontSize: 11.5, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subject, style: TextStyle(color: cs.onSurface.withOpacity(.45),
              fontSize: 9.5)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: urgColor.withOpacity(.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: urgColor.withOpacity(.25)),
          ),
          child: Text(label, style: TextStyle(
              color: urgColor, fontSize: 9, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dernières notes card
// ══════════════════════════════════════════════════════════════════════════════
class _RecentNotesCard extends StatelessWidget {
  final List<SbGrade> notes;
  final double maxScore, k;
  final VoidCallback onTap;
  final bool loading; final ShimmerEffect shimmer;

  const _RecentNotesCard({required this.notes, required this.maxScore,
      required this.k, required this.onTap,
      required this.loading, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(color: _gold.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _gold.withOpacity(.22))),
            child: const Icon(Icons.grading_rounded, color: _gold, size: 15)),
          const SizedBox(width: 8),
          Expanded(child: Text('Dernières notes', style: TextStyle(
              color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w800))),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _gold.withOpacity(.08),
                    borderRadius: BorderRadius.circular(7)),
                child: const Text('Toutes', style: TextStyle(
                    color: _gold, fontSize: 10, fontWeight: FontWeight.w700))),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (!loading && notes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.grading_rounded,
                  color: cs.onSurface.withOpacity(.2), size: 32),
              const SizedBox(height: 8),
              Text("Aucune note pour l'instant", style: TextStyle(
                  color: cs.onSurface.withOpacity(.4), fontSize: 12)),
            ])),
          )
        else
          ...( loading ? _StudentDashboardState._skeletonGrades : notes).map((g) {
            final pct   = (g.score / g.maxScore).clamp(0.0, 1.0);
            final color = g.outOf20 >= 14 ? _green
                : g.outOf20 >= 10 ? _gold : _terra;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Skeletonizer(
                enabled: loading, effect: shimmer,
                child: _NoteRow(
                  sub: g.subjectName ?? g.title ?? '—',
                  note: g.score * k, max: g.maxScore * k,
                  pct: pct, date: _fmtShort(g.gradedAt),
                  color: color, onTap: onTap),
              ),
            );
          }),
      ]),
    );
  }

  static String _fmtShort(DateTime? d) {
    if (d == null) return '';
    const m = ['janv.','févr.','mars','avr.','mai','juin',
                'juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${m[d.month - 1]}';
  }
}

class _NoteRow extends StatelessWidget {
  final String sub, date;
  final double note, max, pct;
  final Color color; final VoidCallback onTap;
  const _NoteRow({required this.sub, required this.note, required this.max,
      required this.pct, required this.date,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: ScolarisSurface.themedCard(context, radius: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            SizedBox(width: 42, height: 42,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 42, height: 42,
                  child: CircularProgressIndicator(
                    value: pct, strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withOpacity(.12),
                    valueColor: AlwaysStoppedAnimation(color))),
                Text(note.toStringAsFixed(1), style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w900)),
              ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sub, style: TextStyle(color: cs.onSurface,
                  fontSize: 12.5, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 4,
                  backgroundColor: color.withOpacity(.10),
                  valueColor: AlwaysStoppedAnimation(color))),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (pct >= 0.7 ? _green : _terra).withOpacity(.10),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(pct >= 0.7 ? '✓ Bien' : '→ Effort',
                    style: TextStyle(color: pct >= 0.7 ? _green : _terra,
                        fontSize: 8.5, fontWeight: FontWeight.w800))),
              const SizedBox(height: 3),
              Text(date, style: TextStyle(
                  color: cs.onSurface.withOpacity(.4), fontSize: 9.5)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Trend line chart
// ══════════════════════════════════════════════════════════════════════════════
class _TrendLineCard extends StatelessWidget {
  final List<SbGrade> graded;
  final double maxScore, k;
  final bool loading; final ShimmerEffect shimmer;
  const _TrendLineCard({required this.graded, required this.maxScore,
      required this.k, required this.loading, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final pts = graded.take(12).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(.22)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Skeletonizer(
        enabled: loading, effect: shimmer,
        child: SizedBox(
          height: 130,
          child: LineChart(LineChartData(
            minY: 0, maxY: maxScore,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: maxScore / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outline.withOpacity(.15), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 26,
                getTitlesWidget: (v, _) {
                  if (v == 0 || v == maxScore / 2 || v == maxScore) {
                    return Text(v.toStringAsFixed(0), style: TextStyle(
                        color: cs.onSurface.withOpacity(.4), fontSize: 9));
                  }
                  return const SizedBox();
                },
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= pts.length) return const SizedBox();
                  if (i != 0 && i != pts.length - 1) return const SizedBox();
                  final d = pts[i].gradedAt;
                  if (d == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${d.day}/${d.month}', style: TextStyle(
                        color: cs.onSurface.withOpacity(.4), fontSize: 8)));
                },
              )),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipColor: (_) => cs.surfaceContainerHighest,
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${s.y.toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
                  TextStyle(color: _green, fontSize: 11,
                      fontWeight: FontWeight.w700))).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (int i = 0; i < pts.length; i++)
                    FlSpot(i.toDouble(), (pts[i].outOf20 * k).clamp(0, maxScore)),
                ],
                isCurved: true, curveSmoothness: 0.3,
                color: _green, barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 3.5, color: _green, strokeWidth: 2,
                    strokeColor: cs.surfaceContainer)),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [_green.withOpacity(.22), _green.withOpacity(.0)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shortcuts — grille adaptative
// Cartes CARRÉES sur mobile (3 cols, ratio 1:1), grille sur wide
// ══════════════════════════════════════════════════════════════════════════════
class _ShortcutsGrid extends StatelessWidget {
  final bool isWide, isMed;
  final Map<String, VoidCallback> onTap;
  const _ShortcutsGrid({required this.isWide, required this.isMed,
      required this.onTap});

  static const _items = [
    (key: 'notes',        icon: Icons.grading_rounded,                label: 'Notes',        c: _gold),
    (key: 'presences',    icon: Icons.fact_check_rounded,             label: 'Présences',    c: _green),
    (key: 'edt',          icon: Icons.calendar_month_rounded,         label: 'Emploi',       c: _terra),
    (key: 'cours',        icon: Icons.menu_book_rounded,              label: 'Cours',        c: _terra),
    (key: 'paiements',    icon: Icons.account_balance_wallet_rounded, label: 'Paiements',    c: _orange),
    (key: 'bibliotheque', icon: Icons.local_library_rounded,          label: 'Bibliothèque', c: _green),
    (key: 'notifications',icon: Icons.notifications_rounded,          label: 'Alertes',      c: _orange),
    (key: 'simulateur',   icon: Icons.calculate_rounded,              label: 'Simulateur',   c: _gold),
    (key: 'documents',    icon: Icons.folder_rounded,                 label: 'Documents',    c: _cyan),
  ];

  @override
  Widget build(BuildContext context) {
    // Wide : 5 colonnes — grille pleine
    if (isWide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, childAspectRatio: 1.05,
          crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) =>
            _ShortcutCard(item: _items[i], onTap: onTap[_items[i].key]),
      );
    }
    // Medium (tablette) : 4 colonnes
    if (isMed) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 1.0,
          crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) =>
            _ShortcutCard(item: _items[i], onTap: onTap[_items[i].key]),
      );
    }
    // Mobile : 3 colonnes CARRÉES (ratio 1:1 strict)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,  // ← strictement carré
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) =>
          _ShortcutCard(item: _items[i], onTap: onTap[_items[i].key]),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final ({String key, IconData icon, String label, Color c}) item;
  final VoidCallback? onTap;
  const _ShortcutCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.c.withOpacity(.18)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: item.c.withOpacity(.12),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(item.icon, color: item.c, size: 20)),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(item.label,
                style: TextStyle(color: cs.onSurface,
                    fontSize: 10.5, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bannière paiement
// ══════════════════════════════════════════════════════════════════════════════
class _PaymentBanner extends ConsumerWidget {
  final VoidCallback onTap;
  const _PaymentBanner({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(myInvoicesProvider).valueOrNull ?? const <SbInvoice>[];
    final unpaid   = invoices.where((i) => !i.isPaid).toList();
    if (unpaid.isEmpty) return const SizedBox.shrink();

    final hasLate  = unpaid.any((i) => i.isLate);
    final color    = hasLate ? _terra : _orange;
    final totalDue = unpaid.fold<double>(0, (s, i) => s + i.balance);
    final currency = unpaid.first.currency;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(.78)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withOpacity(.28),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.18),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(hasLate ? Icons.warning_rounded
                    : Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hasLate ? 'Paiement en retard' : 'Paiement en attente',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12.5, fontWeight: FontWeight.w800)),
                Text('${totalDue.toStringAsFixed(0)} $currency à régler',
                    style: TextStyle(color: Colors.white.withOpacity(.80),
                        fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.22),
                    borderRadius: BorderRadius.circular(9)),
                child: const Text('Voir', style: TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      ),
    );
  }
}
