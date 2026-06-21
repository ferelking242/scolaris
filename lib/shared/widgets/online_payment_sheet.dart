import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/sources/remote/supabase_db_source.dart';
import '../../presentation/providers/db_providers.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);
const _ink = Color(0xFF1A0A00);
const _muted = Color(0xFF7A5C44);

/// Ouvre le paiement en ligne (Mobile Money) d'une facture.
///
/// - Réservé aux offres **Pro / Max** (sinon message d'information).
/// - **Simulation** tant que les agrégateurs ne sont pas branchés : aucun
///   encaissement réel n'a lieu côté opérateur ; on enregistre simplement le
///   paiement en base et la facture passe à « payé ». Le jour où un agrégateur
///   est branché, seule la partie « confirmation opérateur » change.
Future<bool> showOnlinePaymentSheet(
  BuildContext context,
  WidgetRef ref,
  List<SbInvoice> invoices,
) async {
  if (invoices.isEmpty) return false;
  final enabled = await ref.read(onlinePaymentEnabledProvider.future);
  if (!context.mounted) return false;

  if (!enabled) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Paiement en ligne indisponible'),
        content: const Text(
            'Le paiement en ligne (Mobile Money) est disponible avec les offres '
            'Pro et Max.\n\nAvec l\'offre actuelle, réglez votre scolarité '
            'directement auprès de l\'établissement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris')),
        ],
      ),
    );
    return false;
  }

  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PaymentSheet(invoices: invoices, ref: ref),
  );
  return paid ?? false;
}

class _PaymentSheet extends StatefulWidget {
  final List<SbInvoice> invoices;
  final WidgetRef ref;
  const _PaymentSheet({required this.invoices, required this.ref});
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _phone = TextEditingController();
  String _operator = 'mtn';
  bool _processing = false;
  String? _error;

  static const _operators = [
    ('mtn', 'MTN MoMo', Color(0xFFFFCC00)),
    ('airtel', 'Airtel Money', Color(0xFFE40000)),
  ];

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final phone = _phone.text.trim();
    if (phone.length < 6) {
      setState(() => _error = 'Entrez un numéro Mobile Money valide.');
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      // Simulation de la confirmation opérateur (remplacé plus tard par
      // l'appel réel à l'agrégateur).
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      for (final inv in widget.invoices) {
        await SupabaseDbSource.recordPayment(
          invoiceId: inv.id,
          studentId: inv.studentId ?? '',
          amount: inv.amount,
          method: _operator == 'mtn' ? 'mtn_momo' : 'airtel_money',
          reference: 'SIM-${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      widget.ref.invalidate(myInvoicesProvider);
      widget.ref.invalidate(invoicesProvider);
      if (mounted) navigator.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Échec : $e';
          _processing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invs = widget.invoices;
    final total = invs.fold<double>(0, (a, b) => a + b.amount);
    final currency = invs.first.currency;
    final amount =
        '${NumberFormat.decimalPattern("fr").format(total)} $currency';
    final label = invs.length == 1
        ? (invs.first.description ?? 'Frais de scolarité')
        : '${invs.length} factures';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE0D5C8),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        // Bandeau démo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFC17F24).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Démo — simulation (agrégateur non branché)',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A5A12),
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        Text('Payer $amount',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12.5, color: _muted)),
        const SizedBox(height: 18),
        Row(
          children: [
            for (final op in _operators)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: op.$1 == 'mtn' ? 10 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _operator = op.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _operator == op.$1
                            ? op.$3.withValues(alpha: .12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _operator == op.$1
                                ? op.$3
                                : const Color(0xFFDDD0C4),
                            width: _operator == op.$1 ? 2 : 1),
                      ),
                      child: Column(children: [
                        Icon(Icons.smartphone_rounded, color: op.$3, size: 22),
                        const SizedBox(height: 6),
                        Text(op.$2,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numéro Mobile Money',
            hintText: 'Ex : 06 000 00 00',
            prefixIcon: Icon(Icons.phone_iphone_rounded),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: _terra, fontSize: 12.5)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _processing ? null : _pay,
            style: FilledButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _processing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Payer $amount',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Vous recevrez une demande de confirmation sur votre téléphone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _muted)),
      ]),
    );
  }
}
