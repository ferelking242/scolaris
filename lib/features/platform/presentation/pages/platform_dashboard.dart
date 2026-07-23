import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../presentation/providers/nav_providers.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_school_aggregates.dart';
import '../platform_providers.dart';
import '../widgets/platform_charts.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// Vue d'ensemble de la plateforme (KPIs, écoles récentes, alertes) — sur les
/// VRAIES écoles (cf. [PlatformRepository]), plus depuis [PlatformMock].
class PlatformDashboard extends ConsumerWidget {
  const PlatformDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsAsync = ref.watch(platformSchoolsProvider);
    final totalStudentsAsync = ref.watch(platformTotalStudentsProvider);

    return schoolsAsync.when(
      loading: () => const PageScaffold(
        title: 'Vue plateforme',
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => PageScaffold(
        title: 'Vue plateforme',
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Erreur de chargement',
          description: '$e',
        ),
      ),
      data: (schools) {
        final mrr = schools.mrr;
        final totalStudents = totalStudentsAsync.valueOrNull ?? 0;
        final now = DateTime.now();

        return PageScaffold(
          title: 'Vue plateforme',
          subtitle:
              '${schools.total} écoles · ${groupThousands(totalStudents)} élèves suivis',
          actions: const [PlatformSearchLauncher()],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── KPIs ────────────────────────────────────────────────────
              _KpiRow(
                children: [
                  PlatformKpiCard(
                    icon: Icons.apartment_rounded,
                    label: 'Écoles',
                    value: '${schools.total}',
                    sub: '${schools.trials} en essai',
                    accent: ScolarisPalette.terracotta,
                  ),
                  PlatformKpiCard(
                    icon: Icons.verified_rounded,
                    label: 'Écoles payantes',
                    value: '${schools.paying}',
                    sub: 'sur ${schools.total}',
                    accent: ScolarisPalette.forestGreen,
                  ),
                  PlatformKpiCard(
                    icon: Icons.savings_rounded,
                    label: 'MRR estimé',
                    value: '${groupThousands(mrr)} F',
                    sub: '${groupThousands(mrr * 12)} F / an',
                    accent: ScolarisPalette.gold,
                  ),
                  PlatformKpiCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'À surveiller',
                    value: '${schools.needsAttention.length}',
                    sub: '${schools.churned} perdues',
                    accent: ScolarisPalette.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _GrowthPanel(schools: schools, now: now),
              const SizedBox(height: 16),

              LayoutBuilder(builder: (_, c) {
                final recent = _RecentSchools(schools: schools.recent);
                final side = Column(children: [
                  _PlanBreakdown(schools: schools),
                  const SizedBox(height: 16),
                  _AttentionList(items: schools.needsAttention),
                ]);
                if (c.maxWidth < 720) {
                  return Column(children: [
                    recent,
                    const SizedBox(height: 16),
                    side,
                  ]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: recent),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: side),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _KpiRow extends StatelessWidget {
  final List<Widget> children;
  const _KpiRow({required this.children});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final twoCols = c.maxWidth < 640;
      if (twoCols) {
        return Column(children: [
          Row(children: [
            Expanded(child: children[0]),
            const SizedBox(width: 10),
            Expanded(child: children[1]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: children[2]),
            const SizedBox(width: 10),
            Expanded(child: children[3]),
          ]),
        ]);
      }
      return Row(children: [
        for (var i = 0; i < children.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
              child: children[i],
            ),
          ),
      ]);
    });
  }
}

// ── Écoles récentes ──────────────────────────────────────────────────────────
class _RecentSchools extends ConsumerWidget {
  final List<PlatformSchool> schools;
  const _RecentSchools({required this.schools});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schools = this.schools.take(6).toList();
    void open(PlatformSchool s) {
      // Ouvre la fiche inline sur l'onglet « Écoles » (pas de route à part).
      ref.read(selectedPlatformSchoolProvider.notifier).state = s;
      ref.read(navIntentProvider.notifier).state = 'Écoles';
    }
    return DataPanel(
      title: 'Dernières écoles inscrites',
      child: Column(
        children: [
          for (var i = 0; i < schools.length; i++) ...[
            _SchoolLine(school: schools[i], onTap: () => open(schools[i])),
            if (i < schools.length - 1)
              Divider(height: 1, color: context.cBorder.withValues(alpha: .6)),
          ],
        ],
      ),
    );
  }
}

class _SchoolLine extends StatelessWidget {
  final PlatformSchool school;
  final VoidCallback onTap;
  const _SchoolLine({required this.school, required this.onTap});

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return "aujourd'hui";
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    final m = (diff.inDays / 30).floor();
    return 'il y a $m mois';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Avatar(name: school.name, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(school.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.cInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text('${school.city} · ${_ago(school.createdAt)}',
                  style: TextStyle(color: context.cMuted, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          PlanBadge(plan: school.plan),
          const SizedBox(width: 6),
          SubStatusBadge(status: school.status),
        ]),
        ),
      ),
    );
  }
}

// ── Croissance (courbe) ───────────────────────────────────────────────────────
class _GrowthPanel extends StatelessWidget {
  final List<PlatformSchool> schools;
  final DateTime now;
  const _GrowthPanel({required this.schools, required this.now});
  @override
  Widget build(BuildContext context) {
    final t = schools.schoolsTrend(now);
    final delta = t.length >= 2 ? (t.last - t[t.length - 2]).toInt() : 0;
    return DataPanel(
      title: 'Croissance de la plateforme',
      headerActions: [
        Text('${delta >= 0 ? '+' : ''}$delta ce mois',
            style: const TextStyle(
                fontSize: 11.5,
                color: ScolarisPalette.forestGreen,
                fontWeight: FontWeight.w700)),
      ],
      child: PlatformTrendChart(
        values: t,
        labels: schools.trendMonths(now),
        color: ScolarisPalette.terracotta,
        leftLabel: (v) => '${v.toInt()}',
      ),
    );
  }
}

// ── Répartition par offre ────────────────────────────────────────────────────
class _PlanBreakdown extends StatelessWidget {
  final List<PlatformSchool> schools;
  const _PlanBreakdown({required this.schools});
  @override
  Widget build(BuildContext context) {
    final breakdown = schools.planBreakdown;
    final total = schools.total;
    return DataPanel(
      title: 'Répartition par offre',
      child: Column(children: [
        for (final entry in breakdown.entries) ...[
          _PlanRow(plan: entry.key, count: entry.value, total: total),
          if (entry.key != PlatformPlan.max) const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final PlatformPlan plan;
  final int count;
  final int total;
  const _PlanRow({required this.plan, required this.count, required this.total});
  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        PlanBadge(plan: plan),
        const Spacer(),
        Text('$count école${count > 1 ? 's' : ''}',
            style: TextStyle(
                color: context.cInk, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 7,
          backgroundColor: context.cSubtle,
          valueColor: AlwaysStoppedAnimation<Color>(plan.color),
        ),
      ),
    ]);
  }
}

// ── À surveiller ─────────────────────────────────────────────────────────────
class _AttentionList extends StatelessWidget {
  final List<PlatformSchool> items;
  const _AttentionList({required this.items});
  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: 'À surveiller',
      child: items.isEmpty
          ? const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Tout est en ordre',
              description: 'Aucune école en impayé ou essai bientôt terminé.')
          : Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                _AttentionLine(school: items[i]),
                if (i < items.length - 1)
                  Divider(height: 1, color: context.cBorder.withValues(alpha: .6)),
              ],
            ]),
    );
  }
}

class _AttentionLine extends StatelessWidget {
  final PlatformSchool school;
  const _AttentionLine({required this.school});
  @override
  Widget build(BuildContext context) {
    final (icon, color, msg) = switch (school.status) {
      SubStatus.pastDue => (
          Icons.error_outline_rounded,
          ScolarisPalette.orange,
          'Paiement en retard de ${-school.daysLeft} j'
        ),
      SubStatus.expired => (
          Icons.block_rounded,
          ScolarisPalette.terracotta,
          'Abonnement expiré'
        ),
      _ => (
          Icons.hourglass_bottom_rounded,
          ScolarisPalette.gold,
          'Essai — ${school.daysLeft} j restants'
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(school.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.cInk, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(msg, style: TextStyle(color: color, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}
