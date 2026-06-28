import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/staff_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../presentation/providers/nav_providers.dart';
import 'pages/enrollment_config_page.dart';
import 'pages/notification_center_page.dart';
import 'pages/timetable_page.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/widgets/permission_guard.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import 'pages/admin_billing_page.dart';
import 'pages/report_cards_page.dart';
import 'pages/admin_school_page.dart';
import 'pages/admin_subscription_page.dart';
import 'pages/admin_classes_page.dart';
import 'pages/admin_subjects_page.dart';
import 'pages/admin_courses_page.dart';
import 'pages/admin_grades_page.dart';
import 'pages/admin_reports_page.dart';
import 'pages/users_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});

  /// Toutes les entrées possibles, chacune taguée avec la permission requise
  /// (null = visible par tout membre du personnel).
  static const List<RoleNavGroup> _allGroups = [
    RoleNavGroup(labelKey: 'sections.setup', entries: [
      RoleNavEntry(icon: Icons.home_rounded, activeIcon: Icons.home_rounded,
          labelKey: 'nav.dashboard', page: _AdminDashboard()),
      RoleNavEntry(icon: Icons.group_outlined, activeIcon: Icons.group_rounded,
          labelKey: 'nav.users',
          page: PermissionGuard(permission: StaffPermissions.students, child: UsersPage()),
          permission: StaffPermissions.students),
      RoleNavEntry(icon: Icons.class_outlined, activeIcon: Icons.class_rounded,
          labelKey: 'nav.classes',
          page: PermissionGuard(permission: StaffPermissions.classes, child: AdminClassesPage()),
          permission: StaffPermissions.classes),
      RoleNavEntry(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded,
          labelKey: 'nav.subjects',
          page: PermissionGuard(permission: StaffPermissions.classes, child: AdminSubjectsPage()),
          permission: StaffPermissions.classes),
      RoleNavEntry(icon: Icons.school_outlined, activeIcon: Icons.school_rounded,
          labelKey: 'nav.courses',
          page: PermissionGuard(permission: StaffPermissions.classes, child: AdminCoursesPage()),
          permission: StaffPermissions.classes),
      RoleNavEntry(icon: Icons.how_to_reg_outlined, activeIcon: Icons.how_to_reg_rounded,
          labelKey: 'nav.enrollment',
          page: PermissionGuard(permission: StaffPermissions.students, child: EnrollmentConfigPage()),
          permission: StaffPermissions.students),
    ]),
    RoleNavGroup(labelKey: 'sections.activity', entries: [
      RoleNavEntry(icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded,
          labelKey: 'nav.billing',
          page: PermissionGuard(permission: StaffPermissions.finance, child: AdminBillingPage()),
          permission: StaffPermissions.finance),
      RoleNavEntry(icon: Icons.workspace_premium_outlined, activeIcon: Icons.workspace_premium_rounded,
          labelKey: 'nav.subscription',
          page: PermissionGuard(permission: StaffPermissions.schoolConfig, child: AdminSubscriptionPage()),
          permission: StaffPermissions.schoolConfig),
      RoleNavEntry(icon: Icons.grade_outlined, activeIcon: Icons.grade_rounded,
          labelKey: 'nav.grades',
          page: PermissionGuard(permission: StaffPermissions.grades, child: AdminGradesPage()),
          permission: StaffPermissions.grades),
      RoleNavEntry(icon: Icons.workspace_premium_outlined, activeIcon: Icons.workspace_premium_rounded,
          labelKey: 'nav.report_cards',
          page: PermissionGuard(permission: StaffPermissions.grades, child: ReportCardsPage()),
          permission: StaffPermissions.grades),
      RoleNavEntry(icon: Icons.summarize_outlined, activeIcon: Icons.summarize_rounded,
          labelKey: 'nav.reports',
          page: PermissionGuard(permission: StaffPermissions.reports, child: AdminReportsPage()),
          permission: StaffPermissions.reports),
      RoleNavEntry(icon: Icons.table_chart_outlined, activeIcon: Icons.table_chart_rounded,
          labelKey: 'nav.timetable',
          page: PermissionGuard(permission: StaffPermissions.timetable, child: TimetablePage()),
          permission: StaffPermissions.timetable),
    ]),
    RoleNavGroup(labelKey: 'sections.account', entries: [
      RoleNavEntry(icon: Icons.campaign_outlined, activeIcon: Icons.campaign_rounded,
          labelKey: 'nav.notifications',
          page: PermissionGuard(permission: StaffPermissions.communication, child: NotificationCenterPage()),
          permission: StaffPermissions.communication),
      RoleNavEntry(icon: Icons.apps_outlined, activeIcon: Icons.apps_rounded,
          labelKey: 'nav.features', page: FeaturesHubPage()),
      RoleNavEntry(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded,
          labelKey: 'nav.school',
          page: PermissionGuard(permission: StaffPermissions.schoolConfig, child: AdminSchoolPage()),
          permission: StaffPermissions.schoolConfig),
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);

    // Menu dynamique : on ne garde que les entrées dont la permission est
    // satisfaite (null = toujours visible). Les groupes vides sont retirés.
    final groups = <RoleNavGroup>[];
    for (final g in _allGroups) {
      final entries = g.entries
          .where((e) => e.permission == null || (user?.can(e.permission!) ?? false))
          .toList();
      if (entries.isNotEmpty) {
        groups.add(RoleNavGroup(labelKey: g.labelKey, entries: entries));
      }
    }

    return ResponsiveRoleShell(
      role: UserRole.staff,
      title: 'Scolaris',
      groups: groups,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard — Windows 11 / macOS pro style
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDashboard extends ConsumerStatefulWidget {
  const _AdminDashboard();
  @override
  ConsumerState<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<_AdminDashboard> {
  String get _greet {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String get _todayStr {
    final n = DateTime.now();
    const days   = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    const months = ['jan.','fév.','mar.','avr.','mai','juin','juil.','août','sep.','oct.','nov.','déc.'];
    return '${days[n.weekday - 1]} ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider);
    final firstName = user?.fullName.split(' ').first ?? 'Admin';
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashGreeting(greet: _greet, name: firstName, date: _todayStr),
            const SizedBox(height: 20),
            const _DashKpiRow(),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (_, c) {
              if (c.maxWidth < 580) {
                return Column(children: [
                  _DashQuickActions(),
                  const SizedBox(height: 16),
                  const _DashActivity(),
                  const SizedBox(height: 16),
                  _DashToday(),
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 3, child: _DashActivity()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: Column(children: [
                    _DashQuickActions(),
                    const SizedBox(height: 16),
                    _DashToday(),
                  ])),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Greeting strip ───────────────────────────────────────────────────────────
class _DashGreeting extends StatelessWidget {
  final String greet, name, date;
  const _DashGreeting({required this.greet, required this.name, required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greet, $name',
              style: const TextStyle(
                  color: _ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.4)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.grid_view_rounded, size: 12, color: _muted),
            const SizedBox(width: 5),
            const Text('Tableau de bord — Administration',
                style: TextStyle(color: _muted, fontSize: 12)),
          ]),
        ])),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDD0C4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: _muted),
            const SizedBox(width: 6),
            Text(date, style: const TextStyle(
                color: _ink, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    );
  }
}

// ── KPI row (données réelles) ────────────────────────────────────────────────
class _DashKpiRow extends ConsumerWidget {
  const _DashKpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentCountProvider);
    final classes  = ref.watch(classesProvider);
    final users    = ref.watch(usersProvider);
    final subjects = ref.watch(subjectsProvider);

    String n(AsyncValue<int> v) =>
        v.maybeWhen(data: (d) => '$d', orElse: () => '—');
    String len(AsyncValue<List> v) =>
        v.maybeWhen(data: (d) => '${d.length}', orElse: () => '—');
    String teachers(AsyncValue<List> v) => v.maybeWhen(
        data: (d) => '${d.where((u) => (u as dynamic).role == 'teacher').length}',
        orElse: () => '—');

    final loadingAny = students.isLoading ||
        classes.isLoading ||
        users.isLoading ||
        subjects.isLoading;

    final kpis = <(IconData, String, String, Color)>[
      (Icons.people_alt_rounded, 'Élèves inscrits', n(students), _terra),
      (Icons.class_rounded, 'Classes actives', len(classes), _orange),
      (Icons.co_present_rounded, 'Enseignants', teachers(users), _green),
      (Icons.menu_book_rounded, 'Matières', len(subjects), _gold),
    ];

    Widget card(int i) =>
        _DashKpiCard(kpi: kpis[i], loading: loadingAny);

    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth < 500) {
        return Column(children: [
          Row(children: [
            Expanded(child: card(0)),
            const SizedBox(width: 10),
            Expanded(child: card(1)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: card(2)),
            const SizedBox(width: 10),
            Expanded(child: card(3)),
          ]),
        ]);
      }
      return Row(children: [
        for (var i = 0; i < kpis.length; i++)
          Expanded(
              child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
            child: card(i),
          )),
      ]);
    });
  }
}

