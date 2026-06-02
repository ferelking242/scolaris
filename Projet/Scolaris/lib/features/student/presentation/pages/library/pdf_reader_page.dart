import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════
// Thème de lecture
// ══════════════════════════════════════════════════════════════════════════
enum _Theme { paper, white, night }

extension _ThemeX on _Theme {
  Color get bg => const [Color(0xFFFAF3E0), Colors.white, Color(0xFF111111)][index];
  Color get surface => const [Color(0xFFEFE4C8), Color(0xFFF0F0F0), Color(0xFF1C1C1C)][index];
  Color get text  => const [Color(0xFF2C1810), Color(0xFF1A1A1A), Color(0xFFCCCCCC)][index];
  Color get muted => const [Color(0xFF8B6B4A), Color(0xFF888888), Color(0xFF666666)][index];
  Color get ctrl  => const [Color(0xFFE8D8BC), Color(0xFFE8E8E8), Color(0xFF252525)][index];
  String get label => const ['Papier', 'Blanc', 'Nuit'][index];
  IconData get icon => const [Icons.eco_rounded, Icons.light_mode_rounded, Icons.dark_mode_rounded][index];
}

// ══════════════════════════════════════════════════════════════════════════
// Contenu simulé — chapitres réalistes
// ══════════════════════════════════════════════════════════════════════════
const _chapters = [
  _Chapter('Introduction', 1),
  _Chapter('Chapitre 1 — Les fondamentaux', 6),
  _Chapter('Chapitre 2 — Approfondissement', 18),
  _Chapter('Chapitre 3 — Applications pratiques', 32),
  _Chapter('Chapitre 4 — Exercices corrigés', 46),
  _Chapter('Conclusion et synthèse', 58),
];

class _Chapter {
  final String title;
  final int page;
  const _Chapter(this.title, this.page);
}

