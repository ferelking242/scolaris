import 'package:flutter/material.dart';
  import '../../../../../shared/widgets/page_scaffold.dart';

  /// Page Abonnement — Maître Bobo travaux en cours (dépendances manquantes sur main).
  /// Cette page sera complète une fois que les providers SbPlan/SbSubscription seront 
  /// intégrés côté main (SbSubscription, SbPlan, subscriptionProvider…).
  class AdminSubscriptionPage extends StatelessWidget {
    const AdminSubscriptionPage({super.key});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        body: CollapsingPageScaffold(
          title: 'Abonnement',
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    size: 64, color: cs.primary.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('Gestion des abonnements',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                const SizedBox(height: 8),
                Text('Fonctionnalité en préparation',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }
  }
  