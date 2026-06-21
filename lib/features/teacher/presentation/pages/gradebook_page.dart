import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);

const _types = ['interro1', 'interro2', 'examen'];

class GradebookPage extends ConsumerStatefulWidget {
  const GradebookPage({super.key});
  @override
  ConsumerState<GradebookPage> createState() => _GradebookPageState();
}

class _GradebookPageState extends ConsumerState<GradebookPage> {
  String? _selectedClassId;
  String? _selectedSubjectId;
  String _selectedPeriod = 'S1';

  @override
  Widget build(BuildContext context) {
    final schoolId  = ref.watch(currentSchoolIdProvider);
    final teacherId = ref.watch(authSessionProvider)?.id;
    final classesAsync  = ref.watch(classesProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
          title: 'Carnet de notes',
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => PageScaffold(
          title: 'Carnet de notes',
          child: Center(child: Text('Erreur : $e'))),
      data: (classes) {
        if (classes.isNotEmpty && _selectedClassId == null) {
          _selectedClassId = classes.first.id;
        }
        final selectedClass = classes.isEmpty
            ? null
            : classes.firstWhere((c) => c.id == _selectedClassId,
                orElse: () => classes.first);

        return PageScaffold(
          title: 'Carnet de notes',
          subtitle: 'Saisir et consulter les notes de vos classes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sélecteur de classe ─────────────────────────────────────
              _ClassPicker(
                classes: classes,
                selectedId: _selectedClassId,
                onChanged: (id) => setState(() {
                  _selectedClassId = id;
                  _selectedSubjectId = null;
                }),
              ),
              const SizedBox(height: 12),

              // ── Sélecteur matière + période ─────────────────────────────
              subjectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (subjects) => Row(children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedSubjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Matière',
                        prefixIcon: Icon(Icons.menu_book_outlined),
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        for (final s in subjects)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedSubjectId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _PeriodPicker(
                      value: _selectedPeriod,
                      onChanged: (p) => setState(() => _selectedPeriod = p),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Tableau de notes ────────────────────────────────────────
              if (selectedClass != null &&
                  _selectedSubjectId != null &&
                  schoolId != null)
                _GradesPanel(
                  key: ValueKey(
                      '${selectedClass.id}|$_selectedSubjectId|$_selectedPeriod'),
                  classObj: selectedClass,
                  subjectId: _selectedSubjectId!,
                  period: _selectedPeriod,
                  schoolId: schoolId,
                  teacherId: teacherId,
                )
              else
                DataPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.grading_rounded,
                              size: 40, color: Color(0xFFDDCCBB)),
                          SizedBox(height: 10),
                          Text('Sélectionnez une matière pour saisir les notes.',
                              style: TextStyle(
                                  color: Color(0xFF7A5C44), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sélecteur de classe (chips) ───────────────────────────────────────────────
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
                  selectedColor: _terra.withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selectedId == c.id ? _terra : const Color(0xFF7A5C44),
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

// ── Sélecteur de période (S1 / S2 / S3) ──────────────────────────────────────
class _PeriodPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PeriodPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const periods = ['S1', 'S2', 'S3'];
    const labels  = ['Semestre 1', 'Semestre 2', 'Semestre 3'];
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Période',
        prefixIcon: Icon(Icons.date_range_outlined),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        for (var i = 0; i < periods.length; i++)
          DropdownMenuItem(
              value: periods[i], child: Text(labels[i])),
      ],
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

// ── Panneau de notes ──────────────────────────────────────────────────────────
class _GradesPanel extends ConsumerStatefulWidget {
  final SbClass classObj;
  final String subjectId;
  final String period;
  final String schoolId;
  final String? teacherId;

  const _GradesPanel({
    super.key,
    required this.classObj,
    required this.subjectId,
    required this.period,
    required this.schoolId,
    this.teacherId,
  });

  @override
  ConsumerState<_GradesPanel> createState() => _GradesPanelState();
}

class _GradesPanelState extends ConsumerState<_GradesPanel> {
  // studentId → type → controller
  final Map<String, Map<String, TextEditingController>> _ctrls = {};
  List<SbGrade> _loadedGrades = [];
  bool _gradesLoaded = false;
  bool _saving = false;

  String get _key =>
      '${widget.classObj.id}|${widget.subjectId}|${widget.period}';

  @override
  void dispose() {
    for (final m in _ctrls.values) {
      for (final c in m.values) { c.dispose(); }
    }
    super.dispose();
  }

  void _seedGrades(List<SbGrade> grades) {
    if (_gradesLoaded) return;
    _gradesLoaded = true;
    _loadedGrades = grades;
  }

  TextEditingController _ctrl(String studentId, String type) {
    _ctrls[studentId] ??= {};
    if (_ctrls[studentId]![type] == null) {
      final existing = _loadedGrades
          .where((g) => g.studentId == studentId && g.type == type)
          .firstOrNull;
      _ctrls[studentId]![type] = TextEditingController(
        text: existing != null ? existing.score.toStringAsFixed(1) : '',
      );
    }
    return _ctrls[studentId]![type]!;
  }

  double? _avg(String studentId) {
    final m = _ctrls[studentId];
    if (m == null) return null;
    final vals = m.values
        .map((c) => double.tryParse(c.text.trim().replaceAll(',', '.')))
        .whereType<double>()
        .toList();
    if (vals.isEmpty) return null;
    return vals.fold(0.0, (s, v) => s + v) / vals.length;
  }

  Future<void> _save(List<SbStudent> students) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final s in students) {
        for (final type in _types) {
          final raw =
              _ctrls[s.id]?[type]?.text.trim().replaceAll(',', '.') ?? '';
          if (raw.isEmpty) continue;
          final score = double.tryParse(raw);
          if (score == null) continue;
          await SupabaseDbSource.upsertGrade(
            studentId: s.id,
            classId: widget.classObj.id,
            schoolId: widget.schoolId,
            subjectId: widget.subjectId,
            score: score.clamp(0.0, 20.0),
            period: widget.period,
            type: type,
            teacherId: widget.teacherId,
          );
        }
      }
      ref.invalidate(gradesForClassSubjectPeriodProvider(_key));
      ref.invalidate(gradesForStudentProvider);
      ref.invalidate(myGradesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Notes enregistrées avec succès'),
        ]),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _terra,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync =
        ref.watch(studentsByClassProvider(widget.classObj.name));
    final gradesAsync =
        ref.watch(gradesForClassSubjectPeriodProvider(_key));

    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur élèves : $e'),
      data: (students) {
        // Seed grades once when loaded
        if (gradesAsync is AsyncData<List<SbGrade>>) {
          _seedGrades(gradesAsync.value);
        }

        return DataPanel(
          title: '${widget.classObj.name} — ${widget.classObj.level ?? ''}',
          child: students.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Aucun élève dans cette classe.',
                        style: TextStyle(color: Color(0xFF7A5C44))),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gradesAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                    DataTablePanel(
                      columns: const [
                        'Élève',
                        'Matricule',
                        'Interro 1',
                        'Interro 2',
                        'Examen',
                        'Moy.',
                      ],
                      flex: const [3, 2, 1, 1, 1, 1],
                      rows: [
                        for (final s in students)
                          [
                            Row(children: [
                              Avatar(name: s.fullName, size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  s.fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]),
                            Text(s.matricule ?? '—',
                                style: const TextStyle(
                                    fontSize: 12, color: muted)),
                            _GradeInput(
                              controller: _ctrl(s.id, 'interro1'),
                              onChanged: () => setState(() {}),
                            ),
                            _GradeInput(
                              controller: _ctrl(s.id, 'interro2'),
                              onChanged: () => setState(() {}),
                            ),
                            _GradeInput(
                              controller: _ctrl(s.id, 'examen'),
                              onChanged: () => setState(() {}),
                            ),
                            Builder(builder: (_) {
                              final avg = _avg(s.id);
                              if (avg == null) {
                                return const Text('—',
                                    style: TextStyle(
                                        fontSize: 13, color: muted));
                              }
                              return Text(
                                avg.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: avg >= 14
                                      ? _green
                                      : avg >= 10
                                          ? _gold
                                          : _terra,
                                ),
                              );
                            }),
                          ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _save(students),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_saving
                            ? 'Enregistrement…'
                            : 'Enregistrer les notes'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _terra,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ── Champ de saisie note ──────────────────────────────────────────────────────
class _GradeInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  const _GradeInput({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        child: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged?.call(),
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
