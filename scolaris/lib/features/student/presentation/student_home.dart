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
import 'pages/carnet_recompenses_page.dart';
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

// Brand colors
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _cyan   = Color(0xFF0891B2);

// ══════════════════════════════════════════════════════════════════════════
// Shell (navigation)
// ══════════════════════════════════════════════════════════════════════════
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
    final isUniv    = level == SchoolLevel.universite ||
                      level == SchoolLevel.master ||
                      level == SchoolLevel.doctorat;

    final Widget dashboard =
        isPrimaire ? const PrimaryDashboard() : const _StudentDashboard();

    return [
      RoleNavGroup(labelKey: 'sections.setup', entries: [
        RoleNavEntry(
          icon: Icons.home_rounded,
          activeIcon: Icons.home_rounded,
          labelKey: 'nav.dashboard',
          page: dashboard,
        ),
        const RoleNavEntry(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          labelKey: 'nav.courses',
          page: CoursesPage(),
        ),
      ]),

      RoleNavGroup(labelKey: 'sections.activity', entries: [
        const RoleNavEntry(
          icon: Icons.grading_outlined,
          activeIcon: Icons.grading_rounded,
          labelKey: 'nav.grades',
          page: GradesPage(),
        ),
        const RoleNavEntry(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month_rounded,
          labelKey: 'nav.schedule',
          page: SchedulePage(),
        ),
        const RoleNavEntry(
          icon: Icons.fact_check_outlined,
          activeIcon: Icons.fact_check_rounded,
          labelKey: 'nav.attendance',
          page: AttendancePage(),
        ),
        const RoleNavEntry(
          icon: Icons.local_library_outlined,
          activeIcon: Icons.local_library_rounded,
          labelKey: 'nav.library',
          page: PlanGate(
            minPlan: 'pro',
            featureLabel: 'Bibliothèque',
            description: 'Catalogue, manuels et bibliothèque numérique.',
            child: LibraryPage(),
          ),
        ),
      ]),

      if (isPrimaire)
        const RoleNavGroup(labelKey: 'sections.primary_tools', entries: [
          RoleNavEntry(
            icon: Icons.import_contacts_outlined,
            activeIcon: Icons.import_contacts_rounded,
            labelKey: 'nav.cahier_liaison',
            page: CahierLiaisonPage(),
          ),
          RoleNavEntry(
            icon: Icons.emoji_events_outlined,
            activeIcon: Icons.emoji_events_rounded,
            labelKey: 'nav.recompenses',
            page: CarnetRecompensesPage(),
          ),
        ]),

      if (isUniv)
        const RoleNavGroup(labelKey: 'sections.university', entries: [
          RoleNavEntry(
            icon: Icons.workspace_premium_outlined,
            activeIcon: Icons.workspace_premium_rounded,
            labelKey: 'nav.releve_ects',
            page: ReleveEctsPage(),
          ),
          RoleNavEntry(
            icon: Icons.app_registration_outlined,
            activeIcon: Icons.app_registration_rounded,
            labelKey: 'nav.inscription_ue',
            page: InscriptionUEPage(),
          ),
          RoleNavEntry(
            icon: Icons.credit_card_outlined,
            activeIcon: Icons.credit_card_rounded,
            labelKey: 'nav.carte_etudiante',
            page: CarteEtudiantePage(),
          ),
        ]),

      if (!isPrimaire)
        const RoleNavGroup(labelKey: 'sections.finance', entries: [
          RoleNavEntry(
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet_rounded,
            labelKey: 'nav.my_payments',
            page: StudentPaymentsPage(),
          ),
          RoleNavEntry(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder_rounded,
            labelKey: 'nav.documents',
            page: StudentDocumentsPage(),
          ),
        ]),

      RoleNavGroup(labelKey: 'sections.account', entries: [
        const RoleNavEntry(
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications_rounded,
          labelKey: 'nav.notifications',
          page: NotificationsPage(),
        ),
        const RoleNavEntry(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          labelKey: 'nav.settings',
          page: SettingsPage(),
        ),
      ]),
    ];
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Dashboard principal
// ══════════════════════════════════════════════════════════════════════════
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

  /// Navigate within the shell (keeps header + sidebar visible).
  void _nav(String labelKey) =>
      ref.read(navIntentProvider.notifier).state = labelKey;

  /// Fallback push for pages without a shell entry (simulateur, etc.)
  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      ref.invalidate(myGradesProvider);
      ref.invalidate(myAbsencesProvider);
      ref.invalidate(myStudentProfileProvider);
      // Wait for at least one frame so providers reload
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final user   = ref.watch(authSessionProvider);
    final name   = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);

    final level   = ref.watch(studentSchoolLevelProvider).valueOrNull
        ?? SchoolLevel.lycee;
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

    final fmt = ref.watch(studentFormatProvider);
    final k = fmt.maxScore / 20;
    final isLetter = fmt.gradingScale == 'letter';

    final avg20 = grades.isEmpty
        ? null
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;
    final avgScore = avg20 == null ? null : avg20 * k;
    final avgRatio = avg20 == null ? null : (avg20 / 20).clamp(0.0, 1.0);
    final avgText = avg20 == null
        ? null
        : isLetter ? fmt.grade(avgScore) : avgScore!.toStringAsFixed(1);
    final unit = isLetter ? '' : '/${fmt.maxScore.toStringAsFixed(0)}';

    final todayDay = DateTime.now().weekday;
    final edt = (schedules.where((s) => s.dayOfWeek == todayDay).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime)))
        .map((s) => (
              h: s.startTime,
              sub: s.subjectName ?? 'Cours',
              room: s.room ?? '',
              c: getSubjectMeta(s.subjectName ?? '').color,
            ))
        .toList();

    final graded = ([...grades]..sort((a, b) =>
        (a.gradedAt ?? DateTime(2000)).compareTo(b.gradedAt ?? DateTime(2000))));

    final recent = ([...grades]..sort((a, b) =>
            (b.gradedAt ?? DateTime(2000)).compareTo(a.gradedAt ?? DateTime(2000))))
        .take(3)
        .toList();

    // Shimmer effect adapté au thème
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
            final isWide = constraints.maxWidth > 680;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── 1. Hero banner ────────────────────────────────────────
              _HeroBanner(
                greeting: _greeting, name: name,
                initials: initials, loading: loading,
                classLabel: profile?.classe,
                levelLabel: level.label,
              ),
              const SizedBox(height: 16),

              // ── 2. Stats rapides (tappables) ──────────────────────────
              // Shimmer uniquement sur les valeurs dynamiques (pas les labels/icônes)
              _QuickStats(
                loading: loading,
                shimmer: shimmer,
                moyenneText: avgText,
                moyenneUnit: unit,
                absences: absences.length,
                notes: grades.length,
                onMoyenne: () => _nav('nav.grades'),
                onAbsences: () => _nav('nav.attendance'),
                onNotes: () => _nav('nav.grades'),
              ),
              const SizedBox(height: 22),

              // ── 3. Accès rapide (2 lignes max, swipe horizontal) ──────
              _SectionHeader(
                icon: Icons.apps_rounded,
                title: 'Accès rapide',
                accentColor: _terra,
              ),
              const SizedBox(height: 10),
              _PremiumShortcutsGrid(
                onTap: {
                  'notes':         () => _nav('nav.grades'),
                  'edt':           () => _nav('nav.schedule'),
                  'presences':     () => _nav('nav.attendance'),
                  'cours':         () => _nav('nav.courses'),
                  'bibliotheque':  () => _push(const PlanGate(
                        minPlan: 'pro',
                        featureLabel: 'Bibliothèque',
                        description: 'Catalogue, manuels et bibliothèque numérique.',
                        child: LibraryPage(),
                      )),
                  'notifications': () => _nav('nav.notifications'),
                  'simulateur':    () => _push(const SimulateurMoyennePage()),
                },
              ),
              const SizedBox(height: 24),

              // ── 4. Bento grid : EDT + Statistiques ────────────────────
              if (isWide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: _buildEdtSection(edt, loading, shimmer)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildStatsSection(grades, absences, graded, loading, shimmer, fmt.maxScore, k)),
                ])
              else ...[
                _buildEdtSection(edt, loading, shimmer),
                const SizedBox(height: 22),
                _buildStatsSection(grades, absences, graded, loading, shimmer, fmt.maxScore, k),
              ],
              const SizedBox(height: 22),

              // ── 5. Dernières notes ─────────────────────────────────────
              _buildRecentNotesSection(recent, loading, shimmer),
            ]);
          }),
        ),
      ),
    );
  }

  static const _edtSkeleton = [
    (h: '08:00', sub: 'Cours', room: 'A1', c: _terra),
    (h: '10:00', sub: 'Cours', room: 'B2', c: _gold),
    (h: '14:00', sub: 'Cours', room: 'C3', c: _green),
  ];

  Widget _buildEdtSection(
      List<({String h, String sub, String room, Color c})> edt,
      bool loading,
      ShimmerEffect shimmer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.calendar_today_rounded,
          title: "Emploi du temps du jour",
          accentColor: _terra,
          action: 'Tout voir',
          onAction: () => _nav('nav.schedule'),
        ),
        const SizedBox(height: 10),
        if (!loading && edt.isEmpty)
          _MiniEmpty(icon: Icons.event_available_rounded, label: "Pas de cours aujourd'hui")
        else
          Skeletonizer(
            enabled: loading, effect: shimmer,
            child: _EdtTimeline(slots: loading ? _edtSkeleton : edt),
          ),
      ],
    );
  }

  Widget _buildStatsSection(
      List<SbGrade> grades,
      List<SbAbsence> absences,
      List<SbGrade> graded,
      bool loading,
      ShimmerEffect shimmer,
      double maxScore,
      double k) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header statique — jamais shimmerisé
        _SectionHeader(
          icon: Icons.bar_chart_rounded,
          title: 'Statistiques',
          accentColor: _cyan,
        ),
        const SizedBox(height: 10),
        // Grille dynamique — shimmer uniquement ici
        Skeletonizer(
          enabled: loading, effect: shimmer,
          child: _StatsGrid(
            grades: loading ? _skeletonGrades : grades,
            absences: absences.length,
            graded: loading ? _skeletonGrades : graded,
            maxScore: maxScore,
            k: k,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentNotesSection(List<SbGrade> recent, bool loading,
      ShimmerEffect shimmer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.grading_rounded,
          title: 'Dernières notes',
          accentColor: _gold,
          action: 'Toutes',
          onAction: () => _nav('nav.grades'),
        ),
        const SizedBox(height: 10),
        if (!loading && recent.isEmpty)
          const _MiniEmpty(icon: Icons.grading_rounded, label: "Aucune note pour l'instant")
        else
          Skeletonizer(
            enabled: loading, effect: shimmer,
            child: Column(children: [
              for (final g in (loading ? _skeletonGrades : recent)) ...[
                _NoteRow(
                  sub: g.subjectName ?? g.title ?? '—',
                  note: g.score, max: g.maxScore,
                  date: _fmtShort(g.gradedAt),
                  color: g.outOf20 >= 14 ? _green : g.outOf20 >= 10 ? _gold : _terra,
                  onTap: () => _nav('nav.grades'),
                ),
                const SizedBox(height: 8),
              ],
            ]),
          ),
      ],
    );
  }

  static final _skeletonGrades = [
    SbGrade(id: '1', studentId: '', subjectName: 'Matière', score: 15, maxScore: 20),
    SbGrade(id: '2', studentId: '', subjectName: 'Matière', score: 13, maxScore: 20),
    SbGrade(id: '3', studentId: '', subjectName: 'Matière', score: 16, maxScore: 20),
  ];

  static String _fmtShort(DateTime? d) {
    if (d == null) return '';
    const mois = ['janv.','févr.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${mois[d.month - 1]}';
  }

  String _initials(String name) {
    final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return 'E';
    if (p.length == 1) return p[0][0].toUpperCase();
    return (p[0][0] + p[1][0]).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Hero Banner — sans la moyenne (elle est déjà dans les stats en dessous)
// ══════════════════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  final String greeting, name, initials;
  final bool loading;
  final String? classLabel;
  final String? levelLabel;
  const _HeroBanner({
    required this.greeting, required this.name,
    required this.initials, required this.loading,
    this.classLabel, this.levelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), _terra],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _terra.withOpacity(.30),
              blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -4),
        ],
      ),
      child: Stack(children: [
        // Décoration fond
        Positioned(right: -10, top: -20,
          child: Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(.04)))),
        Positioned(right: 50, bottom: -15,
          child: Container(width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _gold.withOpacity(.08)))),
        // Contenu
        Row(children: [
          // Avatar
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.3), width: 2),
            ),
            child: Center(child: Text(initials,
                style: const TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 14),
          // Nom + classe + niveau
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: TextStyle(
                color: Colors.white.withOpacity(.65), fontSize: 12)),
            const SizedBox(height: 2),
            Text(name, style: const TextStyle(color: Colors.white,
                fontSize: 17, fontWeight: FontWeight.w800, height: 1.2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (classLabel?.isNotEmpty == true || levelLabel != null) ...[
              const SizedBox(height: 5),
              Row(children: [
                if (classLabel?.isNotEmpty == true)
                  _HeroBadge(label: classLabel!, color: _gold),
                if (classLabel?.isNotEmpty == true && levelLabel != null)
                  const SizedBox(width: 6),
                if (levelLabel != null)
                  _HeroBadge(label: levelLabel!, color: Colors.white.withOpacity(.6)),
              ]),
            ],
          ])),
          // Icône décorative (pas de moyenne ici — déjà dans les stats)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              shape: BoxShape.circle,
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
  final String label;
  final Color color;
  const _HeroBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(.4)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Stats rapides — tappables, shimmer uniquement sur la valeur dynamique
