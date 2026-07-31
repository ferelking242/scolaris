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
              : LayoutBuilder(builder: (_, constraints) {
                  // Sous ~640px, 5 colonnes à flex fixe écrasent le nom de la
                  // classe et le bouton « Élèves » — on bascule sur des cartes.
                  if (constraints.maxWidth < 640) {
                    return Column(children: [
                      for (final cl in classes) ...[
                        _ClassCard(
                          cl: cl,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ClassRosterPage(cl: cl),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ]);
                  }
                  return DataTablePanel(
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
                  );
                }),
        ),
        );
      },
    );
  }
}

// ── Carte mobile d'une classe (remplace la ligne de `DataTablePanel`) ───────
class _ClassCard extends StatelessWidget {
  final SbClass cl;
  final VoidCallback onOpen;
  const _ClassCard({required this.cl, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cl.name,
                    style: const TextStyle(
                        color: ink, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if ((cl.level ?? '').isNotEmpty) _Tag(cl.level!),
                  if ((cl.section ?? '').isNotEmpty) _Tag(cl.section!),
                  _Tag('${cl.maxStudents} places max'),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: muted),
          ]),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final SbStudent student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Avatar(name: student.fullName, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(student.fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(student.matricule ?? '—',
                style: const TextStyle(fontSize: 11.5, color: muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: student.actif ? const Color(0xFFE8F5E9) : subtleBg,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(student.actif ? 'Actif' : 'Inactif',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: student.actif ? const Color(0xFF1B5E20) : muted)),
        ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: subtleBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      );
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
              : LayoutBuilder(builder: (_, constraints) {
                  // Sous ~640px, l'avatar + le nom se tronquent vite à côté du
                  // matricule et du statut — on bascule sur des cartes.
                  if (constraints.maxWidth < 640) {
                    return Column(children: [
                      for (final s in students) ...[
                        _StudentCard(student: s),
                        const SizedBox(height: 8),
                      ],
                    ]);
                  }
                  return DataTablePanel(
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
                  );
                }),
        ),
      ),
    );
  }
}
