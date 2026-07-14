import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/auth_providers.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);

/// Types d'évaluation — le vocabulaire de la BASE (contrainte grades_type_check :
/// devoir | examen | controle | tp | oral | projet). Le carnet parlait
/// « interro1/interro2 », que la base refusait : aucune note ne pouvait être
/// enregistrée. C'est le même vocabulaire que l'espace élève.
const _types = ['devoir', 'controle', 'examen'];
const _typeLabels = {
  'devoir': 'Devoir',
  'controle': 'Contrôle',
  'examen': 'Examen',
};

class GradebookPage extends ConsumerStatefulWidget {
  const GradebookPage({super.key});
  @override
  ConsumerState<GradebookPage> createState() => _GradebookPageState();
}

class _GradebookPageState extends ConsumerState<GradebookPage> {
  String? _selectedClassId;
  String? _selectedSubjectId;
  // Null tant que l'école n'est pas chargée : les périodes viennent d'elle
  // (trimestres ou semestres), pas d'une constante du code.
  String? _selectedPeriod;

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(schoolFormatProvider);
    final period = _selectedPeriod ?? fmt.periods.first;
    final schoolId  = ref.watch(currentSchoolIdProvider);
    final teacherId = ref.watch(authSessionProvider)?.id;
    final classesAsync  = ref.watch(classesProvider);
    final assignAsync   = ref.watch(teacherAssignmentsProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
          title: 'Carnet de notes',
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => PageScaffold(
          title: 'Carnet de notes',
          child: Center(child: Text('Erreur : $e'))),
      data: (allClasses) {
        // Scope : seulement les classes que ce prof enseigne réellement
        // (emploi du temps + statut de titulaire).
        final assign = assignAsync.valueOrNull;
        if (assign == null) {
          return const PageScaffold(
              title: 'Carnet de notes',
              child: Center(child: CircularProgressIndicator()));
        }
        final classes =
            allClasses.where((c) => assign.teachesClass(c.id)).toList();

        if (classes.isEmpty) {
          return const PageScaffold(
            title: 'Carnet de notes',
            subtitle: 'Saisir et consulter les notes de vos classes',
            child: DataPanel(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.school_outlined,
                        size: 40, color: Color(0xFFDDCCBB)),
                    SizedBox(height: 10),
                    Text('Aucune classe ne vous est assignée.',
                        style: TextStyle(
                            color: Color(0xFF7A5C44), fontSize: 13)),
                    SizedBox(height: 4),
                    Text(
                        "Contactez l'administration pour être affecté à un cours.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFFA98E76), fontSize: 11)),
                  ]),
                ),
              ),
            ),
          );
        }

        if (_selectedClassId == null ||
            !classes.any((c) => c.id == _selectedClassId)) {
          _selectedClassId = classes.first.id;
        }
        final selectedClass = classes.firstWhere((c) => c.id == _selectedClassId,
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
              //  Les matières viennent du PROGRAMME de la classe, pas du
              //  catalogue de l'école : le lycée enseigne la philosophie, le
              //  CM2 non. Le titulaire (primaire) les a toutes ; les autres
              //  seulement celles dont ils ont le cours.
              ref.watch(coursesForClassProvider(selectedClass.id)).when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (courses) {
                  final programme =
                      courses.where((c) => c.subjectId != null).toList();
                  final allowed = assign.isTitulaire(selectedClass.id)
                      ? programme
                      : programme
                          .where((c) => c.isTaughtBy(teacherId ?? ''))
                          .toList();
                  if (allowed.isEmpty) {
                    return const _NoSubjects();
                  }
                  return Row(children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: allowed.any((c) => c.subjectId == _selectedSubjectId)
                            ? _selectedSubjectId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Matière',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          for (final c in allowed)
                            DropdownMenuItem(
                                value: c.subjectId!, child: Text(c.name)),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedSubjectId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _PeriodPicker(
                        value: period,
                        periods: fmt.periods,
                        labelOf: fmt.periodLabel,
                        onChanged: (p) => setState(() => _selectedPeriod = p),
                      ),
                    ),
                  ]);
                },
              ),
              const SizedBox(height: 16),

              // ── Tableau de notes ────────────────────────────────────────
              if (_selectedSubjectId != null && schoolId != null)
                _GradesPanel(
                  key: ValueKey(
                      '${selectedClass.id}|$_selectedSubjectId|$period'),
                  classObj: selectedClass,
                  subjectId: _selectedSubjectId!,
                  period: period,
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

/// Le prof a la classe (titulaire ou cours) mais aucune matière à y enseigner.
/// Cas réel : on l'a rattaché à la classe sans lui donner de cours. Autant le
/// dire, plutôt que d'afficher un menu vide.
class _NoSubjects extends StatelessWidget {
  const _NoSubjects();

  @override
  Widget build(BuildContext context) => DataPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.menu_book_outlined,
                  size: 36, color: Color(0xFFDDCCBB)),
              const SizedBox(height: 10),
              Text('Aucune matière ne vous est confiée dans cette classe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.cMuted, fontSize: 13)),
            ]),
          ),
        ),
      );
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