class _DashKpiCard extends StatelessWidget {
  final (IconData, String, String, Color) kpi;
  final bool loading;
  const _DashKpiCard({required this.kpi, required this.loading});

  @override
  Widget build(BuildContext context) {
    final (icon, label, value, accent) = kpi;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD0C4)),
        boxShadow: const [BoxShadow(
            color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
                color: accent.withOpacity(.10),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: accent),
          ),
        ]),
        const SizedBox(height: 10),
        if (loading)
          Container(height: 20, width: 60, decoration: BoxDecoration(
              color: const Color(0xFFEEE5D8), borderRadius: BorderRadius.circular(5)))
        else
          Text(value, style: TextStyle(
              color: accent, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.3)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(
            color: _muted, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Activity feed (données réelles : dernières inscriptions) ─────────────────
class _DashActivity extends ConsumerWidget {
  const _DashActivity();

  static String _ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentStudentsProvider);
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD0C4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(children: [
            Icon(Icons.timeline_rounded, size: 15, color: _muted),
            SizedBox(width: 7),
            Text('Dernières inscriptions',
                style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFEEE5D8)),
        recent.when(
          loading: () => Column(
              children: List.generate(3, (_) => const _ActivitySkeleton())),
          error: (e, _) => const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Activité indisponible.',
                style: TextStyle(color: _muted, fontSize: 12)),
          ),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      'Aucune inscription pour le moment. Ajoutez un élève depuis Utilisateurs.',
                      style: TextStyle(color: _muted, fontSize: 12.5)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      _ActivityItem(
                        icon: Icons.person_add_rounded,
                        color: _terra,
                        title: list[i].fullName.isEmpty
                            ? 'Nouvel élève'
                            : list[i].fullName,
                        sub: list[i].className == null ||
                                list[i].className!.isEmpty
                            ? 'Sans classe'
                            : list[i].className!,
                        time: _ago(list[i].createdAt),
                        last: i == list.length - 1,
                      ),
                  ],
                ),
        ),
      ]),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(
            color: const Color(0xFFEEE5D8), borderRadius: BorderRadius.circular(9))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 11, width: 140, decoration: BoxDecoration(
              color: const Color(0xFFEEE5D8), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(height: 9, width: 90, decoration: BoxDecoration(
              color: const Color(0xFFEEE5D8), borderRadius: BorderRadius.circular(4))),
        ])),
      ]),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub, time;
  final bool last;
  const _ActivityItem({
    required this.icon, required this.color,
    required this.title, required this.sub, required this.time, required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(.08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withOpacity(.14))),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(sub, style: const TextStyle(color: _muted, fontSize: 11.5)),
          ])),
          Text(time, style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
      ),
      if (!last) const Divider(height: 1, indent: 62, color: Color(0xFFEEE5D8)),
    ]);
  }
}

