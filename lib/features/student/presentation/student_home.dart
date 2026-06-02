import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/surface.dart';
import 'pages/bulletin_page.dart';
import 'pages/courses_page.dart';
import 'pages/grades_page.dart';
import 'pages/homework_student_page.dart';
import 'pages/schedule_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _dark   = ScolarisPalette.darkBrown;
const _cyan   = Color(0xFF0891B2);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFEDD8BE);

// ══════════════════════════════════════════════════════════════════════════
// Shell (inchangé — seul le dashboard est modifié)
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
          RoleNavEntry(icon: Icons.home_rounded,      activeIcon: Icons.home_rounded,
              labelKey: 'nav.dashboard', page: _StudentDashboard()),
          RoleNavEntry(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded,
              labelKey: 'nav.courses',   page: CoursesPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(icon: Icons.grading_outlined,    activeIcon: Icons.grading_rounded,
              labelKey: 'nav.grades',    page: GradesPage()),
          RoleNavEntry(icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              labelKey: 'nav.schedule',  page: SchedulePage()),
          RoleNavEntry(icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              labelKey: 'nav.homework',  page: HomeworkStudentPage()),
          RoleNavEntry(icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              labelKey: 'nav.bulletin',  page: BulletinPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(icon: Icons.chat_outlined,   activeIcon: Icons.chat_rounded,
              labelKey: 'nav.messages',  page: MessagingPage()),
          RoleNavEntry(icon: Icons.apps_outlined,   activeIcon: Icons.apps_rounded,
              labelKey: 'nav.features',  page: FeaturesHubPage()),
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
  bool _loading = true;

  // ── Données mock ──────────────────────────────────────────────────────
  // Progression des moyennes (5 semaines)
  static const _moyenneProgression = [12.5, 13.8, 14.2, 14.8, 15.4];
  static const _semLabels = ['S1', 'S2', 'S3', 'S4', 'S5'];

  // Absences par semaine
  static const _absences = [2.0, 1.0, 0.0, 1.0, 0.0];

  // Dernières notes
  static const _recentNotes = [
    (sub: 'Mathématiques', n: 17.5, max: 20, c: _gold,  d: '28 Mai'),
    (sub: 'Physique',      n: 13.0, max: 20, c: _terra, d: '25 Mai'),
    (sub: 'Histoire',      n: 15.5, max: 20, c: _green, d: '22 Mai'),
  ];

  // Devoirs urgents
  static const _devoirs = [
    (sub: 'Mathématiques', titre: 'Exercices page 124', echeance: 'Demain', c: _gold),
    (sub: 'Physique',      titre: 'Résumé chapitre 8',  echeance: 'Dans 2j', c: _cyan),
  ];

  // EDT aujourd'hui
  static const _edt = [
    (h: '08:00', sub: 'Mathématiques', room: 'A12', c: _terra),
    (h: '10:00', sub: 'Français',      room: 'B04', c: _gold),
    (h: '14:00', sub: 'Sciences',      room: 'Labo', c: _green),
    (h: '16:00', sub: 'Histoire',      room: 'C01', c: _cyan),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _loading = false); });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  void _push(Widget page) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authSessionProvider);
    final name     = user?.fullName ?? 'Étudiant';
    final initials = _initials(name);
    final classe   = user?.roleTitle == null ? 'Terminale' : 'Terminale';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 1. Hero ──────────────────────────────────────────────────
          _HeroCard(
            greeting: _greeting, name: name, initials: initials,
            classe: classe, loading: _loading,
          ),
          const SizedBox(height: 14),

          // ── 2. Stats rapides ─────────────────────────────────────────
          _QuickStats(loading: _loading),
          const SizedBox(height: 20),

          // ── 3. Raccourcis navigation ─────────────────────────────────
          _SectionHeader(title: 'Accès rapide'),
          const SizedBox(height: 10),
          _ShortcutsGrid(onTap: {
            'notes':    () => _push(const GradesPage()),
            'edt':      () => _push(const SchedulePage()),
            'devoirs':  () => _push(const HomeworkStudentPage()),
            'bulletin': () => _push(const BulletinPage()),
            'cours':    () => _push(const CoursesPage()),
            'messages': () => _push(const MessagingPage()),
          }),
          const SizedBox(height: 22),

          // ── 4. Courbe progression notes ───────────────────────────────
          _SectionHeader(title: 'Progression des notes',
              trailing: _SmallBadge('5 semaines', _green)),
          const SizedBox(height: 10),
          if (_loading)
            const SkeletonBox(width: double.infinity, height: 170, radius: 16)
          else
            _NoteProgressionChart(
              values: _moyenneProgression,
              labels: _semLabels,
            ),
          const SizedBox(height: 22),

          // ── 5. Graphique absences ─────────────────────────────────────
          _SectionHeader(title: 'Présences · Absences',
              trailing: _SmallBadge('T2', _terra)),
          const SizedBox(height: 10),
          if (_loading)
            const SkeletonBox(width: double.infinity, height: 160, radius: 16)
          else
            _AbsenceChart(absences: _absences, labels: _semLabels),
          const SizedBox(height: 22),

          // ── 6. EDT du jour ────────────────────────────────────────────
          _SectionHeader(title: "Emploi du temps du jour",
              action: 'Tout voir', onAction: () => _push(const SchedulePage())),
          const SizedBox(height: 10),
          if (_loading)
            const SkeletonBox(width: double.infinity, height: 106, radius: 14)
          else
            _EdtTimeline(slots: _edt),
          const SizedBox(height: 22),

          // ── 7. Devoirs urgents ────────────────────────────────────────
          _SectionHeader(title: 'Devoirs à rendre',
              action: 'Voir tout', onAction: () => _push(const HomeworkStudentPage())),
          const SizedBox(height: 10),
          if (_loading)
            Column(children: [
              const SkeletonListRow(), const SizedBox(height: 8),
              const SkeletonListRow(),
            ])
          else
            Column(children: [
              for (final d in _devoirs) ...[
                _DevoirCard(sub: d.sub, titre: d.titre,
                    echeance: d.echeance, color: d.c,
                    onTap: () => _push(const HomeworkStudentPage())),
                const SizedBox(height: 8),
              ],
            ]),
          const SizedBox(height: 22),

          // ── 8. Dernières notes ────────────────────────────────────────
          _SectionHeader(title: 'Dernières notes',
              action: 'Toutes les notes',
              onAction: () => _push(const GradesPage())),
          const SizedBox(height: 10),
          if (_loading)
            Column(children: [
              const SkeletonListRow(), const SizedBox(height: 8),
              const SkeletonListRow(), const SizedBox(height: 8),
              const SkeletonListRow(),
            ])
          else
            Column(children: [
              for (final n in _recentNotes) ...[
                _NoteRow(sub: n.sub, note: n.n, max: n.max,
                    date: n.d, color: n.c,
                    onTap: () => _push(const GradesPage())),
                const SizedBox(height: 8),
              ],
            ]),
          const SizedBox(height: 22),

          // ── 9. Bulletin résumé ────────────────────────────────────────
          _BulletinSummaryCard(onTap: () => _push(const BulletinPage())),
          const SizedBox(height: 22),

          // ── 10. Message du prof ───────────────────────────────────────
          _SectionHeader(title: 'Dernier message',
              action: 'Messagerie',
              onAction: () => _push(const MessagingPage())),
          const SizedBox(height: 10),
          _MessagePreviewCard(onTap: () => _push(const MessagingPage())),
          const SizedBox(height: 22),

          // ── 11. Citation ──────────────────────────────────────────────
          const _AfricanQuote(),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final p = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return 'E';
    if (p.length == 1) return p[0][0].toUpperCase();
    return (p[0][0] + p[1][0]).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Hero card
