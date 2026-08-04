import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _gold = Color(0xFFC17F24);
const _moisAbbr = [
  'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
  'juil', 'août', 'sept', 'oct', 'nov', 'déc'
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_moisAbbr[d.month - 1]} ${d.year}';
}

/// Justifier une absence ou un retard : l'action "le mot des parents est
/// arrivé", jusqu'ici sans aucun écran pour l'accomplir — `justified`/`reason`
/// existaient déjà en base, affichés côté élève/parent ("à justifier"), mais
/// rien dans l'app ne les écrivait jamais. Réservé à `presences.modifier`
/// (même droit que la correction du pointage, cf. RLS `absences_update`).
class AttendanceJustifyPage extends ConsumerWidget {
  const AttendanceJustifyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingJustificationsProvider);
    final canModifier = ref.watch(canProvider('presences.modifier'));

    return PageScaffold(
      title: 'Justifier des absences',
      onRefresh: () async {
        ref.invalidate(pendingJustificationsProvider);
        await ref.read(pendingJustificationsProvider.future);
      },
      subtitle: canModifier
          ? 'Absences et retards non justifiés'
          : 'Consultation seule — la correction ne vous est pas confiée',
      child: pendingAsync.when(
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator())),
        error: (e, _) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)))),
        data: (pending) {
          if (pending.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_rounded,
              title: 'Rien à justifier',
              description:
                  'Toutes les absences et retards enregistrés sont déjà justifiés.',
            );
          }
          return Column(children: [
            for (final a in pending) ...[
              _PendingCard(
                absence: a,
                canModifier: canModifier,
                onJustify: () => _openJustifyDialog(context, ref, a),
              ),
              const SizedBox(height: 8),
            ],
          ]);
        },
      ),
    );
  }

  Future<void> _openJustifyDialog(
      BuildContext context, WidgetRef ref, SbAbsence a) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Justifier — ${a.status == 'late' ? 'retard' : 'absence'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fmtDate(a.absenceDate), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif (optionnel)',
                border: OutlineInputBorder(),
                hintText: 'Ex : certificat médical, rendez-vous administratif…',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Marquer justifiée'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseDbSource.justifyAbsence(a.id,
          justified: true,
          reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
      ref.invalidate(pendingJustificationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Absence justifiée.'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _PendingCard extends StatelessWidget {
  final SbAbsence absence;
  final bool canModifier;
  final VoidCallback onJustify;
  const _PendingCard({
    required this.absence,
    required this.canModifier,
    required this.onJustify,
  });

  @override
  Widget build(BuildContext context) {
    final isLate = absence.status == 'late';
    final color = isLate ? _gold : _terra;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isLate ? Icons.access_time_rounded : Icons.cancel_rounded,
              color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isLate ? 'Retard' : 'Absence',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_fmtDate(absence.absenceDate),
                style: TextStyle(color: context.cInk, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (canModifier)
          FilledButton(
            onPressed: onJustify,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Justifier', style: TextStyle(fontSize: 12.5)),
          )
        else
          StatusPill.warning('Non justifiée'),
      ]),
    );
  }
}
