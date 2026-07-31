import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/staff_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../presentation/providers/nav_providers.dart';
import '../roles/roles_permissions_page.dart';
import 'pages/enrollment_config_page.dart';
import 'pages/prereg_queue_page.dart';
import 'pages/timetable_page.dart';
import '../../../shared/widgets/permission_guard.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import 'pages/admin_billing_page.dart';
import 'pages/admin_school_page.dart';
import 'pages/admin_subscription_page.dart';
import 'pages/admin_classes_page.dart';
import 'pages/class_promotion_page.dart';
import 'pages/admin_subjects_page.dart';
import 'pages/admin_courses_page.dart';
import 'pages/admin_grades_page.dart';
import 'pages/admin_reports_page.dart';
import 'pages/admin_attendance_page.dart';
import 'pages/admin_class_stats_page.dart';
// import 'pages/library_submission_page.dart'; // Bibliothèque désactivée temporairement.
import 'pages/users_page.dart';

// Accents de marque — volontairement constants, lisibles en clair comme en sombre.
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

// Neutres dérivés du thème courant (s'adaptent clair/sombre).
class _DashColors {
  final Color ink;      // texte principal
  final Color muted;    // texte secondaire
  final Color card;     // fond des cartes
  final Color border;   // contour des cartes
  final Color divider;  // séparateurs internes
  final Color skeleton; // blocs de chargement
  const _DashColors(
      this.ink, this.muted, this.card, this.border, this.divider, this.skeleton);

  factory _DashColors.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _DashColors(
      cs.onSurface,
      cs.onSurfaceVariant,
      cs.surface,
      cs.outlineVariant,
      cs.outlineVariant.withValues(alpha: .5),
      cs.surfaceContainerHighest,
    );
  }
}

