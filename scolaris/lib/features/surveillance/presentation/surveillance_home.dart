import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../shared/pages/settings_page.dart';
import '../../../shared/widgets/dashboard_scaffold.dart';
import '../../../shared/widgets/qr_panel.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import 'pages/attendance_log_page.dart';
import 'pages/students_list_page.dart';

class SurveillanceHome extends StatelessWidget {
  const SurveillanceHome({super.key});
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
              page: _SurvDashboard()),
          RoleNavEntry(
              icon: Icons.qr_code_2_outlined,
              activeIcon: Icons.qr_code_2_rounded,
              labelKey: 'nav.qr',
              page: QrPanel()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              labelKey: 'nav.attendance',
              page: AttendanceLogPage()),
          RoleNavEntry(
              icon: Icons.people_outline,
              activeIcon: Icons.people_rounded,
              labelKey: 'nav.students',
              page: StudentsListPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              labelKey: 'common.settings',
              page: SettingsPage()),
        ]),
      ],
    );
  }
}

class _SurvDashboard extends StatelessWidget {
  const _SurvDashboard();
  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      stats: [
        DashStat(icon: Icons.check_circle_outline,    label: 'Taux de présence', value: '94%'),
        DashStat(icon: Icons.cancel_outlined,          label: 'Absences',         value: '12'),
        DashStat(icon: Icons.qr_code_scanner,          label: 'Scans QR',         value: '341'),
        DashStat(icon: Icons.warning_amber_outlined,   label: 'Alertes actives',  value: '2'),
      ],
      sections: [
        DashSection(
          title: 'Retards du jour',
          count: '2',
          emptyText: 'Aucun retard pour cette période.',
          footerLabel: 'SCANS PORTAIL',
          actionLabel: 'Voir journal',
        ),
        DashSection(
          title: 'Absences non justifiées',
          count: '1',
          emptyText: 'Aucune absence non justifiée pour cette période.',
          footerLabel: 'ABSENCES',
          actionLabel: 'Signaler',
          dotColor: Color(0xFF8B1A00),
        ),
      ],
      explore: [
        ExploreCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Mode scan rapide',
          description: 'Activez le scanner QR pour pointer les entrées en temps réel.',
          suggested: true,
        ),
        ExploreCard(
          icon: Icons.notification_important_outlined,
          title: 'Alertes parents',
          description: 'Notifiez automatiquement les parents en cas d\'absence.',
        ),
      ],
    );
  }
}
