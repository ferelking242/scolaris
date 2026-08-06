import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import 'admin_courses_page.dart' show openCourseForm, CoursesListView;

const _terra = Color(0xFF8B1A00);

/// Texte de recherche de la liste des classes. `autoDispose` : il se remet à
/// vide dès qu'on quitte la page.
final _classSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class AdminClassesPage extends ConsumerWidget {
  const AdminClassesPage({super.key});

  void _openClassDialog(BuildContext context, WidgetRef ref, SbClass? existing) {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune école associée à votre compte.'),
        backgroundColor: _terra,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _ClassDialog(
        schoolId: schoolId,
        existing: existing,
        onSaved: () {
          ref.invalidate(classesProvider);
          // La création peut avoir généré le programme par défaut (matières
          // + cours) : sans ça, la page Matières garde son cache périmé.
          ref.invalidate(subjectsProvider);
          ref.invalidate(coursesForSchoolProvider);
        },
      ),
    );
  }

  Future<void> _deleteClass(BuildContext context, WidgetRef ref, SbClass cl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la classe ?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          'La classe "${cl.name}" sera supprimée définitivement. '
          'Les élèves affectés perdront leur affectation.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseDbSource.deleteClass(cl.id);
      ref.invalidate(classesProvider);
      ref.invalidate(studentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Classe "${cl.name}" supprimée.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _terra,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Suppression impossible : $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _terra,
        ));
      }
    }
  }

  Future<void> _deleteAllClasses(
      BuildContext context, WidgetRef ref, int count) async {
    final confirmCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.warning_amber_rounded, color: _terra, size: 32),
          title: const Text('Supprimer toutes les classes ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Les $count classes de l\'établissement seront supprimées '
                'définitivement, ainsi que leur programme (cours). Les élèves '
                'affectés perdront leur affectation mais ne seront pas '
                'supprimés. Cette action est irréversible.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text('Tapez SUPPRIMER pour confirmer :',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                decoration: const InputDecoration(isDense: true),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: confirmCtrl.text.trim() == 'SUPPRIMER'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(backgroundColor: _terra),
              child: const Text('Tout supprimer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseDbSource.deleteAllClasses(schoolId);
      ref.invalidate(classesProvider);
      ref.invalidate(studentsProvider);
      ref.invalidate(coursesForSchoolProvider);
      messenger.showSnackBar(SnackBar(
        content: const Text('Toutes les classes ont été supprimées.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Suppression impossible : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    Future<void> refresh() async {
      ref.invalidate(classesProvider);
      ref.invalidate(studentsProvider);
      await Future.wait([
        ref.read(classesProvider.future),
        ref.read(studentsProvider.future),
      ]);
    }
    return classesAsync.when(
      loading: () => PageScaffold(
        onRefresh: refresh,
        title: 'Classes & sections',
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        onRefresh: refresh,
        title: 'Classes & sections',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (classes) {
        // Classes saisies à l'inscription mais jamais reportées ici (elles
        // vivent dans `school_classes`, que le tableau de bord ne lit pas). On
        // ne les propose à l'import que si la vraie table est encore vide.
        final schoolId = ref.read(currentSchoolIdProvider);
        final pending = classes.isEmpty && schoolId != null
            ? (ref.watch(registrationClassesProvider(schoolId)).valueOrNull
                ?? const <Map<String, dynamic>>[])
            : const <Map<String, dynamic>>[];
        final canCreate = ref.watch(canProvider('classes.creer'));

        // Effectif réel par classe (élèves actifs seulement — un sorti ne
        // compte plus dans sa classe) pour afficher "12 / 30" et non "/ 30".
        final students =
            ref.watch(studentsProvider).valueOrNull ?? const <SbStudent>[];
        final countByClass = <String, int>{};
        for (final s in students) {
          if (s.classId == null || s.hasExited) continue;
          countByClass[s.classId!] = (countByClass[s.classId!] ?? 0) + 1;
        }

        // Recherche libre : nom, niveau ou section, insensible à la casse.
        final rawSearch = ref.watch(_classSearchProvider).trim();
        final search = rawSearch.toLowerCase();
        final filtered = search.isEmpty
            ? classes
            : classes
                .where((cl) =>
                    cl.name.toLowerCase().contains(search) ||
                    (cl.level ?? '').toLowerCase().contains(search) ||
                    (cl.section ?? '').toLowerCase().contains(search))
                .toList();

        return PageScaffold(
        onRefresh: refresh,
        title: 'Classes & sections',
        subtitle: '${classes.length} classes dans l\'établissement',
        actions: [
          // Les boutons suivent les droits FINS du rôle, comme la base : sans
          // `classes.creer`, l'écriture serait refusée — autant ne pas la
          // proposer.
          if (classes.isNotEmpty && ref.watch(canProvider('classes.supprimer')))
            ActionButton(
                label: 'Tout supprimer',
                icon: Icons.delete_sweep_outlined,
                onTap: () => _deleteAllClasses(context, ref, classes.length)),
          if (canCreate)
            ActionButton(
                label: 'Nouvelle classe',
                icon: Icons.add_rounded,
                primary: true,
                onTap: () => _openClassDialog(context, ref, null)),
        ],
        child: DataPanel(
          title: 'Toutes les classes',
          headerActions: [
            SearchInput(
              hint: 'Rechercher classe…',
              onChanged: (v) =>
                  ref.read(_classSearchProvider.notifier).state = v,
            )
          ],
          child: classes.isEmpty
              ? (pending.isNotEmpty && canCreate
                  ? _ImportBanner(
                      count: pending.length,
                      onImport: () => _importRegistration(context, ref, pending))
                  : const _EmptyState())
              : filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: Text('Aucun résultat pour « $rawSearch ».',
                          style: TextStyle(color: context.cMuted))),
                )
              : LayoutBuilder(builder: (_, constraints) {
                  // 5 colonnes fixes illisibles sous 640px (Niveau/Section
                  // tronqués) : cartes empilées à la place, comme Personnel.
                  if (constraints.maxWidth < 640) {
                    return Column(children: [
                      for (final cl in filtered)
                        _ClassCard(
                          klass: cl,
                          studentCount: countByClass[cl.id] ?? 0,
                          onEdit: ref.watch(canProvider('classes.modifier'))
                              ? () => _openClassDialog(context, ref, cl)
                              : null,
                          onRoster: () => showDialog(
                                context: context,
                                builder: (_) => _ClassRosterDialog(
                                  klass: cl,
                                  onChanged: () =>
                                      ref.invalidate(studentsProvider),
                                ),
                              ),
                          onProgram: () => showDialog(
                                context: context,
                                builder: (_) => _ClassProgramDialog(klass: cl),
                              ),
                          onDelete: ref.watch(canProvider('classes.supprimer'))
                              ? () => _deleteClass(context, ref, cl)
                              : null,
                        ),
                    ]);
                  }
                  return DataTablePanel(
                  columns: const ['Classe', 'Niveau', 'Section', 'Capacité', ''],
                  flex: const [2, 3, 3, 2, 2],
                  rows: [
                    for (final cl in filtered)
                      [
                        Text(cl.name,
                            style: TextStyle(
                                color: context.cInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text(cl.level ?? '—',
                            style: TextStyle(fontSize: 12, color: context.cMuted)),
                        Text(cl.section ?? '—',
                            style: TextStyle(fontSize: 12, color: context.cMuted)),
                        _CapacityBar(
                            count: countByClass[cl.id] ?? 0, max: cl.maxStudents),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (ref.watch(canProvider('classes.modifier'))) ...[
                              _IconBtn(
                                  icon: Icons.edit_outlined,
                                  onTap: () => _openClassDialog(context, ref, cl)),
                              const SizedBox(width: 6),
                            ],
                            _IconBtn(
                                icon: Icons.people_outline_rounded,
                                onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => _ClassRosterDialog(
                                        klass: cl,
                                        onChanged: () =>
                                            ref.invalidate(studentsProvider),
                                      ),
                                    )),
                            const SizedBox(width: 6),
                            _IconBtn(
                                icon: Icons.menu_book_outlined,
                                onTap: () => showDialog(
                                      context: context,
                                      builder: (_) =>
                                          _ClassProgramDialog(klass: cl),
                                    )),
                            if (ref.watch(canProvider('classes.supprimer'))) ...[
                              const SizedBox(width: 6),
                              _IconBtn(
                                  icon: Icons.delete_outline_rounded,
                                  color: _terra,
                                  onTap: () => _deleteClass(context, ref, cl)),
                            ],
                          ]),
                        ),
                      ],
                  ],
                  );
                }),
        ),
      );
      },
    );
  }

  /// Ouvre le sélecteur des classes saisies à l'inscription, pour choisir
  /// exactement lesquelles reporter dans la vraie table `classes` — plutôt
  /// que tout importer d'un bloc.
  Future<void> _importRegistration(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> pending) async {
    await showDialog(
      context: context,
      builder: (_) => _ImportClassesDialog(
        pending: pending,
        onImport: (selected) => _doImport(context, ref, selected),
      ),
    );
  }

  /// Reporte les classes sélectionnées dans la vraie table `classes` (avec
  /// leur programme par défaut), puis rafraîchit la liste. Le vrai correctif
  /// du « piège des classes » : ce que l'admin a saisi à l'inscription
  /// apparaît enfin dans son tableau de bord.
  Future<void> _doImport(
      BuildContext context, WidgetRef ref, Set<String> selected) async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    final year =
        ref.read(schoolProvider).valueOrNull?.academicYear ?? '2025-2026';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await SupabaseDbSource.importRegistrationClasses(
          schoolId: schoolId, academicYear: year, only: selected);
      ref.invalidate(classesProvider);
      ref.invalidate(registrationClassesProvider(schoolId));
      // Le programme généré peuple matières et cours : sans ça, ces deux
      // pages garderaient leur cache périmé.
      ref.invalidate(subjectsProvider);
      ref.invalidate(coursesForSchoolProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(n > 0
            ? '$n classe(s) importée(s), avec leur programme.'
            : 'Rien à importer (déjà à jour).'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16A34A),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Import impossible : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
    }
  }
}

