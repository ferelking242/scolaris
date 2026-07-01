import 'package:flutter/material.dart';

import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';

/// Carte KPI de la console plateforme — même esprit que le dashboard admin,
/// mais entièrement dérivée du thème (clair/sombre).
class PlatformKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color accent;
  const PlatformKpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: accent),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -.3)),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: context.cMuted, fontSize: 11, fontWeight: FontWeight.w500)),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!,
              style: TextStyle(color: context.cMuted.withValues(alpha: .7), fontSize: 10)),
        ],
      ]),
    );
  }
}

/// Pastille d'offre (Simple / Pro / Max) aux couleurs de l'offre.
class PlanBadge extends StatelessWidget {
  final PlatformPlan plan;
  const PlanBadge({super.key, required this.plan});
  @override
  Widget build(BuildContext context) {
    final c = plan.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: .3)),
      ),
      child: Text(plan.label,
          style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w800)),
    );
  }
}

/// Pastille de statut d'abonnement, réutilise les couleurs sémantiques du
/// design system ([StatusPill]).
class SubStatusBadge extends StatelessWidget {
  final SubStatus status;
  const SubStatusBadge({super.key, required this.status});
  @override
  Widget build(BuildContext context) => switch (status) {
        SubStatus.active => StatusPill.success(status.label),
        SubStatus.trial => StatusPill.info(status.label),
        SubStatus.pastDue => StatusPill.warning(status.label),
        SubStatus.expired => StatusPill.danger(status.label),
        SubStatus.canceled => StatusPill.neutral(status.label),
      };
}

/// Formatte un entier en milliers séparés par une espace insécable (1 340).
String groupThousands(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}
