import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class AdminClassesPage extends ConsumerWidget {
  const AdminClassesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Classes & sections',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Classes & sections',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (classes) => PageScaffold(
        title: 'Classes & sections',
        subtitle: '${classes.length} classes dans l\'établissement',
        actions: [
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
              ? const _EmptyState()
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
                        _CapacityBar(max: cl.maxStudents),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _IconBtn(
                                icon: Icons.edit_outlined, onTap: () {}),
                            const SizedBox(width: 6),
                            _IconBtn(
                                icon: Icons.people_outline_rounded,
                                onTap: () {}),
                          ]),
                        ),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Aucune classe créée.',
              style: TextStyle(color: muted, fontSize: 14)),
        ),
      );
}

class _CapacityBar extends StatelessWidget {
  final int max;
  const _CapacityBar({required this.max});
  @override
  Widget build(BuildContext context) => Text('/ $max',
      style: const TextStyle(fontSize: 12, color: muted));
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: muted),
        ),
      );
}
