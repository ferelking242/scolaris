import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold = ScolarisPalette.gold;
const _green = ScolarisPalette.forestGreen;

// ── Modèles ───────────────────────────────────────────────────────────────────
class _SubjectStat {
  final String matiere;
  final double moyenne;
  final double min;
  final double max;
  const _SubjectStat({
    required this.matiere,
    required this.moyenne,
    required this.min,
    required this.max,
  });
}

class _StudentStat {
  final String name;
  final double moyenne;
  const _StudentStat({required this.name, required this.moyenne});
}

class _ClassData {
  final String name;
  final int effectif;
  final double moyenne;
  final int nbSubjects;
  final double reussite;
  final List<_SubjectStat> subjects;
  final List<_StudentStat> topStudents;
  final List<_StudentStat> lowStudents;
  const _ClassData({
    required this.name,
    required this.effectif,
    required this.moyenne,
    required this.nbSubjects,
    required this.reussite,
    required this.subjects,
    required this.topStudents,
    required this.lowStudents,
  });
}

/// Calcule les stats réelles d'une classe à partir des notes + élèves.
_ClassData _compute(
    String className, List<SbGrade> grades, List<SbStudent> students) {
  final byStudent = <String, List<double>>{};
  for (final g in grades) {
    (byStudent[g.studentId] ??= []).add(g.outOf20);
  }
  final graded = <_StudentStat>[];
  for (final s in students) {
    final l = byStudent[s.id];
    if (l != null && l.isNotEmpty) {
      graded.add(_StudentStat(
          name: s.fullName, moyenne: l.reduce((a, b) => a + b) / l.length));
    }
  }
  graded.sort((a, b) => b.moyenne.compareTo(a.moyenne));

  final classMoy = graded.isEmpty
      ? 0.0
      : graded.map((e) => e.moyenne).reduce((a, b) => a + b) / graded.length;
  final reussite = graded.isEmpty
      ? 0.0
      : graded.where((e) => e.moyenne >= 10).length / graded.length;

  final bySubj = <String, List<double>>{};
  for (final g in grades) {
    (bySubj[g.subjectName ?? '—'] ??= []).add(g.outOf20);
  }
  final subjects = bySubj.entries.map((e) {
    final l = e.value;
    return _SubjectStat(
      matiere: e.key,
      moyenne: l.reduce((a, b) => a + b) / l.length,
      min: l.reduce((a, b) => a < b ? a : b),
      max: l.reduce((a, b) => a > b ? a : b),
    );
  }).toList();

  return _ClassData(
    name: className,
    effectif: students.length,
    moyenne: classMoy,
    nbSubjects: subjects.length,
    reussite: reussite,
    subjects: subjects,
    topStudents: graded.take(3).toList(),
    lowStudents: graded.reversed.take(2).toList(),
  );
}

/// Statistiques de classe côté staff : contrairement à l'ancienne page prof
/// (retirée de son menu, limitée à ses classes assignées), ici toutes les
/// classes de l'école sont sélectionnables — la direction/les rapports
/// veulent voir l'ensemble, pas juste ce qu'un enseignant enseigne.
class AdminClassStatsPage extends ConsumerStatefulWidget {
  const AdminClassStatsPage({super.key});
  @override
  ConsumerState<AdminClassStatsPage> createState() =>
      _AdminClassStatsPageState();
}

