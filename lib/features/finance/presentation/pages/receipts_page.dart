import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = Color(0xFF8B1A00);
const _green  = Color(0xFF2D6A4F);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);

class ReceiptsPage extends ConsumerStatefulWidget {
  const ReceiptsPage({super.key});
  @override
  ConsumerState<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends ConsumerState<ReceiptsPage> {
  String _statusFilter = 'Tous';
  String _search = '';
  /// Filtre classe. null = toutes.
  String? _classId;

  List<SbInvoice> _filtered(List<SbInvoice> all, Map<String, String?> classIdByStudent) {
    return all.where((inv) {
      final matchStatus = _statusFilter == 'Tous'
          ? true
          : _statusFilter == 'Payés'
              ? inv.isPaid
              : _statusFilter == 'En attente'
                  ? (inv.isPending && !inv.isLate)
                  : inv.isLate;
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          (inv.studentName?.toLowerCase().contains(q) ?? false) ||
          (inv.invoiceNumber?.toLowerCase().contains(q) ?? false) ||
          (inv.description?.toLowerCase().contains(q) ?? false);
      final matchClass = _classId == null || classIdByStudent[inv.studentId] == _classId;
      return matchStatus && matchSearch && matchClass;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);

    Future<void> refresh() async {
      ref.invalidate(invoicesProvider);
      ref.invalidate(studentsProvider);
      ref.invalidate(classesProvider);
      await Future.wait([
        ref.read(invoicesProvider.future),
        ref.read(studentsProvider.future),
        ref.read(classesProvider.future),
      ]);
    }

    return invoicesAsync.when(
      loading: () => PageScaffold(
        title: 'Reçus & Quittances',
        onRefresh: refresh,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Reçus & Quittances',
        onRefresh: refresh,
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (allInvoices) {
        // Filtre par classe : les factures n'ont pas de classId propre, on
        // joint via invoice.studentId → student.classId (en mémoire).
        final students = ref.watch(studentsProvider).valueOrNull ?? const [];
        final classes = ref.watch(classesProvider).valueOrNull ?? const [];
        final classIdByStudent = {for (final s in students) s.id: s.classId};
        final invoiceClassIds = allInvoices
            .map((i) => classIdByStudent[i.studentId])
            .whereType<String>()
            .toSet();
        final filterableClasses = classes
            .where((c) => invoiceClassIds.contains(c.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final invoices = _filtered(allInvoices, classIdByStudent);
        return PageScaffold(
          title: 'Reçus & Quittances',
          subtitle: '${allInvoices.length} documents au total',
          onRefresh: refresh,
          actions: [
            ActionButton(
                label: 'Imprimer tout',
                icon: Icons.print_outlined,
                onTap: () {}),
            const SizedBox(width: 8),
            ActionButton(
                label: 'Nouveau reçu',
                icon: Icons.add_rounded,
                primary: true,
                onTap: () {}),
          ],
          child: Column(children: [
            _FilterRow(
              current: _statusFilter,
              options: const ['Tous', 'Payés', 'En attente', 'En retard'],
              onChange: (v) => setState(() => _statusFilter = v),
            ),
            const SizedBox(height: 12),
            DataPanel(
              title: 'Factures',
              headerActions: [
                if (filterableClasses.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: context.cSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.cBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _classId,
                        isDense: true,
                        dropdownColor: context.cCard,
                        style: TextStyle(fontSize: 12, color: context.cInk),
                        hint: Text('Toutes les classes',
                            style: TextStyle(fontSize: 12, color: context.cMuted)),
                        items: [
                          DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Toutes les classes',
                                  style: TextStyle(fontSize: 12, color: context.cMuted))),
                          for (final c in filterableClasses)
                            DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setState(() => _classId = v),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                SearchInput(
                  hint: 'Rechercher…',
                  onChanged: (v) => setState(() => _search = v),
                ),
              ],
              child: invoices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('Aucun résultat.',
                              style: TextStyle(color: _muted))),
                    )
                  : DataTablePanel(
                      columns: const [
                        'N° Facture',
                        'Élève',
                        'Montant',
                        'Échéance',
                        'Statut',
                        ''
                      ],
                      flex: const [2, 3, 2, 2, 2, 1],
                      rows: [
                        for (final inv in invoices)
                          [
                            Text(
                                inv.invoiceNumber ??
                                    inv.id.substring(0, 8).toUpperCase(),
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                            Text(inv.studentName ?? '—',
                                style:
                                    const TextStyle(fontSize: 12, color: _ink)),
                            Text(
                                '${NumberFormat.compact(locale: "fr").format(inv.amount)} ${inv.currency}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: _ink,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                inv.dueDate != null
                                    ? DateFormat('dd/MM/yy').format(inv.dueDate!)
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 12, color: _muted)),
                            _statusPill(inv.isLate ? 'overdue' : inv.status),
                            InkWell(
                              onTap: () {},
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.print_outlined,
                                    size: 16, color: _muted),
                              ),
                            ),
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
        c = _green;
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

class _FilterRow extends StatelessWidget {
  final String current;
  final List<String> options;
  final ValueChanged<String> onChange;
  const _FilterRow({required this.current, required this.options, required this.onChange});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(o),
                  selected: current == o,
                  onSelected: (_) => onChange(o),
                  selectedColor: _terra.withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: current == o ? _terra : _muted,
                    fontWeight: current == o ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}
