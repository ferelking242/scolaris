import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';
import '../../../../../shared/widgets/page_scaffold.dart';
import '../../../../../shared/widgets/surface.dart';
import 'pdf_reader_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _white  = Colors.white;

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});
  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  bool _loading = true;
  bool _listView = false;
  String _search = '';
  String _subject = 'Toutes';
  String _classe  = 'Toutes';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _loading = false); });
  }

  List<String> get _subjects {
    final s = <String>{'Toutes'};
    for (final b in MockLibraryData.books) s.add(b.subject);
    return s.toList();
  }

  List<String> get _classes {
    final s = <String>{'Toutes'};
    for (final b in MockLibraryData.books) s.add(b.classe);
    return s.toList();
  }

  List<LibraryBook> get _filtered => MockLibraryData.books.where((b) {
    if (_subject != 'Toutes' && b.subject != _subject) return false;
    if (_classe  != 'Toutes' && b.classe  != _classe)  return false;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      return b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.subject.toLowerCase().contains(q);
    }
    return true;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final books = _filtered;
    return PageScaffold(
      title: 'Livres',
      subtitle: '${MockLibraryData.books.length} livres disponibles',
      actions: [
        IconButton(
          icon: Icon(_listView ? Icons.grid_view_rounded : Icons.view_list_rounded,
              size: 20, color: _ink),
          onPressed: () => setState(() => _listView = !_listView),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search
        _SearchInput(onChanged: (q) => setState(() => _search = q)),
        const SizedBox(height: 10),

        // Filters
        _FilterRow(label: 'Matière', options: _subjects, selected: _subject,
            onSelect: (v) => setState(() => _subject = v)),
        const SizedBox(height: 8),
        _FilterRow(label: 'Classe', options: _classes, selected: _classe,
            onSelect: (v) => setState(() => _classe = v)),
        const SizedBox(height: 14),

        // Count
        Text('${books.length} livre${books.length > 1 ? 's' : ''}',
            style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),

        // List/Grid
        Skeletonizer(
          enabled: _loading,
          effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
          child: _loading
              ? _GridSkeleton()
              : books.isEmpty
                  ? _Empty()
                  : _listView
                      ? _ListView(books: books)
                      : _GridView(books: books),
        ),
      ]),
    );
  }
}

// ── Search ──────────────────────────────────────────────────────────────────
class _SearchInput extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchInput({required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 44, decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      const Icon(Icons.search_rounded, size: 18, color: _muted),
      const SizedBox(width: 8),
      Expanded(child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5, color: _ink),
        decoration: const InputDecoration(
          hintText: 'Rechercher un livre, auteur…',
          hintStyle: TextStyle(fontSize: 13.5, color: _muted),
          isCollapsed: true, border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      )),
    ]),
  );
}

// ── Filters ─────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  const _FilterRow({required this.label, required this.options,
      required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => SizedBox(height: 32,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final sel = options[i] == selected;
        return GestureDetector(
          onTap: () => onSelect(options[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? _terra : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? _terra : _border),
            ),
            child: Text(options[i], style: TextStyle(
                color: sel ? _white : _muted,
                fontSize: 11.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ),
        );
      },
    ),
  );
}

// ── Grid View ────────────────────────────────────────────────────────────────
class _GridView extends StatelessWidget {
  final List<LibraryBook> books;
  const _GridView({required this.books});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: books.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, mainAxisSpacing: 14, crossAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (_, i) => _BookCard(book: books[i]),
      );
    });
  }
}

// ── List View ────────────────────────────────────────────────────────────────
class _ListView extends StatelessWidget {
  final List<LibraryBook> books;
  const _ListView({required this.books});
  @override
  Widget build(BuildContext context) => Column(
    children: books.map((b) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _BookListTile(book: b),
    )).toList(),
  );
}

