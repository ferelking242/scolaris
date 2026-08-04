import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collection/collection.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../data/platform_mock_data.dart';
import '../../data/platform_repository.dart';
import '../platform_providers.dart';
import '../widgets/platform_widgets.dart';

// ── Événements réels (`platform_events`) → widgets d'affichage ──────────────
// Le trigger DB écrit le type + les données brutes (metadata) ; c'est ici,
// côté client, qu'on décide du libellé, de l'icône et de la couleur — plus
// simple à ajuster que de coder du français dans des triggers SQL.

String _planLabel(dynamic code) => switch (code) {
      'simple' => 'Simple',
      'pro' => 'Pro',
      'max' => 'Max',
      _ => code?.toString() ?? '—',
    };

String _statusChangeTitle(String? oldStatus, String? newStatus) {
  if (newStatus == 'active' && oldStatus == 'canceled') return 'École réactivée';
  if (newStatus == 'active') return 'Abonnement activé';
  if (newStatus == 'canceled') return 'École suspendue';
  if (newStatus == 'expired') return 'Abonnement expiré — accès en lecture seule';
  if (newStatus == 'past_due') return 'Paiement en retard détecté';
  return 'Statut changé : ${oldStatus ?? '—'} → ${newStatus ?? '—'}';
}

String _eventTitle(PlatformEvent e) {
  final m = e.metadata;
  switch (e.type) {
    case 'school_created':
      return 'École inscrite sur Scolaris';
    case 'subscription_started':
      return 'Essai gratuit démarré (offre ${_planLabel(m['plan_code'])})';
    case 'status_changed':
      return _statusChangeTitle(m['old_status'] as String?, m['new_status'] as String?);
    case 'plan_changed':
      return 'Offre changée : ${_planLabel(m['old_plan'])} → ${_planLabel(m['new_plan'])}';
    case 'trial_extended':
      final days = m['days'];
      return 'Essai prolongé de ${days ?? '?'} jour${(days is int && days > 1) ? 's' : ''}';
    case 'payment_received':
      final method = m['method'];
      return 'Paiement de ${groupThousands((m['amount'] as num?)?.toInt() ?? 0)} '
          '${m['currency'] ?? 'XAF'} encaissé${method != null ? ' ($method)' : ''}';
    case 'payment_failed':
      return 'Échec de paiement (${groupThousands((m['amount'] as num?)?.toInt() ?? 0)} '
          '${m['currency'] ?? 'XAF'})';
    default:
      return e.type;
  }
}

(IconData, Color) _eventVisual(PlatformEvent e) {
  switch (e.type) {
    case 'school_created':
      return (Icons.rocket_launch_rounded, ScolarisPalette.terracotta);
    case 'subscription_started':
      return (Icons.hourglass_top_rounded, ScolarisPalette.gold);
    case 'status_changed':
      final ns = e.metadata['new_status'];
      if (ns == 'active') return (Icons.play_arrow_rounded, ScolarisPalette.forestGreen);
      if (ns == 'canceled') return (Icons.pause_rounded, ScolarisPalette.terracotta);
      if (ns == 'expired') return (Icons.block_rounded, ScolarisPalette.terracotta);
      return (Icons.sync_alt_rounded, ScolarisAccents.slate);
    case 'plan_changed':
      return (Icons.workspace_premium_rounded, ScolarisPalette.gold);
    case 'trial_extended':
      return (Icons.hourglass_bottom_rounded, ScolarisPalette.gold);
    case 'payment_received':
      return (Icons.payments_rounded, ScolarisPalette.forestGreen);
    case 'payment_failed':
      return (Icons.error_outline_rounded, ScolarisPalette.orange);
    default:
      return (Icons.info_outline_rounded, ScolarisAccents.slate);
  }
}

