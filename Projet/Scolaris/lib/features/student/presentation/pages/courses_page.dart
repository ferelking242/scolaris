import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import '../../../../shared/widgets/scol_shimmer.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;
const _green = ScolarisPalette.forestGreen;

// ── Subject icons par matière ──────────────────────────────────────────────────
IconData _iconFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('math'))       return Icons.calculate_rounded;
  if (n.contains('physique') || n.contains('chimie')) return Icons.science_rounded;
  if (n.contains('svt') || n.contains('biolog') || n.contains('vie')) return Icons.eco_rounded;
  if (n.contains('français') || n.contains('lettre')) return Icons.menu_book_rounded;
  if (n.contains('anglais') || n.contains('langue')) return Icons.language_rounded;
  if (n.contains('histoire') || n.contains('géo'))  return Icons.public_rounded;
  if (n.contains('philo'))      return Icons.lightbulb_rounded;
  if (n.contains('informatiq') || n.contains('info')) return Icons.computer_rounded;
  if (n.contains('eps') || n.contains('sport'))    return Icons.sports_soccer_rounded;
  if (n.contains('art') || n.contains('plastiq'))  return Icons.palette_rounded;
  if (n.contains('musique'))    return Icons.music_note_rounded;
  if (n.contains('droit'))      return Icons.gavel_rounded;
  if (n.contains('économ') || n.contains('compta')) return Icons.bar_chart_rounded;
  if (n.contains('civil'))      return Icons.account_balance_rounded;
  if (n.contains('socio'))      return Icons.people_rounded;
  if (n.contains('constit'))    return Icons.policy_rounded;
  if (n.contains('éducation') || n.contains('civic')) return Icons.emoji_events_rounded;
  return Icons.menu_book_rounded;
}

Color _parseColor(String? hex) {
  if (hex == null) return _terra;
  try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return _terra; }
}

// ── Filtre état ────────────────────────────────────────────────────────────────
enum _SortBy { alpha, coefDesc, hoursDesc }

class _FilterState {
  final Set<String> days;
  final _SortBy sort;
  const _FilterState({this.days = const {}, this.sort = _SortBy.alpha});
  bool get hasActive => days.isNotEmpty || sort != _SortBy.alpha;
  _FilterState copyWith({Set<String>? days, _SortBy? sort}) =>
      _FilterState(days: days ?? this.days, sort: sort ?? this.sort);
}

// ── Page principale ───────────────────────────────────────────────────────────
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});
  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  String _search = '';
  _FilterState _filter = const _FilterState();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<SbCourse> _applyFilters(List<SbCourse> courses) {
    var list = courses.where((c) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!c.name.toLowerCase().contains(q) &&
            !(c.code?.toLowerCase().contains(q) ?? false) &&
            !(c.teacherName?.toLowerCase().contains(q) ?? false)) return false;
      }
      if (_filter.days.isNotEmpty) {
        if (!c.daysOfWeek.any((d) => _filter.days.contains(d))) return false;
      }
      return true;
    }).toList();

    switch (_filter.sort) {
      case _SortBy.alpha:     list.sort((a, b) => a.name.compareTo(b.name));
      case _SortBy.coefDesc:  list.sort((a, b) => b.coefficient.compareTo(a.coefficient));
      case _SortBy.hoursDesc: list.sort((a, b) => (b.hoursWeek ?? 0).compareTo(a.hoursWeek ?? 0));
    }
    return list;
  }

  void _openFilterSheet(BuildContext ctx, List<SbCourse> courses) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        courses: courses,
        initial: _filter,
        onApply: (f) => setState(() => _filter = f),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(myCoursesProvider);
    final profile = ref.watch(myStudentProfileProvider).valueOrNull;
    final th = Theme.of(context);
    final cs = th.colorScheme;

    return coursesAsync.when(
      loading: () => const PageScaffold(title: 'Mes cours', child: ScolSkeletonGrid()),
      error:   (e, _) => PageScaffold(title: 'Mes cours', child: Center(child: Text('Erreur : $e'))),
      data: (courses) {
        final className = profile?.classe ?? '';
        final filtered  = _applyFilters(courses);
        return PageScaffold(
          title: 'Mes cours',
          subtitle: courses.isEmpty
              ? 'Aucun cours'
              : '${courses.length} cours${className.isNotEmpty ? ' · $className' : ''}',
          child: courses.isEmpty
              ? const _EmptyState()
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _StatsRow(courses: courses),
                  const SizedBox(height: 16),

                  // ── Barre recherche + filtre ─────────────────────────
                  Row(children: [
                    Expanded(child: _SearchBar(controller: _searchCtrl, onChanged: (q) => setState(() => _search = q))),
                    const SizedBox(width: 8),
                    _FilterBtn(
                      active: _filter.hasActive,
                      count: _filter.days.length + (_filter.sort != _SortBy.alpha ? 1 : 0),
                      onTap: () => _openFilterSheet(context, courses),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  if (filtered.isEmpty)
                    _noResult(cs)
                  else
                    _CourseGrid(
                      courses: filtered,
                      onOpen: (c) => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailPage(course: c))),
                    ),
                ]),
        );
      },
    );
  }

  Widget _noResult(ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Aucun cours trouvé', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Modifiez votre recherche ou vos filtres.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ]),
        ),
      );
}

