import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/db_providers.dart';
import '../../presentation/providers/nav_providers.dart';

const _terra = Color(0xFF8B1A00);
const _ink   = Color(0xFF1A0A00);
const _muted = Color(0xFF7A5C44);

/// Hiérarchie des plans (simple < pro < max).
const _planOrder = {'simple': 0, 'pro': 1, 'max': 2};

bool planMeetsRequirement(String? current, String required) =>
    (_planOrder[current] ?? -1) >= (_planOrder[required] ?? 99);

String _planLabel(String plan) => switch (plan) {
      'pro' => 'Pro',
      'max' => 'Max',
      _ => plan.toUpperCase(),
    };

Color _planColor(String plan) => switch (plan) {
      'pro' => const Color(0xFF0E7490),
      'max' => const Color(0xFF7C3AED),
      _ => _terra,
    };

/// Remplace son [child] par une bannière "upgrade" si l'offre courante
/// ne couvre pas [minPlan]. Sinon affiche [child] normalement.
class PlanGate extends ConsumerWidget {
  final String minPlan;
  final Widget child;
  final String featureLabel;
  final String? description;
  final IconData icon;

  const PlanGate({
    super.key,
    required this.minPlan,
    required this.child,
    required this.featureLabel,
    this.description,
    this.icon = Icons.lock_outline_rounded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currentPlanCodeProvider).valueOrNull;
    if (planMeetsRequirement(code, minPlan)) return child;
    return _UpgradeBanner(
      minPlan: minPlan,
      featureLabel: featureLabel,
      description: description,
      icon: icon,
    );
  }
}

/// Bannière standalone (sans child à remplacer) — pour ajouter une section
/// "verrouillée" dans une page (ex : bloc Paiement en ligne).
class PlanGateBanner extends ConsumerWidget {
  final String minPlan;
  final String featureLabel;
  final String? description;
  final IconData icon;
  final List<String> bullets;

  const PlanGateBanner({
    super.key,
    required this.minPlan,
    required this.featureLabel,
    this.description,
    this.icon = Icons.lock_outline_rounded,
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currentPlanCodeProvider).valueOrNull;
    if (planMeetsRequirement(code, minPlan)) return const SizedBox.shrink();
    return _UpgradeBanner(
      minPlan: minPlan,
      featureLabel: featureLabel,
      description: description,
      icon: icon,
      bullets: bullets,
    );
  }
}

class _UpgradeBanner extends ConsumerWidget {
  final String minPlan;
  final String featureLabel;
  final String? description;
  final IconData icon;
  final List<String> bullets;

  const _UpgradeBanner({
    required this.minPlan,
    required this.featureLabel,
    this.description,
    this.icon = Icons.lock_outline_rounded,
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _planColor(minPlan);
    final label = _planLabel(minPlan);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: .25)),
        gradient: LinearGradient(
          colors: [c.withValues(alpha: .04), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(featureLabel,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.workspace_premium_rounded, size: 11, color: c),
                    const SizedBox(width: 4),
                    Text('Offre $label',
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
                  ]),
                ),
              ]),
              if (description != null) ...[
                const SizedBox(height: 3),
                Text(description!,
                    style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ]),
          ),
        ]),
        if (bullets.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(Icons.check_circle_outline_rounded, size: 13, color: c),
                  const SizedBox(width: 7),
                  Text(b, style: const TextStyle(fontSize: 12, color: _muted)),
                ]),
              )),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                ref.read(navIntentProvider.notifier).state = 'nav.subscription',
            icon: Icon(Icons.arrow_forward_rounded, size: 14, color: c),
            label: Text('Voir les offres', style: TextStyle(color: c, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.withValues(alpha: .4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ]),
    );
  }
}
