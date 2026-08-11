import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/permissions/my_grants.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;
const _green = ScolarisPalette.forestGreen;

IconData _iconFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('math'))       return Icons.calculate_rounded;
  if (n.contains('physique') || n.contains('chimie')) return Icons.science_rounded;
  if (n.contains('svt') || n.contains('biolog') || n.contains('vie')) return Icons.eco_rounded;
  if (n.contains('français') || n.contains('lettre')) return Icons.menu_book_rounded;
  if (n.contains('anglais') || n.contains('langue')) return Icons.language_rounded;
  if (n.contains('histoire') || n.contains('géo'))   return Icons.public_rounded;
  if (n.contains('philo'))      return Icons.lightbulb_rounded;
  if (n.contains('informatiq')) return Icons.computer_rounded;
  if (n.contains('eps') || n.contains('sport'))      return Icons.sports_soccer_rounded;
  if (n.contains('art') || n.contains('plastiq'))    return Icons.palette_rounded;
  if (n.contains('droit'))      return Icons.gavel_rounded;
  if (n.contains('économ') || n.contains('compta'))  return Icons.bar_chart_rounded;
  if (n.contains('socio'))      return Icons.people_rounded;
  if (n.contains('constit'))    return Icons.policy_rounded;
  if (n.contains('éducation'))  return Icons.emoji_events_rounded;
  return Icons.menu_book_rounded;
}

// ── Couleurs prédéfinies pour les cours ──────────────────────────────────────
const _courseColors = [
  '#8B1A00', '#C17F24', '#1B5E20', '#0D47A1', '#6A1B9A',
  '#E65100', '#00695C', '#1565C0', '#AD1457', '#37474F',
  '#4E342E', '#F57F17', '#2E7D32', '#283593', '#880E4F',
];

const _daysFr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
const _daysKey = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];

