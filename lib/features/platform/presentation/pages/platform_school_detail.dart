import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../platform_providers.dart';
import '../widgets/platform_widgets.dart';

/// Fiche détaillée d'une école — affichée **inline** dans la console (la
/// sidebar reste, le contenu change), pas comme une route à part. Suit le
/// design system : `PageScaffold` + sections `DataPanel` + `DataTablePanel`.
class PlatformSchoolDetailView extends ConsumerStatefulWidget {
  final PlatformSchool school;
  final VoidCallback onBack;
  const PlatformSchoolDetailView({
    super.key,
    required this.school,
    required this.onBack,
  });

  @override
  ConsumerState<PlatformSchoolDetailView> createState() =>
      _PlatformSchoolDetailViewState();
}

class _PlatformSchoolDetailViewState
    extends ConsumerState<PlatformSchoolDetailView> {
  int _tab = 0;

  static const _tabs = [
    (Icons.dashboard_rounded, 'Aperçu'),
    (Icons.people_alt_rounded, 'Élèves'),
    (Icons.timeline_rounded, 'Activité'),
    (Icons.receipt_long_rounded, 'Facturation'),
    (Icons.menu_book_rounded, 'Journal'),
  ];

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color ?? ScolarisPalette.forestGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  /// Répercute une mutation (mock) sur la liste ET sur la fiche ouverte.
  void _apply(PlatformSchool updated) {
    ref.read(selectedPlatformSchoolProvider.notifier).state = updated;
  }

  Future<void> _toggleSuspend() async {
    final s = widget.school;
    final suspended =
        s.status == SubStatus.expired || s.status == SubStatus.canceled;
    final ok = await _confirm(
      title: suspended ? 'Réactiver l\'école ?' : 'Suspendre l\'école ?',
      message: suspended
          ? 'L\'école « ${s.name} » retrouvera un accès complet à Scolaris.'
          : 'L\'accès de « ${s.name} » sera limité (lecture seule) jusqu\'à réactivation.',
      confirmLabel: suspended ? 'Réactiver' : 'Suspendre',
      danger: !suspended,
    );
    if (ok != true) return;
    _apply(PlatformMock.setStatus(
        s.id, suspended ? SubStatus.active : SubStatus.canceled));
    _snack(suspended ? 'École réactivée.' : 'École suspendue.',
        color: suspended ? ScolarisPalette.forestGreen : ScolarisPalette.terracotta);
  }

  Future<void> _extendTrial() async {
    final s = widget.school;
    final ok = await _confirm(
      title: 'Prolonger l\'essai ?',
      message: 'L\'essai gratuit de « ${s.name} » sera prolongé de 30 jours.',
      confirmLabel: 'Prolonger de 30 j',
    );
    if (ok != true) return;
    _apply(PlatformMock.extendTrial(s.id, 30));
    _snack('Essai prolongé de 30 jours.');
  }

  Future<void> _changePlan() async {
    final s = widget.school;
    final picked = await showDialog<PlatformPlan>(
      context: context,
      builder: (_) => _ChangePlanDialog(current: s.plan),
    );
    if (picked == null || picked == s.plan) return;
    _apply(PlatformMock.setPlan(s.id, picked));
    _snack('Offre changée en ${picked.label}.', color: picked.color);
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    danger ? ScolarisPalette.terracotta : ScolarisPalette.forestGreen),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    final suspended =
        s.status == SubStatus.expired || s.status == SubStatus.canceled;
    return PageScaffold(
      title: s.name,
      subtitle: '${s.city}, ${s.country} · ${s.typesLabel}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fil d'ariane / retour à la liste (reste dans la console).
        _BackLink(onBack: widget.onBack),
        const SizedBox(height: 14),
        // Barre d'actions de contrôle (s'enroule sur petit écran).
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionButton(
            label: 'Ouvrir l\'espace',
            icon: Icons.open_in_new_rounded,
            onTap: () => _snack('Ouverture de l\'espace — démonstration',
                color: ScolarisPalette.terracotta),
          ),
          ActionButton(
            label: 'Changer d\'offre',
            icon: Icons.workspace_premium_outlined,
            onTap: _changePlan,
          ),
          if (s.status == SubStatus.trial)
            ActionButton(
              label: 'Prolonger l\'essai',
              icon: Icons.hourglass_bottom_rounded,
              onTap: _extendTrial,
            ),
          ActionButton(
            label: suspended ? 'Réactiver' : 'Suspendre',
            icon: suspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
            primary: true,
            onTap: _toggleSuspend,
          ),
        ]),
        const SizedBox(height: 16),
        _DetailTabs(
          tabs: _tabs,
          current: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        switch (_tab) {
          1 => _StudentsTab(school: s),
          2 => _ActivityTab(school: s),
          3 => _BillingTab(school: s),
          4 => _JournalTab(school: s),
          _ => _OverviewTab(school: s),
        },
      ]),
    );
  }
}

