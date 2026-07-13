import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/sources/remote/supabase_db_source.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../presentation/providers/db_providers.dart';
import '../../../shared/pages/features_hub_page.dart';
import '../../../shared/pages/messaging_page.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/responsive_role_shell.dart';
import '../../../shared/widgets/skeleton.dart';
import 'pages/child_detail_page.dart';
import 'pages/children_page.dart';
import 'pages/parent_payments_page.dart';

// Accents de marque — constants dans les deux thèmes.
const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _white  = Colors.white; // uniquement sur fond coloré

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
          RoleNavEntry(icon: Icons.chat_outlined, activeIcon: Icons.chat_rounded,
              labelKey: 'nav.messages', page: MessagingPage()),
        ]),
        RoleNavGroup(labelKey: 'sections.account', entries: [
          RoleNavEntry(icon: Icons.apps_outlined, activeIcon: Icons.apps_rounded,
              labelKey: 'nav.features', page: FeaturesHubPage()),
        ]),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Dashboard — dérivé des enfants réels du parent (`myChildrenProvider`).
// Aucune donnée fabriquée : tout ce qui s'affiche vient de la base.
// ══════════════════════════════════════════════════════════════════════════
class _ParentDashboard extends ConsumerWidget {
  const _ParentDashboard();

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(authSessionProvider);
    final firstName = user?.fullName.split(' ').first ?? 'Parent';

    final childrenAsync = ref.watch(myChildrenProvider);
    final children = childrenAsync.valueOrNull ?? const <SbStudent>[];
    final loading  = childrenAsync.isLoading;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _ParentGreeting(greeting: _greeting(), name: firstName),
          const SizedBox(height: 20),

          if (childrenAsync.hasError)
            _Notice(
              icon: Icons.error_outline_rounded,
              color: _terra,
              text: 'Impossible de charger vos enfants : '
                  '${childrenAsync.error}',
            )
          else if (!loading && children.isEmpty)
            const _Notice(
              icon: Icons.family_restroom_rounded,
              color: _orange,
              text: 'Aucun enfant n\'est rattaché à votre compte. '
                  'Contactez l\'établissement pour qu\'il fasse le lien.',
            )
          else ...[
            // ── Résumé, agrégé sur TOUS les enfants ────────────────────
            _ParentSummary(children: children, loading: loading),
            const SizedBox(height: 22),

            // ── Les enfants ────────────────────────────────────────────
            Row(children: [
              Text('Mes enfants', style: TextStyle(
                  color: context.cInk, fontSize: 15,
                  fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            if (loading) ...[
              const SkeletonListRow(),
              const SizedBox(height: 10),
              const SkeletonListRow(),
            ] else
              for (final c in children) ...[
                _ChildSummaryCard(child: c),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 12),

            // ── Ce qui demande attention ───────────────────────────────
            if (!loading) _AttentionSection(children: children),
          ],
        ]),
      ),
    );
  }
}

