import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';
import '../../../../../shared/widgets/surface.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _purple = Color(0xFF7C3AED);
const _cyan   = Color(0xFF0891B2);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;

class LibraryStatsPage extends StatelessWidget {
  const LibraryStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = MockLibraryData.readingStats;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _StatsHeader(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // KPI cards row 1
            Row(children: [
              _KpiCard('${s.booksRead}', 'Livres lus', Icons.menu_book_rounded, _terra),
              const SizedBox(width: 10),
              _KpiCard('${s.documentsOpened}', 'Docs ouverts', Icons.description_rounded, _cyan),
            ]),
            const SizedBox(height: 10),
            // KPI cards row 2
            Row(children: [
              _KpiCard('${s.readingHours}h', 'Lecture', Icons.timer_rounded, _purple),
              const SizedBox(width: 10),
              _KpiCard('${s.pagesRead}', 'Pages lues', Icons.article_rounded, _green),
            ]),
            const SizedBox(height: 20),

            // Reading time line chart
            _SectionTitle(Icons.trending_up_rounded, 'Temps de lecture (7 jours)',
                [_terra, _orange]),
            const SizedBox(height: 12),
            Container(
              height: 190,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: ScolarisSurface.card(radius: 18),
              child: _WeeklyLineChart(
                minutes: s.weeklyMinutes,
                days: s.weekDays,
              ),
            ),
            const SizedBox(height: 20),

            // Subject breakdown
            _SectionTitle(Icons.pie_chart_rounded, 'Matières consultées', [_purple, _cyan]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ScolarisSurface.card(radius: 18),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 140, height: 140,
                  child: PieChart(PieChartData(
                    sections: s.subjectBreakdown.map((e) => PieChartSectionData(
                      value: e.pct,
                      color: e.color,
                      radius: 48,
                      showTitle: false,
                    )).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                  )),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: s.subjectBreakdown.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.subject,
                          style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700))),
                      Text('${e.pct.toInt()}%',
                          style: TextStyle(color: e.color, fontSize: 12, fontWeight: FontWeight.w900)),
                    ]),
                  )).toList(),
                )),
              ]),
            ),
            const SizedBox(height: 20),

            // Reading progression
            _SectionTitle(Icons.school_rounded, 'Progression de lecture', [_green, _cyan]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ScolarisSurface.card(radius: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Objectif mensuel', style: TextStyle(
                    color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _GoalBar('Livres lus', 3, 5, _terra),
                const SizedBox(height: 10),
                _GoalBar('Documents ouverts', 14, 20, _cyan),
                const SizedBox(height: 10),
                _GoalBar('Heures de lecture', 4, 8, _purple),
                const SizedBox(height: 10),
                _GoalBar('Pages lues', 312, 500, _green),
              ]),
            ),
            const SizedBox(height: 20),

            // Leaderboard
            _SectionTitle(Icons.emoji_events_rounded, 'Classement des lecteurs', [_gold, _orange]),
            const SizedBox(height: 12),
            Container(
              decoration: ScolarisSurface.card(radius: 18),
              clipBehavior: Clip.hardEdge,
              child: Column(children: [
                for (int i = 0; i < _leaderboard.length; i++)
                  _LeaderboardTile(
                    rank: i + 1,
                    name: _leaderboard[i].name,
                    classe: _leaderboard[i].classe,
                    hours: _leaderboard[i].hours,
                    books: _leaderboard[i].books,
                    isMe: i == 3,
                  ),
              ]),
            ),
            const SizedBox(height: 20),

            // Achievements / badges progression
            _SectionTitle(Icons.military_tech_rounded, 'Prochain badge', [_purple, _terra]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ScolarisSurface.card(radius: 18),
              child: Column(children: [
                Row(children: [
                  Container(width: 50, height: 50,
                    decoration: BoxDecoration(color: _purple.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _purple.withOpacity(0.30))),
                    child: const Center(child: Text('⚡', style: TextStyle(fontSize: 24)))),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Speed Reader', style: TextStyle(
                        color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('Lire 3 documents en 1 heure',
                        style: TextStyle(color: _muted, fontSize: 12)),
                  ])),
                  Text('67%', style: TextStyle(
                      color: _purple, fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.67, minHeight: 8,
                    backgroundColor: _purple.withOpacity(0.10),
                    valueColor: const AlwaysStoppedAnimation(_purple),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('2/3 documents lus cette heure',
                    style: TextStyle(color: _muted, fontSize: 11.5)),
              ]),
            ),
          ]),
        )),
      ]),
    );
  }
}

