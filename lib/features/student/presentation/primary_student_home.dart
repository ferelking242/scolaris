import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/sources/remote/supabase_db_source.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../shared/data/timetable_data.dart' show getSubjectMeta;
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/surface.dart';
import 'pages/grades_page.dart';
import 'pages/schedule_page.dart';

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
// Neutres : jamais figés — voir `context.c*` (page_scaffold.dart).
// `_white` reste légitime : uniquement du texte posé sur un fond coloré.
const _white  = Colors.white;

// ── Matières CP→CM2 (icônes ; couleur réelle via getSubjectMeta) ────────────
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

/// Couleur réelle d'une matière (couvre CP→lycée).
Color _colorFor(String name) => getSubjectMeta(name).color;

// ══════════════════════════════════════════════════════════════════════════
// Dashboard primaire — variante « enfant » du shell unique StudentHome.
// Branché sur les mêmes providers réels que le dashboard secondaire, mais avec
// un barème /10 et une présentation adaptée au primaire.
// ══════════════════════════════════════════════════════════════════════════
class PrimaryDashboard extends ConsumerWidget {
  const PrimaryDashboard({super.key});

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'E';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user     = ref.watch(authSessionProvider);
    final name     = user?.fullName ?? 'Élève';
    final initials = _initials(name);
    final profile  = ref.watch(myStudentProfileProvider).valueOrNull;
    final classe   = profile?.classe ?? '';

    final gradesAsync = ref.watch(myGradesProvider);
    final grades      = gradesAsync.valueOrNull ?? const <SbGrade>[];
    final absences    = ref.watch(myAbsencesProvider).valueOrNull ?? const <SbAbsence>[];

    // Barème du CYCLE de l'élève (ex. primaire /10 si l'école l'a réglé ainsi),
    // et non plus un /10 codé en dur. `studentFormatProvider` applique la
    // surcharge par cycle si elle existe, sinon le défaut de l'école.
    final fmt      = ref.watch(studentFormatProvider);
    final maxScore = fmt.maxScore;
    final isLetter = fmt.gradingScale == 'letter';

    final classId = profile?.classId;
    final scheduleAsync = (classId != null && classId.isNotEmpty)
        ? ref.watch(schedulesForClassProvider(classId))
        : const AsyncValue<List<SbSchedule>>.data([]);
    final schedules = scheduleAsync.valueOrNull ?? const <SbSchedule>[];

    final loading = gradesAsync.isLoading || scheduleAsync.isLoading;

    // Moyenne exprimée sur le barème du cycle. `avgRatio` (0→1) sert au donut ;
    // `avgScore` est la valeur affichée (ex. 8,0 en /10, 16 en /20, 70 en /100).
    final avgRatio = grades.isEmpty
        ? 0.0
        : (grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length) / 20;
    final avgScore = avgRatio * maxScore;