// ── Stats ──────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<SbCourse> courses;
  const _StatsRow({required this.courses});

  @override
  Widget build(BuildContext context) {
    final totalH    = courses.fold<int>(0, (s, c) => s + (c.hoursWeek ?? 0));
    final totalCoef = courses.fold<int>(0, (s, c) => s + c.coefficient);
    final totalChap = courses.fold<int>(0, (s, c) => s + (c.chapterCount ?? 0));
    return Row(children: [
      _StatCard('${courses.length}', 'Matières',   _terra,                    Icons.menu_book_rounded),
      const SizedBox(width: 8),
      _StatCard('${totalH}h',        'Par sem.',   _gold,                     Icons.access_time_rounded),
      const SizedBox(width: 8),
      _StatCard('$totalCoef',        'Coef. tot.', _green,                    Icons.grade_rounded),
      const SizedBox(width: 8),
      _StatCard('$totalChap',        'Chapitres',  const Color(0xFF0D47A1),   Icons.list_alt_rounded),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCard(this.value, this.label, this.color, this.icon);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .28)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .07), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, height: 1)),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2),
        ]),
      ),
    );
  }
}

// ── Barre de recherche ─────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13.5, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Rechercher un cours…',
            hintStyle: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
            isCollapsed: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
          ),
        )),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: () { controller.clear(); onChanged(''); },
            child: Icon(Icons.close_rounded, size: 16, color: cs.onSurfaceVariant),
          ),
      ]),
    );
  }
}

// ── Bouton filtre ──────────────────────────────────────────────────────────────
class _FilterBtn extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;
  const _FilterBtn({required this.active, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: active ? _terra : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _terra : cs.outlineVariant),
        ),
        child: Stack(alignment: Alignment.center, children: [
          Icon(Icons.tune_rounded, size: 20, color: active ? Colors.white : cs.onSurfaceVariant),
          if (active && count > 0)
            Positioned(
              top: 7, right: 7,
              child: Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Center(child: Text('$count', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: _terra))),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Grille cours ───────────────────────────────────────────────────────────────
class _CourseGrid extends StatelessWidget {
  final List<SbCourse> courses;
  final void Function(SbCourse) onOpen;
  const _CourseGrid({required this.courses, required this.onOpen});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 1100 ? 3 : c.maxWidth > 600 ? 2 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: courses.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 152,
          ),
          itemBuilder: (_, i) => _CourseCard(course: courses[i], onOpen: () => onOpen(courses[i])),
        );
      });
}

