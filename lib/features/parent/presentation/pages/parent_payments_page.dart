import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../features/admin/presentation/widgets/tuition_account.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/pdf/invoice_pdf.dart';
import '../../../../shared/widgets/online_payment_sheet.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../widgets/payment_lists.dart';

class ParentPaymentsPage extends ConsumerWidget {
  const ParentPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les factures de TOUS ses enfants. (Avant : `myInvoicesProvider`, qui
    // cherchait les factures d'un élève ayant l'id du parent → toujours vide.)
    final invoicesAsync = ref.watch(myChildrenInvoicesProvider);
    return invoicesAsync.when(
      loading: () => const PageScaffold(
        title: 'Paiements',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Paiements',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (invoices) {
        final school = ref.watch(schoolProvider).valueOrNull;
        final children = ref.watch(myChildrenProvider).valueOrNull ?? const [];
        final online =
            ref.watch(onlinePaymentEnabledProvider).valueOrNull ?? false;

        // La scolarité est désormais un COMPTE (carte par enfant, ci-dessous) ;
        // le tableau ne garde que les autres frais (inscription, etc.).
        final others = invoices.where((i) => !i.isTuition).toList();
        final due = others
            .where((i) => !i.isPaid)
            .fold<double>(0, (a, b) => a + b.balance);

        // Les factures-compte de scolarité impayées d'un enfant (souvent
        // plusieurs mois en retard) — pas seulement la première, sinon le
        // parent ne peut régler qu'un mois à la fois.
        List<SbInvoice> tuitionInvoicesOf(String childId) => invoices
            .where((i) => i.isTuition && i.studentId == childId && !i.isPaid)
            .toList();

        // La facture annuelle de scolarité d'un enfant (une seule par élève),
        // seule trace imprimable d'un versement cash ou en ligne.
        SbInvoice? tuitionInvoiceOf(String childId) => invoices
            .where((i) => i.isTuition && i.studentId == childId)
            .firstOrNull;

        Future<void> payTuition(List<SbInvoice> invs) async {
          if (invs.isEmpty) return;
          // Pré-remplit le dû à ce jour (compte déjà chargé par la carte).
          final owed = ref
              .read(tuitionAccountProvider(invs.first.studentId ?? ''))
              .valueOrNull
              ?.owedNow;
          final ok = await showOnlinePaymentSheet(context, ref, invs,
              suggestedAmount: (owed != null && owed > 0.01) ? owed : null);
          if (ok) ref.invalidate(myChildrenInvoicesProvider);
        }

        Future<void> payOther(SbInvoice inv) async {
          final ok = await showOnlinePaymentSheet(context, ref, [inv]);
          if (ok) ref.invalidate(myChildrenInvoicesProvider);
        }

        return PageScaffold(
          title: 'Paiements',
          subtitle: 'Scolarité, cantine et transport',
          actions: [
            if (due > 0)
              ActionButton(
                  label:
                      'Payer les autres frais (${NumberFormat.compact(locale: "fr").format(due)})',
                  icon: Icons.credit_card_rounded,
                  primary: true,
                  onTap: () => showOnlinePaymentSheet(context, ref,
                      others.where((i) => !i.isPaid).toList())),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Compte de scolarité + historique, un bloc par enfant ────
              for (final c in children) ...[
                TuitionAccountCard(
                  studentId: c.id,
                  studentName: c.fullName,
                  title: children.length > 1
                      ? 'Scolarité — ${c.fullName}'
                      : 'Compte scolarité',
                  onPayOnline: online
                      ? () => payTuition(tuitionInvoicesOf(c.id))
                      : null,
                  onDownload: tuitionInvoiceOf(c.id) == null
                      ? null
                      : () => printInvoice(
                          school: school, invoice: tuitionInvoiceOf(c.id)!),
                ),
                const SizedBox(height: 8),
                _ChildPaymentHistory(
                  childId: c.id,
                  childName: c.fullName,
                  school: school,
                  currency: tuitionInvoiceOf(c.id)?.currency ?? 'FCFA',
                ),
                const SizedBox(height: 12),
              ],

              // ── Autres frais ────────────────────────────────────────────
              if (others.isEmpty && children.isEmpty)
                const _EmptyState()
              else
                OtherFeesPanel(
                  invoices: others,
                  school: school,
                  showStudentName: children.length > 1,
                  onlineEnabled: online,
                  onPay: payOther,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Historique des versements d'UN enfant — chargé séparément (provider par
/// enfant) pour ne pas bloquer l'affichage du compte le temps qu'il arrive.
class _ChildPaymentHistory extends ConsumerWidget {
  final String childId;
  final String childName;
  final dynamic school;
  final String currency;
  const _ChildPaymentHistory({
    required this.childId,
    required this.childName,
    required this.school,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsForStudentProvider(childId));
    final payments = paymentsAsync.valueOrNull ?? const <SbPayment>[];
    if (payments.isEmpty) return const SizedBox.shrink();
    return PaymentHistoryPanel(
      payments: payments,
      school: school,
      studentName: childName,
      currency: currency,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: muted),
              SizedBox(height: 12),
              Text('Aucune facture',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
              SizedBox(height: 4),
              Text('Vos factures apparaîtront ici.',
                  style: TextStyle(fontSize: 13, color: muted)),
            ],
          ),
        ),
      );
}