SubEvent _toSubEvent(PlatformEvent e) {
  final (icon, color) = _eventVisual(e);
  return SubEvent(date: e.createdAt, title: _eventTitle(e), icon: icon, color: color);
}

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

  /// Vrai pour les écoles de démonstration (maquette Dashboard v0) — ne
  /// devrait plus arriver en usage normal (la liste « Écoles » ne montre plus
  /// que de vraies écoles), gardé en filet de sécurité : `PlatformMock.byId`
  /// planterait sur un id absent de la liste figée.
  bool get _isMockSchool =>
      PlatformMock.schools.any((x) => x.id == widget.school.id);

  /// Recharge l'école depuis la base après une mutation et la répercute sur
  /// la liste ET sur la fiche ouverte.
  Future<void> _refresh() async {
    ref.invalidate(platformSchoolsProvider);
    final all = await ref.read(platformSchoolsProvider.future);
    final updated = all.firstWhereOrNull((s) => s.id == widget.school.id);
    if (updated != null && mounted) {
      ref.read(selectedPlatformSchoolProvider.notifier).state = updated;
    }
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
    try {
      if (_isMockSchool) {
        ref.read(selectedPlatformSchoolProvider.notifier).state =
            PlatformMock.setStatus(
                s.id, suspended ? SubStatus.active : SubStatus.canceled);
      } else {
        await PlatformRepository.setSchoolSuspended(s.id, !suspended);
        await _refresh();
      }
      _snack(suspended ? 'École réactivée.' : 'École suspendue.',
          color: suspended ? ScolarisPalette.forestGreen : ScolarisPalette.terracotta);
    } catch (e) {
      _snack('Échec : $e', color: ScolarisPalette.terracotta);
    }
  }

  /// Prolonge l'échéance de l'abonnement, QUEL QUE SOIT le statut (essai OU
  /// offre payante déjà active) — utile pour offrir un mois/an gratuit à une
  /// école, pas seulement pour rallonger un essai.
  Future<void> _extendSubscription() async {
    final s = widget.school;
    final days = await showDialog<int>(
      context: context,
      builder: (_) => const _ExtendSubscriptionDialog(),
    );
    if (days == null) return;
    final label = _durationLabel(days);
    final ok = await _confirm(
      title: 'Prolonger l\'abonnement ?',
      message: 'L\'abonnement de « ${s.name} » sera prolongé de $label, '
          'gratuitement, à partir de son échéance actuelle.',
      confirmLabel: 'Prolonger de $label',
    );
    if (ok != true) return;
    try {
      if (_isMockSchool) {
        ref.read(selectedPlatformSchoolProvider.notifier).state =
            PlatformMock.extendTrial(s.id, days);
      } else {
        await PlatformRepository.extendSchoolSubscription(s.id, days);
        await _refresh();
      }
      _snack('Abonnement prolongé de $label.');
    } catch (e) {
      _snack('Échec : $e', color: ScolarisPalette.terracotta);
    }
  }

  static String _durationLabel(int days) => switch (days) {
        30 => '1 mois',
        60 => '2 mois',
        90 => '3 mois',
        180 => '6 mois',
        365 => '1 an',
        _ => '$days jour${days > 1 ? 's' : ''}',
      };

  Future<void> _changePlan() async {
    final s = widget.school;
    final picked = await showDialog<PlatformPlan>(
      context: context,
      builder: (_) => _ChangePlanDialog(current: s.plan),
    );
    if (picked == null || picked == s.plan) return;
    final ok = await _confirm(
      title: 'Changer l\'offre ?',
      message: '« ${s.name} » passera de ${s.plan.label} à ${picked.label} '
          '(${groupThousands(picked.monthlyPrice)} FCFA/mois). Effet immédiat.',
      confirmLabel: 'Changer pour ${picked.label}',
    );
    if (ok != true) return;
    try {
      if (_isMockSchool) {
        ref.read(selectedPlatformSchoolProvider.notifier).state =
            PlatformMock.setPlan(s.id, picked);
      } else {
        await PlatformRepository.setSchoolPlan(s.id, picked);
        await _refresh();
      }
      _snack('Offre changée en ${picked.label}.', color: picked.color);
    } catch (e) {
      _snack('Échec : $e', color: ScolarisPalette.terracotta);
    }
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
      onRefresh: () async {
        ref.invalidate(platformSchoolStudentsProvider(s.id));
        ref.invalidate(platformSchoolEventsProvider(s.id));
        ref.invalidate(platformSchoolPaymentsProvider(s.id));
        await Future.wait([
          _refresh(),
          ref.read(platformSchoolStudentsProvider(s.id).future),
          ref.read(platformSchoolEventsProvider(s.id).future),
          ref.read(platformSchoolPaymentsProvider(s.id).future),
        ]);
      },
      title: s.name,
      subtitle: '${s.city}, ${s.country} · ${s.typesLabel}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fil d'ariane / retour à la liste (reste dans la console).
        _BackLink(onBack: widget.onBack),
        const SizedBox(height: 14),
        // Barre d'actions de contrôle (s'enroule sur petit écran).
        //
        // Pas de bouton « Ouvrir l'espace » : ça demanderait une vraie
        // impersonation (se connecter EN TANT QUE l'admin de cette école) —
        // aucun système de ce genre n'existe aujourd'hui (nouvelle Edge
        // Function sécurisée + traçabilité de qui a impersonné qui/quand).
        // Retiré plutôt que de laisser un bouton qui n'affichait qu'un
        // message factice.
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionButton(
            label: 'Changer d\'offre',
            icon: Icons.workspace_premium_outlined,
            onTap: _changePlan,
          ),
          ActionButton(
            label: 'Prolonger l\'abonnement',
            icon: Icons.hourglass_bottom_rounded,
            onTap: _extendSubscription,
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
          2 => _BillingTab(school: s),
          3 => _JournalTab(school: s),
          _ => _OverviewTab(school: s),
        },
      ]),
    );
  }
}