// ── Carte cours ────────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final SbCourse course;
  final VoidCallback onOpen;
  const _CourseCard({required this.course, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(course.color);
    final cs    = Theme.of(context).colorScheme;
    final icon  = _iconFor(course.name);

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .25), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(children: [
            // Gradient background strip
            Positioned(
              top: -20, right: -20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [color.withValues(alpha: .18), Colors.transparent]),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Header ──────────────────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: .75)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 21),
                  ),
                  const Spacer(),
                  if (course.teacherName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        course.teacherName!.split(' ').last,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),

                // ── Nom ─────────────────────────────────────────────────
                Text(course.name,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),

                if (course.code != null) ...[
                  const SizedBox(height: 2),
                  Text(course.code!, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                ],

                const Spacer(),

                // ── Footer ───────────────────────────────────────────────
                Row(children: [
                  _Tag('Coef ${course.coefficient}', color),
                  const SizedBox(width: 5),
                  if (course.hoursWeek != null) _Tag('${course.hoursWeek}h', _gold),
                  if (course.daysOfWeek.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    _Tag('${course.daysOfWeek.length}j/sem', color),
                  ],
                  const Spacer(),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );
}

// ── État vide ──────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.menu_book_outlined, size: 56, color: cs.onSurfaceVariant.withValues(alpha: .5)),
          const SizedBox(height: 16),
          Text('Aucun cours disponible', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 6),
          Text("Vos cours apparaîtront ici dès que l'établissement les aura publiés.",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

// ── Filter Bottom Sheet ────────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final List<SbCourse> courses;
  final _FilterState initial;
  final void Function(_FilterState) onApply;
  const _FilterSheet({required this.courses, required this.initial, required this.onApply});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _days;
  late _SortBy _sort;

  static const _dayLabels = {
    'lundi': 'Lundi', 'mardi': 'Mardi', 'mercredi': 'Mercredi',
    'jeudi': 'Jeudi', 'vendredi': 'Vendredi', 'samedi': 'Samedi',
  };
  static const _sortLabels = {
    _SortBy.alpha:     'Alphabétique',
    _SortBy.coefDesc:  'Coefficient (↓)',
    _SortBy.hoursDesc: 'Heures/semaine (↓)',
  };

  @override
  void initState() {
    super.initState();
    _days = Set.from(widget.initial.days);
    _sort = widget.initial.sort;
  }

  Set<String> get _availableDays {
    final days = <String>{};
    for (final c in widget.courses) days.addAll(c.daysOfWeek);
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final avail = _availableDays;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),

        // ── Header ─────────────────────────────────────────────────────────────
        Row(children: [
          Text('Filtrer & trier', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: cs.onSurface)),
          const Spacer(),
          TextButton(
            onPressed: () { setState(() { _days = {}; _sort = _SortBy.alpha; }); },
            child: const Text('Réinitialiser', style: TextStyle(color: _terra)),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Jours de cours ─────────────────────────────────────────────────────
        if (avail.isNotEmpty) ...[
          _SectionLabel('Jour de cours', cs),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _dayLabels.entries
              .where((e) => avail.contains(e.key))
              .map((e) {
                final sel = _days.contains(e.key);
                return FilterChip(
                  label: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : cs.onSurface)),
                  selected: sel,
                  onSelected: (_) => setState(() => sel ? _days.remove(e.key) : _days.add(e.key)),
                  selectedColor: _terra,
                  backgroundColor: cs.surfaceContainer,
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  side: BorderSide(color: sel ? _terra : cs.outlineVariant),
                );
              }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Trier par ──────────────────────────────────────────────────────────
        _SectionLabel('Trier par', cs),
        const SizedBox(height: 8),
        ..._sortLabels.entries.map((e) {
          final sel = _sort == e.key;
          return GestureDetector(
            onTap: () => setState(() => _sort = e.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: sel ? _terra.withValues(alpha: .08) : cs.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _terra : cs.outlineVariant),
              ),
              child: Row(children: [
                Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18, color: sel ? _terra : cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(e.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? _terra : cs.onSurface)),
              ]),
            ),
          );
        }),
        const SizedBox(height: 8),

        // ── Type de matière ────────────────────────────────────────────────────
        _SectionLabel('Catégorie', cs),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: const [
          _TypeChip('Toutes',      Icons.apps_rounded,            true),
          _TypeChip('Sciences',    Icons.science_rounded,         false),
          _TypeChip('Lettres',     Icons.menu_book_rounded,       false),
          _TypeChip('Langues',     Icons.language_rounded,        false),
          _TypeChip('Arts & EPS',  Icons.palette_rounded,         false),
          _TypeChip('Humaines',    Icons.public_rounded,          false),
          _TypeChip('Droit/Éco',   Icons.gavel_rounded,           false),
        ]),
        const SizedBox(height: 24),

        // ── Appliquer ──────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _terra, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              widget.onApply(_FilterState(days: _days, sort: _sort));
              Navigator.pop(context);
            },
            child: const Text('Appliquer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  const _TypeChip(this.label, this.icon, this.selected);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _terra.withValues(alpha: .1) : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _terra : cs.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: selected ? _terra : cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
            color: selected ? _terra : cs.onSurface)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _SectionLabel(this.label, this.cs);
  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 0.5));
}

