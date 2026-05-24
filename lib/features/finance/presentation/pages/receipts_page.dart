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

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});
  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  String _statusFilter = 'Tous';
  String _search = '';
  bool _printing = false;

  List<MockInvoice> get _filtered {
    return MockData.invoices.where((inv) {
      final matchStatus = _statusFilter == 'Tous'
          ? true
          : _statusFilter == 'Payés'
              ? inv.status == InvoiceStatus.paid
              : _statusFilter == 'En attente'
                  ? inv.status == InvoiceStatus.pending
                  : inv.status == InvoiceStatus.overdue;
      final matchSearch = _search.isEmpty ||
          inv.student.toLowerCase().contains(_search.toLowerCase()) ||
          inv.number.toLowerCase().contains(_search.toLowerCase()) ||
          inv.description.toLowerCase().contains(_search.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();
  }

  void _printOne(MockInvoice inv) {
    setState(() => _printing = true);
    Future.microtask(() {
      PrintService.printReceipt(
        invoice: inv,
        schoolName: 'École Scolaris',
        schoolAddress: 'Avenue des Savoirs, Dakar',
        schoolPhone: '+221 33 000 00 00',
        cashierName: 'Jean Tshibangu',
      );
      setState(() => _printing = false);
    });
  }

  void _printAll() {
    setState(() => _printing = true);
    Future.microtask(() {
      for (final inv in _filtered) {
        PrintService.printReceipt(
          invoice: inv,
          schoolName: 'École Scolaris',
          schoolAddress: 'Avenue des Savoirs, Dakar',
          cashierName: 'Jean Tshibangu',
        );
      }
      setState(() => _printing = false);
    });
  }

  void _printReport() {
    PrintService.printFinanceReport(
      invoices: MockData.invoices,
      schoolName: 'École Scolaris',
      period: 'Avril 2026',
      printedBy: 'Jean Tshibangu',
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPaid = MockData.totalCollected();
    final totalPending = MockData.totalPending();
    final totalOverdue = MockData.totalOverdue();

    return PageScaffold(
      title: 'Reçus & Impression',
      subtitle: '${MockData.invoices.length} factures au total',
      actions: [
        ActionButton(
          label: 'Rapport',
          icon: Icons.summarize_outlined,
          onTap: _printReport,
        ),
        const SizedBox(width: 8),
        ActionButton(
          label: _printing ? 'Impression...' : 'Imprimer sélection',
          icon: Icons.print_rounded,
          primary: true,
          onTap: _printing ? null : _printAll,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Stats summary ───────────────────────────────────────────────
          _StatsSummary(
            totalPaid: totalPaid,
            totalPending: totalPending,
            totalOverdue: totalOverdue,
            count: MockData.invoices.length,
          ),
          const SizedBox(height: 16),

          // ── Printer info banner ─────────────────────────────────────────
          _PrinterInfoBanner(),
          const SizedBox(height: 16),

          // ── Filters ────────────────────────────────────────────────────
          DataPanel(
            title: 'Factures & Reçus',
            headerActions: [
              SearchInput(
                hint: 'Rechercher élève, N°…',
                onChanged: (v) => setState(() => _search = v),
              ),
            ],
            child: Column(
              children: [
                _StatusFilterBar(
                  current: _statusFilter,
                  onChange: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucun reçu trouvé',
                    description: 'Modifiez vos filtres ou effectuez une recherche.',
                  )
                else
                  _InvoiceTable(invoices: filtered, onPrint: _printOne),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Summary ─────────────────────────────────────────────────────────
class _StatsSummary extends StatelessWidget {
  final double totalPaid;
  final double totalPending;
  final double totalOverdue;
  final int count;

  const _StatsSummary({
    required this.totalPaid,
    required this.totalPending,
    required this.totalOverdue,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(
        icon: Icons.check_circle_rounded,
        label: 'Encaissé',
        value: '${totalPaid.toStringAsFixed(0)} F',
        color: _green,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        icon: Icons.schedule_rounded,
        label: 'En attente',
        value: '${totalPending.toStringAsFixed(0)} F',
        color: _gold,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        icon: Icons.warning_rounded,
        label: 'En retard',
        value: '${totalOverdue.toStringAsFixed(0)} F',
        color: _terra,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        icon: Icons.receipt_long_rounded,
        label: 'Total factures',
        value: '$count',
        color: _muted,
      )),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderC),
        boxShadow: const [BoxShadow(
            color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: _muted,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 15, color: color,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Printer Info Banner ───────────────────────────────────────────────────
class _PrinterInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withOpacity(.3)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _green.withOpacity(.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.print_rounded, color: _green, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Impression universelle',
                style: TextStyle(fontSize: 12.5, color: _ink,
                    fontWeight: FontWeight.w700)),
            Text(
              'Cliquez "Imprimer" pour ouvrir le dialogue d\'impression de votre '
              'système. Compatible WiFi, Bluetooth, USB/câble — toute imprimante '
              'reconnue par votre ordinateur fonctionne.',
              style: TextStyle(fontSize: 11, color: _muted.withOpacity(.9), height: 1.4),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _PrintBadge(icon: Icons.wifi_rounded, label: 'WiFi'),
            const SizedBox(height: 4),
            _PrintBadge(icon: Icons.bluetooth_rounded, label: 'Bluetooth'),
            const SizedBox(height: 4),
            _PrintBadge(icon: Icons.usb_rounded, label: 'USB'),
          ],
        ),
      ]),
    );
  }
}

class _PrintBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PrintBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _green.withOpacity(.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _green.withOpacity(.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: _green),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 9, color: _green,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Status Filter Bar ─────────────────────────────────────────────────────
class _StatusFilterBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;

  const _StatusFilterBar({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final options = ['Tous', 'Payés', 'En attente', 'En retard'];
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((o) {
            final active = o == current;
            final color = o == 'Payés'
                ? _green
                : o == 'En attente'
                    ? _gold
                    : o == 'En retard'
                        ? _terra
                        : _ink;
            return GestureDetector(
              onTap: () => onChange(o),
              child: Container(
                height: 30,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? color : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? color : _borderC),
                ),
                child: Text(o,
                    style: TextStyle(
                        fontSize: 12,
                        color: active ? _white : _ink,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Invoice Table ─────────────────────────────────────────────────────────
class _InvoiceTable extends StatelessWidget {
  final List<MockInvoice> invoices;
  final void Function(MockInvoice) onPrint;

  const _InvoiceTable({required this.invoices, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    return DataTablePanel(
      columns: const ['N° Facture', 'Élève', 'Objet', 'Montant', 'Statut', 'Actions'],
      flex: const [2, 3, 3, 2, 2, 2],
      rows: [
        for (final inv in invoices)
          [
            Text(inv.number,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600,
                    color: _muted, fontFamily: 'monospace')),
            Row(children: [
              Avatar(name: inv.student, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(inv.student,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5,
                        fontWeight: FontWeight.w600, color: _ink)),
              ),
            ]),
            Text(inv.description,
                style: const TextStyle(fontSize: 12, color: _muted)),
            Text('${inv.amount.toStringAsFixed(0)} F',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: _ink)),
            Align(
              alignment: Alignment.centerLeft,
              child: inv.status == InvoiceStatus.paid
                  ? StatusPill.success('Payé')
                  : inv.status == InvoiceStatus.pending
                      ? StatusPill.warning('En attente')
                      : StatusPill.danger('En retard'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _PrintButton(onTap: () => onPrint(inv)),
            ),
          ],
      ],
    );
  }
}

class _PrintButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PrintButton({required this.onTap});

  @override
  State<_PrintButton> createState() => _PrintButtonState();
}

class _PrintButtonState extends State<_PrintButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hover ? _terra : Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _hover ? _terra : _borderC),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.print_rounded, size: 12,
                color: _hover ? _white : _terra),
            const SizedBox(width: 5),
            Text('Imprimer',
                style: TextStyle(
                    fontSize: 11.5,
                    color: _hover ? _white : _terra,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
