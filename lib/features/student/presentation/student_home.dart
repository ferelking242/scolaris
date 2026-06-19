import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/sources/remote/supabase_db_source.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/pages/settings_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/surface.dart';
import 'pages/attendance_page.dart';
import 'pages/bulletin_page.dart';
import 'pages/courses_page.dart';
import 'pages/grades_page.dart';
import 'pages/homework_student_page.dart';
import 'pages/library/library_page.dart';
import 'pages/schedule_page.dart';
import 'pages/student_documents_page.dart';
import 'pages/student_payments_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _dark   = ScolarisPalette.darkBrown;
const _cyan   = Color(0xFF0891B2);
const _purple = Color(0xFF7C3AED);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFEDD8BE);

// ══════════════════════════════════════════════════════════════════════════
// Shell (navigation)
// ══════════════════════════════════════════════════════════════════════════
class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.student,
      title: 'Scolaris',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(
            icon: Icons.home_rounded,
            activeIcon: Icons.home_rounded,
            labelKey: 'nav.dashboard',
            page: _StudentDashboard(),
          ),
          RoleNavEntry(
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book_rounded,
            labelKey: 'nav.courses',
            page: CoursesPage(),
          ),
        ]),

        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(
            icon: Icons.grading_outlined,
            activeIcon: Icons.grading_rounded,
            labelKey: 'nav.grades',
            page: GradesPage(),
          ),
          RoleNavEntry(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            labelKey: 'nav.schedule',
            page: SchedulePage(),
          ),
          RoleNavEntry(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment_rounded,
            labelKey: 'nav.homework',
            page: HomeworkStudentPage(),
          ),
          RoleNavEntry(
            icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check_rounded,
            labelKey: 'nav.attendance',
            page: AttendancePage(),
          ),
          RoleNavEntry(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            labelKey: 'nav.bulletin',
            page: BulletinPage(),
          ),
          RoleNavEntry(
            icon: Icons.local_library_outlined,
            activeIcon: Icons.local_library_rounded,
            labelKey: 'nav.library',
            page: LibraryPage(),
          ),
        ]),

        RoleNavGroup(labelKey: 'sections.finance', entries: [
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
          RoleNavEntry(
            icon: Icons.chat_outlined,
            activeIcon: Icons.chat_rounded,
            labelKey: 'nav.messages',
            page: MessagingPage(),
          ),
          RoleNavEntry(
            icon: Icons.apps_outlined,
            activeIcon: Icons.apps_rounded,
            labelKey: 'nav.features',
            page: FeaturesHubPage(),
          ),
          RoleNavEntry(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            labelKey: 'nav.settings',
            page: SettingsPage(),
          ),
        ]),
      ],
    );
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

  // EDT EMI — Ferel Ondongo (aujourd'hui = Jeudi par défaut si hors semaine)
  static const _edt = [
    (h: '07h30', sub: 'Chimie',            room: 'L-002',      c: _green),
    (h: '09h15', sub: 'Électronique',      room: 'Labo Élec',  c: _gold),
    (h: '11h00', sub: 'Histoire-Géo',      room: 'C-201',      c: Color(0xFFDB2777)),
    (h: '14h00', sub: 'Philosophie',       room: 'B-201',      c: Color(0xFF78716C)),
    (h: '15h45', sub: 'Anglais',           room: 'B-101',      c: _cyan),
  ];

  // Devoirs EMI — Ferel Ondongo
  static const _devoirs = [
    (sub: 'Mathématiques',   titre: 'Intégrales — Exercices 8.4-8.7',         echeance: 'Demain',   c: _gold),
    (sub: 'Électronique',    titre: 'Rapport TP — Circuits RLC',               echeance: 'Dans 2j',  c: _cyan),
    (sub: 'Algorithmique',   titre: 'Programme tri rapide en Python',          echeance: 'Dans 3j',  c: _purple),
    (sub: 'Sciences Phys.',  titre: 'Compte-rendu — Lois de Kirchhoff',       echeance: 'Dans 5j',  c: _green),
  ];

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  String _initials(String name) {
    final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return 'E';
    if (p.length == 1) return p[0][0].toUpperCase();
    return (p[0][0] + p[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authSessionProvider);
    final name     = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);

    final gradesAsync  = ref.watch(myGradesProvider);
    final absAsync     = ref.watch(myAbsencesProvider);
    final announceAsync= ref.watch(announcementsProvider);
    final profileAsync = ref.watch(myStudentProfileProvider);

    final grades  = gradesAsync.value ?? <SbGrade>[];
    final absences= absAsync.value    ?? <SbAbsence>[];
    final annonces= announceAsync.value ?? <SbAnnouncement>[];
    final profile = profileAsync.value;

    final avg = grades.isEmpty
        ? 0.0
        : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;

    final absents = absences.where((a) => a.status == 'absent').length;
    final retards = absences.where((a) => a.status == 'late').length;
    const joursTotal = 90;
    final presents   = (joursTotal - absents - retards).clamp(0, joursTotal);
    final tauxPres   = joursTotal > 0 ? (presents / joursTotal * 100) : 0.0;

    final recentGrades = grades.take(3).toList();

    final isLoadingGrades  = gradesAsync.isLoading;
    final isLoadingAbs     = absAsync.isLoading;
    final isLoadingAnn     = announceAsync.isLoading;

    final classeLabel = profile?.classe ?? profile?.niveau ?? 'Tle EMI';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          final isDesktop = w > 900;
          final isTablet  = w > 600;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── 1. Greeting ──────────────────────────────────────────────
            _SlimGreeting(
              greeting: _greeting,
              name: name,
              initials: initials,
              classeLabel: classeLabel,
              loading: isLoadingGrades,
            ),
            const SizedBox(height: 18),

            // ── 2. Stats rapides (données réelles) ───────────────────────
            _QuickStatsRow(
              avg: avg,
              tauxPresence: tauxPres,
              devoirsEnCours: _devoirs.length,
              loading: isLoadingGrades || isLoadingAbs,
            ),
            const SizedBox(height: 22),

            // ── 3. Accès rapide ──────────────────────────────────────────
            _SectionHeader(
              icon: Icons.apps_rounded,
              title: 'Accès rapide',
              iconGradient: [_terra, _orange],
            ),
            const SizedBox(height: 10),
            _PremiumShortcutsGrid(onTap: {
              'notes':         () => _push(const GradesPage()),
              'edt':           () => _push(const SchedulePage()),
              'devoirs':       () => _push(const HomeworkStudentPage()),
              'presences':     () => _push(const AttendancePage()),
              'cours':         () => _push(const CoursesPage()),
              'messages':      () => _push(const MessagingPage()),
              'bulletin':      () => _push(const BulletinPage()),
              'bibliotheque':  () => _push(const LibraryPage()),
              'features':      () => _push(const FeaturesHubPage()),
            }),
            const SizedBox(height: 24),

            // ── 4. Layout principal (1, 2 ou 3 colonnes) ────────────────
            if (isDesktop)
              _DesktopLayout(
                absences: absences,
                recentGrades: recentGrades,
                grades: grades,
                avg: avg,
                devoirs: _devoirs,
                edt: _edt,
                annonces: annonces,
                isLoadingGrades: isLoadingGrades,
                isLoadingAbs: isLoadingAbs,
                isLoadingAnn: isLoadingAnn,
                onNavigate: _push,
              )
            else if (isTablet)
              _TabletLayout(
                absences: absences,
                recentGrades: recentGrades,
                grades: grades,
                avg: avg,
                devoirs: _devoirs,
                edt: _edt,
                annonces: annonces,
                isLoadingGrades: isLoadingGrades,
                isLoadingAbs: isLoadingAbs,
                isLoadingAnn: isLoadingAnn,
                onNavigate: _push,
              )
            else
              _MobileLayout(
                absences: absences,
                recentGrades: recentGrades,
                grades: grades,
                avg: avg,
                devoirs: _devoirs,
                edt: _edt,
                annonces: annonces,
                isLoadingGrades: isLoadingGrades,
                isLoadingAbs: isLoadingAbs,
                isLoadingAnn: isLoadingAnn,
                onNavigate: _push,
              ),
          ]);
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Layouts
// ══════════════════════════════════════════════════════════════════════════

