import 'package:flutter/material.dart';

import '../../../../shared/widgets/page_scaffold.dart';

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Billing',
      subtitle: 'Configure fee plans and recurring billing',
      actions: [
        ActionButton(
            label: 'New plan',
            icon: Icons.add_rounded,
            primary: true,
            onTap: () {}),
      ],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _PlanCard(
                  name: 'Tuition (monthly)',
                  price: '\$320 / month',
                  description: 'Standard academic fee, billed on the 1st.',
                  active: 187)),
              const SizedBox(width: 12),
              Expanded(child: _PlanCard(
                  name: 'Cantine',
                  price: '\$85 / month',
                  description: 'Lunch program — opt-in.',
                  active: 92)),
              const SizedBox(width: 12),
              Expanded(child: _PlanCard(
                  name: 'School bus',
                  price: '\$60 / month',
                  description: '2 routes, billed monthly.',
                  active: 41)),
            ],
          ),
          const SizedBox(height: 14),
          DataPanel(
            title: 'Upcoming billing runs',
            child: DataTablePanel(
              columns: const ['Run date', 'Plan', 'Recipients', 'Total', 'Status'],
              flex: const [2, 3, 2, 2, 2],
              rows: [
                _row('01 May 2026', 'Tuition (monthly)', '187', '\$59,840', StatusPill.info('Scheduled')),
                _row('01 May 2026', 'Cantine',           '92',  '\$7,820',  StatusPill.info('Scheduled')),
                _row('01 May 2026', 'School bus',        '41',  '\$2,460',  StatusPill.info('Scheduled')),
                _row('01 Apr 2026', 'Tuition (monthly)', '184', '\$58,880', StatusPill.success('Completed')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _row(String date, String plan, String recipients, String total, Widget statusPill) =>
      [
        Text(date, style: const TextStyle(fontSize: 12, color: ink, fontWeight: FontWeight.w600)),
        Text(plan, style: const TextStyle(fontSize: 12, color: ink)),
        Text(recipients, style: const TextStyle(fontSize: 12, color: muted)),
        Text(total, style: const TextStyle(fontSize: 12.5, color: ink, fontWeight: FontWeight.w700)),
        Align(alignment: Alignment.centerLeft, child: statusPill),
      ];
}

class _PlanCard extends StatelessWidget {
  final String name, price, description;
  final int active;
  const _PlanCard({
    required this.name,
    required this.price,
    required this.description,
    required this.active,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13, color: ink, fontWeight: FontWeight.w700)),
              ),
              StatusPill.success('$active active'),
            ],
          ),
          const SizedBox(height: 8),
          Text(price,
              style: const TextStyle(
                  fontSize: 18, color: ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(fontSize: 11.5, color: muted, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              ActionButton(label: 'Edit', icon: Icons.edit_outlined, onTap: () {}),
              const SizedBox(width: 6),
              ActionButton(label: 'Run now', icon: Icons.play_arrow_rounded, onTap: () {}, primary: true),
            ],
          ),
        ],
      ),
    );
  }
}
