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

const _terra = ScolarisPalette.terracotta;
const _green = ScolarisPalette.forestGreen;
const _gold  = ScolarisPalette.gold;
const _white = Colors.white;

// ── Shell ─────────────────────────────────────────────────────────────────────
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

// ── Dashboard ─────────────────────────────────────────────────────────────────
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
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(authSessionProvider);
    final firstName = user?.fullName.split(' ').first ?? 'Admin';
    final cs        = Theme.of(context).colorScheme;

    final leftContent = <Widget>[
      _AdminGreeting(greeting: _greeting, name: firstName, loading: _loading),
      const SizedBox(height: 16),
      _Label('Vue d\'ensemble', cs),
      const SizedBox(height: 10),
      _KpiGrid(loading: _loading),
      const SizedBox(height: 16),
      _Label('Actions rapides', cs),
      const SizedBox(height: 10),
      const _QuickActions(),
    ];

    final rightContent = <Widget>[
      _Label('Activité récente', cs),
      const SizedBox(height: 10),
      if (_loading) ...[
        const SkeletonListRow(),
        const SizedBox(height: 8),
        const SkeletonListRow(),
        const SizedBox(height: 8),
        const SkeletonListRow(),
      ] else ...[
        _ActivityRow(icon: Icons.person_add_rounded, color: _terra,
            title: 'Nouvelle inscription', subtitle: 'Amara Diallo — Tle S', time: '09:14'),
        const SizedBox(height: 8),
        _ActivityRow(icon: Icons.payments_rounded, color: _green,
            title: 'Paiement reçu', subtitle: 'Ada Lovelace — 85 000 F', time: '08:40'),
        const SizedBox(height: 8),
        _ActivityRow(icon: Icons.warning_amber_rounded, color: _gold,
            title: 'Facture en retard', subtitle: 'Fatou Diallo — 45 000 F', time: 'Hier'),
        const SizedBox(height: 8),
        _ActivityRow(icon: Icons.class_rounded, color: _terra,
            title: 'Classe créée', subtitle: '2nde B — 32 élèves', time: 'Hier'),
      ],
    ];

    return Container(
      color: cs.surfaceContainerLowest,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth >= 680;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 20, 16, isWide ? 20 : 100),
            child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: leftContent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 88),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rightContent,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [...leftContent, const SizedBox(height: 22), ...rightContent],
                ),
          );
        },
      ),
    );
  }
}

// ── Greeting ──────────────────────────────────────────────────────────────────
class _AdminGreeting extends StatelessWidget {
  final String greeting;
  final String name;
  final bool loading;
  const _AdminGreeting({required this.greeting, required this.name, required this.loading});

  static String _todayDate() {
    final now = DateTime.now();
    const months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    const days   = ['Dim','Lun','Mar','Mer','Jeu','Ven','Sam'];
    return '${days[now.weekday % 7]} ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0A00), Color(0xFF3E1A00), _terra],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: _terra.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('ADMINISTRATEUR',
                style: TextStyle(color: _white, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          ),
          const SizedBox(height: 8),
          loading
              ? const SkeletonBox(width: 160, height: 20, radius: 6)
              : Text('$greeting, $name',
                  style: const TextStyle(color: _white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(_todayDate(),
              style: const TextStyle(color: Color(0xFFE8C8B0), fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: _white, size: 28),
        ),
      ]),
    );
  }
}

// ── KPI Grid 2×2 ─────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final bool loading;
  const _KpiGrid({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _KpiCard(
          icon: Icons.people_rounded, label: 'Élèves inscrits',
          value: '248', sub: '↑ 3 ce mois', color: _terra, loading: loading)),
        const SizedBox(width: 10),
        Expanded(child: _KpiCard(
          icon: Icons.class_rounded, label: 'Classes actives',
          value: '18', sub: '4 niveaux · 3 filières', color: _terra, loading: loading)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _KpiCard(
          icon: Icons.account_balance_wallet_rounded, label: 'Revenus du mois',
          value: '24 580 F', sub: '↑ +4.2 % vs préc.', color: _green, loading: loading)),
        const SizedBox(width: 10),
        Expanded(child: _KpiCard(
          icon: Icons.warning_amber_rounded, label: 'Factures impayées',
          value: '3', sub: '45 000 F en attente', color: _gold, loading: loading)),
      ]),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool loading;
  const _KpiCard({
    required this.icon, required this.label, required this.value,
    required this.sub, required this.color, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 17)),
        const SizedBox(height: 12),
        loading
            ? const SkeletonBox(width: 60, height: 20, radius: 4)
            : Text(value, style: TextStyle(
                color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(
            color: color.withValues(alpha: 0.85), fontSize: 10.5, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _Label(this.text, this.cs);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: cs.onSurface, fontSize: 14,
          fontWeight: FontWeight.w700, letterSpacing: 0.1));
}

// ── Quick Actions (2×2) ───────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const actions = [
      (Icons.person_add_rounded,   'Inscrire un élève',   _terra),
      (Icons.class_rounded,         'Gérer les classes',   _terra),
      (Icons.print_rounded,         'Imprimer un reçu',    _green),
      (Icons.summarize_rounded,     'Générer un rapport',  _green),
    ];
    return Column(children: [
      Row(children: [
        Expanded(child: _ActionBtn(actions[0], cs)),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(actions[1], cs)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _ActionBtn(actions[2], cs)),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(actions[3], cs)),
      ]),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final (IconData, String, Color) action;
  final ColorScheme cs;
  const _ActionBtn(this.action, this.cs);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: action.$3.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9)),
            child: Icon(action.$1, color: action.$3, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(action.$2,
              style: TextStyle(color: cs.onSurface, fontSize: 12,
                  fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

// ── Activity Row ──────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityRow({
    required this.icon, required this.color,
    required this.title, required this.subtitle, required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
              color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(subtitle, style: TextStyle(
              color: cs.onSurfaceVariant, fontSize: 11)),
        ])),
        Text(time, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
      ]),
    );
  }
}