/// Dialogue de choix d'offre (Simple / Pro / Max).
class _ChangePlanDialog extends StatelessWidget {
  final PlatformPlan current;
  const _ChangePlanDialog({required this.current});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Changer d\'offre',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final p in PlatformPlan.values) ...[
          _PlanOption(
            plan: p,
            selected: p == current,
            onTap: () => Navigator.pop(context, p),
          ),
          if (p != PlatformPlan.values.last) const SizedBox(height: 8),
        ],
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  final PlatformPlan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanOption({
    required this.plan,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? plan.color.withValues(alpha: .08) : context.cCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? plan.color : context.cBorder,
              width: selected ? 2 : 1),
        ),
        child: Row(children: [
          PlanBadge(plan: plan),
          const SizedBox(width: 12),
          Text('${groupThousands(plan.monthlyPrice)} F/mois',
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.cInk,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 18, color: plan.color)
          else
            Text(
                plan.studentLimit == null
                    ? 'illimité'
                    : '≤ ${groupThousands(plan.studentLimit!)}',
                style: TextStyle(fontSize: 11, color: context.cMuted)),
        ]),
      ),
    );
  }
}

/// Barre d'onglets segmentée (pilule) — theme-aware.
class _DetailTabs extends StatelessWidget {
  final List<(IconData, String)> tabs;
  final int current;
  final ValueChanged<int> onChanged;
  const _DetailTabs({
    required this.tabs,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(child: _seg(context, i)),
      ]),
    );
  }

  Widget _seg(BuildContext context, int i) {
    final sel = current == i;
    return Material(
      color: sel ? context.cCard : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onChanged(i),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: sel
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: context.cBorder))
              : null,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(tabs[i].$1,
                size: 14,
                color: sel ? ScolarisPalette.terracotta : context.cMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(tabs[i].$2,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: sel ? ScolarisPalette.terracotta : context.cMuted,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Onglet APERÇU ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final PlatformSchool school;
  const _OverviewTab({required this.school});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _OverviewPanel(school: school),
      const SizedBox(height: 14),
      _SubscriptionPanel(school: school),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (_, c) {
        final contact = _ContactPanel(school: school);
        final timeline = _TimelinePanel(school: school);
        if (c.maxWidth < 720) {
          return Column(children: [
            contact,
            const SizedBox(height: 14),
            timeline,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: contact),
            const SizedBox(width: 14),
            Expanded(child: timeline),
          ],
        );
      }),
    ]);
  }
}

// ── Onglet ÉLÈVES ─────────────────────────────────────────────────────────────
class _StudentsTab extends StatelessWidget {
  final PlatformSchool school;
  const _StudentsTab({required this.school});
  @override
  Widget build(BuildContext context) {
    final students = PlatformMock.studentsFor(school);
    final more = school.studentCount - students.length;
    return DataPanel(
      title: 'Élèves',
      headerActions: [
        Text('${groupThousands(school.studentCount)} au total',
            style: TextStyle(fontSize: 11.5, color: context.cMuted)),
      ],
      child: students.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Aucun élève',
              description: 'Cette école n\'a pas encore inscrit d\'élèves.')
          : Column(children: [
              DataTablePanel(
                columns: const ['Élève', 'Classe', 'Matricule', 'Statut'],
                flex: const [3, 2, 3, 2],
                rows: [
                  for (final st in students)
                    [
                      Row(children: [
                        Avatar(name: st.name, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(st.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.cInk,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      Text(st.className,
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                      Text(st.matricule,
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: st.active
                            ? StatusPill.success('Actif')
                            : StatusPill.neutral('Inactif'),
                      ),
                    ],
                ],
              ),
              if (more > 0) ...[
                const SizedBox(height: 10),
                Text('+ ${groupThousands(more)} autres élèves (échantillon de démonstration)',
                    style: TextStyle(fontSize: 11, color: context.cMuted)),
              ],
            ]),
    );
  }
}

// ── Onglet ACTIVITÉ ───────────────────────────────────────────────────────────
class _ActivityTab extends StatelessWidget {
  final PlatformSchool school;
  const _ActivityTab({required this.school});
  @override
  Widget build(BuildContext context) {
    final items = PlatformMock.activityFor(school);
    return DataPanel(
      title: 'Activité récente',
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          _ActivityLine(item: items[i]),
          if (i < items.length - 1)
            Divider(height: 1, color: context.cBorder.withValues(alpha: .5)),
        ],
      ]),
    );
  }
}

class _ActivityLine extends StatelessWidget {
  final ActivityItem item;
  const _ActivityLine({required this.item});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(item.icon, size: 15, color: item.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(item.text,
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.cInk,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Text(item.ago, style: TextStyle(fontSize: 11, color: context.cMuted)),
      ]),
    );
  }
}

