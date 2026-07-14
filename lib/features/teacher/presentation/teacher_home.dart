import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/widgets/dashboard_scaffold.dart';
import '../../../shared/widgets/qr_panel.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/school_switcher.dart';
import 'pages/attendance_today_page.dart';
import 'pages/class_stats_page.dart';
import 'pages/classes_page.dart';
import 'pages/gradebook_page.dart';
import 'pages/teacher_liaison_page.dart';
import 'pages/teacher_rewards_page.dart';

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
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              labelKey: 'nav.class_stats',
              page: ClassStatsPage()),
          // L'écriture du cahier de liaison. Sans elle, le cahier que voient
          // les familles reste une boîte vide.
          RoleNavEntry(
              icon: Icons.import_contacts_outlined,
              activeIcon: Icons.import_contacts_rounded,
              labelKey: 'nav.cahier_liaison',
              page: TeacherLiaisonPage()),
          // L'attribution des bons points et badges. Même logique : sans
          // écriture, le carnet des familles reste vide.
          RoleNavEntry(
              icon: Icons.emoji_events_outlined,
              activeIcon: Icons.emoji_events_rounded,
              labelKey: 'nav.recompenses',
              page: TeacherRewardsPage()),
        ]),
        // Messagerie retirée : l'écran était 100 % fictif (conversations codées
        // en dur, aucun accès à la base). À réintroduire quand une vraie
        // messagerie existera (schéma conversations/participants + RLS).
        RoleNavGroup(labelKey: 'sections.account', entries: [
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

class _TeacherDashboard extends ConsumerWidget {
  const _TeacherDashboard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assign     = ref.watch(teacherAssignmentsProvider).valueOrNull;
    final schedules  = ref.watch(teacherSchedulesProvider).valueOrNull ?? const [];
    final studentsN  = ref.watch(teacherStudentCountProvider).valueOrNull;
    final loading    = assign == null;

    final classesN = assign?.classIds.length ?? 0;
    final subjectsN = assign == null
        ? 0
        : <String>{for (final set in assign.subjectsByClass.values) ...set}.length;
    final today = DateTime.now().weekday;
    final coursToday = schedules.where((s) => s.dayOfWeek == today).length;

    return Column(children: [
      const SchoolSwitcher(),
      Expanded(
        child: DashboardScaffold(
      loading: loading,
      stats: [
        DashStat(icon: Icons.class_rounded, label: 'Mes classes', value: '$classesN'),
        DashStat(icon: Icons.people_outline, label: 'Mes élèves', value: '${studentsN ?? 0}'),
        DashStat(icon: Icons.menu_book_rounded, label: 'Mes matières', value: '$subjectsN'),
        DashStat(icon: Icons.event_available_rounded, label: "Cours aujourd'hui", value: '$coursToday'),
      ],
      sections: [
        DashSection(
          title: "Cours aujourd'hui",
          count: '$coursToday',
          emptyText: coursToday == 0
              ? 'Aucun cours prévu aujourd\'hui.'
              : '$coursToday créneau(x) à assurer aujourd\'hui.',
          footerLabel: 'EMPLOI DU TEMPS',
        ),
        DashSection(
          title: 'Classes suivies',
          count: '$classesN',
          emptyText: classesN == 0
              ? 'Aucune classe ne vous est assignée.'
              : 'Sur $subjectsN matière(s) enseignée(s).',
          footerLabel: 'CLASSES',
          dotColor: const Color(0xFFC17F24),
        ),
      ],
      explore: const [
        ExploreCard(
          icon: Icons.grading_rounded,
          title: 'Saisir les notes',
          description: 'Ouvrez le carnet pour valider les notes de vos classes.',
          suggested: true,
        ),
        ExploreCard(
          icon: Icons.bar_chart_rounded,
          title: 'Statistiques de classe',
          description: 'Analysez les performances réelles par matière.',
        ),
      ],
        ),
      ),
    ]);
  }
}
