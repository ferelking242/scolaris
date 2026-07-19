import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sample content
// ─────────────────────────────────────────────────────────────────────────────
const _sampleContent = [
  'Chapitre 1 : Introduction aux mathématiques\n\n'
  'Les mathématiques sont une discipline fondamentale qui touche à tous les '
  'aspects de notre vie quotidienne. Dans ce chapitre, nous allons explorer '
  'les bases essentielles qui vous permettront d\'aborder avec confiance les '
  'notions plus avancées de ce cours.\n\n'
  '1.1 Les nombres entiers\n\n'
  'Les nombres entiers naturels sont : 0, 1, 2, 3, 4, 5…\n'
  'On les note ℕ (ensemble des entiers naturels).\n\n'
  'Les entiers relatifs incluent les nombres négatifs :\n'
  '…, -3, -2, -1, 0, 1, 2, 3, …\n'
  'On les note ℤ (ensemble des entiers relatifs).\n\n'
  '1.2 Opérations de base\n\n'
  'Addition : 15 + 8 = 23\nSoustraction : 15 − 8 = 7\n'
  'Multiplication : 15 × 8 = 120\nDivision : 15 ÷ 3 = 5',

  'Chapitre 1 : Introduction (suite)\n\n'
  '1.3 Les fractions\n\n'
  'Une fraction représente une partie d\'un tout. Elle s\'écrit sous la forme :\n'
  '        a\n      ───\n        b\n\n'
  'où a est le numérateur et b est le dénominateur (b ≠ 0).\n\n'
  'Exemples :\n'
  '• 1/2 représente la moitié\n'
  '• 3/4 représente trois quarts\n'
  '• 2/3 représente deux tiers\n\n'
  'Simplification d\'une fraction :\n'
  '6/8 = 3/4 (en divisant par 2)\n\n'
  '1.4 Addition de fractions\n\n'
  'Pour additionner des fractions, mettre au même dénominateur :\n'
  '1/3 + 1/4 = 4/12 + 3/12 = 7/12',

  'Chapitre 2 : Géométrie plane\n\n'
  '2.1 Les figures géométriques de base\n\n'
  'Le triangle :\n'
  '• 3 côtés, 3 angles\n'
  '• Somme des angles = 180°\n'
  '• Aire = (base × hauteur) / 2\n\n'
  'Le rectangle :\n'
  '• 4 côtés, 4 angles droits\n'
  '• Périmètre = 2(longueur + largeur)\n'
  '• Aire = longueur × largeur\n\n'
  'Le cercle :\n'
  '• Caractérisé par son rayon r\n'
  '• Circonférence = 2πr ≈ 6,28r\n'
  '• Aire = πr² ≈ 3,14r²\n\n'
  '2.2 Théorème de Pythagore\n\n'
  'Dans un triangle rectangle d\'hypoténuse c :\n'
  'a² + b² = c²',

  'Chapitre 3 : Algèbre\n\n'
  '3.1 Les équations du premier degré\n\n'
  'Une équation du premier degré à une inconnue x est de la forme :\n'
  'ax + b = 0, avec a ≠ 0\n\n'
  'Résolution : x = -b/a\n\n'
  'Exemple :\n'
  '3x + 9 = 0 → x = -3\n\n'
  'Vérification : 3×(-3) + 9 = 0 ✓\n\n'
  '3.2 Les systèmes d\'équations\n\n'
  '{ 2x + y = 5\n'
  '{ x  - y = 1\n\n'
  'Substitution : x = y + 1 → 3y = 3 → y = 1, x = 2',

  'Chapitre 4 : Statistiques\n\n'
  '4.1 Notions de base\n\n'
  'La statistique étudie les méthodes de collecte, d\'organisation et '
  'd\'analyse de données numériques.\n\n'
  'Vocabulaire essentiel :\n'
  '• Population : ensemble étudié\n'
  '• Individu : chaque élément\n'
  '• Caractère : la propriété observée\n'
  '• Effectif : nombre d\'individus pour une valeur\n'
  '• Fréquence : effectif / effectif total\n\n'
  '4.2 Indicateurs de position\n\n'
  'Moyenne : somme / nombre de valeurs\n'
  'Données : 5, 8, 6, 9, 7, 8, 6\n'
  'Moyenne = 49 / 7 = 7\n\n'
  'Médiane : 5, 6, 6, 7, 8, 8, 9 → Médiane = 7',
];

