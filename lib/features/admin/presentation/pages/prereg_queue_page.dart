import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/enrollment_config.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../enrollment/data/prereg_request.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);

/// File d'attente des pré-inscriptions reçues (`enrollment_requests`).
/// Master-détail inline : liste des demandes → fiche → Accepter / Refuser.
class PreRegQueuePage extends ConsumerStatefulWidget {
  const PreRegQueuePage({super.key});
  @override
  ConsumerState<PreRegQueuePage> createState() => _PreRegQueuePageState();
}

class _PreRegQueuePageState extends ConsumerState<PreRegQueuePage> {
  // Deux dossiers différents, une seule page : NOUVEAU dossier (pré-inscription
  // publique) contre CONTINUANT (décision de fin d'année à confirmer). Même
  // mécanique d'accueil admin, mécaniques sous-jacentes distinctes.
  String _section = 'preinscriptions';
  String _filter = 'À traiter';
  PreRegRequest? _selected;
  bool _busy = false;

  static const _filters = ['À traiter', 'Acceptées', 'Refusées', 'Toutes'];

  List<PreRegRequest> _filtered(List<PreRegRequest> items) {
    Iterable<PreRegRequest> list = items;
    switch (_filter) {
      case 'À traiter':
        list = list.where((r) => preRegStatusOf(r) == PreRegStatus.pending);
        break;
      case 'Acceptées':
        list = list.where((r) => preRegStatusOf(r) == PreRegStatus.accepted);
        break;
      case 'Refusées':
        list = list.where((r) => preRegStatusOf(r) == PreRegStatus.rejected);
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
          'La fiche élève de « ${r.fullName} » sera créée et rattachée à '
          'cette école. Vous pourrez l\'affecter à une classe ensuite.',
      confirmLabel: 'Accepter',
    );
    if (ok != true) return;
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    setState(() => _busy = true);
    try {
      await SupabaseDbSource.acceptEnrollmentRequest(
          request: r, schoolId: schoolId);
      ref.invalidate(enrollmentRequestsProvider);
      ref.invalidate(studentsProvider);
      if (!mounted) return;
      setState(() { _selected = null; _busy = false; });
      _snack('Demande acceptée — fiche élève créée.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Échec : $e', color: _terra);
    }
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
    setState(() => _busy = true);
    try {
      await SupabaseDbSource.rejectEnrollmentRequest(id: r.id);
      ref.invalidate(enrollmentRequestsProvider);
      if (!mounted) return;
      setState(() { _selected = null; _busy = false; });
      _snack('Demande refusée.', color: _terra);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Échec : $e', color: _terra);
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
                backgroundColor: danger ? _terra : _green),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Widget _sectionTabs() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final s in const [
              ('preinscriptions', 'Nouveaux dossiers'),
              ('reregistrations', 'Ré-inscriptions'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.$2),
                  selected: _section == s.$1,
                  onSelected: (_) =>
                      setState(() { _section = s.$1; _selected = null; }),
                  selectedColor: _green.withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _section == s.$1 ? _green : context.cMuted,
                  ),
                ),
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // PAS d'Expanded ci-dessous : PageScaffold fait déjà défiler tout son
    // contenu (SingleChildScrollView) → hauteur non bornée. Un Expanded
    // dedans plante (« RenderFlex... unbounded height »).
    if (_section == 'reregistrations') {
      return PageScaffold(
        title: 'Inscriptions',
        subtitle: 'Décisions de fin d\'année en attente de confirmation',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTabs(),
          const _ReRegistrationTab(),
        ]),
      );
    }

    final requestsAsync = ref.watch(enrollmentRequestsProvider);

    return requestsAsync.when(
      loading: () => PageScaffold(
        title: 'Inscriptions',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTabs(),
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ]),
      ),
      error: (e, _) => PageScaffold(
        title: 'Inscriptions',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTabs(),
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erreur de chargement',
            description: '$e',
          ),
        ]),
      ),
      data: (items) {
        if (_selected != null) {
          final r = items.where((x) => x.id == _selected!.id).firstOrNull ??
              _selected!;
          return _DetailView(
            request: r,
            busy: _busy,
            onBack: () => setState(() => _selected = null),
            onAccept: () => _accept(r),
            onReject: () => _reject(r),
          );
        }

        final rows = _filtered(items);
        final pendingCount = items
            .where((r) => preRegStatusOf(r) == PreRegStatus.pending)
            .length;
        return PageScaffold(
          title: 'Inscriptions',
          subtitle: '$pendingCount demande(s) à traiter',
          child: Column(children: [
            _sectionTabs(),
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
                        fontWeight:
                            _filter == f ? FontWeight.w700 : FontWeight.w500,
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
                        'Élève', 'Niveau', 'Tuteur', 'Reçue', ''
                      ],
                      flex: const [3, 2, 3, 2, 1],
                      rows: [
                        for (final r in rows)
                          [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _selected = r),
                                child: Row(children: [
                                  Avatar(name: r.fullName, size: 26),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                        r.fullName.isEmpty ? '—' : r.fullName,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: context.cInk,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                              ),
                            ),
                            Text(r.level.isEmpty ? '—' : r.level,
                                style: TextStyle(
                                    fontSize: 11.5, color: context.cMuted)),
                            Text('${r.guardianName}\n${r.guardianPhone}',
                                style: TextStyle(
                                    fontSize: 11, color: context.cMuted)),
                            Text(_ago(r.submittedAt),
                                style: TextStyle(
                                    fontSize: 11, color: context.cMuted)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: preRegStatusOf(r) == PreRegStatus.pending
                                  ? IconButton(
                                      onPressed: () =>
                                          setState(() => _selected = r),
                                      icon: const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18),
                                      color:
                                          context.cMuted.withValues(alpha: .6),
                                      tooltip: 'Ouvrir',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints.tightFor(
                                          width: 32, height: 32),
                                    )
                                  : _StatusPill(status: preRegStatusOf(r)),
                            ),
                          ],
                      ],
                    ),
            ),
          ]),
        );
      },
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inHours < 1) return 'à l\'instant';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    return 'il y a ${diff.inDays} j';
  }
}