/// Ouvre le formulaire cours : dialog centrée sur PC (largeur ≥ 680),
/// bottom sheet draggable sur mobile.
/// Ouvre le formulaire cours — réutilisé par la fiche classe (onglet
/// Programme) autant que par cette page.
void openCourseForm(
  BuildContext context,
  WidgetRef ref,
  String schoolId,
  String classId,
  SbCourse? existing,
  VoidCallback onSaved,
) {
  final width = MediaQuery.sizeOf(context).width;
  final isPC  = width >= 680;

  if (isPC) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 520,
            child: _CourseFormContent(
              schoolId: schoolId,
              classId: classId,
              existing: existing,
              onSaved: () {
                onSaved();
                Navigator.pop(context);
              },
              onCancel: () => Navigator.pop(context),
              isDialog: true,
            ),
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.4,
        maxChildSize: 0.97,
        snap: true,
        snapSizes: const [0.4, 0.92, 0.97],
        builder: (ctx, scrollCtrl) => _CourseFormSheet(
          scrollController: scrollCtrl,
          schoolId: schoolId,
          classId: classId,
          existing: existing,
          onSaved: () {
            onSaved();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

// ── Page principale ───────────────────────────────────────────────────────────
class AdminCoursesPage extends ConsumerStatefulWidget {
  const AdminCoursesPage({super.key});

  @override
  ConsumerState<AdminCoursesPage> createState() => _AdminCoursesPageState();
}

class _AdminCoursesPageState extends ConsumerState<AdminCoursesPage> {
  String? _selectedClassId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(currentSchoolIdProvider);
    final classesAsync = ref.watch(classesProvider);

    return PageScaffold(
      onRefresh: () async {
        ref.invalidate(classesProvider);
        final futures = <Future<Object?>>[ref.read(classesProvider.future)];
        if (_selectedClassId != null) {
          ref.invalidate(coursesForClassProvider(_selectedClassId!));
          futures.add(ref.read(coursesForClassProvider(_selectedClassId!).future));
        }
        await Future.wait(futures);
      },
      title: 'Cours',
      subtitle: 'Gérer les cours par classe',
      actions: [
        // Les écritures suivent les droits fins du rôle, comme Classes/Matières.
        // Affecter un enseignant à un cours lui donne l'accès notation/appel :
        // raison de plus pour ne pas laisser créer un cours sans `classes.creer`.
        if (_selectedClassId != null &&
            schoolId != null &&
            ref.watch(canProvider('classes.creer')))
          ActionButton(
            label: 'Ajouter',
            icon: Icons.add_rounded,
            onTap: () => openCourseForm(
              context, ref, schoolId, _selectedClassId!, null,
              () {
                ref.invalidate(coursesForClassProvider(_selectedClassId!));
                ref.invalidate(coursesForSchoolProvider);
              },
            ),
          ),
      ],
      child: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (classes) {
          if (classes.isEmpty) {
            return const _EmptyClasses();
          }
          // Auto-select first class
          if (_selectedClassId == null && classes.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedClassId = classes.first.id);
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sélecteur de classe ──────────────────────────────────
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cls = classes[i];
                    final sel = cls.id == _selectedClassId;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                      onTap: () => setState(() => _selectedClassId = cls.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? _terra : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? _terra : Theme.of(context).colorScheme.outlineVariant),
                          boxShadow: sel ? [BoxShadow(color: _terra.withValues(alpha:.2), blurRadius: 8, offset: const Offset(0, 2))] : [],
                        ),
                        child: Text(
                          cls.name,
                          style: TextStyle(
                            color: sel ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12.5,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Recherche ────────────────────────────────────────────
              _SearchBar(onChanged: (q) => setState(() => _search = q)),
              const SizedBox(height: 16),

              // ── Liste des cours ──────────────────────────────────────
              if (_selectedClassId != null)
                CoursesListView(
                  classId: _selectedClassId!,
                  schoolId: schoolId ?? '',
                  search: _search,
                  onEdit: (c) => openCourseForm(
                    context, ref, schoolId ?? '', _selectedClassId!, c,
                    () {
                      ref.invalidate(coursesForClassProvider(_selectedClassId!));
                      ref.invalidate(coursesForSchoolProvider);
                    },
                  ),
                  onDelete: (c) => _confirmDelete(context, c),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SbCourse course) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer ce cours ?'),
        content: Text('« ${course.name} » sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
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
      await SupabaseDbSource.deleteCourse(course.id);
      ref.invalidate(coursesForClassProvider(_selectedClassId!));
      ref.invalidate(coursesForSchoolProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }
}

// ── Liste des cours d'une classe ──────────────────────────────────────────────
class CoursesListView extends ConsumerWidget {
  final String classId;
  final String schoolId;
  final String search;
  final void Function(SbCourse) onEdit;
  final void Function(SbCourse) onDelete;

  const CoursesListView({
    required this.classId,
    required this.schoolId,
    required this.search,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesForClassProvider(classId));
    final canEdit = ref.watch(canProvider('classes.modifier'));
    final canDelete = ref.watch(canProvider('classes.supprimer'));
    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (courses) {
        final filtered = search.isEmpty
            ? courses
            : courses.where((c) => c.name.toLowerCase().contains(search.toLowerCase())).toList();

        if (courses.isEmpty) {
          return _EmptyCourses(
            schoolId: schoolId,
            classId: classId,
            onCreated: () => ref.invalidate(coursesForClassProvider(classId)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${filtered.length} cours · ${courses.fold<int>(0, (s, c) => s + (c.hoursWeek ?? 0))}h/sem',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
            ...filtered.map((c) => _CourseAdminCard(
                  course: c,
                  canEdit: canEdit,
                  canDelete: canDelete,
                  onEdit: () => onEdit(c),
                  onDelete: () => onDelete(c),
                )),
          ],
        );
      },
    );
  }
}

// ── Carte cours admin ─────────────────────────────────────────────────────────
class _CourseAdminCard extends StatelessWidget {
  final SbCourse course;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CourseAdminCard({
    required this.course,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  static Color _parseColor(String? hex) {
    if (hex == null) return _terra;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return _terra; }
  }

  @override
  Widget build(BuildContext context) {
    final c  = _parseColor(course.color);
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: .2), width: 1.5),
        boxShadow: [BoxShadow(color: c.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // ── Icône couleur ──────────────────────────────────────────
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c, c.withValues(alpha: .7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(course.name), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),

          // ── Infos ──────────────────────────────────────────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 2),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (course.code != null) _Chip(course.code!, c),
                _Chip('Coef. ${course.coefficient}', _gold),
                if (course.hoursWeek != null) _Chip('${course.hoursWeek}h/sem', _green),
              ]),
              // Un cours sans enseignant, personne ne peut le noter : on le dit.
              const SizedBox(height: 4),
              if (course.teachers.isEmpty)
                const Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 13, color: _terra),
                  SizedBox(width: 4),
                  Text('Aucun enseignant',
                      style: TextStyle(fontSize: 11.5, color: _terra, fontWeight: FontWeight.w700)),
                ])
              else
                Text(course.teacherNames,
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              if (course.description != null) ...[
                const SizedBox(height: 3),
                Text(course.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
              if (course.daysOfWeek.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4, children: course.daysOfWeek.map((d) {
                  final idx = _daysKey.indexOf(d);
                  final label = idx >= 0 ? _daysFr[idx] : d.substring(0, 3);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(4)),
                    child: Text(label, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w700)),
                  );
                }).toList()),
              ],
            ]),
          ),

          // ── Actions (selon les droits fins du rôle) ────────────────
          if (canEdit || canDelete)
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (canEdit)
                IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: c), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              if (canEdit && canDelete) const SizedBox(height: 4),
              if (canDelete)
                IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFCCA99A)), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
      );
}

