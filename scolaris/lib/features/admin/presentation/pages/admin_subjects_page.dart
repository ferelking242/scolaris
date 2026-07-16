import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = Color(0xFF8B1A00);

/// Texte de recherche de la liste des matières. `autoDispose` : remis à vide en
/// quittant la page.
final _subjectSearchProvider = StateProvider.autoDispose<String>((ref) => '');

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
      data: (subjects) {
        // Les boutons de création suivent les droits FINS du rôle, comme la
        // base. « Charger les matières types » CRÉE aussi des matières : même
        // geste que « Nouvelle matière », donc même droit `classes.creer`.
        final canCreate = ref.watch(canProvider('classes.creer'));

        // Recherche libre : nom ou code, insensible à la casse.
        final rawSearch = ref.watch(_subjectSearchProvider).trim();
        final search = rawSearch.toLowerCase();
        final filtered = search.isEmpty
            ? subjects
            : subjects
                .where((s) =>
                    s.name.toLowerCase().contains(search) ||
                    (s.code ?? '').toLowerCase().contains(search))
                .toList();

        return PageScaffold(
        title: 'Matières',
        subtitle: '${subjects.length} matière(s) dans l\'établissement',
        actions: [
          if (canCreate)
            ActionButton(
              label: 'Charger les matières types',
              icon: Icons.auto_awesome_outlined,
              onTap: () => _openLoadCatalog(context, ref),
            ),
          if (canCreate)
            ActionButton(
              label: 'Nouvelle matière',
              icon: Icons.add_rounded,
              primary: true,
              onTap: () => _openSubjectDialog(context, ref, null),
            ),
        ],
        child: DataPanel(
          title: 'Toutes les matières',
          headerActions: [
            SearchInput(
              hint: 'Rechercher matière…',
              onChanged: (v) =>
                  ref.read(_subjectSearchProvider.notifier).state = v,
            )
          ],
          child: subjects.isEmpty
              ? const _EmptyState()
              : filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: Text('Aucun résultat pour « $rawSearch ».',
                          style: TextStyle(color: context.cMuted))),
                )
              : DataTablePanel(
                  columns: const ['Matière', 'Code', 'Coefficient', ''],
                  flex: const [4, 2, 2, 2],
                  rows: [
                    for (final s in filtered)
                      [
                        Text(s.name,
                            style: TextStyle(
                                color: context.cInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text(s.code ?? '—',
                            style:
                                TextStyle(fontSize: 12, color: context.cMuted)),
                        Text('${s.coefficient}',
                            style:
                                TextStyle(fontSize: 12, color: context.cMuted)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (ref.watch(canProvider('classes.modifier'))) ...[
                              _IconBtn(
                                  icon: Icons.edit_outlined,
                                  onTap: () =>
                                      _openSubjectDialog(context, ref, s)),
                              const SizedBox(width: 6),
                            ],
                            if (ref.watch(canProvider('classes.supprimer')))
                              _IconBtn(
                                  icon: Icons.delete_outline_rounded,
                                  onTap: () => _confirmDelete(context, ref, s)),
                          ]),
                        ),
                      ],
                  ],
                ),
        ),
      );
      },
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
  /// Cycles cochés. `null` tant que les cycles réels de l'école ne sont pas
  /// chargés — on les pré-coche tous à la première donnée reçue.
  Set<String>? _cycles;

  /// Séries du lycée cochées (n'a d'effet que si le cycle « lycee » est retenu).
  final Set<String> _series = {'A', 'C', 'D'};

  bool _loading = false;
  String? _error;

  static const _cycleLabels = {
    'prescolaire': 'Préscolaire',
    'primaire': 'Primaire',
    'college': 'Collège',
    'lycee': 'Lycée',
  };

  static const _seriesLabels = {
    'A': 'Série A (littéraire)',
    'C': 'Série C (maths-physique)',
    'D': 'Série D (maths-SVT)',
  };

  /// Matières qui seront réellement ajoutées, selon la sélection courante :
  /// filtrées par cycle + séries (tronc commun toujours gardé), dédoublonnées
  /// par nom, moins celles déjà présentes dans l'école.
  List<SbSubjectCatalog> _preview(
      List<SbSubjectCatalog> catalog, List<SbSubject> existing) {
    final cycles = _cycles ?? const {};
    final existingNames =
        existing.map((s) => s.name.trim().toLowerCase()).toSet();
    final seen = <String>{};
    final out = <SbSubjectCatalog>[];
    for (final c in catalog) {
      if (!cycles.contains(c.cycle)) continue;
      // Séries : ne s'applique qu'au lycée ; tronc commun (series == null) gardé.
      if (c.cycle == 'lycee' && c.series != null && !_series.contains(c.series)) {
        continue;
      }
      final key = c.name.trim().toLowerCase();
      if (!seen.add(key) || existingNames.contains(key)) continue;
      out.add(c);
    }
    return out;
  }

  Future<void> _submit() async {
    final cycles = _cycles ?? const <String>{};
    if (cycles.isEmpty) {
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
        cycles: cycles.toList(),
        series: cycles.contains('lycee') ? _series.toList() : null,
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
    final cyclesAsync = ref.watch(schoolCyclesProvider);
    final catalogAsync = ref.watch(subjectCatalogProvider);
    final existing = ref.watch(subjectsProvider).valueOrNull ?? const [];

    // Cycles réels de l'école (fallback : les cycles v1 si l'école n'a pas
    // renseigné ses types). Pré-cochés tous à la première donnée.
    final schoolCycles = cyclesAsync.maybeWhen(
      data: (c) => c.isEmpty
          ? const ['prescolaire', 'primaire', 'college', 'lycee']
          : c,
      orElse: () => const <String>[],
    );
    if (_cycles == null && schoolCycles.isNotEmpty) {
      _cycles = schoolCycles.toSet();
    }
    final selected = _cycles ?? const <String>{};

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Charger les matières types',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: cyclesAsync.isLoading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Les matières types de vos cycles seront ajoutées à votre '
                    'liste (celles déjà présentes sont ignorées). Vous pourrez '
                    'ensuite les ajuster.',
                    style: TextStyle(fontSize: 12.5, color: context.cMuted),
                  ),
                ),
                const SizedBox(height: 8),
                // Un seul cycle → pas de choix, on l'affiche pour info.
                for (final cy in schoolCycles)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: _terra,
                    title: Text(_cycleLabels[cy] ?? cy),
                    subtitle: catalogAsync.maybeWhen(
                      data: (cat) => Text(
                          '${cat.where((c) => c.cycle == cy).map((c) => c.name.toLowerCase()).toSet().length} matières',
                          style:
                              TextStyle(fontSize: 11, color: context.cMuted)),
                      orElse: () => null,
                    ),
                    value: selected.contains(cy),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _cycles = {...selected, cy};
                      } else {
                        _cycles = {...selected}..remove(cy);
                      }
                    }),
                  ),
                // Séries : seulement si le lycée est retenu.
                if (selected.contains('lycee')) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Séries du lycée',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.cMuted)),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in _seriesLabels.entries)
                        FilterChip(
                          label: Text(entry.value,
                              style: const TextStyle(fontSize: 11.5)),
                          selected: _series.contains(entry.key),
                          selectedColor: _terra.withValues(alpha: 0.15),
                          checkmarkColor: _terra,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _series.add(entry.key);
                            } else {
                              _series.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Prévisualisation des matières à ajouter.
                catalogAsync.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(8),
                      child: LinearProgressIndicator()),
                  error: (e, _) => Text('Catalogue indisponible : $e',
                      style: const TextStyle(color: _terra, fontSize: 12)),
                  data: (cat) {
                    final toAdd = _preview(cat, existing);
                    if (toAdd.isEmpty) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          cat.isEmpty
                              ? 'Aucune matière type disponible pour vos cycles.'
                              : 'Rien à ajouter : tout est déjà présent.',
                          style:
                              TextStyle(fontSize: 12, color: context.cMuted),
                        ),
                      );
                    }
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${toAdd.length} matière(s) seront ajoutées :',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.cInk)),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 140),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final c in toAdd)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.cSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                        border:
                                            Border.all(color: context.cBorder),
                                      ),
                                      child: Text(c.name,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: context.cInk)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Aucune matière. Cliquez « Charger les matières types » pour '
            'démarrer rapidement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.cMuted, fontSize: 14),
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
          child: Icon(icon, size: 16, color: context.cMuted),
        ),
      );
}
