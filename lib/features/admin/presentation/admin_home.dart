import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import 'pages/enrollment_config_page.dart';
import 'pages/notification_center_page.dart';
import 'pages/timetable_page.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/skeleton.dart';
import 'pages/admin_billing_page.dart';
import 'pages/admin_classes_page.dart';
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

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.staff,
      title: 'Scolaris',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(icon: Icons.home_rounded, activeIcon: Icons.home_rounded,
              labelKey: 'nav.dashboard', page: _AdminDashboard()),
          RoleNavEntry(icon: Icons.group_outlined, activeIcon: Icons.group_rounded,
              labelKey: 'nav.users', page: UsersPage()),
          RoleNavEntry(icon: Icons.class_outlined, activeIcon: Icons.class_rounded,
              labelKey: 'nav.classes', page: AdminClassesPage()),
          RoleNavEntry(icon: Icons.how_to_reg_outlined, activeIcon: Icons.how_to_reg_rounded,
              labelKey: 'nav.enrollment', page: EnrollmentConfigPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded,
              labelKey: 'nav.billing', page: AdminBillingPage()),
          RoleNavEntry(icon: Icons.summarize_outlined, activeIcon: Icons.summarize_rounded,
              labelKey: 'nav.reports', page: AdminReportsPage()),
          RoleNavEntry(icon: Icons.table_chart_outlined, activeIcon: Icons.table_chart_rounded,
              labelKey: 'nav.timetable', page: TimetablePage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(icon: Icons.campaign_outlined, activeIcon: Icons.campaign_rounded,
              labelKey: 'nav.notifications', page: NotificationCenterPage()),
          RoleNavEntry(icon: Icons.apps_outlined, activeIcon: Icons.apps_rounded,
              labelKey: 'nav.features', page: FeaturesHubPage()),
        ]),
      ],
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _loading = false); });
  }

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
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashGreeting(greet: _greet, name: firstName, date: _todayStr),
            const SizedBox(height: 20),
            _DashKpiRow(loading: _loading),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (_, c) {
              if (c.maxWidth < 580) {
                return Column(children: [
                  _DashQuickActions(),
                  const SizedBox(height: 16),
                  _DashActivity(loading: _loading),
                  const SizedBox(height: 16),
                  _DashToday(),
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _DashActivity(loading: _loading)),
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

// ── KPI row ──────────────────────────────────────────────────────────────────
class _DashKpiRow extends StatelessWidget {
  final bool loading;
  const _DashKpiRow({required this.loading});

  static const _kpis = [
    (Icons.people_alt_rounded, 'Élèves inscrits', '248', '+12', true,  _terra),
    (Icons.class_rounded,      'Classes actives', '18',  '+1',  true,  _orange),
    (Icons.account_balance_wallet_rounded, 'Revenus (mois)', '24 580 F', '+8 %', true, _green),
    (Icons.warning_amber_rounded, 'Impayés',        '3',   '-2',  false, _gold),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth < 500) {
        return Column(children: [
          Row(children: [
            Expanded(child: _DashKpiCard(kpi: _kpis[0], loading: loading)),
            const SizedBox(width: 10),
            Expanded(child: _DashKpiCard(kpi: _kpis[1], loading: loading)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DashKpiCard(kpi: _kpis[2], loading: loading)),
            const SizedBox(width: 10),
            Expanded(child: _DashKpiCard(kpi: _kpis[3], loading: loading)),
          ]),
        ]);
      }
      return Row(children: _kpis.indexed.map((e) {
        final (i, kpi) = e;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
          child: _DashKpiCard(kpi: kpi, loading: loading),
        ));
      }).toList());
    });
  }
}

class _DashKpiCard extends StatelessWidget {
  final (IconData, String, String, String, bool, Color) kpi;
  final bool loading;
  const _DashKpiCard({required this.kpi, required this.loading});

  @override
  Widget build(BuildContext context) {
    final (icon, label, value, trend, up, accent) = kpi;
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
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (up ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C)).withOpacity(.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 10,
                  color: up ? const Color(0xFF388E3C) : const Color(0xFFD32F2F)),
              const SizedBox(width: 2),
              Text(trend, style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700,
                  color: up ? const Color(0xFF388E3C) : const Color(0xFFD32F2F))),
            ]),
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

// ── Activity feed ────────────────────────────────────────────────────────────
class _DashActivity extends StatelessWidget {
  final bool loading;
  const _DashActivity({required this.loading});

  static const _feed = [
    (Icons.person_add_rounded,      _terra,               'Nouvelle inscription',    'Amara Diallo — Terminale S',       '09:14'),
    (Icons.payments_rounded,        Color(0xFF388E3C),    'Paiement reçu',           'Ada Lovelace — 320 F',             '08:40'),
    (Icons.warning_amber_rounded,   Color(0xFFC17F24),   'Facture en retard',       'Fatou Diallo — 320 F',             'Hier'),
    (Icons.how_to_reg_rounded,      _orange,              'Pré-inscription validée', 'Mohamed Coulibaly — 2nde',         'Hier'),
    (Icons.print_rounded,           Color(0xFF5D4037),   'Reçu imprimé',            '3 copies — Classe 4ème B',         'Hier'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD0C4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(children: [
            const Icon(Icons.timeline_rounded, size: 15, color: _muted),
            const SizedBox(width: 7),
            const Text('Activité récente',
                style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Voir tout',
                  style: TextStyle(color: _terra, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFEEE5D8)),
        if (loading)
          ...List.generate(3, (_) => const _ActivitySkeleton())
        else
          ...List.generate(_feed.length, (i) => _ActivityItem(
            icon:  _feed[i].$1,
            color: _feed[i].$2,
            title: _feed[i].$3,
            sub:   _feed[i].$4,
            time:  _feed[i].$5,
            last:  i == _feed.length - 1,
          )),
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
class _DashQuickActions extends StatelessWidget {
  static const _actions = [
    (Icons.person_add_rounded, 'Inscrire un élève',   _terra),
    (Icons.class_rounded,      'Gérer les classes',    _orange),
    (Icons.print_rounded,      'Imprimer un reçu',     Color(0xFF388E3C)),
    (Icons.summarize_rounded,  'Générer un rapport',   _gold),
  ];

  @override
  Widget build(BuildContext context) {
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
                onTap: () {},
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
class _DashToday extends StatelessWidget {
  static const _items = [
    (Icons.person_add_outlined,     '2 nouvelles inscriptions'),
    (Icons.payments_outlined,       '5 paiements validés'),
    (Icons.assignment_late_outlined,'1 réunion pédagogique'),
    (Icons.event_note_outlined,     'Examen Terminale — 14:00'),
  ];

  @override
  Widget build(BuildContext context) {
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
        ...List.generate(_items.length, (i) {
          final it = _items[i];
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: _terra.withOpacity(.55), shape: BoxShape.circle),
                ),
                Icon(it.$1, size: 13, color: _muted),
                const SizedBox(width: 8),
                Expanded(child: Text(it.$2,
                    style: const TextStyle(color: _ink, fontSize: 12))),
              ]),
            ),
            if (i < _items.length - 1)
              const Divider(height: 1, indent: 30, color: Color(0xFFEEE5D8)),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}