// ── Bandeau d'accueil ───────────────────────────────────────────────────────
class _ParentGreeting extends StatelessWidget {
  final String greeting, name;
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
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greeting, $name 👋',
              style: const TextStyle(color: _white, fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Restez informé de la scolarité de vos enfants',
              style: TextStyle(color: Color(0xFFE8C8B0),
                  fontSize: 12, height: 1.4)),
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

// ── Résumé : enfants / absences / impayés, agrégés sur la fratrie ───────────
class _ParentSummary extends ConsumerWidget {
  final List<SbStudent> children;
  final bool loading;
  const _ParentSummary({required this.children, required this.loading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var absences = 0;
    var unpaid   = 0;
    var pending  = loading;

    for (final c in children) {
      final a = ref.watch(absencesForStudentProvider(c.id));
      final i = ref.watch(invoicesForStudentProvider(c.id));
      if (a.isLoading || i.isLoading) pending = true;
      absences += (a.valueOrNull ?? const <SbAbsence>[]).length;
      unpaid += (i.valueOrNull ?? const <SbInvoice>[])
          .where((inv) => !inv.isPaid)
          .length;
    }

    return Row(children: [
      Expanded(child: _SummaryPill(
        icon: Icons.family_restroom_rounded, label: 'Enfants',
        value: '${children.length}', color: _terra, loading: loading,
      )),
      const SizedBox(width: 10),
      Expanded(child: _SummaryPill(
        icon: Icons.event_busy_rounded, label: 'Absences',
        value: '$absences',
        color: absences == 0 ? _green : _orange, loading: pending,
      )),
      const SizedBox(width: 10),
      Expanded(child: _SummaryPill(
        icon: Icons.receipt_long_rounded, label: 'Impayés',
        value: '$unpaid',
        color: unpaid == 0 ? _green : _gold, loading: pending,
      )),
    ]);
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool loading;
  const _SummaryPill({required this.icon, required this.label,
      required this.value, required this.color, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
            color: context.cMuted, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        if (loading)
          const SkeletonBox(width: 28, height: 16, radius: 4)
        else
          Text(value, style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Carte enfant (dashboard) — mène à sa fiche ──────────────────────────────
class _ChildSummaryCard extends ConsumerWidget {
  final SbStudent child;
  const _ChildSummaryCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades   = ref.watch(gradesForStudentProvider(child.id));
    final absences = ref.watch(absencesForStudentProvider(child.id));
    final invoices = ref.watch(invoicesForStudentProvider(child.id));

    final list = grades.valueOrNull ?? const <SbGrade>[];
    final moyenne = list.isEmpty
        ? null
        : list.fold<double>(0, (s, g) => s + g.outOf20) / list.length;
    final nbAbs = (absences.valueOrNull ?? const <SbAbsence>[]).length;
    final unpaid = (invoices.valueOrNull ?? const <SbInvoice>[])
        .where((i) => !i.isPaid)
        .length;

    return Material(
      color: context.cCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChildDetailPage(child: child),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.cBorder),
          ),
          child: Column(children: [
            Row(children: [
              Avatar(name: child.fullName, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(child.fullName,
                    style: TextStyle(color: context.cInk, fontSize: 14.5,
                        fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(child.classe ?? 'Classe non renseignée',
                    style: TextStyle(color: context.cMuted, fontSize: 12)),
              ])),
              Icon(Icons.chevron_right_rounded,
                  color: context.cMuted, size: 20),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _MiniStat(
                label: 'Moyenne',
                value: moyenne?.toStringAsFixed(1) ?? '—',
                color: moyenne == null
                    ? context.cMuted
                    : moyenne >= 14 ? _green : moyenne >= 10 ? _gold : _terra,
              ),
              _MiniStat(
                label: nbAbs > 1 ? 'Absences' : 'Absence',
                value: '$nbAbs',
                color: nbAbs == 0 ? _green : _orange,
              ),
              _MiniStat(
                label: 'Scolarité',
                value: unpaid == 0 ? 'À jour' : '$unpaid dû',
                color: unpaid == 0 ? _green : _gold,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              color: context.cMuted, fontSize: 10,
              fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Ce qui demande attention — dérivé du réel, jamais fabriqué ──────────────
class _AttentionSection extends ConsumerWidget {
  final List<SbStudent> children;
  const _AttentionSection({required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[];

    for (final c in children) {
      final invoices = ref.watch(invoicesForStudentProvider(c.id)).valueOrNull
          ?? const <SbInvoice>[];
      final absences = ref.watch(absencesForStudentProvider(c.id)).valueOrNull
          ?? const <SbAbsence>[];

      for (final i in invoices.where((i) => i.isOverdue)) {
        items.add(_AlertCard(
          icon: Icons.warning_amber_rounded,
          color: _terra,
          title: 'Facture en retard',
          subtitle: '${c.prenom} · '
              '${i.amount.toStringAsFixed(0)} ${i.currency}'
              '${i.description != null ? ' · ${i.description}' : ''}',
        ));
      }
      for (final i in invoices.where((i) => i.isPending)) {
        items.add(_AlertCard(
          icon: Icons.payments_outlined,
          color: _orange,
          title: 'Frais de scolarité à régler',
          subtitle: '${c.prenom} · '
              '${i.amount.toStringAsFixed(0)} ${i.currency}',
        ));
      }

      final unjustified = absences.where((a) => !a.justified).length;
      if (unjustified > 0) {
        items.add(_AlertCard(
          icon: Icons.event_busy_rounded,
          color: _orange,
          title: unjustified > 1
              ? '$unjustified absences à justifier'
              : 'Une absence à justifier',
          subtitle: c.prenom,
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ce qui demande votre attention', style: TextStyle(
          color: context.cInk, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (items.isEmpty)
        const _Notice(
          icon: Icons.check_circle_outline_rounded,
          color: _green,
          text: 'Tout est en ordre — aucune facture en attente '
              'ni absence à justifier.',
        )
      else
        for (final w in items) ...[w, const SizedBox(height: 8)],
    ]);
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _AlertCard({required this.icon, required this.color,
      required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
              color: context.cInk, fontSize: 13,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(
              color: context.cMuted, fontSize: 11.5)),
        ])),
      ]),
    );
  }
}

// ── Bandeau informatif (vide / erreur / tout va bien) ───────────────────────
class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Notice({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(
            color: context.cMuted, fontSize: 12.5, height: 1.5))),
      ]),
    );
  }
}
