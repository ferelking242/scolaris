import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sources/remote/supabase_db_source.dart';
import '../../../../presentation/providers/db_providers.dart';
import '../../../../shared/widgets/page_scaffold.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;

class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});
  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  String _searchQuery = '';
  String _filterMatiere = 'Toutes';

  List<SbSubject> _filtered(List<SbSubject> all) {
    return all.where((c) {
      if (_filterMatiere != 'Toutes' && c.name != _filterMatiere) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!c.name.toLowerCase().contains(q) &&
            !(c.code?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);
    return subjectsAsync.when(
      loading: () => const PageScaffold(
        title: 'Catalogue des cours',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Catalogue des cours',
        child: Center(child: Text('Erreur : $e')),
      ),
      data: (subjects) {
        final matieres = [
          'Toutes',
          ...subjects.map((s) => s.name).toSet().toList()..sort(),
        ];
        final filtered = _filtered(subjects);
        return PageScaffold(
          title: 'Catalogue des cours',
          subtitle: '${subjects.length} cours dans l\'établissement',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchBar(onChanged: (q) => setState(() => _searchQuery = q)),
              const SizedBox(height: 14),
              _FilterRow(
                label: 'Matière',
                options: matieres,
                selected: _filterMatiere,
                onSelected: (v) => setState(() => _filterMatiere = v),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${filtered.length} cours trouvé${filtered.length > 1 ? "s" : ""}',
                  style: const TextStyle(
                      color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              filtered.isEmpty
                  ? const _EmptySearch()
                  : _CourseGrid(
                      subjects: filtered,
                      onOpen: (s) => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CourseDetailPage(subject: s)),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))
          ],
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
                hintText: 'Rechercher un cours…',
                hintStyle: TextStyle(fontSize: 13.5, color: muted),
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ]),
      );
}

// ── Filter row ─────────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) => Row(children: [
        Text('$label :',
            style: const TextStyle(
                fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _terra : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? _terra : border),
                    ),
                    child: Text(opt,
                        style: TextStyle(
                          color: sel ? Colors.white : muted,
                          fontSize: 12,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ),
                );
              },
            ),
          ),
        ),
      ]);
}

// ── Course grid ────────────────────────────────────────────────────────────────
class _CourseGrid extends StatelessWidget {
  final List<SbSubject> subjects;
  final void Function(SbSubject) onOpen;
  const _CourseGrid({required this.subjects, required this.onOpen});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth > 1100 ? 3 : c.maxWidth > 720 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subjects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 200,
          ),
          itemBuilder: (_, i) =>
              _CourseCard(subject: subjects[i], onOpen: () => onOpen(subjects[i])),
        );
      });
}

// ── Course card ────────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final SbSubject subject;
  final VoidCallback onOpen;
  const _CourseCard({required this.subject, required this.onOpen});

  static Color _parseColor(String? hex) {
    if (hex == null) return _terra;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return _terra;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _parseColor(subject.color);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: .25), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: c.withValues(alpha: .12),
                blurRadius: 14,
                offset: const Offset(0, 5),
                spreadRadius: -2),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [c, c.withValues(alpha: .7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(subject.name,
                style: const TextStyle(
                    fontSize: 14,
                    color: ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
            if (subject.code != null) ...[
              const SizedBox(height: 2),
              Text(subject.code!,
                  style: const TextStyle(fontSize: 11, color: muted)),
            ],
            const Spacer(),
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Coef. ${subject.coefficient}',
                    style: TextStyle(
                        fontSize: 11,
                        color: c,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded, size: 16, color: c),
            ]),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: muted),
              SizedBox(height: 12),
              Text('Aucun cours trouvé',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _terra)),
              SizedBox(height: 4),
              Text('Modifiez votre recherche.',
                  style: TextStyle(fontSize: 13, color: muted)),
            ],
          ),
        ),
      );
}

// ── Course detail page ─────────────────────────────────────────────────────────
class CourseDetailPage extends StatefulWidget {
  final SbSubject subject;
  const CourseDetailPage({super.key, required this.subject});
  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  static const _tabs = ['Programme', 'Objectifs', 'Ressources'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    final c = _CourseCard._parseColor(s.color);
    return Scaffold(
      backgroundColor: const Color(0xFFF5EEE6),
      body: Column(children: [
        // ── Hero ─────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [c, c.withValues(alpha: .75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          padding:
              EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
            ]),
            const SizedBox(height: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(s.name,
                style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w900)),
            if (s.code != null) ...[
              const SizedBox(height: 4),
              Text(s.code!,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: .8))),
            ],
            const SizedBox(height: 12),
            Text('Coefficient : ${s.coefficient}',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: .9))),
          ]),
        ),

        // ── Tabs ─────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
            labelColor: c,
            unselectedLabelColor: muted,
            labelStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700),
            indicatorColor: c,
            indicatorWeight: 3,
          ),
        ),

        // ── Content ───────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _InfoTab(subject: s),
              _ObjectivesTab(),
              _ResourcesTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final SbSubject subject;
  const _InfoTab({required this.subject});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle('Informations'),
          const SizedBox(height: 10),
          _InfoRow('Code', subject.code ?? '—'),
          _InfoRow('Coefficient', '${subject.coefficient}'),
          _InfoRow('Matière', subject.name),
        ]),
      );
}

class _ObjectivesTab extends StatelessWidget {
  const _ObjectivesTab();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Objectifs définis par l\'enseignant.',
              style: TextStyle(color: muted)),
        ),
      );
}

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Ressources partagées par l\'enseignant.',
              style: TextStyle(color: muted)),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 15, color: ink, fontWeight: FontWeight.w800));
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: muted))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: ink, fontWeight: FontWeight.w600))),
        ]),
      );
}
