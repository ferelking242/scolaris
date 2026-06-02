import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final gradesAsync = session != null
        ? ref.watch(gradesForStudentProvider(session.id))
        : const AsyncValue<List<SbGrade>>.data([]);

    return gradesAsync.when(
      loading: () => const PageScaffold(
        title: 'Mes notes',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Mes notes',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (grades) {
        final avg = grades.isEmpty
            ? 0.0
            : grades.fold<double>(0, (s, g) => s + g.outOf20) / grades.length;
        final best = grades.isEmpty
            ? null
            : grades.reduce((a, b) => a.outOf20 >= b.outOf20 ? a : b);

        return PageScaffold(
          title: 'Mes notes',
          subtitle: '${grades.isEmpty ? "Aucun" : grades.length} résultat(s)',
          actions: [
            ActionButton(
                label: 'Export PDF',
                icon: Icons.download_rounded,
                onTap: () {}),
          ],
          child: grades.isEmpty
              ? const _EmptyGrades()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: _MetricCard(
                        label: 'Moyenne générale',
                        value: avg.toStringAsFixed(1),
                        unit: '/ 20',
                        color: avg >= 14 ? _green : avg >= 10 ? _gold : _terra,
                        icon: Icons.grading_rounded,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _MetricCard(
                        label: 'Meilleure matière',
                        value: best?.subjectName?.split(' ').first ?? '—',
                        unit: best != null
                            ? '${best.outOf20.toStringAsFixed(1)}/20'
                            : '',
                        color: _green,
                        icon: Icons.emoji_events_outlined,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _MetricCard(
                        label: 'Nombre de notes',
                        value: '${grades.length}',
                        unit: 'enregistrées',
                        color: _terra,
                        icon: Icons.format_list_numbered_rounded,
                      )),
                    ]),
                    const SizedBox(height: 16),
                    _GradesList(grades: grades),
                  ],
                ),
        );
      },
    );
  }
}

class _EmptyGrades extends StatelessWidget {
  const _EmptyGrades();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grading_rounded, size: 48, color: _gold),
              SizedBox(height: 12),
              Text('Aucune note disponible',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _terra)),
              SizedBox(height: 4),
              Text('Vos notes apparaîtront ici.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF7A5C44))),
            ],
          ),
        ),
      );
}

class _GradesList extends StatelessWidget {
  final List<SbGrade> grades;
  const _GradesList({required this.grades});

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: 'Toutes les notes',
      child: DataTablePanel(
        columns: const ['Matière', 'Type', 'Période', 'Note', '/ Max'],
        flex: const [3, 2, 2, 2, 1],
        rows: [
          for (final g in grades)
            [
              Text(g.subjectName ?? g.title ?? '—',
                  style: const TextStyle(
                      color: ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
              Text(g.type ?? '—',
                  style: const TextStyle(fontSize: 12, color: muted)),
              Text(g.period ?? '—',
                  style: const TextStyle(fontSize: 12, color: muted)),
              Text(
                g.score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: g.outOf20 >= 14
                      ? _green
                      : g.outOf20 >= 10
                          ? _gold
                          : _terra,
                ),
              ),
              Text(g.maxScore.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 12, color: muted)),
            ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDCCBB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    style: const TextStyle(fontSize: 11, color: muted))),
          ]),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color)),
                TextSpan(
                    text: '  $unit',
                    style: const TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
        ]),
      );
}
