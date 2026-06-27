import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);

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
        onSaved: () => ref.invalidate(classesProvider),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    return classesAsync.when(
      loading: () => const PageScaffold(
        title: 'Classes & sections',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Classes & sections',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (classes) => PageScaffold(
        title: 'Classes & sections',
        subtitle: '${classes.length} classes dans l\'établissement',
        actions: [
          ActionButton(
              label: 'Nouvelle classe',
              icon: Icons.add_rounded,
              primary: true,
              onTap: () => _openClassDialog(context, ref, null)),
        ],
        child: DataPanel(
          title: 'Toutes les classes',
          headerActions: const [SearchInput(hint: 'Rechercher classe…')],
          child: classes.isEmpty
              ? const _EmptyState()
              : DataTablePanel(
                  columns: const ['Classe', 'Niveau', 'Section', 'Capacité', ''],
                  flex: const [2, 3, 3, 2, 2],
                  rows: [
                    for (final cl in classes)
                      [
                        Text(cl.name,
                            style: const TextStyle(
                                color: ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text(cl.level ?? '—',
                            style: const TextStyle(fontSize: 12, color: muted)),
                        Text(cl.section ?? '—',
                            style: const TextStyle(fontSize: 12, color: muted)),
                        _CapacityBar(max: cl.maxStudents),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _IconBtn(
                                icon: Icons.edit_outlined,
                                onTap: () => _openClassDialog(context, ref, cl)),
                            const SizedBox(width: 6),
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
                                icon: Icons.delete_outline_rounded,
                                color: _terra,
                                onTap: () => _deleteClass(context, ref, cl)),
                          ]),
                        ),
                      ],
                  ],
                ),
        ),
      ),
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
  bool _loading = false;
  String? _error;

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
      } else {
        final sec = _section.text.trim();
        final name = sec.isEmpty ? _level!.name : '${_level!.name} $sec';
        await SupabaseDbSource.createClass(
          schoolId: widget.schoolId,
          name: name,
          level: _level!.cycle,
          levelId: _level!.id,
          section: sec,
          room: _room.text.trim(),
          maxStudents: cap,
          branchId: _branch?.id,
        );
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
        width: 400,
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
        width: 460,
        height: 520,
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
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
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
              const Text('Ajouter un élève',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
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
          ? Text(subtitle!, style: const TextStyle(fontSize: 11, color: muted))
          : null,
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: Icon(
                  isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  color: isAdd ? _terra : muted),
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
            style: const TextStyle(color: muted, fontSize: 12.5)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Aucune classe créée.',
              style: TextStyle(color: muted, fontSize: 14)),
        ),
      );
}

class _CapacityBar extends StatelessWidget {
  final int max;
  const _CapacityBar({required this.max});
  @override
  Widget build(BuildContext context) => Text('/ $max',
      style: const TextStyle(fontSize: 12, color: muted));
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
