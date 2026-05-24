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
    final user = ref.watch(authSessionProvider);
    final firstName = user?.fullName.split(' ').first ?? 'Admin';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting banner ─────────────────────────────────────────
            _AdminGreeting(greeting: _greeting, name: firstName, loading: _loading),
            const SizedBox(height: 20),

            // ── KPI row ──────────────────────────────────────────────────
            Row(children: [
              Expanded(child: _KpiCard(icon: Icons.people_rounded,
                  label: 'Élèves', value: '248', color: _terra, loading: _loading)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.class_rounded,
                  label: 'Classes', value: '18', color: _orange, loading: _loading)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.account_balance_wallet_rounded,
                  label: 'Revenus', value: '24 580 F', color: _green, loading: _loading)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(icon: Icons.warning_amber_rounded,
                  label: 'Impayés', value: '3', color: _gold, loading: _loading)),
            ]),
            const SizedBox(height: 22),

            // ── Quick actions ─────────────────────────────────────────────
            const _SectionHeader(title: 'Actions rapides'),
            const SizedBox(height: 10),
            _QuickActions(),
            const SizedBox(height: 22),

            // ── Recent activity ───────────────────────────────────────────
            const _SectionHeader(title: 'Activité récente'),
            const SizedBox(height: 10),
            if (_loading) ...[
              const SkeletonListRow(),
              const SizedBox(height: 8),
              const SkeletonListRow(),
              const SizedBox(height: 8),
              const SkeletonListRow(),
            ] else ...[
              _ActivityRow(icon: Icons.person_add_rounded, color: _terra,
                  title: 'Nouvelle inscription', subtitle: 'Amara Diallo — Terminale S', time: '09:14'),
              const SizedBox(height: 8),
              _ActivityRow(icon: Icons.payments_rounded, color: _green,
                  title: 'Paiement reçu', subtitle: 'Ada Lovelace — 320 F', time: '08:40'),
              const SizedBox(height: 8),
              _ActivityRow(icon: Icons.warning_amber_rounded, color: _gold,
                  title: 'Facture en retard', subtitle: 'Fatou Diallo — 320 F', time: 'Hier'),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Admin Greeting ──────────────────────────────────────────────────────────
class _AdminGreeting extends StatelessWidget {
  final String greeting;
  final String name;
  final bool loading;
  const _AdminGreeting({required this.greeting, required this.name, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0A00), Color(0xFF3E1A00), _terra],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: _terra.withOpacity(.2), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _white.withOpacity(.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('ADMINISTRATEUR',
                style: TextStyle(color: _white, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          const SizedBox(height: 8),
          Text('$greeting, $name 👋',
              style: const TextStyle(color: _white, fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Bienvenue sur votre tableau de bord',
              style: TextStyle(color: Color(0xFFE8C8B0), fontSize: 12.5)),
        ])),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _white.withOpacity(.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: _white, size: 32),
        ),
      ]),
    );
  }
}

// ── KPI Card ────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool loading;
  const _KpiCard({required this.icon, required this.label,
      required this.value, required this.color, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0C000000),
            blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _muted, fontSize: 10,
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        if (loading)
          const SkeletonBox(width: 50, height: 16, radius: 4)
        else
          Text(value, style: TextStyle(color: color, fontSize: 15,
              fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 15,
          fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Quick Actions ───────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.person_add_rounded, 'Inscrire élève', _terra),
      (Icons.class_rounded, 'Gérer classes', _orange),
      (Icons.print_rounded, 'Imprimer reçu', _green),
      (Icons.summarize_rounded, 'Rapport', _gold),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: actions.indexOf(a) < 3
                  ? const EdgeInsets.only(right: 10)
                  : EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEE5D8)),
                boxShadow: const [BoxShadow(color: Color(0x0A000000),
                    blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: a.$3.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.$1, color: a.$3, size: 20),
                ),
                const SizedBox(height: 8),
                Text(a.$2, textAlign: TextAlign.center,
                    style: TextStyle(color: a.$3, fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Activity Row ─────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityRow({required this.icon, required this.color,
      required this.title, required this.subtitle, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEE5D8)),
      ),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _ink, fontSize: 13,
              fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        Text(time, style: const TextStyle(color: _muted, fontSize: 11)),
      ]),
    );
  }
}