// ══════════════════════════════════════════════════════════════════════════════
// Détail d'un cours
// ══════════════════════════════════════════════════════════════════════════════
class CourseDetailPage extends StatefulWidget {
  final SbCourse course;
  const CourseDetailPage({super.key, required this.course});
  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c     = widget.course;
    final color = _parseColor(c.color);
    final icon  = _iconFor(c.name);
    final cs    = Theme.of(context).colorScheme;
    final top   = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        // ── Hero avec icône centrée ──────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: .95), color.withValues(alpha: .75)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(children: [
            // Cercle décoratif en fond
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 40, left: -30,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .04),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 12, 16, 24),
              child: Column(children: [
                // ── Top bar ───────────────────────────────────────────────────
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (c.teacherName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c.teacherName!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 16),

                // ── Icône centrée ─────────────────────────────────────────────
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: .35), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 14),

                // ── Nom + code ────────────────────────────────────────────────
                Text(c.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                if (c.code != null) ...[
                  const SizedBox(height: 4),
                  Text(c.code!, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .8), fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 14),

                // ── Chips ─────────────────────────────────────────────────────
                Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  _HChip(Icons.grade_rounded, 'Coef. ${c.coefficient}'),
                  if (c.hoursWeek != null) _HChip(Icons.access_time_rounded, '${c.hoursWeek}h/semaine'),
                  if (c.chapterCount != null && c.chapterCount! > 0) _HChip(Icons.list_alt_rounded, '${c.chapterCount} chapitres'),
                  if (c.daysOfWeek.isNotEmpty) _HChip(Icons.calendar_today_rounded, _fmtDays(c.daysOfWeek)),
                ]),
              ]),
            ),
          ]),
        ),

        // ── TabBar stylée ────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: TabBar(
            controller: _tab,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline_rounded, size: 16), text: 'Infos'),
              Tab(icon: Icon(Icons.list_alt_rounded, size: 16), text: 'Programme'),
              Tab(icon: Icon(Icons.folder_open_rounded, size: 16), text: 'Ressources'),
            ],
            labelColor: color,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
            indicatorColor: color,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),

        // ── Content ──────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _InfoTab(course: c, color: color),
              _ProgramTab(course: c, color: color),
              _ResourcesTab(course: c, color: color),
            ],
          ),
        ),
      ]),
    );
  }

  String _fmtDays(List<String> days) {
    const map = {'lundi': 'Lun', 'mardi': 'Mar', 'mercredi': 'Mer', 'jeudi': 'Jeu', 'vendredi': 'Ven', 'samedi': 'Sam'};
    return days.map((d) => map[d] ?? d.substring(0, 3)).join(' · ');
  }
}

class _HChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Tab Infos ─────────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  final SbCourse course;
  final Color color;
  const _InfoTab({required this.course, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (course.description != null && course.description!.isNotEmpty) ...[
          _Sec('Description', cs),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: .2)),
            ),
            child: Text(course.description!, style: TextStyle(fontSize: 13.5, color: cs.onSurface, height: 1.5)),
          ),
          const SizedBox(height: 16),
        ],

        _Sec('Informations', cs),
        const SizedBox(height: 10),
        _Row(Icons.book_outlined,          'Matière',          course.name,               color, cs),
        if (course.code != null)
          _Row(Icons.tag_rounded,          'Code',             course.code!,              color, cs),
        _Row(Icons.grade_rounded,          'Coefficient',      '${course.coefficient}',   color, cs),
        if (course.hoursWeek != null)
          _Row(Icons.access_time_rounded,  'Heures/semaine',   '${course.hoursWeek}h',    color, cs),
        if (course.chapterCount != null)
          _Row(Icons.list_alt_rounded,     'Chapitres',        '${course.chapterCount}',  color, cs),
        if (course.teacherName != null)
          _Row(Icons.person_outline_rounded,'Enseignant',      course.teacherName!,       color, cs),
        if (course.daysOfWeek.isNotEmpty)
          _Row(Icons.calendar_today_rounded,'Jours de cours',  _fmt(course.daysOfWeek),   color, cs),
      ]),
    );
  }

  String _fmt(List<String> d) {
    const m = {'lundi':'Lundi','mardi':'Mardi','mercredi':'Mercredi','jeudi':'Jeudi','vendredi':'Vendredi','samedi':'Samedi'};
    return d.map((x) => m[x] ?? x).join(', ');
  }
}

class _Sec extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _Sec(this.label, this.cs);
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ]);
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final ColorScheme cs;
  const _Row(this.icon, this.label, this.value, this.color, this.cs);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant)),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface))),
        ]),
      );
}