/// Sélecteur des classes saisies à l'inscription — groupées par série, avec
/// tout coché par défaut. Évite le tout-ou-rien : l'admin peut décocher ce
/// qu'il ne veut pas reporter dans son tableau de bord.
class _ImportClassesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> pending;
  final Future<void> Function(Set<String> selectedNames) onImport;
  const _ImportClassesDialog({required this.pending, required this.onImport});

  @override
  State<_ImportClassesDialog> createState() => _ImportClassesDialogState();
}

class _ImportClassesDialogState extends State<_ImportClassesDialog> {
  late Set<String> _selected = {
    for (final r in widget.pending)
      if (((r['name'] as String?) ?? '').trim().isNotEmpty)
        (r['name'] as String).trim(),
  };
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final byLevel = <String, List<String>>{};
    for (final r in widget.pending) {
      final name = ((r['name'] as String?) ?? '').trim();
      if (name.isEmpty) continue;
      final level = ((r['level'] as String?) ?? '').trim();
      byLevel.putIfAbsent(level.isEmpty ? 'Sans niveau' : level, () => []).add(name);
    }
    final total = _selected.length == widget.pending.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Choisir les classes à importer',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.92).clamp(0, 420),
        height: (MediaQuery.sizeOf(context).height * 0.7).clamp(0, 480),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_selected.length} / ${widget.pending.length} sélectionnée(s)',
                style: TextStyle(fontSize: 12.5, color: context.cMuted)),
            TextButton(
              onPressed: () => setState(() {
                if (total) {
                  _selected.clear();
                } else {
                  _selected = {
                    for (final r in widget.pending)
                      if (((r['name'] as String?) ?? '').trim().isNotEmpty)
                        (r['name'] as String).trim(),
                  };
                }
              }),
              child: Text(total ? 'Tout désélectionner' : 'Tout sélectionner'),
            ),
          ]),
          const Divider(height: 12),
          Expanded(
            child: ListView(children: [
              for (final entry in byLevel.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(entry.key,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: context.cMuted)),
                ),
                for (final name in entry.value)
                  CheckboxListTile(
                    value: _selected.contains(name),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(name, style: const TextStyle(fontSize: 13.5)),
                    onChanged: (v) => setState(() {
                      if (v ?? false) {
                        _selected.add(name);
                      } else {
                        _selected.remove(name);
                      }
                    }),
                  ),
              ],
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: (_submitting || _selected.isEmpty)
              ? null
              : () async {
                  setState(() => _submitting = true);
                  await widget.onImport(_selected);
                  if (context.mounted) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(backgroundColor: _terra),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Importer (${_selected.length})'),
        ),
      ],
    );
  }
}

