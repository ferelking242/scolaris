import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../core/config/countries.dart' show academicYears;
import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart' show SchoolLevel;
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);
const _green = Color(0xFF2D6A4F);
const _gold  = Color(0xFFC17F24);

/// Décision de fin d'année pour un élève. Par défaut suggérée depuis le
/// bulletin (ADMIS(E)/REDOUBLE de la dernière période), toujours corrigeable
/// par l'admin avant validation.
class _RowState {
  String decision; // 'promoted' | 'repeated' | 'transferred' | 'graduated' | 'withdrawn'
  String? toClassId;
  String reason;
  /// Devient vrai dès que l'admin touche cette ligne (chip, dropdown, motif).
  /// Tant que c'est faux, les valeurs par défaut peuvent encore se mettre à
  /// jour — utile car la classe de destination suggérée arrive parfois APRÈS
  /// coup (résolution async du niveau suivant) : sans ça, une ligne créée
  /// avant cette résolution restait bloquée sans destination.
  bool touched;
  _RowState({this.decision = 'promoted', this.toClassId, this.reason = '', this.touched = false});

  bool get isExit =>
      decision == 'transferred' || decision == 'graduated' || decision == 'withdrawn';
}

/// Écran de fin d'année : pour UNE classe, décide pour chaque élève s'il passe
/// (vers quelle classe), redouble, ou quitte l'école (transfert/diplôme/
/// radiation) — puis applique tout en un clic. Unifie le passage de classe et
/// la sortie d'élève : ce sont la MÊME décision annuelle, juste des issues
/// différentes (cf. migration 20260754_student_lifecycle.sql).
class ClassPromotionPage extends ConsumerStatefulWidget {
  const ClassPromotionPage({super.key});
  @override
  ConsumerState<ClassPromotionPage> createState() => _ClassPromotionPageState();
}

class _ClassPromotionPageState extends ConsumerState<ClassPromotionPage> {
  String? _classId;
  String? _toYear;
  bool _busy = false;
  final Map<String, _RowState> _rows = {};

  String _nextYearGuess(String current) {
    final m = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(current);
    if (m == null) return current;
    final y1 = int.parse(m.group(1)!) + 1;
    final y2 = int.parse(m.group(2)!) + 1;
    return '$y1-$y2';
  }

  _RowState _rowFor(String studentId, {required String suggested, String? toClassId}) {
    final row = _rows.putIfAbsent(
        studentId, () => _RowState(decision: suggested, toClassId: toClassId));
    // Tant que l'admin n'a pas touché la ligne, on la laisse suivre les
    // suggestions (ex. la classe de destination résolue après coup).
    if (!row.touched) {
      row.decision = suggested;
      row.toClassId = toClassId;
    }
    return row;
  }

