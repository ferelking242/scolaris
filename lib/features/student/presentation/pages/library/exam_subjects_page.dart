import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/data/mock_library_data.dart';
import '../../../../../shared/widgets/surface.dart';
import 'pdf_reader_page.dart';

const _terra  = ScolarisPalette.terracotta;
const _gold   = ScolarisPalette.gold;
const _green  = ScolarisPalette.forestGreen;
const _purple = Color(0xFF7C3AED);
const _ink    = Color(0xFF1A0A00);
const _muted  = Color(0xFF7A5C44);
const _border = Color(0xFFDDCCBB);
const _bg     = Color(0xFFF5EEE6);
const _white  = Colors.white;

class ExamSubjectsPage extends StatefulWidget {
  const ExamSubjectsPage({super.key});
  @override
  State<ExamSubjectsPage> createState() => _ExamSubjectsPageState();
}

class _ExamSubjectsPageState extends State<ExamSubjectsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late final TabController _tab;
  String _search = '';
  String _subject = 'Toutes';
  String _year    = 'Toutes';

  static const _levels = [ExamLevel.cepe, ExamLevel.bepc, ExamLevel.bac];
  static const _labels = ['CEPE', 'BEPC', 'BAC'];

  static const _levelColors = [_terra, _green, _purple];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    MockLibraryData.load().then((_) {
        if (mounted) setState(() => _loading = false);
      });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  List<ExamSubject> _forLevel(ExamLevel lv) {
    return MockLibraryData.examSubjects.where((e) {
      if (e.level != lv) return false;
      if (_subject != 'Toutes' && e.subject != _subject) return false;
      if (_year    != 'Toutes' && e.year.toString() != _year) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return e.title.toLowerCase().contains(q) ||
            e.subject.toLowerCase().contains(q) || e.session.toLowerCase().contains(q);
      }
      return true;
    }).toList()..sort((a, b) => b.year.compareTo(a.year));
  }

  List<String> get _subjects {
    final s = <String>{'Toutes'};
    for (final e in MockLibraryData.examSubjects) s.add(e.subject);
    return s.toList();
  }

  List<String> get _years {
    final s = <String>{'Toutes'};
    for (final e in MockLibraryData.examSubjects) s.add(e.year.toString());
    return (s.toList()..sort((a, b) => b.compareTo(a)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Header
        _ExamHeader(tab: _tab, colors: _levelColors),

        // Tabs bar
        Container(
          color: _white,
          child: TabBar(
            controller: _tab,
            tabs: List.generate(3, (i) => Tab(text: _labels[i])),
            labelColor: _levelColors[_tab.index],
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            indicatorColor: _levelColors[_tab.index],
            indicatorWeight: 3,
            onTap: (i) => setState(() {}),
          ),
        ),

        // Search + filters
        Container(
          color: _white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(children: [
            _SearchBar(onChanged: (q) => setState(() => _search = q)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _SmallFilter(
                  label: 'Matière', options: _subjects, selected: _subject,
                  color: _levelColors[_tab.index],
                  onSelect: (v) => setState(() => _subject = v))),
              const SizedBox(width: 8),
              Expanded(child: _SmallFilter(
                  label: 'Année', options: _years, selected: _year,
                  color: _levelColors[_tab.index],
                  onSelect: (v) => setState(() => _year = v))),
            ]),
          ]),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: List.generate(3, (i) => Skeletonizer(
              enabled: _loading,
              effect: const ShimmerEffect(baseColor: Color(0xFFDDD6CE), highlightColor: Color(0xFFEFEAE3)),
              child: _ExamList(
                exams: _loading ? _placeholder() : _forLevel(_levels[i]),
                color: _levelColors[i],
                levelLabel: _labels[i],
              ),
            )),
          ),
        ),
      ]),
    );
  }

  List<ExamSubject> _placeholder() => List.generate(4, (i) => ExamSubject(
    id: 'p$i', title: 'Chargement…', subject: 'Matière',
    level: ExamLevel.bepc, session: 'Session 1', year: 2024,
    hasCorrection: i.isEven, color: _green,
  ));
}

