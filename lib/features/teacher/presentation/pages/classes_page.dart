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
    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Mes classes',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Mes classes',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (classes) => PageScaffold(
        title: 'Mes classes',
        subtitle:
            '${classes.length} classe(s) — ${classes.fold<int>(0, (a, b) => a + b.maxStudents)} places max',
        actions: [
          ActionButton(
              label: 'Filtrer', icon: Icons.filter_list_rounded, onTap: () {}),
          const SizedBox(width: 8),
          ActionButton(
              label: 'Nouvelle classe',
              icon: Icons.add_rounded,
              primary: true,
              onTap: () {}),
        ],
        child: DataPanel(
          title: 'Toutes les classes',
          headerActions: const [SearchInput(hint: 'Rechercher classe…')],
          child: classes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('Aucune classe.',
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
                              label: 'Ouvrir',
                              icon: Icons.arrow_forward_rounded,
                              onTap: () {}),
                        ),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}
