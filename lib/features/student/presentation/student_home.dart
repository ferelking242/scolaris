import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/sources/remote/supabase_db_source.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../shared/data/features_catalog.dart';
import '../../../shared/data/timetable_data.dart' show getSubjectMeta;
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/pages/settings_page.dart';
import '../../../shared/widgets/plan_gate.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/surface.dart';
import 'primary_student_home.dart' show PrimaryDashboard;
import 'pages/annales_quiz_page.dart';
import 'pages/attendance_page.dart';
import 'pages/bulletin_page.dart';
import 'pages/cahier_liaison_page.dart';
import 'pages/cahier_textes_page.dart';
import 'pages/carnet_recompenses_page.dart';
import 'pages/carte_etudiante_page.dart';
import 'pages/courses_page.dart';
import 'pages/menu_cantine_page.dart';
import 'pages/grades_page.dart';
import 'pages/inscription_ue_page.dart';
import 'pages/library/library_page.dart';
import 'pages/notifications_page.dart';
import 'pages/prepa_bac_page.dart';
import 'pages/releve_ects_page.dart';
import 'pages/schedule_page.dart';
import 'pages/simulateur_moyenne_page.dart';
import 'pages/student_documents_page.dart';
import 'pages/student_payments_page.dart';

// Brand colors — toujours utilisés comme accents colorés, jamais comme fond
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _dark   = ScolarisPalette.darkBrown;
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
    final planCode = ref.watch(currentPlanCodeProvider).valueOrNull;

    return ResponsiveRoleShell(
      role: UserRole.student,
      title: 'Scolaris',
      groups: _groups(level: level, planCode: planCode),
    );
  }

  List<RoleNavGroup> _groups({
    required SchoolLevel level,
    required String? planCode,
  }) {
    final isPrimaire = level == SchoolLevel.primaire;
    final hasBulletin = level == SchoolLevel.primaire ||
        level == SchoolLevel.college || level == SchoolLevel.lycee;
    final isCollege = level == SchoolLevel.college;
    final isLycee   = level == SchoolLevel.lycee;
    final isUniv    = level == SchoolLevel.universite ||
                      level == SchoolLevel.master ||
                      level == SchoolLevel.doctorat;
    final isCollegeOrLycee = isCollege || isLycee;

    // Dashboard : variante « enfant » en primaire, sinon le dashboard standard.
    final Widget dashboard =
        isPrimaire ? const PrimaryDashboard() : const _StudentDashboard();

    return [
      // ── Accueil ───────────────────────────────────────────────────────────
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

      // ── Scolarité ─────────────────────────────────────────────────────────
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
        if (hasBulletin)
          const RoleNavEntry(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            labelKey: 'nav.bulletin',
            page: BulletinPage(),
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

      // ── Outils Lycée ──────────────────────────────────────────────────────
      if (isLycee)
        const RoleNavGroup(labelKey: 'sections.learning', entries: [
          RoleNavEntry(
            icon: Icons.school_outlined,
            activeIcon: Icons.school_rounded,
            labelKey: 'nav.prepa_bac',
            page: PrepaBacPage(),
          ),
        ]),

      // ── Outils primaire ───────────────────────────────────────────────────
      if (isPrimaire)
        const RoleNavGroup(labelKey: 'sections.primary_tools', entries: [
          RoleNavEntry(
            icon: Icons.import_contacts_outlined,
            activeIcon: Icons.import_contacts_rounded,
            labelKey: 'nav.cahier_liaison',
            page: CahierLiaisonPage(),
          ),
          RoleNavEntry(
            icon: Icons.restaurant_outlined,
            activeIcon: Icons.restaurant_rounded,
            labelKey: 'nav.menu_cantine',
            page: MenuCantinePage(),
          ),
          RoleNavEntry(
            icon: Icons.emoji_events_outlined,
            activeIcon: Icons.emoji_events_rounded,
            labelKey: 'nav.recompenses',
            page: CarnetRecompensesPage(),
          ),
        ]),

      // ── Université ────────────────────────────────────────────────────────
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

      // ── Finance & Documents ───────────────────────────────────────────────
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

      // ── Compte ────────────────────────────────────────────────────────────
      const RoleNavGroup(labelKey: 'sections.account', entries: [
        RoleNavEntry(
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications_rounded,
          labelKey: 'nav.notifications',
          page: NotificationsPage(),
        ),
        RoleNavEntry(
          icon: Icons.chat_outlined,
          activeIcon: Icons.chat_rounded,
          labelKey: 'nav.messages',
          page: PlanGate(
            minPlan: 'pro',
            featureLabel: 'Messagerie',
            description: 'Chat interne sécurisé avec l\'école.',
            child: MessagingPage(),
          ),
        ),
        RoleNavEntry(
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
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final user   = ref.watch(authSessionProvider);
    final name   = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);

    final level   = ref.watch(studentSchoolLevelProvider).valueOrNull
        ?? SchoolLevel.lycee;
    final profile = ref.watch(myStudentProfileProvider).valueOrNull;
    final hasBulletin =
        level == SchoolLevel.college || level == SchoolLevel.lycee;

    final gradesAsync = ref.watch(myGradesProvider);
    final grades      = gradesAsync.valueOrNull ?? const <SbGrade>[];
    final absences    = ref.watch(myAbsencesProvider).valueOrNull ?? const <SbAbsence>[];

    final classId = profile?.classId;
    final scheduleAsync = (classId != null && classId.isNotEmpty)
        ? ref.watch(schedulesForClassProvider(classId))
        : const AsyncValue<List<SbSchedule>>.data([]);
    final schedules = scheduleAsync.valueOrNull ?? const <SbSchedule>[];

    final loading = gradesAsync.isLoading || scheduleAsync.isLoading;

    final moyenne = grades.isEmpty
        ? null
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;

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

    final graded = [...grades]..sort((a, b) =>
        (a.gradedAt ?? DateTime(2000)).compareTo(b.gradedAt ?? DateTime(2000)));
    final running = <double>[];
    double acc = 0;
    for (var i = 0; i < graded.length; i++) {
      acc += graded[i].outOf20;
      running.add(acc / (i + 1));
    }
    final progression =
        running.length > 6 ? running.sublist(running.length - 6) : running;
    final progLabels = List.generate(progression.length, (i) => '${i + 1}');

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

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
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
              moyenne: moyenne,
            ),
            const SizedBox(height: 16),

            // ── 2. Stats rapides ──────────────────────────────────────
            Skeletonizer(
              enabled: loading, effect: shimmer,
              child: _QuickStats(
                loading: loading,
                moyenne: moyenne,
                absences: absences.length,
                notes: grades.length,
              ),
            ),
            const SizedBox(height: 22),

            // ── 3. Accès rapide ───────────────────────────────────────
            _SectionHeader(
              icon: Icons.apps_rounded,
              title: 'Accès rapide',
              accentColor: _terra,
            ),
            const SizedBox(height: 10),
            _PremiumShortcutsGrid(
              showBulletin: hasBulletin,
              onTap: {
                'notes':         () => _push(const GradesPage()),
                'edt':           () => _push(const SchedulePage()),
                'presences':     () => _push(const AttendancePage()),
                'cours':         () => _push(const CoursesPage()),
                'messages':      () => _push(const MessagingPage()),
                if (hasBulletin)
                  'bulletin':    () => _push(const BulletinPage()),
                'bibliotheque':  () => _push(const PlanGate(
                      minPlan: 'pro',
                      featureLabel: 'Bibliothèque',
                      description: 'Catalogue, manuels et bibliothèque numérique.',
                      child: LibraryPage(),
                    )),
                'notifications': () => _push(const NotificationsPage()),
                'simulateur':    () => _push(const SimulateurMoyennePage()),
                'annales':       () => _push(const AnnalesQuizPage()),
              },
            ),
            const SizedBox(height: 24),

            // ── 4. EDT + Progression (2 cols sur desktop) ─────────────
            if (isWide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _buildEdtSection(edt, loading, shimmer)),
                const SizedBox(width: 16),
                Expanded(child: _buildNotesChartSection(progression, progLabels, loading, shimmer)),
              ])
            else ...[
              _buildEdtSection(edt, loading, shimmer),
              const SizedBox(height: 22),
              _buildNotesChartSection(progression, progLabels, loading, shimmer),
            ],
            const SizedBox(height: 22),

            // ── 5. Dernières notes ─────────────────────────────────────
            _buildRecentNotesSection(recent, loading, shimmer),
          ]);
        }),
      ),
    );
  }

  static const _edtSkeleton = [
    (h: '08:00', sub: 'Cours', room: 'A1', c: _terra),
    (h: '10:00', sub: 'Cours', room: 'B2', c: _gold),
    (h: '14:00', sub: 'Cours', room: 'C3', c: _green),
  ];
  static const _progSkeleton = [12.0, 13.0, 13.5, 14.0, 14.5, 15.0];
  static const _progSkeletonLabels = ['1', '2', '3', '4', '5', '6'];

  Widget _buildEdtSection(
      List<({String h, String sub, String room, Color c})> edt,
      bool loading,
      ShimmerEffect shimmer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.calendar_today_rounded,
          title: 'Emploi du temps du jour',
          accentColor: _terra,
          action: 'Tout voir',
          onAction: () => _push(const SchedulePage()),
        ),
        const SizedBox(height: 10),
        if (!loading && edt.isEmpty)
          _MiniEmpty(icon: Icons.event_available_rounded, label: 'Pas de cours aujourd\'hui')
        else
          Skeletonizer(
            enabled: loading, effect: shimmer,
            child: _EdtTimeline(slots: loading ? _edtSkeleton : edt),
          ),
      ],
    );
  }

  Widget _buildNotesChartSection(
      List<double> values, List<String> labels, bool loading,
      ShimmerEffect shimmer) {
    if (!loading && values.length < 2) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        _MiniEmpty(icon: Icons.show_chart_rounded, label: 'Pas assez de notes pour la courbe'),
      ]);
    }
    return Skeletonizer(
      enabled: loading, effect: shimmer,
      child: _NoteProgressionChart(
        values: loading ? _progSkeleton : values,
        labels: loading ? _progSkeletonLabels : labels,
      ),
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
          onAction: () => _push(const GradesPage()),
        ),
        const SizedBox(height: 10),
        if (!loading && recent.isEmpty)
          const _MiniEmpty(icon: Icons.grading_rounded, label: 'Aucune note pour l\'instant')
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
                  onTap: () => _push(const GradesPage()),
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
// Hero Banner — remplace SlimGreeting
// ══════════════════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  final String greeting, name, initials;
  final bool loading;
  final String? classLabel;
  final String? levelLabel;
  final double? moyenne;
  const _HeroBanner({
    required this.greeting, required this.name,
    required this.initials, required this.loading,
    this.classLabel, this.levelLabel, this.moyenne,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        // Décoration en fond
        Positioned(right: -10, top: -20,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.04),
            ),
          ),
        ),
        Positioned(right: 50, bottom: -15,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withOpacity(.08),
            ),
          ),
        ),
        // Contenu principal
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
          // Nom + classe
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
          // Moyenne
          if (!loading && moyenne != null)
            Column(children: [
              Text(moyenne!.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -1)),
              Text('/20', style: TextStyle(
                  color: Colors.white.withOpacity(.55), fontSize: 11)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (moyenne! >= 14 ? _green : moyenne! >= 10 ? _gold : _terra)
                      .withOpacity(.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: (moyenne! >= 14 ? _green : moyenne! >= 10 ? _gold : _terra)
                          .withOpacity(.5)),
                ),
                child: Text(
                  moyenne! >= 14 ? '✓ Bien' : moyenne! >= 10 ? '→ OK' : 'Effort',
                  style: TextStyle(
                      color: moyenne! >= 14 ? _green : moyenne! >= 10 ? _gold : Colors.white,
                      fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
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
// Stats rapides
// ══════════════════════════════════════════════════════════════════════════
class _QuickStats extends StatelessWidget {
  final bool loading;
  final double? moyenne;
  final int absences, notes;
  const _QuickStats({
    required this.loading, required this.moyenne,
    required this.absences, required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = [
      (icon: Icons.star_rounded, label: 'Moyenne',
       val: loading ? '00.0' : (moyenne?.toStringAsFixed(1) ?? '—'),
       sub: '/20', c: _gold),
      (icon: Icons.event_busy_rounded, label: 'Absences',
       val: loading ? '0' : '$absences',
       sub: absences > 1 ? ' jours' : ' jour',
       c: absences == 0 ? _green : _terra),
      (icon: Icons.grading_rounded, label: 'Notes',
       val: loading ? '0' : '$notes', sub: ' reçues', c: _orange),
    ];
    return Row(children: [
      for (int i = 0; i < data.length; i++) ...[
        Expanded(child: _QuickStatPill(d: data[i])),
        if (i < data.length - 1) const SizedBox(width: 8),
      ],
    ]);
  }
}

class _QuickStatPill extends StatelessWidget {
  final ({IconData icon, String label, String val, String sub, Color c}) d;
  const _QuickStatPill({required this.d});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
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
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: d.c.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(d.icon, color: d.c, size: 14),
        ),
        const SizedBox(height: 6),
        Text(d.label, style: TextStyle(
            color: cs.onSurface.withOpacity(.5),
            fontSize: 9.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        RichText(text: TextSpan(children: [
          TextSpan(text: d.val,
              style: TextStyle(color: cs.onSurface,
                  fontSize: 17, fontWeight: FontWeight.w900)),
          TextSpan(text: d.sub,
              style: TextStyle(color: cs.onSurface.withOpacity(.45), fontSize: 9.5)),
        ])),
      ]),
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
// Raccourcis
// ══════════════════════════════════════════════════════════════════════════
class _PremiumShortcutsGrid extends StatelessWidget {
  final Map<String, VoidCallback> onTap;
  final bool showBulletin;
  const _PremiumShortcutsGrid({required this.onTap, this.showBulletin = true});

  static const _items = [
    (key: 'notes',        icon: Icons.grading_rounded,          label: 'Notes',      c: _gold),
    (key: 'edt',          icon: Icons.calendar_month_rounded,   label: 'Emploi',     c: _terra),
    (key: 'presences',    icon: Icons.fact_check_rounded,       label: 'Présences',  c: _green),
    (key: 'cours',        icon: Icons.menu_book_rounded,        label: 'Cours',      c: _terra),
    (key: 'bulletin',     icon: Icons.receipt_long_rounded,     label: 'Bulletin',   c: _gold),
    (key: 'bibliotheque', icon: Icons.local_library_rounded,    label: 'Biblio.',    c: _green),
    (key: 'notifications',icon: Icons.notifications_rounded,    label: 'Alertes',    c: _orange),
    (key: 'messages',     icon: Icons.chat_rounded,             label: 'Messages',   c: _cyan),
    (key: 'simulateur',   icon: Icons.calculate_rounded,        label: 'Simulateur', c: _gold),
    (key: 'annales',      icon: Icons.quiz_rounded,             label: 'Quiz',       c: _terra),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items
        .where((i) => i.key != 'bulletin' || showBulletin)
        .toList();
    return LayoutBuilder(builder: (_, c) {
      final isWide = c.maxWidth > 600;
      final cols  = isWide ? 5 : 3;
      final ratio = isWide ? 2.0 : 1.35;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: ratio,
        children: items.map((item) =>
            _ShortcutCard(item: item, onTap: onTap[item.key])).toList(),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.c.withOpacity(.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: item.c.withOpacity(.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, color: item.c, size: 17),
              ),
              const SizedBox(height: 6),
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
// EDT du jour
// ══════════════════════════════════════════════════════════════════════════
class _EdtTimeline extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> slots;
  const _EdtTimeline({required this.slots});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = slots[i];
          final first = i == 0;
          return Container(
            width: 92,
            decoration: first
                ? BoxDecoration(
                    gradient: LinearGradient(
                        colors: [s.c, s.c.withOpacity(0.72)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: s.c.withOpacity(.35),
                        blurRadius: 12, offset: const Offset(0, 5))],
                  )
                : BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: s.c.withOpacity(.35)),
                  ),
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: first ? Colors.white.withOpacity(.22) : s.c.withOpacity(.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.school_rounded, size: 14,
                        color: first ? Colors.white : s.c),
                  ),
                  if (first)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.22),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Actif', style: TextStyle(
                          color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
                    ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.sub, style: TextStyle(
                      color: first ? Colors.white : cs.onSurface,
                      fontSize: 11, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(s.h, style: TextStyle(
                      color: first ? Colors.white.withOpacity(.8) : s.c,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Courbe progression des notes
// ══════════════════════════════════════════════════════════════════════════
class _NoteProgressionChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _NoteProgressionChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final trend = values.last - values.first;
    final trendUp = trend >= 0;
    final trendColor = trendUp ? _green : _terra;

    return Container(
      decoration: ScolarisSurface.themedCard(context, radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Progression des notes', style: TextStyle(
              color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: trendColor.withOpacity(.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: trendColor.withOpacity(.30))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: trendColor, size: 13),
              const SizedBox(width: 4),
              Text('${trendUp ? '+' : ''}${trend.toStringAsFixed(1)} pts',
                  style: TextStyle(color: trendColor,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Moyenne sur ${values.length} semaines',
            style: TextStyle(color: cs.onSurface.withOpacity(.45), fontSize: 10)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: LineChart(LineChartData(
            minY: 8.0, maxY: 20.0,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              horizontalInterval: 4.0,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outline.withOpacity(.15), strokeWidth: 1.0)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 28.0,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: TextStyle(color: cs.onSurface.withOpacity(.45),
                        fontSize: 9, fontWeight: FontWeight.w600)),
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22.0,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Text(labels[i], style: TextStyle(
                      color: cs.onSurface.withOpacity(.45),
                      fontSize: 9, fontWeight: FontWeight.w600));
                },
              )),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots, isCurved: true, curveSmoothness: 0.35,
                color: _gold, barWidth: 2.5,
                dotData: FlDotData(show: true, getDotPainter: (s, _, __, ___) =>
                    FlDotCirclePainter(radius: 4.0, color: _gold,
                        strokeWidth: 2.0, strokeColor: cs.surfaceContainer)),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                  colors: [_gold.withOpacity(.20), _gold.withOpacity(.0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                )),
              ),
            ],
            lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8.0,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '${s.y}/20', const TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w700),
              )).toList(),
            )),
          )),
        ),
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

// ══════════════════════════════════════════════════════════════════════════
// Résumé présences (kept for reference, not used in current dashboard)
// ══════════════════════════════════════════════════════════════════════════
class _AttPresCell extends StatelessWidget {
  final IconData icon;
  final String label, val;
  final Color color;
  const _AttPresCell({required this.icon, required this.label,
      required this.val, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(child: Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
      Text(label, style: TextStyle(fontSize: 9.5,
          color: cs.onSurface.withOpacity(.45), fontWeight: FontWeight.w600)),
    ]));
  }
}