class _DesktopLayout extends StatelessWidget {
  final List<SbAbsence> absences;
  final List<SbGrade> recentGrades, grades;
  final double avg;
  final List<({String sub, String titre, String echeance, Color c})> devoirs;
  final List<({String h, String sub, String room, Color c})> edt;
  final List<SbAnnouncement> annonces;
  final bool isLoadingGrades, isLoadingAbs, isLoadingAnn;
  final void Function(Widget) onNavigate;

  const _DesktopLayout({
    required this.absences, required this.recentGrades, required this.grades,
    required this.avg, required this.devoirs, required this.edt,
    required this.annonces, required this.isLoadingGrades,
    required this.isLoadingAbs, required this.isLoadingAnn,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Colonne gauche
      Expanded(flex: 2, child: Column(children: [
        _EdtSection(edt: edt, loading: isLoadingGrades, onNavigate: onNavigate),
        const SizedBox(height: 16),
        _DevoirsSection(devoirs: devoirs, loading: false, onNavigate: onNavigate),
        const SizedBox(height: 16),
        _AttendanceSummaryWidget(absences: absences, loading: isLoadingAbs, onNavigate: onNavigate),
      ])),
      const SizedBox(width: 16),
      // Colonne centre
      Expanded(flex: 3, child: Column(children: [
        _NotesProgressionSection(grades: grades, avg: avg, loading: isLoadingGrades, onNavigate: onNavigate),
        const SizedBox(height: 16),
        _RecentNotesSection(recentGrades: recentGrades, loading: isLoadingGrades, onNavigate: onNavigate),
      ])),
      const SizedBox(width: 16),
      // Colonne droite
      Expanded(flex: 2, child: Column(children: [
        _AnnoncesSection(annonces: annonces, loading: isLoadingAnn),
        const SizedBox(height: 16),
        const _WeeklyStatsCard(),
      ])),
    ]);
  }
}