class _AdminClassStatsPageState extends ConsumerState<AdminClassStatsPage> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final classes = classesAsync.valueOrNull;

    Future<void> refreshClasses() async {
      ref.invalidate(classesProvider);
      await ref.read(classesProvider.future);
    }

    if (classes == null) {
      return PageScaffold(
        title: 'Statistiques de classe',
        onRefresh: refreshClasses,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (classes.isEmpty) {
      return PageScaffold(
        title: 'Statistiques de classe',
        onRefresh: refreshClasses,
        child: const Center(child: Text('Aucune classe dans cette école.')),
      );
    }

    if (_selectedClassId == null ||
        !classes.any((c) => c.id == _selectedClassId)) {
      _selectedClassId = classes.first.id;
    }
    final selectedClass = classes.firstWhere((c) => c.id == _selectedClassId);

    final gradesAsync = ref.watch(gradesForClassProvider(selectedClass.id));
    final studentsAsync =
        ref.watch(studentsByClassProvider(selectedClass.name));

    Future<void> refresh() async {
      ref.invalidate(classesProvider);
      ref.invalidate(gradesForClassProvider(selectedClass.id));
      ref.invalidate(studentsByClassProvider(selectedClass.name));
      await Future.wait([
        ref.read(classesProvider.future),
        ref.read(gradesForClassProvider(selectedClass.id).future),
        ref.read(studentsByClassProvider(selectedClass.name).future),
      ]);
    }

    return PageScaffold(
      title: 'Statistiques de classe',
      subtitle: 'Analyse des performances — données réelles',
      onRefresh: refresh,
      child: Column(children: [
        _ClassPicker(
          classes: classes,
          selectedId: _selectedClassId,
          onChanged: (id) => setState(() => _selectedClassId = id),
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final grades = gradesAsync.valueOrNull;
          final students = studentsAsync.valueOrNull;
          if (grades == null || students == null) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (grades.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 44, color: context.cBorder),
                    const SizedBox(height: 12),
                    Text('Aucune note saisie pour cette classe.',
                        style: TextStyle(color: context.cMuted)),
                  ],
                ),
              ),
            );
          }
          final d = _compute(selectedClass.name, grades, students);
          return Column(children: [
            _KpiRow(data: d),
            const SizedBox(height: 14),
            _SubjectBarsCard(subjects: d.subjects),
            const SizedBox(height: 14),
            if (d.topStudents.isNotEmpty)
              _RankingCard(
                  title: 'Top élèves', students: d.topStudents, isTop: true),
            const SizedBox(height: 10),
            if (d.lowStudents.isNotEmpty)
              _RankingCard(
                  title: 'En difficulté',
                  students: d.lowStudents,
                  isTop: false),
          ]);
        }),
      ]),
    );
  }
}

// ── Sélecteur de classe ─────────────────────────────────────────────────────
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
                    color: selectedId == c.id ? _terra : context.cMuted,
                    fontWeight:
                        selectedId == c.id ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
}

// ── KPI row ────────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final _ClassData data;
  const _KpiRow({required this.data});
  @override
  Widget build(BuildContext context) {
    final kpis = [
      (data.moyenne.toStringAsFixed(1), 'Moyenne', _terra, Icons.grade_rounded),
      ('${(data.reussite * 100).toInt()}%', 'Réussite', _orange,
          Icons.check_circle_rounded),
      ('${data.effectif}', 'Élèves', _gold, Icons.groups_rounded),
      ('${data.nbSubjects}', 'Matières', _green, Icons.menu_book_rounded),
    ];
    return Row(
        children: kpis.asMap().entries.map((e) {
      final isLast = e.key == kpis.length - 1;
      final kpi = e.value;
      return Expanded(
          child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.cBorder),
          ),
          child: Column(children: [
            Icon(kpi.$4, size: 20, color: kpi.$3),
            const SizedBox(height: 6),
            Text(kpi.$1,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: kpi.$3)),
            Text(kpi.$2,
                style: TextStyle(
                    fontSize: 10.5,
                    color: context.cMuted,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ));
    }).toList());
  }
}

// ── Subject bars ───────────────────────────────────────────────────────────────
class _SubjectBarsCard extends StatelessWidget {
  final List<_SubjectStat> subjects;
  const _SubjectBarsCard({required this.subjects});
  @override
  Widget build(BuildContext context) {
    final sorted = [...subjects]..sort((a, b) => b.moyenne.compareTo(a.moyenne));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Moyennes par matière',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: context.cInk)),
        const SizedBox(height: 14),
        ...sorted.map((s) {
          final pct = (s.moyenne / 20).clamp(0.0, 1.0);
          final color =
              s.moyenne >= 14 ? _green : s.moyenne >= 12 ? _orange : _terra;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(s.matiere,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: context.cInk,
                            fontWeight: FontWeight.w600))),
                Text(s.moyenne.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                Text('/20',
                    style: TextStyle(fontSize: 11, color: context.cMuted)),
                const SizedBox(width: 8),
                Text('(${s.min.toStringAsFixed(1)}–${s.max.toStringAsFixed(1)})',
                    style: TextStyle(
                        fontSize: 10, color: context.cMuted.withValues(alpha: .7))),
              ]),
              const SizedBox(height: 5),
              Stack(children: [
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Ranking card ───────────────────────────────────────────────────────────────
class _RankingCard extends StatelessWidget {
  final String title;
  final List<_StudentStat> students;
  final bool isTop;
  const _RankingCard(
      {required this.title, required this.students, required this.isTop});
  @override
  Widget build(BuildContext context) {
    final color = isTop ? _green : _terra;
    final icon = isTop ? Icons.emoji_events_rounded : Icons.warning_amber_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(title,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 10),
        ...students.asMap().entries.map((e) {
          final rank = e.key + 1;
          final s = e.value;
          final moy = s.moyenne;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .1), shape: BoxShape.circle),
                child: Center(
                    child: Text('$rank',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(s.name,
                      style: TextStyle(
                          color: context.cInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(moy.toStringAsFixed(2),
                    style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
