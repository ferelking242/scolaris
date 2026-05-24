import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/settings_page.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/skeleton.dart';
import 'pages/children_page.dart';
import 'pages/messages_page.dart';
import 'pages/parent_payments_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _white  = Colors.white;
const _bg     = Color(0xFFF5EEE6);

class ParentHome extends StatelessWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveRoleShell(
      role: UserRole.parent,
      title: 'Scolaris',
      groups: const [
        RoleNavGroup(labelKey: 'sections.setup', entries: [
          RoleNavEntry(icon: Icons.home_rounded, activeIcon: Icons.home_rounded,
              labelKey: 'nav.dashboard', page: _ParentDashboard()),
          RoleNavEntry(icon: Icons.family_restroom_outlined,
              activeIcon: Icons.family_restroom_rounded,
              labelKey: 'nav.children', page: ChildrenPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.activity', entries: [
          RoleNavEntry(icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded,
              labelKey: 'nav.payments', page: ParentPaymentsPage()),
          RoleNavEntry(icon: Icons.message_outlined, activeIcon: Icons.message_rounded,
              labelKey: 'nav.messages', page: MessagesPage()),
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

class _ParentDashboard extends ConsumerStatefulWidget {
  const _ParentDashboard();
  @override
  ConsumerState<_ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<_ParentDashboard> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
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
    final firstName = user?.fullName.split(' ').first ?? 'Parent';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ─────────────────────────────────────────
            _ParentGreeting(greeting: _greeting, name: firstName),
            const SizedBox(height: 20),

            // ── Summary pills ─────────────────────────────────────
            Row(children: [
              Expanded(child: _SummaryPill(icon: Icons.family_restroom_rounded,
                  label: 'Enfants', value: '2', color: _terra, loading: _loading)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryPill(icon: Icons.notifications_active_rounded,
                  label: 'Alertes', value: '1', color: _orange, loading: _loading)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryPill(icon: Icons.receipt_long_rounded,
                  label: 'Impayés', value: '1', color: _gold, loading: _loading)),
            ]),
            const SizedBox(height: 22),

            // ── Children cards ────────────────────────────────────
            _SectionHeader(title: 'Mes enfants', action: 'Détails', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading) ...[
              const _SkeletonChildCard(),
              const SizedBox(height: 10),
              const _SkeletonChildCard(),
            ] else ...[
              _ChildCard(
                name: 'Amara Keita',
                grade: 'Terminale S',
                avg: 15.4,
                attendance: 96,
                feeStatus: 'Payé',
                feeColor: _green,
                avatar: 'AK',
                color: _terra,
              ),
              const SizedBox(height: 10),
              _ChildCard(
                name: 'Fatou Keita',
                grade: '3ème A',
                avg: 13.2,
                attendance: 89,
                feeStatus: 'En attente',
                feeColor: _orange,
                avatar: 'FK',
                color: _gold,
              ),
            ],
            const SizedBox(height: 22),

            // ── Alerts ───────────────────────────────────────────
            _SectionHeader(title: 'Alertes récentes', action: 'Tout voir', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading)
              const SkeletonListRow()
            else ...[
              _AlertCard(
                icon: Icons.payments_outlined,
                title: 'Frais de scolarité en attente',
                subtitle: 'Fatou Keita · Échéance le 15 mai',
                color: _orange,
              ),
              const SizedBox(height: 8),
              _AlertCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Paiement confirmé',
                subtitle: 'Amara Keita · 28 Avr 2026',
                color: _green,
              ),
            ],
            const SizedBox(height: 22),

            // ── Messages ─────────────────────────────────────────
            _SectionHeader(title: 'Messages récents', action: 'Tout voir', onAction: () {}),
            const SizedBox(height: 10),
            if (_loading) ...[
              const SkeletonListRow(),
              const SizedBox(height: 8),
              const SkeletonListRow(),
            ] else ...[
              _MessageRow(
                sender: 'M. Diallo',
                role: 'Mathématiques',
                preview: 'Amara a eu d\'excellents résultats ce trimestre...',
                time: '09:30',
                unread: true,
              ),
              const SizedBox(height: 8),
              _MessageRow(
                sender: 'Direction',
                role: 'Administratif',
                preview: 'Réunion parents-professeurs le 10 mai 2026.',
                time: 'Hier',
                unread: false,
              ),
            ],
            const SizedBox(height: 22),

            // ── Quick actions ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A0A00), _terra],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Actions rapides',
                    style: TextStyle(color: _white, fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _QuickAction(icon: Icons.payment_rounded,
                      label: 'Payer les frais', color: _gold, onTap: () {})),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.message_rounded,
                      label: 'Contacter prof', color: _white, onTap: () {})),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.calendar_today_rounded,
                      label: 'Agenda', color: _gold, onTap: () {})),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Greeting ───────────────────────────────────────────────────────────────
class _ParentGreeting extends StatelessWidget {
  final String greeting;
  final String name;
  const _ParentGreeting({required this.greeting, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E1A00), _terra],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greeting, $name 👋',
              style: const TextStyle(color: _white, fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Restez informé de la scolarité de vos enfants',
              style: TextStyle(color: Color(0xFFE8C8B0), fontSize: 12, height: 1.4)),
        ])),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset('assets/images/logo.png', width: 52, height: 52,
              errorBuilder: (_, __, ___) => Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.family_restroom_rounded,
                    color: _white, size: 30),
              )),
        ),
      ]),
    );
  }
}

