import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../presentation/providers/nav_providers.dart';
import '../../data/platform_mock_data.dart';
import '../platform_providers.dart';
import '../widgets/platform_charts.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// Vue d'ensemble de la plateforme (KPIs, écoles récentes, alertes).
class PlatformDashboard extends StatelessWidget {
  const PlatformDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final mrr = PlatformMock.mrr;
    return PageScaffold(
      title: 'Vue plateforme',
      subtitle:
          '${PlatformMock.total} écoles · ${groupThousands(PlatformMock.totalStudents)} élèves suivis',
      actions: const [PlatformSearchLauncher()],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPIs ────────────────────────────────────────────────────────
          _KpiRow(
            children: [
              PlatformKpiCard(
                icon: Icons.apartment_rounded,
                label: 'Écoles',
                value: '${PlatformMock.total}',
                sub: '${PlatformMock.trials} en essai',
                accent: ScolarisPalette.terracotta,
              ),
              PlatformKpiCard(
                icon: Icons.verified_rounded,
                label: 'Écoles payantes',
                value: '${PlatformMock.paying}',
                sub: 'sur ${PlatformMock.total}',
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
                value: '${PlatformMock.needsAttention.length}',
                sub: '${PlatformMock.churned} perdues',
                accent: ScolarisPalette.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _GrowthPanel(),
          const SizedBox(height: 16),

          LayoutBuilder(builder: (_, c) {
            const recent = _RecentSchools();
            const side = Column(children: [
              _PlanBreakdown(),
              SizedBox(height: 16),
              _AttentionList(),
            ]);
            if (c.maxWidth < 720) {
              return const Column(children: [
                recent,
                SizedBox(height: 16),
                side,
              ]);
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: recent),
                SizedBox(width: 16),
                Expanded(flex: 2, child: side),
              ],
            );
          }),
        ],
      ),
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
  const _RecentSchools();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schools = PlatformMock.recent.take(6).toList();
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
    final diff = DateTime(2026, 6, 30).difference(d);
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
  const _GrowthPanel();
  @override
  Widget build(BuildContext context) {
    const t = PlatformMock.schoolsTrend;
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
        values: PlatformMock.schoolsTrend,
        labels: PlatformMock.trendMonths,
        color: ScolarisPalette.terracotta,
        leftLabel: (v) => '${v.toInt()}',
      ),
    );
  }
}

// ── Répartition par offre ────────────────────────────────────────────────────
class _PlanBreakdown extends StatelessWidget {
  const _PlanBreakdown();
  @override
  Widget build(BuildContext context) {
    final breakdown = PlatformMock.planBreakdown;
    final total = PlatformMock.total;
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
  const _AttentionList();
  @override
  Widget build(BuildContext context) {
    final items = PlatformMock.needsAttention;
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
