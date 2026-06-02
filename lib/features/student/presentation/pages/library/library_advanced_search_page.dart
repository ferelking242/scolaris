import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../shared/data/mock_library_data.dart';
import 'pdf_reader_page.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const _accent  = Color(0xFFCC4A1A);
const _bg      = Color(0xFFF6F4F1);
const _surface = Colors.white;
const _ink     = Color(0xFF1C1008);
const _muted   = Color(0xFF8A7060);
const _divider = Color(0xFFEAE3DB);
const _success = Color(0xFF2D7A4F);

// ══════════════════════════════════════════════════════════════════════════
// Modèle résultat
// ══════════════════════════════════════════════════════════════════════════
class _Result {
  final String type, title, line1, line2;
  final Color color;
  final IconData icon;
  final String? badge;
  final Color? badgeColor;
  final double? rating;
  final bool isDownloaded;
  const _Result({
    required this.type,
    required this.title,
    required this.line1,
    required this.line2,
    required this.color,
    required this.icon,
    this.badge,
    this.badgeColor,
    this.rating,
    this.isDownloaded = false,
  });
}

// ══════════════════════════════════════════════════════════════════════════
// LibraryAdvancedSearchPage
// ══════════════════════════════════════════════════════════════════════════
class LibraryAdvancedSearchPage extends StatefulWidget {
  final String initialQuery;
  const LibraryAdvancedSearchPage({super.key, this.initialQuery = ''});

  @override
  State<LibraryAdvancedSearchPage> createState() =>
      _LibraryAdvancedSearchPageState();
}