    // EDT du jour.
    final todayDay = DateTime.now().weekday;
    final todaySlots = (schedules.where((s) => s.dayOfWeek == todayDay).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime)))
        .map((s) => (
              m: s.subjectName ?? 'Cours',
              t: s.startTime,
              c: _colorFor(s.subjectName ?? ''),
            ))
        .toList();

    // Dernières notes (les plus récentes d'abord).
    final recent = ([...grades]..sort((a, b) =>
            (b.gradedAt ?? DateTime(2000)).compareTo(a.gradedAt ?? DateTime(2000))))
        .toList();
    final barNotes = recent
        .take(6)
        .map((g) => (
              m: g.subjectName ?? g.title ?? '—',
              n: (g.outOf20 / 20) * maxScore,
              c: _colorFor(g.subjectName ?? ''),
            ))
        .toList();

    return Container(
      color: context.cPage,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 1. Hero card ─────────────────────────────────────────────
          _HeroCard(name: name, initials: initials, classe: classe),
          const SizedBox(height: 16),

          // ── 2. Moyenne + mini-stats ──────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _MoyenneDonut(
                ratio: avgRatio,
                valueText: isLetter ? fmt.grade(avgScore) : avgScore.toStringAsFixed(1),
                unitText: isLetter ? '' : '/${maxScore.toStringAsFixed(0)}',
                loading: loading)),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [
              _MiniStatCard(icon: Icons.event_busy_rounded,
                  label: 'Absences', value: '${absences.length}',
                  sub: absences.length > 1 ? 'jours' : 'jour',
                  color: absences.isEmpty ? _green : _terra, loading: loading),
              const SizedBox(height: 10),
              _MiniStatCard(icon: Icons.grading_rounded,
                  label: 'Notes', value: '${grades.length}',
                  sub: 'reçues', color: _gold, loading: loading),
            ])),
          ]),
          const SizedBox(height: 22),

          // ── 3. Graphique notes ────────────────────────────────────────
          _SectionHeader(title: 'Mes notes par matière',
              action: 'Tout voir',
              onAction: () => _push(context, const GradesPage())),
          const SizedBox(height: 10),
          if (loading)
            const SkeletonBox(width: double.infinity, height: 140, radius: 16)
          else if (barNotes.isEmpty)
            const _MiniEmpty(icon: Icons.grading_rounded,
                label: 'Pas encore de notes')
          else
            _NotesBarChart(
                notes: barNotes,
                maxY: maxScore,
                unit: isLetter ? '' : '/${maxScore.toStringAsFixed(0)}'),
          const SizedBox(height: 22),

          // ── 4. Emploi du temps aujourd'hui ────────────────────────────
          _SectionHeader(title: "Aujourd'hui",
              action: 'EDT complet',
              onAction: () => _push(context, const SchedulePage())),
          const SizedBox(height: 10),
          if (loading)
            const SkeletonBox(width: double.infinity, height: 106, radius: 14)
          else if (todaySlots.isEmpty)
            const _MiniEmpty(icon: Icons.event_available_rounded,
                label: "Pas de cours aujourd'hui")
          else
            _TodayTimeline(slots: todaySlots),
          const SizedBox(height: 22),

          // ── 5. Dernières notes ────────────────────────────────────────
          _SectionHeader(title: 'Mes dernières notes',
              action: 'Voir tout',
              onAction: () => _push(context, const GradesPage())),
          const SizedBox(height: 10),
          if (loading) ...[
            for (int i = 0; i < 3; i++) ...[
              const SkeletonListRow(), const SizedBox(height: 8),
            ],
          ] else if (recent.isEmpty)
            const _MiniEmpty(icon: Icons.grading_rounded,
                label: 'Aucune note pour le moment')
          else
            for (final g in recent.take(3)) ...[
              _NoteRow(
                  matiere: g.subjectName ?? g.title ?? '—',
                  note: (g.outOf20 / 20) * maxScore,
                  max: maxScore,
                  date: _fmtShort(g.gradedAt),
                  color: _colorFor(g.subjectName ?? '')),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 22),

          // ── 6. Citation ───────────────────────────────────────────────
          const _AfricanQuote(),
        ]),
      ),
    );
  }

  static String _fmtShort(DateTime? d) {
    if (d == null) return '';
    const mois = ['janv.','févr.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
    return '${d.day} ${mois[d.month - 1]}';
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Widgets de présentation (design enfant, alimentés par des données réelles)
// ══════════════════════════════════════════════════════════════════════════

// ── Hero card ─────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String name, initials, classe;
  const _HeroCard({required this.name, required this.initials,
      required this.classe});

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
          _Avatar(initials: initials),
          const SizedBox(width: 16),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting,
                style: TextStyle(color: _white.withOpacity(0.65),
                    fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(name,
                style: const TextStyle(color: _white, fontSize: 20,
                    fontWeight: FontWeight.w900, height: 1.1),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (classe.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Badge(label: classe, bg: _gold.withOpacity(0.25),
                  border: _gold.withOpacity(0.5), fg: _gold),
            ],
          ])),
        ]),
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
  /// Remplissage de l'arc (0→1) et textes déjà formatés sur le barème du cycle.
  final double ratio;
  final String valueText, unitText;
  final bool loading;
  const _MoyenneDonut({
    required this.ratio,
    required this.valueText,
    required this.unitText,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final r = ratio.clamp(0.0, 1.0);
    return Container(
      height: 170,
      decoration: ScolarisSurface.themedCard(context, radius: 18),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Moyenne', style: TextStyle(
            color: context.cMuted, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Générale', style: TextStyle(
            color: context.cInk, fontSize: 13, fontWeight: FontWeight.w800)),
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
                      value: r, color: _gold,
                      radius: 14.0, showTitle: false,
                    ),
                    PieChartSectionData(
                      value: 1 - r,
                      color: _gold.withOpacity(0.12),
                      radius: 14.0, showTitle: false,
                    ),
                  ],
                )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(valueText,
                      style: const TextStyle(color: _gold, fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  if (unitText.isNotEmpty)
                    Text(unitText, style: TextStyle(
                        color: context.cMuted, fontSize: 10,
                        fontWeight: FontWeight.w600)),
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
      decoration:
          ScolarisSurface.themedAccent(context, color: color, radius: 12),
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
                  color: context.cMuted, fontSize: 9,
                  fontWeight: FontWeight.w500)),
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
  final double maxY;
  final String unit;
  const _NotesBarChart({required this.notes, required this.maxY, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: ScolarisSurface.themedCard(context, radius: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Notes ${unit.isEmpty ? '' : unit}'.trim(), style: TextStyle(
              color: context.cInk, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Récentes', style: TextStyle(
                color: _green, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: BarChart(BarChartData(
          maxY: maxY,
          minY: 0.0,
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxY / 2,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color: context.cBorder, strokeWidth: 1.0),
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
                return Text(short, style: TextStyle(
                    color: context.cMuted, fontSize: 9,
                    fontWeight: FontWeight.w600));
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
                '${r.toY.toStringAsFixed(1)}$unit',
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
                : ScolarisSurface.themedAccent(context, color: s.c, radius: 16),
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
                        child: const Text('1er',
                            style: TextStyle(color: _white,
                                fontSize: 7, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.m,
                        style: TextStyle(
                            color: first ? _white : context.cInk,
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
  final double note, max;
  final Color color;
  const _NoteRow({required this.matiere, required this.note, required this.max,
      required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (max > 0 ? note / max : 0.0).clamp(0.0, 1.0);
    final good = pct >= 0.70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ScolarisSurface.themedCard(context, radius: 14),
      child: Row(children: [
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
            Text(note.toStringAsFixed(1),
                style: TextStyle(color: color, fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(matiere, style: TextStyle(
              color: context.cInk, fontSize: 13, fontWeight: FontWeight.w700),
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
          Text(date, style: TextStyle(color: context.cMuted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ── Mini état vide ─────────────────────────────────────────────────────────
class _MiniEmpty extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniEmpty({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: ScolarisSurface.themedCard(context, radius: 14),
      child: Column(children: [
        Icon(icon, color: context.cMuted.withOpacity(0.5), size: 28),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: context.cMuted, fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ]),
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
      Text(title, style: TextStyle(color: context.cInk, fontSize: 15,
          fontWeight: FontWeight.w800)),
      const Spacer(),
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onAction,
          child: Text(action, style: const TextStyle(color: _terra,
              fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }
}