// ── Quick actions panel ───────────────────────────────────────────────────────
class _DashQuickActions extends ConsumerWidget {
  // (icône, libellé, couleur, labelKey de nav cible)
  static const _actions = [
    (Icons.person_add_rounded, 'Inscrire un élève',  _terra,            'nav.users'),
    (Icons.class_rounded,      'Gérer les classes',  _orange,           'nav.classes'),
    (Icons.menu_book_rounded,  'Gérer les matières', Color(0xFF388E3C), 'nav.subjects'),
    (Icons.summarize_rounded,  'Voir les rapports',  _gold,             'nav.reports'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD0C4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.bolt_rounded, size: 15, color: _muted),
            SizedBox(width: 7),
            Text('Actions rapides',
                style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFEEE5D8)),
        ...List.generate(_actions.length, (i) {
          final a = _actions[i];
          return Column(children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: i == _actions.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(14))
                    : BorderRadius.zero,
                onTap: () =>
                    ref.read(navIntentProvider.notifier).state = a.$4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: a.$3.withOpacity(.09),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(a.$1, size: 14, color: a.$3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.$2,
                        style: const TextStyle(
                            color: _ink, fontSize: 12.5, fontWeight: FontWeight.w500))),
                    Icon(Icons.chevron_right_rounded, size: 15,
                        color: _muted.withOpacity(.5)),
                  ]),
                ),
              ),
            ),
            if (i < _actions.length - 1)
              const Divider(height: 1, indent: 58, color: Color(0xFFEEE5D8)),
          ]);
        }),
      ]),
    );
  }
}