// ── Fiche détail ──────────────────────────────────────────────────────────────
class _DetailView extends StatelessWidget {
  final PreRegRequest request;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _DetailView({
    required this.request,
    required this.busy,
    required this.onBack,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    final status = preRegStatusOf(r);
    final pending = status == PreRegStatus.pending;
    return PageScaffold(
      title: r.fullName.isEmpty ? 'Demande' : r.fullName,
      subtitle: '${r.level} · réf. ${r.reference}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

        Row(children: [
          _StatusPill(status: status),
          const Spacer(),
          Text(r.reference,
              style: TextStyle(
                  fontSize: 12,
                  color: context.cInk,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),

        if (pending) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionButton(
                label: 'Refuser',
                icon: Icons.close_rounded,
                onTap: busy ? null : onReject),
            ActionButton(
                label: 'Accepter',
                icon: Icons.check_rounded,
                primary: true,
                onTap: busy ? null : onAccept),
          ]),
          const SizedBox(height: 14),
        ] else if (status == PreRegStatus.rejected && (r.note ?? '').isNotEmpty) ...[
          DataPanel(
            title: 'Motif du refus',
            child: Text(r.note!, style: TextStyle(fontSize: 12.5, color: context.cInk)),
          ),
          const SizedBox(height: 14),
        ],

        DataPanel(
          title: 'Tuteur / contact',
          child: Column(children: [
            _Row(label: 'Responsable', value: r.guardianName),
            _Row(label: 'Téléphone', value: r.guardianPhone),
            _Row(label: 'Email', value: r.guardianEmail),
          ]),
        ),
        const SizedBox(height: 14),

        DataPanel(
          title: 'Informations soumises',
          child: Column(children: [
            for (final f in EnrollmentFields.all)
              if ((r.payload[f.id] as String?)?.trim().isNotEmpty ?? false)
                (f.type == FieldType.photo || f.type == FieldType.file)
                    ? _DocumentRow(
                        label: f.label, storagePath: r.payload[f.id] as String)
                    : _Row(label: f.label, value: r.payload[f.id] as String),
          ]),
        ),
      ]),
    );
  }
}

/// Ligne "pièce jointe" : le payload ne contient qu'un chemin de stockage
/// (bucket privé `enrollment-documents`) — on génère une URL signée à la
/// demande plutôt que d'en garder une en cache (elle expire au bout d'1 h).
class _DocumentRow extends StatefulWidget {
  final String label;
  final String storagePath;
  const _DocumentRow({required this.label, required this.storagePath});

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _loading = false;

