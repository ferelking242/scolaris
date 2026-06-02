import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/mock_data.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink2   = Color(0xFF1A0A00);
const _muted2 = Color(0xFF7A5C44);
const _white  = Colors.white;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _loading = true;

  static const _summary = MockData.attendanceSummary;
  static final _weekly  = MockData.weeklyAttendance;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000),
        () { if (mounted) setState(() => _loading = false); });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Mes présences',
      subtitle: 'Trimestre 2 · ${_summary.joursTotal} jours de cours',
      actions: [
        ActionButton(label: 'Exporter', icon: Icons.download_rounded, onTap: () {}),
      ],
      child: Skeletonizer(
        enabled: _loading,
        effect: const ShimmerEffect(
          baseColor: Color(0xFFDDD6CE),
          highlightColor: Color(0xFFEFEAE3),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 1. Cartes résumé ────────────────────────────────────────
          _SummaryCards(summary: _summary),
          const SizedBox(height: 18),

          // ── 2. Taux visuels ─────────────────────────────────────────
          _RateCards(summary: _summary),
          const SizedBox(height: 18),

          // ── 3. Graphique circulaire + légende ────────────────────────
          _SectionHeader(icon: Icons.pie_chart_rounded, title: 'Répartition des présences'),
          const SizedBox(height: 10),
          _PresencePieCard(summary: _summary),
          const SizedBox(height: 18),

          // ── 4. Bar chart semaines ────────────────────────────────────
          _SectionHeader(icon: Icons.bar_chart_rounded, title: 'Présences par semaine'),
          const SizedBox(height: 10),
          _WeeklyBarCard(weekly: _weekly),
          const SizedBox(height: 18),

          // ── 5. Courbe de présence ────────────────────────────────────
          _SectionHeader(icon: Icons.show_chart_rounded, title: 'Évolution du taux de présence'),
          const SizedBox(height: 10),
          _PresenceLineCard(weekly: _weekly),
          const SizedBox(height: 18),

          // ── 6. Détail des journées ───────────────────────────────────
          _SectionHeader(icon: Icons.list_alt_rounded, title: 'Détail des absences & retards'),
          const SizedBox(height: 10),
          _AttendanceDetail(),
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
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_terra, _orange],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: _white, size: 15),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(
          fontSize: 14, color: _ink2, fontWeight: FontWeight.w800)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 4 cartes résumé (présents, absents, retards, jours total)
// ══════════════════════════════════════════════════════════════════════════
class _SummaryCards extends StatelessWidget {
  final ({int joursTotal, int presents, int absents, int retards, double tauxPresence, double tauxAbsence}) summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.check_circle_rounded, label: 'Jours présents', val: '${summary.presents}', color: _green),
      (icon: Icons.cancel_rounded,       label: 'Jours absents',  val: '${summary.absents}',  color: _terra),
      (icon: Icons.access_time_rounded,  label: 'Retards',        val: '${summary.retards}',  color: _gold),
      (icon: Icons.calendar_today_rounded, label: 'Total jours',  val: '${summary.joursTotal}', color: const Color(0xFF0891B2)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: items.map((it) => _SummaryCard(
        icon: it.icon, label: it.label, val: it.val, color: it.color,
      )).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label, val;
  final Color color;
  const _SummaryCard({required this.icon, required this.label, required this.val, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.14), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -2),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.75)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: _white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(val, style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 11, color: _muted2, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Taux présence / absence (progress bars)
// ══════════════════════════════════════════════════════════════════════════
class _RateCards extends StatelessWidget {
  final ({int joursTotal, int presents, int absents, int retards, double tauxPresence, double tauxAbsence}) summary;
  const _RateCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        _RateBar(label: 'Taux de présence', pct: summary.tauxPresence / 100, color: _green,
            valStr: '${summary.tauxPresence.toStringAsFixed(1)} %'),
        const SizedBox(height: 14),
        _RateBar(label: 'Taux d\'absence', pct: summary.tauxAbsence / 100, color: _terra,
            valStr: '${summary.tauxAbsence.toStringAsFixed(1)} %'),
        const SizedBox(height: 14),
        _RateBar(
          label: 'Retards',
          pct: summary.retards / summary.joursTotal,
          color: _gold,
          valStr: '${(summary.retards / summary.joursTotal * 100).toStringAsFixed(1)} %',
        ),
      ]),
    );
  }
}

class _RateBar extends StatelessWidget {
  final String label, valStr;
  final double pct;
  final Color color;
  const _RateBar({required this.label, required this.pct, required this.color, required this.valStr});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: _ink2, fontWeight: FontWeight.w600))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.30)),
          ),
          child: Text(valStr, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Pie chart présence
// ══════════════════════════════════════════════════════════════════════════
class _PresencePieCard extends StatelessWidget {
  final ({int joursTotal, int presents, int absents, int retards, double tauxPresence, double tauxAbsence}) summary;
  const _PresencePieCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.joursTotal.toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(children: [
        // Pie
        SizedBox(
          width: 140, height: 140,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 3,
              centerSpaceRadius: 42,
              sections: [
                PieChartSectionData(
                  value: summary.presents.toDouble(),
                  color: _green, radius: 28, showTitle: false,
                ),
                PieChartSectionData(
                  value: summary.absents.toDouble(),
                  color: _terra, radius: 24, showTitle: false,
                ),
                PieChartSectionData(
                  value: summary.retards.toDouble(),
                  color: _gold, radius: 24, showTitle: false,
                ),
              ],
            )),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${summary.tauxPresence.toStringAsFixed(0)}%',
                  style: const TextStyle(color: _green, fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('présent', style: TextStyle(color: _muted2, fontSize: 10)),
            ]),
          ]),
        ),
        const SizedBox(width: 20),

        // Légende
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PieLegend(color: _green,  label: 'Présents',  val: summary.presents,  total: total),
            const SizedBox(height: 12),
            _PieLegend(color: _terra,  label: 'Absents',   val: summary.absents,   total: total),
            const SizedBox(height: 12),
            _PieLegend(color: _gold,   label: 'Retards',   val: summary.retards,   total: total),
          ],
        )),
      ]),
    );
  }
}