class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});

  /// Toutes les entrées possibles, chacune taguée avec la permission requise
  /// (null = visible par tout membre du personnel).
  static const List<RoleNavGroup> _allGroups = [
    RoleNavGroup(labelKey: 'sections.setup', entries: [
      RoleNavEntry(icon: Icons.home_rounded, activeIcon: Icons.home_rounded,
          labelKey: 'nav.dashboard', page: _AdminDashboard()),
      // Deux populations, deux écrans. Le PERSONNEL se recrute et porte un rôle ;
      // les ÉLÈVES s'inscrivent et appartiennent à une classe. Les mélanger dans
      // « Utilisateurs » obligeait à filtrer pour retrouver quelqu'un.
      RoleNavEntry(icon: Icons.badge_outlined, activeIcon: Icons.badge_rounded,
          labelKey: 'Personnel',
          page: PermissionGuard(
              permission: StaffPermissions.staffManage,
              child: UsersPage(scope: UsersScope.staff)),
          permission: StaffPermissions.staffManage),
      RoleNavEntry(icon: Icons.group_outlined, activeIcon: Icons.group_rounded,
          labelKey: 'Élèves & familles',
          page: PermissionGuard(
              permission: StaffPermissions.students,
              child: UsersPage(scope: UsersScope.families)),
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
      RoleNavEntry(icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded,
          labelKey: 'Pré-inscriptions',
          page: PermissionGuard(permission: StaffPermissions.students, child: PreRegQueuePage()),
          permission: StaffPermissions.students),
      // Fin d'année : passage de classe ET sortie d'élève (transfert/diplôme/
      // radiation) — la même décision annuelle, cf. class_promotion_page.dart.
      RoleNavEntry(icon: Icons.move_up_outlined, activeIcon: Icons.move_up_rounded,
          labelKey: 'Passage de classe',
          page: PermissionGuard(permission: StaffPermissions.promotion, child: ClassPromotionPage()),
          permission: StaffPermissions.promotion),
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
      // Notes, bulletins et génération sont désormais TROIS ONGLETS d'une seule
      // page. Plus deux entrées de menu qui se ressemblent (« Notes »,
      // « Bulletins ») et où le vrai bulletin restait introuvable.
      RoleNavEntry(icon: Icons.grade_outlined, activeIcon: Icons.grade_rounded,
          labelKey: 'nav.grades',
          page: PermissionGuard(permission: StaffPermissions.grades, child: AdminGradesPage()),
          permission: StaffPermissions.grades),
      RoleNavEntry(icon: Icons.how_to_reg_outlined, activeIcon: Icons.how_to_reg_rounded,
          labelKey: 'Présences',
          page: PermissionGuard(permission: StaffPermissions.attendance, child: AdminAttendancePage()),
          permission: StaffPermissions.attendance),
      RoleNavEntry(icon: Icons.summarize_outlined, activeIcon: Icons.summarize_rounded,
          labelKey: 'nav.reports',
          page: PermissionGuard(permission: StaffPermissions.reports, child: AdminReportsPage()),
          permission: StaffPermissions.reports),
      RoleNavEntry(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded,
          labelKey: 'Statistiques de classe',
          page: PermissionGuard(permission: StaffPermissions.reports, child: AdminClassStatsPage()),
          permission: StaffPermissions.reports),
      RoleNavEntry(icon: Icons.table_chart_outlined, activeIcon: Icons.table_chart_rounded,
          labelKey: 'nav.timetable',
          page: PermissionGuard(permission: StaffPermissions.timetable, child: TimetablePage()),
          permission: StaffPermissions.timetable),
      // "Récompenses" (catalogue de badges) retiré du menu admin pour
      // l'instant — demande explicite, cf. student_home.dart.
      // Bibliothèque désactivée temporairement (demande explicite) — à
      // réactiver plus tard. Ne pas supprimer LibrarySubmissionPage.
      // RoleNavEntry(icon: Icons.local_library_outlined, activeIcon: Icons.local_library_rounded,
      //     labelKey: 'Bibliothèque',
      //     page: PermissionGuard(permission: StaffPermissions.library, child: LibrarySubmissionPage()),
      //     permission: StaffPermissions.library),
    ]),
    RoleNavGroup(labelKey: 'sections.account', entries: [
      // Pas de centre de notifications : la messagerie et les annonces ont été
      // retirées (décision utilisateur). Elles étaient aussi le dernier trou de
      // la RLS — un élève pouvait écrire au nom d'un autre.
      RoleNavEntry(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded,
          labelKey: 'nav.school',
          page: PermissionGuard(permission: StaffPermissions.schoolConfig, child: AdminSchoolPage()),
          permission: StaffPermissions.schoolConfig),
      RoleNavEntry(icon: Icons.account_tree_outlined, activeIcon: Icons.account_tree_rounded,
          labelKey: 'Rôles & permissions',
          page: PermissionGuard(permission: StaffPermissions.staffManage, child: RolesPermissionsPage()),
          permission: StaffPermissions.staffManage),
      // Profil accessible uniquement via l'avatar de l'app bar (mobile) —
      // plus de doublon dans le drawer.
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);

    // Pas de configuration préalable des rôles : le fondateur entre directement
    // dans son tableau de bord. Les rôles de l'école se créent au fil des
    // invitations (users_page → choix d'un modèle) et se règlent après coup
    // depuis « Rôles & permissions ». Cf. RoleSetupScreen, conservé mais plus
    // branché en écran bloquant.

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
            const SizedBox(height: 14),
            const _PlatformAnnouncementBanner(),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (_, c) {
              if (c.maxWidth < 580) {
                return Column(children: [
                  _DashQuickActions(),
                  const SizedBox(height: 16),
                  const _DashKpiRow(),
                  const SizedBox(height: 16),
                  _DashToday(),
                  const SizedBox(height: 16),
                  const _DashActivity(),
                ]);
              }
              return Column(children: [
                const _DashKpiRow(),
                const SizedBox(height: 20),
                Row(
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
                ),
              ]);
            }),
          ],
        ),
      ),
    );
  }
}

