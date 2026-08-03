import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_repository.dart';
import '../../data/platform_school_aggregates.dart';
import '../platform_providers.dart';
import '../widgets/platform_charts.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// Suivi des abonnements & du revenu de la plateforme (observation) — sur les
/// vraies écoles (cf. [PlatformRepository]).
class PlatformSubscriptionsPage extends ConsumerWidget {
  const PlatformSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(platformSchoolsProvider);
    return PageScaffold(
      title: 'Abonnements',
      subtitle: 'Revenu récurrent & cycle de vie des offres',
      actions: const [PlatformSearchLauncher()],
      child: schoolsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
        ),
        data: (all) => _body(context, all),
      ),
    );
  }

  Widget _body(BuildContext context, List<PlatformSchool> all) {
    final subs = [...all]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    final mrr = all.mrr;
    final now = DateTime.now();

    return Column(children: [
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
              Text('≈ ${groupThousands(mrr * 12)} FCFA / an · ${all.paying} écoles payantes',
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
            values: all.mrrTrend(now),
            labels: all.trendMonths(now),
            color: ScolarisPalette.gold,
            leftLabel: (v) => '${(v / 1000).round()}k',
          ),
        );
        final donut = DataPanel(
          title: 'Écoles par offre',
          child: PlatformPlanDonut(breakdown: all.planBreakdown),
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
            Expanded(flex: 2, child: donut),
          ],
        );
      }),
      const SizedBox(height: 14),

      // ── Répartition du revenu par offre ────────────────────────────────
      _RevenueByPlan(schools: all),
      const SizedBox(height: 14),

      // ── Table des abonnements ──────────────────────────────────────────
      DataPanel(
        title: 'Abonnements par école',
        child: subs.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Aucune école',
                description: 'Aucun établissement sur la plateforme pour l\'instant.')
            : DataTablePanel(
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
    ]);
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
  final List<PlatformSchool> schools;
  const _RevenueByPlan({required this.schools});
  @override
  Widget build(BuildContext context) {
    // Revenu par offre = nb écoles payantes de l'offre × prix mensuel.
    final payingByPlan = {for (final p in PlatformPlan.values) p: 0};
    for (final s in schools) {
      if (s.isPaying) payingByPlan[s.plan] = (payingByPlan[s.plan] ?? 0) + 1;
    }
    final total = schools.mrr;

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