class _TabletLayout extends StatelessWidget {
  final List<SbAbsence> absences;
  final List<SbGrade> recentGrades, grades;
  final double avg;
  final List<({String sub, String titre, String echeance, Color c})> devoirs;
  final List<({String h, String sub, String room, Color c})> edt;
  final List<SbAnnouncement> annonces;
  final bool isLoadingGrades, isLoadingAbs, isLoadingAnn;
  final void Function(Widget) onNavigate;

  const _TabletLayout({
    required this.absences, required this.recentGrades, required this.grades,
    required this.avg, required this.devoirs, required this.edt,
    required this.annonces, required this.isLoadingGrades,
    required this.isLoadingAbs, required this.isLoadingAnn,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _EdtSection(edt: edt, loading: isLoadingGrades, onNavigate: onNavigate)),
        const SizedBox(width: 16),
        Expanded(child: _NotesProgressionSection(grades: grades, avg: avg, loading: isLoadingGrades, onNavigate: onNavigate)),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _DevoirsSection(devoirs: devoirs, loading: false, onNavigate: onNavigate)),
        const SizedBox(width: 16),
        Expanded(child: _AttendanceSummaryWidget(absences: absences, loading: isLoadingAbs, onNavigate: onNavigate)),
      ]),
      const SizedBox(height: 16),
      _RecentNotesSection(recentGrades: recentGrades, loading: isLoadingGrades, onNavigate: onNavigate),
      const SizedBox(height: 16),
      _AnnoncesSection(annonces: annonces, loading: isLoadingAnn),
    ]);
  }
}

class _MobileLayout extends StatelessWidget {
  final List<SbAbsence> absences;
  final List<SbGrade> recentGrades, grades;
  final double avg;
  final List<({String sub, String titre, String echeance, Color c})> devoirs;
  final List<({String h, String sub, String room, Color c})> edt;
  final List<SbAnnouncement> annonces;
  final bool isLoadingGrades, isLoadingAbs, isLoadingAnn;
  final void Function(Widget) onNavigate;

