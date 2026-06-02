import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';

const _ink   = Color(0xFF1A0A00);
const _muted = Color(0xFF7A5C44);
const _white = Colors.white;

// Simulated content for the PDF reader
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
  'Addition : 15 + 8 = 23\nSoustraction : 15 - 8 = 7\n'
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
  '6/8 = 3/4 (en divisant numérateur et dénominateur par 2)\n\n'
  '1.4 Addition de fractions\n\n'
  'Pour additionner des fractions, il faut d\'abord les mettre au même dénominateur :\n'
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
  'Dans un triangle rectangle d\'hypoténuse c et de côtés a et b :\n'
  'a² + b² = c²',

  'Chapitre 3 : Algèbre\n\n'
  '3.1 Les équations du premier degré\n\n'
  'Une équation du premier degré à une inconnue x est de la forme :\n'
  'ax + b = 0, avec a ≠ 0\n\n'
  'Résolution : x = -b/a\n\n'
  'Exemple :\n'
  '3x + 9 = 0\n'
  '3x = -9\n'
  'x = -3\n\n'
  'Vérification : 3×(-3) + 9 = -9 + 9 = 0 ✓\n\n'
  '3.2 Les systèmes d\'équations\n\n'
  '{ 2x + y = 5\n'
  '{ x - y = 1\n\n'
  'Méthode par substitution :\n'
  'De la 2e équation : x = y + 1\n'
  'Substitution dans la 1re : 2(y+1) + y = 5\n'
  '2y + 2 + y = 5 → 3y = 3 → y = 1\n'
  'Donc x = 2. Solution : (2 ; 1)',

  'Chapitre 4 : Statistiques\n\n'
  '4.1 Notions de base\n\n'
  'La statistique est la science qui étudie les méthodes de collecte, '
  'd\'organisation et d\'analyse de données numériques.\n\n'
  'Vocabulaire essentiel :\n'
  '• Population : ensemble étudié\n'
  '• Individu : chaque élément de la population\n'
  '• Caractère : la propriété observée\n'
  '• Effectif : nombre d\'individus pour une valeur\n'
  '• Fréquence : effectif / effectif total\n\n'
  '4.2 Indicateurs de position\n\n'
  'Moyenne : somme des valeurs / nombre de valeurs\n\n'
  'Pour les données : 5, 8, 6, 9, 7, 8, 6\n'
  'Moyenne = (5+8+6+9+7+8+6) / 7 = 49/7 = 7\n\n'
  'Médiane : valeur qui partage la série ordonnée en deux\n'
  'Série ordonnée : 5, 6, 6, 7, 8, 8, 9 → Médiane = 7',
];

class PdfReaderPage extends StatefulWidget {
  final String title;
  final Color color;
  final int totalPages;
  final int initialPage;

