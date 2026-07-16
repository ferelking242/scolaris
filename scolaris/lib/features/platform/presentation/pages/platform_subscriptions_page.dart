import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../widgets/platform_charts.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// Suivi des abonnements & du revenu de la plateforme (observation).
class PlatformSubscriptionsPage extends StatelessWidget {
  const PlatformSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final subs = [...PlatformMock.schools]
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    final mrr = PlatformMock.mrr;

    return PageScaffold(
      title: 'Abonnements',
      subtitle: 'Revenu récurrent & cycle de vie des offres',
      actions: const [PlatformSearchLauncher()],
      child: Column(children: [
        // ── Bandeau revenu ─────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ScolarisPalette.terracotta, ScolarisPalette.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Revenu mensuel récurrent (MRR)',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${groupThousands(mrr)} FCFA',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5)),
                const SizedBox(height: 2),
                Text('≈ ${groupThousands(mrr * 12)} FCFA / an · ${PlatformMock.paying} écoles payantes',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              ]),
            ),
            const Icon(Icons.trending_up_rounded, color: Colors.white, size: 44),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Évolution du MRR + répartition par offre ───────────────────────
        LayoutBuilder(builder: (_, c) {
          final trend = DataPanel(
            title: 'Évolution du MRR (6 mois)',
            child: PlatformTrendChart(
              values: PlatformMock.mrrTrend,
              labels: PlatformMock.trendMonths,
              color: ScolarisPalette.gold,
              leftLabel: (v) => '${(v / 1000).round()}k',
            ),
          );
          const donut = DataPanel(
            title: 'Écoles par offre',
            child: PlatformPlanDonut(),
          );
          if (c.maxWidth < 720) {
            return Column(children: [
              trend,
              const SizedBox(height: 14),
              donut,
            ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: trend),
              const SizedBox(width: 14),
              const Expanded(flex: 2, child: donut),
            ],
          );
        }),
        const SizedBox(height: 14),

        // ── Répartition du revenu par offre ────────────────────────────────
        _RevenueByPlan(),
        const SizedBox(height: 14),

        // ── Table des abonnements ──────────────────────────────────────────
        DataPanel(
          title: 'Abonnements par école',
          child: DataTablePanel(
            columns: const ['École', 'Offre', 'Statut', 'Échéance', 'Montant/mois'],
            flex: const [3, 2, 2, 3, 2],
            rows: [
              for (final s in subs)
                [
                  Text(s.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.cInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: PlanBadge(plan: s.plan)),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: SubStatusBadge(status: s.status)),
                  _Deadline(school: s),
                  Text('${groupThousands(s.plan.monthlyPrice)} F',
                      style: TextStyle(
                          color: s.isPaying ? context.cInk : context.cMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _Deadline extends StatelessWidget {
  final PlatformSchool school;
  const _Deadline({required this.school});
  @override
  Widget build(BuildContext context) {
    final d = school.daysLeft;
    final overdue = d < 0;
    final soon = d >= 0 && d <= 7;
    final color = overdue
        ? ScolarisPalette.terracotta
        : soon
            ? ScolarisPalette.orange
            : context.cMuted;
    final label = overdue
        ? 'Dépassée de ${-d} j'
        : d == 0
            ? "Aujourd'hui"
            : 'Dans $d j';
    return Text(label,
        style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: (overdue || soon) ? FontWeight.w700 : FontWeight.w500));
  }
}

class _RevenueByPlan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Revenu par offre = nb écoles payantes de l'offre × prix mensuel.
    final payingByPlan = {for (final p in PlatformPlan.values) p: 0};
    for (final s in PlatformMock.schools) {
      if (s.isPaying) payingByPlan[s.plan] = (payingByPlan[s.plan] ?? 0) + 1;
    }
    final total = PlatformMock.mrr;

    return DataPanel(
      title: 'Revenu par offre',
      child: Column(children: [
        for (final p in PlatformPlan.values) ...[
          Builder(builder: (context) {
            final revenue = (payingByPlan[p] ?? 0) * p.monthlyPrice;
            final ratio = total == 0 ? 0.0 : revenue / total;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PlanBadge(plan: p),
                const Spacer(),
                Text('${groupThousands(revenue)} F',
                    style: TextStyle(
                        color: context.cInk,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: context.cSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(p.color),
                ),
              ),
              if (p != PlatformPlan.max) const SizedBox(height: 12),
            ]);
          }),
        ],
      ]),
    );
  }
}