// ── Leaderboard data ─────────────────────────────────────────────────────────
const _leaderboard = [
  (name: 'Amara Diallo',     classe: '5e A', hours: 28.5, books: 9),
  (name: 'Fatou Camara',     classe: '4e B', hours: 22.0, books: 7),
  (name: 'Ibrahim Konaté',   classe: '3e A', hours: 18.5, books: 6),
  (name: 'Moi (Jean Elève)', classe: '5e A', hours: 4.5,  books: 3),
  (name: 'Nadia Traoré',     classe: '5e B', hours: 3.0,  books: 2),
];

// ── Header ───────────────────────────────────────────────────────────────────
class _StatsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF2D1060), _purple],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 16),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _white),
              onPressed: () => Navigator.pop(context)),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mes statistiques', style: TextStyle(
                color: _white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text('Tableau de bord lecture personnalisé',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ])),
          const Text('📊', style: TextStyle(fontSize: 28)),
        ]),
      )),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  const _SectionTitle(this.icon, this.label, this.gradient);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _white, size: 14)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
  ]);
}

// ── KPI card ─────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String val, label;
  final IconData icon;
  final Color color;
  const _KpiCard(this.val, this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.18)),
      boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: color)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11.5)),
      ]),
    ]),
  ));
}

// ── Weekly line chart ─────────────────────────────────────────────────────────
class _WeeklyLineChart extends StatelessWidget {
  final List<double> minutes;
  final List<String> days;
  const _WeeklyLineChart({required this.minutes, required this.days});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(minutes.length,
            (i) => FlSpot(i.toDouble(), minutes[i]));
    final maxY = (minutes.reduce((a, b) => a > b ? a : b) * 1.25).ceilToDouble();

    return LineChart(LineChartData(
      minX: 0, maxX: minutes.length - 1.0,
      minY: 0, maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 30,
        getDrawingHorizontalLine: (_) => FlLine(
            color: const Color(0xFFDDD6CE), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i >= 0 && i < days.length) {
              return Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(days[i], style: const TextStyle(
                    color: _muted, fontSize: 10, fontWeight: FontWeight.w600)));
            }
            return const SizedBox();
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 32,
          getTitlesWidget: (v, _) {
            if (v == 0) return const SizedBox();
            return Text('${v.toInt()}m', style: const TextStyle(
                color: _muted, fontSize: 9));
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true, curveSmoothness: 0.3,
          color: _terra,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                radius: 4, color: _white,
                strokeColor: _terra, strokeWidth: 2.5),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [_terra.withOpacity(0.25), _terra.withOpacity(0.0)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
            '${s.y.toInt()} min',
            const TextStyle(color: _white, fontSize: 11, fontWeight: FontWeight.w700),
          )).toList(),
        ),
      ),
    ));
  }
}

// ── Goal bar ─────────────────────────────────────────────────────────────────
class _GoalBar extends StatelessWidget {
  final String label;
  final num current, goal;
  final Color color;
  const _GoalBar(this.label, this.current, this.goal, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = (current / goal).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(
            color: _ink, fontSize: 12, fontWeight: FontWeight.w700))),
        Text('$current / $goal', style: TextStyle(
            color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct.toDouble(), minHeight: 7,
          backgroundColor: color.withOpacity(0.10),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

// ── Leaderboard tile ──────────────────────────────────────────────────────────
class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name, classe;
  final double hours;
  final int books;
  final bool isMe;
  const _LeaderboardTile({required this.rank, required this.name,
      required this.classe, required this.hours, required this.books, required this.isMe});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? _terra.withOpacity(0.06) : _white,
        border: Border(
            bottom: BorderSide(color: const Color(0xFFEEE0D0)),
            left: isMe ? BorderSide(color: _terra, width: 4) : BorderSide.none),
      ),
      child: Row(children: [
        // Rank
        SizedBox(width: 32, child: Center(child: rank <= 3
            ? Text(_medals[rank - 1], style: const TextStyle(fontSize: 20))
            : Text('$rank', style: const TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 10),
        // Avatar
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: isMe ? _terra.withOpacity(0.15) : const Color(0xFFEEE0D0),
            shape: BoxShape.circle,
            border: Border.all(color: isMe ? _terra.withOpacity(0.40) : const Color(0xFFDDD6CE)),
          ),
          child: Center(child: Text(name[0],
              style: TextStyle(color: isMe ? _terra : _muted,
                  fontSize: 14, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
              color: isMe ? _terra : _ink,
              fontSize: 12.5, fontWeight: FontWeight.w800)),
          Text(classe, style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        // Stats
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${hours}h', style: TextStyle(color: isMe ? _terra : _purple,
              fontSize: 13, fontWeight: FontWeight.w900)),
          Text('$books livres', style: const TextStyle(color: _muted, fontSize: 10.5)),
        ]),
      ]),
    );
  }
}