// ─────────────────────────────────────────────────────────────────────────────
// Reading themes
// ─────────────────────────────────────────────────────────────────────────────
enum _Theme { light, sepia, dark }

extension _ThemeExt on _Theme {
  Color get bg => switch (this) {
    _Theme.light => const Color(0xFFF7F4EF),
    _Theme.sepia => const Color(0xFFF5EDD8),
    _Theme.dark  => const Color(0xFF0F0F0F),
  };
  Color get page => switch (this) {
    _Theme.light => const Color(0xFFFFFFFF),
    _Theme.sepia => const Color(0xFFFAF0D7),
    _Theme.dark  => const Color(0xFF1A1A1A),
  };
  Color get text => switch (this) {
    _Theme.light => const Color(0xFF1A0A00),
    _Theme.sepia => const Color(0xFF3D2B1F),
    _Theme.dark  => const Color(0xFFE8DCC8),
  };
  Color get muted => switch (this) {
    _Theme.light => const Color(0xFF8A7A6A),
    _Theme.sepia => const Color(0xFF9A7A5A),
    _Theme.dark  => const Color(0xFF6A5A4A),
  };
  String get label => switch (this) {
    _Theme.light => 'Clair',
    _Theme.sepia => 'Sépia',
    _Theme.dark  => 'Nuit',
  };
  IconData get icon => switch (this) {
    _Theme.light => Icons.wb_sunny_rounded,
    _Theme.sepia => Icons.auto_awesome_rounded,
    _Theme.dark  => Icons.nightlight_rounded,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class PdfReaderPage extends StatefulWidget {
  final String title;
  final Color color;
  final int totalPages;
  final int initialPage;

  // Identité de la ressource ouverte — permet d'enregistrer le suivi de lecture
  // (« reprendre » + statistiques) et de gérer le favori. Optionnel : si non
  // fourni (ex. ouverture depuis un résultat de recherche brut), le lecteur
  // reste purement local.
  final String? resourceId;
  final ResourceType? resourceType;
  final String? subject;

  const PdfReaderPage({
    super.key,
    required this.title,
    required this.color,
    required this.totalPages,
    this.initialPage = 1,
    this.resourceId,
    this.resourceType,
    this.subject,
  });

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage>
    with TickerProviderStateMixin {
  // State
  late int _page;
  _Theme _theme         = _Theme.sepia;
  bool _showControls    = true;
  bool _showSettings    = false;
  double _fontSize      = 15.0;
  final Set<int> _bookmarkedPages = {};

  // Controllers
  late final AnimationController _fadeCtrl;
  late final AnimationController _settingsCtrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _settingsSlide;
  late final Animation<double>   _settingsFade;
  final _pageCtrl = TextEditingController();

  // Suivi de lecture / favori.
  late final DateTime _openedAt;
  bool _favorited = false;
  bool get _trackable =>
      widget.resourceId != null && widget.resourceType != null;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _page = widget.initialPage.clamp(1, widget.totalPages);
    if (_trackable) {
      _favorited =
          MockLibraryData.isFavorite(widget.resourceType!, widget.resourceId!);
    }

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.value = 1.0;

    _settingsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _settingsSlide = Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _settingsCtrl, curve: Curves.easeOutCubic));
    _settingsFade =
        CurvedAnimation(parent: _settingsCtrl, curve: Curves.easeOut);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark));
  }

  @override
  void dispose() {
    // Enregistre la progression de lecture (fire-and-forget, persistée via RLS).
    if (_trackable) {
      MockLibraryData.recordReading(
        type: widget.resourceType!,
        id: widget.resourceId!,
        title: widget.title,
        subject: widget.subject,
        progress: (_page / widget.totalPages).clamp(0, 1).toDouble(),
        pagesRead: _page,
        addMinutes: DateTime.now().difference(_openedAt).inMinutes,
      );
    }
    _fadeCtrl.dispose();
    _settingsCtrl.dispose();
    _pageCtrl.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _toggleFavorite() {
    if (!_trackable) return;
    setState(() => _favorited = !_favorited);
    MockLibraryData.toggleFavorite(widget.resourceType!, widget.resourceId!);
    _snack(_favorited ? '❤️ Ajouté aux favoris' : 'Retiré des favoris');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String get _content => _sampleContent[(_page - 1) % _sampleContent.length];
  bool   get _bookmarkedNow => _bookmarkedPages.contains(_page);

  void _toggleControls() {
    if (_showSettings) { _closeSettings(); return; }
    setState(() => _showControls = !_showControls);
    if (_showControls) _fadeCtrl.forward(); else _fadeCtrl.reverse();
  }

  void _openSettings()  { setState(() => _showSettings = true);  _settingsCtrl.forward(); }
  void _closeSettings() { _settingsCtrl.reverse().then((_) { if (mounted) setState(() => _showSettings = false); }); }

  void _prevPage() { if (_page > 1)                    { setState(() => _page--); _flip(); } }
  void _nextPage() { if (_page < widget.totalPages)     { setState(() => _page++); _flip(); } }
  void _goFirst()  { setState(() => _page = 1);              _flip(); }
  void _goLast()   { setState(() => _page = widget.totalPages); _flip(); }

  void _flip() {
    _fadeCtrl.reverse().then((_) { if (mounted) _fadeCtrl.forward(); });
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarkedPages.contains(_page)) {
        _bookmarkedPages.remove(_page);
      } else {
        _bookmarkedPages.add(_page);
      }
    });
    _snack(_bookmarkedPages.contains(_page)
        ? '🔖 Page $_page ajoutée aux favoris'
        : 'Favori retiré');
  }

  void _jumpToPage() {
    _pageCtrl.text = '$_page';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: widget.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.find_in_page_rounded,
                color: widget.color, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Aller à la page',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: TextField(
          controller: _pageCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: widget.color, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: '1 – ${widget.totalPages}',
            filled: true,
            fillColor: widget.color.withOpacity(0.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.color.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.color, width: 2)),
            prefixIcon: Icon(Icons.tag_rounded, color: widget.color, size: 18),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('Annuler', style: TextStyle(color: widget.color.withOpacity(0.6)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () {
              final n = int.tryParse(_pageCtrl.text);
              if (n != null && n >= 1 && n <= widget.totalPages) {
                setState(() => _page = n);
                _flip();
              }
              Navigator.pop(context);
            },
            child: const Text('Aller', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showBookmarksSheet() {
    if (_bookmarkedPages.isEmpty) {
      _snack('Aucune page mise en favori');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        color: widget.color,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          Text('Pages favorites (${_bookmarkedPages.length})',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 12),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: (_bookmarkedPages.toList()..sort())
                .map((p) => _BookmarkTile(
                      page: p,
                      color: widget.color,
                      onTap: () {
                        setState(() => _page = p);
                        _flip();
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: widget.color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 1600),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;
    final t = _theme;

    return Scaffold(
      backgroundColor: t.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(children: [

          // ── Page content ────────────────────────────────────────────────
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                  top: topPad + 64, bottom: 130 + botPad),
              child: FadeTransition(
                opacity: _fade,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Page watermark
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Page $_page  ·  ${widget.totalPages} pages',
                          style: TextStyle(
                              color: widget.color.withOpacity(0.7),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Article text
                    SelectableText(
                      _content,
                      style: TextStyle(
                        color: t.text,
                        fontSize: _fontSize,
                        height: 1.80,
                        letterSpacing: 0.08,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Progress bar
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _page / widget.totalPages,
                            backgroundColor:
                                widget.color.withOpacity(0.10),
                            valueColor:
                                AlwaysStoppedAnimation(widget.color),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${((_page / widget.totalPages) * 100).toInt()}%',
                        style: TextStyle(
                            color: widget.color.withOpacity(0.65),
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ),
          ),

          // ── Glass Top Bar ───────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: _showControls
                  ? Offset.zero
                  : const Offset(0, -1.2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: _GlassTopBar(
                color: widget.color,
                title: widget.title,
                page: _page,
                totalPages: widget.totalPages,
                topPad: topPad,
                bookmarked: _bookmarkedNow,
                showFavorite: _trackable,
                favorited: _favorited,
                onFavorite: _toggleFavorite,
                onBack: () => Navigator.pop(context),
                onBookmark: _toggleBookmark,
                onSettings: _openSettings,
              ),
            ),
          ),

          // ── Glass Floating Dock ─────────────────────────────────────────
          Positioned(
            bottom: botPad + 14,
            left: 0, right: 0,
            child: AnimatedSlide(
              offset: _showControls
                  ? Offset.zero
                  : const Offset(0, 2.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Center(
                child: _GlassDock(
                  color: widget.color,
                  page: _page,
                  totalPages: widget.totalPages,
                  onPrev: _prevPage,
                  onNext: _nextPage,
                  onFirst: _goFirst,
                  onLast: _goLast,
                  onJump: _jumpToPage,
                  onSlide: (v) => setState(() => _page = v.round()),
                  onSlideEnd: (_) => _flip(),
                ),
              ),
            ),
          ),

          // ── Settings Panel (slide up overlay) ──────────────────────────
          if (_showSettings)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSettings,
                child: FadeTransition(
                  opacity: _settingsFade,
                  child: Container(color: Colors.black.withOpacity(0.45)),
                ),
              ),
            ),
          if (_showSettings)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: _settingsSlide,
                child: _SettingsPanel(
                  color: widget.color,
                  theme: _theme,
                  fontSize: _fontSize,
                  bookmarkedPages: _bookmarkedPages,
                  currentPage: _page,
                  totalPages: widget.totalPages,
                  botPad: botPad,
                  onThemeChange: (t) => setState(() => _theme = t),
                  onFontChange: (v) => setState(() => _fontSize = v),
                  onJump: _jumpToPage,
                  onBookmarks: _showBookmarksSheet,
                  onClose: _closeSettings,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _GlassTopBar extends StatelessWidget {
  final Color color;
  final String title;
  final int page, totalPages;
  final double topPad;
  final bool bookmarked;
  final bool showFavorite;
  final bool favorited;
  final VoidCallback? onFavorite;
  final VoidCallback onBack, onBookmark, onSettings;

  const _GlassTopBar({
    required this.color, required this.title,
    required this.page, required this.totalPages,
    required this.topPad, required this.bookmarked,
    this.showFavorite = false,
    this.favorited = false,
    this.onFavorite,
    required this.onBack, required this.onBookmark, required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.only(
              top: topPad + 6, bottom: 6, left: 6, right: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.82),
                color.withOpacity(0.65),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withOpacity(0.18), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 6)),
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            // Back
            _GlassIconBtn(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
            const SizedBox(width: 6),

            // Title + subtitle
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Page $page / $totalPages',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ]),
            ),

            // Favori (ressource)
            if (showFavorite) ...[
              _GlassIconBtn(
                icon: favorited
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: favorited ? const Color(0xFFFF5A7A) : Colors.white,
                onTap: onFavorite ?? () {},
              ),
              const SizedBox(width: 2),
            ],

            // Bookmark
            _GlassIconBtn(
              icon: bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: bookmarked ? const Color(0xFFFFD700) : Colors.white,
              onTap: onBookmark,
            ),

            // Settings
            _GlassIconBtn(
              icon: Icons.tune_rounded,
              onTap: onSettings,
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Floating Dock
// ─────────────────────────────────────────────────────────────────────────────
class _GlassDock extends StatelessWidget {
  final Color color;
  final int page, totalPages;
  final VoidCallback onPrev, onNext, onFirst, onLast, onJump;
  final ValueChanged<double> onSlide;
  final ValueChanged<double> onSlideEnd;

  const _GlassDock({
    required this.color, required this.page, required this.totalPages,
    required this.onPrev, required this.onNext,
    required this.onFirst, required this.onLast,
    required this.onJump, required this.onSlide, required this.onSlideEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      // 3D outer glow
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // Main shadow
          BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 12)),
          // Dark under-shadow for depth
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 8)),
          // Top highlight
          BoxShadow(
              color: Colors.white.withOpacity(0.12),
              blurRadius: 1,
              spreadRadius: 1,
              offset: const Offset(0, -1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.28),
                  Colors.white.withOpacity(0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.white.withOpacity(0.30), width: 1.2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Drag handle
              Container(
                  width: 32, height: 3,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2))),

              // Slider row
              Row(children: [
                Text('1',
                    style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: _GlowThumbShape(color: color),
                      activeTrackColor: color,
                      inactiveTrackColor: color.withOpacity(0.18),
                      overlayColor: color.withOpacity(0.12),
                    ),
                    child: Slider(
                      value: page.toDouble(),
                      min: 1, max: totalPages.toDouble(),
                      onChanged: onSlide,
                      onChangeEnd: onSlideEnd,
                    ),
                  ),
                ),
                Text('$totalPages',
                    style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800)),
              ]),

              const SizedBox(height: 2),

              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DockBtn(
                      icon: Icons.first_page_rounded,
                      label: 'Début',
                      color: color,
                      enabled: page > 1,
                      onTap: onFirst),
                  _DockBtn(
                      icon: Icons.chevron_left_rounded,
                      label: 'Préc.',
                      color: color,
                      enabled: page > 1,
                      onTap: onPrev),

                  // Center page pill
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                    onTap: onJump,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.80)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '$page',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5),
                        ),
                        Text(
                          ' / $totalPages',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                    ),
                  ),

                  _DockBtn(
                      icon: Icons.chevron_right_rounded,
                      label: 'Suiv.',
                      color: color,
                      enabled: page < totalPages,
                      onTap: onNext),
                  _DockBtn(
                      icon: Icons.last_page_rounded,
                      label: 'Fin',
                      color: color,
                      enabled: page < totalPages,
                      onTap: onLast),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Panel (slides up)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsPanel extends StatelessWidget {
  final Color color;
  final _Theme theme;
  final double fontSize;
  final Set<int> bookmarkedPages;
  final int currentPage, totalPages;
  final double botPad;
  final ValueChanged<_Theme> onThemeChange;
  final ValueChanged<double> onFontChange;
  final VoidCallback onJump, onBookmarks, onClose;

  const _SettingsPanel({
    required this.color, required this.theme, required this.fontSize,
    required this.bookmarkedPages, required this.currentPage,
    required this.totalPages, required this.botPad,
    required this.onThemeChange, required this.onFontChange,
    required this.onJump, required this.onBookmarks, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + botPad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.92),
                Colors.white.withOpacity(0.85),
              ],
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
                color: color.withOpacity(0.15), width: 1.2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Handle
            Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2))),

            // Title
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Paramètres de lecture',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A0A00))),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFF7A5C44)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── Thème ─────────────────────────────────────────────
            _SettingsLabel(icon: Icons.palette_rounded, label: 'Thème de lecture', color: color),
            const SizedBox(height: 10),
            Row(children: _Theme.values.map((t) => Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: () => onThemeChange(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme == t
                        ? color.withOpacity(0.12)
                        : const Color(0xFFF5F0EA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: theme == t
                            ? color
                            : Colors.transparent,
                        width: 1.5),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.icon,
                        size: 20,
                        color: theme == t ? color : const Color(0xFF9A8A7A)),
                    const SizedBox(height: 4),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme == t
                                ? color
                                : const Color(0xFF9A8A7A))),
                  ]),
                ),
                ),
              ),
            )).toList()),
            const SizedBox(height: 20),

            // ── Taille du texte ───────────────────────────────────
            _SettingsLabel(
                icon: Icons.format_size_rounded,
                label: 'Taille du texte  ·  ${fontSize.toInt()}px',
                color: color),
            const SizedBox(height: 6),
            Row(children: [
              _PillBtn(label: 'A−', color: color,
                  onTap: () { if (fontSize > 11) onFontChange(fontSize - 1); }),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: _GlowThumbShape(color: color, radius: 8),
                    activeTrackColor: color,
                    inactiveTrackColor: color.withOpacity(0.15),
                    overlayColor: color.withOpacity(0.10),
                  ),
                  child: Slider(
                    value: fontSize,
                    min: 11, max: 24,
                    onChanged: onFontChange,
                  ),
                ),
              ),
              _PillBtn(label: 'A+', color: color,
                  onTap: () { if (fontSize < 24) onFontChange(fontSize + 1); }),
            ]),
            const SizedBox(height: 20),

            // ── Actions ───────────────────────────────────────────
            _SettingsLabel(icon: Icons.more_horiz_rounded, label: 'Actions', color: color),
            const SizedBox(height: 10),
            Row(children: [
              _ActionCard(
                icon: Icons.find_in_page_rounded,
                label: 'Aller à\nla page',
                color: color,
                onTap: () { onClose(); Future.delayed(const Duration(milliseconds: 350), onJump); },
              ),
              const SizedBox(width: 10),
              _ActionCard(
                icon: Icons.bookmarks_rounded,
                label: 'Mes\nfavoris',
                color: color,
                badge: bookmarkedPages.isEmpty
                    ? null
                    : '${bookmarkedPages.length}',
                onTap: () { onClose(); Future.delayed(const Duration(milliseconds: 350), onBookmarks); },
              ),
              const SizedBox(width: 10),
              _ActionCard(
                icon: Icons.share_rounded,
                label: 'Partager',
                color: color,
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _GlassIconBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    ),
  );
}

