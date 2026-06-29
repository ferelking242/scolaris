import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/surface.dart';
import 'pages/cahier_liaison_page.dart';
import 'pages/carnet_recompenses_page.dart';
import 'pages/menu_cantine_page.dart';

// ── Couleurs ──────────────────────────────────────────────────────────────
const _terra  = ScolarisPalette.terracotta;   // #8B1A00
const _orange = ScolarisPalette.orange;        // #D4540A
const _gold   = ScolarisPalette.gold;          // #C17F24
const _green  = ScolarisPalette.forestGreen;   // #1B5E20
const _dark   = ScolarisPalette.darkBrown;     // #3E1A00
const _cyan   = Color(0xFF0891B2);
const _violet = Color(0xFF6D28D9);
const _pink   = Color(0xFFDB2777);
const _teal   = Color(0xFF059669);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
// Fond légèrement plus sombre que avant → cartes blanches ressortent vraiment
const _bg     = Color(0xFFEDD8BE);

// ── Matières CP→CM2 ───────────────────────────────────────────────────────
class _S {
  final String name; final IconData icon; final Color color;
  const _S(this.name, this.icon, this.color);
}

const _subjects = [
  _S('Lecture',     Icons.menu_book_rounded,       _terra),
  _S('Calcul',      Icons.calculate_rounded,        _gold),
  _S('Écriture',    Icons.edit_rounded,             _green),
  _S('Sciences',    Icons.science_rounded,          _cyan),
  _S('Éd. Civique', Icons.account_balance_rounded,  _orange),
  _S('Religion',    Icons.church_rounded,           _violet),
  _S('Dessin',      Icons.palette_rounded,          _pink),
  _S('Sport',       Icons.sports_soccer_rounded,    _teal),
];

_S _iconFor(String name) =>
    _subjects.firstWhere((s) => s.name == name,
        orElse: () => const _S('', Icons.school_rounded, _terra));

// ══════════════════════════════════════════════════════════════════════════
// Shell
// ══════════════════════════════════════════════════════════════════════════
class PrimaryStudentHome extends StatelessWidget {
  const PrimaryStudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.student,
      title: 'Scolaris · Primaire',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(icon: Icons.home_outlined,  activeIcon: Icons.home_rounded,
              labelKey: 'nav.dashboard',  page: _PrimaryDashboard()),
          RoleNavEntry(icon: Icons.grading_outlined, activeIcon: Icons.grading_rounded,
              labelKey: 'nav.grades',     page: _PrimaryNotesPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              labelKey: 'nav.schedule',   page: _PrimarySchedulePage()),
          RoleNavEntry(icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              labelKey: 'nav.homework',   page: _PrimaryDevoirsPage()),
          RoleNavEntry(icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              labelKey: 'nav.bulletin',   page: _PrimaryBulletinPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.primary_tools', entries: [
          RoleNavEntry(icon: Icons.import_contacts_outlined,
              activeIcon: Icons.import_contacts_rounded,
              labelKey: 'nav.cahier_liaison', page: CahierLiaisonPage()),
          RoleNavEntry(icon: Icons.restaurant_outlined,
              activeIcon: Icons.restaurant_rounded,
              labelKey: 'nav.menu_cantine',  page: MenuCantinePage()),
          RoleNavEntry(icon: Icons.emoji_events_outlined,
              activeIcon: Icons.emoji_events_rounded,
              labelKey: 'nav.recompenses',   page: CarnetRecompensesPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(icon: Icons.chat_outlined, activeIcon: Icons.chat_rounded,
              labelKey: 'nav.messages',   page: MessagingPage()),
        ]),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Dashboard
// ══════════════════════════════════════════════════════════════════════════
class _PrimaryDashboard extends ConsumerStatefulWidget {
  const _PrimaryDashboard();
  @override
  ConsumerState<_PrimaryDashboard> createState() => _PrimaryDashboardState();
}

class _PrimaryDashboardState extends ConsumerState<_PrimaryDashboard> {
  bool _loading = true;

