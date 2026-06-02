import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/mock_data.dart';
import '../../../../shared/widgets/page_scaffold.dart';
import 'course_detail_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});
  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  bool _loading = true;
  String _searchQuery = '';
  String _filterClasse = 'Toutes';
  String _filterMatiere = 'Toutes';
  String _filterTeacher = 'Tous';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100),
        () { if (mounted) setState(() => _loading = false); });
  }

  List<String> get _classes => [
    'Toutes', '6e', '5e', '4e', '3e',
  ];

  List<String> get _matieres {
    final set = <String>{'Toutes'};
    for (final c in MockData.catalog) {
      set.add(c.name);
    }
    return set.toList();
  }

  List<String> get _teachers {
    final set = <String>{'Tous'};
    for (final c in MockData.catalog) {
      set.add(c.teacher);
    }
    return set.toList();
  }

  List<MockCourse> get _filtered {
    return MockData.catalog.where((c) {
      if (_filterClasse != 'Toutes' && c.classe != _filterClasse) return false;
      if (_filterMatiere != 'Toutes' && c.name != _filterMatiere) return false;
      if (_filterTeacher != 'Tous' && c.teacher != _filterTeacher) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!c.name.toLowerCase().contains(q) &&
            !c.teacher.toLowerCase().contains(q) &&
            !c.classe.toLowerCase().contains(q) &&
            !c.description.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final courses = _filtered;

    return PageScaffold(
      title: 'Catalogue des cours',
      subtitle: '${MockData.catalog.length} cours disponibles dans l\'établissement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barre de recherche ────────────────────────────────────
          _SearchBar(
            onChanged: (q) => setState(() => _searchQuery = q),
          ),
          const SizedBox(height: 14),

          // ── Filtres ───────────────────────────────────────────────
          _FilterRow(
            label: 'Classe',
            options: _classes,
            selected: _filterClasse,
            onSelected: (v) => setState(() => _filterClasse = v),
          ),
          const SizedBox(height: 8),
          _FilterRow(
            label: 'Matière',
            options: _matieres,
            selected: _filterMatiere,
            onSelected: (v) => setState(() => _filterMatiere = v),
          ),
          const SizedBox(height: 8),
          _FilterRow(
            label: 'Prof',
            options: _teachers,
            selected: _filterTeacher,
            onSelected: (v) => setState(() => _filterTeacher = v),
          ),
          const SizedBox(height: 16),

          // ── Résultat count ────────────────────────────────────────
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${courses.length} cours trouvé${courses.length > 1 ? 's' : ''}',
                style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),

          // ── Grille de cours ───────────────────────────────────────
          Skeletonizer(
            enabled: _loading,
            effect: const ShimmerEffect(
              baseColor: Color(0xFFDDD6CE),
              highlightColor: Color(0xFFEFEAE3),
            ),
            child: _loading
                ? _skeletonGrid()
                : courses.isEmpty
                    ? const _EmptySearch()
                    : _CourseGrid(
                        courses: courses,
                        onOpen: (c) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CourseDetailPage(course: c)),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonGrid() {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 1100 ? 3 : c.maxWidth > 720 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 230,
        ),
        itemBuilder: (_, __) => const _CourseSkeleton(),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Barre de recherche
// ══════════════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 18, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13.5, color: ink),
            decoration: const InputDecoration(
              hintText: 'Rechercher un cours, prof, classe…',
              hintStyle: TextStyle(fontSize: 13.5, color: muted),
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const Icon(Icons.tune_rounded, size: 16, color: muted),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Ligne de filtres
// ══════════════════════════════════════════════════════════════════════════
class _FilterRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final opt = options[i];
          final sel = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? _terra : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? _terra : border),
                boxShadow: sel
                    ? [BoxShadow(color: _terra.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Text(opt, style: TextStyle(
                color: sel ? Colors.white : muted,
                fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              )),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Grille de cours
// ══════════════════════════════════════════════════════════════════════════
class _CourseGrid extends StatelessWidget {
  final List<MockCourse> courses;
  final void Function(MockCourse) onOpen;
  const _CourseGrid({required this.courses, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 1100 ? 3 : c.maxWidth > 720 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: courses.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 230,
        ),
        itemBuilder: (_, i) => _CourseCard(course: courses[i], onOpen: () => onOpen(courses[i])),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Carte cours — design complet
// ══════════════════════════════════════════════════════════════════════════
class _CourseCard extends StatelessWidget {
  final MockCourse course;
  final VoidCallback onOpen;
  const _CourseCard({required this.course, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = course.color;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: c.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -2),
          const BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header coloré ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.withOpacity(0.12), c.withOpacity(0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c, c.withOpacity(0.75)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [BoxShadow(color: c.withOpacity(0.40), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Icon(course.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(course.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: ink, fontWeight: FontWeight.w800))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withOpacity(0.30)),
                  ),
                  child: Text(course.classe,
                      style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 11, color: muted),
                const SizedBox(width: 4),
                Expanded(child: Text(course.teacher,
                    style: const TextStyle(fontSize: 11.5, color: muted),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ])),
          ]),
        ),

        // ── Corps ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(course.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: muted, height: 1.4)),
            const SizedBox(height: 10),

            // Méta-infos
            Row(children: [
              _MetaChip(icon: Icons.auto_stories_rounded, label: '${course.chapters} chapitres', color: c),
              const SizedBox(width: 8),
              _MetaChip(icon: Icons.schedule_rounded, label: '${course.hoursPerWeek}h/sem.', color: c),
            ]),
            const SizedBox(height: 8),

            // Info importante
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.50)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFE65100)),
                const SizedBox(width: 6),
                Expanded(child: Text(course.importantInfo,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFE65100)))),
              ]),
            ),
          ]),
        ),

        const Spacer(),

        // ── Footer ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: GestureDetector(
            onTap: onOpen,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c, c.withOpacity(0.80)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: c.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Ouvrir le cours', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Skeleton d'une carte cours
// ══════════════════════════════════════════════════════════════════════════
class _CourseSkeleton extends StatelessWidget {
  const _CourseSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6CE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 76,
          decoration: const BoxDecoration(
            color: Color(0xFFDDD6CE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 12, width: 120, decoration: BoxDecoration(
                color: const Color(0xFFDDD6CE), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(height: 10, decoration: BoxDecoration(
                color: const Color(0xFFDDD6CE), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Container(height: 10, width: 180, decoration: BoxDecoration(
                color: const Color(0xFFDDD6CE), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Container(height: 36, decoration: BoxDecoration(
                color: const Color(0xFFDDD6CE), borderRadius: BorderRadius.circular(10))),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// État vide
// ══════════════════════════════════════════════════════════════════════════
class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF0E8DC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.search_off_rounded, color: muted, size: 26),
        ),
        const SizedBox(height: 14),
        const Text('Aucun cours trouvé', style: TextStyle(fontSize: 14, color: ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Essayez d\'autres filtres ou une autre recherche',
            style: TextStyle(fontSize: 12, color: muted)),
      ]),
    );
  }
}