/// Annonce plateforme (Scolaris → écoles) concernant l'école courante —
/// maintenance, nouveauté, rappel d'essai/impayé. Masquage persisté
/// localement (cf. `dismissedAnnouncementIdsProvider`) : ne réapparaît plus
/// une fois masquée sur cet appareil.
class _PlatformAnnouncementBanner extends ConsumerWidget {
  const _PlatformAnnouncementBanner();

  Color _colorOf(String kind) => switch (kind) {
        'maintenance' => _orange,
        'feature' => _green,
        _ => ScolarisAccents.sapphire,
      };

  IconData _iconOf(String kind) => switch (kind) {
        'maintenance' => Icons.build_rounded,
        'feature' => Icons.auto_awesome_rounded,
        _ => Icons.campaign_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(myPlatformAnnouncementsProvider);
    final dismissed = ref.watch(dismissedAnnouncementIdsProvider);
    final items = announcementsAsync.valueOrNull ?? const [];
    final visible = items.where((a) => !dismissed.contains(a.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final a = visible.first;
    final color = _colorOf(a.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_iconOf(a.kind), size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(a.body,
                  style: TextStyle(
                      color: _DashColors.of(context).muted, fontSize: 12, height: 1.35)),
            ]),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => ref
                .read(dismissedAnnouncementIdsProvider.notifier)
                .dismiss(a.id),
            icon: const Icon(Icons.close_rounded, size: 16),
            color: _DashColors.of(context).muted,
            tooltip: 'Masquer',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ]),
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
    final c = _DashColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greet, $name',
              style: TextStyle(
                  color: c.ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.4)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.grid_view_rounded, size: 12, color: c.muted),
            const SizedBox(width: 5),
            Text('Tableau de bord — Administration',
                style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ])),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: c.muted),
            const SizedBox(width: 6),
            Text(date, style: TextStyle(
                color: c.ink, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
    final teachers = ref.watch(teachersProvider);
    final subjects = ref.watch(subjectsProvider);

    String n(AsyncValue<int> v) =>
        v.maybeWhen(data: (d) => '$d', orElse: () => '—');
    String len(AsyncValue<List> v) =>
        v.maybeWhen(data: (d) => '${d.length}', orElse: () => '—');

    final loadingAny = students.isLoading ||
        classes.isLoading ||
        teachers.isLoading ||
        subjects.isLoading;

    final kpis = <(IconData, String, String, Color)>[
      (Icons.people_alt_rounded, 'Élèves inscrits', n(students), _terra),
      (Icons.class_rounded, 'Classes actives', len(classes), _orange),
      (Icons.co_present_rounded, 'Enseignants', len(teachers), _green),
      (Icons.menu_book_rounded, 'Matières', len(subjects), _gold),
    ];

    Widget card(int i) =>
        _DashKpiCard(kpi: kpis[i], loading: loadingAny);

    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth < 500) {
        // Bande horizontale scrollable : libère la hauteur verticale sur
        // mobile plutôt qu'une grille 2×2 qui repousse le contenu utile.
        // Fondu en bord droit : signale qu'il reste des cartes à découvrir.
        final bg = Theme.of(context).scaffoldBackgroundColor;
        return SizedBox(
          height: 92,
          child: Stack(children: [
            ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kpis.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: 132, child: card(i)),
            ),
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [bg.withValues(alpha: 0), bg.withValues(alpha: .9)],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
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
    final c = _DashColors.of(context);
    final (icon, label, value, accent) = kpi;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : const [BoxShadow(
                color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: accent),
          ),
        ]),
        const SizedBox(height: 10),
        if (loading)
          Container(height: 20, width: 60, decoration: BoxDecoration(
              color: c.skeleton, borderRadius: BorderRadius.circular(5)))
        else
          Text(value, style: TextStyle(
              color: accent, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.3)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            color: c.muted, fontSize: 11, fontWeight: FontWeight.w500)),
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
    final c = _DashColors.of(context);
    final recent = ref.watch(recentStudentsProvider);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(children: [
            Icon(Icons.timeline_rounded, size: 15, color: c.muted),
            const SizedBox(width: 7),
            Text('Dernières inscriptions',
                style: TextStyle(color: c.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        Divider(height: 1, color: c.divider),
        recent.when(
          loading: () => Column(
              children: List.generate(3, (_) => const _ActivitySkeleton())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Activité indisponible.',
                style: TextStyle(color: c.muted, fontSize: 12)),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                      'Aucune inscription pour le moment. Ajoutez un élève depuis Utilisateurs.',
                      style: TextStyle(color: c.muted, fontSize: 12.5)),
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
    final sk = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(
            color: sk, borderRadius: BorderRadius.circular(9))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 11, width: 140, decoration: BoxDecoration(
              color: sk, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(height: 9, width: 90, decoration: BoxDecoration(
              color: sk, borderRadius: BorderRadius.circular(4))),
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
    final c = _DashColors.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: .14))),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: c.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(sub, style: TextStyle(color: c.muted, fontSize: 11.5)),
          ])),
          Text(time, style: TextStyle(color: c.muted, fontSize: 11)),
        ]),
      ),
      if (!last) Divider(height: 1, indent: 62, color: c.divider),
    ]);
  }
}

