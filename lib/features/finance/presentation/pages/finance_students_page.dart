import 'package:flutter/material.dart';

import '../../../../shared/data/mock_data.dart';
import '../../../../shared/services/print_service.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = Color(0xFF8B1A00);
const _orange = Color(0xFFD4540A);
const _gold   = Color(0xFFC17F24);
const _green  = Color(0xFF2D6A4F);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);
const _borderC = Color(0xFFDDCCBB);

class FinanceStudentsPage extends StatefulWidget {
  const FinanceStudentsPage({super.key});

  @override
  State<FinanceStudentsPage> createState() => _FinanceStudentsPageState();
}

class _FinanceStudentsPageState extends State<FinanceStudentsPage> {
  String _classFilter = 'Toutes';
  String _payFilter   = 'Tous';
  String _search      = '';

  List<String> get _classes =>
      ['Toutes', ...MockData.students.map((s) => s.classGroup).toSet().toList()..sort()];

  List<MockStudent> get _filtered {
    return MockData.students.where((s) {
      final matchClass = _classFilter == 'Toutes' || s.classGroup == _classFilter;
      final matchSearch = _search.isEmpty ||
          s.name.toLowerCase().contains(_search.toLowerCase()) ||
          s.id.toLowerCase().contains(_search.toLowerCase()) ||
          s.guardian.toLowerCase().contains(_search.toLowerCase());

      final studentInvoices = MockData.invoices
          .where((i) => i.student == s.name)
          .toList();
      final hasOverdue = studentInvoices.any((i) => i.status == InvoiceStatus.overdue);
      final hasPending = studentInvoices.any((i) => i.status == InvoiceStatus.pending);
      final allPaid = studentInvoices.isNotEmpty &&
          studentInvoices.every((i) => i.status == InvoiceStatus.paid);

      final matchPay = _payFilter == 'Tous'
          ? true
          : _payFilter == 'Payé'
              ? allPaid
              : _payFilter == 'En attente'
                  ? hasPending
                  : hasOverdue;

      return matchClass && matchSearch && matchPay;
    }).toList();
  }

  String _payStatus(MockStudent s) {
    final inv = MockData.invoices.where((i) => i.student == s.name).toList();
    if (inv.isEmpty) return 'Aucune facture';
    if (inv.any((i) => i.status == InvoiceStatus.overdue)) return 'En retard';
    if (inv.any((i) => i.status == InvoiceStatus.pending)) return 'En attente';
    return 'Payé';
  }