// ── Dialogue Créer / Modifier une classe ─────────────────────────────────────
class _ClassDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final SbClass? existing;
  final VoidCallback onSaved;
  const _ClassDialog(
      {required this.schoolId, required this.existing, required this.onSaved});
  @override
  ConsumerState<_ClassDialog> createState() => _ClassDialogState();
}

class _ClassDialogState extends ConsumerState<_ClassDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _section =
      TextEditingController(text: widget.existing?.section ?? '');
  late final TextEditingController _room =
      TextEditingController(text: widget.existing?.room ?? '');
  late final TextEditingController _capacity = TextEditingController(
      text: (widget.existing?.maxStudents ?? 35).toString());
  SbClassLevel? _level;
  SbBranch? _branch;
  late String? _mainTeacherId = widget.existing?.mainTeacherId;
  bool _loading = false;
  String? _error;
  // Génère automatiquement le programme (matières du cycle, via
  // subject_catalog) à la création — évite la classe vide qu'il fallait
  // ensuite remplir matière par matière dans un écran séparé.
  bool _generateProgram = true;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _room.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isEdit && _level == null) {
      setState(() => _error = 'Choisissez un niveau.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final navigator = Navigator.of(context);
    final cap = int.tryParse(_capacity.text.trim()) ?? 35;
    try {
      if (_isEdit) {
        await SupabaseDbSource.updateClass(
          id: widget.existing!.id,
          name: _name.text.trim(),
          section: _section.text.trim(),
          room: _room.text.trim(),
          maxStudents: cap,
        );
        await SupabaseDbSource.setClassMainTeacher(
            widget.existing!.id, _mainTeacherId);
      } else {
        final sec = _section.text.trim();
        final name = sec.isEmpty ? _level!.name : '${_level!.name} $sec';
        final classId = await SupabaseDbSource.createClass(
          schoolId: widget.schoolId,
          name: name,
          level: _level!.cycle,
          levelId: _level!.id,
          section: sec,
          room: _room.text.trim(),
          maxStudents: cap,
          branchId: _branch?.id,
          mainTeacherId: _mainTeacherId,
        );
        if (_generateProgram) {
          await SupabaseDbSource.generateDefaultProgramForClass(
            schoolId: widget.schoolId,
            classId: classId,
            cycle: _level!.cycle,
            series: _level!.series != null ? [_level!.series!] : null,
            levelOrderNum: _level!.orderNum,
          );
        }
      }
      widget.onSaved();
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(classLevelsProvider);
    final branchesAsync = ref.watch(branchesProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_isEdit ? 'Modifier la classe' : 'Nouvelle classe',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.92).clamp(0, 400),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Niveau : dropdown depuis class_levels (création uniquement)
            if (!_isEdit)
              levelsAsync.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator()),
                error: (e, _) => Text('Niveaux indisponibles : $e',
                    style: const TextStyle(color: _terra, fontSize: 12)),
                data: (levels) => DropdownButtonFormField<SbClassLevel>(
                  value: _level,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Niveau',
                      prefixIcon: Icon(Icons.school_outlined)),
                  items: [
                    for (final lv in levels)
                      DropdownMenuItem(value: lv, child: Text(lv.fullLabel)),
                  ],
                  onChanged: (v) => setState(() => _level = v),
                ),
              )
            else
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Nom de la classe',
                    prefixIcon: Icon(Icons.class_outlined)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
            // Campus (uniquement si l'école a des filiales)
            if (!_isEdit)
              branchesAsync.whenData((branches) {
                if (branches.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DropdownButtonFormField<SbBranch?>(
                    value: _branch,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Campus (optionnel)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les campus')),
                      for (final b in branches)
                        DropdownMenuItem(value: b, child: Text(b.name)),
                    ],
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                );
              }).value ?? const SizedBox.shrink(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _section,
                  decoration: const InputDecoration(
                      labelText: 'Section (A, B…)',
                      prefixIcon: Icon(Icons.label_outline)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Capacité',
                      prefixIcon: Icon(Icons.groups_outlined)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _room,
              decoration: const InputDecoration(
                  labelText: 'Salle (optionnel)',
                  prefixIcon: Icon(Icons.meeting_room_outlined)),
            ),
            const SizedBox(height: 12),
            // Titulaire : enseigne toute la classe (modèle primaire). Voit son
            // carnet/ses présences pour cette classe (cf. teacherAssignments).
            ref.watch(teachersProvider).when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (teachers) => DropdownButtonFormField<String?>(
                value: teachers.any((t) => t.id == _mainTeacherId)
                    ? _mainTeacherId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Titulaire (optionnel)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Aucun titulaire')),
                  for (final t in teachers)
                    DropdownMenuItem(value: t.id, child: Text(t.fullName)),
                ],
                onChanged: (v) => setState(() => _mainTeacherId = v),
              ),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _generateProgram,
                onChanged: (v) => setState(() => _generateProgram = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Générer le programme par défaut',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Matières types du niveau, pré-remplies avec leur coefficient. '
                  'Les enseignants restent à assigner.',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: _terra, fontSize: 12.5)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _terra),
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}