  const PdfReaderPage({
    super.key,
    required this.title,
    required this.color,
    required this.totalPages,
    this.initialPage = 1,
  });

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage>
    with SingleTickerProviderStateMixin {
  late int _page;
  bool _darkMode      = false;
  bool _showControls  = true;
  bool _isBookmarked  = false;
  double _fontSize    = 14.0;
  bool _showPageNav   = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  final _pageCtrl = TextEditingController();
  final Set<int> _bookmarkedPages = {};

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, widget.totalPages);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.value = 1.0;
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: widget.color, statusBarBrightness: Brightness.dark));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pageCtrl.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  String get _content {
    final idx = (_page - 1) % _sampleContent.length;
    return _sampleContent[idx];
  }

  bool get _bookmarkedNow => _bookmarkedPages.contains(_page);

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _fadeCtrl.forward(); else _fadeCtrl.reverse();
  }

  void _prevPage() {
    if (_page > 1) {
      setState(() => _page--);
      _animateFlip();
    }
  }

  void _nextPage() {
    if (_page < widget.totalPages) {
      setState(() => _page++);
      _animateFlip();
    }
  }

  void _animateFlip() {
    _fadeCtrl.reverse().then((_) => _fadeCtrl.forward());
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarkedPages.contains(_page)) {
        _bookmarkedPages.remove(_page);
      } else {
        _bookmarkedPages.add(_page);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_bookmarkedPages.contains(_page)
          ? 'Page $_page ajoutée aux favoris' : 'Favori retiré'),
      backgroundColor: widget.color,
      duration: const Duration(milliseconds: 1500),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _jumpToPage() {
    showDialog(context: context, builder: (_) {
      _pageCtrl.text = '$_page';
      return AlertDialog(
        title: const Text('Aller à la page'),
        content: TextField(
          controller: _pageCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1 – ${widget.totalPages}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.color),
            onPressed: () {
              final n = int.tryParse(_pageCtrl.text);
              if (n != null && n >= 1 && n <= widget.totalPages) {
                setState(() => _page = n);
                _animateFlip();
              }
              Navigator.pop(context);
            },
            child: const Text('Aller', style: TextStyle(color: _white)),
          ),
        ],
      );
    });
  }

  void _showBookmarks() {
    if (_bookmarkedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune page mise en favori'),
        duration: Duration(milliseconds: 1500),
      ));
      return;
    }
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16),
            child: Text('Pages favorites (${_bookmarkedPages.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink))),
        const Divider(height: 1),
        ListView(
          shrinkWrap: true,
          children: (_bookmarkedPages.toList()..sort()).map((p) => ListTile(
            leading: Icon(Icons.bookmark_rounded, color: widget.color),
            title: Text('Page $p'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
            onTap: () {
              setState(() => _page = p);
              _animateFlip();
              Navigator.pop(context);
            },
          )).toList(),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg  = _darkMode ? const Color(0xFF121212) : const Color(0xFFF8F0E4);
    final txt = _darkMode ? const Color(0xFFE0D4C0) : _ink;
    final surface = _darkMode ? const Color(0xFF1E1E1E) : _white;

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(children: [
          // Content
          Column(children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 56),
            Expanded(child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Page number watermark
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Page $_page / ${widget.totalPages}',
                        style: TextStyle(color: widget.color.withOpacity(0.50),
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),
                  // Content
                  SelectableText(
                    _content,
                    style: TextStyle(
                      color: txt, fontSize: _fontSize, height: 1.75,
                      fontFamily: 'Georgia',
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Reading progress hint
                  Center(child: Column(children: [
                    LinearProgressIndicator(
                      value: _page / widget.totalPages,
                      backgroundColor: widget.color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(widget.color),
                      minHeight: 4, borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Text('${((_page / widget.totalPages) * 100).toInt()}% lu',
                        style: TextStyle(color: widget.color.withOpacity(0.60),
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ])),
                  const SizedBox(height: 20),
                ]),
              ),
            )),
          ]),

          // ── Top bar ─────────────────────────────────────────────────────
          AnimatedSlide(
            offset: _showControls ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.color, widget.color.withOpacity(0.85)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: widget.color.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _white),
                      onPressed: () => Navigator.pop(context)),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title,
                        style: const TextStyle(color: _white, fontSize: 13.5, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Page $_page / ${widget.totalPages}',
                        style: TextStyle(color: _white.withOpacity(0.65), fontSize: 11)),
                  ])),
                  // Toolbar actions
                  IconButton(
                    icon: Icon(_bookmarkedNow ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: _bookmarkedNow ? const Color(0xFFFFD700) : _white, size: 22),
                    onPressed: _toggleBookmark,
                  ),
                  IconButton(
                    icon: Icon(_darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: _white, size: 20),
                    onPressed: () => setState(() => _darkMode = !_darkMode),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: _white, size: 20),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'bookmarks', child: Text('Mes favoris')),
                      const PopupMenuItem(value: 'jump', child: Text('Aller à la page…')),
                      PopupMenuItem(value: 'zoomin',  child: Text('Zoom + (${_fontSize.toInt()}px)')),
                      const PopupMenuItem(value: 'zoomout', child: Text('Zoom -')),
                    ],
                    onSelected: (v) {
                      if (v == 'bookmarks') _showBookmarks();
                      if (v == 'jump') _jumpToPage();
                      if (v == 'zoomin'  && _fontSize < 22) setState(() => _fontSize += 2);
                      if (v == 'zoomout' && _fontSize >  10) setState(() => _fontSize -= 2);
                    },
                  ),
                ]),
              ),
            ),
          ),

          // ── Bottom navigation bar ────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: _showControls ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16,
                    MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: widget.color.withOpacity(0.15))),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10),
                      blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Progress slider
                  Row(children: [
                    Text('1', style: TextStyle(color: widget.color, fontSize: 10, fontWeight: FontWeight.w600)),
                    Expanded(child: Slider(
                      value: _page.toDouble(),
                      min: 1, max: widget.totalPages.toDouble(),
                      activeColor: widget.color,
                      inactiveColor: widget.color.withOpacity(0.15),
                      onChanged: (v) => setState(() => _page = v.round()),
                      onChangeEnd: (_) => _animateFlip(),
                    )),
                    Text('${widget.totalPages}', style: TextStyle(
                        color: widget.color, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  // Page navigation buttons
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    // Prev
                    _NavBtn(
                      icon: Icons.skip_previous_rounded, label: 'Début', color: widget.color,
                      enabled: _page > 1,
                      onTap: () { setState(() => _page = 1); _animateFlip(); },
                    ),
                    _NavBtn(
                      icon: Icons.chevron_left_rounded, label: 'Préc.', color: widget.color,
                      enabled: _page > 1, onTap: _prevPage,
                    ),
                    // Page indicator (tap to jump)
                    GestureDetector(
                      onTap: _jumpToPage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: widget.color.withOpacity(0.25)),
                        ),
                        child: Text('$_page / ${widget.totalPages}', style: TextStyle(
                            color: widget.color, fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    _NavBtn(
                      icon: Icons.chevron_right_rounded, label: 'Suiv.', color: widget.color,
                      enabled: _page < widget.totalPages, onTap: _nextPage,
                    ),
                    _NavBtn(
                      icon: Icons.skip_next_rounded, label: 'Fin', color: widget.color,
                      enabled: _page < widget.totalPages,
                      onTap: () { setState(() => _page = widget.totalPages); _animateFlip(); },
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label, required this.color,
      required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 28, color: enabled ? color : color.withOpacity(0.25)),
      Text(label, style: TextStyle(
          color: enabled ? color : color.withOpacity(0.25),
          fontSize: 9, fontWeight: FontWeight.w600)),
    ]),
  );
}
