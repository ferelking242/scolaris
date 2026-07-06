import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class TeacherClassesPage extends ConsumerWidget {
  const TeacherClassesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final assignAsync  = ref.watch(teacherAssignmentsProvider);
    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Mes classes',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Mes classes',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (allClasses) {
        // Scope : seulement les classes que ce prof enseigne.
        final assign = assignAsync.valueOrNull;
        if (assign == null) {
          return const PageScaffold(
            title: 'Mes classes',
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final classes =
            allClasses.where((c) => assign.teachesClass(c.id)).toList();
        return PageScaffold(
        title: 'Mes classes',
        subtitle:
            '${classes.length} classe(s) — ${classes.fold<int>(0, (a, b) => a + b.maxStudents)} places max',
        child: DataPanel(
          title: 'Mes classes',
          headerActions: const [SearchInput(hint: 'Rechercher classe…')],
          child: classes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('Aucune classe ne vous est assignée.',
                          style: TextStyle(color: muted))),
                )
              : DataTablePanel(
                  columns: const ['Classe', 'Niveau', 'Section', 'Capacité', ''],
                  flex: const [2, 3, 3, 2, 2],
                  rows: [
                    for (final cl in classes)
                      [
                        Text(cl.name,
                            style: const TextStyle(
                                color: ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text(cl.level ?? '—',
                            style: const TextStyle(fontSize: 12, color: muted)),
                        Text(cl.section ?? '—',
                            style: const TextStyle(fontSize: 12, color: muted)),
                        Text('${cl.maxStudents}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: ink,
                                fontWeight: FontWeight.w700)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ActionButton(
                              label: 'Élèves',
                              icon: Icons.arrow_forward_rounded,
                              onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _ClassRosterPage(cl: cl),
                                    ),
                                  )),
                        ),
                      ],
                  ],
                ),
        ),
        );
      },
    );
  }
}

// ── Liste des élèves d'une classe ─────────────────────────────────────────────
class _ClassRosterPage extends ConsumerWidget {
  final SbClass cl;
  const _ClassRosterPage({required this.cl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsByClassProvider(cl.name));
    return studentsAsync.when(
      loading: () => PageScaffold(
        title: cl.name,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: cl.name,
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (students) => PageScaffold(
        title: cl.name,
        subtitle:
            '${cl.level ?? ''} — ${students.length} élève(s)',
        child: DataPanel(
          title: 'Élèves de la classe',
          headerActions: const [SearchInput(hint: 'Rechercher élève…')],
          child: students.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('Aucun élève dans cette classe.',
                          style: TextStyle(color: muted))),
                )
              : DataTablePanel(
                  columns: const ['Élève', 'Matricule', 'Statut'],
                  flex: const [4, 3, 2],
                  rows: [
                    for (final s in students)
                      [
                        Row(children: [
                          Avatar(name: s.fullName, size: 24),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(s.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        Text(s.matricule ?? '—',
                            style: const TextStyle(fontSize: 12, color: muted)),
                        Text(s.actif ? 'Actif' : 'Inactif',
                            style: TextStyle(
                                fontSize: 12,
                                color: s.actif
                                    ? const Color(0xFF1B5E20)
                                    : muted)),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}
