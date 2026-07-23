import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../admin/presentation/widgets/tuition_account.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/pdf/invoice_pdf.dart';
import '../../../../shared/widgets/online_payment_sheet.dart';
import '../../../../shared/widgets/page_scaffold.dart';

/// La scolarité d'UN enfant, ouverte depuis sa fiche : le compte (solde qui
/// court + paiement en ligne) et, séparément, ses autres frais.
class ChildPaymentsPage extends ConsumerWidget {
  final SbStudent child;
  const ChildPaymentsPage({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesForStudentProvider(child.id));
    final school = ref.watch(schoolProvider).valueOrNull;
    final online = ref.watch(onlinePaymentEnabledProvider).valueOrNull ?? false;

    final invoices = invoicesAsync.valueOrNull ?? const <SbInvoice>[];
    final others = invoices.where((i) => !i.isTuition).toList();

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

    return PageScaffold(
      title: 'Scolarité — ${child.fullName}',
      subtitle: child.classe?.isNotEmpty == true ? child.classe : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Le compte de scolarité ────────────────────────────────────────
        TuitionAccountCard(
          studentId: child.id,
          studentName: child.fullName,
          onPayOnline: (online && unpaidTuition.isNotEmpty) ? payTuition : null,
        ),

        // ── Autres frais (inscription, etc.) ──────────────────────────────
        if (others.isNotEmpty) ...[
          const SizedBox(height: 14),
          DataPanel(
            title: 'Autres frais',
            child: DataTablePanel(
              columns: const ['Facture', 'Description', 'Échéance', 'Montant', 'Statut', ''],
              flex: const [2, 3, 2, 2, 2, 2],
              rows: [
                for (final inv in others)
                  [
                    Text(inv.invoiceNumber ?? inv.id.substring(0, 8).toUpperCase(),
                        style: TextStyle(
                            color: context.cInk,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                    Text(inv.description ?? '—',
                        style: TextStyle(fontSize: 12.5, color: context.cInk)),
                    Text(
                        inv.dueDate != null
                            ? DateFormat('dd/MM/yy').format(inv.dueDate!)
                            : '—',
                        style: TextStyle(fontSize: 12, color: context.cMuted)),
                    Text(
                        '${NumberFormat.compact(locale: "fr").format(inv.amount)} ${inv.currency}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: context.cInk,
                            fontWeight: FontWeight.w700)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: inv.isPaid
                          ? StatusPill.success('Payé')
                          : (inv.isLate
                              ? StatusPill.danger('En retard')
                              : StatusPill.warning('En attente')),
                    ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        color: context.cMuted,
                        tooltip: inv.isPaid
                            ? 'Télécharger le reçu'
                            : 'Télécharger la facture',
                        onPressed: () =>
                            printInvoice(school: school, invoice: inv),
                      ),
                      if (!inv.isPaid && online) ...[
                        const SizedBox(width: 4),
                        ActionButton(
                          label: 'Payer',
                          primary: true,
                          onTap: () async {
                            final ok = await showOnlinePaymentSheet(
                                context, ref, [inv]);
                            if (ok) {
                              ref.invalidate(
                                  invoicesForStudentProvider(child.id));
                            }
                          },
                        ),
                      ],
                    ]),
                  ],
              ],
            ),
          ),
        ],
      ]),
    );
  }
}