// ── Curriculum data ────────────────────────────────────────────────────────────
class _CChapter {
  final String num, title;
  final List<String> lessons;
  _CChapter(this.num, this.title, this.lessons);
}

List<_CChapter> _getCurriculum(String name) {
  final n = name.toLowerCase();
  if (n.contains('math')) return [
    _CChapter('I',   'Analyse — Fonctions et limites',          ['Rappels sur les fonctions réelles', 'Limites et continuité', 'Dérivabilité et dérivées usuelles', 'Étude de fonctions']),
    _CChapter('II',  'Analyse — Intégration',                   ['Primitives d\'une fonction', 'Intégrales définies (Riemann)', 'Calcul d\'aires et de volumes', 'Intégration par parties']),
    _CChapter('III', 'Équations différentielles',               ['É.D. du 1er ordre à variables séparées', 'É.D. linéaires du 1er ordre', 'É.D. du 2ème ordre à coefficients constants']),
    _CChapter('IV',  'Probabilités & Statistiques',             ['Probabilités conditionnelles et Bayes', 'Variables aléatoires discrètes', 'Loi binomiale B(n,p)', 'Statistiques descriptives']),
    _CChapter('V',   'Géométrie dans l\'espace',                ['Vecteurs, droites et plans', 'Positions relatives', 'Distances et angles', 'Sphère et surfaces']),
    _CChapter('VI',  'Suites numériques',                       ['Suites arithmétiques et géométriques', 'Convergence et limites', 'Suites récurrentes', 'Raisonnement par récurrence']),
  ];
  if (n.contains('physique') || n.contains('chimie') || n.contains('pc')) return [
    _CChapter('I',   'Mécanique du point',                      ['Cinématique — mouvement rectiligne', 'Dynamique — lois de Newton', 'Travail et énergie cinétique', 'Chute libre et projectile']),
    _CChapter('II',  'Électricité',                             ['Régime continu — lois de Kirchhoff', 'Dipôles actifs et passifs', 'Régimes transitoires RC et RL', 'Oscillations LC']),
    _CChapter('III', 'Optique géométrique',                     ['Réflexion et réfraction', 'Lentilles minces convergentes/divergentes', 'Instruments d\'optique', 'Miroirs']),
    _CChapter('IV',  'Chimie — Réactions acido-basiques',       ['Acides, bases et pH', 'Réactions acido-basiques', 'Titrages et indicateurs', 'Tampons']),
    _CChapter('V',   'Chimie organique',                        ['Alcanes, alcènes, alcools', 'Réactions de substitution et d\'addition', 'Esters et savons', 'Polymères']),
    _CChapter('VI',  'Thermodynamique',                         ['Temperature, chaleur, calorimétrie', '1er et 2ème principes', 'Cycles thermodynamiques', 'Machines thermiques']),
  ];
  if (n.contains('svt') || n.contains('biolog') || n.contains('vie') || n.contains('terre')) return [
    _CChapter('I',   'Génétique & Hérédité',                    ['ADN et expression des gènes', 'Méiose et brassage génétique', 'Lois de Mendel', 'Mutations et maladies génétiques']),
    _CChapter('II',  'Évolution des êtres vivants',             ['Théorie de l\'évolution (Darwin)', 'Sélection naturelle et dérive génétique', 'Spéciation et phylogénèse', 'Preuves de l\'évolution']),
    _CChapter('III', 'Immunologie',                             ['Système immunitaire inné', 'Immunité adaptative — lymphocytes B et T', 'Vaccination et mémoire immunitaire', 'Sida et déficits immunitaires']),
    _CChapter('IV',  'Neurophysiologie',                        ['Neurone et influx nerveux', 'Synapse et neurotransmetteurs', 'Réflexes et arcs réflexes', 'Cerveau et fonctions supérieures']),
    _CChapter('V',   'Reproduction & Développement',            ['Reproduction sexuée', 'Gamétogenèse', 'Fécondation et développement embryonnaire', 'Hormones et régulation']),
    _CChapter('VI',  'Écologie & Environnement',                ['Écosystèmes et biomes', 'Chaînes et réseaux alimentaires', 'Cycles biogéochimiques', 'Déforestation et biodiversité']),
  ];
  if (n.contains('franç') || n.contains('lettre') || n.contains('littér')) return [
    _CChapter('S1',  'Lecture analytique & Texte',              ['Méthodologie de la lecture analytique', 'Narrateur, point de vue et focalisation', 'Procédés stylistiques et figures de style', 'Commentaire composé']),
    _CChapter('S2',  'Argumentation & Rhétorique',              ['Types d\'arguments (logique, exemple, autorité)', 'Mouvements argumentatifs', 'La dissertation littéraire', 'Débat oral']),
    _CChapter('S3',  'Poésie — Du XIXe au XXe siècle',          ['Le romantisme (Lamartine, Hugo)', 'Le symbolisme (Verlaine, Rimbaud, Mallarmé)', 'Les surréalistes (Breton, Éluard)', 'Poésie africaine (Senghor, Césaire)']),
    _CChapter('S4',  'Roman & Récit africain',                  ['Le roman réaliste et naturaliste', 'La Négritude dans la littérature', 'Auteurs africains : Kourouma, Bebey, Beyala', 'Analyse de texte']),
    _CChapter('S5',  'Théâtre',                                 ['Structure dramatique et registres', 'Le théâtre classique (Molière, Racine)', 'Le théâtre moderne (Ionesco, Beckett)', 'Mise en scène et jeu de rôle']),
    _CChapter('Ex.', 'Expression écrite & orale',               ['Rédaction de dissertation', 'Commentaire de texte', 'Synthèse de documents', 'Exposé oral noté']),
  ];
  if (n.contains('anglais') || n.contains('langues')) return [
    _CChapter('U1',  'Grammar & Structures',                    ['Tenses review (past, present, future)', 'Conditionals 1, 2 & 3', 'Modal verbs and passive voice', 'Reported speech']),
    _CChapter('U2',  'Oral Communication',                      ['Listening comprehension strategies', 'Pronunciation and intonation', 'Discussion and debate skills', 'Presentation techniques']),
    _CChapter('U3',  'Reading & Writing',                       ['Reading comprehension — inference', 'Essay writing (argumentative/descriptive)', 'Letter and email writing', 'Summary and paraphrase']),
    _CChapter('U4',  'Thematic Vocabulary',                     ['Technology and the digital world', 'Environment and sustainability', 'Society, culture and identity', 'Africa in the 21st century']),
    _CChapter('U5',  'Literature & Civilisation',               ['Anglophone African literature', 'British and American texts', 'Civilisation: UK & USA', 'African-American history']),
  ];
  if (n.contains('philo')) return [
    _CChapter('I',   'La Conscience & Le Sujet',                ['Conscience de soi et rapport à l\'autre', 'L\'inconscient freudien', 'L\'identité personnelle', 'Autrui et intersubjectivité']),
    _CChapter('II',  'La Liberté & La Responsabilité',          ['Libre arbitre vs déterminisme', 'Responsabilité morale et juridique', 'Liberté politique (Rousseau, Locke)', 'L\'existentialisme (Sartre)']),
    _CChapter('III', 'La Raison & La Vérité',                   ['Rationalisme (Descartes) et empirisme', 'Vérité scientifique et méthode', 'L\'opinion, le doute, la certitude', 'Les limites de la raison']),
    _CChapter('IV',  'La Justice & L\'État',                    ['Droit naturel et droit positif', 'L\'État, ses fonctions et ses limites', 'Justice sociale (Rawls, Marx)', 'Légitimité et légalité']),
    _CChapter('V',   'La Religion & La Foi',                    ['Religion et raison', 'Foi et preuves de l\'existence de Dieu', 'Critique de la religion (Marx, Nietzsche)', 'Spiritualité et sécularisation']),
    _CChapter('VI',  'Le Travail & La Technique',               ['Travail comme valeur et aliénation', 'Technique et humanité', 'Le progrès : mythe ou réalité ?', 'Art et technique']),
  ];
  if (n.contains('histoire') || n.contains('géo') || n.contains('geo')) return [
    _CChapter('H1',  'Le Monde depuis 1945',                    ['La Guerre froide (1947–1991)', 'Décolonisation en Afrique et en Asie', 'Les crises de la bipolarisation', 'Le monde post-guerre froide']),
    _CChapter('H2',  'L\'Afrique contemporaine',                ['L\'Afrique dans le système international', 'Conflits, instabilité et gouvernance', 'Intégration régionale (UA, CEMAC)', 'Développement et inégalités']),
    _CChapter('H3',  'Le Congo-Brazzaville',                    ['Histoire politique depuis l\'indépendance', 'Les guerres civiles (1993–1999)', 'Reconstruction et enjeux économiques', 'Ressources naturelles et développement']),
    _CChapter('G1',  'Géographie — Les grandes régions',        ['Les grands domaines climatiques', 'Population mondiale et migrations', 'Mondialisation et inégalités spatiales', 'Mégapoles et urbanisation']),
    _CChapter('G2',  'Géographie du Congo',                     ['Géographie physique (bassins, relief)', 'Économie (pétrole, forêt, agriculture)', 'Population, villes et aménagements', 'Enjeux environnementaux']),
  ];
  if (n.contains('eps') || n.contains('sport') || n.contains('éduc')) return [
    _CChapter('1',   'Activités Athlétiques',                   ['Sprint et relais', 'Sauts (longueur, hauteur)', 'Lancers (disque, poids)', 'Endurance et fonds']),
    _CChapter('2',   'Sports Collectifs',                       ['Football', 'Basketball', 'Volleyball', 'Handball']),
    _CChapter('3',   'Gymnastique',                             ['Acrobaties au sol', 'Barres parallèles et barre fixe', 'Poutre', 'Saut de cheval']),
    _CChapter('4',   'Sports de Raquette',                      ['Tennis de table', 'Badminton', 'Tennis', 'Techniques et règles']),
    _CChapter('5',   'Théorie : Santé & Corps',                 ['Anatomie musculaire', 'Hygiène et nutrition sportive', 'Prévention des blessures', 'Dopage : enjeux éthiques']),
  ];
  if (n.contains('info') || n.contains('informatiqu')) return [
    _CChapter('I',   'Algorithmique & Programmation',           ['Types de données et variables', 'Structures conditionnelles et boucles', 'Tableaux et fonctions', 'Récursivité']),
    _CChapter('II',  'Bases de données',                        ['Modèle relationnel (tables, clés)', 'Requêtes SQL (SELECT, JOIN, ...)', 'Normalisation', 'Sécurité des données']),
    _CChapter('III', 'Réseaux informatiques',                   ['Architecture client-serveur', 'Protocoles TCP/IP', 'Internet et le Web', 'Cybersécurité']),
    _CChapter('IV',  'Traitement de l\'information',            ['Représentation binaire', 'Compression et encodage', 'Algorithmes de tri', 'Complexité algorithmique']),
  ];
  // default
  return [
    _CChapter('I',   'Introduction & Fondements',               ['Présentation de la matière', 'Concepts de base', 'Histoire et évolution', 'Méthodes de travail']),
    _CChapter('II',  'Notions fondamentales',                   ['Définitions essentielles', 'Théories et modèles', 'Applications pratiques', 'Exercices d\'application']),
    _CChapter('III', 'Approfondissement',                       ['Cas complexes et exceptions', 'Liens avec d\'autres disciplines', 'Recherche documentaire', 'Travaux dirigés']),
    _CChapter('IV',  'Révision & Préparation à l\'examen',      ['Synthèse de l\'année', 'Annales et exercices corrigés', 'Méthode de dissertation / composition', 'Conseils pour le BAC']),
  ];
}