// ── Dialogue Effectif d'une classe (affecter / retirer des élèves) ───────────
class _ClassRosterDialog extends ConsumerStatefulWidget {
  final SbClass klass;
  final VoidCallback onChanged;
  const _ClassRosterDialog({required this.klass, required this.onChanged});
  @override
  ConsumerState<_ClassRosterDialog> createState() => _ClassRosterDialogState();
}

class _ClassRosterDialogState extends ConsumerState<_ClassRosterDialog> {
  String? _busyId; // élève en cours d'affectation/retrait
  String _search = '';

  Future<void> _assign(SbStudent s) async {
    setState(() => _busyId = s.id);
    try {
      await SupabaseDbSource.assignStudentToClass(
          userId: s.id, classId: widget.klass.id);
      widget.onChanged();
      ref.invalidate(studentsProvider);
    } catch (e) {
      _toast('Échec : $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(SbStudent s) async {
    setState(() => _busyId = s.id);
    try {
      await SupabaseDbSource.unassignStudentFromClass(s.id);
      widget.onChanged();
      ref.invalidate(studentsProvider);
    } catch (e) {
      _toast('Échec : $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Effectif — ${widget.klass.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.92).clamp(0, 460),
        height: (MediaQuery.sizeOf(context).height * 0.75).clamp(0, 520),
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (all) {
            final inClass =
                all.where((s) => s.classId == widget.klass.id).toList();
            final inIds = inClass.map((s) => s.id).toSet();
            final q = _search.trim().toLowerCase();
            final available = all
                .where((s) => !inIds.contains(s.id))
                .where((s) =>
                    q.isEmpty || s.fullName.toLowerCase().contains(q))
                .toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Élèves de la classe
              Text('Dans la classe (${inClass.length})',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: context.cInk)),
              const SizedBox(height: 6),
              Expanded(
                child: inClass.isEmpty
                    ? const _Hint('Aucun élève affecté pour l\'instant.')
                    : ListView(
                        children: [
                          for (final s in inClass)
                            _RosterTile(
                              student: s,
                              busy: _busyId == s.id,
                              action: _RosterAction.remove,
                              onTap: () => _remove(s),
                            ),
                        ],
                      ),
              ),
              const Divider(height: 20),
              // Élèves disponibles
              Text('Ajouter un élève',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: context.cInk)),
              const SizedBox(height: 6),
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Rechercher un élève…',
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: available.isEmpty
                    ? const _Hint('Aucun élève disponible. Créez-en dans Utilisateurs.')
                    : ListView(
                        children: [
                          for (final s in available)
                            _RosterTile(
                              student: s,
                              busy: _busyId == s.id,
                              action: _RosterAction.add,
                              subtitle: s.classe == null || s.classe!.isEmpty
                                  ? 'Sans classe'
                                  : 'Actuellement : ${s.classe}',
                              onTap: () => _assign(s),
                            ),
                        ],
                      ),
              ),
            ]);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

// ── Dialogue Programme d'une classe (cours = classe × matière × prof) ────────
// Fusionne ce qui vivait dans l'écran séparé "Cours" : on gère le programme
// directement depuis la fiche classe, avec un bouton pour le regénérer depuis
// le catalogue si besoin (ex: matière ajoutée après coup dans le catalogue).
class _ClassProgramDialog extends ConsumerWidget {
  final SbClass klass;
  const _ClassProgramDialog({required this.klass});

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) return;
    // `classes.level` est déjà le cycle (cf. createClass : `level: _level!.cycle`).
    final cycle = klass.level;
    if (cycle == null || cycle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Niveau inconnu pour cette classe : impossible de '
            'générer un programme par défaut.'),
        backgroundColor: _terra,
      ));
      return;
    }
    // Résout le niveau exact (order_num) pour les matières réservées à partir
    // d'un certain niveau (ex. l'anglais à partir du CM1) ; sans levelId (vieille
    // classe créée avant Phase C) on génère sans restriction.
    final levels = ref.read(classLevelsProvider).valueOrNull ?? const [];
    final level =
        levels.where((l) => l.id == klass.levelId).firstOrNull;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await SupabaseDbSource.generateDefaultProgramForClass(
        schoolId: schoolId,
        classId: klass.id,
        cycle: cycle,
        series: level?.series != null ? [level!.series!] : null,
        levelOrderNum: level?.orderNum,
      );
      ref.invalidate(coursesForClassProvider(klass.id));
      ref.invalidate(coursesForSchoolProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(n > 0
            ? '$n cours ajouté(s) depuis le catalogue.'
            : 'Programme déjà à jour (rien à ajouter).'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16A34A),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Génération impossible : $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _terra,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(currentSchoolIdProvider) ?? '';
    final canWrite = ref.watch(canProvider('classes.creer'));
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Programme — ${klass.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.92).clamp(0, 520),
        height: (MediaQuery.sizeOf(context).height * 0.75).clamp(0, 560),
        child: SingleChildScrollView(
          child: CoursesListView(
            classId: klass.id,
            schoolId: schoolId,
            search: '',
            onEdit: (c) => openCourseForm(
              context, ref, schoolId, klass.id, c,
              () {
                ref.invalidate(coursesForClassProvider(klass.id));
                ref.invalidate(coursesForSchoolProvider);
              },
            ),
            onDelete: (c) async {
              await SupabaseDbSource.deleteCourse(c.id);
              ref.invalidate(coursesForClassProvider(klass.id));
              ref.invalidate(coursesForSchoolProvider);
            },
          ),
        ),
      ),
      actions: [
        if (canWrite)
          TextButton.icon(
            onPressed: () => _generate(context, ref),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Générer depuis le catalogue'),
          ),
        if (canWrite && schoolId.isNotEmpty)
          TextButton.icon(
            onPressed: () => openCourseForm(
              context, ref, schoolId, klass.id, null,
              () {
                ref.invalidate(coursesForClassProvider(klass.id));
                ref.invalidate(coursesForSchoolProvider);
              },
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Ajouter un cours'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

enum _RosterAction { add, remove }

class _RosterTile extends StatelessWidget {
  final SbStudent student;
  final bool busy;
  final _RosterAction action;
  final String? subtitle;
  final VoidCallback onTap;
  const _RosterTile({
    required this.student,
    required this.busy,
    required this.action,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isAdd = action == _RosterAction.add;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(student.fullName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 11, color: context.cMuted))
          : null,
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: Icon(
                  isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  color: isAdd ? _terra : context.cMuted),
              tooltip: isAdd ? 'Ajouter à la classe' : 'Retirer de la classe',
              onPressed: onTap,
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            style: TextStyle(color: context.cMuted, fontSize: 12.5)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text('Aucune classe créée.',
              style: TextStyle(color: context.cMuted, fontSize: 14)),
        ),
      );
}

/// Bannière proposant d'importer les classes saisies à l'inscription.
///
/// L'assistant d'inscription écrit les classes dans `school_classes` (avant
/// connexion, sous le compte anonyme) — une table que le tableau de bord ne lit
/// jamais. Résultat : elles semblaient perdues. Ce bouton les reporte dans la
/// vraie table `classes`, en un tap.
class _ImportBanner extends StatelessWidget {
  final int count;
  final VoidCallback onImport;
  const _ImportBanner({required this.count, required this.onImport});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.download_for_offline_outlined, size: 40, color: _terra),
          const SizedBox(height: 12),
          Text('$count classe(s) saisie(s) à votre inscription',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.cInk, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Elles n’ont pas encore été ajoutées à votre tableau de bord. '
            'Choisissez lesquelles importer (vous pourrez les modifier ensuite).',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.cMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: const Text('Choisir les classes à importer'),
            style: FilledButton.styleFrom(backgroundColor: _terra),
          ),
        ]),
      );
}