// ── Bottom Sheet wrapper (mobile draggable) ───────────────────────────────────
class _CourseFormSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final String schoolId;
  final String classId;
  final SbCourse? existing;
  final VoidCallback onSaved;

  const _CourseFormSheet({
    required this.scrollController,
    required this.schoolId,
    required this.classId,
    this.existing,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _CourseFormContent(
        scrollController: scrollController,
        schoolId: schoolId,
        classId: classId,
        existing: existing,
        onSaved: onSaved,
        onCancel: () => Navigator.pop(context),
        isDialog: false,
      ),
    );
  }
}

// ── Formulaire contenu (partagé mobile/PC) ────────────────────────────────────
class _CourseFormContent extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final String schoolId;
  final String classId;
  final SbCourse? existing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  final bool isDialog;

  const _CourseFormContent({
    this.scrollController,
    required this.schoolId,
    required this.classId,
    this.existing,
    required this.onSaved,
    required this.onCancel,
    required this.isDialog,
  });

  @override
  ConsumerState<_CourseFormContent> createState() => _CourseFormContentState();
}

class _CourseFormContentState extends ConsumerState<_CourseFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _desc;
  late final TextEditingController _program;
  late final TextEditingController _room;
  late int _coef;
  late int _hours;
  late int _chapters;
  late String _color;

  /// Les enseignants du cours — **plusieurs** possibles (co-enseignement).
  /// C'est ici, et nulle part ailleurs, qu'un prof gagne l'accès à la classe :
  /// carnet de notes et appel en découlent. L'ordre compte pour l'affichage
  /// seulement (le premier est « principal »).
  late List<String> _teacherIds;

  // Le cours est le PROGRAMME d'une matière dans une classe. Il ne redéclare
  // donc pas son nom : il choisit la matière. Le coefficient, lui, est celui de
  // la matière DANS CETTE CLASSE : maths coef 5 en série C, 2 en série A.
  String? _subjectId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name     = TextEditingController(text: e?.name ?? '');
    _code     = TextEditingController(text: e?.code ?? '');
    _desc     = TextEditingController(text: e?.description ?? '');
    _program  = TextEditingController(text: e?.programSummary ?? '');
    _room     = TextEditingController(text: e?.room ?? '');
    _coef     = e?.coefficient ?? 1;
    _hours    = e?.hoursWeek ?? 3;
    _chapters = e?.chapterCount ?? 6;
    _color    = e?.color ?? _courseColors.first;
    _teacherIds = [
      for (final t in (e?.teachers ?? const <SbCourseTeacher>[])) t.teacherId,
    ];
    _subjectId = e?.subjectId;
  }

  @override
  void dispose() {
    _name.dispose(); _code.dispose(); _desc.dispose();
    _program.dispose(); _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await SupabaseDbSource.createCourse(
          schoolId: widget.schoolId,
          classId: widget.classId,
          subjectId: _subjectId,
          name: _name.text,
          code: _code.text.isEmpty ? null : _code.text,
          teacherIds: _teacherIds,
          coefficient: _coef,
          hoursWeek: _hours,
          description: _desc.text.isEmpty ? null : _desc.text,
          color: _color,
          programSummary: _program.text.isEmpty ? null : _program.text,
          chapterCount: _chapters,
          room: _room.text.isEmpty ? null : _room.text,
        );
      } else {
        await SupabaseDbSource.updateCourse(
          id: widget.existing!.id,
          subjectId: _subjectId,
          name: _name.text,
          code: _code.text,
          coefficient: _coef,
          hoursWeek: _hours,
          description: _desc.text,
          color: _color,
          programSummary: _program.text,
          chapterCount: _chapters,
          room: _room.text.isEmpty ? null : _room.text,
        );
        await SupabaseDbSource.setCourseTeachers(
          courseId: widget.existing!.id,
          schoolId: widget.schoolId,
          teacherIds: _teacherIds,
        );
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);
    final selectedColor = Color(int.parse(_color.replaceFirst('#', '0xFF')));
    final cs = Theme.of(context).colorScheme;

    final content = SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        widget.isDialog ? 20 : 8,
        20,
        widget.isDialog ? 20 : MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Handle (mobile only) / Header ─────────────────────────
          if (!widget.isDialog)
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
            )),

          Row(children: [
            Expanded(
              child: Text(
                widget.existing == null ? 'Nouveau cours' : 'Modifier le cours',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.onSurface),
              ),
            ),
            // Close button always visible
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onCancel,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Matière ───────────────────────────────────────────────
          //  On CHOISIT la matière au lieu d'en retaper le nom. Sans ce lien, un
          //  cours n'était rattaché à rien : ni aux notes, ni aux bulletins, ni
          //  à l'emploi du temps. Le nom et le code suivent la matière.
          ref.watch(subjectsProvider).when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Matières indisponibles : $e',
                style: const TextStyle(color: _terra, fontSize: 12)),
            data: (subjects) => DropdownButtonFormField<String>(
              value: subjects.any((s) => s.id == _subjectId) ? _subjectId : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Matière *',
                prefixIcon: Icon(Icons.menu_book_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in subjects)
                  DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} (coef. ${s.coefficient})')),
              ],
              validator: (v) => v == null ? 'Choisissez une matière' : null,
              onChanged: (v) {
                final s = subjects.where((x) => x.id == v).firstOrNull;
                setState(() {
                  _subjectId = v;
                  // Le nom et le code du cours suivent la matière : ils n'ont
                  // pas à diverger.
                  if (s != null) {
                    _name.text = s.name;
                    _code.text = s.code ?? '';
                    _coef = s.coefficient;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── Description ───────────────────────────────────────────
          _Field(
            controller: _desc,
            label: 'Description',
            hint: 'Résumé de la matière…',
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          // ── Salle / Lieu ──────────────────────────────────────────
          _Field(
            controller: _room,
            label: 'Salle / Lieu',
            hint: 'ex: Salle B12, Labo Physique, Terrain…',
          ),
          const SizedBox(height: 4),
          // Suggestions rapides : un tap remplit le champ salle.
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final s in const [
              'Salle flexible', 'Non défini', 'Amphi A', 'Laboratoire', 'Terrain'
            ])
              _RoomSuggestion(s, onTap: () => setState(() => _room.text = s)),
          ]),
          const SizedBox(height: 14),

          // ── Coefficient + Heures/sem + Chapitres ─────────────────
          Row(children: [
            Expanded(child: _Stepper(label: 'Coefficient', value: _coef, min: 1, max: 10, onChanged: (v) => setState(() => _coef = v))),
            const SizedBox(width: 10),
            Expanded(child: _Stepper(label: 'H/semaine', value: _hours, min: 1, max: 20, onChanged: (v) => setState(() => _hours = v))),
            const SizedBox(width: 10),
            Expanded(child: _Stepper(label: 'Chapitres', value: _chapters, min: 0, max: 50, onChanged: (v) => setState(() => _chapters = v))),
          ]),
          const SizedBox(height: 16),

          // Jours de cours : retiré du formulaire — l'horaire (schedules,
          // page Emploi du temps) est la seule source fiable des jours d'un
          // cours ; ce champ manuel sur `courses` pouvait diverger de ce qui
          // est réellement placé dans la semaine. daysOfWeek reste lu en
          // affichage (données historiques) mais n'est plus saisi ici.

          // ── Programme scolaire ────────────────────────────────────
          _Field(
            controller: _program,
            label: 'Programme / Objectifs',
            hint: 'Détailler le programme annuel, les objectifs pédagogiques…',
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          // ── Enseignants ───────────────────────────────────────────
          //  PLUSIEURS possibles : au primaire le maître fait français/maths et
          //  la maîtresse éveil/anglais ; ailleurs deux profs se partagent une
          //  matière. Tous ont les mêmes droits — le « principal » n'est qu'un
          //  affichage.
          //
          //  C'est ICI qu'un prof gagne l'accès à la classe. Un cours sans
          //  enseignant, c'est une matière que personne ne peut noter.
          Text('Enseignants', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            'Ils pourront noter et faire l’appel dans cette classe, pour cette matière.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          teachersAsync.when(
            loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => Text('Enseignants indisponibles : $e',
                style: const TextStyle(color: _terra, fontSize: 12)),
            data: (teachers) {
              if (teachers.isEmpty) {
                return Text('Aucun enseignant dans cette école.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant));
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: teachers.map((t) {
                  final i = _teacherIds.indexOf(t.id);
                  final sel = i >= 0;
                  return FilterChip(
                    selected: sel,
                    showCheckmark: false,
                    avatar: sel
                        ? Icon(i == 0 ? Icons.star_rounded : Icons.person_rounded,
                            size: 16, color: Colors.white)
                        : null,
                    label: Text(t.fullName),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : cs.onSurfaceVariant,
                    ),
                    selectedColor: _terra,
                    backgroundColor: cs.surfaceContainerHighest,
                    side: BorderSide(color: sel ? _terra : cs.outlineVariant),
                    onSelected: (_) => setState(() {
                      sel ? _teacherIds.remove(t.id) : _teacherIds.add(t.id);
                    }),
                  );
                }).toList(),
              );
            },
          ),
          if (_teacherIds.length > 1) ...[
            const SizedBox(height: 6),
            Text('★ = enseignant principal. Les co-enseignants ont les mêmes droits.',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),

          // ── Couleur ───────────────────────────────────────────────
          Text('Couleur du cours', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _courseColors.map((hex) {
              final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
              final sel = hex == _color;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
                      boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: .5), blurRadius: 8)] : [],
                    ),
                    child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Bouton enregistrer ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: selectedColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );

    if (widget.isDialog) {
      return content;
    }
    return content;
  }
}

