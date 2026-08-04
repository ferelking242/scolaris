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

    // Scolarité/inscription : pas de facture à pointer (modèle « reçu par
    // encaissement », cf. recordTuitionPayment) — la cible est l'élève, pas
    // une SbInvoice.
    Future<void> payTuition({required bool registration}) async {
      final schoolId = school?.id;
      final year = school?.academicYear;
      if (schoolId == null || year == null) return;
      final acc = ref.read(tuitionAccountProvider(child.id)).valueOrNull;
      if (acc == null) return;
      final balance = registration ? acc.registrationOwed : acc.balance;
      if (balance <= 0.01) return;
      final ok = await showOnlineTuitionPaymentSheet(
        context,
        ref,
        OnlineTuitionTarget(
          studentId: child.id,
          schoolId: schoolId,
          academicYear: year,
          category: registration ? 'registration' : 'tuition',
          label: registration
              ? 'Inscription — ${child.fullName}'
              : 'Scolarité — ${child.fullName}',
          balance: balance,
          currency: acc.currency,
        ),
        suggestedAmount: registration
            ? acc.registrationOwed
            : (acc.owedNow > 0.01 ? acc.owedNow : null),
      );
      if (ok) {
        ref.invalidate(invoicesForStudentProvider(child.id));
        ref.invalidate(tuitionAccountProvider(child.id));
      }
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
          onPayOnline: online ? () => payTuition(registration: false) : null,
          onPayRegistrationOnline:
              online ? () => payTuition(registration: true) : null,
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