  Future<void> _open(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final url =
          await SupabaseDbSource.getEnrollmentDocumentUrl(widget.storagePath);
      if (!mounted) return;
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible d\'ouvrir le document.'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 150,
          child: Text(widget.label,
              style: TextStyle(fontSize: 12, color: context.cMuted)),
        ),
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _loading ? null : () => _open(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _loading
                    ? const SizedBox(
                        height: 13, width: 13,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.attach_file_rounded, size: 15, color: _terra),
                const SizedBox(width: 6),
                const Text('Voir la pièce jointe',
                    style: TextStyle(
                        fontSize: 12.5, color: _terra, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ]),
    );
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

/// La file de ré-inscription : les décisions de fin d'année (`proposed`) en
/// attente. Chemin UNIVERSEL (Simple/Pro/Max) — aucune dépendance à un compte
/// famille. Résumé de ce qui existe déjà, pas un formulaire : l'élève a son
/// dossier, il n'y a que la décision à confirmer (ou annuler).
class _ReRegistrationTab extends ConsumerWidget {
  const _ReRegistrationTab();

  Future<void> _confirm(BuildContext context, WidgetRef ref, SbProgression p,
      List<SbClass> classes) async {
    String? overrideClassId = p.toClassId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirmer pour ${p.studentName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.isExit
                  ? 'Sortie de l\'école (${_decisionLabel(p.decision)})'
                      '${p.reason?.isNotEmpty == true ? ' — ${p.reason}' : ''}.'
                  : 'Passe en année ${p.toAcademicYear ?? '—'}.'),
              if (!p.isExit) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: overrideClassId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Classe de destination',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [for (final c in classes)
                    DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => overrideClassId = v),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                  'Ce geste applique enfin le changement — rien n\'était '
                  'encore fait jusqu\'ici.',
                  style: TextStyle(fontSize: 11.5, color: context.cMuted)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: (!p.isExit && (overrideClassId == null || overrideClassId!.isEmpty))
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseDbSource.confirmReRegistration(p.id,
          newToClassId: p.isExit ? null : overrideClassId);
      ref.invalidate(pendingReRegistrationsProvider);
      ref.invalidate(usersProvider);
      ref.invalidate(studentsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('Ré-inscription confirmée pour ${p.studentName}.'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, SbProgression p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler cette décision ?'),
        content: Text(
            'Rien n\'a été appliqué pour ${p.studentName} — la décision sera '
            'juste marquée annulée. Vous pourrez en reprendre une nouvelle '
            'depuis « Passage de classe ».'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Retour')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Annuler la décision'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseDbSource.cancelReRegistration(p.id);
      ref.invalidate(pendingReRegistrationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  static String _decisionLabel(String d) => switch (d) {
        'transferred' => 'Transféré',
        'graduated' => 'Diplômé',
        'withdrawn' => 'Radiation',
        'repeated' => 'Redouble',
        _ => 'Passe',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingReRegistrationsProvider);
    final classes = ref.watch(classesProvider).valueOrNull ?? const <SbClass>[];
    String classNameOf(String? id) =>
        classes.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? '—';

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.move_up_outlined,
            title: 'Aucune ré-inscription en attente',
            description:
                'Les décisions prises dans « Passage de classe » apparaîtront ici.',
          );
        }
        return DataPanel(
          title: 'À confirmer',
          child: DataTablePanel(
            columns: const ['Élève', 'Décision', 'De → Vers', 'Moyenne', ''],
            flex: const [3, 2, 3, 1, 2],
            rows: [
              for (final p in items)
                [
                  Row(children: [
                    Avatar(name: p.studentName, size: 24),
                    const SizedBox(width: 8),
                    Flexible(child: Text(p.studentName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.cInk, fontSize: 12.5,
                            fontWeight: FontWeight.w600))),
                  ]),
                  Text(_decisionLabel(p.decision),
                      style: TextStyle(fontSize: 12, color: context.cMuted)),
                  Text(
                      p.isExit
                          ? classNameOf(p.fromClassId)
                          : '${classNameOf(p.fromClassId)} → ${classNameOf(p.toClassId)}',
                      style: TextStyle(fontSize: 11.5, color: context.cMuted)),
                  Text(p.average == null ? '—' : p.average!.toStringAsFixed(2),
                      style: TextStyle(fontSize: 12, color: context.cMuted)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: 'Confirmer',
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        color: _green,
                        onPressed: () => _confirm(context, ref, p, classes)),
                    IconButton(
                        tooltip: 'Annuler',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: _terra,
                        onPressed: () => _cancel(context, ref, p)),
                  ]),
                ],
            ],
          ),
        );
      },
    );
  }
}