class _DockBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _DockBtn({
    required this.icon, required this.label, required this.color,
    required this.enabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: enabled
                ? color.withOpacity(0.12)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: enabled
                    ? color.withOpacity(0.25)
                    : Colors.transparent),
          ),
          child: Icon(icon,
              size: 22,
              color: enabled ? color : color.withOpacity(0.20)),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: enabled ? color.withOpacity(0.75) : color.withOpacity(0.22),
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2)),
      ]),
    ),
  );
}

class _GlassSheet extends StatelessWidget {
  final Color color;
  final Widget child;
  const _GlassSheet({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.88), color.withOpacity(0.72)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: child,
      ),
    ),
  );
}

class _BookmarkTile extends StatelessWidget {
  final int page;
  final Color color;
  final VoidCallback onTap;
  const _BookmarkTile({required this.page, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.bookmark_rounded, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 10),
          Text('Page $page',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 11, color: Colors.white54),
        ]),
      ),
    ),
  );
}

class _SettingsLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SettingsLabel({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: color),
    const SizedBox(width: 6),
    Text(label,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A0A00).withOpacity(0.65),
            letterSpacing: 0.2)),
  ]);
}

class _PillBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PillBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.label, required this.color,
    required this.onTap, this.badge,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Stack(alignment: Alignment.topCenter, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3)),
          ]),
          if (badge != null)
            Positioned(
              right: 10, top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom slider thumb with glow
// ─────────────────────────────────────────────────────────────────────────────
class _GlowThumbShape extends SliderComponentShape {
  final Color color;
  final double radius;
  const _GlowThumbShape({required this.color, this.radius = 10});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size(radius * 2, radius * 2);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    // Glow
    canvas.drawCircle(
        center,
        radius + 4,
        Paint()
          ..color = color.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // White ring
    canvas.drawCircle(center, radius + 1,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    // Colored center
    canvas.drawCircle(center, radius - 1,
        Paint()..color = color..style = PaintingStyle.fill);
  }
}
