import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/settings_page.dart';
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
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded,
              labelKey: 'nav.billing', page: AdminBillingPage()),
          RoleNavEntry(icon: Icons.summarize_outlined, activeIcon: Icons.summarize_rounded,
              labelKey: 'nav.reports', page: AdminReportsPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(icon: Icons.apps_outlined, activeIcon: Icons.apps_rounded,
              labelKey: 'nav.features', page: FeaturesHubPage()),
          RoleNavEntry(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded,
              labelKey: 'common.settings', page: SettingsPage()),
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
    Future.delayed(const Duration(milliseconds: 1600), () {
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
            // ── Admin header ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A0A00), ScolarisPalette.terracotta],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_greeting, $firstName',
                        style: const TextStyle(color: _white, fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('Vue d\'ensemble de l\'établissement',
                        style: TextStyle(color: Color(0xFFB8D4C0), fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _AdminBadge(label: 'ADMINISTRATEUR', color: _gold),
                      const SizedBox(width: 8),
                      _AdminBadge(label: '● EN LIGNE', color: const Color(0xFF4ADE80)),
                    ]),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _white.withOpacity(.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: _white, size: 32),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── KPI Grid ─────────────────────────────────────────
            const Text('Indicateurs clés',
                style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_loading)
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: const [
                  SkeletonStatCard(), SkeletonStatCard(),
                  SkeletonStatCard(), SkeletonStatCard(),
                ],
              )
            else
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: const [
                  _KpiCard(icon: Icons.group_rounded, label: 'Utilisateurs',
                      value: '1 284', trend: '+8 cette semaine', trendPos: true,
                      color: _terra),
                  _KpiCard(icon: Icons.class_rounded, label: 'Classes',
                      value: '42', trend: 'Stable', trendPos: true,
                      color: _gold),
                  _KpiCard(icon: Icons.account_balance_wallet_rounded, label: 'Revenus',
                      value: '24,5k €', trend: '+12% ce mois', trendPos: true,
                      color: _green),
                  _KpiCard(icon: Icons.health_and_safety_rounded, label: 'Présence',
                      value: '94%', trend: '-2% vs mois dernier', trendPos: false,
                      color: _orange),
                ],
              ),
            const SizedBox(height: 22),

            // ── Quick actions ─────────────────────────────────────
            const Text('Actions rapides',
                style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _AdminAction(icon: Icons.person_add_rounded,
                  label: 'Ajouter\nutilisateur', color: _terra, onTap: () {})),
              const SizedBox(width: 10),
              Expanded(child: _AdminAction(icon: Icons.add_chart_rounded,
                  label: 'Nouveau\nrapport', color: _gold, onTap: () {})),
              const SizedBox(width: 10),
              Expanded(child: _AdminAction(icon: Icons.send_rounded,
                  label: 'Notifier\ntous', color: _green, onTap: () {})),
              const SizedBox(width: 10),
              Expanded(child: _AdminAction(icon: Icons.settings_rounded,
                  label: 'Paramètres', color: _orange, onTap: () {})),
            ]),
            const SizedBox(height: 22),

            // ── Recent activity ───────────────────────────────────
            _SectionHeader(title: 'Activité récente', action: 'Tout voir', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading) ...[
              const SkeletonListRow(), const SizedBox(height: 8),
              const SkeletonListRow(), const SizedBox(height: 8),
              const SkeletonListRow(),
            ] else ...[
              _ActivityRow(icon: Icons.person_add_rounded,
                  title: 'Nouvel étudiant inscrit',
                  subtitle: 'Kofi Mensah · Terminale B · il y a 2h',
                  color: _terra),
              const SizedBox(height: 8),
              _ActivityRow(icon: Icons.payment_rounded,
                  title: 'Paiement reçu',
                  subtitle: '350 € · Famille Traoré · il y a 3h',
                  color: _green),
              const SizedBox(height: 8),
              _ActivityRow(icon: Icons.warning_amber_rounded,
                  title: 'Taux d\'absence élevé',
                  subtitle: 'Classe 4ème C · 18% absences · aujourd\'hui',
                  color: _orange),
              const SizedBox(height: 8),
              _ActivityRow(icon: Icons.class_rounded,
                  title: 'Nouvelle classe créée',
                  subtitle: 'Terminale D · 35 élèves · hier',
                  color: _gold),
            ],
            const SizedBox(height: 22),

            // ── System status ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEE5D8)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('État du système',
                    style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _StatusRow(label: 'Base de données', status: 'Opérationnelle', ok: true),
                const SizedBox(height: 6),
                _StatusRow(label: 'Synchronisation hors-ligne', status: 'Active', ok: true),
                const SizedBox(height: 6),
                _StatusRow(label: 'Notifications push', status: 'Opérationnelles', ok: true),
                const SizedBox(height: 6),
                _StatusRow(label: 'Sauvegardes', status: 'Dernière il y a 2h', ok: true),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _AdminBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label, value, trend;
  final bool trendPos;
  final Color color;
  const _KpiCard({required this.icon, required this.label,
      required this.value, required this.trend,
      required this.trendPos, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0A000000),
            blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
          const Spacer(),
          Icon(trendPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: trendPos ? _green : _orange, size: 14),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _ink, fontSize: 11,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(trend, style: TextStyle(
            color: trendPos ? _green : _orange, fontSize: 10)),
      ]),
    );
  }
}

class _AdminAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AdminAction({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.2)),
        ),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: _ink, fontSize: 9.5,
                  fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _ActivityRow({required this.icon, required this.title,
      required this.subtitle, required this.color});

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
          child: Center(child: Icon(icon, color: color, size: 18))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _ink, fontSize: 12,
              fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        Icon(Icons.chevron_right_rounded, color: _muted, size: 16),
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label, status;
  final bool ok;
  const _StatusRow({required this.label, required this.status, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(
              color: ok ? _green : _orange, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
      Text(status, style: TextStyle(color: ok ? _green : _orange, fontSize: 12,
          fontWeight: FontWeight.w600)),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title, action;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 15,
          fontWeight: FontWeight.w700)),
      const Spacer(),
      GestureDetector(onTap: onAction,
          child: Text(action, style: const TextStyle(color: _terra, fontSize: 12,
              fontWeight: FontWeight.w600))),
    ]);
  }
}
