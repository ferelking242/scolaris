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
/// - **Pas d'agrégateur branché** : le parent envoie l'argent lui-même (USSD,
///   hors app) vers le numéro marchand de l'école, puis saisit ici la
///   référence reçue par SMS. Le versement est enregistré en attente — le
///   solde ne bouge qu'après vérification par l'admin. Le jour où un
///   agrégateur est branché, seule la confirmation devient automatique.
/// [suggestedAmount] : pré-remplit le montant à payer quand il n'y a qu'une
/// seule facture (ex. le dû à ce jour d'un compte de scolarité). Le parent peut
/// le modifier — pour régler une tranche, tout le solde, ou un acompte.
Future<bool> showOnlinePaymentSheet(
  BuildContext context,
  WidgetRef ref,
  List<SbInvoice> invoices, {
  double? suggestedAmount,
}) async {
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
    builder: (_) =>
        _PaymentSheet(invoices: invoices, ref: ref, suggested: suggestedAmount),
  );
  return paid ?? false;
}

class _PaymentSheet extends StatefulWidget {
  final List<SbInvoice> invoices;
  final WidgetRef ref;
  final double? suggested;
  const _PaymentSheet(
      {required this.invoices, required this.ref, this.suggested});
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _reference = TextEditingController();
  // Montant éditable quand il n'y a qu'une facture (scolarité, un frais).
  late final TextEditingController _amount;
  String _operator = 'mtn';
  bool _processing = false;
  String? _error;

  static const _operators = [
    ('mtn', 'MTN MoMo', Color(0xFFFFCC00)),
    ('airtel', 'Airtel Money', Color(0xFFE40000)),
  ];

  bool get _single => widget.invoices.length == 1;

  @override
  void initState() {
    super.initState();
    // Défaut : le montant suggéré (dû à ce jour), sinon le solde restant.
    final def = _single
        ? (widget.suggested ?? widget.invoices.first.balance)
        : 0.0;
    _amount = TextEditingController(
        text: def <= 0 ? '' : def.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _reference.dispose();
    _amount.dispose();
    super.dispose();
  }

  // Total à régler : le montant saisi si une facture, sinon la somme des soldes.
  double get _total => _single
      ? (double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0)
      : widget.invoices.fold<double>(0, (a, b) => a + b.balance);

  Future<void> _pay() async {
    final reference = _reference.text.trim();
    if (reference.isEmpty) {
      setState(() => _error = 'Entrez la référence reçue par SMS après votre envoi.');
      return;
    }
    if (_single) {
      final v = _total;
      final bal = widget.invoices.first.balance;
      if (v <= 0) {
        setState(() => _error = 'Entrez un montant à payer.');
        return;
      }
      if (v > bal + 0.01) {
        setState(() => _error =
            'Dépasse le reste dû (${NumberFormat.decimalPattern("fr").format(bal)} ${widget.invoices.first.currency}).');
        return;
      }
    }
    setState(() {
      _processing = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      // `payment_method` doit rester une des valeurs autorisées par la
      // contrainte CHECK de `payments` (cash | mobile_money | bank_transfer |
      // cheque | other). Statut `pending` côté serveur (cf. record-online-
      // payment) — le solde ne bouge qu'après vérification par l'admin.
      const method = 'mobile_money';
      // Écriture SERVEUR (Edge Function) : les familles sont en lecture seule
      // sur `payments`. La fonction vérifie le lien famille↔élève puis écrit.
      if (_single) {
        final inv = widget.invoices.first;
        await SupabaseDbSource.recordOnlinePayment(
          invoiceId: inv.id,
          amount: _total, // partiel possible → cascade sur le compte
          method: method,
          reference: reference,
        );
      } else {
        for (final inv in widget.invoices) {
          await SupabaseDbSource.recordOnlinePayment(
            invoiceId: inv.id,
            amount: inv.balance, // le reste dû, pas le montant d'origine
            method: method,
            reference: reference,
          );
        }
      }
      widget.ref.invalidate(myInvoicesProvider);
      widget.ref.invalidate(invoicesProvider);
      widget.ref.invalidate(myChildrenInvoicesProvider);
      // Rafraîchit les comptes de scolarité concernés.
      for (final inv in widget.invoices) {
        final sid = inv.studentId;
        if (sid != null) {
          widget.ref.invalidate(tuitionAccountProvider(sid));
          widget.ref.invalidate(invoicesForStudentProvider(sid));
        }
      }
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
    final currency = invs.first.currency;
    final amount =
        '${NumberFormat.decimalPattern("fr").format(_total)} $currency';
    final label = _single
        ? (invs.first.description ?? 'Frais de scolarité')
        : '${invs.length} factures';
    final school = widget.ref.read(schoolProvider).valueOrNull;
    final merchantNumber =
        _operator == 'mtn' ? school?.mobileMoneyMtn : school?.mobileMoneyAirtel;
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
        // Bandeau : paiement manuel (pas d'agrégateur branché)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFC17F24).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
              merchantNumber != null
                  ? 'Envoyez ce montant via Mobile Money au $merchantNumber, '
                      'puis saisissez la référence reçue par SMS ci-dessous.'
                  : 'L\'école n\'a pas encore renseigné son numéro Mobile '
                      'Money — contactez-la pour connaître où envoyer le paiement.',
              style: const TextStyle(
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
        // Montant éditable (une seule facture) : régler une tranche, un
        // acompte, ou tout le solde. Le solde restant est rappelé en dessous.
        if (_single) ...[
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Montant à payer ($currency)',
              helperText:
                  'Reste dû : ${NumberFormat.decimalPattern("fr").format(invs.first.balance)} $currency',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            for (final op in _operators)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: op.$1 == 'mtn' ? 10 : 0),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
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
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reference,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Référence de transaction (reçue par SMS)',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
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
                : Text('J\'ai envoyé $amount',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
            'L\'école vérifiera votre versement avant de le valider sur la facture.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _muted)),
      ]),
    );
  }
}
