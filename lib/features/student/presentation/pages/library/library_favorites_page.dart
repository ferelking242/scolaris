import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';
import '../../../../../shared/widgets/surface.dart';
import 'pdf_reader_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _green  = ScolarisPalette.forestGreen;
const _gold   = ScolarisPalette.gold;
const _cyan   = Color(0xFF0891B2);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;

class LibraryFavoritesPage extends StatefulWidget {
  const LibraryFavoritesPage({super.key});
  @override
  State<LibraryFavoritesPage> createState() => _LibraryFavoritesPageState();
}

class _LibraryFavoritesPageState extends State<LibraryFavoritesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _tabIdx = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() => _tabIdx = _tab.index));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  static const _tabColors = [_terra, _green, _cyan];
  static const _tabLabels = ['Livres', 'Examens', 'Supports'];
  static const _tabIcons  = [Icons.book_rounded, Icons.quiz_rounded, Icons.description_rounded];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Header
        _FavHeader(),

        // Downloads overview banner
        _DownloadBanner(),

        // Tab bar
        Container(
          color: _white,
          child: TabBar(
            controller: _tab,
            tabs: List.generate(3, (i) => Tab(
              icon: Icon(_tabIcons[i], size: 18),
              text: _tabLabels[i],
              iconMargin: const EdgeInsets.only(bottom: 2),
            )),
            labelColor: _tabColors[_tabIdx],
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            indicatorColor: _tabColors[_tabIdx],
            indicatorWeight: 3,
            onTap: (i) => setState(() => _tabIdx = i),
          ),
        ),

        // Tab views
        Expanded(child: TabBarView(
          controller: _tab,
          children: [
            _FavBooksTab(),
            _FavExamsTab(),
            _FavMaterialsTab(),
          ],
        )),
      ]),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _FavHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final totalFav = MockLibraryData.favoriteBooks.length +
        MockLibraryData.favoriteExams.length +
        MockLibraryData.favoriteMaterials.length;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF5B0F1A), _terra],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 16),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _white),
              onPressed: () => Navigator.pop(context)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mes favoris & téléchargements', style: TextStyle(
                color: _white, fontSize: 18, fontWeight: FontWeight.w900)),
            Text('$totalFav ressource${totalFav > 1 ? 's' : ''} sauvegardée${totalFav > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ])),
          const Text('❤️', style: TextStyle(fontSize: 28)),
        ]),
      )),
    );
  }
}