// ── Tab Programme — arbre du programme scolaire ───────────────────────────────
class _ProgramTab extends StatefulWidget {
  final SbCourse course;
  final Color color;
  const _ProgramTab({required this.course, required this.color});
  @override
  State<_ProgramTab> createState() => _ProgramTabState();
}

class _ProgramTabState extends State<_ProgramTab> {
  late final List<_CChapter> _chapters;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _chapters = _getCurriculum(widget.course.name);
    if (_chapters.isNotEmpty) _expanded.add(0); // open first chapter
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final color = widget.color;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Entête programme ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: .12), color.withValues(alpha: .04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .22)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_tree_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Programme annuel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
              Text('${_chapters.length} chapitres · Année scolaire 2025-2026',
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_chapters.fold<int>(0, (s, c) => s + c.lessons.length)} leçons',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Arbre des chapitres ───────────────────────────────────────────────
        ..._chapters.asMap().entries.map((e) {
          final idx  = e.key;
          final chap = e.value;
          final open = _expanded.contains(idx);
          return _ChapterNode(
            chapter: chap,
            isOpen: open,
            color: color,
            cs: cs,
            isLast: idx == _chapters.length - 1,
            onToggle: () => setState(() => open ? _expanded.remove(idx) : _expanded.add(idx)),
          );
        }),
      ]),
    );
  }
}