class _LibraryAdvancedSearchPageState
    extends State<LibraryAdvancedSearchPage> {
  late TextEditingController _ctrl;
  String _query = '';
  bool _loading = false;

  // ── Filtres ──────────────────────────────────────────────────────────
  final Set<String> _types = {'Livres', 'Examens', 'Supports'};
  String _subject   = 'Toutes';
  String _examLevel = 'Tous';
  double _minRating = 0;
  bool _withCorrection = false;
  bool _downloadedOnly = false;
  bool _favoritesOnly  = false;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _ctrl  = TextEditingController(text: _query);
    if (_query.isNotEmpty) {
      _loading = true;
      Future.delayed(const Duration(milliseconds: 500),
          () { if (mounted) setState(() => _loading = false); });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Listes options ────────────────────────────────────────────────────
  List<String> get _subjects => [
    'Toutes',
    ...{
      for (final b in MockLibraryData.books) b.subject,
      for (final m in MockLibraryData.materials) m.subject,
    },
  ];

  // ── Calcul des résultats ──────────────────────────────────────────────
  List<_Result> get _results {
    final q   = _query.toLowerCase().trim();
    final out = <_Result>[];

    if (_types.contains('Livres')) {
      for (final b in MockLibraryData.books) {
        if (_subject != 'Toutes' && b.subject != _subject) continue;
        if (_minRating > 0 && b.rating < _minRating) continue;
        if (_favoritesOnly && !b.isFavorite) continue;
        if (_downloadedOnly && !b.isDownloaded) continue;
        if (q.isNotEmpty &&
            !b.title.toLowerCase().contains(q) &&
            !b.author.toLowerCase().contains(q) &&
            !b.subject.toLowerCase().contains(q)) continue;
        out.add(_Result(
          type: 'Livre', title: b.title,
          line1: b.author,
          line2: '${b.subject} · ${b.classe} · ${b.pages} p.',
          color: b.coverColor, icon: Icons.book_rounded,
          badge: b.isFavorite ? 'Favori' : null,
          badgeColor: const Color(0xFFB72653),
          rating: b.rating,
          isDownloaded: b.isDownloaded,
        ));
      }
    }

    if (_types.contains('Examens')) {
      for (final e in MockLibraryData.examSubjects) {
        if (_examLevel != 'Tous' && e.levelLabel != _examLevel) continue;
        if (_withCorrection && !e.hasCorrection) continue;
        if (_favoritesOnly && !e.isFavorite) continue;
        if (_downloadedOnly && !e.isDownloaded) continue;
        if (q.isNotEmpty &&
            !e.title.toLowerCase().contains(q) &&
            !e.subject.toLowerCase().contains(q)) continue;
        out.add(_Result(
          type: 'Examen', title: e.title,
          line1: '${e.levelLabel} · ${e.year} · ${e.session}',
          line2: e.subject,
          color: e.color, icon: Icons.quiz_rounded,
          badge: e.hasCorrection ? 'Corrigé' : null,
          badgeColor: _success,
          isDownloaded: e.isDownloaded,
        ));
      }
    }

    if (_types.contains('Supports')) {
      for (final m in MockLibraryData.materials) {
        if (_subject != 'Toutes' && m.subject != _subject) continue;
        if (_favoritesOnly && !m.isFavorite) continue;
        if (_downloadedOnly && !m.isDownloaded) continue;
        if (q.isNotEmpty &&
            !m.title.toLowerCase().contains(q) &&
            !m.subject.toLowerCase().contains(q)) continue;
        out.add(_Result(
          type: 'Support', title: m.title,
          line1: '${m.subject} · ${m.teacher}',
          line2: '${m.size} · ${m.addedDate}',
          color: m.color, icon: m.icon,
          badge: m.isDownloaded ? 'Téléchargé' : null,
          badgeColor: _muted,
          isDownloaded: m.isDownloaded,
        ));
      }
    }

    return out;
  }

  bool get _hasActiveFilters =>
      _types.length < 3 ||
      _subject != 'Toutes' ||
      _examLevel != 'Tous' ||
      _minRating > 0 ||
      _withCorrection ||
      _downloadedOnly ||
      _favoritesOnly;

  void _resetFilters() => setState(() {
        _types
          ..clear()
          ..addAll(['Livres', 'Examens', 'Supports']);
        _subject   = 'Toutes';
        _examLevel = 'Tous';
        _minRating = 0;
        _withCorrection = false;
        _downloadedOnly = false;
        _favoritesOnly  = false;
      });

  void _triggerSearch(String q) {
    setState(() { _query = q; _loading = true; });
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) setState(() => _loading = false); });
  }

  @override
  Widget build(BuildContext context) {
    final wide    = MediaQuery.sizeOf(context).width > 700;
    final results = _results;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 44,
        leading: const BackButton(color: _ink),
        title: const Text('Recherche avancée',
            style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _divider),
        ),
        actions: [
          // Bouton filtre — visible seulement sur mobile
          if (!wide)
            Stack(alignment: Alignment.center, children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
                onPressed: () => _showFiltersSheet(context),
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: _accent, shape: BoxShape.circle),
                  ),
                ),
            ]),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        // ── Barre de recherche ──────────────────────────────────────
        Container(
          color: _surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBE5),
              borderRadius: BorderRadius.circular(11),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 18, color: _muted),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _ctrl,
                autofocus: _query.isEmpty,
                onChanged: _triggerSearch,
                style: const TextStyle(fontSize: 14, color: _ink),
                decoration: const InputDecoration(
                  hintText: 'Titre, auteur, matière…',
                  hintStyle: TextStyle(fontSize: 14, color: _muted),
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 13),
                ),
              )),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    _triggerSearch('');
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: _muted),
                  ),
                ),
            ]),
          ),
        ),
        const Divider(height: 1, color: _divider),

        // ── Corps ───────────────────────────────────────────────────
        Expanded(
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Panneau filtres gauche (desktop/tablette)
                  _FilterPanel(
                    types: _types,
                    subject: _subject,
                    subjects: _subjects,
                    examLevel: _examLevel,
                    minRating: _minRating,
                    withCorrection: _withCorrection,
                    downloadedOnly: _downloadedOnly,
                    favoritesOnly: _favoritesOnly,
                    onTypesChanged: (t) => setState(() {
                      _types..clear()..addAll(t);
                    }),
                    onSubjectChanged: (s) => setState(() => _subject = s),
                    onExamLevelChanged: (l) => setState(() => _examLevel = l),
                    onMinRatingChanged: (r) => setState(() => _minRating = r),
                    onWithCorrectionChanged: (v) =>
                        setState(() => _withCorrection = v),
                    onDownloadedOnlyChanged: (v) =>
                        setState(() => _downloadedOnly = v),
                    onFavoritesOnlyChanged: (v) =>
                        setState(() => _favoritesOnly = v),
                    onReset: _resetFilters,
                  ),
                  Container(width: 1, color: _divider),
                  Expanded(
                    child: _ResultsList(
                      results: results,
                      loading: _loading,
                      query: _query,
                      onTap: (r) => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => PdfReaderPage(
                              title: r.title,
                              color: r.color,
                              totalPages: 100))),
                    ),
                  ),
                ])
              // Mobile — résultats seulement (filtres = bottom sheet)
              : _ResultsList(
                  results: results,
                  loading: _loading,
                  query: _query,
                  onTap: (r) => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => PdfReaderPage(
                          title: r.title,
                          color: r.color,
                          totalPages: 100))),
                ),
        ),
      ]),
    );
  }

  // Bottom sheet filtres (mobile)
  void _showFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (_, sc) => _FilterPanel(
            scrollController: sc,
            types: _types,
            subject: _subject,
            subjects: _subjects,
            examLevel: _examLevel,
            minRating: _minRating,
            withCorrection: _withCorrection,
            downloadedOnly: _downloadedOnly,
            favoritesOnly: _favoritesOnly,
            onTypesChanged: (t) {
              ss(() {});
              setState(() { _types..clear()..addAll(t); });
            },
            onSubjectChanged: (s) {
              ss(() {});
              setState(() => _subject = s);
            },
            onExamLevelChanged: (l) {
              ss(() {});
              setState(() => _examLevel = l);
            },
            onMinRatingChanged: (r) {
              ss(() {});
              setState(() => _minRating = r);
            },
            onWithCorrectionChanged: (v) {
              ss(() {});
              setState(() => _withCorrection = v);
            },
            onDownloadedOnlyChanged: (v) {
              ss(() {});
              setState(() => _downloadedOnly = v);
            },
            onFavoritesOnlyChanged: (v) {
              ss(() {});
              setState(() => _favoritesOnly = v);
            },
            onReset: () {
              ss(() {});
              _resetFilters();
            },
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Panneau de filtres (desktop gauche + mobile sheet)
// ══════════════════════════════════════════════════════════════════════════
class _FilterPanel extends StatelessWidget {
  final Set<String> types;
  final String subject;
  final List<String> subjects;
  final String examLevel;
  final double minRating;
  final bool withCorrection, downloadedOnly, favoritesOnly;
  final ValueChanged<List<String>> onTypesChanged;
  final ValueChanged<String> onSubjectChanged, onExamLevelChanged;
  final ValueChanged<double> onMinRatingChanged;
  final ValueChanged<bool> onWithCorrectionChanged,
      onDownloadedOnlyChanged,
      onFavoritesOnlyChanged;
  final VoidCallback onReset;
  final ScrollController? scrollController;

  const _FilterPanel({
    required this.types,
    required this.subject,
    required this.subjects,
    required this.examLevel,
    required this.minRating,
    required this.withCorrection,
    required this.downloadedOnly,
    required this.favoritesOnly,
    required this.onTypesChanged,
    required this.onSubjectChanged,
    required this.onExamLevelChanged,
    required this.onMinRatingChanged,
    required this.onWithCorrectionChanged,
    required this.onDownloadedOnlyChanged,
    required this.onFavoritesOnlyChanged,
    required this.onReset,
    this.scrollController,
  });

  static const _allTypes   = ['Livres', 'Examens', 'Supports'];
  static const _examLevels = ['Tous', 'CEPE', 'BEPC', 'BAC'];
  static const _ratingVals = [0.0, 3.0, 3.5, 4.0, 4.5];
  static const _ratingLabels = ['Tout', '≥ 3', '≥ 3.5', '≥ 4', '≥ 4.5'];

  @override
  Widget build(BuildContext context) {
    final isSheet = scrollController != null;
    return Container(
      width: isSheet ? double.infinity : 230,
      color: _surface,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [

          // En-tête + reset
          Row(children: [
            const Expanded(child: Text('Filtres',
                style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Réinitialiser',
                  style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Type de ressource ──────────────────────────────────────
          _FilterSectionLabel('Type'),
          const SizedBox(height: 8),
          ..._allTypes.map((t) => _CheckRow(
            label: t,
            checked: types.contains(t),
            onChanged: (v) {
              final updated = Set<String>.from(types);
              if (v) updated.add(t); else updated.remove(t);
              if (updated.isNotEmpty) onTypesChanged(updated.toList());
            },
          )),
          const SizedBox(height: 18),

          // ── Matière ────────────────────────────────────────────────
          _FilterSectionLabel('Matière'),
          const SizedBox(height: 8),
          _DropdownSelect(
              options: subjects, value: subject,
              onChanged: onSubjectChanged),
          const SizedBox(height: 18),

          // ── Niveau examen ──────────────────────────────────────────
          _FilterSectionLabel("Niveau d'examen"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _examLevels.map((l) => _PillButton(
              label: l,
              selected: l == examLevel,
              onTap: () => onExamLevelChanged(l),
            )).toList(),
          ),
          const SizedBox(height: 18),

          // ── Note minimale ──────────────────────────────────────────
          _FilterSectionLabel('Note minimale'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: List.generate(_ratingVals.length, (i) => _PillButton(
              label: _ratingLabels[i],
              selected: minRating == _ratingVals[i],
              onTap: () => onMinRatingChanged(_ratingVals[i]),
            )),
          ),
          const SizedBox(height: 18),

          // ── Options booléennes ─────────────────────────────────────
          _FilterSectionLabel('Options'),
          const SizedBox(height: 8),
          _ToggleRow(
              label: 'Avec corrigé',
              value: withCorrection,
              onChanged: onWithCorrectionChanged),
          _ToggleRow(
              label: 'Téléchargé seulement',
              value: downloadedOnly,
              onChanged: onDownloadedOnlyChanged),
          _ToggleRow(
              label: 'Favoris seulement',
              value: favoritesOnly,
              onChanged: onFavoritesOnlyChanged),
        ],
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  final String text;
  const _FilterSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4));
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _CheckRow(
      {required this.label, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!checked),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: checked ? _accent : Colors.transparent,
            border: Border.all(
                color: checked ? _accent : _muted, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: checked
              ? const Icon(Icons.check_rounded,
                  size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(color: _ink, fontSize: 13)),
      ]),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Expanded(child: Text(label,
          style: const TextStyle(color: _ink, fontSize: 13))),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: _accent,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]),
  );
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _accent : const Color(0xFFF0EBE5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : _muted,
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500)),
    ),
  );
}