  void _printList() {
    PrintService.printStudentList(
      students: _filtered,
      schoolName: 'École Scolaris',
      classFilter: _classFilter == 'Toutes' ? null : _classFilter,
      printedBy: 'Jean Tshibangu',
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return PageScaffold(
      title: 'Liste des Élèves',
      subtitle: '${MockData.students.length} élèves enregistrés',
      actions: [
        ActionButton(
          label: 'Imprimer la liste',
          icon: Icons.print_rounded,
          primary: true,
          onTap: _printList,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Summary stats ───────────────────────────────────────────────
          _SummaryRow(students: MockData.students),
          const SizedBox(height: 16),

          // ── Table ───────────────────────────────────────────────────────
          DataPanel(
            title: 'Élèves & Statuts de paiement',
            headerActions: [
              SearchInput(
                hint: 'Nom, ID, tuteur…',
                onChanged: (v) => setState(() => _search = v),
              ),
            ],
            child: Column(
              children: [
                // Filters
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    // Class filter
                    _DropFilter(
                      label: 'Classe',
                      value: _classFilter,
                      items: _classes,
                      onChange: (v) => setState(() => _classFilter = v),
                    ),
                    const SizedBox(width: 10),
                    // Pay filter
                    _DropFilter(
                      label: 'Paiement',
                      value: _payFilter,
                      items: const ['Tous', 'Payé', 'En attente', 'En retard'],
                      onChange: (v) => setState(() => _payFilter = v),
                    ),
                    const Spacer(),
                    Text('${filtered.length} résultat(s)',
                        style: const TextStyle(fontSize: 12, color: _muted,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Aucun élève trouvé',
                    description: 'Modifiez les filtres ou la recherche.',
                  )
                else
                  _StudentTable(
                    students: filtered,
                    payStatusOf: _payStatus,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Row ───────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final List<MockStudent> students;
  const _SummaryRow({required this.students});

  @override
  Widget build(BuildContext context) {
    int paid = 0, pending = 0, overdue = 0, none = 0;
    for (final s in students) {
      final inv = MockData.invoices.where((i) => i.student == s.name).toList();
      if (inv.isEmpty) {
        none++;
      } else if (inv.any((i) => i.status == InvoiceStatus.overdue)) {
        overdue++;
      } else if (inv.any((i) => i.status == InvoiceStatus.pending)) {
        pending++;
      } else {
        paid++;
      }
    }

    return Row(children: [
      Expanded(child: _SumCard(icon: Icons.groups_rounded,
          label: 'Total élèves', value: '${students.length}', color: _muted)),
      const SizedBox(width: 10),
      Expanded(child: _SumCard(icon: Icons.check_circle_rounded,
          label: 'À jour', value: '$paid', color: _green)),
      const SizedBox(width: 10),
      Expanded(child: _SumCard(icon: Icons.schedule_rounded,
          label: 'En attente', value: '$pending', color: _gold)),
      const SizedBox(width: 10),
      Expanded(child: _SumCard(icon: Icons.warning_amber_rounded,
          label: 'En retard', value: '$overdue', color: _terra)),
    ]);
  }
}

class _SumCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SumCard({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderC),
        boxShadow: const [BoxShadow(
            color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: _muted,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(fontSize: 20, color: color,
                  fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }
}

// ── Drop Filter ───────────────────────────────────────────────────────────
class _DropFilter extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChange;

  const _DropFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderC),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.expand_more_rounded, size: 14, color: _muted),
        style: const TextStyle(fontSize: 12, color: _ink,
            fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: (v) { if (v != null) onChange(v); },
        hint: Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
      ),
    );
  }
}

// ── Student Table ─────────────────────────────────────────────────────────
class _StudentTable extends StatelessWidget {
  final List<MockStudent> students;
  final String Function(MockStudent) payStatusOf;

  const _StudentTable({
    required this.students,
    required this.payStatusOf,
  });

  @override
  Widget build(BuildContext context) {
    return DataTablePanel(
      columns: const ['ID', 'Élève', 'Classe', 'Tuteur', 'Moy.', 'Présence', 'Paiement'],
      flex: const [2, 3, 2, 3, 1, 2, 2],
      rows: [
        for (final s in students) [
          Text(s.id,
              style: const TextStyle(fontSize: 10.5, color: _muted,
                  fontFamily: 'monospace')),
          Row(children: [
            Avatar(name: s.name, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(s.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5,
                      fontWeight: FontWeight.w600, color: _ink)),
            ),
          ]),
          Text(s.classGroup,
              style: const TextStyle(fontSize: 12, color: _muted)),
          Flexible(
            child: Text(s.guardian,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: _muted)),
          ),
          Text(s.avg.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12.5,
                  fontWeight: FontWeight.w700, color: _ink)),
          Text('${(s.attendance * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: s.attendance >= .9 ? _green :
                         s.attendance >= .8 ? _gold : _terra)),
          Align(
            alignment: Alignment.centerLeft,
            child: _payBadge(payStatusOf(s)),
          ),
        ],
      ],
    );
  }

  Widget _payBadge(String status) {
    switch (status) {
      case 'Payé':        return StatusPill.success('Payé');
      case 'En attente':  return StatusPill.warning('En attente');
      case 'En retard':   return StatusPill.danger('En retard');
      default:            return StatusPill.neutral('—');
    }
  }
}
