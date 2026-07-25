import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/pdf/reports_pdf.dart';
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

    // ── Tendance de recouvrement par période (exclusif Max) ─────────────────
    // `period` (ex. '2025-09') est déjà écrit sur chaque facture par le
    // système de scolarité — un simple regroupement suffit, pas besoin d'une
    // nouvelle donnée : c'est pour ça qu'on peut l'offrir en Max sans backend
    // dédié.
    final byPeriod = <String, ({double billed, double collected})>{};
    for (final i in invoices) {
      final p = i.period ?? 'Sans période';
      final entry = byPeriod[p] ?? (billed: 0.0, collected: 0.0);
      byPeriod[p] = (
        billed: entry.billed + i.amount,
        collected: entry.collected + i.amountPaid,
      );
    }
    final periods = byPeriod.keys.toList()..sort();
    final recentPeriods =
        periods.length > 6 ? periods.sublist(periods.length - 6) : periods;
    final trendRows = [
      for (final p in recentPeriods)
        (
          period: p,
          billed: byPeriod[p]!.billed,
          collected: byPeriod[p]!.collected,
        ),
    ];

    // ── Retards par classe (exclusif Max) ────────────────────────────────────
    // Jointure en mémoire invoice.studentId → student.classId/classe — pas de
    // nouvelle donnée serveur, juste une agrégation plus poussée des mêmes
    // factures.
    final classById = {for (final s in students) s.id: s};
    final lateByClass = <String, double>{};
    for (final i in invoices) {
      if (!i.isLate) continue;
      final className = classById[i.studentId]?.classe ?? 'Sans classe';
      lateByClass[className] = (lateByClass[className] ?? 0) + i.balance;
    }
    final classLateRows = lateByClass.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Top des retards par élève (exclusif Max) ─────────────────────────────
    final lateByStudent = <String, double>{};
    final studentLabel = <String, String>{};
    for (final i in invoices) {
      if (!i.isLate) continue;
      final key = i.studentId ?? i.studentName ?? i.id;
      lateByStudent[key] = (lateByStudent[key] ?? 0) + i.balance;
      final st = classById[i.studentId];
      studentLabel[key] =
          i.studentName ?? (st != null ? '${st.prenom} ${st.nom}' : 'Élève inconnu');
    }
    final topLateRows = (lateByStudent.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(8)
        .map((e) => (
              label: studentLabel[e.key] ?? 'Élève inconnu',
              className: classById[e.key]?.classe ?? '—',
              amount: e.value,
            ))
        .toList();

    // ── Répartition par catégorie (exclusif Max) ─────────────────────────────
    final byCategory = <String, ({double billed, double collected})>{};
    for (final i in invoices) {
      final cat = i.category ?? 'Autre';
      final entry = byCategory[cat] ?? (billed: 0.0, collected: 0.0);
      byCategory[cat] = (
        billed: entry.billed + i.amount,
        collected: entry.collected + i.amountPaid,
      );
    }
    final categoryRows = byCategory.entries
        .map((e) => (
              category: e.key,
              billed: e.value.billed,
              collected: e.value.collected,
            ))
        .toList()
      ..sort((a, b) => b.billed.compareTo(a.billed));

    final planCode = ref.watch(currentPlanCodeProvider).valueOrNull;
    // Même seuil que le PlanGateBanner plus bas — une seule notion de
    // "rapports avancés", pas une condition ad hoc dupliquée.
    final canExport = planMeetsRequirement(planCode, 'pro');
    final isMax = planMeetsRequirement(planCode, 'max');
    final school = ref.watch(schoolProvider).valueOrNull;

    return PageScaffold(
      title: 'Rapports',
      subtitle: 'Vue d\'ensemble de l\'établissement',
      actions: [
        if (canExport)
          ActionButton(
            label: 'Exporter (PDF)',
            icon: Icons.picture_as_pdf_outlined,
            primary: true,
            onTap: () => printReportsPdf(
              school: school,
              classRows: classRows,
              finances: (
                collected: collected,
                pending: pending,
                overdue: overdue,
                billed: billed,
              ),
              studentsCount: students.length,
              teachersCount: teachers,
              unassigned: unassigned,
              trendRows: isMax ? trendRows : null,
              lateByClassRows: isMax ? classLateRows : null,
              topLateRows: isMax ? topLateRows : null,
            ),
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
              : LayoutBuilder(builder: (_, constraints) {
                  if (constraints.maxWidth < 640) {
                    return Column(children: [
                      for (final r in classRows) _ClassRow(row: r),
                    ]);
                  }
                  return DataTablePanel(
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
                  );
                }),
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
        const SizedBox(height: 14),
        PlanGate(
          minPlan: 'max',
          featureLabel: 'Rapport Premium',
          description:
              'Analyses financières avancées : tendance, retards par classe, '
              'top des impayés, répartition par catégorie.',
          icon: Icons.workspace_premium_rounded,
          child: Column(children: [
            _PremiumTrendPanel(rows: trendRows, fmt: fmt),
            const SizedBox(height: 14),
            _PremiumLateByClassPanel(rows: classLateRows, fmt: fmt),
            const SizedBox(height: 14),
            _PremiumTopLatePanel(rows: topLateRows, fmt: fmt),
            const SizedBox(height: 14),
            _PremiumCategoryPanel(rows: categoryRows, fmt: fmt),
          ]),
        ),
      ]),
    );
  }

}

