import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class ParentPaymentsPage extends ConsumerWidget {
  const ParentPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(myInvoicesProvider);
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
        final due = invoices
            .where((i) => !i.isPaid)
            .fold<double>(0, (a, b) => a + b.amount);
        return PageScaffold(
          title: 'Paiements',
          subtitle: 'Scolarité, cantine et transport',
          actions: [
            if (due > 0)
              ActionButton(
                  label:
                      'Tout payer (${NumberFormat.compact(locale: "fr").format(due)})',
                  icon: Icons.credit_card_rounded,
                  primary: true,
                  onTap: () {}),
          ],
          child: invoices.isEmpty
              ? const _EmptyState()
              : DataPanel(
                  title: 'Factures récentes',
                  headerActions: const [SearchInput()],
                  child: DataTablePanel(
                    columns: const [
                      'Facture',
                      'Description',
                      'Échéance',
                      'Montant',
                      'Statut',
                      ''
                    ],
                    flex: const [2, 3, 2, 2, 2, 2],
                    rows: [
                      for (final inv in invoices)
                        [
                          Text(
                              inv.invoiceNumber ??
                                  inv.id.substring(0, 8).toUpperCase(),
                              style: const TextStyle(
                                  color: ink,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                          Text(inv.description ?? '—',
                              style:
                                  const TextStyle(fontSize: 12.5, color: ink)),
                          Text(
                              inv.dueDate != null
                                  ? DateFormat('dd/MM/yy').format(inv.dueDate!)
                                  : '—',
                              style:
                                  const TextStyle(fontSize: 12, color: muted)),
                          Text(
                              '${NumberFormat.compact(locale: "fr").format(inv.amount)} ${inv.currency}',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: ink,
                                  fontWeight: FontWeight.w700)),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: _statusPill(inv.status)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ActionButton(
                              label: inv.isPaid ? 'Reçu' : 'Payer',
                              onTap: () {},
                              primary: !inv.isPaid,
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  static Widget _statusPill(String s) {
    Color c;
    String label;
    switch (s) {
      case 'paid':
        c = const Color(0xFF16A34A);
        label = 'Payé';
        break;
      case 'overdue':
        c = const Color(0xFFDC2626);
        label = 'En retard';
        break;
      default:
        c = const Color(0xFFEA580C);
        label = 'En attente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
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
