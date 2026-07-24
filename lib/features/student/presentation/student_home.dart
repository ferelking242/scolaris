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
// Dashboard lycée — bento grid responsive
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
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final user    = ref.watch(authSessionProvider);
    final name    = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);

    final level   = ref.watch(studentSchoolLevelProvider).valueOrNull ?? SchoolLevel.lycee;
    final profile = ref.watch(myStudentProfileProvider).valueOrNull;

    final gradesAsync = ref.watch(myGradesProvider);
    final grades      = gradesAsync.valueOrNull ?? const <SbGrade>[];
    final absences    = ref.watch(myAbsencesProvider).valueOrNull ?? const <SbAbsence>[];

    final classId = profile?.classId;
    final scheduleAsync = (classId != null && classId.isNotEmpty)
        ? ref.watch(schedulesForClassProvider(classId))
        : const AsyncValue<List<SbSchedule>>.data([]);
    final schedules = scheduleAsync.valueOrNull ?? const <SbSchedule>[];

    final loading = gradesAsync.isLoading || scheduleAsync.isLoading;

    final fmt     = ref.watch(studentFormatProvider);
    final k       = fmt.maxScore / 20;
    final isLetter = fmt.gradingScale == 'letter';

    final avg20 = grades.isEmpty
        ? null
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;
    final avgScore = avg20 == null ? null : avg20 * k;
    final avgRatio = avg20 == null ? null : (avg20 / 20).clamp(0.0, 1.0);
    final avgText  = avg20 == null
        ? null
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
        .take(4)
        .toList();

    // Moyennes par matière pour le bar chart
    final bySubject = <String, List<double>>{};
    for (final g in grades) {
      final s = g.subjectName ?? '—';
      (bySubject[s] ??= []).add(g.outOf20 * k);
    }
    final subjectAvgs = bySubject.entries
        .map((e) => (
              name: e.key,
              avg: e.value.reduce((a, b) => a + b) / e.value.length,
              color: getSubjectMeta(e.key).color,
            ))
        .toList()
      ..sort((a, b) => b.avg.compareTo(a.avg));
    final chartData = subjectAvgs.take(7).toList();

    final shimmer = ShimmerEffect(
      baseColor: cs.surfaceContainer,
      highlightColor: cs.surface,
      duration: const Duration(milliseconds: 1300),
    );

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _terra,
      backgroundColor: cs.surface,
      displacement: 40,
      strokeWidth: 2.5,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: LayoutBuilder(builder: (_, constraints) {
            final w = constraints.maxWidth;
            final isWide  = w > 860;
            final isMed   = w > 560;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Bloc 1 : Hero + Moyenne ──────────────────────────────────
                if (isWide)
                  _BentoRow(gap: 14, children: [
                    _BentoCell(flex: 3, child: _HeroBanner(
                      greeting: _greeting, name: name, initials: initials,
                      loading: loading, classLabel: profile?.classe,
                      levelLabel: level.label,
                    )),
                    _BentoCell(flex: 2, child: _MoyenneCard(
                      loading: loading, shimmer: shimmer,
                      avgText: avgText, unit: unit,
                      avgRatio: avgRatio ?? 0,
                      notes: grades.length,
                      absences: absences.length,
                      onTap: () => _nav('nav.grades'),
                    )),
                  ])
                else ...[
                  _HeroBanner(
                    greeting: _greeting, name: name, initials: initials,
                    loading: loading, classLabel: profile?.classe,
                    levelLabel: level.label,
                  ),
                  const SizedBox(height: 12),
                  _QuickStatRow(
                    loading: loading, shimmer: shimmer,
                    avgText: avgText, unit: unit,
                    absences: absences.length, notes: grades.length,
                    onMoyenne: () => _nav('nav.grades'),
                    onAbsences: () => _nav('nav.attendance'),
                    onNotes: () => _nav('nav.grades'),
                  ),
                ],
                const SizedBox(height: 14),

                // ── Bannière paiement ────────────────────────────────────────
                _PaymentBanner(onTap: () => _nav('nav.my_payments')),

                // ── Bloc 2 : EDT + Stats rapides ─────────────────────────────
                if (isWide)
                  _BentoRow(gap: 14, children: [
                    _BentoCell(flex: 3, child: _EdtSection(
                      edt: loading ? _edtSkeleton : edt,
                      loading: loading, shimmer: shimmer,
                      onMore: () => _nav('nav.schedule'),
                    )),
                    _BentoCell(flex: 2, child: _SideStatColumn(
                      loading: loading, shimmer: shimmer,
                      grades: grades, absences: absences.length,
                      graded: graded, maxScore: fmt.maxScore, k: k,
                      onAttendance: () => _nav('nav.attendance'),
                      onGrades: () => _nav('nav.grades'),
                    )),
                  ])
                else ...[
                  _DashSectionHeader(icon: Icons.calendar_today_rounded,
                      title: "Emploi du temps du jour",
                      accentColor: _terra, action: 'Tout voir',
                      onAction: () => _nav('nav.schedule')),
                  const SizedBox(height: 10),
                  Skeletonizer(
                    enabled: loading, effect: shimmer,
                    child: _EdtTimeline(slots: loading ? _edtSkeleton : edt),
                  ),
                ],
                const SizedBox(height: 14),

                // ── Bloc 3 : Bar chart notes + Stats grid ────────────────────
                if (isWide)
                  _BentoRow(gap: 14, children: [
                    _BentoCell(flex: 3, child: _SubjectBarChartCard(
                      loading: loading, shimmer: shimmer,
                      chartData: loading ? _skeletonChart : chartData,
                      maxScore: fmt.maxScore,
                    )),
                    _BentoCell(flex: 2, child: _StatsGridCard(
                      grades: loading ? _skeletonGrades : grades,
                      absences: absences.length,
                      graded: loading ? _skeletonGrades : graded,
                      maxScore: fmt.maxScore, k: k,
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
                  _StatsGridCard(
                    grades: loading ? _skeletonGrades : grades,
                    absences: absences.length,
                    graded: loading ? _skeletonGrades : graded,
                    maxScore: fmt.maxScore, k: k,
                  ),
                ],
                const SizedBox(height: 14),

                // ── Bloc 4 : Tendance (line chart) ───────────────────────────
                if (graded.length >= 3) ...[
                  _DashSectionHeader(icon: Icons.trending_up_rounded,
                      title: 'Évolution des notes', accentColor: _green,
                      action: 'Toutes', onAction: () => _nav('nav.grades')),
                  const SizedBox(height: 10),
                  _TrendLineCard(
                    graded: loading ? _skeletonGrades : graded,
                    maxScore: fmt.maxScore, k: k,
                    loading: loading, shimmer: shimmer,
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Bloc 5 : Dernières notes ─────────────────────────────────
                _DashSectionHeader(icon: Icons.grading_rounded,
                    title: 'Dernières notes', accentColor: _gold,
                    action: 'Toutes', onAction: () => _nav('nav.grades')),
                const SizedBox(height: 10),
                if (!loading && recent.isEmpty)
                  _MiniEmpty(icon: Icons.grading_rounded,
                      label: "Aucune note pour l'instant")
                else
                  Skeletonizer(
                    enabled: loading, effect: shimmer,
                    child: _RecentNotesGrid(
                      notes: loading ? _skeletonGrades : recent,
                      isWide: isMed,
                      maxScore: fmt.maxScore, k: k,
                      onTap: () => _nav('nav.grades'),
                    ),
                  ),
                const SizedBox(height: 22),

                // ── Bloc 6 : Accès rapide (grille adaptative) ───────────────
                _DashSectionHeader(icon: Icons.apps_rounded,
                    title: 'Accès rapide', accentColor: _terra),
                const SizedBox(height: 10),
                _ShortcutsAdaptiveGrid(
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
    );
  }

  // ── Squelettes de démo ──────────────────────────────────────────────────────
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
    (name: 'Maths', avg: 14.0, color: _terra),
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
// Helpers bento
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
  final int flex;
  final Widget child;
  const _BentoCell({required this.flex, required this.child});
}

// ══════════════════════════════════════════════════════════════════════════════
// Hero Banner
// ══════════════════════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  final String greeting, name, initials;
  final bool loading;
  final String? classLabel, levelLabel;
  const _HeroBanner({
    required this.greeting, required this.name,
    required this.initials, required this.loading,
    this.classLabel, this.levelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), _terra],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: _terra.withOpacity(.30),
          blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -4,
        )],
      ),
      child: Stack(children: [
        Positioned(right: -10, top: -20, child: Container(width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(.04)))),
        Positioned(right: 60, bottom: -20, child: Container(width: 70, height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _gold.withOpacity(.07)))),
        Row(children: [
          // Avatar
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.3), width: 2),
            ),
            child: Center(child: Text(initials, style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: TextStyle(
                color: Colors.white.withOpacity(.65), fontSize: 12)),
            const SizedBox(height: 2),
            Text(name, style: const TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w800, height: 1.2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (classLabel?.isNotEmpty == true || levelLabel != null) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                if (classLabel?.isNotEmpty == true)
                  _HeroBadge(label: classLabel!, color: _gold),
                if (levelLabel != null)
                  _HeroBadge(label: levelLabel!, color: Colors.white.withOpacity(.6)),
              ]),
            ],
          ])),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
          ),
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
      border: Border.all(color: color.withOpacity(.4)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Carte Moyenne — version featured (bento large)
// ══════════════════════════════════════════════════════════════════════════════
class _MoyenneCard extends StatelessWidget {
  final bool loading;
  final ShimmerEffect shimmer;
  final String? avgText, unit;
  final double avgRatio;
  final int notes, absences;
  final VoidCallback onTap;

  const _MoyenneCard({
    required this.loading, required this.shimmer,
    required this.avgText, required this.unit,
    required this.avgRatio, required this.notes,
    required this.absences, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = avgRatio.clamp(0.0, 1.0);
    final rankColor = ratio >= 0.7 ? _green : ratio >= 0.5 ? _gold : _terra;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [rankColor.withOpacity(.18), cs.surfaceContainer],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rankColor.withOpacity(.35)),
            boxShadow: [BoxShadow(
              color: rankColor.withOpacity(.12),
              blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(children: [
            // Titre
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Moyenne générale', style: TextStyle(
                  color: cs.onSurface.withOpacity(.6),
                  fontSize: 12, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ratio >= 0.7 ? '✓ Bien' : ratio >= 0.5 ? '~ Passable' : '↑ Effort',
                  style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            // Indicateur circulaire centré
            SizedBox(
              width: 110, height: 110,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 110, height: 110,
                  child: CircularProgressIndicator(
                    value: loading ? 0.0 : ratio,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: rankColor.withOpacity(.12),
                    valueColor: AlwaysStoppedAnimation(rankColor),
                  ),
                ),
                Skeletonizer(
                  enabled: loading, effect: shimmer,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(loading ? '——' : (avgText ?? '—'), style: TextStyle(
                        color: rankColor, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
                    Text(unit ?? '', style: TextStyle(
                        color: cs.onSurface.withOpacity(.5), fontSize: 11)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Mini stats row
            Row(children: [
              Expanded(child: _MiniStatPill(
                icon: Icons.grading_rounded, color: _gold,
                label: '$notes notes', loading: loading, shimmer: shimmer)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStatPill(
                icon: Icons.event_busy_rounded,
                color: absences == 0 ? _green : _orange,
                label: '$absences abs.', loading: loading, shimmer: shimmer)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final IconData icon; final Color color;
  final String label; final bool loading;
  final ShimmerEffect shimmer;
  const _MiniStatPill({required this.icon, required this.color,
      required this.label, required this.loading, required this.shimmer});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Skeletonizer(enabled: loading, effect: shimmer,
          child: Text(label, style: TextStyle(
              color: cs.onSurface, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick stats row (mobile uniquement)
// ══════════════════════════════════════════════════════════════════════════════
class _QuickStatRow extends StatelessWidget {
  final bool loading;
  final ShimmerEffect shimmer;
  final String? avgText, unit;
  final int absences, notes;
  final VoidCallback? onMoyenne, onAbsences, onNotes;
  const _QuickStatRow({
    required this.loading, required this.shimmer,
    required this.avgText, required this.unit,
    required this.absences, required this.notes,
    this.onMoyenne, this.onAbsences, this.onNotes,
  });

  @override
  Widget build(BuildContext context) {
    final data = [
      (icon: Icons.star_rounded, label: 'Moyenne',
       val: avgText ?? '—', sub: unit ?? '',
       c: _gold, onTap: onMoyenne),
      (icon: Icons.event_busy_rounded, label: 'Absences',
       val: '$absences', sub: absences > 1 ? ' jours' : ' jour',
       c: absences == 0 ? _green : _terra, onTap: onAbsences),
      (icon: Icons.grading_rounded, label: 'Notes',
       val: '$notes', sub: ' reçues',
       c: _orange, onTap: onNotes),
    ];
    return Row(children: [
      for (int i = 0; i < data.length; i++) ...[
        Expanded(child: _QuickStatPill(d: data[i], loading: loading, shimmer: shimmer)),
        if (i < data.length - 1) const SizedBox(width: 8),
      ],
    ]);
  }
}

class _QuickStatPill extends StatelessWidget {
  final ({IconData icon, String label, String val, String sub, Color c, VoidCallback? onTap}) d;
  final bool loading; final ShimmerEffect shimmer;
  const _QuickStatPill({required this.d, required this.loading, required this.shimmer});

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
            border: Border.all(color: d.c.withOpacity(.25)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                  color: d.c.withOpacity(.12),
                  borderRadius: BorderRadius.circular(9)),
                child: Icon(d.icon, color: d.c, size: 15)),
              Icon(Icons.chevron_right_rounded,
                  size: 14, color: cs.onSurface.withOpacity(.25)),
            ]),
            const SizedBox(height: 8),
            Text(d.label, style: TextStyle(
                color: cs.onSurface.withOpacity(.5),
                fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Skeletonizer(enabled: loading, effect: shimmer,
              child: RichText(text: TextSpan(children: [
                TextSpan(text: loading ? '——' : d.val,
                    style: TextStyle(color: cs.onSurface,
                        fontSize: 18, fontWeight: FontWeight.w900)),
                TextSpan(text: d.sub,
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(.45), fontSize: 10)),
              ]))),
          ]),
        ),
      ),
    );
  }
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
          border: Border.all(color: accentColor.withOpacity(.25)),
        ),
        child: Icon(icon, color: accentColor, size: 16)),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: TextStyle(
          fontSize: 15, color: cs.onSurface,
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
                border: Border.all(color: accentColor.withOpacity(.2)),
              ),
              child: Text(action!, style: TextStyle(
                  color: accentColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EDT Section (avec header intégré pour le mode wide)
// ══════════════════════════════════════════════════════════════════════════════
class _EdtSection extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> edt;
  final bool loading; final ShimmerEffect shimmer;
  final VoidCallback onMore;
  const _EdtSection({required this.edt, required this.loading,
      required this.shimmer, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DashSectionHeader(icon: Icons.calendar_today_rounded,
          title: "Emploi du temps du jour",
          accentColor: _terra, action: 'Tout voir', onAction: onMore),
      const SizedBox(height: 10),
      if (!loading && edt.isEmpty)
        _MiniEmpty(icon: Icons.event_available_rounded,
            label: "Pas de cours aujourd'hui")
      else
        Skeletonizer(enabled: loading, effect: shimmer,
            child: _EdtTimeline(slots: edt)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Colonne stats latérale (mode wide)
// ══════════════════════════════════════════════════════════════════════════════
class _SideStatColumn extends StatelessWidget {
  final bool loading; final ShimmerEffect shimmer;
  final List<SbGrade> grades, graded;
  final int absences;
  final double maxScore, k;
  final VoidCallback onAttendance, onGrades;

  const _SideStatColumn({
    required this.loading, required this.shimmer,
    required this.grades, required this.absences,
    required this.graded, required this.maxScore, required this.k,
    required this.onAttendance, required this.onGrades,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final avg20 = grades.isEmpty ? null
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;

    // Tendance
    String trendLabel = '—'; Color trendColor = _gold;
    IconData trendIcon = Icons.trending_flat_rounded;
    if (graded.length >= 4) {
      final half = graded.length ~/ 2;
      final rAvg = graded.sublist(graded.length - half)
          .fold<double>(0, (s, g) => s + g.outOf20) / half;
      final oAvg = graded.sublist(0, half)
          .fold<double>(0, (s, g) => s + g.outOf20) / half;
      final diff = rAvg - oAvg;
      if (diff > 0.3) {
        trendLabel = '+${(diff * k).toStringAsFixed(1)} pts'; trendColor = _green;
        trendIcon  = Icons.trending_up_rounded;
      } else if (diff < -0.3) {
        trendLabel = '${(diff * k).toStringAsFixed(1)} pts'; trendColor = _terra;
        trendIcon  = Icons.trending_down_rounded;
      } else {
        trendLabel = 'Stable';
      }
    }

    final items = [
      _SideStatItem(icon: Icons.star_rounded, color: _gold, label: 'Moyenne',
        value: avg20 == null ? '—' : '${(avg20 * k).toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
        onTap: onGrades),
      _SideStatItem(icon: Icons.event_busy_rounded,
        color: absences == 0 ? _green : _orange,
        label: 'Absences',
        value: '$absences ${absences > 1 ? "jours" : "jour"}',
        onTap: onAttendance),
      _SideStatItem(icon: trendIcon, color: trendColor, label: 'Tendance',
        value: trendLabel, onTap: onGrades),
      _SideStatItem(icon: Icons.grading_rounded, color: _cyan, label: 'Notes reçues',
        value: '${grades.length}', onTap: onGrades),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashSectionHeader(icon: Icons.insights_rounded,
            title: 'Statistiques rapides', accentColor: _cyan),
        const SizedBox(height: 10),
        ...items.map((it) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Skeletonizer(
            enabled: loading, effect: shimmer,
            child: _SideStatTile(item: it),
          ),
        )),
      ],
    );
  }
}

class _SideStatItem {
  final IconData icon; final Color color;
  final String label, value; final VoidCallback onTap;
  const _SideStatItem({required this.icon, required this.color,
      required this.label, required this.value, required this.onTap});
}

class _SideStatTile extends StatelessWidget {
  final _SideStatItem item;
  const _SideStatTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              item.color.withOpacity(.10), cs.surfaceContainer]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.color.withOpacity(.25)),
          ),
          child: Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: item.color.withOpacity(.18),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, color: item.color, size: 17)),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label, style: TextStyle(
                color: cs.onSurface.withOpacity(.6),
                fontSize: 11, fontWeight: FontWeight.w700))),
            Text(item.value, style: TextStyle(
                color: item.color, fontSize: 14, fontWeight: FontWeight.w900)),
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

  const _SubjectBarChartCard({
    required this.loading, required this.shimmer,
    required this.chartData, required this.maxScore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(
              color: _cyan.withOpacity(.12),
              borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.bar_chart_rounded, color: _cyan, size: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text('Notes par matière', style: TextStyle(
              color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('/${maxScore.toStringAsFixed(0)}',
                style: const TextStyle(color: _cyan,
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        if (chartData.isEmpty)
          SizedBox(height: 160, child: Center(child: Text('Aucune note',
              style: TextStyle(color: cs.onSurface.withOpacity(.4), fontSize: 12))))
        else
          Skeletonizer(
            enabled: loading, effect: shimmer,
            child: SizedBox(
              height: 170,
              child: BarChart(BarChartData(
                maxY: maxScore,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxScore / 4,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: cs.outline.withOpacity(.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      if (v == 0 || v == maxScore / 2 || v == maxScore) {
                        return Text(v.toStringAsFixed(0),
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(.4),
                                fontSize: 9));
                      }
                      return const SizedBox();
                    },
                  )),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= chartData.length) return const SizedBox();
                      final n = chartData[i].name;
                      final short = n.length > 5 ? n.substring(0, 4) : n;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(short, style: TextStyle(
                            color: cs.onSurface.withOpacity(.5),
                            fontSize: 9, fontWeight: FontWeight.w600)),
                      );
                    },
                  )),
                ),
                barGroups: [
                  for (int i = 0; i < chartData.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: chartData[i].avg.clamp(0, maxScore),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7)),
                        gradient: LinearGradient(
                          colors: [
                            chartData[i].color,
                            chartData[i].color.withOpacity(.55),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ]),
                ],
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipColor: (_) => cs.surfaceContainerHighest,
                    getTooltipItem: (g, _, r, __) => BarTooltipItem(
                      '${chartData[g.x].name}\n${r.toY.toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
                      TextStyle(color: cs.onSurface,
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
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
// Stats Grid Card (remplace l'ancienne _StatsGrid)
// ══════════════════════════════════════════════════════════════════════════════
class _StatsGridCard extends StatelessWidget {
  final List<SbGrade> grades, graded;
  final int absences;
  final double maxScore, k;
  const _StatsGridCard({
    required this.grades, required this.graded,
    required this.absences, required this.maxScore, required this.k,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEmpty = grades.isEmpty;

    final best  = isEmpty ? null : grades.reduce((a, b) => a.outOf20 > b.outOf20 ? a : b);
    final worst = isEmpty ? null : grades.reduce((a, b) => a.outOf20 < b.outOf20 ? a : b);

    final bySubject = <String, List<double>>{};
    for (final g in grades) { (bySubject[g.subjectName ?? '—'] ??= []).add(g.outOf20); }
    String? bestSubject; double bestAvg = 0;
    for (final e in bySubject.entries) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      if (avg > bestAvg) { bestAvg = avg; bestSubject = e.key; }
    }

    final avg20 = isEmpty ? 0.0 : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;
    final above = grades.where((g) => g.outOf20 > avg20).length;

    String trendLabel = '—'; Color trendColor = cs.onSurface.withOpacity(.5);
    IconData trendIcon = Icons.remove_rounded;
    if (graded.length >= 4) {
      final half = graded.length ~/ 2;
      final rAvg = graded.sublist(graded.length - half)
          .fold<double>(0, (s, g) => s + g.outOf20) / half;
      final oAvg = graded.sublist(0, half)
          .fold<double>(0, (s, g) => s + g.outOf20) / half;
      final diff = rAvg - oAvg;
      if (diff > 0.3) { trendLabel = '+${(diff * k).toStringAsFixed(1)}'; trendColor = _green; trendIcon = Icons.trending_up_rounded; }
      else if (diff < -0.3) { trendLabel = '${(diff * k).toStringAsFixed(1)}'; trendColor = _terra; trendIcon = Icons.trending_down_rounded; }
      else { trendLabel = 'Stable'; trendColor = _gold; trendIcon = Icons.trending_flat_rounded; }
    }

    final stats = [
      _StatItem(icon: Icons.emoji_events_rounded, color: _gold, label: 'Meilleure',
        value: isEmpty ? '—' : '${(best!.outOf20 * k).toStringAsFixed(1)}',
        sub: best?.subjectName),
      _StatItem(icon: Icons.arrow_downward_rounded, color: _terra, label: 'Plus basse',
        value: isEmpty ? '—' : '${(worst!.outOf20 * k).toStringAsFixed(1)}',
        sub: worst?.subjectName),
      _StatItem(icon: Icons.star_half_rounded, color: _green, label: 'Point fort',
        value: bestSubject ?? '—', sub: bestSubject != null
            ? 'moy. ${(bestAvg * k).toStringAsFixed(1)}' : null, compact: true),
      _StatItem(icon: Icons.check_circle_outline_rounded, color: _cyan,
        label: 'Au-dessus moy.', value: isEmpty ? '—' : '$above/${grades.length}',
        sub: 'notes'),
      _StatItem(icon: trendIcon, color: trendColor, label: 'Tendance',
        value: trendLabel, sub: graded.length < 4 ? 'peu de données' : 'récent vs avant'),
      _StatItem(icon: Icons.event_busy_rounded, color: absences == 0 ? _green : _orange,
        label: 'Absences', value: '$absences', sub: absences > 1 ? 'jours' : 'jour'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.5,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _StatCard(item: stats[i]),
    );
  }
}

class _StatItem {
  final IconData icon; final Color color;
  final String label, value; final String? sub; final bool compact;
  const _StatItem({required this.icon, required this.color,
      required this.label, required this.value,
      this.sub, this.compact = false});
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          item.color.withOpacity(.13), cs.surfaceContainer]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withOpacity(.25)),
        boxShadow: [BoxShadow(color: item.color.withOpacity(.08),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 27, height: 27,
            decoration: BoxDecoration(color: item.color.withOpacity(.18),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(item.icon, color: item.color, size: 13)),
          const SizedBox(width: 6),
          Expanded(child: Text(item.label, style: TextStyle(
              color: cs.onSurface.withOpacity(.55), fontSize: 9,
              fontWeight: FontWeight.w700), maxLines: 1,
              overflow: TextOverflow.ellipsis)),
        ]),
        const Spacer(),
        Text(item.value, style: TextStyle(color: item.color,
            fontSize: item.compact ? 11 : 15, fontWeight: FontWeight.w900,
            height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (item.sub != null)
          Text(item.sub!, style: TextStyle(
              color: cs.onSurface.withOpacity(.45), fontSize: 8.5,
              fontWeight: FontWeight.w600), maxLines: 1,
              overflow: TextOverflow.ellipsis),
      ]),
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
    final cs = Theme.of(context).colorScheme;
    final pts = graded.take(12).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Skeletonizer(
          enabled: loading, effect: shimmer,
          child: SizedBox(
            height: 130,
            child: LineChart(LineChartData(
              minY: 0, maxY: maxScore,
              gridData: FlGridData(
                show: true, drawVerticalLine: false,
                horizontalInterval: maxScore / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.outline.withOpacity(.18), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 28,
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
                    final g = pts[i];
                    if (g.gradedAt == null) return const SizedBox();
                    if (i == 0 || i == pts.length - 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${g.gradedAt!.day}/${g.gradedAt!.month}',
                            style: TextStyle(color: cs.onSurface.withOpacity(.4),
                                fontSize: 8)),
                      );
                    }
                    return const SizedBox();
                  },
                )),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipColor: (_) => cs.surfaceContainerHighest,
                  getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    '${(s.y).toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
                    TextStyle(color: _green, fontSize: 11,
                        fontWeight: FontWeight.w700),
                  )).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (int i = 0; i < pts.length; i++)
                      FlSpot(i.toDouble(), (pts[i].outOf20 * k).clamp(0, maxScore)),
                  ],
                  isCurved: true, curveSmoothness: 0.3,
                  color: _green,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 4,
                      color: _green,
                      strokeWidth: 2,
                      strokeColor: cs.surfaceContainer,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [_green.withOpacity(.25), _green.withOpacity(.0)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            )),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Recent notes — grille adaptative (2 cols sur medium+)
// ══════════════════════════════════════════════════════════════════════════════
class _RecentNotesGrid extends StatelessWidget {
  final List<SbGrade> notes;
  final bool isWide;
  final double maxScore, k;
  final VoidCallback onTap;
  const _RecentNotesGrid({required this.notes, required this.isWide,
      required this.maxScore, required this.k, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(children: [
        for (int i = 0; i < notes.length; i++) ...[
          _NoteRow(
            sub: notes[i].subjectName ?? notes[i].title ?? '—',
            note: notes[i].score, max: notes[i].maxScore,
            date: _fmtShort(notes[i].gradedAt),
            color: notes[i].outOf20 >= 14 ? _green
                : notes[i].outOf20 >= 10 ? _gold : _terra,
            onTap: onTap,
          ),
          if (i < notes.length - 1) const SizedBox(height: 8),
        ],
      ]);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 3.4,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: notes.length,
      itemBuilder: (_, i) => _NoteRow(
        sub: notes[i].subjectName ?? notes[i].title ?? '—',
        note: notes[i].score, max: notes[i].maxScore,
        date: _fmtShort(notes[i].gradedAt),
        color: notes[i].outOf20 >= 14 ? _green
            : notes[i].outOf20 >= 10 ? _gold : _terra,
        onTap: onTap,
      ),
    );
  }

  static String _fmtShort(DateTime? d) {
    if (d == null) return '';
    const m = ['janv.','févr.','mars','avr.','mai','juin',
                'juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${m[d.month - 1]}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shortcuts — grille adaptative (wrap sur wide, scroll horizontal sur mobile)
// ══════════════════════════════════════════════════════════════════════════════
class _ShortcutsAdaptiveGrid extends StatelessWidget {
  final bool isWide, isMed;
  final Map<String, VoidCallback> onTap;
  const _ShortcutsAdaptiveGrid({
    required this.isWide, required this.isMed, required this.onTap});

  static const _items = [
    (key: 'notes',        icon: Icons.grading_rounded,             label: 'Notes',       c: _gold),
    (key: 'presences',    icon: Icons.fact_check_rounded,          label: 'Présences',   c: _green),
    (key: 'edt',          icon: Icons.calendar_month_rounded,      label: 'Emploi',      c: _terra),
    (key: 'cours',        icon: Icons.menu_book_rounded,           label: 'Cours',       c: _terra),
    (key: 'paiements',    icon: Icons.account_balance_wallet_rounded, label: 'Paiements', c: _orange),
    (key: 'bibliotheque', icon: Icons.local_library_rounded,       label: 'Bibliothèque',c: _green),
    (key: 'notifications',icon: Icons.notifications_rounded,       label: 'Alertes',     c: _orange),
    (key: 'simulateur',   icon: Icons.calculate_rounded,           label: 'Simulateur',  c: _gold),
    (key: 'documents',    icon: Icons.folder_rounded,              label: 'Documents',   c: _cyan),
  ];

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      // Grille fixe — 5 colonnes sur large, 4 sur medium
      final cols = isWide ? 5 : 4;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, childAspectRatio: 1.1,
          crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) => _ShortcutCard(
            item: _items[i], onTap: onTap[_items[i].key]),
      );
    }

    if (isMed) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 0.95,
          crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) => _ShortcutCard(
            item: _items[i], onTap: onTap[_items[i].key]),
      );
    }

    // Mobile — scroll horizontal 2 lignes
    const gap  = 10.0;
    const rows = 2;
    final cols = <List<({String key, IconData icon, String label, Color c})>>[];
    for (var i = 0; i < _items.length; i += rows) {
      cols.add(_items.sublist(i, (i + rows).clamp(0, _items.length)));
    }
    return LayoutBuilder(builder: (_, constraints) {
      final cardW = (constraints.maxWidth - gap * 2) / 3.2;
      final cardH = (cardW * 1.05).clamp(88.0, 108.0);
      final totalH = cardH * rows + gap * (rows - 1);
      return SizedBox(
        height: totalH,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          separatorBuilder: (_, __) => const SizedBox(width: gap),
          itemCount: cols.length,
          itemBuilder: (_, ci) {
            final col = cols[ci];
            return SizedBox(
              width: cardW,
              child: Column(children: [
                for (int ri = 0; ri < col.length; ri++) ...[
                  if (ri > 0) const SizedBox(height: gap),
                  SizedBox(height: cardH, child: _ShortcutCard(
                      item: col[ri], onTap: onTap[col[ri].key])),
                ],
              ]),
            );
          },
        ),
      );
    });
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.c.withOpacity(.20)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(
                color: item.c.withOpacity(.12),
                borderRadius: BorderRadius.circular(11)),
              child: Icon(item.icon, color: item.c, size: 19)),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(item.label,
                  style: TextStyle(color: cs.onSurface,
                      fontSize: 10.5, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EDT Timeline (cartes horizontales)
// ══════════════════════════════════════════════════════════════════════════════
class _EdtTimeline extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> slots;
  const _EdtTimeline({required this.slots});

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return LayoutBuilder(builder: (_, constraints) {
      final cardW = (constraints.maxWidth - gap * 2) / 2.75;
      const cardH = 148.0;
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
                    colors: [s.c, s.c.withOpacity(.75)]),
                  boxShadow: [BoxShadow(color: s.c.withOpacity(.28),
                      blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: Stack(children: [
                  Positioned(right: -12, top: -12, child: Container(width: 68,
                      height: 68, decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(.06)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Container(width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.20),
                            borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.school_rounded,
                              size: 16, color: Colors.white)),
                        if (i == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.22),
                              borderRadius: BorderRadius.circular(6)),
                            child: const Text('Actif', style: TextStyle(
                                color: Colors.white, fontSize: 8,
                                fontWeight: FontWeight.w900))),
                      ]),
                      const Spacer(),
                      Text(s.sub, style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w900, height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: Color(0xCCFFFFFF)),
                        const SizedBox(width: 4),
                        Text(s.h, style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 10, fontWeight: FontWeight.w700)),
                        if (s.room.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.room_outlined,
                              size: 11, color: Color(0xAAFFFFFF)),
                          const SizedBox(width: 2),
                          Text(s.room, style: const TextStyle(
                              color: Color(0xAAFFFFFF), fontSize: 10)),
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hasLate ? 'Paiement en retard' : 'Paiement en attente',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12.5, fontWeight: FontWeight.w800)),
                Text('${totalDue.toStringAsFixed(0)} $currency à régler',
                    style: TextStyle(color: Colors.white.withOpacity(.80), fontSize: 11)),
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

// ══════════════════════════════════════════════════════════════════════════════
// Note row
// ══════════════════════════════════════════════════════════════════════════════
class _NoteRow extends StatelessWidget {
  final String sub, date;
  final double note, max;
  final Color color;
  final VoidCallback onTap;
  const _NoteRow({required this.sub, required this.note, required this.max,
      required this.date, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final pct = (note / max).clamp(0.0, 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: ScolarisSurface.themedCard(context, radius: 13),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            SizedBox(width: 44, height: 44,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 44, height: 44,
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
                  fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: color.withOpacity(.10),
                  valueColor: AlwaysStoppedAnimation(color))),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (pct >= 0.7 ? _green : _terra).withOpacity(.10),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(pct >= 0.7 ? '✓ Bien' : '→ Effort',
                    style: TextStyle(color: pct >= 0.7 ? _green : _terra,
                        fontSize: 9, fontWeight: FontWeight.w800))),
              const SizedBox(height: 4),
              Text(date, style: TextStyle(
                  color: cs.onSurface.withOpacity(.45), fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Mini état vide
// ══════════════════════════════════════════════════════════════════════════════
class _MiniEmpty extends StatelessWidget {
  final IconData icon; final String label;
  const _MiniEmpty({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withOpacity(.25))),
      child: Column(children: [
        Icon(icon, color: cs.onSurface.withOpacity(.3), size: 30),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: TextStyle(
            color: cs.onSurface.withOpacity(.45),
            fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