class _ChapterNode extends StatelessWidget {
  final _CChapter chapter;
  final bool isOpen, isLast;
  final Color color;
  final ColorScheme cs;
  final VoidCallback onToggle;
  const _ChapterNode({
    required this.chapter, required this.isOpen, required this.isLast,
    required this.color, required this.cs, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Chapter row ──────────────────────────────────────────────────────
      GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isOpen ? color.withValues(alpha: .08) : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isOpen ? color.withValues(alpha: .3) : cs.outlineVariant),
          ),
          child: Row(children: [
            // Chapter num badge
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: isOpen ? color : color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(chapter.num,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isOpen ? Colors.white : color,
                    )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chapter.title,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: isOpen ? cs.onSurface : cs.onSurface.withValues(alpha: .85),
                    )),
                Text('${chapter.lessons.length} leçon${chapter.lessons.length > 1 ? "s" : ""}',
                    style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
              ]),
            ),
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded,
                  size: 20, color: isOpen ? color : cs.onSurfaceVariant),
            ),
          ]),
        ),
      ),

      // ── Lessons tree ─────────────────────────────────────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: isOpen
            ? Padding(
                padding: const EdgeInsets.only(left: 17, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: chapter.lessons.asMap().entries.map((e) {
                    final isLastLesson = e.key == chapter.lessons.length - 1;
                    return IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // Tree line
                        SizedBox(
                          width: 16,
                          child: Column(children: [
                            Container(width: 1.5, color: color.withValues(alpha: .25),
                                height: isLastLesson ? 22 : double.infinity),
                            if (isLastLesson) const SizedBox(height: 4),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.value,
                                  style: TextStyle(fontSize: 12.5, color: cs.onSurface, height: 1.3))),
                            ]),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              )
            : const SizedBox.shrink(),
      ),
      SizedBox(height: isLast ? 0 : 8),
    ]);
  }
}

