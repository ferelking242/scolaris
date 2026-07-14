import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/services/print_service.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);
const _orange = Color(0xFFD4540A);

// ── Calcul partagé (mêmes règles que le bulletin élève) ──────────────────────
class _BulletinRow {
  final String matiere;
  final int coef;
  final double moyenne;
  final String appreciation;
  const _BulletinRow({
    required this.matiere,
    required this.coef,
    required this.moyenne,
    required this.appreciation,
  });
}

String _mention(double moy) {
  if (moy >= 16) return 'Très Bien';
  if (moy >= 14) return 'Bien';
  if (moy >= 12) return 'Assez Bien';
  if (moy >= 10) return 'Passable';
  return 'Insuffisant';
}

Color _mentionColor(double moy) {
  if (moy >= 16) return _green;
  if (moy >= 14) return const Color(0xFF0EA5E9);
  if (moy >= 12) return _gold;
  if (moy >= 10) return _orange;
  return _terra;
}

String _autoAppreciation(double avg) {
  if (avg >= 16) return 'Excellent travail, continuez sur cette lancée';
  if (avg >= 14) return 'Très bon résultat ce semestre';
  if (avg >= 12) return 'Bon niveau, peut encore progresser';
  if (avg >= 10) return 'Résultat passable, des efforts sont nécessaires';
  return 'Résultat insuffisant, un travail important est requis';
}

/// Lignes du bulletin d'un élève pour une période, à partir des notes de la
/// classe et du **programme de sa classe** (ses cours).
///
/// Le programme, et non le catalogue de l'école : le lycée enseigne la
/// philosophie, le CM2 non — son bulletin ne doit pas en porter la trace. Et le
/// coefficient est celui de la matière **dans cette classe** : les maths pèsent
/// 5 en série C, 2 en série A (cf. 20260739).
List<_BulletinRow> _rowsFor(
    String studentId, List<SbGrade> classGrades, List<SbCourse> programme, String period) {
  final g = classGrades
      .where((x) => x.studentId == studentId && x.period == period)
      .toList();
  final bySubject = <String, List<SbGrade>>{};
  for (final x in g) {
    if (x.subjectId == null) continue;
    (bySubject[x.subjectId!] ??= []).add(x);
  }
  final rows = <_BulletinRow>[];
  for (final cours in programme) {
    final grades = bySubject[cours.subjectId];
    if (grades == null || grades.isEmpty) continue;
    final avg = grades.fold(0.0, (s, x) => s + x.outOf20) / grades.length;
    final comment = grades
        .where((x) => x.comment != null && x.comment!.isNotEmpty)
        .lastOrNull
        ?.comment;
    rows.add(_BulletinRow(
      matiere: cours.name,
      coef: cours.coefficient,
      moyenne: avg,
      appreciation: comment ?? _autoAppreciation(avg),
    ));
  }
  return rows;
}

double _generalAvg(List<_BulletinRow> rows) {
  if (rows.isEmpty) return 0;
  final totalPts = rows.fold(0.0, (s, r) => s + r.moyenne * r.coef);
  final totalCoef = rows.fold(0, (s, r) => s + r.coef);
  return totalCoef > 0 ? totalPts / totalCoef : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE — Notes & Bulletins (supervision admin sur toutes les classes)
// ─────────────────────────────────────────────────────────────────────────────
class AdminGradesPage extends ConsumerStatefulWidget {
  const AdminGradesPage({super.key});
  @override
  ConsumerState<AdminGradesPage> createState() => _AdminGradesPageState();
}

class _AdminGradesPageState extends ConsumerState<AdminGradesPage> {
  String? _classId;
  // Null tant que l'école n'est pas chargée : trimestres ou semestres, c'est
  // elle qui décide (cf. SchoolFormat).
  String? _selectedPeriod;
  SbStudent? _bulletinStudent; // fiche bulletin inline (null = liste)

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(schoolFormatProvider);
    final period = _selectedPeriod ?? fmt.periods.first;
    final classesAsync = ref.watch(classesProvider);

    return classesAsync.when(
      loading: () => const PageScaffold(
          title: 'Notes & Bulletins',
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => PageScaffold(
          title: 'Notes & Bulletins',
          child: Center(child: Text('Erreur : $e'))),
      data: (classes) {
        if (classes.isNotEmpty && _classId == null) _classId = classes.first.id;
        final selected = classes.isEmpty
            ? null
            : classes.firstWhere((c) => c.id == _classId,
                orElse: () => classes.first);

        // Bulletin inline : remplace la liste par la fiche de l'élève.
        if (_bulletinStudent != null) {
          return _StudentBulletinPage(
            student: _bulletinStudent!,
            className: selected?.name ?? '',
            classId: selected?.id ?? '',
            period: period,
            onBack: () => setState(() => _bulletinStudent = null),
          );
        }

        return PageScaffold(
          title: 'Notes & Bulletins',
          subtitle: 'Consulter les moyennes et bulletins de toutes les classes',
          child: classes.isEmpty
              ? const _Empty(
                  icon: Icons.class_outlined,
                  text: 'Aucune classe. Créez des classes pour suivre les notes.')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _ClassChips(
                    classes: classes,
                    selectedId: _classId,
                    onChanged: (id) => setState(() => _classId = id),
                  ),
                  const SizedBox(height: 12),
                  _PeriodChips(
                    value: period,
                    periods: fmt.periods,
                    labelOf: fmt.periodLabel,
                    onChanged: (p) => setState(() => _selectedPeriod = p),
                  ),
                  const SizedBox(height: 14),
                  if (selected != null)
                    _ClassGradesPanel(
                      key: ValueKey('${selected.id}|$period'),
                      classObj: selected,
                      period: period,
                      onOpen: (s) => setState(() => _bulletinStudent = s),
                    ),
                ]),
        );
      },
    );
  }
}

