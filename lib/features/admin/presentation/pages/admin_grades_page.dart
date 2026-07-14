import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../core/permissions/my_grants.dart';
import '../widgets/bulletin_view.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import 'report_cards_page.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);
const _orange = Color(0xFFD4540A);

// ── Le calcul du bulletin vit dans core/bulletin/bulletin_math.dart ─────────
//  Il y était autrefois ici, en double, et en FAUX : une moyenne arithmétique
//  de toutes les notes, quand le bulletin congolais pondère la composition.
//  Deux calculs pour une même moyenne, c'est la liste qui affiche 12,00 et le
//  bulletin 12,17. Il n'en reste qu'un, et il est testé.

/// La couleur d'une mention. Le libellé, lui, vient de [mentionOf] — une seule
/// source, partagée avec le bulletin et le PDF.
Color _mentionColor(double moy) {
  if (moy >= 16) return _green;
  if (moy >= 14) return const Color(0xFF0EA5E9);
  if (moy >= 12) return _gold;
  if (moy >= 10) return _orange;
  return _terra;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE — Notes & Bulletins (supervision admin sur toutes les classes)
// ─────────────────────────────────────────────────────────────────────────────
class AdminGradesPage extends ConsumerStatefulWidget {
  const AdminGradesPage({super.key});
  @override
  ConsumerState<AdminGradesPage> createState() => _AdminGradesPageState();
}

/// Les trois onglets de la page. Trois choses distinctes qu'on mélangeait :
///  • NOTES — le tableau brut d'une matière, corrigeable ;
///  • BULLETINS — la synthèse vivante d'un élève, imprimable ;
///  • GÉNÉRER — figer et publier aux familles, en fin de trimestre.
enum _Tab { notes, bulletins, generer }

class _AdminGradesPageState extends ConsumerState<AdminGradesPage> {
  _Tab _tab = _Tab.notes;
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

        // Bulletin inline : remplace tout par la fiche de l'élève.
        if (_bulletinStudent != null) {
          return _StudentBulletinPage(
            student: _bulletinStudent!,
            className: selected?.name ?? '',
            classId: selected?.id ?? '',
            period: period,
            onBack: () => setState(() => _bulletinStudent = null),
          );
        }

        if (classes.isEmpty) {
          return const PageScaffold(
            title: 'Notes & Bulletins',
            child: _Empty(
                icon: Icons.class_outlined,
                text: 'Aucune classe. Créez des classes pour suivre les notes.'),
          );
        }

        return PageScaffold(
          title: 'Notes & Bulletins',
          subtitle: switch (_tab) {
            _Tab.notes => 'Consulter et corriger les notes, matière par matière',
            _Tab.bulletins => 'Le bulletin de chaque élève',
            _Tab.generer => 'Figer et publier les bulletins aux familles',
          },
          // PageScaffold fait DÉJÀ défiler verticalement : ici, pas d'Expanded
          // ni de second SingleChildScrollView — ils recevraient une hauteur
          // infinie et feraient planter le rendu (« unbounded height »).
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _TabBar(value: _tab, onChanged: (t) => setState(() => _tab = t)),
            const SizedBox(height: 14),
            // La génération a son propre sélecteur de classe/période : on ne lui
            // impose pas ceux du haut.
            if (_tab == _Tab.generer)
              const ReportCardsPage(embedded: true)
            else ...[
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
                _tab == _Tab.notes
                    ? _AdminNotesPanel(
                        key: ValueKey('notes|${selected.id}|$period'),
                        classObj: selected,
                        period: period,
                      )
                    : _ClassGradesPanel(
                        key: ValueKey('bul|${selected.id}|$period'),
                        classObj: selected,
                        period: period,
                        onOpen: (s) => setState(() => _bulletinStudent = s),
                      ),
            ],
          ]),
        );
      },
    );
  }
}

/// Le basculement Notes / Bulletins / Générer.
class _TabBar extends StatelessWidget {
  final _Tab value;
  final ValueChanged<_Tab> onChanged;
  const _TabBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(_Tab t, String label, IconData icon) {
      final active = t == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? _terra : context.cSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? _terra : context.cBorder),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 16, color: active ? Colors.white : context.cMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : context.cMuted)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      tab(_Tab.notes, 'Notes', Icons.edit_note_rounded),
      const SizedBox(width: 8),
      tab(_Tab.bulletins, 'Bulletins', Icons.receipt_long_rounded),
      const SizedBox(width: 8),
      tab(_Tab.generer, 'Générer', Icons.workspace_premium_rounded),
    ]);
  }
}