  Future<void> _apply({
    required String schoolId,
    required String fromYear,
    required String fromClassId,
    required List<SbStudent> students,
    required Map<String, Bulletin> bulletins,
  }) async {
    // Une classe de destination manquante bloque APRÈS coup, moins clair
    // qu'avant : on vérifie d'abord que chaque « promu » a une classe choisie.
    final missing = students.where((s) {
      final r = _rows[s.id];
      return r != null && !r.isExit && (r.toClassId == null || r.toClassId!.isEmpty);
    }).toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Choisissez une classe de destination pour ${missing.length} élève(s) '
            '(ex. ${missing.first.fullName}).'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Envoyer ces décisions en ré-inscription ?'),
        content: Text(
            '${students.length} élève(s) seront ajoutés à la file de '
            '« Ré-inscriptions » (dans Pré-inscriptions). RIEN ne change encore '
            'pour eux — la classe/le statut ne bascule qu\'une fois la '
            're-inscription confirmée là-bas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: _terra),
              child: Text('Envoyer — ${students.length} élève(s)')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final decisions = [
        for (final s in students)
          PromotionDecision(
            studentId: s.id,
            fromClassId: fromClassId,
            fromAcademicYear: fromYear,
            decision: _rows[s.id]?.decision ?? 'promoted',
            toClassId: _rows[s.id]?.isExit == true ? null : _rows[s.id]?.toClassId,
            average: bulletins[s.id]?.average,
            reason: _rows[s.id]?.reason.isEmpty == true ? null : _rows[s.id]?.reason,
          ),
      ];
      await SupabaseDbSource.proposeYearEndDecisions(
        schoolId: schoolId,
        toAcademicYear: _toYear ?? fromYear,
        decisions: decisions,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: _terra,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!mounted) return;
    setState(() { _busy = false; _rows.clear(); });
    ref.invalidate(pendingReRegistrationsProvider);
    messenger.showSnackBar(SnackBar(
      content: Text(
          '${students.length} élève(s) envoyés en ré-inscription — rien '
          'n\'a encore changé pour eux.'),
      backgroundColor: _green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final classes = classesAsync.valueOrNull ?? const <SbClass>[];
    if (_classId == null && classes.isNotEmpty) _classId = classes.first.id;
    final selected = classes.where((c) => c.id == _classId).firstOrNull;

    final school = ref.watch(schoolProvider).valueOrNull;
    final fromYear = school?.academicYear ?? '';
    _toYear ??= fromYear.isEmpty ? null : _nextYearGuess(fromYear);

    final cycle = SchoolLevel.fromClassName(selected?.level);
    final fmt = ref.watch(schoolFormatForLevelProvider(cycle));
    final finalPeriod = fmt.periods.isEmpty ? 'T3' : fmt.periods.last;

    final nextLevelKey = '${school?.levelSystemType ?? ''}|${selected?.level ?? ''}';
    final nextLevelName = ref.watch(nextLevelNameProvider(nextLevelKey)).valueOrNull;
    final destinationClasses = nextLevelName == null
        ? const <SbClass>[]
        : classes.where((c) => c.level == nextLevelName && c.id != selected?.id).toList();

    return PageScaffold(
      title: 'Passage de classe',
      subtitle: 'Décision de fin d\'année : passage, redoublement ou sortie',
      child: classes.isEmpty
          ? const EmptyState(
              icon: Icons.class_outlined,
              title: 'Aucune classe',
              description: 'Créez des classes pour organiser le passage de fin d\'année.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Classe + année de destination ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.cBorder),
                ),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: _dropdown<String>(
                      label: 'Classe (année en cours)',
                      value: _classId,
                      items: [for (final c in classes)
                        DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.level ?? '—'})'))],
                      onChanged: (v) => setState(() { _classId = v; _rows.clear(); }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdown<String>(
                      label: 'Vers l\'année',
                      value: _toYear,
                      items: [
                        for (final y in {...academicYears(), if (_toYear != null) _toYear!})
                          DropdownMenuItem(value: y, child: Text(y)),
                      ],
                      onChanged: (v) => setState(() => _toYear = v),
                    ),
                  ),
                ]),
              ),
              if (nextLevelName != null && destinationClasses.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                    'Niveau suivant attendu : $nextLevelName — aucune classe de ce '
                    'niveau n\'existe encore. Créez-la dans « Classes », ou choisissez '
                    'la destination manuellement ci-dessous.',
                    style: TextStyle(fontSize: 11.5, color: _gold)),
              ],
              const SizedBox(height: 14),

              // ── La liste des élèves ──────────────────────────────────────
              //  PAS d'Expanded ici : PageScaffold fait déjà défiler tout son
              //  contenu (SingleChildScrollView) → hauteur non bornée. Un
              //  Expanded dedans plante (« RenderFlex... unbounded height »).
              if (selected == null)
                const SizedBox.shrink()
              else
                _StudentDecisionList(
                  key: ValueKey(selected.id),
                  classObj: selected,
                  finalPeriod: finalPeriod,
                  destinationClasses: destinationClasses,
                  rowFor: _rowFor,
                  onChanged: () => setState(() {}),
                  busy: _busy,
                  onApply: (students, bulletins) => _apply(
                    schoolId: school?.id ?? '',
                    fromYear: fromYear,
                    fromClassId: selected.id,
                    students: students,
                    bulletins: bulletins,
                  ),
                ),
            ]),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items,
        onChanged: onChanged,
      );
}

/// La liste des élèves de la classe, chacun avec sa moyenne annuelle (dernière
/// période), la décision suggérée, et le contrôle pour la corriger.
class _StudentDecisionList extends ConsumerWidget {
  final SbClass classObj;
  final String finalPeriod;
  final List<SbClass> destinationClasses;
  final _RowState Function(String studentId, {required String suggested, String? toClassId}) rowFor;
  final VoidCallback onChanged;
  final bool busy;
  final void Function(List<SbStudent> students, Map<String, Bulletin> bulletins) onApply;

