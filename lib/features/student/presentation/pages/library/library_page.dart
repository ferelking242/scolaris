import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';
import '../../../../../shared/widgets/surface.dart';
import 'books_page.dart';
import 'course_materials_page.dart';
import 'exam_subjects_page.dart';
import 'library_favorites_page.dart';
import 'library_stats_page.dart';
import 'pdf_reader_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _orange = ScolarisPalette.orange;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;
const _cyan   = Color(0xFF0891B2);
const _purple = Color(0xFF7C3AED);

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _loading = true;
  String _searchQuery = '';
  int _filterIdx = 0; // 0=Tout, 1=Livres, 2=Examens, 3=Supports, 4=Favoris
  static const _filterLabels = ['Tout', 'Livres', 'Examens', 'Supports', 'Favoris'];
  static const _userClasse = '5e A';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000),
        () { if (mounted) setState(() => _loading = false); });
  }

  void _go(Widget page) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: _bg,
      child: Column(children: [
        // ── Header premium ─────────────────────────────────────────
        _LibraryHeader(loading: _loading),

        // ── Barre de recherche + filtres ───────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            _SearchBar(
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
            const SizedBox(height: 10),
            _FilterChips(
              selected: _filterIdx,
              onSelect: (i) => setState(() => _filterIdx = i),
            ),
          ]),
        ),

        // ── Corps scrollable ───────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
            child: _searchQuery.isNotEmpty
                ? _SearchResults(query: _searchQuery, onGo: _go)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Continuer la lecture
                    if (MockLibraryData.readingHistory.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.play_circle_rounded,
                        title: 'Continuer la lecture',
                        gradient: [_terra, _orange],
                      ),
                      const SizedBox(height: 10),
                      Skeletonizer(
                        enabled: _loading,
                        effect: const ShimmerEffect(
                            baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
                        child: _ContinueReadingCarousel(history: MockLibraryData.readingHistory, onGo: _go),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Catégories
                    _SectionHeader(
                      icon: Icons.apps_rounded,
                      title: 'Catégories',
                      gradient: [_gold, _orange],
                    ),
                    const SizedBox(height: 10),
                    _CategoriesGrid(onGo: _go),
                    const SizedBox(height: 20),

                    // Adaptés à ta classe
                    _SectionHeader(
                      icon: Icons.school_rounded,
                      title: 'Recommandés pour ta classe',
                      gradient: [_green, _cyan],
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _green.withOpacity(0.30)),
                        ),
                        child: Text(_userClasse,
                            style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Skeletonizer(
                      enabled: _loading,
                      effect: const ShimmerEffect(
                          baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
                      child: _RecommendedBooks(
                        books: MockLibraryData.recommendedForClasse(_userClasse).take(5).toList(),
                        onBook: (b) => _go(PdfReaderPage(
                            title: b.title, color: b.coverColor, totalPages: b.pages)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _go(const BooksPage()),
                        icon: const Icon(Icons.grid_view_rounded, size: 14, color: _terra),
                        label: const Text('Voir toutes les ressources',
                            style: TextStyle(color: _terra, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Examens recommandés
                    _SectionHeader(
                      icon: Icons.quiz_rounded,
                      title: 'Examens pour ta classe',
                      gradient: [_green, const Color(0xFF1B5E20)],
                    ),
                    const SizedBox(height: 10),
                    Skeletonizer(
                      enabled: _loading,
                      effect: const ShimmerEffect(
                          baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
                      child: _MiniExamList(
                        exams: MockLibraryData.recommendedExamsForClasse(_userClasse).take(4).toList(),
                        onExam: (e) => _go(PdfReaderPage(
                            title: e.title, color: e.color, totalPages: 12)),
                        onSeeAll: () => _go(const ExamSubjectsPage()),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Populaires
                    _SectionHeader(
                      icon: Icons.trending_up_rounded,
                      title: 'Livres populaires',
                      gradient: [_purple, const Color(0xFF5B21B6)],
                      action: 'Voir tout',
                      onAction: () => _go(const BooksPage()),
                    ),
                    const SizedBox(height: 10),
                    Skeletonizer(
                      enabled: _loading,
                      effect: const ShimmerEffect(
                          baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
                      child: _PopularBooksRow(
                        books: MockLibraryData.popularBooks.take(4).toList(),
                        onBook: (b) => _go(PdfReaderPage(
                            title: b.title, color: b.coverColor, totalPages: b.pages)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Supports récents
                    _SectionHeader(
                      icon: Icons.schedule_rounded,
                      title: 'Supports récemment ajoutés',
                      gradient: [_cyan, const Color(0xFF006064)],
                      action: 'Voir tout',
                      onAction: () => _go(const CourseMaterialsPage()),
                    ),
                    const SizedBox(height: 10),
                    Skeletonizer(
                      enabled: _loading,
                      effect: const ShimmerEffect(
                          baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
                      child: _RecentMaterialsList(
                        materials: MockLibraryData.materials.take(4).toList(),
                        onMaterial: (m) => _go(PdfReaderPage(
                            title: m.title, color: m.color, totalPages: 24)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Badges lecteur
                    _SectionHeader(
                      icon: Icons.emoji_events_rounded,
                      title: 'Mes badges de lecture',
                      gradient: [_gold, _orange],
                    ),
                    const SizedBox(height: 10),
                    const _ReadingBadges(),
                  ]),
          ),
        ),
      ]),
    );
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth > 700) {
        return Row(children: [
          Expanded(child: content),
          _LibraryRightSidebar(onGo: _go),
        ]);
      }
      return content;
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Right sidebar — PC only (navigation rapide bibliothèque)
// ══════════════════════════════════════════════════════════════════════════
class _LibraryRightSidebar extends StatefulWidget {
  final Function(Widget) onGo;
  const _LibraryRightSidebar({required this.onGo});
  @override
  State<_LibraryRightSidebar> createState() => _LibraryRightSidebarState();
}

class _LibraryRightSidebarState extends State<_LibraryRightSidebar> {
  int _sel = -1;

  static const _items = [
    (icon: Icons.book_rounded,          label: 'Livres',          sub: 'Romans & manuels'),
    (icon: Icons.quiz_rounded,           label: 'Examens',         sub: 'Sujets & corrigés'),
    (icon: Icons.description_rounded,    label: 'Supports',        sub: 'Fiches de cours'),
    (icon: Icons.favorite_rounded,       label: 'Favoris',         sub: 'Mes sauvegardes'),
    (icon: Icons.download_done_rounded,  label: 'Téléch.',         sub: 'Offline'),
    (icon: Icons.bar_chart_rounded,      label: 'Stats',           sub: 'Mon profil'),
  ];

  void _tap(int i) {
    setState(() => _sel = i);
    final pages = [
      const BooksPage(),
      const ExamSubjectsPage(),
      const CourseMaterialsPage(),
      const LibraryFavoritesPage(),
      const LibraryFavoritesPage(),
      const LibraryStatsPage(),
    ];
    widget.onGo(pages[i]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      decoration: const BoxDecoration(
        color: Color(0xFF1A0500),
        border: Border(left: BorderSide(color: Color(0xFF3E1A00), width: 1)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Row(children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_terra, _orange]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.local_library_rounded, color: _white, size: 11),
            ),
            const SizedBox(width: 7),
            const Expanded(child: Text('Navigation',
                style: TextStyle(color: Color(0xFFE8DDD0), fontSize: 10.5,
                    fontWeight: FontWeight.w800, letterSpacing: 0.2),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        Container(height: 1, color: const Color(0xFF3E1A00)),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              final active = _sel == i;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? _terra.withOpacity(0.90) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: active ? _terra : Colors.transparent,
                      ),
                    ),
                    child: Row(children: [
                      Icon(item.icon, size: 15,
                          color: active ? _white : const Color(0xFFB89880)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.label, style: TextStyle(
                            color: active ? _white : const Color(0xFFE8DDD0),
                            fontSize: 11, fontWeight: active
                                ? FontWeight.w700 : FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(item.sub, style: const TextStyle(
                            color: Color(0xFF7A5040), fontSize: 9.5),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        Container(height: 1, color: const Color(0xFF3E1A00)),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withOpacity(0.30)),
            ),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded, size: 14, color: _gold),
              const SizedBox(width: 7),
              const Expanded(child: Text('2/6 badges', style: TextStyle(
                  color: _gold, fontSize: 10, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Header premium
// ══════════════════════════════════════════════════════════════════════════
class _LibraryHeader extends StatelessWidget {
  final bool loading;
  const _LibraryHeader({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0500), Color(0xFF4A1500), _terra],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bibliothèque', style: TextStyle(
                  color: _white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
              const SizedBox(height: 4),
              Text('Toutes tes ressources pédagogiques',
                  style: TextStyle(color: _white.withOpacity(0.65), fontSize: 12)),
              const SizedBox(height: 12),
              // Stats
              Skeletonizer(
                enabled: loading,
                effect: const ShimmerEffect(baseColor: Color(0x44FFFFFF), highlightColor: Color(0x66FFFFFF)),
                child: Row(children: [
                  _HeaderStat(label: 'Ressources', val: '${MockLibraryData.totalResources}',
                      icon: Icons.folder_rounded),
                  const SizedBox(width: 16),
                  _HeaderStat(label: 'Livres', val: '${MockLibraryData.totalBooks}',
                      icon: Icons.book_rounded),
                  const SizedBox(width: 16),
                  _HeaderStat(label: 'Examens', val: '${MockLibraryData.totalExams}',
                      icon: Icons.quiz_rounded),
                ]),
              ),
            ])),
            const SizedBox(width: 12),
            // Illustration décorative
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _white.withOpacity(0.25)),
              ),
              child: const Center(child: Text('📚', style: TextStyle(fontSize: 36))),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label, val;
  final IconData icon;
  const _HeaderStat({required this.label, required this.val, required this.icon});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(icon, size: 11, color: _gold),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: _white.withOpacity(0.60), fontSize: 9, fontWeight: FontWeight.w600)),
    ]),
    const SizedBox(height: 2),
    Text(val, style: const TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.w900)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════
// Search bar
// ══════════════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, decoration: BoxDecoration(
        color: _white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 18, color: _muted),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5, color: _ink),
          decoration: const InputDecoration(
            hintText: 'Rechercher livres, examens, supports…',
            hintStyle: TextStyle(fontSize: 13.5, color: _muted),
            isCollapsed: true, border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        )),
        const Icon(Icons.mic_rounded, size: 16, color: _muted),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Filter chips
// ══════════════════════════════════════════════════════════════════════════
class _FilterChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _FilterChips({required this.selected, required this.onSelect});

  static const _icons = [Icons.apps_rounded, Icons.book_rounded,
    Icons.quiz_rounded, Icons.description_rounded, Icons.favorite_rounded];

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _LibraryPageState._filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? _terra : _white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? _terra : _border),
                boxShadow: sel ? [BoxShadow(color: _terra.withOpacity(0.30),
                    blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_icons[i], size: 12, color: sel ? _white : _muted),
                const SizedBox(width: 5),
                Text(_LibraryPageState._filterLabels[i], style: TextStyle(
                    color: sel ? _white : _muted,
                    fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Section header
// ══════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Color> gradient;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  const _SectionHeader({
    required this.icon, required this.title, required this.gradient,
    this.action, this.onAction, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.35),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: _white, size: 15),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: const TextStyle(
          fontSize: 14.5, color: _ink, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (trailing != null) trailing!,
      if (action != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _terra.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Text(action!, style: const TextStyle(
                color: _terra, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Continue reading carousel
// ══════════════════════════════════════════════════════════════════════════
class _ContinueReadingCarousel extends StatelessWidget {
  final List<ReadingEntry> history;
  final Function(Widget) onGo;
  const _ContinueReadingCarousel({required this.history, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final h = history[i];
          return GestureDetector(
            onTap: () => onGo(PdfReaderPage(
                title: h.title, color: h.color, totalPages: 200,
                initialPage: (h.progress * 200).round())),
            child: Container(
              width: 230,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: h.color.withOpacity(0.25)),
                boxShadow: [BoxShadow(color: h.color.withOpacity(0.12),
                    blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [h.color, h.color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(h.icon, color: _white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_typeLabel(h.type), style: TextStyle(
                      color: h.color, fontSize: 9.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(h.title, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: h.progress, minHeight: 5,
                        backgroundColor: h.color.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation(h.color),
                      ),
                    )),
                    const SizedBox(width: 6),
                    Text('${(h.progress * 100).toInt()}%',
                        style: TextStyle(color: h.color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ]),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }

  String _typeLabel(ResourceType t) {
    switch (t) {
      case ResourceType.book: return 'Livre';
      case ResourceType.material: return 'Support';
      case ResourceType.examSubject: return 'Examen';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Catégories grid
// ══════════════════════════════════════════════════════════════════════════
class _CategoriesGrid extends StatelessWidget {
  final Function(Widget) onGo;
  const _CategoriesGrid({required this.onGo});

  @override
  Widget build(BuildContext context) {
    final cats = [
      (icon: Icons.book_rounded,        label: 'Livres',        sub: '${MockLibraryData.totalBooks}',        grad: [const Color(0xFF1565C0), const Color(0xFF0288D1)], page: const BooksPage()),
      (icon: Icons.quiz_rounded,         label: 'Examens',       sub: '${MockLibraryData.totalExams}',        grad: [const Color(0xFF1B5E20), const Color(0xFF388E3C)], page: const ExamSubjectsPage()),
      (icon: Icons.description_rounded,  label: 'Supports',      sub: '${MockLibraryData.totalMaterials}',    grad: [_terra, _orange],                                  page: const CourseMaterialsPage()),
      (icon: Icons.favorite_rounded,     label: 'Favoris',       sub: '${MockLibraryData.favoriteBooks.length + MockLibraryData.favoriteExams.length}', grad: [const Color(0xFFE91E63), const Color(0xFFC2185B)], page: const LibraryFavoritesPage()),
      (icon: Icons.download_done_rounded,label: 'Téléchargements',sub: '${MockLibraryData.downloadedBooks.length + MockLibraryData.downloadedMaterials.length}', grad: [_cyan, const Color(0xFF006064)], page: const LibraryFavoritesPage()),
      (icon: Icons.bar_chart_rounded,    label: 'Statistiques',  sub: 'Mon profil',  grad: [_purple, const Color(0xFF5B21B6)],            page: const LibraryStatsPage()),
    ];

    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 500 ? 6 : 3;
      final ratio = constraints.maxWidth > 500 ? 1.5 : 1.0;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: ratio,
        children: cats.map((c) => GestureDetector(
        onTap: () => onGo(c.page),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: c.grad,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: c.grad.first.withOpacity(0.35),
                blurRadius: 12, offset: const Offset(0, 5))],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(color: _white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(c.icon, color: _white, size: 18)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.label, style: const TextStyle(color: _white,
                  fontSize: 11, fontWeight: FontWeight.w800),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(c.sub, style: TextStyle(color: _white.withOpacity(0.70),
                  fontSize: 9.5, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      )).toList(),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Recommended books horizontal scroll
// ══════════════════════════════════════════════════════════════════════════
class _RecommendedBooks extends StatelessWidget {
  final List<LibraryBook> books;
  final Function(LibraryBook) onBook;
  const _RecommendedBooks({required this.books, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _BookCover(book: books[i], onTap: () => onBook(books[i])),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  final LibraryBook book;
  final VoidCallback onTap;
  const _BookCover({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Couverture
          Container(
            height: 140, width: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [book.coverColor, book.coverColorEnd],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: book.coverColor.withOpacity(0.35),
                  blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Stack(children: [
              // Reliure
              Positioned(left: 0, top: 0, bottom: 0,
                child: Container(width: 6,
                  decoration: BoxDecoration(
                    color: _white.withOpacity(0.20),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(book.subject, style: TextStyle(
                      color: _white.withOpacity(0.75), fontSize: 9, fontWeight: FontWeight.w700)),
                  Text(book.title, style: const TextStyle(
                      color: _white, fontSize: 11.5, fontWeight: FontWeight.w900, height: 1.3),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  Text(book.classe, style: TextStyle(
                      color: _white.withOpacity(0.65), fontSize: 9)),
                ]),
              ),
              // Rating badge
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: _white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 8, color: _gold),
                    const SizedBox(width: 2),
                    Text(book.rating.toStringAsFixed(1), style: const TextStyle(
                        color: _white, fontSize: 8, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(book.title, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(book.author, style: const TextStyle(color: _muted, fontSize: 9.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Mini exam list
// ══════════════════════════════════════════════════════════════════════════
class _MiniExamList extends StatelessWidget {
  final List<ExamSubject> exams;
  final Function(ExamSubject) onExam;
  final VoidCallback onSeeAll;
  const _MiniExamList({required this.exams, required this.onExam, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final e in exams) ...[
        GestureDetector(
          onTap: () => onExam(e),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: e.color.withOpacity(0.20))),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: e.color.withOpacity(0.10), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: e.color.withOpacity(0.25)),
                ),
                child: Center(child: Text(e.levelLabel[0],
                    style: TextStyle(color: e.color, fontSize: 14, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e.subject} · ${e.year}', style: const TextStyle(
                    color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text('${e.levelLabel} · ${e.session}',
                    style: const TextStyle(color: _muted, fontSize: 11)),
              ])),
              if (e.hasCorrection)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: _green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _green.withOpacity(0.30))),
                  child: const Text('+ Corrigé', style: TextStyle(
                      color: _green, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _muted),
            ]),
          ),
        ),
      ],
      TextButton(
        onPressed: onSeeAll,
        child: const Text('Voir tous les examens',
            style: TextStyle(color: _terra, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Popular books row
// ══════════════════════════════════════════════════════════════════════════
class _PopularBooksRow extends StatelessWidget {
  final List<LibraryBook> books;
  final Function(LibraryBook) onBook;
  const _PopularBooksRow({required this.books, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (int i = 0; i < books.length; i++) ...[
        GestureDetector(
          onTap: () => onBook(books[i]),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: ScolarisSurface.card(radius: 12),
            child: Row(children: [
              // Mini cover
              Container(width: 44, height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [books[i].coverColor, books[i].coverColorEnd]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.all(4),
                    child: Text(books[i].classe, style: TextStyle(
                        color: _white.withOpacity(0.80), fontSize: 7, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(books[i].title, style: const TextStyle(
                    color: _ink, fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(books[i].author, style: const TextStyle(color: _muted, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  ...List.generate(5, (s) => Icon(
                      s < books[i].rating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 11, color: _gold)),
                  const SizedBox(width: 4),
                  Text('(${books[i].reviewCount})', style: const TextStyle(color: _muted, fontSize: 9.5)),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: books[i].coverColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.download_rounded, size: 10, color: books[i].coverColor),
                    const SizedBox(width: 3),
                    Text('${(books[i].downloads / 1000).toStringAsFixed(1)}k',
                        style: TextStyle(color: books[i].coverColor, fontSize: 9, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Recent materials list
// ══════════════════════════════════════════════════════════════════════════
class _RecentMaterialsList extends StatelessWidget {
  final List<CourseMaterial> materials;
  final Function(CourseMaterial) onMaterial;
  const _RecentMaterialsList({required this.materials, required this.onMaterial});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: materials.map((m) => GestureDetector(
        onTap: () => onMaterial(m),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: ScolarisSurface.card(radius: 12),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(m.icon, color: _white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${m.subject} · ${m.teacher}', style: const TextStyle(color: _muted, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(m.size, style: TextStyle(color: m.color, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(m.addedDate, style: const TextStyle(color: _muted, fontSize: 9.5)),
            ]),
          ]),
        ),
      )).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Badges de lecture
// ══════════════════════════════════════════════════════════════════════════
class _ReadingBadges extends StatelessWidget {
  const _ReadingBadges();

  static const _badges = [
    (emoji: '📖', label: 'Premier livre', desc: 'Débloqué', unlocked: true,  color: Color(0xFF6D28D9)),
    (emoji: '🎯', label: 'Lecteur régulier', desc: '7 jours consécutifs', unlocked: true, color: Color(0xFF1B5E20)),
    (emoji: '⚡', label: 'Speed reader', desc: '3 docs en 1h', unlocked: false, color: Color(0xFFC17F24)),
    (emoji: '🏆', label: 'Champion BAC', desc: '10 examens', unlocked: false, color: Color(0xFF8B1A00)),
    (emoji: '💡', label: 'Curieux',         desc: '5 matières', unlocked: false, color: Color(0xFF0891B2)),
    (emoji: '🌟', label: 'Super lecteur',   desc: 'Top 10%',   unlocked: false, color: Color(0xFFDB2777)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ScolarisSurface.card(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Mes badges', style: TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w800))),
          Text('2/6 débloqués', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: _badges.map((b) => Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: b.unlocked ? b.color.withOpacity(0.08) : const Color(0xFFF5EEE6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: b.unlocked ? b.color.withOpacity(0.30) : _border),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(b.emoji, style: TextStyle(fontSize: 22,
                  color: b.unlocked ? null : const Color(0xFFBBBBBB))),
              const SizedBox(height: 4),
              Text(b.label, style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: b.unlocked ? b.color : _muted),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          )).toList(),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Search results
// ══════════════════════════════════════════════════════════════════════════
class _SearchResults extends StatelessWidget {
  final String query;
  final Function(Widget) onGo;
  const _SearchResults({required this.query, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final books = MockLibraryData.books.where((b) =>
      b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q) ||
      b.subject.toLowerCase().contains(q)).toList();
    final exams = MockLibraryData.examSubjects.where((e) =>
      e.title.toLowerCase().contains(q) || e.subject.toLowerCase().contains(q) ||
      e.levelLabel.toLowerCase().contains(q)).toList();
    final mats = MockLibraryData.materials.where((m) =>
      m.title.toLowerCase().contains(q) || m.subject.toLowerCase().contains(q) ||
      m.teacher.toLowerCase().contains(q)).toList();
    final total = books.length + exams.length + mats.length;
    if (total == 0) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 48),
        Container(width: 56, height: 56,
          decoration: BoxDecoration(color: const Color(0xFFF0E8DC), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.search_off_rounded, color: _muted, size: 26)),
        const SizedBox(height: 14),
        const Text('Aucun résultat', style: TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Aucune ressource ne correspond à "$query"',
            style: const TextStyle(fontSize: 12, color: _muted), textAlign: TextAlign.center),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$total résultat${total > 1 ? 's' : ''} pour "$query"',
          style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      if (books.isNotEmpty) ...[
        const Text('Livres', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final b in books) GestureDetector(
          onTap: () => onGo(PdfReaderPage(title: b.title, color: b.coverColor, totalPages: b.pages)),
          child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: ScolarisSurface.card(radius: 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [b.coverColor, b.coverColorEnd]),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.book_rounded, color: _white, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${b.author} · ${b.classe}', style: const TextStyle(color: _muted, fontSize: 11)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _muted),
            ])),
        ),
        const SizedBox(height: 8),
      ],
      if (exams.isNotEmpty) ...[
        const Text('Examens', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final e in exams) GestureDetector(
          onTap: () => onGo(PdfReaderPage(title: e.title, color: e.color, totalPages: 12)),
          child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: ScolarisSurface.card(radius: 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: e.color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10), border: Border.all(color: e.color.withOpacity(0.30))),
                child: Center(child: Text(e.levelLabel[0],
                    style: TextStyle(color: e.color, fontSize: 14, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${e.subject} · ${e.year}', style: const TextStyle(color: _muted, fontSize: 11)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _muted),
            ])),
        ),
      ],
      if (mats.isNotEmpty) ...[
        const Text('Supports', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final m in mats) GestureDetector(
          onTap: () => onGo(PdfReaderPage(title: m.title, color: m.color, totalPages: 24)),
          child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: ScolarisSurface.card(radius: 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(m.icon, color: _white, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${m.subject} · ${m.teacher}', style: const TextStyle(color: _muted, fontSize: 11)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _muted),
            ])),
        ),
      ],
    ]);
  }
}