// ── Onglet NOTES : le tableau brut d'une matière, corrigeable ────────────────
//  L'admin voyait des moyennes, jamais les notes elles-mêmes. Ici il choisit une
//  matière du programme et voit chaque élève, ses devoirs et sa composition — et
//  il peut CORRIGER, s'il a le droit `notes.corriger` (le fondateur l'a d'office).
class _AdminNotesPanel extends ConsumerStatefulWidget {
  final SbClass classObj;
  final String period;
  const _AdminNotesPanel(
      {super.key, required this.classObj, required this.period});
  @override
  ConsumerState<_AdminNotesPanel> createState() => _AdminNotesPanelState();
}

class _AdminNotesPanelState extends ConsumerState<_AdminNotesPanel> {
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesForClassProvider(widget.classObj.id));
    final schoolId = ref.watch(currentSchoolIdProvider);

    return coursesAsync.when(
      loading: () => const DataPanel(
          child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => _Empty(icon: Icons.error_outline, text: 'Erreur : $e'),
      data: (courses) {
        final programme = courses.where((c) => c.subjectId != null).toList();
        if (programme.isEmpty) {
          return const _Empty(
              icon: Icons.menu_book_outlined,
              text: 'Cette classe n’a aucune matière à son programme. '
                  'Ajoutez-les dans « Cours ».');
        }
        _subjectId ??= programme.first.subjectId;
        final course =
            programme.where((c) => c.subjectId == _subjectId).firstOrNull ??
                programme.first;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Sélecteur de matière — celles du programme, pas le catalogue école.
          DropdownButtonFormField<String>(
            value: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Matière',
              prefixIcon: Icon(Icons.menu_book_outlined),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: [
              for (final c in programme)
                DropdownMenuItem(value: c.subjectId, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 14),
          if (schoolId != null)
            _NotesGrid(
              key: ValueKey('${widget.classObj.id}|$_subjectId|${widget.period}'),
              classObj: widget.classObj,
              subjectId: _subjectId!,
              subjectName: course.name,
              period: widget.period,
              schoolId: schoolId,
            ),
        ]);
      },
    );
  }
}

/// Le tableau éditable d'une matière : chaque élève, ses devoirs et sa compo.
///
/// C'est le carnet du prof, mais pour l'admin et sur n'importe quelle classe.
/// La différence : l'admin peut **corriger une note verrouillée** (déjà saisie)
/// s'il a le droit `notes.corriger` — le fondateur l'a d'office. Sans ce droit,
/// il consulte, il ne touche pas : on garde le verrou du prof intact.
class _NotesGrid extends ConsumerStatefulWidget {
  final SbClass classObj;
  final String subjectId;
  final String subjectName;
  final String period;
  final String schoolId;
  const _NotesGrid({
    super.key,
    required this.classObj,
    required this.subjectId,
    required this.subjectName,
    required this.period,
    required this.schoolId,
  });
  @override
  ConsumerState<_NotesGrid> createState() => _NotesGridState();
}

class _NotesGridState extends ConsumerState<_NotesGrid> {
  // studentId → « type#seq » → contrôleur
  final Map<String, Map<String, TextEditingController>> _ctrls = {};
  bool _seeded = false;
  bool _saving = false;
  String _gradesKey = '';

