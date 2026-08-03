import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/platform_admin.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/db_providers.dart';
import '../../presentation/providers/nav_providers.dart';

const _white = Colors.white;

/// Bannière d'alerte d'abonnement — affichée en haut du contenu quand l'offre
/// expire, est en retard de paiement, ou que l'essai touche à sa fin. Cliquable
/// pour aller à la page « Mon abonnement » via [navIntentProvider].
///
/// Réservée à l'admin (qui paie et peut agir) : les autres rôles ne la voient
/// pas. Le shell décide de l'inclure ou non selon le rôle.
class SubscriptionAlertBanner extends ConsumerWidget {
  const SubscriptionAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    if (PlatformAdmins.isPlatformAdmin(user)) return const SizedBox.shrink();

    final sub = ref.watch(subscriptionProvider).valueOrNull;
    if (sub == null) return const SizedBox.shrink();

    final days = sub.daysLeft;
    // `sub.isReadOnly` reflète le VRAI verdict de la base (RLS), pas juste
    // `status` — qui reste souvent bloqué sur 'trial' indéfiniment tant que
    // rien ne le bascule. Sans ça, la bannière continuerait de dire « se
    // termine aujourd'hui » indéfiniment après le vrai dépassement.
    late final bool show;
    late final Color color;
    late final IconData icon;
    late final String message;

    if (sub.isReadOnly) {
      show = true;
      icon = Icons.lock_clock_rounded;
      if (sub.status == 'trial') {
        color = const Color(0xFFDC2626);
        message = 'Votre essai gratuit est terminé. Vos données restent '
            'visibles, mais en lecture seule — choisissez une offre pour '
            'continuer à les modifier.';
      } else if (sub.status == 'past_due') {
        color = const Color(0xFFEA580C);
        message = 'Paiement en retard. Vos données restent visibles, mais '
            'en lecture seule jusqu\'à régularisation.';
      } else {
        color = const Color(0xFFDC2626);
        message = 'Votre abonnement a expiré. Vos données restent visibles, '
            'mais en lecture seule — réactivez une offre pour continuer à '
            'les modifier.';
      }
    } else if (sub.status == 'trial' && days <= 5) {
      show = true;
      color = const Color(0xFFC17F24);
      icon = Icons.timelapse_rounded;
      message = days <= 0
          ? 'Votre essai gratuit se termine aujourd\'hui. Choisissez une offre pour continuer.'
          : 'Votre essai gratuit se termine dans $days jour${days > 1 ? 's' : ''}. Choisissez une offre.';
    } else {
      show = false;
      color = const Color(0xFF8B1A00);
      icon = Icons.info_outline;
      message = '';
    }
    if (!show) return const SizedBox.shrink();

    return Material(
      color: color.withValues(alpha: .10),
      child: InkWell(
        onTap: () => ref.read(navIntentProvider.notifier).state = 'nav.subscription',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: color.withValues(alpha: .25))),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Voir les offres',
                    style: TextStyle(
                        fontSize: 11.5, color: _white, fontWeight: FontWeight.w700)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 13, color: _white),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
