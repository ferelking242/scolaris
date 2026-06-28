import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra = ScolarisPalette.terracotta;
const _gold  = ScolarisPalette.gold;
const _green = ScolarisPalette.forestGreen;

// ── Page principale ───────────────────────────────────────────────────────────
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(myCoursesProvider);
    final profile = ref.watch(myStudentProfileProvider).valueOrNull;

    return coursesAsync.when(
      loading: () => const PageScaffold(
        title: 'Mes cours',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Mes cours',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (courses) {
        final className = profile?.classe ?? '';
        final filtered = _search.isEmpty
            ? courses
            : courses.where((c) =>
                c.name.toLowerCase().contains(_search.toLowerCase()) ||
                (c.code?.toLowerCase().contains(_search.toLowerCase()) ?? false) ||
                (c.teacherName?.toLowerCase().contains(_search.toLowerCase()) ?? false)).toList();

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
                  _SearchBar(onChanged: (q) => setState(() => _search = q)),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFAA9080)),
                          SizedBox(height: 12),
                          Text('Aucun cours trouvé', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF8B1A00))),
                          SizedBox(height: 4),
                          Text('Modifiez votre recherche.', style: TextStyle(fontSize: 13, color: Color(0xFF7A5C44))),
                        ]),
                      ),
                    )
                  else
                    _CourseGrid(
                      courses: filtered,
                      onOpen: (c) => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CourseDetailPage(course: c)),
                      ),
                    ),
                ]),
        );
      },
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<SbCourse> courses;
  const _StatsRow({required this.courses});

  @override
  Widget build(BuildContext context) {
    final totalH    = courses.fold<int>(0, (s, c) => s + (c.hoursWeek ?? 0));
    final totalCoef = courses.fold<int>(0, (s, c) => s + c.coefficient);
    final totalChap = courses.fold<int>(0, (s, c) => s + (c.chapterCount ?? 0));
    return Row(children: [
      _StatCard(value: '${courses.length}', label: 'Matières',  color: _terra),
      const SizedBox(width: 8),
      _StatCard(value: '${totalH}h',        label: 'Par sem.',  color: _gold),
      const SizedBox(width: 8),
      _StatCard(value: '$totalCoef',        label: 'Coef. tot.', color: _green),
      const SizedBox(width: 8),
      _StatCard(value: '$totalChap',        label: 'Chapitres', color: const Color(0xFF0D47A1)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .2)),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF7A5C44)), textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Grille des cours ──────────────────────────────────────────────────────────
class _CourseGrid extends StatelessWidget {
  final List<SbCourse> courses;
  final void Function(SbCourse) onOpen;
  const _CourseGrid({required this.courses, required this.onOpen});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 1100 ? 3 : c.maxWidth > 700 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: courses.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 215,
          ),
          itemBuilder: (_, i) => _CourseCard(
            course: courses[i],
            onOpen: () => onOpen(courses[i]),
          ),
        );
      });
}

// ── Carte cours ───────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final SbCourse course;
  final VoidCallback onOpen;
  const _CourseCard({required this.course, required this.onOpen});

  static Color parseColor(String? hex) {
    if (hex == null) return _terra;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return _terra; }
  }

  @override
  Widget build(BuildContext context) {
    final color = parseColor(course.color);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .22), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .10), blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -2)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ─────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: .7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
            ),
            const Spacer(),
            if (course.teacherName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  course.teacherName!.split(' ').last,
                  style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700),
                ),
              ),
          ]),
          const SizedBox(height: 10),

          // ── Nom ─────────────────────────────────────────────────────
          Text(course.name,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1A0A00), letterSpacing: -0.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (course.description != null) ...[
            const SizedBox(height: 3),
            Text(course.description!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E8070)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],

          const Spacer(),

          // ── Jours ───────────────────────────────────────────────────
          if (course.daysOfWeek.isNotEmpty) ...[
            Row(children: course.daysOfWeek.take(5).map((d) {
              const keys   = ['lundi','mardi','mercredi','jeudi','vendredi','samedi'];
              const labels = ['L','Ma','Me','J','V','S'];
              final idx = keys.indexOf(d);
              return Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(4)),
                child: Text(idx >= 0 ? labels[idx] : d[0].toUpperCase(), style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w800)),
              );
            }).toList()),
            const SizedBox(height: 6),
          ],

          // ── Footer ──────────────────────────────────────────────────
          Row(children: [
            _Tag('Coef. ${course.coefficient}', color),
            const SizedBox(width: 6),
            if (course.hoursWeek != null) _Tag('${course.hoursWeek}h/sem', _gold),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, size: 16, color: color),
          ]),
        ]),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
      );
}

// ── Search bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDCCBB)),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xFF7A5C44)),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A0A00)),
            decoration: const InputDecoration(
              hintText: 'Rechercher un cours…',
              hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF7A5C44)),
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          )),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.menu_book_outlined, size: 56, color: Color(0xFFCCBBAA)),
            SizedBox(height: 16),
            Text('Aucun cours disponible', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF8B1A00))),
            SizedBox(height: 6),
            Text('Vos cours apparaîtront ici dès que l\'établissement les aura publiés.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF7A5C44))),
          ]),
        ),
      );
}