// ── Suggestion salle rapide ───────────────────────────────────────────────────
class _RoomSuggestion extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RoomSuggestion(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(label, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({required this.controller, required this.label, required this.hint, this.maxLines = 1, this.validator});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(fontSize: 13.5, color: cs.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: .5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant)),
        ),
      ),
    ]);
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.remove_rounded, size: 16), onPressed: value > min ? () => onChanged(value - 1) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 36)),
          Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
          IconButton(icon: const Icon(Icons.add_rounded, size: 16), onPressed: value < max ? () => onChanged(value + 1) : null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 36)),
        ]),
      ),
    ]);
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          onChanged: onChanged,
          style: TextStyle(fontSize: 13.5, color: cs.onSurface),
          decoration: InputDecoration(hintText: 'Rechercher un cours…', hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: .5)), isCollapsed: true, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
        )),
      ]),
    );
  }
}

class _EmptyClasses extends StatelessWidget {
  const _EmptyClasses();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.class_outlined, size: 52, color: cs.onSurfaceVariant.withValues(alpha: .4)),
          const SizedBox(height: 14),
          const Text('Aucune classe créée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _terra)),
          const SizedBox(height: 6),
          Text('Créez d\'abord des classes dans la section Classes.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _EmptyCourses extends ConsumerWidget {
  final String schoolId;
  final String classId;
  final VoidCallback onCreated;

  const _EmptyCourses({required this.schoolId, required this.classId, required this.onCreated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canProvider('classes.creer'));
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.menu_book_outlined, size: 52, color: Color(0xFFCCBBAA)),
            const SizedBox(height: 14),
            const Text('Aucun cours pour cette classe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _terra)),
            const SizedBox(height: 6),
            Builder(builder: (ctx) => Text(
                canCreate
                    ? 'Ajoutez des cours ou chargez les matières types.'
                    : 'Aucun cours n\'a encore été créé pour cette classe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
            if (canCreate) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => openCourseForm(
                  context, ref, schoolId, classId, null,
                  () {
                    ref.invalidate(coursesForClassProvider(classId));
                    ref.invalidate(coursesForSchoolProvider);
                    onCreated();
                  },
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer un cours'),
                style: FilledButton.styleFrom(backgroundColor: _terra),
              ),
            ],
          ]),
        ),
      );
  }
}

