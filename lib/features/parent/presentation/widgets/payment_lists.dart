import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../shared/pdf/invoice_pdf.dart';
import '../../../../shared/widgets/page_scaffold.dart';

/// Rendu commun (cartes, pas de tableau dense) des « Autres frais » et de
/// l'historique des versements — partagé entre la vue globale
/// (`ParentPaymentsPage`, tous les enfants) et la vue par enfant
/// (`ChildPaymentsPage`, ouverte depuis sa fiche). Les deux pages restent
/// distinctes (décision de navigation du projet : pas de sélecteur d'enfant
/// global, cf. `child_detail_page.dart`) mais partagent ce rendu pour ne pas
/// diverger — avant, seule la version par enfant avait l'historique.
String _methodLabel(String? method) => switch (method?.toLowerCase()) {
      'cash' => 'Espèces',
      'mobile_money' || 'mtn' || 'airtel' => 'Mobile Money',
      'bank_transfer' || 'transfer' => 'Virement bancaire',
      'card' => 'Carte bancaire',
      _ => method ?? '—',
    };

class OtherFeesPanel extends StatelessWidget {
  final List<SbInvoice> invoices;
  final dynamic school;

  /// Affiche le nom de l'élève sur chaque ligne — utile seulement quand
  /// plusieurs enfants sont mélangés dans la même liste (vue globale).
  final bool showStudentName;
  final bool onlineEnabled;
  final void Function(SbInvoice invoice) onPay;

  const OtherFeesPanel({
    super.key,
    required this.invoices,
    required this.school,
    required this.onlineEnabled,
    required this.onPay,
    this.showStudentName = false,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const SizedBox.shrink();
    return DataPanel(
      title: 'Autres frais',
      child: Column(children: [
        for (var i = 0; i < invoices.length; i++) ...[
          _FeeCard(
            invoice: invoices[i],
            school: school,
            showStudentName: showStudentName,
            onlineEnabled: onlineEnabled,
            onPay: () => onPay(invoices[i]),
          ),
          if (i < invoices.length - 1) const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

class _FeeCard extends StatelessWidget {
  final SbInvoice invoice;
  final dynamic school;
  final bool showStudentName;
  final bool onlineEnabled;
  final VoidCallback onPay;

  const _FeeCard({
    required this.invoice,
    required this.school,
    required this.showStudentName,
    required this.onlineEnabled,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showStudentName && inv.studentName != null) ...[
                Text(inv.studentName!,
                    style: TextStyle(
                        fontSize: 11,
                        color: context.cMuted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
              ],
              Text(inv.description ?? inv.invoiceNumber ?? 'Facture',
                  style: TextStyle(
                      fontSize: 13.5,
                      color: context.cInk,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          inv.isPaid
              ? StatusPill.success('Payé')
              : (inv.isLate
                  ? StatusPill.danger('En retard')
                  : StatusPill.warning('En attente')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.event_outlined, size: 13, color: context.cMuted),
          const SizedBox(width: 4),
          Text(
              inv.dueDate != null
                  ? 'Échéance ${DateFormat('dd/MM/yy').format(inv.dueDate!)}'
                  : 'Sans échéance',
              style: TextStyle(fontSize: 11.5, color: context.cMuted)),
          const Spacer(),
          Text('${NumberFormat.decimalPattern("fr").format(inv.amount)} ${inv.currency}',
              style: TextStyle(
                  fontSize: 14,
                  color: context.cInk,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => printInvoice(school: school, invoice: inv),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(inv.isPaid ? 'Reçu' : 'Facture',
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ),
          if (!inv.isPaid && onlineEnabled) ...[
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.credit_card_rounded, size: 16),
                label: const Text('Payer', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class PaymentHistoryPanel extends StatelessWidget {
  final List<SbPayment> payments;
  final dynamic school;
  final String studentName;
  final String currency;

  const PaymentHistoryPanel({
    super.key,
    required this.payments,
    required this.school,
    required this.studentName,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const SizedBox.shrink();
    return DataPanel(
      title: 'Historique des versements',
      child: Column(children: [
        for (var i = 0; i < payments.length; i++) ...[
          _PaymentRow(
            payment: payments[i],
            school: school,
            studentName: studentName,
            currency: currency,
          ),
          if (i < payments.length - 1)
            Divider(height: 18, color: context.cBorder.withValues(alpha: .5)),
        ],
      ]),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final SbPayment payment;
  final dynamic school;
  final String studentName;
  final String currency;

  const _PaymentRow({
    required this.payment,
    required this.school,
    required this.studentName,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(Icons.check_rounded, size: 17, color: Color(0xFF16A34A)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              p.paymentDate != null
                  ? DateFormat('dd/MM/yyyy').format(p.paymentDate!)
                  : '—',
              style: TextStyle(
                  fontSize: 13, color: context.cInk, fontWeight: FontWeight.w700)),
          Text(_methodLabel(p.paymentMethod),
              style: TextStyle(fontSize: 11.5, color: context.cMuted)),
        ]),
      ),
      Text('${NumberFormat.decimalPattern("fr").format(p.amount)} $currency',
          style: TextStyle(
              fontSize: 13, color: context.cInk, fontWeight: FontWeight.w800)),
      const SizedBox(width: 6),
      IconButton(
        icon: const Icon(Icons.download_rounded, size: 18),
        color: context.cMuted,
        tooltip: 'Télécharger le reçu',
        onPressed: () => printPaymentReceipt(
          school: school,
          payment: p,
          studentName: studentName,
          description: 'Scolarité',
          currency: currency,
        ),
      ),
    ]);
  }
}
