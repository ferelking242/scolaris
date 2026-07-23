import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import 'platform_widgets.dart';

/// Courbe de tendance (aire dégradée) — même style que les graphiques élèves.
class PlatformTrendChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;

  /// Formatte les libellés de l'axe vertical (ex. « 8 » ou « 165k »).
  final String Function(double v) leftLabel;

  const PlatformTrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    required this.leftLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = maxV <= 0 ? 1.0 : (maxV * 1.25).ceilToDouble();
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    return SizedBox(
      height: 170,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (values.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: context.cBorder, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i >= 0 && i < labels.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i],
                      style: TextStyle(
                          color: context.cMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                );
              }
              return const SizedBox();
            },
          )),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            getTitlesWidget: (v, _) {
              if (v == 0) return const SizedBox();
              return Text(leftLabel(v),
                  style: TextStyle(color: context.cMuted, fontSize: 9));
            },
          )),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                  radius: 3.5,
                  color: context.cCard,
                  strokeColor: color,
                  strokeWidth: 2),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      )),
    );
  }
}

/// Donut de répartition des écoles par offre + légende.
class PlatformPlanDonut extends StatelessWidget {
  final Map<PlatformPlan, int> breakdown;
  const PlatformPlanDonut({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 130,
        height: 130,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            for (final e in breakdown.entries)
              PieChartSectionData(
                value: e.value.toDouble(),
                color: e.key.color,
                title: '${e.value}',
                radius: 22,
                titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
          ],
        )),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in breakdown.entries) ...[
              Row(children: [
                PlanBadge(plan: e.key),
                const Spacer(),
                Text('${e.value} école${e.value > 1 ? 's' : ''}',
                    style: TextStyle(
                        color: context.cInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
              if (e.key != breakdown.keys.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ]);
  }
}
