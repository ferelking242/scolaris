import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/widgets/dashboard_scaffold.dart';
import '../../../shared/widgets/qr_panel.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import 'pages/attendance_today_page.dart';
import 'pages/class_stats_page.dart';
import 'pages/classes_page.dart';
import 'pages/gradebook_page.dart';
import 'pages/homework_page.dart';

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});
  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.teacher,
      title: 'Scolaris',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              labelKey: 'nav.dashboard',
              page: _TeacherDashboard()),
          RoleNavEntry(
              icon: Icons.class_outlined,
              activeIcon: Icons.class_rounded,
              labelKey: 'nav.classes',
              page: TeacherClassesPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(
              icon: Icons.grading_outlined,
              activeIcon: Icons.grading_rounded,
              labelKey: 'nav.grades',
              page: GradebookPage()),
          RoleNavEntry(
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              labelKey: 'nav.attendance',
              page: AttendanceTodayPage()),
          RoleNavEntry(
              icon: Icons.qr_code_2_outlined,
              activeIcon: Icons.qr_code_2_rounded,
              labelKey: 'nav.qr',
              page: QrPanel()),
          RoleNavEntry(
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              labelKey: 'nav.homework',
              page: HomeworkPage()),
          RoleNavEntry(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              labelKey: 'nav.class_stats',
              page: ClassStatsPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(
              icon: Icons.chat_outlined,
              activeIcon: Icons.chat_rounded,
              labelKey: 'nav.messages',
              page: MessagingPage()),
          RoleNavEntry(
              icon: Icons.apps_outlined,
              activeIcon: Icons.apps_rounded,
              labelKey: 'nav.features',
              page: FeaturesHubPage()),
        ]),
      ],
    );
  }
}

class _TeacherDashboard extends StatelessWidget {
  const _TeacherDashboard();
  @override
  Widget build(BuildContext context) {
    return const DashboardScaffold(
      stats: [
        DashStat(icon: Icons.class_rounded,      label: 'Mes classes',     value: '6'),
        DashStat(icon: Icons.people_outline,      label: 'Élèves',          value: '178'),
        DashStat(icon: Icons.grading_rounded,     label: 'Moyenne classe',  value: '13.8'),
        DashStat(icon: Icons.assignment_outlined, label: 'Copies à noter',  value: '4'),
      ],
      sections: [
        DashSection(
          title: 'Cours aujourd\'hui',
          count: '3',
          emptyText: 'Aucun cours supplémentaire pour cette période.',
          footerLabel: 'COURS',
          actionLabel: 'Voir classes',
        ),
        DashSection(
          title: 'File de notation',
          count: '4',
          emptyText: 'Aucun devoir en attente de notation.',
          footerLabel: 'NOTATION',
          actionLabel: 'Ouvrir carnet',
          dotColor: Color(0xFFC17F24),
        ),
      ],
      explore: [
        ExploreCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scanner les présences',
          description: 'Utilisez le QR pour pointer les élèves rapidement.',
          suggested: true,
        ),
        ExploreCard(
          icon: Icons.bar_chart_rounded,
          title: 'Statistiques de classe',
          description: 'Analysez les performances par matière et trimestre.',
        ),
      ],
    );
  }
}
