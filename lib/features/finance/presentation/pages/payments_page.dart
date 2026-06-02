import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class FinancePaymentsPage extends ConsumerWidget {
  const FinancePaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
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
        final collected =
            invoices.where((i) => i.isPaid).fold(0.0, (a, b) => a + b.amount);
        final pending =
            invoices.where((i) => i.isPending).fold(0.0, (a, b) => a + b.amount);
        final overdue =
            invoices.where((i) => i.isOverdue).fold(0.0, (a, b) => a + b.amount);
        final fmt = NumberFormat.compact(locale: 'fr');

        return PageScaffold(
          title: 'Paiements',
          subtitle: '${invoices.length} factures ce mois',
          actions: [
            ActionButton(
                label: 'Export CSV',
                icon: Icons.file_download_outlined,
                onTap: () {}),
            const SizedBox(width: 8),
            ActionButton(
                label: 'Enregistrer paiement',
                icon: Icons.add_rounded,
                primary: true,
                onTap: () {}),
          ],
          child: Column(children: [
            Row(children: [
              Expanded(
                child: _Kpi(
                    label: 'Encaissé',
                    value: fmt.format(collected),
                    color: const Color(0xFF16A34A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                    label: 'En attente',
                    value: fmt.format(pending),
                    color: const Color(0xFFEA580C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                    label: 'En retard',
                    value: fmt.format(overdue),
                    color: const Color(0xFFDC2626)),
              ),
            ]),
            const SizedBox(height: 12),
            DataPanel(
              title: 'Toutes les factures',
              headerActions: const [SearchInput(hint: 'Rechercher facture…')],
              child: invoices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('Aucune facture.',
                              style: TextStyle(color: muted))),
                    )
                  : DataTablePanel(
                      columns: const [
                        'Facture',
                        'Élève',
                        'Description',
                        'Échéance',
                        'Montant',
                        'Statut'
                      ],
                      flex: const [2, 3, 3, 2, 2, 2],
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
                            Row(children: [
                              Avatar(name: inv.studentName ?? '?', size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(inv.studentName ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: ink)),
                              ),
                            ]),
                            Text(inv.description ?? '—',
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontSize: 12, color: muted)),
                            Text(
                                inv.dueDate != null
                                    ? DateFormat('dd/MM/yy')
                                        .format(inv.dueDate!)
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
                          ],
                      ],
                    ),
            ),
          ]),
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
        border: Border.all(color: c.withValues(alpha: .3)),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}
