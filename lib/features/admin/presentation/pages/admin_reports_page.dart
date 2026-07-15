import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/plan_gate.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF16A34A);

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    final classesAsync = ref.watch(classesProvider);
    final usersAsync = ref.watch(usersProvider);
    final invoicesAsync = ref.watch(invoicesProvider);

    final loading = studentsAsync.isLoading ||
        classesAsync.isLoading ||
        usersAsync.isLoading ||
        invoicesAsync.isLoading;

    if (loading) {
      return const PageScaffold(
        title: 'Rapports',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final students = studentsAsync.valueOrNull ?? const [];
    final classes = classesAsync.valueOrNull ?? const [];
    final users = usersAsync.valueOrNull ?? const [];
    final invoices = invoicesAsync.valueOrNull ?? const [];

    // ── Effectifs par classe ────────────────────────────────────────────────
    final byClass = <String, int>{};
    for (final s in students) {
      if (s.classId != null) byClass[s.classId!] = (byClass[s.classId!] ?? 0) + 1;
    }
    final classRows = [
      for (final c in classes)
        (
          name: c.name,
          level: c.level ?? '—',
          count: byClass[c.id] ?? 0,
          capacity: c.maxStudents,
        )
    ];
    final unassigned = students.where((s) => s.classId == null).length;

    // ── Finances ────────────────────────────────────────────────────────────
    final collected =
        invoices.where((i) => i.isPaid).fold<double>(0, (a, b) => a + b.amount);
    // Buckets exclusifs : « en retard » sur isLate (échéance dépassée impayée),
    // « en attente » = impayé pas encore échu — sinon double comptage.
    final overdue = invoices
        .where((i) => i.isLate)
        .fold<double>(0, (a, b) => a + b.amount);
    final pending = invoices
        .where((i) => !i.isPaid && !i.isLate && i.status != 'cancelled')
        .fold<double>(0, (a, b) => a + b.amount);
    final billed = collected + pending + overdue;
    final recovery = billed > 0 ? (collected / billed * 100) : 0.0;

    final teachers = users.where((u) => u.role == 'teacher').length;
    final fmt = NumberFormat.decimalPattern('fr');

    final canExport =
        ref.watch(currentPlanCodeProvider).valueOrNull != 'simple';

    return PageScaffold(
      title: 'Rapports',
      subtitle: 'Vue d\'ensemble de l\'établissement',
      actions: [
        if (canExport)
          ActionButton(
            label: 'Exporter (CSV)',
            icon: Icons.file_download_outlined,
            primary: true,
            onTap: () => _exportCsv(context, classRows, fmt),
          ),
      ],
      child: Column(children: [
        // ── Métriques clés ────────────────────────────────────────────────
        DataPanel(
          title: 'Indicateurs clés',
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            _Tile(
                label: 'Élèves inscrits',
                value: '${students.length}',
                icon: Icons.group_rounded),
            _Tile(
                label: 'Classes',
                value: '${classes.length}',
                icon: Icons.class_rounded),
            _Tile(
                label: 'Enseignants',
                value: '$teachers',
                icon: Icons.co_present_rounded),
            _Tile(
                label: 'Sans classe',
                value: '$unassigned',
                icon: Icons.person_off_rounded,
                color: unassigned > 0 ? _terra : null),
            _Tile(
                label: 'Taux de recouvrement',
                value: '${recovery.toStringAsFixed(0)}%',
                icon: Icons.savings_rounded,
                color: _green),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Finances ──────────────────────────────────────────────────────
        DataPanel(
          title: 'Finances (scolarité)',
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            _Tile(
                label: 'Encaissé',
                value: '${fmt.format(collected)} F',
                icon: Icons.check_circle_outline_rounded,
                color: _green),
            _Tile(
                label: 'En attente',
                value: '${fmt.format(pending)} F',
                icon: Icons.schedule_rounded,
                color: const Color(0xFFEA580C)),
            _Tile(
                label: 'En retard',
                value: '${fmt.format(overdue)} F',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFDC2626)),
            _Tile(
                label: 'Total facturé',
                value: '${fmt.format(billed)} F',
                icon: Icons.receipt_long_rounded),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Effectifs par classe ──────────────────────────────────────────
        DataPanel(
          title: 'Effectifs par classe',
          child: classRows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: Text('Aucune classe.',
                          style: TextStyle(color: context.cMuted))),
                )
              : DataTablePanel(
                  columns: const ['Classe', 'Niveau', 'Effectif', 'Remplissage'],
                  flex: const [3, 2, 2, 3],
                  rows: [
                    for (final r in classRows)
                      [
                        Text(r.name,
                            style: TextStyle(
                                color: context.cInk,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        Text(r.level,
                            style:
                                TextStyle(fontSize: 12, color: context.cMuted)),
                        Text('${r.count} / ${r.capacity}',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: context.cInk,
                                fontWeight: FontWeight.w700)),
                        _FillBar(count: r.count, capacity: r.capacity),
                      ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        const PlanGateBanner(
          minPlan: 'pro',
          featureLabel: 'Rapports avancés & export',
          description: 'Analyses détaillées, taux de recouvrement et exports CSV.',
          icon: Icons.analytics_outlined,
          bullets: [
            'Export CSV des effectifs et finances',
            'Rapport de présences par classe',
            'Suivi des paiements et retards',
            'Tableau de bord financier mensuel',
          ],
        ),
      ]),
    );
  }

  void _exportCsv(
    BuildContext context,
    List<({String name, String level, int count, int capacity})> rows,
    NumberFormat fmt,
  ) {
    final buf = StringBuffer('Classe,Niveau,Effectif,Capacité\n');
    for (final r in rows) {
      buf.writeln('"${r.name}","${r.level}",${r.count},${r.capacity}');
    }
    final csv = buf.toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Export CSV — Effectifs'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Copiez ce texte et collez-le dans Excel / Google Sheets '
                  '(données séparées par des virgules).',
                  style: TextStyle(fontSize: 12, color: context.cMuted)),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(csv,
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12, color: context.cInk)),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer')),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('CSV copié dans le presse-papier.'),
                behavior: SnackBarBehavior.floating,
              ));
            },
            style: FilledButton.styleFrom(backgroundColor: _terra),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copier'),
          ),
        ],
      ),
    );
  }
}

class _FillBar extends StatelessWidget {
  final int count;
  final int capacity;
  const _FillBar({required this.count, required this.capacity});
  @override
  Widget build(BuildContext context) {
    final ratio = capacity > 0 ? (count / capacity).clamp(0.0, 1.0) : 0.0;
    final color = ratio >= 1.0
        ? const Color(0xFFDC2626)
        : ratio >= 0.85
            ? const Color(0xFFEA580C)
            : _green;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: const Color(0xFFEDE3D6),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${(ratio * 100).toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _Tile(
      {required this.label,
      required this.value,
      required this.icon,
      this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cInk;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.cCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.cBorder),
            ),
            child: Icon(icon, size: 16, color: color ?? context.cMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: context.cMuted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17, color: c, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