/// Carte compacte pour une classe — remplace la ligne du tableau sous 640px.
class _ClassRow extends StatelessWidget {
  final ({String name, String level, int count, int capacity}) row;
  const _ClassRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final r = row;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.cInk, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          Text(r.level, style: TextStyle(fontSize: 11.5, color: context.cMuted)),
          const SizedBox(width: 8),
          Text('${r.count} / ${r.capacity}',
              style: TextStyle(
                  fontSize: 12.5, color: context.cInk, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        _FillBar(count: r.count, capacity: r.capacity),
      ]),
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

/// Badge "Offre Max" — répété sur chaque volet du Rapport Premium.
Widget _maxBadge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text('Offre Max',
          style: TextStyle(
              fontSize: 10, color: Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
    );

/// Rapport Premium (Max) : évolution du recouvrement période par période,
/// à partir des mêmes factures que le reste de la page — pas une donnée à
/// part, juste un regroupement plus poussé.
class _PremiumTrendPanel extends StatelessWidget {
  final List<({String period, double billed, double collected})> rows;
  final NumberFormat fmt;
  const _PremiumTrendPanel({required this.rows, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: 'Tendance de recouvrement',
      headerActions: [_maxBadge()],
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: Text('Aucune facture pour établir une tendance.',
                      style: TextStyle(color: context.cMuted))),
            )
          : Column(children: [
              for (final r in rows) ...[
                _PeriodTrendRow(row: r, fmt: fmt),
                if (r != rows.last) const SizedBox(height: 10),
              ],
            ]),
    );
  }
}

class _PeriodTrendRow extends StatelessWidget {
  final ({String period, double billed, double collected}) row;
  final NumberFormat fmt;
  const _PeriodTrendRow({required this.row, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final ratio = row.billed > 0 ? (row.collected / row.billed).clamp(0.0, 1.0) : 0.0;
    final color = ratio >= 0.85
        ? _green
        : ratio >= 0.5
            ? const Color(0xFFEA580C)
            : const Color(0xFFDC2626);
    return Row(children: [
      SizedBox(
        width: 70,
        child: Text(row.period,
            style: TextStyle(
                fontSize: 12, color: context.cInk, fontWeight: FontWeight.w700)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: context.cSubtle,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 46,
        child: Text('${(ratio * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 10),
      Text('${fmt.format(row.collected)} / ${fmt.format(row.billed)} F',
          style: TextStyle(fontSize: 11, color: context.cMuted)),
    ]);
  }
}

/// Rapport Premium (Max) : montant en retard cumulé par classe — jointure
/// invoice.studentId → student.classe, en mémoire, sur les mêmes factures.
class _PremiumLateByClassPanel extends StatelessWidget {
  final List<MapEntry<String, double>> rows;
  final NumberFormat fmt;
  const _PremiumLateByClassPanel({required this.rows, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: 'Retards par classe',
      headerActions: [_maxBadge()],
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: Text('Aucun retard actuellement — bravo.',
                      style: TextStyle(color: context.cMuted))),
            )
          : Column(children: [
              for (final r in rows.take(8)) ...[
                Row(children: [
                  Expanded(
                    child: Text(r.key,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: context.cInk,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text('${fmt.format(r.value)} F',
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700)),
                ]),
                if (r != rows.take(8).last) const SizedBox(height: 8),
              ],
            ]),
    );
  }
}

/// Rapport Premium (Max) : les élèves qui doivent le plus, pour cibler les
/// relances plutôt que de recontacter toute la liste.
class _PremiumTopLatePanel extends StatelessWidget {
  final List<({String label, String className, double amount})> rows;
  final NumberFormat fmt;
  const _PremiumTopLatePanel({required this.rows, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: 'Top des impayés',
      headerActions: [_maxBadge()],
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: Text('Aucun impayé actuellement.',
                      style: TextStyle(color: context.cMuted))),
            )
          : Column(children: [
              for (var idx = 0; idx < rows.length; idx++) ...[
                Row(children: [
                  SizedBox(
                    width: 20,
                    child: Text('${idx + 1}',
                        style: TextStyle(fontSize: 11, color: context.cMuted, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rows[idx].label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: context.cInk,
                              fontWeight: FontWeight.w600)),
                      Text(rows[idx].className,
                          style: TextStyle(fontSize: 10.5, color: context.cMuted)),
                    ]),
                  ),
                  Text('${fmt.format(rows[idx].amount)} F',
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700)),
                ]),
                if (idx < rows.length - 1) const SizedBox(height: 10),
              ],
            ]),
    );
  }
}

/// Rapport Premium (Max) : facturé/encaissé regroupé par catégorie de
/// facture (scolarité, cantine, transport…) — même logique que la tendance
/// par période, mais un autre axe de lecture.
class _PremiumCategoryPanel extends StatelessWidget {
  final List<({String category, double billed, double collected})> rows;
  final NumberFormat fmt;
  const _PremiumCategoryPanel({required this.rows, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: 'Répartition par catégorie',
      headerActions: [_maxBadge()],
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: Text('Aucune facture pour l\'instant.',
                      style: TextStyle(color: context.cMuted))),
            )
          : Column(children: [
              for (final r in rows) ...[
                _PeriodTrendRow(
                    row: (period: r.category, billed: r.billed, collected: r.collected),
                    fmt: fmt),
                if (r != rows.last) const SizedBox(height: 10),
              ],
            ]),
    );
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