/// Carte compacte pour une classe — remplace la ligne du tableau sous 640px.
class _ClassCard extends StatelessWidget {
  final SbClass klass;
  final int studentCount;
  final VoidCallback? onEdit;
  final VoidCallback onRoster;
  final VoidCallback onProgram;
  final VoidCallback? onDelete;
  const _ClassCard({
    required this.klass,
    required this.studentCount,
    required this.onEdit,
    required this.onRoster,
    required this.onProgram,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cl = klass;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cl.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.cInk, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              [
                if ((cl.level ?? '').isNotEmpty) cl.level!,
                if ((cl.section ?? '').isNotEmpty) 'Section ${cl.section}',
                '$studentCount / ${cl.maxStudents} élèves',
              ].join(' · '),
              style: TextStyle(fontSize: 11.5, color: context.cMuted),
            ),
          ]),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 18, color: context.cMuted),
          padding: EdgeInsets.zero,
          itemBuilder: (_) => [
            if (onEdit != null)
              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
            const PopupMenuItem(value: 'roster', child: Text('Effectif')),
            const PopupMenuItem(value: 'program', child: Text('Programme')),
            if (onDelete != null)
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
          onSelected: (v) {
            switch (v) {
              case 'edit':
                onEdit?.call();
                break;
              case 'roster':
                onRoster();
                break;
              case 'program':
                onProgram();
                break;
              case 'delete':
                onDelete?.call();
                break;
            }
          },
        ),
      ]),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  final int count;
  final int max;
  const _CapacityBar({required this.count, required this.max});
  @override
  Widget build(BuildContext context) => Text('$count / $max',
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: count >= max ? _terra : context.cMuted));
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color ?? muted),
        ),
      );
}