// ── Today summary ─────────────────────────────────────────────────────────────
class _DashToday extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync      = ref.watch(recentStudentsProvider);
    final invoicesAsync    = ref.watch(invoicesProvider);
    final announcementsAsync = ref.watch(announcementsProvider);

    final today = DateTime.now();
    bool sameDay(DateTime? d) =>
        d != null && d.year == today.year && d.month == today.month && d.day == today.day;

    final inscriptions = recentAsync.maybeWhen(
      data: (list) => list.where((s) => sameDay(s.createdAt)).length,
      orElse: () => null,
    );
    final pending = invoicesAsync.maybeWhen(
      data: (list) => list.where((inv) => inv.isPending).length,
      orElse: () => null,
    );
    final overdue = invoicesAsync.maybeWhen(
      data: (list) => list.where((inv) => inv.isOverdue).length,
      orElse: () => null,
    );
    final announcements = announcementsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => null,
    );

    String fmt(int? n, String singular, String plural) {
      if (n == null) return '…';
      return '$n ${n == 1 ? singular : plural}';
    }

    final items = <(IconData, Color, String)>[
      (Icons.person_add_outlined,
          _terra,
          inscriptions == null
              ? 'Inscriptions du jour…'
              : inscriptions == 0
                  ? 'Aucune inscription aujourd\'hui'
                  : fmt(inscriptions, 'inscription aujourd\'hui', 'inscriptions aujourd\'hui')),
      (Icons.hourglass_top_outlined,
          _orange,
          fmt(pending, 'facture en attente', 'factures en attente')),
      (Icons.warning_amber_rounded,
          _gold,
          overdue == 0 || overdue == null && invoicesAsync.hasValue
              ? 'Aucune facture en retard'
              : fmt(overdue, 'facture en retard', 'factures en retard')),
      (Icons.campaign_outlined,
          _green,
          fmt(announcements, 'annonce active', 'annonces actives')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD0C4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.today_rounded, size: 15, color: _muted),
            SizedBox(width: 7),
            Text("Aujourd'hui",
                style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFEEE5D8)),
        ...List.generate(items.length, (i) {
          final it = items[i];
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: it.$2.withOpacity(.55), shape: BoxShape.circle),
                ),
                Icon(it.$1, size: 13, color: it.$2),
                const SizedBox(width: 8),
                Expanded(child: Text(it.$3,
                    style: const TextStyle(color: _ink, fontSize: 12))),
              ]),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 30, color: Color(0xFFEEE5D8)),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}
