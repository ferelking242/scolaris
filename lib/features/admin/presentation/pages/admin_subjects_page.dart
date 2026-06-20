import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);

class AdminSubjectsPage extends ConsumerWidget {
  const AdminSubjectsPage({super.key});

  String? _schoolOrWarn(BuildContext context, WidgetRef ref) {
    final schoolId = ref.read(currentSchoolIdProvider);
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune école associée à votre compte.'),
        backgroundColor: _terra,
      ));
    }
    return schoolId;
  }

  void _openSubjectDialog(
      BuildContext context, WidgetRef ref, SbSubject? existing) {
    final schoolId = _schoolOrWarn(context, ref);
    if (schoolId == null) return;
    showDialog(
      context: context,
      builder: (_) => _SubjectDialog(
        schoolId: schoolId,
        existing: existing,
        onSaved: () => ref.invalidate(subjectsProvider),
      ),
    );
  }

  void _openLoadCatalog(BuildContext context, WidgetRef ref) {
    final schoolId = _schoolOrWarn(context, ref);
    if (schoolId == null) return;
    showDialog(
      context: context,
      builder: (_) => _LoadCatalogDialog(
        schoolId: schoolId,
        onSaved: () => ref.invalidate(subjectsProvider),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SbSubject s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer la matière ?'),
        content: Text(
            '« ${s.name} » sera retirée de la liste. Les notes déjà saisies '
            'pour cette matière ne seront plus rattachées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _terra),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseDbSource.deleteSubject(s.id);
      ref.invalidate(subjectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Suppression impossible : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    return subjectsAsync.when(
      loading: () => const PageScaffold(
        title: 'Matières',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Matières',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (subjects) => PageScaffold(
        title: 'Matières',
        subtitle: '${subjects.length} matière(s) dans l\'établissement',
        actions: [
          ActionButton(
            label: 'Charger les matières types',
            icon: Icons.auto_awesome_outlined,
            onTap: () => _openLoadCatalog(context, ref),
          ),
          ActionButton(
            label: 'Nouvelle matière',
            icon: Icons.add_rounded,
            primary: true,
            onTap: () => _openSubjectDialog(context, ref, null),
          ),
        ],
        child: DataPanel(
          title: 'Toutes les matières',
          headerActions: const [SearchInput(hint: 'Rechercher matière…')],
          child: subjects.isEmpty
              ? const _EmptyState()
              : DataTablePanel(
                  columns: const ['Matière', 'Code', 'Coefficient', ''],
                  flex: const [4, 2, 2, 2],
                  rows: [
                    for (final s in subjects)
                      [
                        Text(s.name,
                            style: const TextStyle(
                                color: ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text(s.code ?? '—',
                            style:
                                const TextStyle(fontSize: 12, color: muted)),
                        Text('${s.coefficient}',
                            style:
                                const TextStyle(fontSize: 12, color: muted)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _IconBtn(
                                icon: Icons.edit_outlined,
                                onTap: () =>
                                    _openSubjectDialog(context, ref, s)),
                            const SizedBox(width: 6),
                            _IconBtn(
                                icon: Icons.delete_outline_rounded,
                                onTap: () => _confirmDelete(context, ref, s)),
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

// ── Dialogue Créer / Modifier une matière ────────────────────────────────────
class _SubjectDialog extends StatefulWidget {
  final String schoolId;
  final SbSubject? existing;
  final VoidCallback onSaved;
  const _SubjectDialog(
      {required this.schoolId, required this.existing, required this.onSaved});
  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _code =
      TextEditingController(text: widget.existing?.code ?? '');
  late final TextEditingController _coef = TextEditingController(
      text: (widget.existing?.coefficient ?? 1).toString());
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _coef.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final coef = num.tryParse(_coef.text.trim().replaceAll(',', '.')) ?? 1;
    try {
      if (_isEdit) {
        await SupabaseDbSource.updateSubject(
          id: widget.existing!.id,
          name: _name.text.trim(),
          code: _code.text.trim(),
          coefficient: coef,
        );
      } else {
        await SupabaseDbSource.createSubject(
          schoolId: widget.schoolId,
          name: _name.text.trim(),
          code: _code.text.trim(),
          coefficient: coef,
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_isEdit ? 'Modifier la matière' : 'Nouvelle matière',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Nom de la matière',
                  prefixIcon: Icon(Icons.menu_book_outlined)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                      labelText: 'Code (Maths…)',
                      prefixIcon: Icon(Icons.tag_outlined)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _coef,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Coefficient',
                      prefixIcon: Icon(Icons.calculate_outlined)),
                ),
              ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: _terra, fontSize: 12.5)),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}

// ── Dialogue « Charger les matières types » ──────────────────────────────────
class _LoadCatalogDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final VoidCallback onSaved;
  const _LoadCatalogDialog({required this.schoolId, required this.onSaved});
  @override
  ConsumerState<_LoadCatalogDialog> createState() => _LoadCatalogDialogState();
}

class _LoadCatalogDialogState extends ConsumerState<_LoadCatalogDialog> {
  final Set<String> _cycles = {'primaire', 'college', 'lycee'};
  bool _loading = false;
  String? _error;

  static const _labels = {
    'primaire': 'Primaire',
    'college': 'Collège',
    'lycee': 'Lycée',
  };

  Future<void> _submit() async {
    if (_cycles.isEmpty) {
      setState(() => _error = 'Choisissez au moins un cycle.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await SupabaseDbSource.loadSubjectsFromCatalog(
        schoolId: widget.schoolId,
        cycles: _cycles.toList(),
      );
      widget.onSaved();
      if (mounted) navigator.pop();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(added == 0
            ? 'Aucune nouvelle matière à ajouter (déjà présentes).'
            : '$added matière(s) ajoutée(s).'),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(subjectCatalogProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Charger les matières types',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sélectionnez les cycles. Les matières types seront ajoutées '
              'à votre liste (celles déjà présentes sont ignorées). Vous '
              'pourrez ensuite les ajuster.',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in _labels.entries)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: _terra,
              title: Text(entry.value),
              subtitle: catalogAsync.maybeWhen(
                data: (cat) => Text(
                    '${cat.where((c) => c.cycle == entry.key).length} matières',
                    style: const TextStyle(fontSize: 11, color: muted)),
                orElse: () => null,
              ),
              value: _cycles.contains(entry.key),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _cycles.add(entry.key);
                } else {
                  _cycles.remove(entry.key);
                }
              }),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: _terra, fontSize: 12.5)),
          ],
        ]),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Charger'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Aucune matière. Cliquez « Charger les matières types » pour '
            'démarrer rapidement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: muted),
        ),
      );
}
