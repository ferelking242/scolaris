import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../admin/presentation/widgets/tuition_account.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/pdf/invoice_pdf.dart';
import '../../../../shared/widgets/online_payment_sheet.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../widgets/payment_lists.dart';

/// La scolarité d'UN enfant, ouverte depuis sa fiche : le compte (solde qui
/// court + paiement en ligne) et, séparément, ses autres frais.
class ChildPaymentsPage extends ConsumerWidget {
  final SbStudent child;
  const ChildPaymentsPage({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesForStudentProvider(child.id));
    final paymentsAsync = ref.watch(paymentsForStudentProvider(child.id));
    final school = ref.watch(schoolProvider).valueOrNull;
    final online = ref.watch(onlinePaymentEnabledProvider).valueOrNull ?? false;

    final invoices = invoicesAsync.valueOrNull ?? const <SbInvoice>[];
    final payments = paymentsAsync.valueOrNull ?? const <SbPayment>[];
    final others = invoices.where((i) => !i.isTuition).toList();
    final tuitionInvoice = invoices.where((i) => i.isTuition).firstOrNull;
    final currency = tuitionInvoice?.currency ?? 'FCFA';

    // Toutes les factures de scolarité impayées (souvent plusieurs mois en
    // retard) — pas seulement la première, sinon le parent ne peut régler
    // qu'un mois à la fois.
    final unpaidTuition =
        invoices.where((i) => i.isTuition && !i.isPaid).toList();

    Future<void> payTuition() async {
      if (unpaidTuition.isEmpty) return;
      final owed =
          ref.read(tuitionAccountProvider(child.id)).valueOrNull?.owedNow;
      final ok = await showOnlinePaymentSheet(context, ref, unpaidTuition,
          suggestedAmount: (owed != null && owed > 0.01) ? owed : null);
      if (ok) ref.invalidate(invoicesForStudentProvider(child.id));
    }

    Future<void> payOther(SbInvoice inv) async {
      final ok = await showOnlinePaymentSheet(context, ref, [inv]);
      if (ok) ref.invalidate(invoicesForStudentProvider(child.id));
    }

    return PageScaffold(
      title: 'Scolarité — ${child.fullName}',
      subtitle: child.classe?.isNotEmpty == true ? child.classe : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Le compte de scolarité ────────────────────────────────────────
        TuitionAccountCard(
          studentId: child.id,
          studentName: child.fullName,
          onPayOnline: (online && unpaidTuition.isNotEmpty) ? payTuition : null,
          onDownload: tuitionInvoice == null
              ? null
              : () => printInvoice(school: school, invoice: tuitionInvoice),
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 14),
          OtherFeesPanel(
            invoices: others,
            school: school,
            onlineEnabled: online,
            onPay: payOther,
          ),
        ],
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 14),
          PaymentHistoryPanel(
            payments: payments,
            school: school,
            studentName: child.fullName,
            currency: currency,
          ),
        ],
      ]),
    );
  }
}
