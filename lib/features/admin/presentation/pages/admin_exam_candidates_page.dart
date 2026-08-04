import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);

/// Liste des élèves des classes repérées « classe d'examen » (ex. CM2 →
/// CEPE, cf. [examCandidatesProvider]) — utile pour préparer le dossier de
/// candidature (effectif exact, dates de naissance) sans dépouiller les
/// classes une par une.
class AdminExamCandidatesPage extends ConsumerWidget {
  const AdminExamCandidatesPage({super.key});

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(examCandidatesProvider);
    Future<void> refresh() async {
      ref.invalidate(examCandidatesProvider);
      await ref.read(examCandidatesProvider.future);
    }
    return candidatesAsync.when(
      loading: () => PageScaffold(
        onRefresh: refresh,
        title: 'Candidats examen',
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        onRefresh: refresh,
        title: 'Candidats examen',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (groups) {
        final total = groups.fold<int>(0, (s, g) => s + g.$2.length);
        return PageScaffold(
          onRefresh: refresh,
          title: 'Candidats examen',
          subtitle: total > 0
              ? '$total candidat(s) dans ${groups.length} classe(s)'
              : null,
          child: groups.isEmpty
              ? const _EmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final g in groups) ...[
                      _ClassCandidates(klass: g.$1, students: g.$2),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _ClassCandidates extends StatelessWidget {
  final SbClass klass;
  final List<SbStudent> students;
  const _ClassCandidates({required this.klass, required this.students});

  @override
  Widget build(BuildContext context) {
    return DataPanel(
      title: '${klass.name} · ${students.length} candidat(s)',
      child: students.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Aucun élève dans cette classe pour l\'instant.',
                  style: TextStyle(color: context.cMuted)),
            )
          : LayoutBuilder(builder: (_, constraints) {
              if (constraints.maxWidth < 640) {
                return Column(children: [
                  for (final s in students)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.cCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.cBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.fullName,
                              style: TextStyle(
                                  color: context.cInk,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                            '${s.id_} · Né(e) le ${AdminExamCandidatesPage._formatDate(s.dateOfBirth)}',
                            style: TextStyle(fontSize: 11.5, color: context.cMuted),
                          ),
                        ],
                      ),
                    ),
                ]);
              }
              return DataTablePanel(
                columns: const ['Nom complet', 'Matricule', 'Date de naissance'],
                flex: const [3, 2, 2],
                rows: [
                  for (final s in students)
                    [
                      Text(s.fullName,
                          style: TextStyle(
                              color: context.cInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text(s.id_,
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                      Text(AdminExamCandidatesPage._formatDate(s.dateOfBirth),
                          style: TextStyle(fontSize: 12, color: context.cMuted)),
                    ],
                ],
              );
            }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_turned_in_outlined,
              size: 52, color: context.cMuted.withValues(alpha: .5)),
          const SizedBox(height: 14),
          Text('Aucune classe d\'examen',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _terra)),
          const SizedBox(height: 6),
          Text(
            'Aucun niveau n\'est repéré comme classe d\'examen (ex. CM2 pour le '
            'CEPE), ou aucune classe n\'a encore été créée à ce niveau.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.cMuted),
          ),
        ]),
      ),
    );
  }
}
