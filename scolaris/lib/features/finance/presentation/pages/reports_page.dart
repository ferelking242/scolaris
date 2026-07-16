import 'package:flutter/material.dart';

import '../../../../shared/widgets/page_scaffold.dart';

class FinanceReportsPage extends StatelessWidget {
  const FinanceReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Reports',
      subtitle: 'Monthly P&L, fee collection, exports',
      actions: [
        ActionButton(
            label: 'Custom report',
            icon: Icons.tune_rounded,
            onTap: () {}),
        const SizedBox(width: 8),
        ActionButton(
            label: 'Export PDF',
            icon: Icons.file_download_outlined,
            primary: true,
            onTap: () {}),
      ],
      child: Column(
        children: [
          DataPanel(
            title: 'April 2026 — overview',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth > 800 ? 4 : 2;
                final items = [
                  ('Revenue', '\$24,580', const Color(0xFF16A34A)),
                  ('Cash in', '\$22,910', const Color(0xFF0EA5E9)),
                  ('Pending', '\$3,420', const Color(0xFFEA580C)),
                  ('Overdue', '\$1,420', const Color(0xFFDC2626)),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final it in items)
                      SizedBox(
                        width: (c.maxWidth - (cols - 1) * 12) / cols - 0.5,
                        child: _Tile(label: it.$1, value: it.$2, color: it.$3),
                      ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          DataPanel(
            title: 'Available reports',
            child: Column(
              children: [
                _ReportRow(
                  title: 'Monthly P&L',
                  subtitle: 'Profit & loss snapshot of the school month',
                  icon: Icons.bar_chart_rounded,
                ),
                Divider(color: border, height: 1),
                _ReportRow(
                  title: 'Fee collection ratio',
                  subtitle: 'Compares billed vs paid by class',
                  icon: Icons.pie_chart_outline_rounded,
                ),
                Divider(color: border, height: 1),
                _ReportRow(
                  title: 'Outstanding by family',
                  subtitle: 'Aged balance grouped by guardian',
                  icon: Icons.family_restroom_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Tile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: subtleBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const _ReportRow({required this.title, required this.subtitle, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: subtleBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, color: ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11.5, color: muted)),
              ],
            ),
          ),
          ActionButton(label: 'Generate', icon: Icons.play_arrow_rounded, onTap: () {}, primary: true),
        ],
      ),
    );
  }
}