// ── Sélecteur de période ─────────────────────────────────────────────────────
//  Les périodes viennent de l'école : trimestres (T1/T2/T3) au lycée, semestres
//  (S1/S2) à l'université. Cf. SchoolFormat.
class _PeriodPicker extends StatelessWidget {
  final String value;
  final List<String> periods;
  final String Function(String) labelOf;
  final ValueChanged<String> onChanged;
  const _PeriodPicker({
    required this.value,
    required this.periods,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Période',
        prefixIcon: Icon(Icons.date_range_outlined),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        for (final p in periods)
          DropdownMenuItem(value: p, child: Text(labelOf(p))),
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

  /// Barème de CETTE série d'évaluations. Chaque note porte son propre maximum
  /// (`grades.max_score`) : une interro sur 10 et un examen sur 20 coexistent
  /// sans fausser la moyenne, qui ramène tout à la même échelle avant de
  /// comparer. Défaut = barème de l'école, que le prof peut abaisser (10 au
  /// primaire, par exemple).
  double? _maxScore;
  double get _max => _maxScore ?? ref.read(schoolFormatProvider).maxScore;

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

  /// Note déjà enregistrée en base pour (élève, type) = **validée → verrouillée**.
  SbGrade? _existing(String studentId, String type) => _loadedGrades
      .where((g) => g.studentId == studentId && g.type == type)
      .firstOrNull;

  bool _isLocked(String studentId, String type) =>
      _existing(studentId, type) != null;

  /// Moyenne = notes verrouillées (base) + notes saisies non encore validées.
  ///
  /// Les notes déjà en base peuvent avoir un autre barème que celui affiché
  /// (une interro sur 10 dans une série sur 20) : on les ramène sur le barème
  /// courant avant de les mélanger.
  double? _avg(String studentId) {
    final vals = <double>[];
    for (final type in _types) {
      final existing = _existing(studentId, type);
      if (existing != null) {
        final m = existing.maxScore > 0 ? existing.maxScore : _max;
        vals.add(existing.score / m * _max);
        continue;
      }
      final c = _ctrls[studentId]?[type];
      final v = double.tryParse((c?.text ?? '').trim().replaceAll(',', '.'));
      if (v != null) vals.add(v);
    }
    if (vals.isEmpty) return null;
    return vals.fold(0.0, (s, v) => s + v) / vals.length;
  }

  /// Cellule : verrouillée si la note est déjà validée, ou si ce professeur n'a
  /// pas le droit de saisir (`notes.saisir`). Un directeur peut décider que
  /// chez lui les profs consultent sans noter — la base le refuserait de toute
  /// façon, autant ne pas afficher un champ qui mènera à une erreur.
  Widget _cell(String studentId, String type, {required bool canSaisir}) {
    final existing = _existing(studentId, type);
    if (existing != null) {
      return _LockedGrade(value: existing.score, max: existing.maxScore);
    }
    if (!canSaisir) {
      return Text('—',
          style: TextStyle(fontSize: 12.5, color: context.cMuted));
    }
    return _GradeInput(
      controller: _ctrl(studentId, type),
      onChanged: () => setState(() {}),
    );
  }

  /// Confirme la validation (action irréversible pour le prof) puis enregistre.
  Future<void> _confirmAndSave(List<SbStudent> students) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valider les notes ?'),
        content: const Text(
            'Une fois validées, ces notes ne pourront plus être modifiées. '
            'Pour corriger une note validée, contactez l’administration.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _terra),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Valider')),
        ],
      ),
    );
    if (ok == true) await _save(students);
  }

  Future<void> _save(List<SbStudent> students) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final s in students) {
        for (final type in _types) {
          // Note déjà validée → verrouillée, on n'y touche pas.
          if (_isLocked(s.id, type)) continue;
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
            score: score.clamp(0.0, _max),
            maxScore: _max,
            period: widget.period,
            type: type,
            teacherId: widget.teacherId,
          );
        }
      }
      // Recharge les notes → les nouvelles apparaissent désormais verrouillées.
      _gradesLoaded = false;
      ref.invalidate(gradesForClassSubjectPeriodProvider(_key));
      ref.invalidate(gradesForStudentProvider);
      ref.invalidate(myGradesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.lock_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Notes validées et verrouillées'),
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
    // Le rôle « Enseignant » est configurable comme les autres : un directeur
    // peut retirer `notes.saisir` à ses profs. La base le refuserait ; le
    // carnet, lui, affichait encore les champs et le bouton.
    final canSaisir = ref.watch(canProvider('notes.saisir'));

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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        const Icon(Icons.lock_rounded, size: 13, color: muted),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'Les notes validées sont verrouillées. Pour corriger une note, contactez l’administration.',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Noté sur',
                            style: TextStyle(fontSize: 11, color: muted)),
                        const SizedBox(width: 6),
                        DropdownButton<double>(
                          value: _max,
                          isDense: true,
                          underline: const SizedBox(),
                          style: const TextStyle(
                              fontSize: 12,
                              color: ink,
                              fontWeight: FontWeight.w700),
                          items: const [
                            DropdownMenuItem(value: 10.0, child: Text('10')),
                            DropdownMenuItem(value: 20.0, child: Text('20')),
                            DropdownMenuItem(value: 100.0, child: Text('100')),
                          ],
                          onChanged: (v) =>
                              setState(() => _maxScore = v ?? _max),
                        ),
                      ]),
                    ),
                    DataTablePanel(
                      columns: [
                        'Élève',
                        'Matricule',
                        for (final t in _types)
                          '${_typeLabels[t]} /${_max.toStringAsFixed(0)}',
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
                            for (final t in _types)
                              _cell(s.id, t, canSaisir: canSaisir),
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
                    if (!canSaisir)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.cBorder),
                        ),
                        child: Row(children: [
                          Icon(Icons.visibility_outlined,
                              size: 16, color: context.cMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Consultation seule : votre rôle ne vous autorise pas '
                              'à saisir de notes.',
                              style: TextStyle(
                                  fontSize: 12, color: context.cMuted),
                            ),
                          ),
                        ]),
                      )
                    else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _saving ? null : () => _confirmAndSave(students),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.lock_rounded, size: 18),
                        label: Text(_saving
                            ? 'Validation…'
                            : 'Valider les notes'),
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

// ── Note verrouillée (déjà validée, lecture seule) ────────────────────────────
class _LockedGrade extends StatelessWidget {
  final double value;
  // Le barème de la note telle qu'elle a été saisie : une note sur 10 reste sur
  // 10, même si la série affichée est sur 20.
  final double max;
  const _LockedGrade({required this.value, required this.max});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EAE0),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2D0C0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${value.toStringAsFixed(1)}/${max.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: ink,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 2),
              const Icon(Icons.lock_rounded, size: 10, color: muted),
            ],
          ),
        ),
      );
}