// ── Onglet JOURNAL ────────────────────────────────────────────────────────────
/// Journal de bord de l'école : historique horodaté du cycle de vie du compte
/// (création, souscription, changements d'offre, paiements, incidents…).
class _JournalTab extends StatelessWidget {
  final PlatformSchool school;
  const _JournalTab({required this.school});
  @override
  Widget build(BuildContext context) {
    final events = PlatformMock.timelineFor(school);
    return DataPanel(
      title: 'Journal de bord',
      headerActions: [
        Text('${events.length} événement${events.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 11.5, color: context.cMuted)),
      ],
      child: events.isEmpty
          ? const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Journal vide',
              description: 'Aucun événement enregistré pour cette école.')
          : Column(children: [
              for (var i = 0; i < events.length; i++)
                _TimelineTile(event: events[i], last: i == events.length - 1),
            ]),
    );
  }
}

// ── Onglet FACTURATION ────────────────────────────────────────────────────────
class _BillingTab extends StatelessWidget {
  final PlatformSchool school;
  const _BillingTab({required this.school});
  @override
  Widget build(BuildContext context) {
    final s = school;
    final payments = PlatformMock.paymentsFor(s);
    final collected =
        payments.where((p) => p.success).fold(0, (sum, p) => sum + p.amount);
    return Column(children: [
      _SubscriptionPanel(school: s),
      const SizedBox(height: 14),
      DataPanel(
        title: 'Historique de paiements',
        headerActions: payments.isEmpty
            ? const []
            : [
                Text('${groupThousands(collected)} F encaissés',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: ScolarisPalette.forestGreen,
                        fontWeight: FontWeight.w700)),
              ],
        child: payments.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Aucun paiement',
                description: 'Cette école est encore en période d\'essai.')
            : DataTablePanel(
                columns: const ['Période', 'Méthode', 'Montant', 'Statut'],
                flex: const [3, 3, 2, 2],
                rows: [
                  for (final p in payments)
                    [
                      Text(p.period,
                          style: TextStyle(
                              color: context.cInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                      Text(p.method,
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                      Text('${groupThousands(p.amount)} F',
                          style: TextStyle(
                              color: context.cInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: p.success
                            ? StatusPill.success('Payé')
                            : StatusPill.danger('Échoué'),
                      ),
                    ],
                ],
              ),
      ),
    ]);
  }
}

/// Lien « ‹ Écoles » qui referme le détail et revient à la liste (inline).
class _BackLink extends StatelessWidget {
  final VoidCallback onBack;
  const _BackLink({required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded, size: 15, color: context.cMuted),
              const SizedBox(width: 6),
              Text('Toutes les écoles',
                  style: TextStyle(
                      fontSize: 12,
                      color: context.cMuted,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Aperçu : tuiles de métriques (style « _Tile » des rapports) ───────────────
class _OverviewPanel extends StatelessWidget {
  final PlatformSchool school;
  const _OverviewPanel({required this.school});
  @override
  Widget build(BuildContext context) {
    final s = school;
    final metrics = <_Metric>[
      _Metric(Icons.people_alt_rounded, 'Élèves',
          groupThousands(s.studentCount), ScolarisPalette.terracotta),
      _Metric(Icons.co_present_rounded, 'Enseignants', '${s.teacherCount}',
          ScolarisPalette.forestGreen),
      _Metric(Icons.class_rounded, 'Classes', '${s.classCount}',
          ScolarisAccents.sapphire),
      _Metric(
        s.daysLeft < 0 ? Icons.event_busy_rounded : Icons.event_available_rounded,
        s.status == SubStatus.trial ? 'Fin d\'essai' : 'Échéance',
        s.daysLeft < 0 ? '${-s.daysLeft} j' : '${s.daysLeft} j',
        s.daysLeft < 0 ? ScolarisPalette.terracotta : ScolarisPalette.gold,
      ),
    ];
    return DataPanel(
      title: 'Aperçu',
      child: LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth < 520 ? 2 : 4;
        const spacing = 10.0;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final m in metrics) SizedBox(width: w, child: _MetricTile(m)),
          ],
        );
      }),
    );
  }
}

class _Metric {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Metric(this.icon, this.label, this.value, this.color);
}

class _MetricTile extends StatelessWidget {
  final _Metric m;
  const _MetricTile(this.m);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: context.cBorder),
          ),
          child: Icon(m.icon, size: 16, color: m.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.value,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17, color: m.color, fontWeight: FontWeight.w800)),
            Text(m.label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: context.cMuted, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ── Abonnement ────────────────────────────────────────────────────────────────
class _SubscriptionPanel extends StatelessWidget {
  final PlatformSchool school;
  const _SubscriptionPanel({required this.school});
  @override
  Widget build(BuildContext context) {
    final s = school;
    final lim = s.studentLimit;
    return DataPanel(
      title: 'Abonnement',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 28,
          runSpacing: 14,
          children: [
            _KeyVal(label: 'Offre', child: PlanBadge(plan: s.plan)),
            _KeyVal(label: 'Statut', child: SubStatusBadge(status: s.status)),
            _KeyVal(
              label: 'Prix mensuel',
              child: _valueText(context, '${groupThousands(s.plan.monthlyPrice)} FCFA'),
            ),
            _KeyVal(
              label: s.status == SubStatus.trial ? 'Fin d\'essai' : 'Prochaine échéance',
              child: _valueText(
                  context,
                  s.daysLeft < 0
                      ? 'Dépassée de ${-s.daysLeft} j'
                      : 'Dans ${s.daysLeft} j'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: context.cBorder.withValues(alpha: .6)),
        const SizedBox(height: 14),
        Row(children: [
          Text('Usage élèves',
              style: TextStyle(
                  fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            lim == null
                ? '${groupThousands(s.studentCount)} · illimité'
                : '${groupThousands(s.studentCount)} / ${groupThousands(lim)}',
            style: TextStyle(
                fontSize: 12, color: context.cInk, fontWeight: FontWeight.w700),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: lim == null ? 1 : s.usageRatio,
            minHeight: 8,
            backgroundColor: context.cSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(
                s.usageRatio >= .9 ? ScolarisPalette.terracotta : s.plan.color),
          ),
        ),
      ]),
    );
  }

  Widget _valueText(BuildContext context, String v) => Text(v,
      style: TextStyle(
          color: context.cInk, fontSize: 13.5, fontWeight: FontWeight.w800));
}

class _KeyVal extends StatelessWidget {
  final String label;
  final Widget child;
  const _KeyVal({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 9,
                color: context.cMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: .6)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ── Contact ───────────────────────────────────────────────────────────────────
class _ContactPanel extends StatelessWidget {
  final PlatformSchool school;
  const _ContactPanel({required this.school});
  @override
  Widget build(BuildContext context) {
    final s = school;
    return DataPanel(
      title: 'Coordonnées',
      child: Column(children: [
        _ContactRow(icon: Icons.person_rounded, label: 'Responsable', value: s.director),
        _rowGap(context),
        _ContactRow(icon: Icons.mail_outline_rounded, label: 'Email', value: s.email),
        _rowGap(context),
        _ContactRow(icon: Icons.phone_rounded, label: 'Téléphone', value: s.phone),
      ]),
    );
  }

  Widget _rowGap(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: context.cBorder.withValues(alpha: .5)),
      );
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: ScolarisPalette.terracotta),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, color: context.cMuted)),
          const SizedBox(height: 1),
          Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, color: context.cInk, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

// ── Timeline (cycle de vie) ────────────────────────────────────────────────────
class _TimelinePanel extends StatelessWidget {
  final PlatformSchool school;
  const _TimelinePanel({required this.school});
  @override
  Widget build(BuildContext context) {
    final events = PlatformMock.timelineFor(school);
    return DataPanel(
      title: 'Cycle de vie',
      child: Column(children: [
        for (var i = 0; i < events.length; i++)
          _TimelineTile(event: events[i], last: i == events.length - 1),
      ]),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final SubEvent event;
  final bool last;
  const _TimelineTile({required this.event, required this.last});

  static String _fmt(DateTime d) {
    const m = [
      'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.icon, size: 14, color: event.color),
          ),
          if (!last)
            Expanded(
              child: Container(
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: context.cBorder,
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: context.cInk,
                      fontWeight: FontWeight.w600,
                      height: 1.3)),
              const SizedBox(height: 1),
              Text(_fmt(event.date),
                  style: TextStyle(fontSize: 11, color: context.cMuted)),
            ]),
          ),
        ),
      ]),
    );
  }
}