class _DropdownSelect extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _DropdownSelect(
      {required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: _ink),
          dropdownColor: _surface,
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: _muted),
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o,
                style: TextStyle(
                    color: o == value ? _accent : _ink,
                    fontSize: 13)),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Liste des résultats
// ══════════════════════════════════════════════════════════════════════════
class _ResultsList extends StatelessWidget {
  final List<_Result> results;
  final bool loading;
  final String query;
  final Function(_Result) onTap;
  const _ResultsList({
    required this.results,
    required this.loading,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Barre de compte
      Container(
        color: _bg,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Text(
          loading
              ? 'Recherche en cours…'
              : query.isEmpty
                  ? '${results.length} ressource${results.length > 1 ? 's' : ''} disponibles'
                  : '${results.length} résultat${results.length > 1 ? 's' : ''} pour « $query »',
          style: const TextStyle(color: _muted, fontSize: 12.5),
        ),
      ),
      const Divider(height: 1, color: _divider),
      Expanded(
        child: Skeletonizer(
          enabled: loading,
          effect: const ShimmerEffect(
              baseColor: Color(0xFFEAE3DB),
              highlightColor: Color(0xFFF5F0EA)),
          child: results.isEmpty && !loading
              ? Center(
                  child: Column(
                      mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.search_off_rounded,
                        size: 52,
                        color: Color(0xFFD6C8BC)),
                    const SizedBox(height: 14),
                    const Text('Aucun résultat',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                        'Modifie ta recherche ou tes filtres.',
                        style: TextStyle(
                            color: _muted, fontSize: 13)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: loading ? 10 : results.length,
                  itemBuilder: (_, i) {
                    if (loading) return _SkeletonTile();
                    return _ResultTile(
                        result: results[i],
                        onTap: () => onTap(results[i]));
                  },
                ),
        ),
      ),
    ]);
  }
}