// ══════════════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final String greeting, name, initials, classe;
  final bool loading;
  const _HeroCard({required this.greeting, required this.name,
      required this.initials, required this.classe, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), _dark, _terra],
          stops: [0.0, 0.40, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _terra.withOpacity(0.45),
              blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -6),
          BoxShadow(color: _dark.withOpacity(0.25),
              blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          _AvatarCircle(initials: initials),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: TextStyle(
                color: _white.withOpacity(0.60), fontSize: 12)),
            const SizedBox(height: 2),
            Text(name, style: const TextStyle(color: _white,
                fontSize: 21, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 8),
            Row(children: [
              _Badge(label: classe,
                  bg: _gold.withOpacity(0.22), border: _gold.withOpacity(0.50), fg: _gold),
              const SizedBox(width: 6),
              _Badge(label: 'Trimestre 2',
                  bg: _white.withOpacity(0.12), border: _white.withOpacity(0.25),
                  fg: _white.withOpacity(0.85)),
            ]),
          ])),
        ]),
        const SizedBox(height: 16),
        // Bottom bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _white.withOpacity(0.15)),
          ),
          child: Row(children: [
            Icon(Icons.timer_outlined, color: _gold, size: 15),
            const SizedBox(width: 6),
            if (loading)
              const SkeletonBox(width: 140, height: 14, radius: 6)
            else
              RichText(text: TextSpan(
                style: TextStyle(color: _white.withOpacity(0.75), fontSize: 12),
                children: const [
                  TextSpan(text: 'Examens dans '),
                  TextSpan(text: '47 jours',
                      style: TextStyle(color: _gold,
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              )),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_gold, Color(0xFFE8A83A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _gold.withOpacity(0.40),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Text('Réviser',
                  style: TextStyle(color: _dark, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initials;
  const _AvatarCircle({required this.initials});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62, height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE8A83A), _gold],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: _white, width: 3),
        boxShadow: [BoxShadow(color: _gold.withOpacity(0.50),
            blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Center(child: Text(initials,
          style: const TextStyle(color: _dark, fontSize: 21,
              fontWeight: FontWeight.w900))),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, border, fg;
  const _Badge({required this.label, required this.bg,
      required this.border, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border)),
    child: Text(label, style: TextStyle(
        color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Stats rapides (3 pills sous le hero)
// ══════════════════════════════════════════════════════════════════════════
class _QuickStats extends StatelessWidget {
  final bool loading;
  const _QuickStats({required this.loading});

  static const _data = [
    (icon: Icons.star_rounded,         label: 'Moyenne',  val: '15.4', sub: '/20',  c: _gold),
    (icon: Icons.check_circle_rounded, label: 'Présence', val: '96',   sub: ' %',   c: _green),
    (icon: Icons.assignment_rounded,   label: 'En cours', val: '3',    sub: ' devoirs', c: _terra),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 0; i < _data.length; i++) ...[
        Expanded(child: _QuickStatPill(d: _data[i], loading: loading)),
        if (i < _data.length - 1) const SizedBox(width: 10),
      ],
    ]);
  }
}

class _QuickStatPill extends StatelessWidget {
  final ({IconData icon, String label, String val, String sub, Color c}) d;
  final bool loading;
  const _QuickStatPill({required this.d, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: ScolarisSurface.accent(color: d.c, radius: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: d.c.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
          child: Icon(d.icon, color: d.c, size: 14),
        ),
        const SizedBox(height: 7),
        Text(d.label, style: TextStyle(
            color: d.c.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        if (loading)
          const SkeletonBox(width: 40, height: 18, radius: 5)
        else
          RichText(text: TextSpan(children: [
            TextSpan(text: d.val,
                style: TextStyle(color: d.c, fontSize: 18, fontWeight: FontWeight.w900)),
            TextSpan(text: d.sub,
                style: TextStyle(color: d.c.withOpacity(0.65), fontSize: 10)),
          ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Raccourcis navigation (grid 3x2)
// ══════════════════════════════════════════════════════════════════════════
class _ShortcutsGrid extends StatelessWidget {
  final Map<String, VoidCallback> onTap;
  const _ShortcutsGrid({required this.onTap});

  static const _items = [
    (key: 'notes',    icon: Icons.grading_rounded,          label: 'Notes',    sub: 'Résultats',  c: _gold),
    (key: 'edt',      icon: Icons.calendar_month_rounded,    label: 'Emploi',   sub: 'du temps',   c: _terra),
    (key: 'devoirs',  icon: Icons.assignment_rounded,         label: 'Devoirs',  sub: '2 urgents',  c: _orange),
    (key: 'bulletin', icon: Icons.receipt_long_rounded,       label: 'Bulletin', sub: 'Trimestre',  c: _green),
    (key: 'cours',    icon: Icons.menu_book_rounded,          label: 'Cours',    sub: 'Programme',  c: _cyan),
    (key: 'messages', icon: Icons.chat_rounded,               label: 'Messages', sub: '1 nouveau',  c: Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: _items.map((item) => GestureDetector(
        onTap: onTap[item.key],
        child: Container(
          decoration: ScolarisSurface.accent(color: item.c, radius: 14),
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: item.c.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(item.icon, color: item.c, size: 17),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.label, style: TextStyle(
                      color: _ink, fontSize: 12, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(item.sub, style: TextStyle(
                      color: item.c, fontSize: 9, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ]),
        ),
      )).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Courbe progression des notes (LineChart)
// ══════════════════════════════════════════════════════════════════════════
class _NoteProgressionChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _NoteProgressionChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final trend = values.last - values.first;
    final trendUp = trend >= 0;

    return Container(
      decoration: ScolarisSurface.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Text('Progression des notes', style: TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: (trendUp ? _green : _terra).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (trendUp ? _green : _terra).withOpacity(0.30))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: trendUp ? _green : _terra, size: 13),
              const SizedBox(width: 4),
              Text('${trendUp ? '+' : ''}${trend.toStringAsFixed(1)} pts',
                  style: TextStyle(
                      color: trendUp ? _green : _terra,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Moyenne générale sur 5 semaines',
            style: TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: LineChart(LineChartData(
            minY: 8, maxY: 20,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 4,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: _ink.withOpacity(0.06), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: const TextStyle(
                        color: _muted, fontSize: 9, fontWeight: FontWeight.w600)),
              )),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22,
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
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: _gold,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 4,
                    color: _gold,
                    strokeWidth: 2,
                    strokeColor: _white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [_gold.withOpacity(0.22), _gold.withOpacity(0.0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${s.y}/20',
                  const TextStyle(color: _white, fontSize: 11,
                      fontWeight: FontWeight.w700),
                )).toList(),
              ),
            ),
          )),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Graphique absences (BarChart + présence pie)
// ══════════════════════════════════════════════════════════════════════════
class _AbsenceChart extends StatelessWidget {
  final List<double> absences;
  final List<String> labels;
  const _AbsenceChart({required this.absences, required this.labels});

  @override
  Widget build(BuildContext context) {
    final totalAbs = absences.reduce((a, b) => a + b);
    final totalHours = absences.length * 5.0;
    final presencePct = ((totalHours - totalAbs) / totalHours * 100).round();

    return Container(
      decoration: ScolarisSurface.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Absences par semaine', style: TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.30))),
            child: Text('$presencePct% présent',
                style: const TextStyle(color: _green,
                    fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Total absences · ${totalAbs.toInt()} heure(s) ce trimestre',
            style: const TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // BarChart
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 110,
              child: BarChart(BarChartData(
                maxY: 4,
                minY: 0,
                gridData: FlGridData(
                  show: true, drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: _ink.withOpacity(0.06), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 20,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox();
                      return Text(labels[i], style: const TextStyle(
                          color: _muted, fontSize: 9, fontWeight: FontWeight.w600));
                    },
                  )),
                ),
                barGroups: absences.asMap().entries.map((e) =>
                    BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(
                        toY: e.value,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        gradient: LinearGradient(
                          colors: e.value > 0
                              ? [_terra, _orange]
                              : [_green.withOpacity(0.5), _green],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ])).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (g, _, r, __) => BarTooltipItem(
                      r.toY == 0 ? 'Présent ✓' : '${r.toY.toInt()} abs',
                      const TextStyle(color: _white, fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )),
            ),
          ),
          const SizedBox(width: 14),
          // Donut présence
          SizedBox(
            width: 90, height: 110,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                width: 70, height: 70,
                child: Stack(alignment: Alignment.center, children: [
                  PieChart(PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: 24,
                    sections: [
                      PieChartSectionData(
                          value: presencePct.toDouble(),
                          color: _green, radius: 12, showTitle: false),
                      PieChartSectionData(
                          value: (100 - presencePct).toDouble(),
                          color: _terra.withOpacity(0.20),
                          radius: 12, showTitle: false),
                    ],
                  )),
                  Text('$presencePct%',
                      style: const TextStyle(color: _green,
                          fontSize: 12, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 6),
              const Text('Présence', style: TextStyle(
                  color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
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
                    boxShadow: [BoxShadow(color: s.c.withOpacity(0.40),
                        blurRadius: 12, offset: const Offset(0, 5))],
                  )
                : ScolarisSurface.accent(color: s.c, radius: 16),
            padding: const EdgeInsets.all(11),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: first
                              ? _white.withOpacity(0.25) : s.c.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.school_rounded, size: 14,
                          color: first ? _white : s.c),
                    ),
                    if (first)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: _white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('Actif', style: TextStyle(
                            color: _white, fontSize: 7, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.sub, style: TextStyle(
                        color: first ? _white : _ink, fontSize: 11,
                        fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(s.h, style: TextStyle(
                        color: first ? _white.withOpacity(0.80) : s.c,
                        fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ]),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.card(radius: 13),
        padding: const EdgeInsets.all(14),
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
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(titre, style: const TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 10, color: _muted),
              const SizedBox(width: 4),
              Text(echeance,
                  style: const TextStyle(color: _muted, fontSize: 11)),
            ]),
          ])),
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
    final pct = note / max;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.card(radius: 13),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 46, height: 46,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 46, height: 46,
                child: CircularProgressIndicator(
                  value: pct, strokeWidth: 4,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(note.toStringAsFixed(1),
                  style: TextStyle(color: color, fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: const TextStyle(
                color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
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
// Bulletin résumé card
// ══════════════════════════════════════════════════════════════════════════
class _BulletinSummaryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BulletinSummaryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0D3B1E), _green],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.35),
              blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -4)],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: _gold, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bulletin Trimestriel',
                style: TextStyle(color: _white, fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              _TrimBadge('T1 · 13.2', active: false),
              const SizedBox(width: 8),
              _TrimBadge('T2 · 15.4', active: true),
              const SizedBox(width: 8),
              _TrimBadge('T3 · —', active: false),
            ]),
          ])),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white54, size: 22),
        ]),
      ),
    );
  }
}

class _TrimBadge extends StatelessWidget {
  final String label;
  final bool active;
  const _TrimBadge(this.label, {required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: active ? _gold.withOpacity(0.25) : _white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: active ? Border.all(color: _gold.withOpacity(0.50)) : null),
    child: Text(label, style: TextStyle(
        color: active ? _gold : _white.withOpacity(0.55),
        fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Message preview card
// ══════════════════════════════════════════════════════════════════════════
class _MessagePreviewCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MessagePreviewCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ScolarisSurface.card(radius: 13),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  border: Border.all(color: _white, width: 2),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.35),
                      blurRadius: 10, offset: const Offset(0, 4))]),
              child: const Center(child: Text('MD', style: TextStyle(
                  color: _white, fontSize: 14, fontWeight: FontWeight.w800))),
            ),
            Positioned(right: 0, top: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                    color: _terra, shape: BoxShape.circle,
                    border: Border.all(color: _white, width: 1.5)),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('M. Diallo', style: TextStyle(
                  color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: _terra.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Nouveau', style: TextStyle(
                    color: _terra, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 3),
            const Text('Rappel : remettez le devoir de maths avant vendredi.',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _muted, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: _muted.withOpacity(0.50), size: 20),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Citation africaine
// ══════════════════════════════════════════════════════════════════════════
class _AfricanQuote extends StatelessWidget {
  const _AfricanQuote();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), _dark, _terra],
          stops: [0.0, 0.40, 1.0],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _terra.withOpacity(0.35),
            blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -4)],
      ),
      child: Row(children: [
        Icon(Icons.format_quote_rounded,
            color: _white.withOpacity(0.18), size: 52),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('"Le savoir est une lumière\nque nul ne peut éteindre."',
              style: TextStyle(color: _white.withOpacity(0.92), fontSize: 13,
                  height: 1.55, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text('— Proverbe africain', style: TextStyle(
              color: _gold.withOpacity(0.90),
              fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Helpers UI
// ══════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.action,
      this.onAction, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: const TextStyle(
        color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
    if (trailing != null) ...[const SizedBox(width: 8), trailing!],
    const Spacer(),
    if (action != null)
      GestureDetector(
        onTap: onAction,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(action!, style: const TextStyle(
              color: _terra, fontSize: 12, fontWeight: FontWeight.w600)),
          const Icon(Icons.chevron_right_rounded, color: _terra, size: 14),
        ]),
      ),
  ]);
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.28))),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.w700)),
  );
}