// ── Summary Pill ───────────────────────────────────────────────────────────
class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool loading;
  const _SummaryPill({required this.icon, required this.label,
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
          decoration: BoxDecoration(color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _muted, fontSize: 10,
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        if (loading) const SkeletonBox(width: 28, height: 16, radius: 4)
        else Text(value, style: TextStyle(color: color, fontSize: 15,
            fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Child Card ─────────────────────────────────────────────────────────────
class _ChildCard extends StatelessWidget {
  final String name, grade, feeStatus, avatar;
  final double avg, attendance;
  final Color feeColor, color;
  const _ChildCard({
    required this.name, required this.grade,
    required this.avg, required this.attendance,
    required this.feeStatus, required this.feeColor,
    required this.avatar, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE5D8)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000),
            blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(.6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(avatar,
                style: const TextStyle(color: _white, fontWeight: FontWeight.w800,
                    fontSize: 14))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: _ink, fontSize: 14,
                fontWeight: FontWeight.w700)),
            Text(grade, style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: feeColor.withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: feeColor.withOpacity(.3)),
            ),
            child: Text(feeStatus,
                style: TextStyle(color: feeColor, fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MiniStat(label: 'Moyenne',
              value: '${avg.toStringAsFixed(1)}/20', color: _gold)),
          Container(width: 1, height: 30, color: const Color(0xFFEEE5D8)),
          Expanded(child: _MiniStat(label: 'Présence',
              value: '${attendance.toStringAsFixed(0)}%', color: _green)),
          Container(width: 1, height: 30, color: const Color(0xFFEEE5D8)),
          Expanded(child: _MiniStat(label: 'Cours', value: '7', color: _terra)),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    ]);
  }
}

class _SkeletonChildCard extends StatelessWidget {
  const _SkeletonChildCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(children: const [
          SkeletonBox(width: 44, height: 44, radius: 12),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 120, height: 14, radius: 4),
            SizedBox(height: 6),
            SkeletonBox(width: 80, height: 10, radius: 4),
          ])),
          SkeletonBox(width: 60, height: 26, radius: 8),
        ]),
        const SizedBox(height: 14),
        const Row(children: [
          Expanded(child: SkeletonBox(width: double.infinity, height: 40, radius: 8)),
          SizedBox(width: 10),
          Expanded(child: SkeletonBox(width: double.infinity, height: 40, radius: 8)),
          SizedBox(width: 10),
          Expanded(child: SkeletonBox(width: double.infinity, height: 40, radius: 8)),
        ]),
      ]),
    );
  }
}

// ── Alert Card ─────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _AlertCard({required this.icon, required this.title,
      required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10)),
          child: Center(child: Icon(icon, color: color, size: 18)),
        ),
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

// ── Message Row ────────────────────────────────────────────────────────────
class _MessageRow extends StatelessWidget {
  final String sender, role, preview, time;
  final bool unread;
  const _MessageRow({required this.sender, required this.role,
      required this.preview, required this.time, required this.unread});

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
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _terra.withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(sender.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: _terra, fontWeight: FontWeight.w800,
                  fontSize: 16))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(sender, style: const TextStyle(color: _ink, fontSize: 12,
                fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('· $role', style: const TextStyle(color: _muted, fontSize: 11)),
          ]),
          Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _muted, fontSize: 11,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.normal)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(time, style: const TextStyle(color: _muted, fontSize: 10)),
          if (unread) ...[
            const SizedBox(height: 4),
            Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle)),
          ],
        ]),
      ]),
    );
  }
}

// ── Quick Action ───────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _white.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
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