// ── Skeleton tile ──────────────────────────────────────────────────────────
class _SkeletonTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider)),
    child: Row(children: [
      Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFFEAE3DB),
              borderRadius: BorderRadius.circular(10))),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 12, width: 180,
            decoration: BoxDecoration(
                color: const Color(0xFFEAE3DB),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 6),
        Container(height: 10, width: 120,
            decoration: BoxDecoration(
                color: const Color(0xFFEAE3DB),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 4),
        Container(height: 9, width: 90,
            decoration: BoxDecoration(
                color: const Color(0xFFEAE3DB),
                borderRadius: BorderRadius.circular(4))),
      ])),
    ]),
  );
}

// ── Tuile résultat ─────────────────────────────────────────────────────────
class _ResultTile extends StatelessWidget {
  final _Result result;
  final VoidCallback onTap;
  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: result.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(result.icon, size: 20, color: result.color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(result.title,
                style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(result.line1,
                style: const TextStyle(color: _muted, fontSize: 11.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text(result.line2,
                style: const TextStyle(color: _muted, fontSize: 10.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            // Tag type
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
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
            // Badge (Corrigé / Favori / Téléchargé)
            if (result.badge != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: result.badgeColor!.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(result.badge!,
                    style: TextStyle(
                        color: result.badgeColor!,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            // Note
            if (result.rating != null) ...[
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded,
                    size: 11, color: Color(0xFFC17F24)),
                const SizedBox(width: 2),
                Text(result.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ],
            // Icône téléchargé
            if (result.isDownloaded) ...[
              const SizedBox(height: 4),
              const Icon(Icons.download_done_rounded,
                  size: 12, color: _success),
            ],
          ]),
        ]),
      ),
    );
  }
}