  static const _recentNotes = [
    (m: 'Calcul',      n: 9.5, c: _gold,   d: '28 Mai'),
    (m: 'Lecture',     n: 8.0, c: _terra,  d: '26 Mai'),
    (m: 'Écriture',    n: 8.5, c: _green,  d: '23 Mai'),
    (m: 'Sciences',    n: 7.5, c: _cyan,   d: '21 Mai'),
    (m: 'Éd. Civique', n: 9.0, c: _orange, d: '19 Mai'),
  ];

  static const _todaySlots = [
    (m: 'Lecture',  t: '08h00', c: _terra),
    (m: 'Calcul',   t: '09h30', c: _gold),
    (m: 'Sport',    t: '11h00', c: _teal),
    (m: 'Écriture', t: '14h00', c: _green),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800),
        () { if (mounted) setState(() => _loading = false); });
  }

  double get _avg =>
      _recentNotes.map((e) => e.n).reduce((a, b) => a + b) / _recentNotes.length;

  @override
  Widget build(BuildContext context) {
    final user    = ref.watch(authSessionProvider);
    final name    = user?.fullName ?? 'Élève';
    final initials = _initials(name);
    final classe  = 'CE1';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 1. Hero card ─────────────────────────────────────────────
          _HeroCard(name: name, initials: initials, classe: classe,
              loading: _loading),
          const SizedBox(height: 16),

          // ── 2. Moyenne + présence (côte à côte) ──────────────────────
          Row(children: [
            Expanded(child: _MoyenneDonut(avg: _avg, loading: _loading)),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [
              _MiniStatCard(icon: Icons.check_circle_rounded,
                  label: 'Présence', value: '97 %',
                  sub: '2 abs ce mois', color: _green, loading: _loading),
              const SizedBox(height: 10),
              _MiniStatCard(icon: Icons.assignment_rounded,
                  label: 'Devoirs', value: '2',
                  sub: 'à remettre', color: _terra, loading: _loading),
              const SizedBox(height: 10),
              _MiniStatCard(icon: Icons.emoji_events_rounded,
                  label: 'Rang classe', value: '3ᵉ',
                  sub: 'sur 28 élèves', color: _gold, loading: _loading),
            ])),
          ]),
          const SizedBox(height: 22),

          // ── 3. Graphique notes ────────────────────────────────────────
          _SectionHeader(title: 'Notes par matière (T2)',
              action: 'Tout voir', onAction: () {}),
          const SizedBox(height: 10),
          if (_loading)
            const SkeletonBox(width: double.infinity, height: 140, radius: 16)
          else
            _NotesBarChart(notes: _recentNotes
                .map((e) => (m: e.m, n: e.n, c: e.c)).toList()),
          const SizedBox(height: 22),

          // ── 4. Emploi du temps aujourd'hui ────────────────────────────
          _SectionHeader(title: "Aujourd'hui",
              action: 'EDT complet', onAction: () {}),
          const SizedBox(height: 10),
          if (_loading)
            const SkeletonBox(width: double.infinity, height: 106, radius: 14)
          else
            _TodayTimeline(slots: _todaySlots),
          const SizedBox(height: 22),

          // ── 5. Dernières notes ────────────────────────────────────────
          _SectionHeader(title: 'Mes dernières notes',
              action: 'Voir tout', onAction: () {}),
          const SizedBox(height: 10),
          if (_loading) ...[
            for (int i = 0; i < 3; i++) ...[
              const SkeletonListRow(), const SizedBox(height: 8),
            ],
          ] else
            for (final n in _recentNotes.take(3)) ...[
              _NoteRow(matiere: n.m, note: n.n, date: n.d, color: n.c),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 22),

          // ── 6. Prochain devoir ────────────────────────────────────────
          _SectionHeader(title: 'Prochain devoir',
              action: 'Voir tout', onAction: () {}),
          const SizedBox(height: 10),
          if (_loading)
            const SkeletonListRow()
          else
            const _NextDevoirCard(),
          const SizedBox(height: 22),

          // ── 7. Citation ───────────────────────────────────────────────
          const _AfricanQuote(),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'E';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Widgets partagés dans ce fichier
// ══════════════════════════════════════════════════════════════════════════