// ── Page détail d'un cours ────────────────────────────────────────────────────
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
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  static Color _c(String? hex) {
    if (hex == null) return _terra;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return _terra; }
  }

  @override
  Widget build(BuildContext context) {
    final c     = widget.course;
    final color = _c(c.color);
    const tabs  = ['Infos', 'Programme', 'Ressources'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        // ── Hero ────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: .75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              if (c.teacherName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(20)),
                  child: Text(c.teacherName!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 12),
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(c.name, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            if (c.code != null) ...[
              const SizedBox(height: 2),
              Text(c.code!, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .8))),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _HeroChip(Icons.grade_rounded, 'Coef. ${c.coefficient}'),
              if (c.hoursWeek != null) _HeroChip(Icons.access_time_rounded, '${c.hoursWeek}h/semaine'),
              if (c.chapterCount != null && c.chapterCount! > 0) _HeroChip(Icons.list_alt_rounded, '${c.chapterCount} chapitres'),
              if (c.daysOfWeek.isNotEmpty) _HeroChip(Icons.calendar_today_rounded, _fmtDays(c.daysOfWeek)),
            ]),
          ]),
        ),

        // ── Tabs ────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tab,
            tabs: tabs.map((t) => Tab(text: t)).toList(),
            labelColor: color,
            unselectedLabelColor: const Color(0xFF7A5C44),
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            indicatorColor: color,
            indicatorWeight: 3,
          ),
        ),

        // ── Content ─────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _InfoTab(course: c, color: color),
              _ProgramTab(course: c, color: color),
              _ResourcesPlaceholder(),
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

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip(this.icon, this.label);
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
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (course.description != null && course.description!.isNotEmpty) ...[
            _Section('Description'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: .15)),
              ),
              child: Text(course.description!, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A0A00), height: 1.5)),
            ),
            const SizedBox(height: 16),
          ],
          _Section('Informations'),
          const SizedBox(height: 10),
          _InfoRow(Icons.book_outlined,       'Matière',       course.name,            color),
          if (course.code != null) _InfoRow(Icons.tag_rounded, 'Code',                course.code!,           color),
          _InfoRow(Icons.grade_rounded,        'Coefficient',   '${course.coefficient}', color),
          if (course.hoursWeek != null) _InfoRow(Icons.access_time_rounded, 'Heures/semaine', '${course.hoursWeek}h', color),
          if (course.chapterCount != null) _InfoRow(Icons.list_alt_rounded, 'Chapitres', '${course.chapterCount}', color),
          if (course.teacherName != null) _InfoRow(Icons.person_outline_rounded, 'Enseignant', course.teacherName!, color),
          if (course.daysOfWeek.isNotEmpty) _InfoRow(Icons.calendar_today_rounded, 'Jours de cours', _fmtDays(course.daysOfWeek), color),
        ]),
      );

  String _fmtDays(List<String> d) {
    const map = {'lundi': 'Lundi', 'mardi': 'Mardi', 'mercredi': 'Mercredi', 'jeudi': 'Jeudi', 'vendredi': 'Vendredi', 'samedi': 'Samedi'};
    return d.map((x) => map[x] ?? x).join(', ');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEDDD0))),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A5C44)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A0A00)))),
        ]),
      );
}

// ── Tab Programme ─────────────────────────────────────────────────────────────
class _ProgramTab extends StatelessWidget {
  final SbCourse course;
  final Color color;
  const _ProgramTab({required this.course, required this.color});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: (course.programSummary != null && course.programSummary!.isNotEmpty)
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Section('Programme annuel'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: .15)),
                  ),
                  child: Text(course.programSummary!, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A0A00), height: 1.6)),
                ),
                if (course.chapterCount != null && course.chapterCount! > 0) ...[
                  const SizedBox(height: 16),
                  _Section('Chapitres prévus'),
                  const SizedBox(height: 10),
                  ...List.generate(course.chapterCount!, (i) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEDDD0))),
                    child: Row(children: [
                      Container(width: 24, height: 24, decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle), child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)))),
                      const SizedBox(width: 10),
                      Text('Chapitre ${i + 1}', style: const TextStyle(fontSize: 13, color: Color(0xFF7A5C44))),
                    ]),
                  )),
                ],
              ])
            : const Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.article_outlined, size: 48, color: Color(0xFFCCBBAA)),
                SizedBox(height: 12),
                Text('Programme non renseigné', style: TextStyle(fontSize: 14, color: Color(0xFF7A5C44))),
              ]))),
      );
}

// ── Tab Ressources (placeholder) ──────────────────────────────────────────────
class _ResourcesPlaceholder extends StatelessWidget {
  const _ResourcesPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_outlined, size: 48, color: Color(0xFFCCBBAA)),
          SizedBox(height: 12),
          Text('Ressources', style: TextStyle(fontSize: 14, color: Color(0xFF7A5C44))),
          SizedBox(height: 4),
          Text('Les documents partagés par votre enseignant s\'afficheront ici.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF9E8070))),
        ]),
      ));
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A0A00)));
}
