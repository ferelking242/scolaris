import 'package:flutter/material.dart';

import '../../../domain/entities/user_entity.dart';
import '../../../shared/widgets/dashboard_scaffold.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import 'pages/billing_page.dart';
import 'pages/finance_students_page.dart';
import 'pages/payments_page.dart';
import 'pages/receipts_page.dart';
import 'pages/reports_page.dart';

class FinanceHome extends StatelessWidget {
  const FinanceHome({super.key});
  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.staff,
      title: 'Scolaris',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              labelKey: 'nav.dashboard',
              page: _FinanceDashboard()),
          RoleNavEntry(
              icon: Icons.people_outline,
              activeIcon: Icons.people_rounded,
              labelKey: 'nav.students',
              page: FinanceStudentsPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(
              icon: Icons.payments_outlined,
              activeIcon: Icons.payments_rounded,
              labelKey: 'nav.payments',
              page: FinancePaymentsPage()),
          RoleNavEntry(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              labelKey: 'nav.billing',
              page: BillingPage()),
          RoleNavEntry(
              icon: Icons.print_outlined,
              activeIcon: Icons.print_rounded,
              labelKey: 'nav.receipts',
              page: ReceiptsPage()),
          RoleNavEntry(
              icon: Icons.summarize_outlined,
              activeIcon: Icons.summarize_rounded,
              labelKey: 'nav.reports',
              page: FinanceReportsPage()),
        ]),
        // Profil accessible uniquement via l'avatar de l'app bar (mobile) —
        // plus de doublon dans le drawer.
      ],
    );
  }
}

class _FinanceDashboard extends StatelessWidget {
  const _FinanceDashboard();
  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      stats: [
        DashStat(icon: Icons.account_balance_wallet_outlined, label: 'Revenus (mois)',  value: '24 580 F'),
        DashStat(icon: Icons.receipt_long_outlined,            label: 'Factures',        value: '187'),
        DashStat(icon: Icons.timelapse_rounded,                label: 'En attente',      value: '3 420 F'),
        DashStat(icon: Icons.people_outline,                   label: 'Élèves',          value: '8'),
      ],
      sections: [
        DashSection(
          title: 'Paiements récents',
          count: '12',
          emptyText: 'Aucune activité de paiement pour cette période.',
          footerLabel: 'PAIEMENTS',
          actionLabel: 'Voir paiements',
        ),
        DashSection(
          title: 'Factures impayées',
          count: '3',
          emptyText: 'Aucune facture en souffrance pour cette période.',
          footerLabel: 'FACTURES',
          actionLabel: 'Gérer factures',
          dotColor: Color(0xFFD4540A),
        ),
      ],
      explore: [
        ExploreCard(
          icon: Icons.print_rounded,
          title: 'Imprimer les reçus',
          description: 'Imprimez les reçus de paiement (WiFi, Bluetooth, câble).',
          suggested: true,
        ),
        ExploreCard(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Rapport financier',
          description: 'Générez un rapport complet des recettes et dépenses.',
        ),
        ExploreCard(
          icon: Icons.people_outline,
          title: 'Liste des élèves',
          description: 'Consultez la liste complète avec statuts de paiement.',
        ),
      ],
    );
  }
}