// ══════════════════════════════════════════════════════════════════════════
class _QuickStats extends StatelessWidget {
  final bool loading;
  final ShimmerEffect shimmer;
  final String? moyenneText;
  final String moyenneUnit;
  final int absences, notes;
  final VoidCallback? onMoyenne, onAbsences, onNotes;
  const _QuickStats({
    required this.loading, required this.shimmer,
    required this.moyenneText, required this.moyenneUnit,
    required this.absences, required this.notes,
    this.onMoyenne, this.onAbsences, this.onNotes,
  });

  @override
  Widget build(BuildContext context) {
    final data = [
      (icon: Icons.star_rounded,      label: 'Moyenne',
       val: moyenneText ?? '—',       sub: moyenneUnit,
       c: _gold,                      onTap: onMoyenne),
      (icon: Icons.event_busy_rounded, label: 'Absences',
       val: '$absences',              sub: absences > 1 ? ' jours' : ' jour',
       c: absences == 0 ? _green : _terra, onTap: onAbsences),
      (icon: Icons.grading_rounded,   label: 'Notes',
       val: '$notes',                 sub: ' reçues',
       c: _orange,                    onTap: onNotes),
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
  final bool loading;
  final ShimmerEffect shimmer;
  const _QuickStatPill({required this.d, required this.loading, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: d.onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withOpacity(.3)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icône + chevron : 100 % statiques, jamais shimmerisés
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: d.c.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(d.icon, color: d.c, size: 14),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 14, color: cs.onSurface.withOpacity(.25)),
          ]),
          const SizedBox(height: 6),
          // Label statique
          Text(d.label, style: TextStyle(
              color: cs.onSurface.withOpacity(.5),
              fontSize: 9.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          // Valeur dynamique : shimmer uniquement ici
          Skeletonizer(
            enabled: loading, effect: shimmer,
            child: RichText(text: TextSpan(children: [
              TextSpan(text: loading ? '——' : d.val,
                  style: TextStyle(color: cs.onSurface,
                      fontSize: 17, fontWeight: FontWeight.w900)),
              TextSpan(text: d.sub,
                  style: TextStyle(color: cs.onSurface.withOpacity(.45), fontSize: 9.5)),
            ])),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Section header
// ══════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accentColor,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accentColor.withOpacity(.25)),
        ),
        child: Icon(icon, color: accentColor, size: 15),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: TextStyle(
          fontSize: 14.5, color: cs.onSurface,
          fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (action != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(action!, style: TextStyle(
                color: accentColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Mini état vide
// ══════════════════════════════════════════════════════════════════════════
class _MiniEmpty extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniEmpty({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(.3)),
      ),
      child: Column(children: [
        Icon(icon, color: cs.onSurface.withOpacity(.3), size: 28),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onSurface.withOpacity(.45),
                fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Accès rapide — 2 lignes max, scroll horizontal si > 2×cols éléments
// ══════════════════════════════════════════════════════════════════════════
class _PremiumShortcutsGrid extends StatelessWidget {
  final Map<String, VoidCallback> onTap;
  const _PremiumShortcutsGrid({required this.onTap});

  static const _items = [
    (key: 'notes',        icon: Icons.grading_rounded,          label: 'Notes',       c: _gold),
    (key: 'edt',          icon: Icons.calendar_month_rounded,   label: 'Emploi',      c: _terra),
    (key: 'presences',    icon: Icons.fact_check_rounded,       label: 'Présences',   c: _green),
    (key: 'cours',        icon: Icons.menu_book_rounded,        label: 'Cours',       c: _terra),
    (key: 'bibliotheque', icon: Icons.local_library_rounded,    label: 'Biblio.',     c: _green),
    (key: 'notifications',icon: Icons.notifications_rounded,    label: 'Alertes',     c: _orange),
    (key: 'simulateur',   icon: Icons.calculate_rounded,        label: 'Simulateur',  c: _gold),
  ];

  @override
  Widget build(BuildContext context) {
    const itemW = 88.0;
    const itemH = 82.0;
    const gap   = 10.0;
    const rows  = 2;

    // Organise en colonnes de 2
    final cols = <List<({String key, IconData icon, String label, Color c})>>[];
    for (var i = 0; i < _items.length; i += rows) {
      cols.add(_items.sublist(i, (i + rows).clamp(0, _items.length)));
    }

    return SizedBox(
      height: itemH * rows + gap * (rows - 1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: gap),
        itemCount: cols.length,
        itemBuilder: (_, ci) {
          final col = cols[ci];
          return SizedBox(
            width: itemW,
            child: Column(
              children: [
                for (int ri = 0; ri < col.length; ri++) ...[
                  if (ri > 0) const SizedBox(height: gap),
                  SizedBox(
                    height: itemH,
                    child: _ShortcutCard(
                        item: col[ri], onTap: onTap[col[ri].key]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.c.withOpacity(.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: item.c.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.c, size: 18),
              ),
              const SizedBox(height: 7),
              Text(item.label,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// EDT du jour — style identique à la page Emploi du temps
// ══════════════════════════════════════════════════════════════════════════
class _EdtTimeline extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> slots;
  const _EdtTimeline({required this.slots});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = slots[i];
          final isFirst = i == 0;
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [s.c, s.c.withOpacity(.80)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: s.c.withOpacity(.30),
                    blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Stack(children: [
                // Symbole décoratif en fond
                Positioned(right: -8, top: -8,
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.08)),
                  )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Heure + badge actif
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.18),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.school_rounded,
                              size: 14, color: Colors.white),
                        ),
                        if (isFirst)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.22),
                              borderRadius: BorderRadius.circular(5)),
                            child: const Text('Actif',
                                style: TextStyle(color: Colors.white,
                                    fontSize: 7, fontWeight: FontWeight.w900)),
                          ),
                      ]),
                      // Matière + heure
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.sub,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w900, height: 1.2),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.access_time_rounded,
                              size: 10, color: Color(0xCCFFFFFF)),
                          const SizedBox(width: 3),
                          Text(s.h,
                              style: const TextStyle(color: Color(0xCCFFFFFF),
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                        ]),
                        if (s.room.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.room_outlined,
                                size: 10, color: Color(0xAAFFFFFF)),
                            const SizedBox(width: 3),
                            Text(s.room,
                                style: const TextStyle(color: Color(0xAAFFFFFF),
                                    fontSize: 9)),
                          ]),
                        ],
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Grille statistiques — données dynamiques uniquement (header géré par parent)
// ══════════════════════════════════════════════════════════════════════════
class _StatsGrid extends StatelessWidget {
  final List<SbGrade> grades;
  final List<SbGrade> graded; // trié chronologiquement
  final int absences;
  final double maxScore, k;

  const _StatsGrid({
    required this.grades,
    required this.graded,
    required this.absences,
    required this.maxScore,
    required this.k,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ── Calculs ──
    final isEmpty = grades.isEmpty;

    final best = isEmpty ? null
        : grades.reduce((a, b) => a.outOf20 > b.outOf20 ? a : b);
    final worst = isEmpty ? null
        : grades.reduce((a, b) => a.outOf20 < b.outOf20 ? a : b);

    // Meilleure matière (moyenne par matière)
    final bySubject = <String, List<double>>{};
    for (final g in grades) {
      final s = g.subjectName ?? '—';
      (bySubject[s] ??= []).add(g.outOf20);
    }
    String? bestSubject;
    double bestSubjectAvg = 0;
    for (final e in bySubject.entries) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      if (avg > bestSubjectAvg) {
        bestSubjectAvg = avg;
        bestSubject = e.key;
      }
    }

    // Notes au-dessus de la moyenne générale
    final avg20 = isEmpty ? 0.0
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;
    final aboveAvg = grades.where((g) => g.outOf20 > avg20).length;

    // Tendance : compare les 3 dernières aux 3 précédentes
    String trendLabel = '—';
    Color trendColor = cs.onSurface.withOpacity(.5);
    IconData trendIcon = Icons.remove_rounded;
    if (graded.length >= 4) {
      final half = graded.length ~/ 2;
      final recent = graded.sublist(graded.length - half);
      final older  = graded.sublist(0, half);
      final rAvg = recent.fold<double>(0, (s, g) => s + g.outOf20) / recent.length;
      final oAvg = older.fold<double>(0,  (s, g) => s + g.outOf20) / older.length;
      final diff = rAvg - oAvg;
      if (diff > 0.3) {
        trendLabel = '+${diff.toStringAsFixed(1)} pts';
        trendColor = _green;
        trendIcon  = Icons.trending_up_rounded;
      } else if (diff < -0.3) {
        trendLabel = '${diff.toStringAsFixed(1)} pts';
        trendColor = _terra;
        trendIcon  = Icons.trending_down_rounded;
      } else {
        trendLabel = 'Stable';
        trendColor = _gold;
        trendIcon  = Icons.trending_flat_rounded;
      }
    }

    final stats = [
      _StatItem(
        icon: Icons.emoji_events_rounded,
        color: _gold,
        label: 'Meilleure note',
        value: isEmpty ? '—'
            : '${(best!.outOf20 * k).toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
        sub: best?.subjectName,
      ),
      _StatItem(
        icon: Icons.arrow_downward_rounded,
        color: _terra,
        label: 'Note la plus basse',
        value: isEmpty ? '—'
            : '${(worst!.outOf20 * k).toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}',
        sub: worst?.subjectName,
      ),
      _StatItem(
        icon: Icons.star_half_rounded,
        color: _green,
        label: 'Point fort',
        value: bestSubject ?? '—',
        sub: bestSubject != null
            ? 'moy. ${(bestSubjectAvg * k).toStringAsFixed(1)}'
            : null,
        compact: true,
      ),
      _StatItem(
        icon: Icons.check_circle_outline_rounded,
        color: _cyan,
        label: 'Au-dessus moy.',
        value: isEmpty ? '—' : '$aboveAvg/${grades.length}',
        sub: isEmpty ? null : 'notes',
      ),
      _StatItem(
        icon: trendIcon,
        color: trendColor,
        label: 'Tendance',
        value: trendLabel,
        sub: graded.length < 4 ? 'pas assez de notes' : 'récent vs précédent',
      ),
      _StatItem(
        icon: Icons.event_busy_rounded,
        color: absences == 0 ? _green : _orange,
        label: 'Absences',
        value: '$absences',
        sub: absences > 1 ? 'jours' : 'jour',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _StatCard(item: stats[i]),
    );
  }
}

class _StatItem {
  final IconData icon;
  final Color color;
  final String label, value;
  final String? sub;
  final bool compact;
  const _StatItem({
    required this.icon, required this.color,
    required this.label, required this.value,
    this.sub, this.compact = false,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: item.color.withOpacity(.18)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(.03),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: item.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(7)),
            child: Icon(item.icon, color: item.color, size: 13),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(item.label, style: TextStyle(
              color: cs.onSurface.withOpacity(.5),
              fontSize: 9, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const Spacer(),
        Text(item.value,
            style: TextStyle(
                color: cs.onSurface, fontSize: item.compact ? 12 : 15,
                fontWeight: FontWeight.w900, height: 1.1),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (item.sub != null)
          Text(item.sub!, style: TextStyle(
              color: cs.onSurface.withOpacity(.4),
              fontSize: 9, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Note row
// ══════════════════════════════════════════════════════════════════════════
class _NoteRow extends StatelessWidget {
  final String sub, date;
  final double note, max;
  final Color color;
  final VoidCallback onTap;
  const _NoteRow({required this.sub, required this.note, required this.max,
      required this.date, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = note / max;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.themedCard(context, radius: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(width: 46, height: 46,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 46, height: 46,
                child: CircularProgressIndicator(
                  value: pct, strokeWidth: 4,
                  backgroundColor: color.withOpacity(.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(note.toStringAsFixed(1),
                  style: TextStyle(color: color,
                      fontSize: 11, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: TextStyle(
                color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 5,
                backgroundColor: color.withOpacity(.10),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ])),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: (pct >= 0.7 ? _green : _terra).withOpacity(.10),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(pct >= 0.7 ? '✓ Bien' : '→ Effort',
                  style: TextStyle(
                      color: pct >= 0.7 ? _green : _terra,
                      fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(date, style: TextStyle(
                color: cs.onSurface.withOpacity(.45), fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}