// ── Book card (grid) ──────────────────────────────────────────────────────────
class _BookCard extends StatefulWidget {
  final LibraryBook book;
  const _BookCard({required this.book});
  @override
  State<_BookCard> createState() => _BookCardState();
}
class _BookCardState extends State<_BookCard> {
  late bool _fav;
  @override
  void initState() { super.initState(); _fav = widget.book.isFavorite; }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PdfReaderPage(
              title: b.title, color: b.coverColor, totalPages: b.pages))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover
        Expanded(child: Stack(children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [b.coverColor, b.coverColorEnd],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: b.coverColor.withOpacity(0.35),
                  blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Stack(children: [
              // Reliure
              Positioned(left: 0, top: 0, bottom: 0,
                child: Container(width: 8,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.15),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(14))))),
              // Content
              Padding(padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.subject, style: TextStyle(
                        color: _white.withOpacity(0.70), fontSize: 9, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(b.title, style: const TextStyle(
                        color: _white, fontSize: 12, fontWeight: FontWeight.w900, height: 1.3),
                        maxLines: 4, overflow: TextOverflow.ellipsis),
                  ]),
                  Text(b.author, style: TextStyle(
                      color: _white.withOpacity(0.70), fontSize: 9)),
                ]),
              ),
              // Classe badge
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.30),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(b.classe, style: const TextStyle(
                      color: _white, fontSize: 8, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
          // Fav button
          Positioned(bottom: 8, right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _fav = !_fav),
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle),
                child: Icon(_fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 14, color: _fav ? Colors.red : _white)),
            ),
          ),
        ])),
        const SizedBox(height: 6),
        Text(b.title, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Row(children: [
          ...List.generate(5, (s) => Icon(
              s < b.rating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
              size: 10, color: _gold)),
          const SizedBox(width: 3),
          Text('${b.downloads >= 1000 ? '${(b.downloads / 1000).toStringAsFixed(1)}k' : b.downloads}',
              style: const TextStyle(color: _muted, fontSize: 9)),
        ]),
      ]),
    );
  }
}

// ── Book list tile ────────────────────────────────────────────────────────────
class _BookListTile extends StatefulWidget {
  final LibraryBook book;
  const _BookListTile({required this.book});
  @override
  State<_BookListTile> createState() => _BookListTileState();
}
class _BookListTileState extends State<_BookListTile> {
  late bool _fav;
  @override
  void initState() { super.initState(); _fav = widget.book.isFavorite; }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
          PdfReaderPage(title: b.title, color: b.coverColor, totalPages: b.pages))),
      child: Container(
        decoration: ScolarisSurface.card(radius: 14),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // Mini cover
          Container(width: 56, height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [b.coverColor, b.coverColorEnd]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(children: [
              Positioned(left: 0, top: 0, bottom: 0,
                child: Container(width: 6,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.15),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10))))),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(b.title, style: const TextStyle(
                    color: _white, fontSize: 9, fontWeight: FontWeight.w800, height: 1.3),
                    maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.title, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(b.author, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 3),
            Row(children: [
              _Chip(b.subject, b.coverColor),
              const SizedBox(width: 6),
              _Chip(b.classe, _muted),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              ...List.generate(5, (s) => Icon(
                  s < b.rating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 11, color: _gold)),
              const SizedBox(width: 4),
              Text('${b.reviewCount} avis', style: const TextStyle(color: _muted, fontSize: 10)),
            ]),
            const SizedBox(height: 4),
            Text('${b.pages} pages', style: const TextStyle(color: _muted, fontSize: 10)),
          ])),
          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () => setState(() => _fav = !_fav),
              child: Icon(_fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20, color: _fav ? Colors.red.shade400 : _muted),
            ),
            const SizedBox(height: 16),
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [b.coverColor, b.coverColorEnd]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: _white, size: 20)),
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
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
  );
}

// ── Skeleton grid ────────────────────────────────────────────────────────────
class _GridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10, mainAxisSpacing: 14,
    childAspectRatio: 0.62,
    children: List.generate(6, (_) => Column(children: [
      Expanded(child: Container(decoration: BoxDecoration(
          color: const Color(0xFFDDD6CE), borderRadius: BorderRadius.circular(14)))),
      const SizedBox(height: 6),
      Container(height: 12, width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFFDDD6CE), borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 4),
      Container(height: 10, width: 80,
          decoration: BoxDecoration(color: const Color(0xFFDDD6CE), borderRadius: BorderRadius.circular(4))),
    ])),
  );
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 48),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: const Color(0xFFF0E8DC), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.book_outlined, color: _muted, size: 26)),
      const SizedBox(height: 14),
      const Text('Aucun livre trouvé', style: TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('Essayez d\'autres filtres', style: TextStyle(fontSize: 12, color: _muted)),
    ]),
  );
}
