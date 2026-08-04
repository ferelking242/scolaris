import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bulletin/bulletin_math.dart';
import '../../../../core/permissions/my_grants.dart';
import '../widgets/bulletin_view.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/data/features_catalog.dart' show SchoolLevel;
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

  /// « notes.voir » — même règle et même repli que `_canSeeStudents()` dans
  /// `users_page.dart` : bloqué si le rôle est sur le système fin (au moins un
  /// grain quelconque) mais n'a pas `notes.voir` ; jamais bloqué pour une école
  /// qui n'utilise pas encore les rôles fins (repli sur la case grossière
  /// `grades`, qui a déjà laissé passer la page).
  bool _canSeeGrades() {
    final grants = ref.watch(myGrantsProvider).valueOrNull;
    if (grants == null) return false;
    if (grants.contains('*') || grants.contains('notes.voir')) return true;
    return grants.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_canSeeGrades()) {
      return PageScaffold(
        title: 'Notes & Bulletins',
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, color: context.cMuted, size: 40),
            const SizedBox(height: 12),
            Text('Accès non autorisé',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: context.cInk)),
            const SizedBox(height: 6),
            Text(
              'Votre rôle n\'a pas le droit « Voir les notes ». '
              'Contactez la direction de votre établissement.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.cMuted),
            ),
          ]),
        ),
      );
    }
    final classesAsync = ref.watch(classesProvider);

    Future<void> refresh() async {
      ref.invalidate(classesProvider);
      await ref.read(classesProvider.future);
    }

    return classesAsync.when(
      loading: () => PageScaffold(
          title: 'Notes & Bulletins',
          onRefresh: refresh,
          child: const Center(child: CircularProgressIndicator())),
      error: (e, _) => PageScaffold(
          title: 'Notes & Bulletins',
          onRefresh: refresh,
          child: Center(child: Text('Erreur : $e'))),
      data: (classes) {
        if (classes.isNotEmpty && _classId == null) _classId = classes.first.id;
        final selected = classes.isEmpty
            ? null
            : classes.firstWhere((c) => c.id == _classId,
                orElse: () => classes.first);

        // La périodicité (mensuelle au primaire, trimestrielle ailleurs) suit
        // le CYCLE de la classe consultée, pas un réglage unique d'école.
        final cycle = SchoolLevel.fromClassName(selected?.level);
        final fmt = ref.watch(schoolFormatForLevelProvider(cycle));
        final period = _selectedPeriod ?? fmt.periods.first;

        // Bulletin inline : remplace tout par la fiche de l'élève.
        if (_bulletinStudent != null) {
          return _StudentBulletinPage(
            student: _bulletinStudent!,
            className: selected?.name ?? '',
            classId: selected?.id ?? '',
            period: period,
            cycle: cycle,
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
          onRefresh: refresh,
          subtitle: switch (_tab) {
            _Tab.notes => 'Consulter et corriger les notes, matière par matière',
            _Tab.bulletins => 'Le bulletin de chaque élève',
            _Tab.generer => 'Valider, verrouiller et archiver les bulletins',
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
                onChanged: (id) => setState(() {
                  _classId = id;
                  // Une autre classe peut être d'un autre cycle (mois vs
                  // trimestre) : l'ancienne période sélectionnée ne vaut plus.
                  _selectedPeriod = null;
                }),
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

/// Le basculement Notes / Bulletins / Clôture.
class _TabBar extends StatelessWidget {
  final _Tab value;
  final ValueChanged<_Tab> onChanged;
  const _TabBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(_Tab t, String label, IconData icon) {
      final active = t == value;
      return Expanded(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
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
        ),
      );
    }

    return Row(children: [
      tab(_Tab.notes, 'Notes', Icons.edit_note_rounded),
      const SizedBox(width: 8),
      tab(_Tab.bulletins, 'Bulletins', Icons.receipt_long_rounded),
      const SizedBox(width: 8),
      tab(_Tab.generer, 'Clôture', Icons.workspace_premium_rounded),
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
      double maxScore, {
    required bool reasonRequired,
    required bool Function(bool isNew) canWriteCell,
    required SbGrade? Function(String studentId, GradeSlot slot) existing,
  }) async {
    // Période validée : un motif unique couvre le lot de corrections. La base le
    // réclame de toute façon, et il part dans l'historique.
    String? reason;
    if (reasonRequired) {
      reason = await _askReason();
      if (reason == null || reason.isEmpty) return; // annulé
    }
    if (!mounted) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    var n = 0;
    var skipped = 0;
    try {
      for (final s in students) {
        for (final slot in slots) {
          // Une note déjà en base exige `notes.modifier` ; une case encore
          // vide exige `notes.saisir` — pas le même droit. On ignore toute
          // case que ce rôle n'a pas le droit d'écrire, plutôt que de la
          // renvoyer et se faire rejeter par la base au milieu du lot.
          if (!canWriteCell(existing(s.id, slot) == null)) {
            skipped++;
            continue;
          }
          final raw = _ctrls[s.id]?['${slot.type}#${slot.seq}']
                  ?.text
                  .trim()
                  .replaceAll(',', '.') ??
              '';
          if (raw.isEmpty) continue;
          final score = double.tryParse(raw)?.clamp(0.0, maxScore);
          if (score == null) continue;
          // Sur période validée, on passe par la RPC qui transporte le motif
          // jusqu'au trigger d'audit (motif + écriture, même transaction).
          if (reasonRequired) {
            await SupabaseDbSource.saveGradeWithReason(
              studentId: s.id,
              classId: widget.classObj.id,
              schoolId: widget.schoolId,
              subjectId: widget.subjectId,
              score: score,
              maxScore: maxScore,
              period: widget.period,
              type: slot.type,
              sequence: slot.seq,
              reason: reason,
            );
          } else {
            await SupabaseDbSource.upsertGrade(
              studentId: s.id,
              classId: widget.classObj.id,
              schoolId: widget.schoolId,
              subjectId: widget.subjectId,
              score: score,
              maxScore: maxScore,
              period: widget.period,
              type: slot.type,
              sequence: slot.seq,
            );
          }
          n++;
        }
      }
      _seeded = false; // relire les valeurs enregistrées
      ref.invalidate(gradesForClassProvider(widget.classObj.id));
      ref.invalidate(classBulletinsProvider(
          '${widget.classObj.id}|${widget.period}'));
      // Une correction sur période validée alimente le journal : rafraîchir
      // l'Historique de l'onglet Clôture (même clé classe|période).
      ref.invalidate(periodAuditProvider(
          '${widget.classObj.id}|${widget.period}'));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(skipped > 0
            ? '$n note(s) enregistrée(s), $skipped ignorée(s) (droit insuffisant).'
            : '$n note(s) enregistrée(s).'),
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

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Motif de la correction'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'ex : erreur de recopie du Devoir 2',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  /// Le bandeau d'état de la période, en tête du tableau.
  Widget _stateBanner(BuildContext context, String status, bool canEdit) {
    final (Color c, IconData i, String t) = switch (status) {
      'validated' => (
          _gold,
          Icons.verified_outlined,
          canEdit
              ? 'Période validée — toute correction demande un motif (tracé).'
              : 'Période validée — consultation seule (droit de correction requis).'
        ),
      'locked' => (
          _terra,
          Icons.lock_outline_rounded,
          'Période verrouillée — notes non modifiables.'
        ),
      _ => (
          _green,
          Icons.lock_open_outlined,
          canEdit ? 'Période ouverte — saisie libre.' : 'Consultation seule.'
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(i, size: 15, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(t,
              style: TextStyle(
                  fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(schoolFormatProvider);
    final maxScore = fmt.maxScore;
    final rules = BulletinRules.fromSchool(ref.watch(schoolProvider).valueOrNull);
    final slots = rules.slots;
    final studentsAsync = ref.watch(studentsByClassProvider(widget.classObj.name));
    final gradesAsync = ref.watch(gradesForClassProvider(widget.classObj.id));

    // L'état de la période décide de tout — c'est la même règle qu'en base :
    //   ouverte    → saisie/édition avec `notes.saisir`
    //   validée    → correction avec `notes.corriger` + MOTIF obligatoire
    //   verrouillée→ lecture seule pour tous
    final period = ref
        .watch(gradePeriodProvider('${widget.classObj.id}|${widget.period}'))
        .valueOrNull;
    final status = period?.status ?? 'open';
    final canCorriger = ref.watch(canProvider('notes.corriger'));
    final canSaisir = ref.watch(canProvider('notes.saisir'));
    final canModifier = ref.watch(canProvider('notes.modifier'));
    // La base distingue TOUJOURS saisir (note neuve, INSERT) de modifier
    // (note déjà en base, UPDATE) — même en période validée, où le trigger
    // exige EN PLUS `notes.corriger` (cf. guard_grade_period : le droit de
    // base ne suffit jamais à lui seul une fois la période gelée).
    bool canWriteCell(bool isNew) {
      if (status == 'locked') return false;
      final base = isNew ? canSaisir : canModifier;
      return status == 'validated' ? (base && canCorriger) : base;
    }

    final canEdit = canWriteCell(true) || canWriteCell(false);
    final reasonRequired = status == 'validated';

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
            _stateBanner(context, status, canEdit),
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
                            canEdit: canWriteCell(existing(s.id, slot) == null))),
                    ]),
                ],
              ),
            ),
            if (canEdit) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _save(students, slots, maxScore,
                          reasonRequired: reasonRequired,
                          canWriteCell: canWriteCell,
                          existing: existing),
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

  /// Une case. Éditable seulement si l'état de la période l'autorise ([canEdit]).
  /// Sinon, lecture seule — la valeur si elle existe, sinon un tiret.
  Widget _cell(String sid, GradeSlot slot, SbGrade? existing,
      {required bool canEdit}) {
    if (!canEdit) {
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
      child: LayoutBuilder(builder: (_, c) {
        // Moyenne + mention se compressaient sous 640px, partagées avec le
        // nom : cartes empilées à la place, comme Présences/Classes.
        if (c.maxWidth < 640) {
          return Column(children: [
            for (final s in sorted)
              _BulletinCard(
                  student: s, bulletin: bulletins[s.id], onTap: () => onOpen(s)),
          ]);
        }
        return DataTablePanel(
          columns: const ['Rang', 'Élève', 'Moy. générale', 'Mention', ''],
          flex: const [1, 4, 2, 3, 1],
          rows: [
            for (final s in sorted) _row(context, s, bulletins[s.id]),
          ],
        );
      }),
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

class _BulletinCard extends StatelessWidget {
  final SbStudent student;
  final Bulletin? bulletin;
  final VoidCallback onTap;
  const _BulletinCard(
      {required this.student, required this.bulletin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = bulletin;
    final hasGrades = b != null && !b.isEmpty;
    final avg = hasGrades ? b.average : 0.0;
    final c = _mentionColor(avg);
    return Material(
      color: context.cCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(children: [
            if (hasGrades) ...[
              SizedBox(
                width: 26,
                child: Text('${b.rank}',
                    style: TextStyle(
                        fontSize: 12,
                        color: context.cMuted,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
            ],
            Avatar(name: student.fullName, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(student.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.cInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            if (hasGrades) ...[
              Text(avg.toStringAsFixed(2).replaceAll('.', ','),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: c)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(b.mention,
                    style: TextStyle(
                        fontSize: 11, color: c, fontWeight: FontWeight.w700)),
              ),
            ] else
              Text('Pas de notes',
                  style: TextStyle(fontSize: 11, color: context.cMuted)),
            Icon(Icons.chevron_right_rounded, size: 20, color: context.cMuted),
          ]),
        ),
      ),
    );
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
  final SchoolLevel? cycle;
  final VoidCallback onBack;
  const _StudentBulletinPage({
    required this.student,
    required this.className,
    required this.classId,
    required this.period,
    this.cycle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodLabel =
        ref.watch(schoolFormatForLevelProvider(cycle)).periodLabel(period);
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
                classId: classId,
                academicYear: school?.academicYear,
                periodCode: period,
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
    // Wrap plutôt que Row : un découpage mensuel (10 périodes) déborderait
    // d'une ligne fixe, contrairement aux 2-3 trimestres/semestres.
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final p in periods)
        ChoiceChip(
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

  static const _terra = Color(0xFF8B1A00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_terra, Color(0xFFB8471F)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    color: context.cInk, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _tag(context, Icons.class_outlined, classe),
              _tag(context, Icons.event_note_rounded, periodLabel),
              if (matricule != null && matricule!.isNotEmpty)
                _tag(context, Icons.badge_outlined, matricule!),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(BuildContext context, IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.cSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12.5, color: context.cMuted),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  color: context.cMuted,
                  fontWeight: FontWeight.w600)),
        ]),
      );
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
