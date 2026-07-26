import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _orange = Color(0xFFEA580C);

String _money(num v, String currency) =>
    '${NumberFormat.decimalPattern('fr').format(v)} $currency';

/// « couvert jusqu'à … » : le dernier mois entièrement couvert par [total].
String coveredUntilLabel(SbTuitionAccount acc, double total) {
  if (acc.monthly <= 0 || acc.periods.isEmpty) return '—';
  final full = (total / acc.monthly).floor();
  if (full <= 0) return 'aucun mois couvert';
  final idx = (full - 1).clamp(0, acc.periods.length - 1);
  final label = acc.periods[idx].label.replaceFirst('Scolarité — ', '');
  final partial = (total / acc.monthly) - full > 0.02 && full < acc.periodsCount;
  return partial ? '$label (+ acompte)' : label;
}

/// Carte « Compte scolarité » d'un élève : payé / dû / à jour, et — si
/// [canCollect] — le bouton « Encaisser un versement ».
class TuitionAccountCard extends ConsumerWidget {
  final String studentId;
  final String studentName;

  /// Vue admin : affiche « Encaisser un versement » (caisse).
  final bool canCollect;

  /// Vue famille : titre du panneau (ex. « Scolarité — Awa »).
  final String title;

  /// Vue famille : si fourni et qu'il reste un solde, affiche « Payer en ligne ».
  /// (Le règlement à la caisse passe par [canCollect], côté admin.)
  final VoidCallback? onPayOnline;

  /// Vue famille : si fourni, affiche « Télécharger la facture/le reçu » — la
  /// facture annuelle de scolarité (catégorie `tuition`), seule trace
  /// imprimable d'un versement fait à la caisse ou en ligne.
  final VoidCallback? onDownload;

  const TuitionAccountCard({
    super.key,
    required this.studentId,
    required this.studentName,
    this.canCollect = false,
    this.title = 'Compte scolarité',
    this.onPayOnline,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accAsync = ref.watch(tuitionAccountProvider(studentId));
    return DataPanel(
      title: title,
      child: accAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(
              child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => Text('Compte indisponible.',
            style: TextStyle(fontSize: 12, color: context.cMuted)),
        data: (acc) {
          if (acc == null) {
            return Text(
              'Pas de grille de frais pour la classe de cet élève. '
              'Définissez-la dans Facturation → Frais de scolarité.',
              style: TextStyle(fontSize: 12.5, color: context.cMuted),
            );
          }
          final ratio =
              acc.annual > 0 ? (acc.paid / acc.annual).clamp(0.0, 1.0) : 0.0;
          final upToDate = acc.isUpToDate;
          final statusColor = upToDate ? _green : _terra;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payé / total + barre.
                Row(children: [
                  Expanded(
                    child: Text('${_money(acc.paid, acc.currency)} '
                        'sur ${_money(acc.annual, acc.currency)}',
                        style: TextStyle(
                            fontSize: 14,
                            color: context.cInk,
                            fontWeight: FontWeight.w800)),
                  ),
                  _StatusChip(
                    label: upToDate
                        ? 'À jour'
                        : 'Doit ${_money(acc.owedNow, acc.currency)}',
                    color: statusColor,
                  ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: statusColor.withValues(alpha: .12),
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
                const SizedBox(height: 10),
                _kv('Dû à ce jour', _money(acc.dueToDate, acc.currency),
                    context),
                _kv('Reste sur l\'année', _money(acc.balance, acc.currency),
                    context),
                _kv('Couvert jusqu\'à', coveredUntilLabel(acc, acc.paid),
                    context),
                if (acc.credit > 0.01)
                  _kv('Payé d\'avance', _money(acc.credit, acc.currency),
                      context,
                      valueColor: _green),
                if (onDownload != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onDownload,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.download_rounded, size: 14, color: context.cMuted),
                      const SizedBox(width: 4),
                      Text(upToDate ? 'Télécharger le reçu' : 'Télécharger la facture',
                          style: TextStyle(
                              fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
                if (canCollect) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ActionButton(
                      label: 'Encaisser un versement',
                      icon: Icons.payments_rounded,
                      primary: true,
                      onTap: () => showTuitionPaymentDialog(
                          context, ref, studentId, studentName, acc),
                    ),
                  ),
                ] else if (onPayOnline != null && acc.balance > 0.01) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ActionButton(
                      label: 'Payer la scolarité en ligne',
                      icon: Icons.smartphone_rounded,
                      primary: true,
                      onTap: onPayOnline!,
                    ),
                  ),
                ],
              ]);
        },
      ),
    );
  }