/// Dialogue de choix de durée de prolongation — un cadeau/geste commercial
/// (ex. « 1 an gratuit »), pas juste une rallonge d'essai : marche pour une
/// école déjà en offre payante active comme pour un essai.
class _ExtendSubscriptionDialog extends StatefulWidget {
  const _ExtendSubscriptionDialog();
  @override
  State<_ExtendSubscriptionDialog> createState() => _ExtendSubscriptionDialogState();
}

class _ExtendSubscriptionDialogState extends State<_ExtendSubscriptionDialog> {
  static const _quickOptions = [
    (30, '1 mois'),
    (60, '2 mois'),
    (90, '3 mois'),
    (180, '6 mois'),
    (365, '1 an'),
  ];

  final _customDays = TextEditingController();

  @override
  void dispose() {
    _customDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Prolonger l\'abonnement',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gratuitement, à partir de l\'échéance actuelle.',
              style: TextStyle(fontSize: 12, color: context.cMuted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _quickOptions)
              ActionChip(
                label: Text(o.$2),
                onPressed: () => Navigator.pop(context, o.$1),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _customDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ou un nombre de jours précis',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ScolarisPalette.terracotta),
              onPressed: () {
                final n = int.tryParse(_customDays.text.trim());
                if (n != null && n > 0) Navigator.pop(context, n);
              },
              child: const Text('OK'),
            ),
          ]),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
      ],
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
class _StudentsTab extends ConsumerWidget {
  final PlatformSchool school;
  const _StudentsTab({required this.school});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(platformSchoolStudentsProvider(school.id));
    return DataPanel(
      title: 'Élèves',
      headerActions: [
        Text('${groupThousands(school.studentCount)} au total',
            style: TextStyle(fontSize: 11.5, color: context.cMuted)),
      ],
      child: studentsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
        ),
        data: (students) => students.isEmpty
            ? const EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Aucun élève',
                description: 'Cette école n\'a pas encore inscrit d\'élèves.')
            : DataTablePanel(
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
      ),
    );
  }
}

// ── Onglet JOURNAL ────────────────────────────────────────────────────────────
/// Journal de bord de l'école : historique horodaté du cycle de vie du compte
/// (création, souscription, changements d'offre, paiements, incidents…) —
/// vrai, alimenté par `platform_events` (triggers DB).
class _JournalTab extends ConsumerWidget {
  final PlatformSchool school;
  const _JournalTab({required this.school});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(platformSchoolEventsProvider(school.id));
    return DataPanel(
      title: 'Journal de bord',
      child: eventsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
        ),
        data: (raw) {
          final events = raw.map(_toSubEvent).toList();
          return events.isEmpty
              ? const EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Journal vide',
                  description: 'Aucun événement enregistré pour cette école.')
              : Column(children: [
                  for (var i = 0; i < events.length; i++)
                    _TimelineTile(event: events[i], last: i == events.length - 1),
                ]);
        },
      ),
    );
  }
}

// ── Onglet FACTURATION ────────────────────────────────────────────────────────
class _BillingTab extends ConsumerWidget {
  final PlatformSchool school;
  const _BillingTab({required this.school});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = school;
    final paymentsAsync = ref.watch(platformSchoolPaymentsProvider(s.id));
    return Column(children: [
      _SubscriptionPanel(school: s),
      const SizedBox(height: 14),
      paymentsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => DataPanel(
          title: 'Historique de paiements',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
          ),
        ),
        data: (payments) {
          final collected = payments
              .where((p) => p.success)
              .fold(0, (sum, p) => sum + p.amount);
          return DataPanel(
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
          );
        },
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
class _TimelinePanel extends ConsumerWidget {
  final PlatformSchool school;
  const _TimelinePanel({required this.school});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(platformSchoolEventsProvider(school.id));
    return DataPanel(
      title: 'Cycle de vie',
      child: eventsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
        ),
        data: (raw) {
          // Aperçu compact : les 6 événements les plus récents seulement
          // (le détail complet est dans l'onglet Journal).
          final events = raw.take(6).map(_toSubEvent).toList();
          return Column(children: [
            for (var i = 0; i < events.length; i++)
              _TimelineTile(event: events[i], last: i == events.length - 1),
          ]);
        },
      ),
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