// ══════════════════════════════════════════════════════════════════════════
// Header
// ══════════════════════════════════════════════════════════════════════════
class _ExamHeader extends StatelessWidget {
  final TabController tab;
  final List<Color> colors;
  const _ExamHeader({required this.tab, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D3B1E), _green],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _white),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sujets d\'examens', style: TextStyle(
                  color: _white, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('CEPE · BEPC · BAC', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('📋', style: TextStyle(fontSize: 22)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            _StatBubble('${MockLibraryData.examSubjects.where((e) => e.level == ExamLevel.cepe).length}', 'CEPE', _terra),
            const SizedBox(width: 12),
            _StatBubble('${MockLibraryData.examSubjects.where((e) => e.level == ExamLevel.bepc).length}', 'BEPC', _green),
            const SizedBox(width: 12),
            _StatBubble('${MockLibraryData.examSubjects.where((e) => e.level == ExamLevel.bac).length}', 'BAC', _purple),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.quiz_rounded, size: 12, color: _gold),
                const SizedBox(width: 4),
                Text('${MockLibraryData.totalExams} sujets', style: const TextStyle(
                    color: _white, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
      ])),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String val, label;
  final Color color;
  const _StatBubble(this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.50))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(val, style: const TextStyle(color: _white, fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: _white.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Search bar
// ══════════════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(color: const Color(0xFFF5EEE6),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      const Icon(Icons.search_rounded, size: 16, color: _muted),
      const SizedBox(width: 8),
      Expanded(child: TextField(onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: _ink),
        decoration: const InputDecoration(
          hintText: 'Rechercher un sujet…', hintStyle: TextStyle(fontSize: 13, color: _muted),
          isCollapsed: true, border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8)),
      )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// Small dropdown filter
// ══════════════════════════════════════════════════════════════════════════
class _SmallFilter extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final Color color;
  final ValueChanged<String> onSelect;
  const _SmallFilter({required this.label, required this.options,
      required this.selected, required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final r = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _FilterSheet(label: label, options: options,
              selected: selected, color: color, onSelect: onSelect),
        );
        if (r != null) onSelect(r);
      },
      child: Container(
        height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: selected != 'Toutes' && selected != 'Toutes les années' ? color.withOpacity(0.10) : const Color(0xFFF5EEE6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected != 'Toutes' ? color.withOpacity(0.40) : _border)),
        child: Row(children: [
          Expanded(child: Text('$label: $selected', style: TextStyle(
              color: selected != 'Toutes' ? color : _muted,
              fontSize: 11.5, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Icon(Icons.expand_more_rounded, size: 16, color: selected != 'Toutes' ? color : _muted),
        ]),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final Color color;
  final ValueChanged<String> onSelect;
  const _FilterSheet({required this.label, required this.options,
      required this.selected, required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(16), child: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink))),
      const Divider(height: 1),
      Flexible(child: ListView(shrinkWrap: true, children: [
        for (final o in options) ListTile(
          title: Text(o, style: TextStyle(
              color: o == selected ? color : _ink, fontWeight: o == selected ? FontWeight.w700 : FontWeight.w500)),
          trailing: o == selected ? Icon(Icons.check_rounded, color: color) : null,
          onTap: () { Navigator.pop(context, o); onSelect(o); },
        ),
      ])),
      const SizedBox(height: 16),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Exam list
// ══════════════════════════════════════════════════════════════════════════
class _ExamList extends StatelessWidget {
  final List<ExamSubject> exams;
  final Color color;
  final String levelLabel;
  const _ExamList({required this.exams, required this.color, required this.levelLabel});

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(color: const Color(0xFFF0E8DC), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.search_off_rounded, color: _muted, size: 26)),
        const SizedBox(height: 14),
        const Text('Aucun sujet trouvé', style: TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Essayez d\'autres filtres', style: TextStyle(fontSize: 12, color: _muted)),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ExamCard(exam: exams[i], color: color),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Exam card
// ══════════════════════════════════════════════════════════════════════════
class _ExamCard extends StatefulWidget {
  final ExamSubject exam;
  final Color color;
  const _ExamCard({required this.exam, required this.color});
  @override
  State<_ExamCard> createState() => _ExamCardState();
}
class _ExamCardState extends State<_ExamCard> {
  late bool _fav;
  @override
  void initState() { super.initState(); _fav = widget.exam.isFavorite; }

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    final c = widget.color;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
          PdfReaderPage(title: e.title, color: c, totalPages: 12,
              resourceId: e.id, resourceType: ResourceType.examSubject,
              subject: e.subject))),
      child: Container(
        decoration: BoxDecoration(
          color: _white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.20)),
          boxShadow: [BoxShadow(color: c.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: c.withOpacity(0.15))),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, c.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: c.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Center(child: Text(e.levelLabel,
                    style: const TextStyle(color: _white, fontSize: 11, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.subject, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('${e.year}', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('· ${e.session}', style: const TextStyle(color: _muted, fontSize: 12)),
                ]),
              ])),
              GestureDetector(
                onTap: () => setState(() => _fav = !_fav),
                child: Icon(_fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _fav ? Colors.red.shade400 : _muted, size: 20),
              ),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(children: [
              // Correction badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: e.hasCorrection ? _green.withOpacity(0.10) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: e.hasCorrection
                      ? _green.withOpacity(0.30) : _gold.withOpacity(0.40)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.hasCorrection ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 14, color: e.hasCorrection ? _green : _gold),
                  const SizedBox(width: 6),
                  Text(e.hasCorrection ? 'Sujet + Corrigé' : 'Sujet seul',
                      style: TextStyle(
                          color: e.hasCorrection ? _green : _gold,
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
              const Spacer(),
              // Actions
              _ActionBtn(icon: Icons.download_rounded, color: c,
                  onTap: () {}),
              const SizedBox(width: 8),
              _ActionBtn(icon: Icons.share_rounded, color: c,
                  onTap: () {}),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, c.withOpacity(0.80)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Lire', style: TextStyle(
                    color: _white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.20))),
      child: Icon(icon, size: 14, color: color),
    ),
  );
}
