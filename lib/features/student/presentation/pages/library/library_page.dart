import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';
import 'library_advanced_search_page.dart';
import 'library_stats_page.dart';
import 'pdf_reader_page.dart';

// ── Palette propre (un seul accent, pas de couleurs idiotes) ───────────────
const _accent  = Color(0xFFCC4A1A);
const _success = Color(0xFF2D7A4F);

// ── Search result model ─────────────────────────────────────────────────────
class _QuickResult {
  final String type, title, sub;
  final Color color;
  final IconData icon;
  const _QuickResult({
    required this.type,
    required this.title,
    required this.sub,
    required this.color,
    required this.icon,
  });
}

// ══════════════════════════════════════════════════════════════════════════
// LibraryPage — hub principal (sans sidebar droite, navigation interne)
// ══════════════════════════════════════════════════════════════════════════
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final _searchFocus = FocusNode();

  // Filtres par onglet
  String _bookSubject = 'Toutes';
  String _bookClasse  = 'Toutes';
  String _examLevel   = 'Tous';
  String _matSubject  = 'Toutes';

  static const _tabLabels = ['Accueil', 'Livres', 'Examens', 'Supports', 'Favoris'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabLabels.length, vsync: this);
    MockLibraryData.load().then((_) {
        if (mounted) setState(() => _loading = false);
      });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _go(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _switchTab(int i) => _tab.animateTo(i);

  List<_QuickResult> get _quickResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    final out = <_QuickResult>[];
    for (final b in MockLibraryData.books) {
      if (b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.subject.toLowerCase().contains(q)) {
        out.add(_QuickResult(
            type: 'Livre', title: b.title,
            sub: '${b.author} · ${b.subject}',
            color: b.coverColor, icon: Icons.book_rounded));
      }
    }
    for (final e in MockLibraryData.examSubjects) {
      if (e.title.toLowerCase().contains(q) ||
          e.subject.toLowerCase().contains(q)) {
        out.add(_QuickResult(
            type: 'Examen', title: e.title,
            sub: '${e.levelLabel} · ${e.year}',
            color: e.color, icon: Icons.quiz_rounded));
      }
    }
    for (final m in MockLibraryData.materials) {
      if (m.title.toLowerCase().contains(q) ||
          m.subject.toLowerCase().contains(q)) {
        out.add(_QuickResult(
            type: 'Support', title: m.title,
            sub: '${m.subject} · ${m.teacher}',
            color: m.color, icon: m.icon));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _searchFocus.unfocus(),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(children: [

          // ── Header compact ─────────────────────────────────────────
          _LibraryHeader(loading: _loading),

          // ── Barre de recherche ─────────────────────────────────────
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              _SearchBarWidget(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: (q) => setState(() => _searchQuery = q),
                onClear: () => setState(() {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }),
                onFilterTap: () =>
                    _go(LibraryAdvancedSearchPage(initialQuery: _searchQuery)),
              ),
              // Dropdown résultats inline
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: _searchQuery.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _SearchDropdown(
                          results: _quickResults,
                          onSeeAll: () => _go(
                              LibraryAdvancedSearchPage(initialQuery: _searchQuery)),
                          onTapResult: (r) => _go(PdfReaderPage(
                              title: r.title, color: r.color, totalPages: 100)),
                        ),
                      )
                    : const SizedBox(height: 10),
              ),
            ]),
          ),

          // ── Onglets internes ───────────────────────────────────────
          Container(
            color: cs.surface,
            child: Column(children: [
              TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _accent,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                indicatorColor: _accent,
                indicatorWeight: 2.5,
                dividerColor: cs.outlineVariant,
                tabs: _tabLabels
                    .map((t) => Tab(text: t, height: 40))
                    .toList(),
              ),
            ]),
          ),

          // ── Contenu des onglets ────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _HomeTab(
                    loading: _loading,
                    onGo: _go,
                    onSwitchTab: _switchTab),
                _BooksTab(
                  loading: _loading,
                  subject: _bookSubject,
                  classe: _bookClasse,
                  onSubjectChanged: (s) => setState(() => _bookSubject = s),
                  onClasseChanged: (c) => setState(() => _bookClasse = c),
                  onGo: _go,
                ),
                _ExamsTab(
                  loading: _loading,
                  level: _examLevel,
                  onLevelChanged: (l) => setState(() => _examLevel = l),
                  onGo: _go,
                ),
                _MaterialsTab(
                  loading: _loading,
                  subject: _matSubject,
                  onSubjectChanged: (s) => setState(() => _matSubject = s),
                  onGo: _go,
                ),
                _FavoritesTab(loading: _loading, onGo: _go),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Header compact