// ── Downloads banner ─────────────────────────────────────────────────────────
class _DownloadBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dlBooks = MockLibraryData.downloadedBooks.length;
    final dlMats  = MockLibraryData.downloadedMaterials.length;
    final total   = dlBooks + dlMats;
    final sizeMb  = MockLibraryData.downloadedSizeMb;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_cyan.withOpacity(0.10), _green.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cyan.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_cyan, Color(0xFF006064)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.download_done_rounded, color: _white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mes téléchargements', style: TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
          Text('$total fichier${total > 1 ? 's' : ''} disponibles hors-ligne · ${sizeMb.toStringAsFixed(0)} MB utilisés',
              style: const TextStyle(color: _muted, fontSize: 11.5)),
        ])),
        GestureDetector(
          onTap: () => _showDownloadsDialog(context, dlBooks, dlMats, sizeMb),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cyan.withOpacity(0.30)),
            ),
            child: const Text('Gérer', style: TextStyle(
                color: _cyan, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  void _showDownloadsDialog(BuildContext ctx, int dlBooks, int dlMats, double sizeMb) {
    showModalBottomSheet(context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Gestion du stockage', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 16),
          _StorageStat('Livres téléchargés', '$dlBooks livres',
              '${dlBooks * 15} MB', Icons.book_rounded, const Color(0xFF1565C0)),
          const SizedBox(height: 8),
          _StorageStat('Supports téléchargés', '$dlMats fichiers',
              '${(sizeMb - dlBooks * 15).toStringAsFixed(0)} MB', Icons.description_rounded, _cyan),
          const SizedBox(height: 16),
          // Total bar
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (sizeMb / 500).clamp(0.0, 1.0),
                minHeight: 8, backgroundColor: const Color(0xFFDDD6CE),
                valueColor: const AlwaysStoppedAnimation(_cyan),
              ),
            )),
            const SizedBox(width: 10),
            Text('${sizeMb.toStringAsFixed(0)} MB / 500 MB',
                style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _terra,
                  foregroundColor: _white, padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Libérer de l\'espace', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.pop(ctx),
            )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  final String label, count, size;
  final IconData icon;
  final Color color;
  const _StorageStat(this.label, this.count, this.size, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.18))),
    child: Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
        Text(count, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ])),
      Text(size, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Tab content – Books
// ══════════════════════════════════════════════════════════════════════════
class _FavBooksTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final books = MockLibraryData.favoriteBooks;
    if (books.isEmpty) return _Empty('Aucun livre favori', 'Ajoutez des livres à vos favoris');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final b = books[i];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              PdfReaderPage(title: b.title, color: b.coverColor, totalPages: b.pages))),
          child: Container(
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: b.coverColor.withOpacity(0.20)),
                boxShadow: [BoxShadow(color: b.coverColor.withOpacity(0.08),
                    blurRadius: 8, offset: const Offset(0, 3))]),
            child: Row(children: [
              // Mini cover
              Container(width: 64, height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [b.coverColor, b.coverColorEnd]),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                ),
                child: Stack(children: [
                  Positioned(left: 0, top: 0, bottom: 0,
                    child: Container(width: 6, decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(15))))),
                  Padding(padding: const EdgeInsets.all(8),
                    child: Text(b.title, style: const TextStyle(
                        color: _white, fontSize: 8, fontWeight: FontWeight.w800, height: 1.3),
                        maxLines: 5, overflow: TextOverflow.clip)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.title, style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(b.author, style: const TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _Tag(b.subject, b.coverColor),
                    const SizedBox(width: 6),
                    _Tag(b.classe, _muted),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    ...List.generate(5, (s) => Icon(
                        s < b.rating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 12, color: _gold)),
                    const SizedBox(width: 4),
                    Text('${b.reviewCount} avis', style: const TextStyle(color: _muted, fontSize: 10)),
                  ]),
                ]),
              )),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [b.coverColor, b.coverColorEnd]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: _white, size: 18),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Tab content – Exams
// ══════════════════════════════════════════════════════════════════════════
class _FavExamsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final exams = MockLibraryData.favoriteExams;
    if (exams.isEmpty) return _Empty('Aucun examen favori', 'Ajoutez des sujets à vos favoris');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = exams[i];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              PdfReaderPage(title: e.title, color: e.color, totalPages: 12))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: e.color.withOpacity(0.20))),
            child: Row(children: [
              Container(width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [e.color, e.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(e.levelLabel,
                    style: const TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e.subject} · ${e.year}', style: const TextStyle(
                    color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${e.levelLabel} · ${e.session}', style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: e.hasCorrection ? _green.withOpacity(0.10) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: e.hasCorrection ? _green.withOpacity(0.30) : _gold.withOpacity(0.40))),
                    child: Text(e.hasCorrection ? 'Sujet + Corrigé' : 'Sujet seul',
                        style: TextStyle(color: e.hasCorrection ? _green : _gold,
                            fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _muted),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Tab content – Materials
// ══════════════════════════════════════════════════════════════════════════
class _FavMaterialsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mats = MockLibraryData.favoriteMaterials;
    if (mats.isEmpty) return _Empty('Aucun support favori', 'Ajoutez des supports à vos favoris');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = mats[i];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              PdfReaderPage(title: m.title, color: m.color, totalPages: 24))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: m.color.withOpacity(0.20))),
            child: Row(children: [
              Container(width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [m.color, m.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(m.icon, color: _white, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${m.subject} · ${m.teacher}', style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  _Tag(m.classe, m.color),
                  const SizedBox(width: 6),
                  _Tag(m.size, _muted),
                ]),
              ])),
              if (m.isDownloaded)
                Container(
                  width: 32, height: 32, margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(color: _green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _green.withOpacity(0.30))),
                  child: const Icon(Icons.download_done_rounded, size: 16, color: _green),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _muted),
            ]),
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
  );
}

class _Empty extends StatelessWidget {
  final String title, sub;
  const _Empty(this.title, this.sub);
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 60, height: 60,
      decoration: BoxDecoration(color: const Color(0xFFF0E8DC), borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.favorite_border_rounded, color: _muted, size: 28)),
    const SizedBox(height: 14),
    Text(title, style: const TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(sub, style: const TextStyle(fontSize: 12.5, color: _muted)),
  ]));
}