// ── Tableau des moyennes de la classe ────────────────────────────────────────
class _ClassGradesPanel extends ConsumerWidget {
  final SbClass classObj;
  final String period;
  final void Function(SbStudent) onOpen;
  const _ClassGradesPanel(
      {super.key,
      required this.classObj,
      required this.period,
      required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsByClassProvider(classObj.name));
    final gradesAsync = ref.watch(gradesForClassProvider(classObj.id));
    final subjectsAsync = ref.watch(coursesForClassProvider(classObj.id));

    if (studentsAsync.isLoading || gradesAsync.isLoading || subjectsAsync.isLoading) {
      return const DataPanel(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final students = studentsAsync.valueOrNull ?? const [];
    final grades = gradesAsync.valueOrNull ?? const [];
    final subjects = subjectsAsync.valueOrNull ?? const [];

    if (students.isEmpty) {
      return const _Empty(
          icon: Icons.group_off_rounded,
          text: 'Aucun élève dans cette classe.');
    }

    // Pré-calcul des moyennes pour trier (meilleur → moins bon).
    final computed = [
      for (final s in students)
        (
          student: s,
          rows: _rowsFor(s.id, grades, subjects, period),
        )
    ]..sort((a, b) {
        final avgA = a.rows.isEmpty ? -1.0 : _generalAvg(a.rows);
        final avgB = b.rows.isEmpty ? -1.0 : _generalAvg(b.rows);
        return avgB.compareTo(avgA);
      });

    final withGrades = computed.where((c) => c.rows.isNotEmpty).length;

    return DataPanel(
      title: '${classObj.name} — $withGrades/${students.length} élève(s) noté(s)',
      child: DataTablePanel(
        columns: const ['#', 'Élève', 'Moy. générale', 'Mention', ''],
        flex: const [1, 4, 2, 3, 1],
        rows: [
          for (var i = 0; i < computed.length; i++)
            _row(context, i + 1, computed[i].student, computed[i].rows),
        ],
      ),
    );
  }

  List<Widget> _row(
      BuildContext context, int rank, SbStudent s, List<_BulletinRow> rows) {
    final hasGrades = rows.isNotEmpty;
    final avg = hasGrades ? _generalAvg(rows) : 0.0;
    final c = _mentionColor(avg);
    return [
      Text('$rank',
          style: TextStyle(fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
      Row(children: [
        Avatar(name: s.fullName, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(s.fullName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.cInk, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ]),
      hasGrades
          ? Text(avg.toStringAsFixed(2),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c))
          : Text('—', style: TextStyle(fontSize: 13, color: context.cMuted)),
      hasGrades
          ? Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_mention(avg),
                    style: TextStyle(
                        fontSize: 11, color: c, fontWeight: FontWeight.w700)),
              ),
            )
          : Text('Pas de notes',
              style: TextStyle(fontSize: 11, color: context.cMuted)),
      IconButton(
        icon: Icon(Icons.chevron_right_rounded, size: 20, color: context.cMuted),
        tooltip: 'Voir le bulletin',
        onPressed: () => onOpen(s),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulletin détaillé d'un élève (admin) — réutilise le calcul + impression PDF
// ─────────────────────────────────────────────────────────────────────────────
class _StudentBulletinPage extends ConsumerWidget {
  final SbStudent student;
  final String className;
  final String classId;
  final String period;
  final VoidCallback onBack;
  const _StudentBulletinPage({
    required this.student,
    required this.className,
    required this.classId,
    required this.period,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodLabel = ref.watch(schoolFormatProvider).periodLabel(period);
    final gradesAsync = ref.watch(gradesForStudentProvider(student.id));
    final subjectsAsync = ref.watch(coursesForClassProvider(classId));
    final school = ref.watch(schoolProvider).valueOrNull;

    return PageScaffold(
      title: 'Bulletin',
      subtitle: '${student.fullName} · $className · $periodLabel',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(label: 'Retour aux notes', onTap: onBack),
        const SizedBox(height: 14),
        gradesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
          ),
          data: (allGrades) {
            final subjects = subjectsAsync.valueOrNull ?? const [];
            final rows = _rowsFor(student.id, allGrades, subjects, period);
            final avg = _generalAvg(rows);

            return Column(children: [
              _InfoCard(
                name: student.fullName,
                classe: className,
                matricule: student.matricule,
                periodLabel: periodLabel,
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const _Empty(
                    icon: Icons.receipt_long_outlined,
                    text: 'Aucune note saisie pour cette période.')
              else ...[
                _GradesTable(rows: rows),
                const SizedBox(height: 14),
                _SummaryCard(avg: avg),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => PrintService.printBulletin(
                      studentName: student.fullName,
                      schoolName: school?.name ?? 'École',
                      period: periodLabel,
                      rows: rows
                          .map((r) => {
                                'subject': r.matiere,
                                'coef': r.coef,
                                'grade': r.moyenne,
                                'appreciation': r.appreciation,
                              })
                          .toList(),
                      average: avg,
                      mention: _mention(avg),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Télécharger le bulletin (PDF)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _terra,
                      side: const BorderSide(color: _terra),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ]);
          },
        ),
      ]),
    );
  }
}

// ── Sous-widgets ─────────────────────────────────────────────────────────────
class _ClassChips extends StatelessWidget {
  final List<SbClass> classes;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  const _ClassChips(
      {required this.classes, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
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
                  color: selectedId == c.id ? _terra : muted,
                  fontWeight:
                      selectedId == c.id ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
        ]),
      );
}

// Les périodes viennent de l'école : trimestres au lycée, semestres à
// l'université. Cf. SchoolFormat.
class _PeriodChips extends StatelessWidget {
  final String value;
  final List<String> periods;
  final String Function(String) labelOf;
  final ValueChanged<String> onChanged;
  const _PeriodChips({
    required this.value,
    required this.periods,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final p in periods)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(labelOf(p)),
            selected: value == p,
            onSelected: (_) => onChanged(p),
            selectedColor: _green.withValues(alpha: .12),
            labelStyle: TextStyle(
              fontSize: 12,
              color: value == p ? _green : muted,
              fontWeight: value == p ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  final String name;
  final String classe;
  final String? matricule;
  final String periodLabel;
  const _InfoCard(
      {required this.name,
      required this.classe,
      this.matricule,
      required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Avatar(name: name, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    color: context.cInk, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('$classe · $periodLabel',
                style: TextStyle(color: context.cMuted, fontSize: 11.5)),
            const SizedBox(height: 2),
            Text('Matricule : ${matricule ?? '—'}',
                style: TextStyle(color: context.cMuted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

class _GradesTable extends ConsumerWidget {
  final List<_BulletinRow> rows;
  const _GradesTable({required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Barème de l'école : /20, /100 ou lettres. Jamais figé — un bulletin
    // nigérian noté « 14/20 » ne veut rien dire là-bas.
    final fmt = ref.watch(schoolFormatProvider);
    final totalCoef = rows.fold(0, (s, r) => s + r.coef);
    final generalAvg = _generalAvg(rows);
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: _terra,
            borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            const Expanded(
                flex: 5,
                child: Text('Matière',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 1,
                child: Text('Coef',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 2,
                child: Text(fmt.gradeHeader,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
        ...rows.asMap().entries.map((e) {
          final r = e.value;
          final isEven = e.key % 2 == 0;
          final c = r.moyenne >= 14 ? _green : r.moyenne >= 10 ? _orange : _terra;
          return Container(
            color: isEven ? context.cSubtle : context.cCard,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    flex: 5,
                    child: Text(r.matiere,
                        style: TextStyle(
                            color: context.cInk, fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Center(
                        child: Text('${r.coef}',
                            style: const TextStyle(
                                color: _terra,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)))),
                Expanded(
                    flex: 2,
                    child: Center(
                        child: Text(r.moyenne.toStringAsFixed(1),
                            style: TextStyle(
                                color: c,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)))),
              ]),
              const SizedBox(height: 3),
              Text(r.appreciation,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: context.cMuted,
                      fontStyle: FontStyle.italic)),
            ]),
          );
        }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.cSubtle,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
          ),
          child: Row(children: [
            Expanded(
                flex: 5,
                child: Text('Moyenne Générale',
                    style: TextStyle(
                        color: context.cInk, fontSize: 13, fontWeight: FontWeight.w800))),
            Expanded(
                flex: 1,
                child: Center(
                    child: Text('$totalCoef',
                        style: TextStyle(
                            color: context.cMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)))),
            Expanded(
                flex: 2,
                child: Center(
                    child: Text(generalAvg.toStringAsFixed(2),
                        style: const TextStyle(
                            color: _terra,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)))),
          ]),
        ),
      ]),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  final double avg;
  const _SummaryCard({required this.avg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(schoolFormatProvider);
    final c = _mentionColor(avg);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: .08), c.withValues(alpha: .02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: .2)),
      ),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: c.withValues(alpha: .15), shape: BoxShape.circle),
          child: Center(
              child: Text(avg.toStringAsFixed(2),
                  style: TextStyle(
                      color: c, fontSize: 16, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mention : ${_mention(avg)}',
                style: TextStyle(
                    color: c, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fmt.ratio(avg),
                backgroundColor: c.withValues(alpha: .1),
                valueColor: AlwaysStoppedAnimation<Color>(c),
                minHeight: 5,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: context.cBorder),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.cMuted)),
        ]),
      );
}
