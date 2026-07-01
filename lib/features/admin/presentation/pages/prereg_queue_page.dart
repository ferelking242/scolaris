import 'package:flutter/material.dart';

import '../../../../shared/widgets/page_scaffold.dart';
import '../../../enrollment/data/prereg_request.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);

/// File d'attente des pré-inscriptions reçues (maquette). Master-détail inline :
/// liste des demandes → fiche → Accepter / Refuser.
class PreRegQueuePage extends StatefulWidget {
  const PreRegQueuePage({super.key});
  @override
  State<PreRegQueuePage> createState() => _PreRegQueuePageState();
}

class _PreRegQueuePageState extends State<PreRegQueuePage> {
  String _filter = 'À traiter';
  PreRegRequest? _selected;

  static const _filters = ['À traiter', 'Acceptées', 'Refusées', 'Toutes'];

  List<PreRegRequest> get _filtered {
    Iterable<PreRegRequest> list = PreRegRequests.items;
    switch (_filter) {
      case 'À traiter':
        list = list.where((r) => r.status == PreRegStatus.pending);
        break;
      case 'Acceptées':
        list = list.where((r) => r.status == PreRegStatus.accepted);
        break;
      case 'Refusées':
        list = list.where((r) => r.status == PreRegStatus.rejected);
        break;
    }
    return list.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color ?? _green,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _accept(PreRegRequest r) async {
    final ok = await _confirm(
      title: 'Accepter la demande ?',
      message:
          'La fiche élève de « ${r.fullName} » sera créée et affectée à une '
          'classe, et les comptes parent/élève seront générés.',
      confirmLabel: 'Accepter',
    );
    if (ok != true) return;
    setState(() {
      PreRegRequests.accept(r.id);
      _selected = null;
    });
    _snack('Demande acceptée — fiche & comptes créés (démo).');
  }

  Future<void> _reject(PreRegRequest r) async {
    final ok = await _confirm(
      title: 'Refuser la demande ?',
      message:
          'La demande de « ${r.fullName} » sera refusée. Les frais de dossier '
          'déjà réglés ne sont pas remboursés.',
      confirmLabel: 'Refuser',
      danger: true,
    );
    if (ok != true) return;
    setState(() {
      PreRegRequests.reject(r.id);
      _selected = null;
    });
    _snack('Demande refusée.', color: _terra);
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
                backgroundColor: danger ? _terra : _green),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return _DetailView(
        request: _selected!,
        onBack: () => setState(() => _selected = null),
        onAccept: () => _accept(_selected!),
        onReject: () => _reject(_selected!),
      );
    }

    final rows = _filtered;
    return PageScaffold(
      title: 'Pré-inscriptions',
      subtitle: '${PreRegRequests.pendingCount} demande(s) à traiter',
      child: Column(children: [
        // Filtres.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: _terra.withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _filter == f ? _terra : context.cMuted,
                    fontWeight: _filter == f ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        DataPanel(
          title: 'Demandes reçues',
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Aucune demande',
                  description: 'Aucune pré-inscription pour ce filtre.')
              : DataTablePanel(
                  columns: const [
                    'Élève', 'Niveau', 'Tuteur', 'Paiement', 'Reçue', ''
                  ],
                  flex: const [3, 2, 3, 2, 2, 1],
                  rows: [
                    for (final r in rows)
                      [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selected = r),
                          child: Row(children: [
                            Avatar(name: r.fullName, size: 26),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(r.fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: context.cInk,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                        Text(r.level,
                            style:
                                TextStyle(fontSize: 11.5, color: context.cMuted)),
                        Text('${r.guardianName}\n${r.guardianPhone}',
                            style:
                                TextStyle(fontSize: 11, color: context.cMuted)),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: _PayPill(pay: r.pay)),
                        Text(_ago(r.submittedAt),
                            style:
                                TextStyle(fontSize: 11, color: context.cMuted)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: r.status == PreRegStatus.pending
                              ? IconButton(
                                  onPressed: () =>
                                      setState(() => _selected = r),
                                  icon: const Icon(
                                      Icons.chevron_right_rounded, size: 18),
                                  color: context.cMuted.withValues(alpha: .6),
                                  tooltip: 'Ouvrir',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                      width: 32, height: 32),
                                )
                              : _StatusPill(status: r.status),
                        ),
                      ],
                  ],
                ),
        ),
      ]),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime(2026, 6, 30).difference(d);
    if (diff.inHours < 1) return 'à l\'instant';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    return 'il y a ${diff.inDays} j';
  }
}

// ── Fiche détail ──────────────────────────────────────────────────────────────
class _DetailView extends StatelessWidget {
  final PreRegRequest request;
  final VoidCallback onBack;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _DetailView({
    required this.request,
    required this.onBack,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    final pending = r.status == PreRegStatus.pending;
    return PageScaffold(
      title: r.fullName,
      subtitle: '${r.level} · ${r.city}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Retour.
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: context.cSubtle,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: onBack,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back_rounded, size: 15, color: context.cMuted),
                  const SizedBox(width: 6),
                  Text('Toutes les demandes',
                      style: TextStyle(
                          fontSize: 12,
                          color: context.cMuted,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Statut / paiement.
        Row(children: [
          _StatusPill(status: r.status),
          const SizedBox(width: 8),
          _PayPill(pay: r.pay),
          const Spacer(),
          Text('${_group(r.feeAmount)} F de frais',
              style: TextStyle(
                  fontSize: 12,
                  color: context.cInk,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),

        // Actions (seulement si à traiter).
        if (pending) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionButton(
                label: 'Refuser', icon: Icons.close_rounded, onTap: onReject),
            ActionButton(
                label: 'Accepter',
                icon: Icons.check_rounded,
                primary: true,
                onTap: onAccept),
          ]),
          const SizedBox(height: 14),
        ],

        // Tuteur / contact.
        DataPanel(
          title: 'Tuteur / contact',
          child: Column(children: [
            _Row(label: 'Responsable', value: r.guardianName),
            _Row(label: 'Téléphone', value: r.guardianPhone),
            _Row(label: 'Email', value: r.guardianEmail),
          ]),
        ),
        const SizedBox(height: 14),

        // Informations soumises.
        DataPanel(
          title: 'Informations soumises',
          child: Column(children: [
            _Row(label: 'Niveau souhaité', value: r.level),
            _Row(label: 'Ville', value: r.city),
            for (final e in r.data.entries)
              _Row(label: e.key, value: e.value),
          ]),
        ),
      ]),
    );
  }

  static String _group(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 150,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: context.cMuted)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.cInk,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Pastilles ─────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final PreRegStatus status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PreRegStatus.pending => StatusPill.info('À traiter'),
      PreRegStatus.accepted => StatusPill.success('Acceptée'),
      PreRegStatus.rejected => StatusPill.danger('Refusée'),
    };
  }
}

class _PayPill extends StatelessWidget {
  final PreRegPay pay;
  const _PayPill({required this.pay});
  @override
  Widget build(BuildContext context) {
    return switch (pay) {
      PreRegPay.online => StatusPill.success('Payé en ligne'),
      PreRegPay.cash => StatusPill.success('Payé (espèces)'),
      PreRegPay.unpaid => StatusPill.warning('À régler à l\'école'),
    };
  }
}
