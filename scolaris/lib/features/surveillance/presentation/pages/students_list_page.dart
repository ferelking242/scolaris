import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class StudentsListPage extends ConsumerWidget {
  const StudentsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    return studentsAsync.when(
      loading: () => const PageScaffold(
        title: 'Annuaire élèves',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Annuaire élèves',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (students) => _StudentsListContent(students: students),
    );
  }
}

class _StudentsListContent extends StatefulWidget {
  final List<SbStudent> students;
  const _StudentsListContent({required this.students});
  @override
  State<_StudentsListContent> createState() => _StudentsListContentState();
}

class _StudentsListContentState extends State<_StudentsListContent> {
  String _search = '';

  List<SbStudent> get _filtered {
    if (_search.isEmpty) return widget.students;
    final q = _search.toLowerCase();
    return widget.students.where((s) =>
      s.fullName.toLowerCase().contains(q) ||
      (s.matricule?.toLowerCase().contains(q) ?? false) ||
      (s.classe?.toLowerCase().contains(q) ?? false),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final students = _filtered;
    return PageScaffold(
      title: 'Annuaire élèves',
      subtitle: '${widget.students.length} élèves inscrits cette année',
      actions: [
        ActionButton(label: 'Filtrer', icon: Icons.filter_list_rounded, onTap: () {}),
        const SizedBox(width: 8),
        ActionButton(
            label: 'Exporter',
            icon: Icons.file_download_outlined,
            primary: true,
            onTap: () {}),
      ],
      child: DataPanel(
        title: 'Tous les élèves',
        headerActions: [
          SearchInput(
            hint: 'Rechercher élève…',
            onChanged: (v) => setState(() => _search = v),
          ),
        ],
        child: DataTablePanel(
          columns: const ['Nom', 'Matricule', 'Classe', 'Niveau', ''],
          flex: const [3, 2, 2, 2, 1],
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
                Text(s.classe ?? '—',
                    style: const TextStyle(fontSize: 12, color: ink)),
                Text(s.niveau ?? '—',
                    style: const TextStyle(fontSize: 12, color: muted)),
                const SizedBox.shrink(),
              ],
          ],
        ),
      ),
    );
  }
}