// ══════════════════════════════════════════════════════════════════════════
class _LibraryHeader extends StatelessWidget {
  final bool loading;
  const _LibraryHeader({required this.loading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: SafeArea(
        bottom: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bibliothèque', style: TextStyle(
                  color: cs.onSurface, fontSize: 22,
                  fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              SizedBox(height: 2),
              Text('Toutes tes ressources pédagogiques',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ]),
          ),
          Skeletonizer(
            enabled: loading,
            effect: const ShimmerEffect(
                baseColor: Color(0xFFEAE3DB),
                highlightColor: Color(0xFFF5F0EA)),
            child: Row(children: [
              _MiniStat(n: MockLibraryData.totalBooks,     label: 'Livres'),
              _statDiv(cs),
              _MiniStat(n: MockLibraryData.totalExams,     label: 'Examens'),
              _statDiv(cs),
              _MiniStat(n: MockLibraryData.totalMaterials, label: 'Supports'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _statDiv(ColorScheme cs) => Container(
      height: 26, width: 1,
      color: cs.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: 10));
}

class _MiniStat extends StatelessWidget {
  final int n;
  final String label;
  const _MiniStat({required this.n, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Text('$n', style: TextStyle(
          color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w900)),
      SizedBox(height: 1),
      Text(label, style: TextStyle(
          color: cs.onSurfaceVariant, fontSize: 9.5, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Barre de recherche + bouton filtre
// ══════════════════════════════════════════════════════════════════════════
class _SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;
  const _SearchBarWidget({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EBE5),
            borderRadius: BorderRadius.circular(11),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: TextStyle(fontSize: 13.5, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Livres, examens, supports…',
                hintStyle: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
            )),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.close_rounded, size: 16, color: cs.onSurfaceVariant),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      // Bouton filtre → Recherche avancée
      GestureDetector(
        onTap: onFilterTap,
        child: Container(
          height: 44, width: 44,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Dropdown résultats de recherche (inline, sans quitter la page)
// ══════════════════════════════════════════════════════════════════════════
class _SearchDropdown extends StatelessWidget {
  final List<_QuickResult> results;
  final VoidCallback onSeeAll;
  final Function(_QuickResult) onTapResult;
  const _SearchDropdown({
    required this.results,
    required this.onSeeAll,
    required this.onTapResult,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = results.take(7).toList();
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (shown.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text('Aucun résultat.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          )
        else
          ...shown.map((r) => _QuickResultTile(
              result: r, onTap: () => onTapResult(r))),

        Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        // Bouton "Voir tout"
        InkWell(
          onTap: onSeeAll,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(children: [
              Text(
                results.isNotEmpty
                    ? 'Voir tous les résultats (${results.length})'
                    : 'Recherche avancée',
                style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded,
                  size: 15, color: _accent),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _QuickResultTile extends StatelessWidget {
  final _QuickResult result;
  final VoidCallback onTap;
  const _QuickResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: result.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(result.icon, size: 16, color: result.color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(result.title,
                style: TextStyle(
                    color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 1),
            Text(result.sub,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: result.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(result.type,
                style: TextStyle(
                    color: result.color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Widgets partagés
// ══════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _SectionLabel(this.text, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(child: Text(text, style: TextStyle(
          color: cs.onSurface, fontSize: 14,
          fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: TextStyle(
              color: _accent, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = value != options.first;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => _OptionsSheet(
            title: label, options: options,
            value: value, onChanged: onChanged),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? _accent.withOpacity(0.08)
              : const Color(0xFFF0EBE5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? _accent.withOpacity(0.35)
                  : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  color: active ? _accent : cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500)),
          SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              size: 14, color: active ? _accent : cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _OptionsSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _OptionsSheet({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(title, style: TextStyle(
              color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        ...options.map((o) => InkWell(
          onTap: () { onChanged(o); Navigator.pop(context); },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 13),
            child: Row(children: [
              Expanded(child: Text(o,
                  style: TextStyle(
                      color: o == value ? _accent : cs.onSurface,
                      fontSize: 14,
                      fontWeight: o == value
                          ? FontWeight.w700
                          : FontWeight.w400))),
              if (o == value)
                const Icon(Icons.check_rounded, size: 16, color: _accent),
            ]),
          ),
        )),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Couverture livre ──────────────────────────────────────────────────────
class _BookCover extends StatelessWidget {
  final LibraryBook book;
  final VoidCallback onTap;
  const _BookCover({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 140, width: 112,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [book.coverColor, book.coverColorEnd],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: book.coverColor.withOpacity(0.25),
                  blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Stack(children: [
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text(book.subject,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 8.5, fontWeight: FontWeight.w700)),
                  Text(book.title,
                      style: TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w900, height: 1.3),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        size: 9, color: Color(0xFFFFD966)),
                    const SizedBox(width: 2),
                    Text(book.rating.toStringAsFixed(1),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 8.5, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
            ]),
          ),
          SizedBox(height: 6),
          Text(book.title,
              style: TextStyle(
                  color: cs.onSurface, fontSize: 11, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(book.author,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Ligne livre ───────────────────────────────────────────────────────────
class _BookListTile extends StatelessWidget {
  final LibraryBook book;
  final VoidCallback onTap;
  const _BookListTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(children: [
          // Mini couverture
          Container(
            width: 46, height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [book.coverColor, book.coverColorEnd]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(children: [
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title,
                style: TextStyle(
                    color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2),
            Text(book.author,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
            const SizedBox(height: 5),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: book.coverColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(book.subject,
                    style: TextStyle(
                        color: book.coverColor,
                        fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBE5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(book.classe,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 9.5)),
              ),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              const Icon(Icons.star_rounded,
                  size: 11, color: Color(0xFFC17F24)),
              SizedBox(width: 2),
              Text(book.rating.toStringAsFixed(1),
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            SizedBox(height: 4),
            Text('${book.pages}p',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
            if (book.isFavorite) ...[
              const SizedBox(height: 4),
              const Icon(Icons.favorite_rounded,
                  size: 12, color: Color(0xFFB72653)),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ── Ligne examen ──────────────────────────────────────────────────────────
class _ExamTile extends StatelessWidget {
  final ExamSubject exam;
  final VoidCallback onTap;
  const _ExamTile({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: exam.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(exam.levelLabel[0],
                style: TextStyle(
                    color: exam.color,
                    fontSize: 15, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${exam.subject} · ${exam.year}',
                style: TextStyle(
                    color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('${exam.levelLabel} · ${exam.session}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          ])),
          if (exam.hasCorrection)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: _success.withOpacity(0.25)),
              ),
              child: const Text('Corrigé',
                  style: TextStyle(
                      color: _success,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 11, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── Ligne support ─────────────────────────────────────────────────────────
class _MaterialTile extends StatelessWidget {
  final CourseMaterial material;
  final VoidCallback onTap;
  const _MaterialTile({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: material.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(material.icon, size: 20, color: material.color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(material.title,
                style: TextStyle(
                    color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2),
            Text('${material.subject} · ${material.teacher}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(material.size,
                style: TextStyle(
                    color: material.color,
                    fontSize: 11, fontWeight: FontWeight.w700)),
            SizedBox(height: 3),
            Text(material.addedDate,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
            if (material.isDownloaded) ...[
              const SizedBox(height: 3),
              const Icon(Icons.download_done_rounded,
                  size: 12, color: _success),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET 0 — Accueil
// ══════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  final bool loading;
  final Function(Widget) onGo;
  final Function(int) onSwitchTab;
  const _HomeTab({
    required this.loading,
    required this.onGo,
    required this.onSwitchTab,
  });

  static const _userClasse = '5e A';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── En cours de lecture ──────────────────────────────────────
        if (MockLibraryData.readingHistory.isNotEmpty) ...[
          const _SectionLabel('Reprendre la lecture'),
          const SizedBox(height: 10),
          Skeletonizer(
            enabled: loading,
            effect: const ShimmerEffect(
                baseColor: Color(0xFFEAE3DB),
                highlightColor: Color(0xFFF5F0EA)),
            child: SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: MockLibraryData.readingHistory.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final h = MockLibraryData.readingHistory[i];
                  return _ContinueCard(
                    entry: h,
                    onTap: () => onGo(PdfReaderPage(
                        title: h.title, color: h.color, totalPages: 200,
                        initialPage: (h.progress * 200).round(),
                        resourceId: h.resourceId, resourceType: h.type)),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],

        // ── Catégories ───────────────────────────────────────────────
        const _SectionLabel('Catégories'),
        const SizedBox(height: 10),
        _CategoryGrid(onSwitchTab: onSwitchTab, onGo: onGo),
        const SizedBox(height: 22),

        // ── Recommandés pour la classe ───────────────────────────────
        _SectionLabel(
          'Pour ta classe · $_userClasse',
          action: 'Voir tout',
          onAction: () => onSwitchTab(1),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(
              baseColor: Color(0xFFEAE3DB),
              highlightColor: Color(0xFFF5F0EA)),
          child: SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MockLibraryData.recommendedForClasse(_userClasse)
                  .take(5).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final books = MockLibraryData.recommendedForClasse(_userClasse)
                    .take(5).toList();
                return _BookCover(
                    book: books[i],
                    onTap: () => onGo(PdfReaderPage(
                        title: books[i].title,
                        color: books[i].coverColor,
                        totalPages: books[i].pages,
                        resourceId: books[i].id,
                        resourceType: ResourceType.book,
                        subject: books[i].subject)));
              },
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── Examens ──────────────────────────────────────────────────
        _SectionLabel(
          'Examens recommandés',
          action: 'Voir tout',
          onAction: () => onSwitchTab(2),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(
              baseColor: Color(0xFFEAE3DB),
              highlightColor: Color(0xFFF5F0EA)),
          child: Column(children: [
            ...MockLibraryData.recommendedExamsForClasse(_userClasse)
                .take(4)
                .map((e) => _ExamTile(
                      exam: e,
                      onTap: () => onGo(PdfReaderPage(
                          title: e.title, color: e.color, totalPages: 12,
                          resourceId: e.id,
                          resourceType: ResourceType.examSubject,
                          subject: e.subject)),
                    )),
          ]),
        ),
        const SizedBox(height: 22),

        // ── Supports récents ─────────────────────────────────────────
        _SectionLabel(
          'Supports récents',
          action: 'Voir tout',
          onAction: () => onSwitchTab(3),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(
              baseColor: Color(0xFFEAE3DB),
              highlightColor: Color(0xFFF5F0EA)),
          child: Column(children: [
            ...MockLibraryData.materials.take(4).map((m) => _MaterialTile(
                  material: m,
                  onTap: () => onGo(PdfReaderPage(
                      title: m.title, color: m.color, totalPages: 24,
                      resourceId: m.id,
                      resourceType: ResourceType.material,
                      subject: m.subject)),
                )),
          ]),
        ),
      ]),
    );
  }
}

// ── Carte "continuer la lecture" ───────────────────────────────────────────
class _ContinueCard extends StatelessWidget {
  final ReadingEntry entry;
  final VoidCallback onTap;
  const _ContinueCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 218,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: entry.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(entry.icon, color: entry.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(entry.title,
                style: TextStyle(
                    color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: entry.progress,
                  minHeight: 4,
                  backgroundColor: entry.color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(entry.color),
                ),
              )),
              const SizedBox(width: 6),
              Text('${(entry.progress * 100).toInt()}%',
                  style: TextStyle(
                      color: entry.color,
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ])),
        ]),
      ),
    );
  }
}

// ── Grille catégories (propre, sans gradients inutiles) ────────────────────
class _CategoryGrid extends StatelessWidget {
  final Function(int) onSwitchTab;
  final Function(Widget) onGo;
  const _CategoryGrid({required this.onSwitchTab, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cats = [
      _CatDef(
        icon: Icons.book_rounded,
        label: 'Livres',
        count: '${MockLibraryData.totalBooks} manuels',
        color: const Color(0xFF1565C0),
        onTap: () => onSwitchTab(1),
      ),
      _CatDef(
        icon: Icons.quiz_rounded,
        label: 'Examens',
        count: '${MockLibraryData.totalExams} sujets',
        color: const Color(0xFF2D7A4F),
        onTap: () => onSwitchTab(2),
      ),
      _CatDef(
        icon: Icons.description_rounded,
        label: 'Supports',
        count: '${MockLibraryData.totalMaterials} fichiers',
        color: _accent,
        onTap: () => onSwitchTab(3),
      ),
      _CatDef(
        icon: Icons.favorite_rounded,
        label: 'Favoris',
        count: '${MockLibraryData.favoriteBooks.length + MockLibraryData.favoriteExams.length} enregistrés',
        color: const Color(0xFFB72653),
        onTap: () => onSwitchTab(4),
      ),
      _CatDef(
        icon: Icons.download_done_rounded,
        label: 'Hors ligne',
        count: '${MockLibraryData.downloadedBooks.length + MockLibraryData.downloadedMaterials.length} téléchargés',
        color: const Color(0xFF5B4F3A),
        onTap: () {},
      ),
      _CatDef(
        icon: Icons.bar_chart_rounded,
        label: 'Statistiques',
        count: 'Mon profil lecteur',
        color: const Color(0xFF6D28D9),
        onTap: () => onGo(const LibraryStatsPage()),
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 420 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: c.maxWidth > 420 ? 2.3 : 2.0,
        children: cats.map((cat) => GestureDetector(
          onTap: cat.onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(cat.icon, size: 17, color: cat.color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(cat.label,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 1),
                Text(cat.count,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
        )).toList(),
      );
    });
  }
}

class _CatDef {
  final IconData icon;
  final String label, count;
  final Color color;
  final VoidCallback onTap;
  const _CatDef({
    required this.icon, required this.label, required this.count,
    required this.color, required this.onTap,
  });
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET 1 — Livres
// ══════════════════════════════════════════════════════════════════════════
class _BooksTab extends StatelessWidget {
  final bool loading;
  final String subject, classe;
  final ValueChanged<String> onSubjectChanged, onClasseChanged;
  final Function(Widget) onGo;
  const _BooksTab({
    required this.loading, required this.subject, required this.classe,
    required this.onSubjectChanged, required this.onClasseChanged,
    required this.onGo,
  });

  List<String> get _subjects =>
      ['Toutes', ...{for (final b in MockLibraryData.books) b.subject}];
  List<String> get _classes =>
      ['Toutes', ...{for (final b in MockLibraryData.books) b.classe}];

  List<LibraryBook> get _filtered => MockLibraryData.books.where((b) {
        if (subject != 'Toutes' && b.subject != subject) return false;
        if (classe != 'Toutes' && b.classe != classe) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final books = _filtered;
    return Column(children: [
      Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          _FilterDropdown(
              label: 'Matière', options: _subjects,
              value: subject, onChanged: onSubjectChanged),
          const SizedBox(width: 8),
          _FilterDropdown(
              label: 'Classe', options: _classes,
              value: classe, onChanged: onClasseChanged),
          Spacer(),
          Text('${books.length} livre${books.length > 1 ? 's' : ''}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ]),
      ),
      Divider(height: 1, thickness: 1, color: cs.outlineVariant),
      Expanded(
        child: Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(
              baseColor: Color(0xFFEAE3DB),
              highlightColor: Color(0xFFF5F0EA)),
          child: books.isEmpty
              ? Center(child: Text('Aucun livre ne correspond.',
                  style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: books.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BookListTile(
                      book: books[i],
                      onTap: () => onGo(PdfReaderPage(
                          title: books[i].title,
                          color: books[i].coverColor,
                          totalPages: books[i].pages,
                          resourceId: books[i].id,
                          resourceType: ResourceType.book,
                          subject: books[i].subject)),
                    ),
                  ),
                ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET 2 — Examens
// ══════════════════════════════════════════════════════════════════════════
class _ExamsTab extends StatelessWidget {
  final bool loading;
  final String level;
  final ValueChanged<String> onLevelChanged;
  final Function(Widget) onGo;
  const _ExamsTab({
    required this.loading, required this.level,
    required this.onLevelChanged, required this.onGo,
  });

  static const _levels = ['Tous', 'CEPE', 'BEPC', 'BAC'];

  List<ExamSubject> get _filtered => level == 'Tous'
      ? MockLibraryData.examSubjects
      : MockLibraryData.examSubjects
          .where((e) => e.levelLabel == level)
          .toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exams = _filtered;
    return Column(children: [
      Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          ..._levels.map((l) => Padding(
            padding: const EdgeInsets.only(right: 7),
            child: GestureDetector(
              onTap: () => onLevelChanged(l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: l == level
                      ? _accent
                      : const Color(0xFFF0EBE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(l,
                    style: TextStyle(
                        color: l == level ? Colors.white : cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: l == level
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
            ),
          )),
          Spacer(),
          Text('${exams.length} sujet${exams.length > 1 ? 's' : ''}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ]),
      ),
      Divider(height: 1, thickness: 1, color: cs.outlineVariant),
      Expanded(
        child: Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(
              baseColor: Color(0xFFEAE3DB),
              highlightColor: Color(0xFFF5F0EA)),
          child: exams.isEmpty
              ? Center(child: Text('Aucun examen.',
                  style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: exams.length,
                  itemBuilder: (_, i) => _ExamTile(
                    exam: exams[i],
                    onTap: () => onGo(PdfReaderPage(
                        title: exams[i].title,
                        color: exams[i].color,
                        totalPages: 12,
                        resourceId: exams[i].id,
                        resourceType: ResourceType.examSubject,
                        subject: exams[i].subject)),
                  ),
                ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET 3 — Supports
// ══════════════════════════════════════════════════════════════════════════
class _MaterialsTab extends StatelessWidget {
  final bool loading;
  final String subject;
  final ValueChanged<String> onSubjectChanged;
  final Function(Widget) onGo;
  const _MaterialsTab({
    required this.loading, required this.subject,
    required this.onSubjectChanged, required this.onGo,
  });

  List<String> get _subjects =>
      ['Toutes', ...{for (final m in MockLibraryData.materials) m.subject}];
  List<CourseMaterial> get _filtered => subject == 'Toutes'
      ? MockLibraryData.materials
      : MockLibraryData.materials
          .where((m) => m.subject == subject)
          .toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mats = _filtered;
    return Column(children: [
      Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          _FilterDropdown(
              label: 'Matière', options: _subjects,
              value: subject, onChanged: onSubjectChanged),
          Spacer(),
          Text('${mats.length} support${mats.length > 1 ? 's' : ''}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ]),
      ),
      Divider(height: 1, thickness: 1, color: cs.outlineVariant),
      Expanded(
        child: Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(
              baseColor: Color(0xFFEAE3DB),
              highlightColor: Color(0xFFF5F0EA)),
          child: mats.isEmpty
              ? Center(child: Text('Aucun support.',
                  style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: mats.length,
                  itemBuilder: (_, i) => _MaterialTile(
                    material: mats[i],
                    onTap: () => onGo(PdfReaderPage(
                        title: mats[i].title,
                        color: mats[i].color,
                        totalPages: 24,
                        resourceId: mats[i].id,
                        resourceType: ResourceType.material,
                        subject: mats[i].subject)),
                  ),
                ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET 4 — Favoris
// ══════════════════════════════════════════════════════════════════════════
class _FavoritesTab extends StatelessWidget {
  final bool loading;
  final Function(Widget) onGo;
  const _FavoritesTab({required this.loading, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final favBooks = MockLibraryData.favoriteBooks;
    final favExams = MockLibraryData.favoriteExams;
    final favMats  = MockLibraryData.favoriteMaterials;
    final total = favBooks.length + favExams.length + favMats.length;

    return Skeletonizer(
      enabled: loading,
      effect: const ShimmerEffect(
          baseColor: Color(0xFFEAE3DB),
          highlightColor: Color(0xFFF5F0EA)),
      child: total == 0
          ? Center(child: Text('Aucun favori enregistré.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (favBooks.isNotEmpty) ...[
                  const _SectionLabel('Livres favoris'),
                  const SizedBox(height: 10),
                  ...favBooks.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BookListTile(
                      book: b,
                      onTap: () => onGo(PdfReaderPage(
                          title: b.title, color: b.coverColor,
                          totalPages: b.pages,
                          resourceId: b.id, resourceType: ResourceType.book,
                          subject: b.subject)),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
                if (favExams.isNotEmpty) ...[
                  const _SectionLabel('Examens favoris'),
                  const SizedBox(height: 10),
                  ...favExams.map((e) => _ExamTile(
                    exam: e,
                    onTap: () => onGo(PdfReaderPage(
                        title: e.title, color: e.color, totalPages: 12,
                        resourceId: e.id, resourceType: ResourceType.examSubject,
                        subject: e.subject)),
                  )),
                  const SizedBox(height: 16),
                ],
                if (favMats.isNotEmpty) ...[
                  const _SectionLabel('Supports favoris'),
                  const SizedBox(height: 10),
                  ...favMats.map((m) => _MaterialTile(
                    material: m,
                    onTap: () => onGo(PdfReaderPage(
                        title: m.title, color: m.color, totalPages: 24,
                        resourceId: m.id, resourceType: ResourceType.material,
                        subject: m.subject)),
                  )),
                ],
              ]),
            ),
    );
  }
}