  @override
  void dispose() {
    for (final m in _ctrls.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  TextEditingController _ctrl(String studentId, GradeSlot slot, double? initial) {
    _ctrls[studentId] ??= {};
    return _ctrls[studentId]!.putIfAbsent(
      '${slot.type}#${slot.seq}',
      () => TextEditingController(
          text: initial == null ? '' : initial.toStringAsFixed(1)),
    );
  }

  Future<void> _save(List<SbStudent> students, List<GradeSlot> slots,
      double maxScore) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    var n = 0;
    try {
      for (final s in students) {
        for (final slot in slots) {
          final raw = _ctrls[s.id]?['${slot.type}#${slot.seq}']
                  ?.text
                  .trim()
                  .replaceAll(',', '.') ??
              '';
          if (raw.isEmpty) continue;
          final score = double.tryParse(raw);
          if (score == null) continue;
          await SupabaseDbSource.upsertGrade(
            studentId: s.id,
            classId: widget.classObj.id,
            schoolId: widget.schoolId,
            subjectId: widget.subjectId,
            score: score.clamp(0.0, maxScore),
            maxScore: maxScore,
            period: widget.period,
            type: slot.type,
            sequence: slot.seq,
          );
          n++;
        }
      }
      // Recharge : notes, bulletins, tout ce qui en dépend.
      ref.invalidate(gradesForClassProvider(widget.classObj.id));
      ref.invalidate(classBulletinsProvider(
          '${widget.classObj.id}|${widget.period}'));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('$n note(s) enregistrée(s).'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Échec : $e'),
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
    final fmt = ref.watch(schoolFormatProvider);
    final maxScore = fmt.maxScore;
    final rules = BulletinRules.fromSchool(ref.watch(schoolProvider).valueOrNull);
    final slots = rules.slots;
    final studentsAsync = ref.watch(studentsByClassProvider(widget.classObj.name));
    final gradesAsync = ref.watch(gradesForClassProvider(widget.classObj.id));

    // Le fondateur a « * ». Sinon il faut `notes.corriger` pour toucher une note
    // déjà validée, et `notes.saisir` pour remplir une case vide.
    final canCorriger = ref.watch(canProvider('notes.corriger'));
    final canSaisir = canCorriger || ref.watch(canProvider('notes.saisir'));

    return studentsAsync.when(
      loading: () => const DataPanel(
          child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => _Empty(icon: Icons.error_outline, text: 'Erreur : $e'),
      data: (students) {
        if (students.isEmpty) {
          return const _Empty(
              icon: Icons.group_off_rounded,
              text: 'Aucun élève dans cette classe.');
        }

        final grades = (gradesAsync.valueOrNull ?? const <SbGrade>[])
            .where((g) =>
                g.subjectId == widget.subjectId && g.period == widget.period)
            .toList();

        // (Re)remplit les champs quand les notes chargées changent — pas à
        // chaque frame, sinon on écraserait la frappe en cours.
        final key = grades.map((g) => '${g.id}:${g.score}').join(',');
        if (!_seeded || key != _gradesKey) {
          _seeded = true;
          _gradesKey = key;
          for (final s in students) {
            for (final slot in slots) {
              final g = grades
                  .where((x) => x.type == slot.type && x.sequence == slot.seq
                      && x.studentId == s.id)
                  .firstOrNull;
              _ctrls[s.id] ??= {};
              final k = '${slot.type}#${slot.seq}';
              if (_ctrls[s.id]![k] == null) {
                _ctrls[s.id]![k] = TextEditingController(
                    text: g == null ? '' : g.score.toStringAsFixed(1));
              }
            }
          }
        }

        SbGrade? existing(String sid, GradeSlot slot) => grades
            .where((g) =>
                g.studentId == sid &&
                g.type == slot.type &&
                g.sequence == slot.seq)
            .firstOrNull;

        return DataPanel(
          title: '${widget.classObj.name} — ${widget.subjectName}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!canSaisir)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Consultation seule.',
                    style: TextStyle(fontSize: 12, color: context.cMuted)),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 48,
                columnSpacing: 20,
                headingTextStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: context.cMuted),
                columns: [
                  const DataColumn(label: Text('Élève')),
                  for (final slot in slots)
                    DataColumn(
                        label: Text('${slot.label}\n/${maxScore.toInt()}'),
                        numeric: true),
                ],
                rows: [
                  for (final s in students)
                    DataRow(cells: [
                      DataCell(SizedBox(
                        width: 150,
                        child: Text(s.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: context.cInk)),
                      )),
                      for (final slot in slots)
                        DataCell(_cell(s.id, slot, existing(s.id, slot),
                            canSaisir: canSaisir, canCorriger: canCorriger)),
                    ]),
                ],
              ),
            ),
            if (canSaisir) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _saving ? null : () => _save(students, slots, maxScore),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _terra,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }

  /// Une case. Verrouillée si la note existe déjà **et** que l'admin n'a pas le
  /// droit de corriger : on affiche alors la valeur, non modifiable, avec un
  /// cadenas discret.
  Widget _cell(String sid, GradeSlot slot, SbGrade? existing,
      {required bool canSaisir, required bool canCorriger}) {
    final locked = existing != null && !canCorriger;
    if (locked) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Text(existing.score.toStringAsFixed(1),
            style: TextStyle(fontSize: 12.5, color: context.cInk)),
        const SizedBox(width: 3),
        Icon(Icons.lock_outline_rounded, size: 12, color: context.cMuted),
      ]);
    }
    if (!canSaisir) {
      return Text(existing?.score.toStringAsFixed(1) ?? '—',
          style: TextStyle(fontSize: 12.5, color: context.cMuted));
    }
    return SizedBox(
      width: 46,
      child: TextField(
        controller: _ctrl(sid, slot, existing?.score),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: context.cInk),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          // Une note corrigée (déjà en base) : on la teinte, pour que l'admin
          // voie qu'il modifie un acquis, pas qu'il saisit du neuf.
          fillColor: existing != null ? _gold.withValues(alpha: .08) : null,
          filled: existing != null,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
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
    // Le MÊME calcul que le bulletin. Deux moyennes qui ne se parlent pas, c'est
    // la liste qui dit 12,00 et le bulletin 12,17 — et un parent qui appelle.
    final bulletinsAsync =
        ref.watch(classBulletinsProvider('${classObj.id}|$period'));

    if (studentsAsync.isLoading || bulletinsAsync.isLoading) {
      return const DataPanel(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final students = studentsAsync.valueOrNull ?? const <SbStudent>[];
    final bulletins = bulletinsAsync.valueOrNull ?? const <String, Bulletin>{};

    if (students.isEmpty) {
      return const _Empty(
          icon: Icons.group_off_rounded,
          text: 'Aucun élève dans cette classe.');
    }

    // Le rang vient du calcul, pas de la position dans la liste : deux élèves
    // ex æquo portent le même rang.
    final sorted = [...students]..sort((a, b) {
        final ba = bulletins[a.id], bb = bulletins[b.id];
        final avgA = (ba == null || ba.isEmpty) ? -1.0 : ba.average;
        final avgB = (bb == null || bb.isEmpty) ? -1.0 : bb.average;
        return avgB.compareTo(avgA);
      });

    final noted =
        students.where((s) => !(bulletins[s.id]?.isEmpty ?? true)).length;

    return DataPanel(
      title: '${classObj.name} — $noted/${students.length} élève(s) noté(s)',
      child: DataTablePanel(
        columns: const ['Rang', 'Élève', 'Moy. générale', 'Mention', ''],
        flex: const [1, 4, 2, 3, 1],
        rows: [
          for (final s in sorted) _row(context, s, bulletins[s.id]),
        ],
      ),
    );
  }

  List<Widget> _row(BuildContext context, SbStudent s, Bulletin? b) {
    final hasGrades = b != null && !b.isEmpty;
    final avg = hasGrades ? b.average : 0.0;
    final c = _mentionColor(avg);
    return [
      Text(hasGrades ? '${b.rank}' : '—',
          style: TextStyle(
              fontSize: 12, color: context.cMuted, fontWeight: FontWeight.w700)),
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
          ? Text(avg.toStringAsFixed(2).replaceAll('.', ','),
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
                child: Text(b.mention,
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
    final school = ref.watch(schoolProvider).valueOrNull;
    final rules = BulletinRules.fromSchool(school);
    // Les bulletins de TOUTE la classe : sans les autres, cet élève n'a ni rang,
    // ni moyenne de classe, ni premier, ni dernier.
    final bulletinsAsync =
        ref.watch(classBulletinsProvider('$classId|$period'));

    return PageScaffold(
      title: 'Bulletin',
      subtitle: '${student.fullName} · $className · $periodLabel',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackLinkRow(label: 'Retour aux notes', onTap: onBack),
        const SizedBox(height: 14),
        bulletinsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $e', style: TextStyle(color: context.cMuted)),
          ),
          data: (all) {
            final b = all[student.id];

            if (b == null || b.isEmpty) {
              return Column(children: [
                _InfoCard(
                  name: student.fullName,
                  classe: className,
                  matricule: student.matricule,
                  periodLabel: periodLabel,
                ),
                const SizedBox(height: 14),
                const _Empty(
                    icon: Icons.receipt_long_outlined,
                    text: 'Aucune note saisie pour cette période.'),
              ]);
            }

            return Column(children: [
              _InfoCard(
                name: student.fullName,
                classe: className,
                matricule: student.matricule,
                periodLabel: periodLabel,
              ),
              const SizedBox(height: 14),
              // La MÊME vue que la page « Bulletins » : un bulletin se ressemble
              // partout, qu'on le prévisualise ou qu'on le ressorte du classeur.
              BulletinView(
                school: school,
                student: student,
                className: className,
                periodLabel: periodLabel,
                bulletin: b,
                rules: rules,
              ),
              const SizedBox(height: 8),
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