  static Widget _kv(String k, String v, BuildContext context,
          {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 140,
              child: Text(k,
                  style: TextStyle(fontSize: 12, color: context.cMuted))),
          Expanded(
            child: Text(v,
                style: TextStyle(
                    fontSize: 12.5,
                    color: valueColor ?? context.cInk,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w800)),
      );
}

/// Dialogue « Encaisser un versement » : montant + aperçu d'affectation en
/// direct, puis `recordTuitionPayment`.
Future<void> showTuitionPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  String studentId,
  String studentName,
  SbTuitionAccount acc,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _TuitionPaymentDialog(
      studentId: studentId,
      studentName: studentName,
      acc: acc,
    ),
  );
}

class _TuitionPaymentDialog extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final SbTuitionAccount acc;
  const _TuitionPaymentDialog({
    required this.studentId,
    required this.studentName,
    required this.acc,
  });
  @override
  ConsumerState<_TuitionPaymentDialog> createState() =>
      _TuitionPaymentDialogState();
}

class _TuitionPaymentDialogState extends ConsumerState<_TuitionPaymentDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: _defaultAmount().toStringAsFixed(0));
  bool _loading = false;
  String? _error;

  // Défaut malin : ce qu'il doit aujourd'hui (mise à jour), sinon une mensualité.
  double _defaultAmount() {
    final a = widget.acc;
    if (a.owedNow > 0.01) return a.owedNow;
    return a.monthly;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _entered =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _submit() async {
    final v = _entered;
    final a = widget.acc;
    if (v <= 0) {
      setState(() => _error = 'Montant invalide.');
      return;
    }
    if (v > a.balance + 0.01) {
      setState(() => _error =
          'Dépasse le reste dû sur l\'année (${_money(a.balance, a.currency)}).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final schoolId = ref.read(currentSchoolIdProvider);
    final year = ref.read(schoolProvider).valueOrNull?.academicYear;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (schoolId == null || year == null) {
        throw Exception('École ou année scolaire introuvable.');
      }
      await SupabaseDbSource.recordTuitionPayment(
        studentId: widget.studentId,
        schoolId: schoolId,
        academicYear: year,
        amount: v,
      );
      ref.invalidate(tuitionAccountProvider(widget.studentId));
      ref.invalidate(invoicesProvider);
      ref.invalidate(invoicesForStudentProvider(widget.studentId));
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Versement de ${_money(v, a.currency)} encaissé.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _green,
      ));
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.acc;
    final newPaid = a.paid + _entered;
    final newOwed = (a.dueToDate - newPaid).clamp(0, double.infinity).toDouble();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Encaisser un versement',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.studentName,
                style: TextStyle(
                    fontSize: 13,
                    color: context.cInk,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
                'Payé ${_money(a.paid, a.currency)} · dû aujourd\'hui ${_money(a.owedNow, a.currency)}',
                style: TextStyle(fontSize: 12, color: context.cMuted)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Montant reçu (${a.currency})',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          // Aperçu d'affectation en direct.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.cSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Après ce versement',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.cMuted,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _line('Total payé', _money(newPaid, a.currency), context),
              _line(
                  'Reste dû aujourd\'hui',
                  _money(newOwed, a.currency),
                  context,
                  color: newOwed > 0.01 ? _orange : _green),
              _line('Couvert jusqu\'à', coveredUntilLabel(a, newPaid), context),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!,
                  style: const TextStyle(color: _terra, fontSize: 12.5)),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _green),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Encaisser'),
        ),
      ],
    );
  }

  Widget _line(String k, String v, BuildContext context, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 12, color: context.cMuted)),
          Text(v,
              style: TextStyle(
                  fontSize: 12.5,
                  color: color ?? context.cInk,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}
