import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_repository.dart';
import '../platform_providers.dart';
import '../widgets/platform_search.dart';
import '../widgets/platform_widgets.dart';

/// File des versements Mobile Money reçus des écoles (pas d'agrégateur
/// branché) — à vérifier sur le relevé marchand Scolaris avant de confirmer.
/// Page à part : c'est une ACTION à traiter (au même titre que les
/// pré-inscriptions côté école), pas une donnée d'observation comme
/// « Abonnements » (MRR, cycle de vie) — les deux ne se mélangent pas.
class PlatformPaymentsPage extends ConsumerWidget {
  const PlatformPaymentsPage({super.key});

  Future<void> _confirm(BuildContext context, WidgetRef ref, PlatformPendingPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer ce versement ?'),
        content: Text(
            'Vérifiez d\'abord sur le relevé marchand Scolaris que '
            '${groupThousands(p.amount.round())} ${p.currency} de « ${p.schoolName} » '
            'est bien arrivé (réf. ${p.reference ?? "—"}) avant de confirmer — '
            'ça active immédiatement leur offre ${p.planCode.toUpperCase()}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PlatformRepository.confirmSubscriptionPayment(p.id);
      ref.invalidate(platformPendingPaymentsProvider);
      ref.invalidate(platformSchoolsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Offre activée pour « ${p.schoolName} ».'),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: ScolarisPalette.terracotta,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, PlatformPendingPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rejeter ce versement ?'),
        content: Text(
            'La référence ${p.reference ?? "—"} de « ${p.schoolName} » sera '
            'marquée invalide — rien ne s\'active.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Retour')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: ScolarisPalette.terracotta),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await PlatformRepository.rejectSubscriptionPayment(p.id);
    if (!context.mounted) return;
    ref.invalidate(platformPendingPaymentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(platformPendingPaymentsProvider);
    return PageScaffold(
      title: 'Paiements',
      subtitle: 'Versements Mobile Money des écoles à vérifier',
      actions: const [PlatformSearchLauncher()],
      child: pendingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Rien à vérifier',
              description: 'Les versements envoyés par les écoles (référence '
                  'Mobile Money saisie depuis « Mon abonnement ») apparaîtront '
                  'ici en attente de confirmation.',
            );
          }
          return DataPanel(
            title: '${items.length} versement(s) en attente',
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                _PendingPaymentRow(
                  payment: items[i],
                  onConfirm: () => _confirm(context, ref, items[i]),
                  onReject: () => _reject(context, ref, items[i]),
                ),
                if (i < items.length - 1) Divider(height: 20, color: context.cBorder),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _PendingPaymentRow extends StatelessWidget {
  final PlatformPendingPayment payment;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  const _PendingPaymentRow({
    required this.payment,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final periodLabel = p.period == 'annual' ? 'annuel' : 'mensuel';
    final providerLabel = p.provider == 'mtn' ? 'MTN' : p.provider == 'airtel' ? 'Airtel' : '—';
    return LayoutBuilder(builder: (_, c) {
      final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.schoolName,
            style: TextStyle(color: context.cInk, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(
            'Offre ${p.planCode.toUpperCase()} · $periodLabel · '
            '${groupThousands(p.amount.round())} ${p.currency} · $providerLabel',
            style: TextStyle(fontSize: 12, color: context.cMuted)),
        const SizedBox(height: 2),
        Text('Réf. ${p.reference ?? "—"}',
            style: TextStyle(fontSize: 11.5, color: context.cMuted, fontWeight: FontWeight.w600)),
      ]);
      final actions = Row(mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton.icon(
          onPressed: onReject,
          style: OutlinedButton.styleFrom(
            foregroundColor: ScolarisPalette.terracotta,
            side: BorderSide(color: ScolarisPalette.terracotta.withValues(alpha: .4)),
          ),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Rejeter'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Confirmer'),
        ),
      ]);
      if (c.maxWidth < 520) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          info,
          const SizedBox(height: 10),
          actions,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: info),
        const SizedBox(width: 12),
        actions,
      ]);
    });
  }
}