const _pages = [
  // Page 1 — Introduction
  '''Introduction générale

Ce document constitue un support pédagogique complet conçu pour accompagner les élèves dans leur apprentissage. Il couvre l'ensemble des notions fondamentales du programme officiel.

Objectifs du cours :
  • Maîtriser les concepts de base
  • Développer une méthodologie de travail rigoureuse
  • Préparer aux évaluations et examens nationaux

Ce cours est structuré en quatre chapitres progressifs, chacun accompagné d'exercices corrigés et de points-clés à retenir.

Comment utiliser ce document :

Lisez chaque chapitre attentivement avant de passer aux exercices. Les définitions importantes sont encadrées, et les formules essentielles sont mises en évidence.

Prenez des notes dans les marges, surlignez les passages importants, et revenez régulièrement sur les notions vues précédemment pour consolider vos acquis.''',

  // Page 2
  '''Les notions préalables

Avant d'aborder le cœur du programme, il est essentiel de s'assurer que vous maîtrisez les prérequis nécessaires.

Rappels fondamentaux :

1. Vocabulaire de base
Les termes techniques utilisés dans ce cours sont définis dès leur première apparition. Un glossaire complet est disponible en annexe.

2. Méthodes de travail
La réussite en classe nécessite une organisation rigoureuse : révisions régulières, participation active, et travail personnel quotidien.

3. Outils nécessaires
Selon les chapitres, vous aurez besoin de votre manuel de référence, d'une calculatrice scientifique, et de matériel de géométrie.

"L'apprentissage est un voyage, pas une destination."
— Adapté du proverbe africain : "L'éducation est la clé qui ouvre toutes les portes."

Commençons ensemble ce parcours d'apprentissage avec enthousiasme et détermination.''',

  // Page 3
  '''Chapitre 1 — Les fondamentaux

1.1 Définitions essentielles

Une définition rigoureuse est le fondement de tout raisonnement mathématique. Sans elle, il est impossible de construire une démonstration solide.

Définition 1.1 :
On appelle ensemble une collection d'objets mathématiques appelés éléments. On note habituellement les ensembles avec des lettres majuscules (A, B, E…).

Définition 1.2 :
Une fonction f de E vers F est une application qui associe à chaque élément x de E un unique élément y de F, noté y = f(x).

1.2 Propriétés fondamentales

Propriété 1 : Pour tous réels a et b,
      (a + b)² = a² + 2ab + b²

Propriété 2 : Pour tous réels a et b,
      (a - b)² = a² - 2ab + b²

Propriété 3 : Pour tous réels a et b,
      (a + b)(a - b) = a² - b²

Ces trois identités remarquables sont à connaître absolument par cœur.

Exercice d'application :
Développer et simplifier l'expression : (3x + 2)²
Solution : 9x² + 12x + 4''',

  // Page 4
  '''1.3 Méthodes de démonstration

La démonstration mathématique est un raisonnement rigoureux qui établit la vérité d'un énoncé à partir d'hypothèses et de règles logiques.

Principales méthodes :

① Démonstration directe
On part des hypothèses et on applique des étapes logiques jusqu'à la conclusion.

Exemple : Montrons que la somme de deux nombres pairs est paire.
Soient 2k et 2m deux entiers pairs (k, m ∈ ℤ).
Leur somme est 2k + 2m = 2(k + m), qui est bien paire. □

② Démonstration par contraposée
Pour prouver "si P alors Q", on prouve "si non-Q alors non-P".

③ Démonstration par l'absurde
On suppose que la conclusion est fausse et on en déduit une contradiction.

④ Démonstration par récurrence
Pour prouver qu'une propriété P(n) est vraie pour tout entier n ≥ n₀ :
  • Initialisation : vérifier P(n₀)
  • Hérédité : supposer P(k) vraie et prouver P(k+1)

Ces méthodes constituent la boîte à outils du mathématicien.''',

  // Page 5
  '''1.4 Les ensembles de nombres

ℕ — Entiers naturels : {0, 1, 2, 3, 4, …}
ℤ — Entiers relatifs : {…, -2, -1, 0, 1, 2, …}
ℚ — Nombres rationnels : fractions p/q (q ≠ 0)
ℝ — Nombres réels : tous les points de la droite
ℂ — Nombres complexes : a + bi (i² = -1)

Inclusions : ℕ ⊂ ℤ ⊂ ℚ ⊂ ℝ ⊂ ℂ

Intervalles réels :
  [a, b] = {x ∈ ℝ | a ≤ x ≤ b}  (fermé)
  ]a, b[ = {x ∈ ℝ | a < x < b}   (ouvert)
  [a, +∞[ = {x ∈ ℝ | x ≥ a}

Valeur absolue :
  |x| = x  si x ≥ 0
  |x| = -x si x < 0

Propriétés de la valeur absolue :
  |ab| = |a| · |b|
  |a + b| ≤ |a| + |b|   (inégalité triangulaire)

Points-clés à retenir :
  ✓ Tout entier est un rationnel
  ✓ √2 ∉ ℚ (irrationnel classique)
  ✓ π ≉ ℚ (irrationnel transcendant)''',

  // Page 6
  '''Chapitre 2 — Approfondissement

2.1 Fonctions et représentations graphiques

Une fonction f : ℝ → ℝ peut être représentée graphiquement dans un repère cartésien (O, i, j).

Fonctions usuelles à connaître :

Fonction affine : f(x) = ax + b
  Représentation : droite de pente a
  Zéro : x = -b/a (si a ≠ 0)

Fonction carrée : f(x) = x²
  Représentation : parabole d'axe Oy
  Minimum en x = 0, f(0) = 0

Fonction inverse : f(x) = 1/x
  Définie sur ℝ* = ℝ \ {0}
  Courbe : hyperbole équilatère

Fonction racine : f(x) = √x
  Définie sur [0, +∞[
  Strictement croissante

Étude de fonction — méthode :
  1. Domaine de définition
  2. Parité (paire/impaire)
  3. Variations (tableau de signe de f')
  4. Extrema (annulation de f')
  5. Limites aux bornes
  6. Représentation graphique''',

  // Page 7
  '''2.2 Suites numériques

Définition : Une suite (uₙ) est une application de ℕ vers ℝ.

Suite arithmétique :
  uₙ = u₀ + nr  où r = raison
  Somme : S = n × (u₀ + uₙ) / 2

Suite géométrique :
  uₙ = u₀ × qⁿ  où q = raison
  Somme : S = u₀ × (1 - qⁿ) / (1 - q)  si q ≠ 1

Exemples :

1, 4, 7, 10, 13…  → arithmétique, raison 3
2, 6, 18, 54…     → géométrique, raison 3
1, 1, 2, 3, 5, 8… → Fibonacci (ni arithmétique ni géométrique)

Limites de suites classiques :
  lim (n → ∞) 1/n = 0
  lim (n → ∞) qⁿ = 0  si |q| < 1
  lim (n → ∞) qⁿ = +∞ si q > 1

Application concrète :
Un capital C₀ placé à un taux t par an pendant n ans devient :
  Cₙ = C₀ × (1 + t)ⁿ

C'est une suite géométrique de raison (1 + t).''',

  // Page 8
  '''Chapitre 3 — Applications pratiques

3.1 Résolution de problèmes

La démarche de résolution :

① Lire attentivement l'énoncé (2 fois minimum)
② Identifier les données et ce qu'on cherche
③ Faire un schéma ou tableau si nécessaire
④ Choisir la méthode adaptée
⑤ Calculer avec soin en justifiant chaque étape
⑥ Vérifier et conclure (unités, ordre de grandeur)

Problème modèle :

Un fermier dispose d'une clôture de 120 mètres pour délimiter un enclos rectangulaire. Quelles dimensions maximisent l'aire de cet enclos ?

Solution :
Soient ℓ et L les dimensions. On a : 2ℓ + 2L = 120, soit ℓ + L = 60.
Aire : A = ℓ × L = ℓ(60 - ℓ) = -ℓ² + 60ℓ

A atteint son maximum pour ℓ = 30 m (sommet de la parabole).
Donc L = 30 m aussi : l'enclos optimal est un carré de 30 m de côté.
Aire maximale = 900 m²

Morale : parmi tous les rectangles de périmètre fixe, le carré a la plus grande aire.''',

  // Page 9
  '''3.2 Géométrie dans l'espace

Solides usuels et leurs formules :

Cube (arête a) :
  Volume : V = a³
  Aire totale : A = 6a²

Parallélépipède (a × b × c) :
  Volume : V = abc
  Aire totale : A = 2(ab + bc + ca)

Sphère (rayon r) :
  Volume : V = (4/3)πr³
  Aire : A = 4πr²

Cylindre (rayon r, hauteur h) :
  Volume : V = πr²h
  Aire latérale : A = 2πrh

Cône (rayon r, hauteur h, apothème l) :
  Volume : V = (1/3)πr²h
  Aire latérale : A = πrl  avec l = √(r² + h²)

Pyramide (base B, hauteur h) :
  Volume : V = (1/3) × B × h

Théorème de Pythagore en 3D :
  Dans un parallélépipède rectangle, la diagonale d vérifie :
  d² = a² + b² + c²''',

  // Page 10
  '''Chapitre 4 — Exercices corrigés

Exercice 1 ★
Résoudre dans ℝ : 2x² - 5x + 3 = 0

Correction :
Discriminant : Δ = b² - 4ac = 25 - 24 = 1 > 0

Deux solutions réelles :
  x₁ = (5 + 1) / 4 = 3/2
  x₂ = (5 - 1) / 4 = 1

Vérification : 2(3/2)² - 5(3/2) + 3 = 9/2 - 15/2 + 6/2 = 0 ✓

Exercice 2 ★★
Un train part de la ville A à 08h00 à 80 km/h. Un second train part de B à 09h00 à 120 km/h. Les villes A et B sont distantes de 400 km. À quelle heure se croisent-ils ?

Correction :
À t heures après 08h00 :
  Train 1 : d₁ = 80t
  Train 2 : d₂ = 120(t - 1)   [part 1h plus tard]

Croisement : 80t + 120(t - 1) = 400
  80t + 120t - 120 = 400
  200t = 520
  t = 2,6 h = 2h36min

Ils se croisent à 10h36. Train 1 a parcouru 208 km.''',
];