  const _MobileLayout({
    required this.absences, required this.recentGrades, required this.grades,
    required this.avg, required this.devoirs, required this.edt,
    required this.annonces, required this.isLoadingGrades,
    required this.isLoadingAbs, required this.isLoadingAnn,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _EdtSection(edt: edt, loading: isLoadingGrades, onNavigate: onNavigate),
      const SizedBox(height: 16),
      _DevoirsSection(devoirs: devoirs, loading: false, onNavigate: onNavigate),
      const SizedBox(height: 16),
      _AttendanceSummaryWidget(absences: absences, loading: isLoadingAbs, onNavigate: onNavigate),
      const SizedBox(height: 16),
      _NotesProgressionSection(grades: grades, avg: avg, loading: isLoadingGrades, onNavigate: onNavigate),
      const SizedBox(height: 16),
      _RecentNotesSection(recentGrades: recentGrades, loading: isLoadingGrades, onNavigate: onNavigate),
      const SizedBox(height: 16),
      _AnnoncesSection(annonces: annonces, loading: isLoadingAnn),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Sections extraites
// ══════════════════════════════════════════════════════════════════════════

class _EdtSection extends StatelessWidget {
  final List<({String h, String sub, String room, Color c})> edt;
  final bool loading;
  final void Function(Widget) onNavigate;
  const _EdtSection({required this.edt, required this.loading, required this.onNavigate});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        icon: Icons.calendar_today_rounded,
        title: 'Emploi du temps',
        iconGradient: [_terra, _orange],
        action: 'Tout voir',
        onAction: () => onNavigate(const SchedulePage()),
      ),
      const SizedBox(height: 10),
      Skeletonizer(
        enabled: loading,
        effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
        child: _EdtTimeline(slots: edt),
      ),
    ],
  );
}