class _PieLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int val;
  final double total;
  const _PieLegend({required this.color, required this.label, required this.val, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (val / total * 100).toStringAsFixed(1) : '0.0';
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: _ink2, fontWeight: FontWeight.w600))),
      Text('$val j · $pct%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Bar chart semaines
// ══════════════════════════════════════════════════════════════════════════
class _WeeklyBarCard extends StatelessWidget {
  final List<MockAttendanceStat> weekly;
  const _WeeklyBarCard({required this.weekly});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Légende
        Wrap(spacing: 14, runSpacing: 6, children: [
          _BarLegend(color: _green, label: 'Présents'),
          _BarLegend(color: _terra, label: 'Absents'),
          _BarLegend(color: _gold,  label: 'Retards'),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 160,
          child: BarChart(BarChartData(
            maxY: 6.0,
            minY: 0.0,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: 2.0,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: _ink2.withOpacity(0.06), strokeWidth: 1.0),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22.0,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= weekly.length) return const SizedBox();
                  return Text(weekly[i].label, style: const TextStyle(
                      color: _muted2, fontSize: 9.5, fontWeight: FontWeight.w600));
                },
              )),
            ),
            barGroups: weekly.asMap().entries.map((e) =>
              BarChartGroupData(x: e.key, groupVertically: false, barRods: [
                BarChartRodData(
                  toY: e.value.presents,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: LinearGradient(
                    colors: [_green.withOpacity(0.8), _green],
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  ),
                ),
                BarChartRodData(
                  toY: e.value.absents,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: LinearGradient(
                    colors: [_terra.withOpacity(0.8), _terra],
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  ),
                ),
                BarChartRodData(
                  toY: e.value.retards,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: LinearGradient(
                    colors: [_gold.withOpacity(0.8), _gold],
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  ),
                ),
              ])
            ).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8.0,
                getTooltipItem: (g, _, rod, rodIndex) {
                  final labels = ['Présents', 'Absents', 'Retards'];
                  return BarTooltipItem(
                    '${labels[rodIndex]}: ${rod.toY.toInt()} j',
                    const TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
          )),
        ),
      ]),
    );
  }
}

class _BarLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _BarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 11, color: _muted2, fontWeight: FontWeight.w600)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════
// Line chart — évolution du taux de présence
// ══════════════════════════════════════════════════════════════════════════
class _PresenceLineCard extends StatelessWidget {
  final List<MockAttendanceStat> weekly;
  const _PresenceLineCard({required this.weekly});

  @override
  Widget build(BuildContext context) {
    final spots = weekly.asMap().entries.map((e) {
      final total = e.value.presents + e.value.absents + e.value.retards;
      final pct = total > 0 ? (e.value.presents / total * 100) : 100.0;
      return FlSpot(e.key.toDouble(), pct);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: SizedBox(
        height: 150,
        child: LineChart(LineChartData(
          minY: 50.0, maxY: 105.0,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: 25.0,
            getDrawingHorizontalLine: (_) => FlLine(
                color: _ink2.withOpacity(0.06), strokeWidth: 1.0),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 32.0,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                  style: const TextStyle(color: _muted2, fontSize: 9, fontWeight: FontWeight.w600)),
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 22.0,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= weekly.length) return const SizedBox();
                return Text(weekly[i].label, style: const TextStyle(
                    color: _muted2, fontSize: 9.5, fontWeight: FontWeight.w600));
              },
            )),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.30,
              color: _green,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4.0, color: _green,
                  strokeWidth: 2.0, strokeColor: _white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [_green.withOpacity(0.20), _green.withOpacity(0.0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8.0,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '${s.y.toStringAsFixed(0)}% présent',
                const TextStyle(color: _white, fontSize: 11, fontWeight: FontWeight.w700),
              )).toList(),
            ),
          ),
        )),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Détail absences et retards
// ══════════════════════════════════════════════════════════════════════════
class _AttendanceDetail extends StatelessWidget {
  const _AttendanceDetail();

  static const _detail = [
    (date: 'Lundi 6 Mai 2026',   type: 'Absence',  motif: 'Non justifiée',     justified: false),
    (date: 'Mercredi 8 Mai 2026', type: 'Retard',   motif: 'Justifié (médical)', justified: true),
    (date: 'Lundi 20 Mai 2026',  type: 'Absence',  motif: 'Justifiée (maladie)', justified: true),
    (date: 'Vendredi 24 Mai 2026', type: 'Absence', motif: 'Non justifiée',     justified: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _detail.map((d) {
        final isAbsence = d.type == 'Absence';
        final color = d.justified ? _gold : (isAbsence ? _terra : _orange);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAbsence ? Icons.cancel_rounded : Icons.access_time_rounded,
                color: _white, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.type, style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(d.date, style: const TextStyle(
                  color: _ink2, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(d.motif, style: const TextStyle(color: _muted2, fontSize: 11.5)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (d.justified ? _green : _terra).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (d.justified ? _green : _terra).withOpacity(0.30)),
              ),
              child: Text(d.justified ? 'Justifiée' : 'Non justifiée',
                  style: TextStyle(
                      color: d.justified ? _green : _terra,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}