// ── Tab Ressources — liste par section avec lien bibliothèque ────────────────
class _ResSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _ResSection({required this.title, required this.icon, required this.color, required this.items});
}

class _ResourcesTab extends StatelessWidget {
  final SbCourse course;
  final Color color;
  const _ResourcesTab({required this.course, required this.color});

  List<_ResSection> _sections() => [
    _ResSection(
      title: 'Cours & Supports',
      icon: Icons.picture_as_pdf_rounded,
      color: const Color(0xFFD32F2F),
      items: ['Cours complet du chapitre I', 'Résumé de cours — fiche synthèse', 'Cours en diapositives (slides)'],
    ),
    _ResSection(
      title: 'Exercices & TD',
      icon: Icons.edit_note_rounded,
      color: const Color(0xFF1565C0),
      items: ['TD n°1 — exercices d\'application', 'TD n°2 — problèmes corrigés', 'Fiches de révision'],
    ),
    _ResSection(
      title: 'Annales & BAC',
      icon: Icons.school_rounded,
      color: const Color(0xFF2E7D32),
      items: ['Annales BAC 2023 corrigées', 'Annales BAC 2022 corrigées', 'Sujets de composition interne'],
    ),
    _ResSection(
      title: 'Ressources en ligne',
      icon: Icons.link_rounded,
      color: const Color(0xFF6A1B9A),
      items: ['Vidéos explicatives (Khan Academy)', 'Exercices interactifs en ligne', 'Liens vers ressources officielles'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sections = _sections();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Bouton "Voir dans la bibliothèque" ──────────────────────────────
        GestureDetector(
          onTap: () => Navigator.pop(context), // TODO: route to library page
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: .75)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_library_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bibliothèque', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                const Text('Tous les documents disponibles', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // ── Sections de ressources ───────────────────────────────────────────
        ...sections.map((sec) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(sec.icon, size: 15, color: sec.color),
            const SizedBox(width: 6),
            Text(sec.title,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: 0.2)),
          ]),
          const SizedBox(height: 8),
          ...sec.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: sec.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(sec.icon, size: 15, color: sec.color),
              ),
              title: Text(item, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
              subtitle: Text('Disponible dans la bibliothèque',
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
              trailing: Icon(Icons.open_in_new_rounded, size: 14, color: sec.color.withValues(alpha: .7)),
              onTap: () => Navigator.pop(context), // TODO: open in library
            ),
          )),
          const SizedBox(height: 14),
        ])),
      ]),
    );
  }
}