// ── Quick actions panel ───────────────────────────────────────────────────────
class _DashQuickActions extends ConsumerWidget {
  // (icône, libellé, couleur, labelKey de nav cible, permission requise).
  // Le labelKey DOIT correspondre exactement à une entrée de `_allGroups`,
  // sinon l'intention de nav tombe dans le vide (indexWhere == -1).
  static const _actions = [
    (Icons.person_add_rounded, 'Inscrire un élève',  _terra,            'Élèves & familles', StaffPermissions.students),
    (Icons.class_rounded,      'Gérer les classes',  _orange,           'nav.classes',       StaffPermissions.classes),
    (Icons.menu_book_rounded,  'Gérer les matières', _green,            'nav.subjects',      StaffPermissions.classes),
    (Icons.summarize_rounded,  'Voir les rapports',  _gold,             'nav.reports',       StaffPermissions.reports),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _DashColors.of(context);
    final user = ref.watch(authSessionProvider);

    // Mêmes règles que le menu : on ne propose que les actions dont la page
    // cible est accessible au membre connecté. Panneau masqué si aucune.
    final actions = _actions.where((a) => user?.can(a.$5) ?? false).toList();
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.bolt_rounded, size: 15, color: c.muted),
            const SizedBox(width: 7),
            Text('Actions rapides',
                style: TextStyle(color: c.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        Divider(height: 1, color: c.divider),
        ...List.generate(actions.length, (i) {
          final a = actions[i];
          return Column(children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: i == actions.length - 1
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
                          color: a.$3.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(a.$1, size: 14, color: a.$3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.$2,
                        style: TextStyle(
                            color: c.ink, fontSize: 12.5, fontWeight: FontWeight.w500))),
                    Icon(Icons.chevron_right_rounded, size: 15,
                        color: c.muted.withValues(alpha: .5)),
                  ]),
                ),
              ),
            ),
            if (i < actions.length - 1)
              Divider(height: 1, indent: 58, color: c.divider),
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
      data: (list) => list.where((inv) => inv.isLate).length,
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
          overdue == 0
              ? 'Aucune facture en retard'
              : fmt(overdue, 'facture en retard', 'factures en retard')),
    ];

    final c = _DashColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.today_rounded, size: 15, color: c.muted),
            const SizedBox(width: 7),
            Text("Aujourd'hui",
                style: TextStyle(color: c.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        Divider(height: 1, color: c.divider),
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
                      color: it.$2.withValues(alpha: .55), shape: BoxShape.circle),
                ),
                Icon(it.$1, size: 13, color: it.$2),
                const SizedBox(width: 8),
                Expanded(child: Text(it.$3,
                    style: TextStyle(color: c.ink, fontSize: 12))),
              ]),
            ),
            if (i < items.length - 1)
              Divider(height: 1, indent: 30, color: c.divider),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}