class _DevoirsSection extends StatelessWidget {
  final List<({String sub, String titre, String echeance, Color c})> devoirs;
  final bool loading;
  final void Function(Widget) onNavigate;
  const _DevoirsSection({required this.devoirs, required this.loading, required this.onNavigate});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        icon: Icons.assignment_late_rounded,
        title: 'Devoirs à rendre',
        iconGradient: [_orange, const Color(0xFFBF360C)],
        action: 'Voir tout',
        onAction: () => onNavigate(const HomeworkStudentPage()),
      ),
      const SizedBox(height: 10),
      Skeletonizer(
        enabled: loading,
        effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
        child: Column(children: [
          for (final d in devoirs) ...[
            _DevoirCard(
              sub: d.sub, titre: d.titre,
              echeance: d.echeance, color: d.c,
              onTap: () => onNavigate(const HomeworkStudentPage()),
            ),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    ],
  );
}

class _AttendanceSummaryWidget extends StatelessWidget {
  final List<SbAbsence> absences;
  final bool loading;
  final void Function(Widget) onNavigate;
  const _AttendanceSummaryWidget({required this.absences, required this.loading, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final absents  = absences.where((a) => a.status == 'absent').length;
    final retards  = absences.where((a) => a.status == 'late').length;
    const joursTotal = 90;
    final presents = (joursTotal - absents - retards).clamp(0, joursTotal);
    final taux     = joursTotal > 0 ? (presents / joursTotal * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.fact_check_rounded,
          title: 'Présences',
          iconGradient: [_green, const Color(0xFF2E7D32)],
          action: 'Détail',
          onAction: () => onNavigate(const AttendancePage()),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
          child: GestureDetector(
            onTap: () => onNavigate(const AttendancePage()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: ScolarisSurface.card(radius: 14),
              child: Column(children: [
                Row(children: [
                  _AttCell(icon: Icons.check_circle_rounded, label: 'Présents',  val: '$presents', color: _green),
                  _AttDivider(),
                  _AttCell(icon: Icons.cancel_rounded,       label: 'Absents',   val: '$absents',  color: _terra),
                  _AttDivider(),
                  _AttCell(icon: Icons.access_time_rounded,  label: 'Retards',   val: '$retards',  color: _gold),
                  _AttDivider(),
                  _AttCell(icon: Icons.percent_rounded,      label: 'Taux',      val: '${taux.toStringAsFixed(0)}%', color: _cyan),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: taux / 100,
                    minHeight: 7,
                    backgroundColor: _terra.withOpacity(0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(_green),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text('${taux.toStringAsFixed(1)}% sur $joursTotal jours',
                      style: const TextStyle(color: _muted, fontSize: 10))),
                  const Text('Voir →', style: TextStyle(color: _terra, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesProgressionSection extends StatelessWidget {
  final List<SbGrade> grades;
  final double avg;
  final bool loading;
  final void Function(Widget) onNavigate;
  const _NotesProgressionSection({required this.grades, required this.avg, required this.loading, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final groupedByPeriod = <String, List<SbGrade>>{};
    for (final g in grades) {
      final key = g.period ?? 'T1';
      groupedByPeriod.putIfAbsent(key, () => []).add(g);
    }
    final periods = groupedByPeriod.keys.toList()..sort();
    final chartValues = periods.isEmpty
        ? [avg, avg]
        : periods.map((p) {
            final gs = groupedByPeriod[p]!;
            return gs.fold<double>(0, (s, g) => s + g.outOf20) / gs.length;
          }).toList();
    final chartLabels = periods.isEmpty ? ['T1', 'T2'] : periods;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.trending_up_rounded,
          title: 'Progression des notes',
          iconGradient: [_gold, const Color(0xFFF57F17)],
          action: 'Toutes',
          onAction: () => onNavigate(const GradesPage()),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
          child: _NoteProgressionChart(
            values: chartValues,
            labels: chartLabels,
            avgActuel: avg,
          ),
        ),
      ],
    );
  }
}

class _RecentNotesSection extends StatelessWidget {
  final List<SbGrade> recentGrades;
  final bool loading;
  final void Function(Widget) onNavigate;
  const _RecentNotesSection({required this.recentGrades, required this.loading, required this.onNavigate});

  // Notes récentes EMI — Ferel Ondongo (si Supabase vide)
  static const _mockNotes = [
    (sub: 'Mathématiques',      n: 17.5, max: 20.0, c: Color(0xFF6D28D9), d: '14 Jun'),
    (sub: 'Algorithmique',      n: 18.0, max: 20.0, c: Color(0xFF1E3A5F), d: '03 Jun'),
    (sub: 'Électronique',       n: 16.5, max: 20.0, c: Color(0xFFB45309), d: '06 Jun'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.grading_rounded,
          title: 'Dernières notes',
          iconGradient: [_gold, const Color(0xFFF57F17)],
          action: 'Toutes',
          onAction: () => onNavigate(const GradesPage()),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
          child: recentGrades.isEmpty
              ? Column(children: [
                  for (final n in _mockNotes) ...[
                    _NoteRow(sub: n.sub, note: n.n, max: n.max,
                        date: n.d, color: n.c, onTap: () => onNavigate(const GradesPage())),
                    const SizedBox(height: 8),
                  ],
                ])
              : Column(children: [
                  for (final g in recentGrades) ...[
                    _NoteRow(
                      sub: g.subjectName ?? g.title ?? 'Matière',
                      note: g.score, max: g.maxScore,
                      date: g.gradedAt != null
                          ? '${g.gradedAt!.day}/${g.gradedAt!.month}'
                          : '',
                      color: g.outOf20 >= 14 ? _green : g.outOf20 >= 10 ? _gold : _terra,
                      onTap: () => onNavigate(const GradesPage()),
                    ),
                    const SizedBox(height: 8),
                  ],
                ]),
        ),
      ],
    );
  }
}

class _AnnoncesSection extends StatelessWidget {
  final List<SbAnnouncement> annonces;
  final bool loading;
  const _AnnoncesSection({required this.annonces, required this.loading});

  static const _mockAnnonces = [
    (icon: Icons.event_note_rounded,  color: _terra,
     title: 'Examens de fin de trimestre',
     body:  'Les examens T2 auront lieu du 23 au 27 juin.',
     author: 'Direction', time: 'Il y a 2h'),
    (icon: Icons.calculate_rounded,   color: _gold,
     title: 'Nouveau programme de maths',
     body:  'Le chapitre 9 sur les probabilités est disponible.',
     author: 'M. Dupont', time: 'Il y a 5h'),
    (icon: Icons.park_rounded,        color: _green,
     title: 'Sortie botanique SVT',
     body:  'Autorisations parentales avant le 15 juin.',
     author: 'Dr. Yao', time: 'Hier'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.campaign_rounded,
          title: 'Annonces',
          iconGradient: [_purple, const Color(0xFF5B21B6)],
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
          child: annonces.isEmpty
              ? Column(children: [
                  for (final a in _mockAnnonces)
                    _AnnonceCard(
                      icon: a.icon, color: a.color,
                      title: a.title, body: a.body,
                      author: a.author, time: a.time,
                    ),
                ])
              : Column(children: [
                  for (final a in annonces.take(3))
                    _AnnonceCard(
                      icon: a.isPinned ? Icons.push_pin_rounded : Icons.campaign_rounded,
                      color: _purple,
                      title: a.title,
                      body: a.content ?? '',
                      author: a.authorName ?? 'Direction',
                      time: a.createdAt != null
                          ? '${a.createdAt!.day}/${a.createdAt!.month}'
                          : '',
                    ),
                ]),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Greeting slim
// ══════════════════════════════════════════════════════════════════════════
class _SlimGreeting extends StatelessWidget {
  final String greeting, name, initials, classeLabel;
  final bool loading;
  const _SlimGreeting({
    required this.greeting, required this.name,
    required this.initials, required this.classeLabel,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A0A00), _dark, _terra],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: _terra.withOpacity(0.30),
          blurRadius: 18, offset: const Offset(0, 6),
        )],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8A83A), _gold],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _white.withOpacity(0.25), width: 2),
            boxShadow: [BoxShadow(
              color: _gold.withOpacity(0.45),
              blurRadius: 10, offset: const Offset(0, 4),
            )],
          ),
          child: Center(child: Text(initials,
              style: const TextStyle(color: _dark, fontSize: 20, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting, style: TextStyle(color: _white.withOpacity(0.55), fontSize: 11)),
          Text(name, style: const TextStyle(color: _white,
              fontSize: 18, fontWeight: FontWeight.w900, height: 1.2)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withOpacity(0.45)),
            ),
            child: Text(classeLabel, style: const TextStyle(
                color: _gold, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text('Trimestre 2', style: TextStyle(
              color: _white.withOpacity(0.55), fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Stats rapides (données réelles)
// ══════════════════════════════════════════════════════════════════════════
class _QuickStatsRow extends StatelessWidget {
  final double avg, tauxPresence;
  final int devoirsEnCours;
  final bool loading;
  const _QuickStatsRow({
    required this.avg, required this.tauxPresence,
    required this.devoirsEnCours, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final avgColor = avg >= 14 ? _green : avg >= 10 ? _gold : _terra;
    final presColor = tauxPresence >= 90 ? _green : tauxPresence >= 75 ? _gold : _terra;

    final data = [
      (icon: Icons.star_rounded,         label: 'Moyenne',  val: avg > 0 ? avg.toStringAsFixed(1) : '—', sub: '/20',       c: avgColor),
      (icon: Icons.check_circle_rounded, label: 'Présence', val: tauxPresence > 0 ? '${tauxPresence.toStringAsFixed(0)}' : '—', sub: ' %', c: presColor),
      (icon: Icons.assignment_rounded,   label: 'Devoirs',  val: '$devoirsEnCours', sub: ' à rendre', c: _orange),
    ];

    return Row(children: [
      for (int i = 0; i < data.length; i++) ...[
        Expanded(child: Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
          child: _QuickStatCard(d: data[i]),
        )),
        if (i < data.length - 1) const SizedBox(width: 10),
      ],
    ]);
  }
}

class _QuickStatCard extends StatelessWidget {
  final ({IconData icon, String label, String val, String sub, Color c}) d;
  const _QuickStatCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: d.c.withOpacity(0.18)),
        boxShadow: [BoxShadow(
          color: d.c.withOpacity(0.08),
          blurRadius: 10, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: d.c.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(d.icon, color: d.c, size: 16),
        ),
        const SizedBox(height: 8),
        Text(d.label, style: const TextStyle(
            color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        RichText(text: TextSpan(children: [
          TextSpan(text: d.val,
              style: TextStyle(color: d.c, fontSize: 22, fontWeight: FontWeight.w900)),
          TextSpan(text: d.sub,
              style: const TextStyle(color: _muted, fontSize: 10)),
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
  final List<Color> iconGradient;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.iconGradient,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: iconGradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [BoxShadow(color: iconGradient.first.withOpacity(0.35),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: _white, size: 15),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: const TextStyle(
          fontSize: 14.5, color: _ink, fontWeight: FontWeight.w800,
          letterSpacing: -0.2))),
      if (action != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _terra.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(action!, style: const TextStyle(
                color: _terra, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Raccourcis
// ══════════════════════════════════════════════════════════════════════════
class _PremiumShortcutsGrid extends StatelessWidget {
  final Map<String, VoidCallback> onTap;
  const _PremiumShortcutsGrid({required this.onTap});

  static const _items = [
    (key: 'notes',        icon: Icons.grading_rounded,          label: 'Notes',      c: _gold),
    (key: 'edt',          icon: Icons.calendar_month_rounded,   label: 'Emploi',     c: _terra),
    (key: 'presences',    icon: Icons.fact_check_rounded,       label: 'Présences',  c: _green),
    (key: 'cours',        icon: Icons.menu_book_rounded,        label: 'Cours',      c: _terra),
    (key: 'devoirs',      icon: Icons.assignment_rounded,       label: 'Devoirs',    c: _orange),
    (key: 'bulletin',     icon: Icons.receipt_long_rounded,     label: 'Bulletin',   c: _gold),
    (key: 'bibliotheque', icon: Icons.local_library_rounded,    label: 'Biblio.',    c: _green),
    (key: 'messages',     icon: Icons.chat_rounded,             label: 'Messages',   c: _ink),
    (key: 'features',     icon: Icons.apps_rounded,             label: 'Tout',       c: _muted),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final isWide = c.maxWidth > 600;
      final cols  = isWide ? 5 : 3;
      final ratio = isWide ? 2.2 : 1.35;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: ratio,
        children: _items.map((item) =>
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
    return Material(
      color: _white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.c.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: item.c.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, color: item.c, size: 17),
              ),
              const SizedBox(height: 6),
              Text(item.label,
                  style: TextStyle(
                      color: _ink, fontSize: 11, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Progression des notes (graphe)
// ══════════════════════════════════════════════════════════════════════════
class _NoteProgressionChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double avgActuel;
  const _NoteProgressionChart({required this.values, required this.labels, required this.avgActuel});

  @override
  Widget build(BuildContext context) {
    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final trend = values.length >= 2 ? values.last - values.first : 0.0;
    final trendUp = trend >= 0;
    final avgColor = avgActuel >= 14 ? _green : avgActuel >= 10 ? _gold : _terra;

    return Container(
      decoration: ScolarisSurface.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Progression des notes', style: TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
            if (avgActuel > 0) ...[
              const SizedBox(height: 2),
              RichText(text: TextSpan(children: [
                const TextSpan(text: 'Moyenne : ', style: TextStyle(color: _muted, fontSize: 10)),
                TextSpan(text: '${avgActuel.toStringAsFixed(1)}/20',
                    style: TextStyle(color: avgColor, fontSize: 11, fontWeight: FontWeight.w800)),
              ])),
            ],
          ])),
          if (values.length >= 2) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: (trendUp ? _green : _terra).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (trendUp ? _green : _terra).withOpacity(0.30))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: trendUp ? _green : _terra, size: 13),
              const SizedBox(width: 4),
              Text('${trendUp ? '+' : ''}${trend.toStringAsFixed(1)} pts',
                  style: TextStyle(color: trendUp ? _green : _terra,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: LineChart(LineChartData(
            minY: 0.0, maxY: 20.0,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              horizontalInterval: 5.0,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: _ink.withOpacity(0.06), strokeWidth: 1.0)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 28.0,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w600)),
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22.0,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Text(labels[i], style: const TextStyle(
                      color: _muted, fontSize: 9, fontWeight: FontWeight.w600));
                },
              )),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots, isCurved: true, curveSmoothness: 0.35,
                color: _gold, barWidth: 2.5,
                dotData: FlDotData(show: true, getDotPainter: (s, _, __, ___) =>
                    FlDotCirclePainter(radius: 4.0, color: _gold, strokeWidth: 2.0, strokeColor: _white)),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                  colors: [_gold.withOpacity(0.22), _gold.withOpacity(0.0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                )),
              ),
            ],
            lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8.0,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '${s.y.toStringAsFixed(1)}/20',
                const TextStyle(color: _white, fontSize: 11, fontWeight: FontWeight.w700),
              )).toList(),
            )),
          )),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// EDT du jour (horizontal scroll)
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
          final first = i == 0;
          return Container(
            width: 96,
            decoration: first
                ? BoxDecoration(
                    gradient: LinearGradient(
                        colors: [s.c, s.c.withOpacity(0.75)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: s.c.withOpacity(0.40),
                        blurRadius: 12, offset: const Offset(0, 5))],
                  )
                : ScolarisSurface.accent(color: s.c, radius: 16),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: first ? _white.withOpacity(0.22) : s.c.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.school_rounded, size: 14, color: first ? _white : s.c),
                  ),
                  if (first)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: _white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('En cours', style: TextStyle(
                          color: _white, fontSize: 7, fontWeight: FontWeight.w800)),
                    ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.sub, style: TextStyle(
                      color: first ? _white : _ink, fontSize: 11, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 9,
                        color: first ? _white.withOpacity(0.70) : s.c),
                    const SizedBox(width: 3),
                    Text(s.h, style: TextStyle(
                        color: first ? _white.withOpacity(0.80) : s.c,
                        fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                  Text('Salle ${s.room}', style: TextStyle(
                      color: first ? _white.withOpacity(0.60) : _muted,
                      fontSize: 9)),
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
// Devoir card
// ══════════════════════════════════════════════════════════════════════════
class _DevoirCard extends StatelessWidget {
  final String sub, titre, echeance;
  final Color color;
  final VoidCallback onTap;
  const _DevoirCard({required this.sub, required this.titre,
      required this.echeance, required this.color, required this.onTap});

  bool get _isUrgent => echeance.toLowerCase().contains('demain') ||
      echeance.toLowerCase().contains('aujourd');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.card(radius: 13),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color.withOpacity(0.12), color.withOpacity(0.24)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(Icons.assignment_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(titre, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 10, color: _isUrgent ? _terra : _muted),
              const SizedBox(width: 3),
              Text(echeance, style: TextStyle(
                  color: _isUrgent ? _terra : _muted,
                  fontSize: 11, fontWeight: _isUrgent ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ])),
          if (_isUrgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _terra.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Urgent', style: TextStyle(
                  color: _terra, fontSize: 9, fontWeight: FontWeight.w800)),
            )
          else
            Icon(Icons.chevron_right_rounded, color: _muted.withOpacity(0.50), size: 20),
        ]),
      ),
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
    final pct = max > 0 ? (note / max) : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.card(radius: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(width: 46, height: 46,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 46, height: 46,
                child: CircularProgressIndicator(
                  value: pct, strokeWidth: 4,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(note.toStringAsFixed(note == note.roundToDouble() ? 0 : 1),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 5,
                backgroundColor: color.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ])),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: (pct >= 0.7 ? _green : _terra).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(pct >= 0.7 ? '✓ Bien' : '→ Effort',
                  style: TextStyle(
                      color: pct >= 0.7 ? _green : _terra,
                      fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(color: _muted, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Annonce card
// ══════════════════════════════════════════════════════════════════════════
class _AnnonceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, body, author, time;
  const _AnnonceCard({
    required this.icon, required this.color,
    required this.title, required this.body,
    required this.author, required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.07),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.70)]),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(body, style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            Text(author, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Text('·', style: TextStyle(color: _muted, fontSize: 10)),
            const SizedBox(width: 6),
            Text(time, style: const TextStyle(fontSize: 10.5, color: _muted)),
          ]),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Attendance helpers
// ══════════════════════════════════════════════════════════════════════════
class _AttCell extends StatelessWidget {
  final IconData icon;
  final String label, val;
  final Color color;
  const _AttCell({required this.icon, required this.label, required this.val, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(height: 4),
    Text(val, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(fontSize: 9.5, color: _muted, fontWeight: FontWeight.w600)),
  ]));
}

class _AttDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 40, color: const Color(0xFFDDCCBB),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Stats hebdomadaires
// ══════════════════════════════════════════════════════════════════════════
class _WeeklyStatsCard extends StatelessWidget {
  const _WeeklyStatsCard();

  static const _stats = [
    (icon: Icons.access_time_rounded,  label: 'Heures de cours', val: '28h',    color: _cyan),
    (icon: Icons.check_rounded,         label: 'Devoirs rendus',  val: '5/6',    color: _green),
    (icon: Icons.star_rounded,          label: 'Notes obtenues',  val: '3',      color: _gold),
    (icon: Icons.trending_up_rounded,   label: 'Progression',     val: '+0.6',   color: _terra),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ScolarisSurface.card(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Cette semaine', style: TextStyle(
              fontSize: 13, color: _ink, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.10), borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Semaine ${_currentWeek()}',
              style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: _stats.map((s) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.color.withOpacity(0.20)),
            ),
            child: Row(children: [
              Icon(s.icon, size: 16, color: s.color),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(s.val, style: TextStyle(
                    fontSize: 14, color: s.color, fontWeight: FontWeight.w900)),
                Text(s.label, style: const TextStyle(
                    fontSize: 9.5, color: _muted, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          )).toList(),
        ),
      ]),
    );
  }

  static String _currentWeek() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final diff  = now.difference(start).inDays;
    return '${(diff / 7).ceil()}';
  }
}
