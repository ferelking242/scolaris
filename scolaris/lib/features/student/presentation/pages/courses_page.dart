import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import 'annales_quiz_page.dart';

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
      loading: () => const PageScaffold(title: 'Mes cours', child: Center(child: CircularProgressIndicator())),
      error:   (e, _) => PageScaffold(title: 'Mes cours', child: Center(child: Text('Erreur : $e'))),
      data: (courses) {
        final className = profile?.classe ?? '';
        final filtered  = _applyFilters(courses);
        return PageScaffold(
          title: 'Mes cours',
          subtitle: courses.isEmpty
              ? 'Aucun cours'
              : '${courses.length} cours${className.isNotEmpty ? ' · $className' : ''}',
          actions: [
            ActionButton(
              label: 'Annales & Quiz',
              icon: Icons.quiz_rounded,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnnalesQuizPage())),
            ),
          ],
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
              _ResourcesTab(color: color, subject: c.name),
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

// ── Tab Programme ─────────────────────────────────────────────────────────────
class _ProgramTab extends StatelessWidget {
  final SbCourse course;
  final Color color;
  const _ProgramTab({required this.course, required this.color});

  /// Strip **bold** markdown and trim.
  static String _clean(String s) => s.replaceAll(RegExp(r'\*{1,2}'), '').trim();

  /// Parse raw text into structured (title, subtitle?) pairs.
  static List<({String title, String? subtitle})> _parse(String raw) {
    // Try splitting on \n first; if only one line try splitting on bullet dash.
    var lines = raw.split('\n').map(_clean).where((l) => l.isNotEmpty).toList();

    // If data came as one big blob separated by \n inside, we're done.
    // Otherwise try em-dash as inline separator: "**Ch1** — Foo\n**Ch2** — Bar"
    final chapters = <({String title, String? subtitle})>[];

    // Pattern: lines may be "Chapitre 1 — Suites numériques" or just raw lines.
    for (final line in lines) {
      // Split title / subtitle at em-dash or " - "
      final dashIdx = line.indexOf(RegExp(r'[—–\-]{1,2}'));
      if (dashIdx > 0) {
        final title = line.substring(0, dashIdx).trim();
        final sub   = line.substring(dashIdx + 1).replaceFirst(RegExp(r'^[—–\-\s]+'), '').trim();
        chapters.add((title: title, subtitle: sub.isEmpty ? null : sub));
      } else {
        chapters.add((title: line, subtitle: null));
      }
    }
    return chapters;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (course.programSummary == null || course.programSummary!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.list_alt_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: .4)),
            const SizedBox(height: 12),
            Text('Programme non disponible',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 6),
            Text("L'enseignant n'a pas encore publié le programme de ce cours.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ]),
        ),
      );
    }

    final chapters = _parse(course.programSummary!);
    final total    = chapters.length;
    // Accent color with decent contrast
    final accent   = color;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Sec('Programme annuel', cs),
        const SizedBox(height: 20),
        // ── Tree ──────────────────────────────────────────────────────────────
        for (int i = 0; i < total; i++) ...[
          _ChapterNode(
            index: i,
            total: total,
            title: chapters[i].title,
            subtitle: chapters[i].subtitle,
            accent: accent,
            cs: cs,
          ),
        ],
      ]),
    );
  }
}

class _ChapterNode extends StatelessWidget {
  final int    index;
  final int    total;
  final String title;
  final String? subtitle;
  final Color  accent;
  final ColorScheme cs;

  const _ChapterNode({
    required this.index,
    required this.total,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isLast   = index == total - 1;
    final nodeSize = 32.0;
    final lineW    = 2.0;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Left column: circle + vertical line ──
        SizedBox(
          width: nodeSize,
          child: Column(children: [
            // Numbered circle
            Container(
              width: nodeSize,
              height: nodeSize,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _contrastColor(accent),
                ),
              ),
            ),
            // Vertical connector (hidden after last)
            if (!isLast)
              Expanded(
                child: Container(
                  width: lineW,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: accent.withValues(alpha: .25),
                ),
              )
            else
              const SizedBox(height: 16),
          ]),
        ),
        const SizedBox(width: 14),
        // ── Right column: title + subtitle ──
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24, top: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  height: 1.3,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  static Color _contrastColor(Color bg) {
    final lum = bg.computeLuminance();
    return lum > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
  }
}

// ── Tab Ressources ────────────────────────────────────────────────────────────
class _ResourcesTab extends ConsumerWidget {
  final Color color;
  final String subject;
  const _ResourcesTab({required this.color, required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(courseMaterialsForSubjectProvider(subject));

    Widget centered(Widget child) =>
        Center(child: Padding(padding: const EdgeInsets.all(32), child: child));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => centered(Text('Erreur : $e',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
      data: (mats) {
        if (mats.isEmpty) {
          return centered(Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_open_rounded,
                size: 48, color: cs.onSurfaceVariant.withValues(alpha: .4)),
            const SizedBox(height: 12),
            Text('Aucune ressource',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 6),
            Text(
                "Les documents et supports de ce cours apparaîtront ici dès "
                "que l'enseignant les aura déposés.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: mats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _ResourceTile(material: mats[i], color: color),
        );
      },
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final SbCourseMaterial material;
  final Color color;
  const _ResourceTile({required this.material, required this.color});

  static IconData _iconFor(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('corrig'))  return Icons.fact_check_rounded;
    if (t.contains('exerc'))   return Icons.edit_note_rounded;
    if (t.contains('td') || t.contains('tp')) return Icons.science_rounded;
    if (t.contains('video') || t.contains('vidéo')) return Icons.play_circle_rounded;
    return Icons.description_rounded;
  }

  static String _sizeLabel(int? kb) {
    if (kb == null || kb <= 0) return '';
    if (kb < 1024) return '$kb Ko';
    return '${(kb / 1024).toStringAsFixed(1)} Mo';
  }

  Future<void> _open() async {
    final url = material.fileUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFile = material.fileUrl != null && material.fileUrl!.isNotEmpty;
    final meta = [
      if (material.type != null && material.type!.isNotEmpty) material.type!,
      if (material.level != null && material.level!.isNotEmpty) material.level!,
      _sizeLabel(material.sizeKb),
    ].where((s) => s.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: hasFile ? _open : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(material.type), size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(material.title,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: cs.onSurface),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(meta, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ])),
          const SizedBox(width: 8),
          Icon(hasFile ? Icons.open_in_new_rounded : Icons.lock_outline_rounded,
              size: 15, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}
