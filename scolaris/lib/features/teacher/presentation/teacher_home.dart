import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/my_grants.dart';
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

/// Le menu du professeur, **filtré par ses permissions**.
///
/// Le rôle « Enseignant » portait des permissions depuis 20260721, mais aucun
/// écran du prof ne les lisait : l'admin pouvait décocher « Notes » et le carnet
/// restait là — la base refusait la note, l'app affichait une erreur. La
/// permission était décorative.
///
/// Un directeur peut désormais décider « chez moi les profs ne font pas l'appel,
/// c'est le surveillant » : l'onglet disparaît. Le menu et la base disent enfin
/// la même chose.
class TeacherHome extends ConsumerWidget {
  const TeacherHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool can(String g) => ref.watch(canProvider(g));

    return ResponsiveRoleShell(
      role: UserRole.teacher,
      title: 'Scolaris',
      groups: [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          const RoleNavEntry(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              labelKey: 'nav.dashboard',
              page: _TeacherDashboard()),
          if (can('eleves.voir'))
            const RoleNavEntry(
                icon: Icons.class_outlined,
                activeIcon: Icons.class_rounded,
                labelKey: 'nav.classes',
                page: TeacherClassesPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          if (can('notes.voir'))
            const RoleNavEntry(
                icon: Icons.grading_outlined,
                activeIcon: Icons.grading_rounded,
                labelKey: 'nav.grades',
                page: GradebookPage()),
          if (can('presences.voir'))
            const RoleNavEntry(
                icon: Icons.fact_check_outlined,
                activeIcon: Icons.fact_check_rounded,
                labelKey: 'nav.attendance',
                page: AttendanceTodayPage()),
          // Le QR sert à pointer les présences : sans le droit de faire l'appel,
          // il ne mène nulle part.
          if (can('presences.saisir'))
            const RoleNavEntry(
                icon: Icons.qr_code_2_outlined,
                activeIcon: Icons.qr_code_2_rounded,
                labelKey: 'nav.qr',
                page: QrPanel()),
          if (can('notes.voir'))
            const RoleNavEntry(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                labelKey: 'nav.class_stats',
                page: ClassStatsPage()),
          // L'écriture du cahier de liaison. Sans elle, le cahier que voient
          // les familles reste une boîte vide.
          if (can('liaison.voir'))
            const RoleNavEntry(
                icon: Icons.import_contacts_outlined,
                activeIcon: Icons.import_contacts_rounded,
                labelKey: 'nav.cahier_liaison',
                page: TeacherLiaisonPage()),
          // L'attribution des bons points et badges. Même logique : sans
          // écriture, le carnet des familles reste vide.
          if (can('recompenses.voir'))
            const RoleNavEntry(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events_rounded,
                labelKey: 'nav.recompenses',
                page: TeacherRewardsPage()),
        ]),
        // Messagerie retirée : l'écran était 100 % fictif (conversations codées
        // en dur, aucun accès à la base). À réintroduire quand une vraie
        // messagerie existera (schéma conversations/participants + RLS).
        const RoleNavGroup(labelKey: 'sections.account', entries: [
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