// ── Hero card ─────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String name, initials, classe;
  final bool loading;
  const _HeroCard({required this.name, required this.initials,
      required this.classe, required this.loading});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0500), _dark, _terra],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _terra.withOpacity(0.45),
              blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -6),
          BoxShadow(color: _dark.withOpacity(0.30),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Avatar ───────────────────────────────────────────────────
          _Avatar(initials: initials),
          const SizedBox(width: 16),

          // ── Nom + badge ───────────────────────────────────────────────
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting,
                style: TextStyle(color: _white.withOpacity(0.65),
                    fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(name,
                style: const TextStyle(color: _white, fontSize: 20,
                    fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 8),
            Row(children: [
              _Badge(label: classe, bg: _gold.withOpacity(0.25),
                  border: _gold.withOpacity(0.5), fg: _gold),
              const SizedBox(width: 6),
              _Badge(label: 'Trimestre 2', bg: _white.withOpacity(0.12),
                  border: _white.withOpacity(0.25), fg: _white.withOpacity(0.85)),
            ]),
          ])),
        ]),
        const SizedBox(height: 16),

        // ── Barre du bas ─────────────────────────────────────────────
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
            RichText(text: TextSpan(
              style: TextStyle(color: _white.withOpacity(0.75), fontSize: 12),
              children: [
                const TextSpan(text: 'Examens dans '),
                TextSpan(text: '47 jours',
                    style: const TextStyle(color: _gold,
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            )),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_gold, Color(0xFFE8A83A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _gold.withOpacity(0.40),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Text('Préparer',
                  style: TextStyle(color: _dark, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE8A83A), _gold, Color(0xFFC17F24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _white, width: 3),
        boxShadow: [
          BoxShadow(color: _gold.withOpacity(0.50),
              blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Center(child: Text(initials,
          style: const TextStyle(color: _dark, fontSize: 22,
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(label, style: TextStyle(
          color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Donut moyenne ─────────────────────────────────────────────────────────
class _MoyenneDonut extends StatelessWidget {
  final double avg;
  final bool loading;
  const _MoyenneDonut({required this.avg, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: ScolarisSurface.card(radius: 18),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Moyenne', style: TextStyle(
            color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Générale', style: TextStyle(
            color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (loading)
          const Center(child: SkeletonBox(width: 90, height: 90, radius: 45))
        else
          Center(
            child: SizedBox(
              width: 100, height: 100,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 0,
                  centerSpaceRadius: 34,
                  sections: [
                    PieChartSectionData(
                      value: avg, color: _gold,
                      radius: 14.0, showTitle: false,
                    ),
                    PieChartSectionData(
                      value: 10 - avg,
                      color: _gold.withOpacity(0.12),
                      radius: 14.0, showTitle: false,
                    ),
                  ],
                )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(avg.toStringAsFixed(1),
                      style: const TextStyle(color: _gold, fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  Text('/10', style: TextStyle(
                      color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ),
        const Spacer(),
      ]),
    );
  }
}

// ── Mini stat card ─────────────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  final bool loading;
  const _MiniStatCard({required this.icon, required this.label,
      required this.value, required this.sub,
      required this.color, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: ScolarisSurface.accent(color: color, radius: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(
                  color: color.withOpacity(0.70), fontSize: 9,
                  fontWeight: FontWeight.w700)),
              Text(sub, style: TextStyle(
                  color: _muted, fontSize: 9, fontWeight: FontWeight.w500)),
            ])),
        if (loading)
          const SkeletonBox(width: 32, height: 18, radius: 4)
        else
          Text(value, style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

// ── Bar chart notes ────────────────────────────────────────────────────────
class _NotesBarChart extends StatelessWidget {
  final List<({String m, double n, Color c})> notes;
  const _NotesBarChart({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: ScolarisSurface.card(radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Notes /10', style: TextStyle(
              color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Trimestre 2', style: TextStyle(
                color: _green, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: BarChart(BarChartData(
          maxY: 10.0,
          minY: 0.0,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 5.0,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color: _ink.withOpacity(0.06), strokeWidth: 1.0),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22.0,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= notes.length) return const SizedBox();
                final name = notes[i].m;
                final short = name.length > 4 ? name.substring(0, 3) : name;
                return Text(short, style: const TextStyle(
                    color: _muted, fontSize: 9, fontWeight: FontWeight.w600));
              },
            )),
          ),
          barGroups: [
            for (int i = 0; i < notes.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: notes[i].n,
                  width: 18.0,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                  gradient: LinearGradient(
                    colors: [
                      notes[i].c,
                      notes[i].c.withOpacity(0.65),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ]),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8.0,
              getTooltipItem: (g, _, r, __) => BarTooltipItem(
                '${r.toY}/10',
                const TextStyle(color: _white, fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ))),
      ]),
    );
  }
}

// ── Today timeline ─────────────────────────────────────────────────────────
class _TodayTimeline extends StatelessWidget {
  final List<({String m, String t, Color c})> slots;
  const _TodayTimeline({required this.slots});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s   = slots[i];
          final sub = _iconFor(s.m);
          final first = i == 0;
          return Container(
            width: 90,
            decoration: first
                ? BoxDecoration(
                    gradient: LinearGradient(
                        colors: [s.c, s.c.withOpacity(0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: s.c.withOpacity(0.40),
                        blurRadius: 14, offset: const Offset(0, 6))],
                  )
                : ScolarisSurface.accent(color: s.c, radius: 16),
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: first
                            ? _white.withOpacity(0.25)
                            : s.c.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(sub.icon, size: 15,
                          color: first ? _white : s.c),
                    ),
                    if (first)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('En cours',
                            style: TextStyle(color: _white,
                                fontSize: 7, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.m,
                        style: TextStyle(
                            color: first ? _white : _ink,
                            fontSize: 11, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(s.t,
                        style: TextStyle(
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

// ── Note row ──────────────────────────────────────────────────────────────
class _NoteRow extends StatelessWidget {
  final String matiere, date;
  final double note;
  final Color color;
  const _NoteRow({required this.matiere, required this.note,
      required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = note / 10;
    final good = pct >= 0.70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ScolarisSurface.card(radius: 14),
      child: Row(children: [

        // Score badge circulaire
        SizedBox(
          width: 46, height: 46,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 46, height: 46,
              child: CircularProgressIndicator(
                value: pct, strokeWidth: 4,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(note.toStringAsFixed(1),
                  style: TextStyle(color: color, fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ]),
          ]),
        ),
        const SizedBox(width: 14),

        // Matière + progress
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(matiere, style: const TextStyle(
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

        // Date + badge
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: good ? _green.withOpacity(0.10) : _terra.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(good ? '✓ Bien' : '→ Effort',
                style: TextStyle(
                    color: good ? _green : _terra,
                    fontSize: 9, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ── Prochain devoir card ───────────────────────────────────────────────────
class _NextDevoirCard extends StatelessWidget {
  const _NextDevoirCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ScolarisSurface.card(radius: 14),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_gold.withOpacity(0.15), _gold.withOpacity(0.28)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _gold.withOpacity(0.25)),
          ),
          child: const Icon(Icons.assignment_rounded, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const _SubjectChip('Calcul', _gold),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: _terra.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Urgent',
                  style: TextStyle(color: _terra, fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Additions et soustractions',
              style: TextStyle(color: _ink, fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 11, color: _muted),
            const SizedBox(width: 4),
            const Text('À remettre demain · M. Mbuyi',
                style: TextStyle(color: _muted, fontSize: 11)),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_terra, _orange],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _terra.withOpacity(0.35),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Column(children: [
            Text('Demain', style: TextStyle(color: _white,
                fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SubjectChip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Citation africaine ─────────────────────────────────────────────────────
class _AfricanQuote extends StatelessWidget {
  const _AfricanQuote();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B1E), _green],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: _green.withOpacity(0.35),
              blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -4),
        ],
      ),
      child: Row(children: [
        Icon(Icons.format_quote_rounded,
            color: _white.withOpacity(0.20), size: 52),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('"L\'enfant qui n\'est pas embrassé par son village\nbrûlera le monde pour se réchauffer."',
              style: TextStyle(color: _white.withOpacity(0.92), fontSize: 12,
                  height: 1.55, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text('— Proverbe africain',
              style: TextStyle(color: _gold.withOpacity(0.90),
                  fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, action;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.action,
      required this.onAction});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 15,
          fontWeight: FontWeight.w800)),
      const Spacer(),
      GestureDetector(
        onTap: onAction,
        child: Text(action, style: const TextStyle(color: _terra,
            fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Page Notes
// ══════════════════════════════════════════════════════════════════════════
class _PrimaryNotesPage extends StatelessWidget {
  const _PrimaryNotesPage();

  static const _notes = [
    (m: 'Calcul',      n: 9.5,  c: _gold,   d: '28 Mai'),
    (m: 'Lecture',     n: 8.0,  c: _terra,  d: '26 Mai'),
    (m: 'Écriture',    n: 8.5,  c: _green,  d: '23 Mai'),
    (m: 'Sciences',    n: 7.5,  c: _cyan,   d: '21 Mai'),
    (m: 'Éd. Civique', n: 9.0,  c: _orange, d: '19 Mai'),
    (m: 'Religion',    n: 9.5,  c: _violet, d: '15 Mai'),
    (m: 'Dessin',      n: 10.0, c: _pink,   d: '14 Mai'),
    (m: 'Sport',       n: 8.0,  c: _teal,   d: '12 Mai'),
  ];

  @override
  Widget build(BuildContext context) {
    final avg = _notes.map((e) => e.n).reduce((a, b) => a + b) / _notes.length;
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Banner moyenne
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_dark, _terra],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _terra.withOpacity(0.40),
                  blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -4)],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Moyenne générale · T2',
                    style: TextStyle(color: _white.withOpacity(0.65),
                        fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                RichText(text: TextSpan(children: [
                  TextSpan(text: avg.toStringAsFixed(1),
                      style: const TextStyle(color: _gold, fontSize: 38,
                          fontWeight: FontWeight.w900)),
                  const TextSpan(text: '/10',
                      style: TextStyle(color: Colors.white60, fontSize: 18,
                          fontWeight: FontWeight.w400)),
                ])),
              ]),
              const Spacer(),
              SizedBox(width: 70, height: 70,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: avg / 10, strokeWidth: 6,
                    backgroundColor: _white.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(_gold),
                  ),
                  Icon(Icons.star_rounded, color: _gold, size: 24),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Notes du Trimestre 2', style: TextStyle(
              color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final n in _notes) ...[
            _NoteRow(matiere: n.m, note: n.n, date: n.d, color: n.c),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Page Emploi du temps
// ══════════════════════════════════════════════════════════════════════════
class _PrimarySchedulePage extends StatelessWidget {
  const _PrimarySchedulePage();

  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];
  static const _schedule = {
    'Lun': [
      ('08h00', 'Lecture',     _terra),
      ('09h30', 'Calcul',      _gold),
      ('11h00', 'Écriture',    _green),
      ('14h00', 'Sciences',    _cyan),
    ],
    'Mar': [
      ('08h00', 'Calcul',      _gold),
      ('09h30', 'Lecture',     _terra),
      ('11h00', 'Dessin',      _pink),
      ('14h00', 'Éd. Civique', _orange),
    ],
    'Mer': [
      ('08h00', 'Écriture',    _green),
      ('09h30', 'Calcul',      _gold),
      ('11h00', 'Religion',    _violet),
    ],
    'Jeu': [
      ('08h00', 'Lecture',     _terra),
      ('09h30', 'Sciences',    _cyan),
      ('11h00', 'Écriture',    _green),
      ('14h00', 'Calcul',      _gold),
    ],
    'Ven': [
      ('08h00', 'Calcul',      _gold),
      ('09h30', 'Lecture',     _terra),
      ('11h00', 'Sport',       _teal),
      ('14h00', 'Éd. Civique', _orange),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final todayIdx = (DateTime.now().weekday - 1).clamp(0, 4);
    return DefaultTabController(
      length: _days.length,
      initialIndex: todayIdx,
      child: Container(
        color: _bg,
        child: Column(children: [
          Container(
            color: _bg,
            child: TabBar(
              isScrollable: true,
              labelColor: _terra,
              unselectedLabelColor: _muted,
              indicator: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _terra.withOpacity(0.15),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              indicatorPadding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              tabs: _days.asMap().entries.map((e) {
                final isToday = e.key == todayIdx;
                return Tab(child: Text(
                    isToday ? '${e.value} ·' : e.value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)));
              }).toList(),
            ),
          ),
          Expanded(child: TabBarView(
            children: _days.map((d) {
              final slots = _schedule[d] ?? [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  for (int i = 0; i < slots.length; i++) ...[
                    _EdtCard(
                      time: slots[i].$1,
                      matiere: slots[i].$2,
                      color: slots[i].$3,
                      isNow: d == _days[todayIdx] && i == 0,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }).toList(),
          )),
        ]),
      ),
    );
  }
}

class _EdtCard extends StatelessWidget {
  final String time, matiere;
  final Color color;
  final bool isNow;
  const _EdtCard({required this.time, required this.matiere,
      required this.color, required this.isNow});

  @override
  Widget build(BuildContext context) {
    final sub = _iconFor(matiere);
    return Container(
      decoration: isNow
          ? BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.70)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withOpacity(0.40),
                  blurRadius: 16, offset: const Offset(0, 6))],
            )
          : ScolarisSurface.card(radius: 16),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: isNow ? _white.withOpacity(0.20) : color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(sub.icon, color: isNow ? _white : color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(matiere, style: TextStyle(
              color: isNow ? _white : _ink,
              fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('M. Mbuyi · Salle 3', style: TextStyle(
              color: isNow ? _white.withOpacity(0.70) : _muted,
              fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('En cours', style: TextStyle(
                  color: _white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(
              color: isNow ? _white.withOpacity(0.85) : color,
              fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Page Devoirs
// ══════════════════════════════════════════════════════════════════════════
class _PrimaryDevoirsPage extends StatelessWidget {
  const _PrimaryDevoirsPage();

  static const _devoirs = [
    (m: 'Calcul',   titre: 'Additions et soustractions', echeance: 'Demain',      urgent: true,  c: _gold),
    (m: 'Lecture',  titre: 'Lire pages 34–40 du livre',  echeance: 'Dans 3 jours', urgent: false, c: _terra),
    (m: 'Écriture', titre: 'Recopier "La savane"',        echeance: 'Dans 4 jours', urgent: false, c: _green),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          _DevoirsHeader(count: _devoirs.length),
          const SizedBox(height: 16),
          for (final d in _devoirs) ...[
            _DevoirCard(
                matiere: d.m, titre: d.titre,
                echeance: d.echeance, urgent: d.urgent, color: d.c),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DevoirsHeader extends StatelessWidget {
  final int count;
  const _DevoirsHeader({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [_dark, _terra],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _terra.withOpacity(0.35),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        const Icon(Icons.assignment_rounded, color: _white, size: 28),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mes devoirs',
              style: TextStyle(color: _white, fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text('$count à faire cette semaine',
              style: TextStyle(
                  color: _white.withOpacity(0.65), fontSize: 12)),
        ]),
        const Spacer(),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: _white.withOpacity(0.20), shape: BoxShape.circle),
          child: Center(child: Text('$count',
              style: const TextStyle(color: _white, fontSize: 18,
                  fontWeight: FontWeight.w900))),
        ),
      ]),
    );
  }
}

class _DevoirCard extends StatelessWidget {
  final String matiere, titre, echeance;
  final bool urgent;
  final Color color;
  const _DevoirCard({required this.matiere, required this.titre,
      required this.echeance, required this.urgent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ScolarisSurface.card(radius: 14),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color.withOpacity(0.12), color.withOpacity(0.24)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(Icons.assignment_outlined, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _SubjectChip(matiere, color),
            if (urgent) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: _terra.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Urgent',
                    style: TextStyle(color: _terra, fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
          const SizedBox(height: 5),
          Text(titre, style: const TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 11, color: _muted),
            const SizedBox(width: 4),
            Text(echeance,
                style: const TextStyle(color: _muted, fontSize: 11)),
          ]),
        ])),
        const SizedBox(width: 8),
        Icon(Icons.check_circle_outline_rounded,
            color: _muted.withOpacity(0.40), size: 24),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Page Bulletin
// ══════════════════════════════════════════════════════════════════════════
class _PrimaryBulletinPage extends StatelessWidget {
  const _PrimaryBulletinPage();

  static const _rows = [
    (m: 'Calcul',      t1: 8.5,  t2: 9.5,  t3: 0.0, c: _gold),
    (m: 'Lecture',     t1: 7.5,  t2: 8.0,  t3: 0.0, c: _terra),
    (m: 'Écriture',    t1: 8.0,  t2: 8.5,  t3: 0.0, c: _green),
    (m: 'Sciences',    t1: 6.5,  t2: 7.5,  t3: 0.0, c: _cyan),
    (m: 'Éd. Civique', t1: 9.0,  t2: 9.0,  t3: 0.0, c: _orange),
    (m: 'Religion',    t1: 9.5,  t2: 9.5,  t3: 0.0, c: _violet),
    (m: 'Dessin',      t1: 9.0,  t2: 10.0, t3: 0.0, c: _pink),
    (m: 'Sport',       t1: 8.5,  t2: 8.0,  t3: 0.0, c: _teal),
  ];

  double _avgOf(double Function(({String m, double t1, double t2, double t3, Color c}) r) fn) {
    final vals = _rows.map(fn).where((v) => v > 0).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  @override
  Widget build(BuildContext context) {
    final avgT1 = _avgOf((r) => r.t1);
    final avgT2 = _avgOf((r) => r.t2);

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A0500), _dark, _terra],
                  stops: [0.0, 0.4, 1.0],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _terra.withOpacity(0.40),
                  blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -4)],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long_rounded,
                    color: _gold, size: 22),
                const SizedBox(width: 10),
                const Text('Bulletin Trimestriel',
                    style: TextStyle(color: _white, fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 4),
              Text('Année 2025–2026  ·  Classe CE1',
                  style: TextStyle(color: _white.withOpacity(0.60),
                      fontSize: 11)),
              const SizedBox(height: 18),
              Row(children: [
                _TrimesterAvg(label: 'Trim. 1', avg: avgT1),
                const SizedBox(width: 10),
                _TrimesterAvg(label: 'Trim. 2', avg: avgT2, current: true),
                const SizedBox(width: 10),
                _TrimesterAvg(label: 'Trim. 3', avg: null),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Détail par matière',
              style: TextStyle(color: _ink, fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          // Table
          Container(
            decoration: ScolarisSurface.card(radius: 16),
            clipBehavior: Clip.hardEdge,
            child: Column(children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: const Color(0xFFF3EAE0),
                child: Row(children: [
                  const Expanded(flex: 4,
                      child: Text('Matière', style: TextStyle(
                          color: _muted, fontSize: 11,
                          fontWeight: FontWeight.w700))),
                  for (final t in ['T1', 'T2', 'T3'])
                    SizedBox(width: 46,
                        child: Text(t, textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: _muted, fontSize: 11,
                                fontWeight: FontWeight.w700))),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFE2D0C0)),
              for (int i = 0; i < _rows.length; i++) ...[
                _BulletinRow(row: _rows[i]),
                if (i < _rows.length - 1)
                  const Divider(height: 1,
                      color: Color(0xFFF0E4D8), indent: 16),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TrimesterAvg extends StatelessWidget {
  final String label;
  final double? avg;
  final bool current;
  const _TrimesterAvg({required this.label, required this.avg,
      this.current = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: current ? _white.withOpacity(0.20) : _white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: current ? Border.all(color: _white.withOpacity(0.40)) : null,
      ),
      child: Column(children: [
        Text(label, style: TextStyle(
            color: _white.withOpacity(current ? 0.90 : 0.50),
            fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(avg != null ? avg!.toStringAsFixed(1) : '—',
            style: TextStyle(
                color: current ? _gold : _white.withOpacity(0.40),
                fontSize: 18, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _BulletinRow extends StatelessWidget {
  final ({String m, double t1, double t2, double t3, Color c}) row;
  const _BulletinRow({required this.row});

  Widget _cell(double v) {
    if (v == 0.0) return const SizedBox(width: 46,
        child: Center(child: Text('—', style: TextStyle(color: _muted, fontSize: 12))));
    final good = v >= 7.0;
    return SizedBox(width: 46,
        child: Center(child: Text(v.toStringAsFixed(1),
            style: TextStyle(
                color: good ? _green : _terra,
                fontSize: 13, fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(flex: 4, child: Row(children: [
          Container(
            width: 9, height: 9,
            decoration: BoxDecoration(
              color: row.c, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: row.c.withOpacity(0.45),
                  blurRadius: 5)],
            ),
          ),
          const SizedBox(width: 10),
          Text(row.m, style: const TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
        _cell(row.t1),
        _cell(row.t2),
        _cell(row.t3),
      ]),
    );
  }
}