  const _StudentDecisionList({
    super.key,
    required this.classObj,
    required this.finalPeriod,
    required this.destinationClasses,
    required this.rowFor,
    required this.onChanged,
    required this.busy,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsByClassProvider(classObj.name));
    final bulletinsAsync = ref.watch(classBulletinsProvider('${classObj.id}|$finalPeriod'));

    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _terra)),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (students) {
        if (students.isEmpty) {
          return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Aucun élève',
              description: 'Cette classe n\'a pas encore d\'élève.');
        }
        final bulletins = bulletinsAsync.valueOrNull ?? const {};

        // Pré-remplit la décision suggérée dès que le bulletin est connu, et
        // garde chaque _RowState pour l'itemBuilder (pas de deuxième appel à
        // rowFor() avec une suggestion arbitraire, ça écraserait celle-ci).
        final rows = <String, _RowState>{};
        for (final s in students) {
          final avg = bulletins[s.id]?.average;
          final suggested = avg == null ? 'promoted' : (avg >= 10 ? 'promoted' : 'repeated');
          final defaultDest = suggested == 'repeated'
              ? classObj.id
              : (destinationClasses.isNotEmpty ? destinationClasses.first.id : null);
          rows[s.id] = rowFor(s.id, suggested: suggested, toClassId: defaultDest);
        }

        // `eleves.passage_classe` OU `utilisateurs.modifier` — même règle OR
        // que la policy `student_progressions_write` (cf. 20260770). La page
        // reste accessible via le droit large `promotion` (legacy, coarse) ;
        // c'est l'ACTION d'envoi qui exige le droit fin dédié.
        final canDecide = ref.watch(canProvider('eleves.passage_classe')) ||
            ref.watch(canProvider('utilisateurs.modifier'));

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // shrinkWrap + pas de scroll propre : la page défile déjà entière
          // (cf. commentaire dans ClassPromotionPage.build).
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = students[i];
              final row = rows[s.id]!;
              final avg = bulletins[s.id]?.average;
              return _StudentDecisionRow(
                student: s,
                average: avg,
                row: row,
                destinationClasses: destinationClasses,
                currentClassName: classObj.name,
                onChanged: onChanged,
              );
            },
          ),
          const SizedBox(height: 12),
          if (!canDecide)
            Text(
              'Vous n\'avez pas le droit « Passage de classe & sortie » : '
              'contactez la direction pour envoyer ces décisions.',
              style: TextStyle(fontSize: 12, color: context.cMuted),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: ActionButton(
                label: busy ? 'Envoi…' : 'Envoyer en ré-inscription — ${students.length} élève(s)',
                icon: Icons.move_up_rounded,
                primary: true,
                onTap: busy ? null : () => onApply(students, bulletins),
              ),
            ),
        ]);
      },
    );
  }
}

class _StudentDecisionRow extends StatelessWidget {
  final SbStudent student;
  final double? average;
  final _RowState row;
  final List<SbClass> destinationClasses;
  final String currentClassName;
  final VoidCallback onChanged;

  const _StudentDecisionRow({
    required this.student,
    required this.average,
    required this.row,
    required this.destinationClasses,
    required this.currentClassName,
    required this.onChanged,
  });

  static const _decisions = [
    ('promoted', 'Passe'),
    ('repeated', 'Redouble'),
    ('transferred', 'Transféré'),
    ('graduated', 'Diplômé'),
    ('withdrawn', 'Radiation'),
  ];

  @override
  Widget build(BuildContext context) {
    final avgColor = average == null
        ? context.cMuted
        : average! >= 10 ? _green : _terra;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(student.fullName,
                style: TextStyle(color: context.cInk, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
          Text(average == null ? '—' : average!.toStringAsFixed(2),
              style: TextStyle(color: avgColor, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (value, label) in _decisions)
            ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 11.5)),
              selected: row.decision == value,
              onSelected: (_) {
                row.touched = true;
                row.decision = value;
                if (value == 'repeated') {
                  row.toClassId = null; // même classe : résolu à l'application
                } else if (value == 'promoted' && destinationClasses.isNotEmpty) {
                  row.toClassId = destinationClasses.first.id;
                } else if (row.isExit) {
                  row.toClassId = null;
                }
                onChanged();
              },
              selectedColor: (value == 'transferred' || value == 'graduated' || value == 'withdrawn')
                  ? _gold.withValues(alpha: .18)
                  : _green.withValues(alpha: .15),
            ),
        ]),
        const SizedBox(height: 8),
        if (row.decision == 'promoted')
          DropdownButtonFormField<String>(
            value: row.toClassId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Classe de destination',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: [for (final c in destinationClasses)
              DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) { row.touched = true; row.toClassId = v; onChanged(); },
          )
        else if (row.decision == 'repeated')
          Text('Reste dans « $currentClassName » (même niveau, année suivante).',
              style: TextStyle(fontSize: 11.5, color: context.cMuted))
        else
          TextField(
            controller: TextEditingController(text: row.reason)
              ..selection = TextSelection.collapsed(offset: row.reason.length),
            decoration: const InputDecoration(
              labelText: 'Motif (optionnel)',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (v) => row.reason = v,
          ),
      ]),
    );
  }
}
