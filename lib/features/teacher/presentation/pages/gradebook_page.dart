import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

class GradebookPage extends ConsumerStatefulWidget {
  const GradebookPage({super.key});
  @override
  ConsumerState<GradebookPage> createState() => _GradebookPageState();
}

class _GradebookPageState extends ConsumerState<GradebookPage> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Carnet de notes',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Carnet de notes',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (classes) {
        if (classes.isNotEmpty && _selectedClassId == null) {
          _selectedClassId = classes.first.id;
        }
        final selectedClass = classes.isEmpty
            ? null
            : classes.firstWhere(
                (c) => c.id == _selectedClassId,
                orElse: () => classes.first,
              );

        return PageScaffold(
          title: 'Carnet de notes',
          subtitle: 'Saisir et consulter les notes de vos classes',
          actions: [
            ActionButton(
                label: 'Import CSV', icon: Icons.upload_rounded, onTap: () {}),
            const SizedBox(width: 8),
            ActionButton(
                label: 'Enregistrer',
                icon: Icons.check_rounded,
                primary: true,
                onTap: () {}),
          ],
          child: Column(children: [
            _ClassPicker(
              classes: classes,
              selectedId: _selectedClassId,
              onChanged: (id) => setState(() => _selectedClassId = id),
            ),
            const SizedBox(height: 12),
            if (selectedClass != null)
              _GradesPanel(classObj: selectedClass),
          ]),
        );
      },
    );
  }
}

class _GradesPanel extends ConsumerWidget {
  final SbClass classObj;
  const _GradesPanel({required this.classObj});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsByClassProvider(classObj.name));
    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur : $e'),
      data: (students) => DataPanel(
        title: '${classObj.name} — ${classObj.level ?? ""}',
        headerActions: const [SearchInput(hint: 'Rechercher élève…')],
        child: students.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Aucun élève dans cette classe.',
                        style: TextStyle(color: muted))),
              )
            : DataTablePanel(
                columns: const [
                  'Élève',
                  'Matricule',
                  'Interro 1',
                  'Interro 2',
                  'Examen',
                  'Moy.'
                ],
                flex: const [3, 2, 1, 1, 1, 1],
                rows: [
                  for (final s in students)
                    [
                      Row(children: [
                        Avatar(name: s.fullName, size: 22),
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
                          style:
                              const TextStyle(fontSize: 12, color: muted)),
                      _GradeInput(initial: null),
                      _GradeInput(initial: null),
                      _GradeInput(initial: null),
                      const Text('—',
                          style: TextStyle(
                              fontSize: 13,
                              color: ink,
                              fontWeight: FontWeight.w700)),
                    ],
                ],
              ),
      ),
    );
  }
}

class _ClassPicker extends StatelessWidget {
  final List<SbClass> classes;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  const _ClassPicker(
      {required this.classes,
      required this.selectedId,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in classes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.name),
                  selected: selectedId == c.id,
                  onSelected: (_) => onChanged(c.id),
                  selectedColor:
                      const Color(0xFF8B1A00).withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selectedId == c.id
                        ? const Color(0xFF8B1A00)
                        : muted,
                    fontWeight: selectedId == c.id
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _GradeInput extends StatefulWidget {
  final double? initial;
  const _GradeInput({this.initial});
  @override
  State<_GradeInput> createState() => _GradeInputState();
}

class _GradeInputState extends State<_GradeInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.initial != null ? widget.initial!.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12, color: ink),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFFDDCCBB))),
          ),
        ),
      );
}