// ══════════════════════════════════════════════════════════════════════════
// PdfReaderPage
// ══════════════════════════════════════════════════════════════════════════
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
    with TickerProviderStateMixin {
  late int _page;
  late PageController _pageCtrl;
  _Theme _theme = _Theme.paper;
  bool _showUI = true;
  double _fontSize = 15.0;
  final Set<int> _bookmarks = {};
  Timer? _hideTimer;
  Timer? _readTimer;
  int _readSeconds = 0;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  late AnimationController _uiAnim;
  late Animation<double> _uiFade;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, widget.totalPages);
    _pageCtrl = PageController(initialPage: _page - 1);
    _uiAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _uiFade = CurvedAnimation(parent: _uiAnim, curve: Curves.easeOut);
    _uiAnim.value = 1.0;
    _startReadTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _uiAnim.dispose();
    _hideTimer?.cancel();
    _readTimer?.cancel();
    _searchCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startReadTimer() {
    _readTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _readSeconds++);
    });
  }

  String get _readTime {
    if (_readSeconds < 60) return '${_readSeconds}s';
    final m = _readSeconds ~/ 60;
    final s = _readSeconds % 60;
    return '${m}min ${s.toString().padLeft(2, '0')}s';
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) {
      _uiAnim.forward();
      _scheduleHide();
    } else {
      _uiAnim.reverse();
      _hideTimer?.cancel();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showUI = false);
        _uiAnim.reverse();
      }
    });
  }

  void _showUITemporarily() {
    if (!_showUI) {
      setState(() => _showUI = true);
      _uiAnim.forward();
    }
    _scheduleHide();
  }

  void _jumpToPage(int p) {
    final target = p.clamp(1, widget.totalPages);
    setState(() => _page = target);
    _pageCtrl.animateToPage(target - 1,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  bool get _isBookmarked => _bookmarks.contains(_page);

  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_page)) {
        _bookmarks.remove(_page);
      } else {
        _bookmarks.add(_page);
      }
    });
    _showUITemporarily();
  }

  String _pageContent(int page) {
    final idx = (page - 1) % _pages.length;
    final content = _pages[idx];
    if (_searchQuery.isEmpty) return content;
    return content; // full highlight handled in widget
  }

  void _showToc() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TocSheet(
        chapters: _chapters,
        currentPage: _page,
        theme: _theme,
        onChapter: (p) { Navigator.pop(context); _jumpToPage(p); },
      ),
    );
  }

  void _showBookmarkList() {
    if (_bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucun marque-page.'),
          backgroundColor: widget.color,
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 3, width: 40, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: _theme.muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(children: [
            Icon(Icons.bookmark_rounded, size: 18, color: widget.color),
            const SizedBox(width: 8),
            Text('Marque-pages (${_bookmarks.length})',
                style: TextStyle(color: _theme.text, fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
        const Divider(height: 1),
        ListView(
          shrinkWrap: true,
          children: (_bookmarks.toList()..sort()).map((p) => ListTile(
            dense: true,
            leading: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: widget.color.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Center(child: Icon(Icons.bookmark_rounded, size: 16,
                  color: widget.color)),
            ),
            title: Text('Page $p', style: TextStyle(color: _theme.text,
                fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 11,
                color: _theme.muted),
            onTap: () { Navigator.pop(context); _jumpToPage(p); },
          )).toList(),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  void _showSettings() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(height: 3, width: 40, margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: _theme.muted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text('Paramètres de lecture', style: TextStyle(
                  color: _theme.text, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Thème
                Row(children: [
                  Text('Thème', style: TextStyle(
                      color: _theme.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  ..._Theme.values.map((t) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () { ss(() {}); setState(() => _theme = t); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: t.bg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _theme == t ? widget.color : _theme.muted.withOpacity(0.3),
                            width: _theme == t ? 2.5 : 1,
                          ),
                        ),
                        child: Icon(t.icon, size: 16, color: t.text),
                      ),
                    ),
                  )),
                ]),
                const SizedBox(height: 20),
                // Taille de police
                Row(children: [
                  Text('Taille', style: TextStyle(
                      color: _theme.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { if (_fontSize > 11) { ss(() {}); setState(() => _fontSize -= 1); }},
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _theme.ctrl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.remove_rounded, size: 16,
                          color: _theme.text),
                    ),
                  ),
                  SizedBox(width: 60,
                    child: Text('${_fontSize.toInt()}px',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _theme.text, fontSize: 14,
                            fontWeight: FontWeight.w700))),
                  GestureDetector(
                    onTap: () { if (_fontSize < 24) { ss(() {}); setState(() => _fontSize += 1); }},
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _theme.ctrl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add_rounded, size: 16,
                          color: _theme.text),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final progress = _page / widget.totalPages;
    final pct = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: t.bg,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(children: [

          // ── Contenu — PageView ────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.totalPages,
            onPageChanged: (i) {
              setState(() => _page = i + 1);
              _showUITemporarily();
            },
            itemBuilder: (_, i) {
              final pageNum = i + 1;
              final content = _pageContent(pageNum);
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Watermark numéro de page
                  Center(child: Text('— $pageNum —',
                      style: TextStyle(
                          color: widget.color.withOpacity(0.35),
                          fontSize: 11, fontWeight: FontWeight.w600,
                          letterSpacing: 2))),
                  const SizedBox(height: 24),
                  // Contenu textuel
                  _SearchableText(
                    text: content,
                    fontSize: _fontSize,
                    color: t.text,
                    searchQuery: _searchQuery,
                    highlightColor: widget.color.withOpacity(0.25),
                  ),
                  const SizedBox(height: 40),
                  // Barre de progression en bas de page
                  Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress, minHeight: 3,
                        backgroundColor: widget.color.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation(widget.color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$pct% · $pageNum / ${widget.totalPages}',
                        style: TextStyle(
                            color: widget.color.withOpacity(0.55),
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              );
            },
          ),

          // ── Barre de recherche (slide down) ──────────────────────
          if (_showSearch)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 16, right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Icon(Icons.search_rounded, size: 18, color: widget.color),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (q) => setState(() => _searchQuery = q),
                      style: TextStyle(fontSize: 14, color: t.text),
                      decoration: InputDecoration(
                        hintText: 'Rechercher dans le texte…',
                        hintStyle: TextStyle(fontSize: 14, color: t.muted),
                        isCollapsed: true, border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    )),
                    GestureDetector(
                      onTap: () {
                        setState(() { _showSearch = false; _searchQuery = ''; _searchCtrl.clear(); });
                      },
                      child: Icon(Icons.close_rounded, size: 18, color: t.muted),
                    ),
                  ]),
                ),
              ),
            ),

          // ── Barre supérieure ──────────────────────────────────────
          FadeTransition(
            opacity: _uiFade,
            child: IgnorePointer(
              ignoring: !_showUI,
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [t.bg, t.bg.withOpacity(0)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: t.text, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.title,
                          style: TextStyle(color: t.text, fontSize: 13,
                              fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$_readTime de lecture · $pct% lu',
                          style: TextStyle(color: t.muted, fontSize: 10.5)),
                    ])),
                    // Search
                    IconButton(
                      icon: Icon(Icons.search_rounded,
                          color: _showSearch ? widget.color : t.text, size: 20),
                      onPressed: () => setState(() => _showSearch = !_showSearch),
                    ),
                    // Bookmark
                    IconButton(
                      icon: Icon(
                          _isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _isBookmarked ? widget.color : t.text,
                          size: 20),
                      onPressed: _toggleBookmark,
                    ),
                    // Settings
                    IconButton(
                      icon: Icon(Icons.tune_rounded, color: t.text, size: 20),
                      onPressed: _showSettings,
                    ),
                    // More
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: t.text, size: 20),
                      color: t.surface,
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toc', child: Row(children: [
                          Icon(Icons.list_rounded, size: 16, color: t.muted),
                          const SizedBox(width: 8),
                          Text('Table des matières',
                              style: TextStyle(color: t.text, fontSize: 13)),
                        ])),
                        PopupMenuItem(value: 'bookmarks', child: Row(children: [
                          Icon(Icons.bookmarks_rounded, size: 16, color: t.muted),
                          const SizedBox(width: 8),
                          Text('Marque-pages',
                              style: TextStyle(color: t.text, fontSize: 13)),
                        ])),
                        PopupMenuItem(value: 'jump', child: Row(children: [
                          Icon(Icons.input_rounded, size: 16, color: t.muted),
                          const SizedBox(width: 8),
                          Text('Aller à la page…',
                              style: TextStyle(color: t.text, fontSize: 13)),
                        ])),
                      ],
                      onSelected: (v) {
                        if (v == 'toc') _showToc();
                        if (v == 'bookmarks') _showBookmarkList();
                        if (v == 'jump') _showJumpDialog();
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // ── Barre inférieure ──────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _uiFade,
              child: IgnorePointer(
                ignoring: !_showUI,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 14, 16,
                      MediaQuery.of(context).padding.bottom + 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [t.bg.withOpacity(0), t.bg],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Slider
                    Row(children: [
                      Text('1', style: TextStyle(color: t.muted, fontSize: 9.5)),
                      Expanded(child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: widget.color,
                          inactiveTrackColor: widget.color.withOpacity(0.15),
                          thumbColor: widget.color,
                          overlayColor: widget.color.withOpacity(0.15),
                        ),
                        child: Slider(
                          value: _page.toDouble(),
                          min: 1,
                          max: widget.totalPages.toDouble(),
                          onChanged: (v) => setState(() => _page = v.round()),
                          onChangeEnd: (v) => _jumpToPage(v.round()),
                        ),
                      )),
                      Text('${widget.totalPages}',
                          style: TextStyle(color: t.muted, fontSize: 9.5)),
                    ]),
                    const SizedBox(height: 4),
                    // Navigation
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                      _NavButton(
                        icon: Icons.first_page_rounded, color: widget.color,
                        enabled: _page > 1,
                        onTap: () => _jumpToPage(1),
                      ),
                      _NavButton(
                        icon: Icons.chevron_left_rounded, color: widget.color,
                        enabled: _page > 1,
                        onTap: () => _jumpToPage(_page - 1),
                      ),
                      GestureDetector(
                        onTap: _showJumpDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: widget.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$_page / ${widget.totalPages}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      _NavButton(
                        icon: Icons.chevron_right_rounded, color: widget.color,
                        enabled: _page < widget.totalPages,
                        onTap: () => _jumpToPage(_page + 1),
                      ),
                      _NavButton(
                        icon: Icons.last_page_rounded, color: widget.color,
                        enabled: _page < widget.totalPages,
                        onTap: () => _jumpToPage(widget.totalPages),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showJumpDialog() {
    _hideTimer?.cancel();
    final ctrl = TextEditingController(text: '$_page');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Aller à la page',
            style: TextStyle(color: _theme.text, fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: _theme.text),
          decoration: InputDecoration(
            hintText: '1 – ${widget.totalPages}',
            hintStyle: TextStyle(color: _theme.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: widget.color, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: _theme.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null) _jumpToPage(n);
              Navigator.pop(context);
            },
            child: const Text('Aller',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Table des matières ────────────────────────────────────────────────────
class _TocSheet extends StatelessWidget {
  final List<_Chapter> chapters;
  final int currentPage;
  final _Theme theme;
  final Function(int) onChapter;
  const _TocSheet({
    required this.chapters, required this.currentPage,
    required this.theme, required this.onChapter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(height: 3, width: 40, margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(color: theme.muted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Row(children: [
          Icon(Icons.list_rounded, size: 18, color: theme.text),
          const SizedBox(width: 8),
          Text('Table des matières', style: TextStyle(
              color: theme.text, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
      ),
      const Divider(height: 1),
      ListView.separated(
        shrinkWrap: true,
        itemCount: chapters.length,
        separatorBuilder: (_, __) => Divider(
            height: 1, color: theme.muted.withOpacity(0.10)),
        itemBuilder: (_, i) {
          final ch = chapters[i];
          final isActive = currentPage >= ch.page &&
              (i + 1 >= chapters.length ||
                  currentPage < chapters[i + 1].page);
          return ListTile(
            dense: true,
            leading: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFCC4A1A).withOpacity(0.12)
                      : theme.ctrl,
                  shape: BoxShape.circle),
              child: Center(child: Text('${i + 1}',
                  style: TextStyle(
                      color: isActive
                          ? const Color(0xFFCC4A1A)
                          : theme.muted,
                      fontSize: 11, fontWeight: FontWeight.w800))),
            ),
            title: Text(ch.title, style: TextStyle(
                color: isActive ? const Color(0xFFCC4A1A) : theme.text,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
            trailing: Text('p.${ch.page}',
                style: TextStyle(color: theme.muted, fontSize: 11)),
            onTap: () => onChapter(ch.page),
          );
        },
      ),
      const SizedBox(height: 12),
    ]);
  }
}

// ── Texte avec surbrillance de recherche ──────────────────────────────────
class _SearchableText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final String searchQuery;
  final Color highlightColor;
  const _SearchableText({
    required this.text, required this.fontSize, required this.color,
    required this.searchQuery, required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) {
      return SelectableText(
        text,
        style: TextStyle(
            color: color, fontSize: fontSize, height: 1.8,
            fontFamily: 'Georgia', letterSpacing: 0.1),
      );
    }
    final q = searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx;
    while ((idx = lowerText.indexOf(q, start)) != -1) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w700),
      ));
      start = idx + q.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      style: TextStyle(
          color: color, fontSize: fontSize, height: 1.8,
          fontFamily: 'Georgia', letterSpacing: 0.1),
    );
  }
}

// ── Bouton navigation ─────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _NavButton({
    required this.icon, required this.color,
    required this.enabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: enabled
            ? color.withOpacity(0.12)
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 24,
          color: enabled ? color : color.withOpacity(0.25)),
    ),
  );
}
